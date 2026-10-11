\set ON_ERROR_STOP on
-- Pruebas T10-T12: ejecutar DESPUÉS de instalar programación y seguridad.
-- Requiere iniciar sesión como postgres/superusuario para comprobar un session_user sin privilegios DBA.
-- Usa solo datos ficticios, no archivos reales ni servicios externos. Todas las filas se revierten.
-- Las secuencias pueden conservar saltos después de ROLLBACK: es el comportamiento normal de PostgreSQL.
BEGIN;
SET LOCAL client_min_messages = notice;
CREATE TEMP TABLE t40_contexto(clave text PRIMARY KEY,valor bigint NOT NULL) ON COMMIT DROP;
GRANT SELECT ON t40_contexto TO st_app;

DO $pruebas$
DECLARE
  personas bigint[]:=ARRAY[]::bigint[]; usuarios bigint[]:=ARRAY[]::bigint[];
  pid bigint; uid bigint; i integer; sufijo text:=gen_random_uuid()::text;
  conv bigint; otra bigint; msg bigint; msg_archivo bigint; msg_interno bigint; msg_retirado bigint;
  part1 bigint; part2 bigint; part_otra bigint; archivo bigint; pendiente bigint; interno bigint; retirado bigint;
  adj bigint; n1 bigint; n2 bigint; e1 bigint; e2 bigint; intento2 bigint; evento uuid:=gen_random_uuid();
  idempotencia uuid:=gen_random_uuid(); instante timestamptz;
BEGIN
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname=session_user) THEN
    RAISE EXCEPTION 'Esta prueba debe iniciarse como postgres/superusuario para SET SESSION AUTHORIZATION';
  END IF;
  PERFORM set_config('app.usuario_id','',true);
  PERFORM set_config('app.invitado_token','',true);
  FOR i IN 1..3 LOOP
    INSERT INTO identidad.persona(nombres,apellidos,correo_contacto)
    VALUES('Persona ficticia '||i,'Prueba comunicación','t40_'||i||'_'||sufijo||'@example.invalid') RETURNING id INTO pid;
    INSERT INTO identidad.usuario(persona_id,correo_acceso,estado,origen_auth,emisor_externo,sujeto_externo,verificado_en)
    VALUES(pid,'t40_'||i||'_'||sufijo||'@example.invalid','activo','externo','https://auth.example.invalid',gen_random_uuid()::text,clock_timestamp())
    RETURNING id INTO uid;
    personas:=array_append(personas,pid); usuarios:=array_append(usuarios,uid);
  END LOOP;

  PERFORM set_config('app.usuario_id',usuarios[1]::text,true);
  CALL comunicacion.crear_conversacion('Seguimiento ficticio de equipo',NULL,NULL,personas,conv);
  CALL comunicacion.crear_conversacion('Otra conversación ficticia',NULL,NULL,ARRAY[personas[1]],otra);
  SELECT id INTO part1 FROM comunicacion.participante_conversacion WHERE conversacion_id=conv AND persona_id=personas[1];
  SELECT id INTO part2 FROM comunicacion.participante_conversacion WHERE conversacion_id=conv AND persona_id=personas[2];
  SELECT id INTO part_otra FROM comunicacion.participante_conversacion WHERE conversacion_id=otra AND persona_id=personas[1];
  CALL comunicacion.enviar_mensaje(conv,'Solicitud ficticia de información',ARRAY[]::bigint[],msg);
  PERFORM comunicacion.validar_integridad();
  RAISE NOTICE 'T40-01 OK: conversación con participantes y mensaje de autor vigente';

  PERFORM set_config('app.usuario_id',usuarios[2]::text,true);
  IF comunicacion.contar_mensajes_no_leidos(conv)<>1 THEN RAISE EXCEPTION 'T40-02: conteo previo incorrecto'; END IF;
  CALL comunicacion.marcar_mensaje_leido(msg);
  CALL comunicacion.marcar_mensaje_leido(msg);
  IF comunicacion.contar_mensajes_no_leidos(conv)<>0 OR
     (SELECT count(*) FROM comunicacion.lectura_mensaje WHERE mensaje_id=msg AND participante_id=part2)<>1 THEN
    RAISE EXCEPTION 'T40-02: lectura no es idempotente';
  END IF;
  RAISE NOTICE 'T40-02 OK: primera lectura y conteo sin duplicados';

  BEGIN
    CALL comunicacion.editar_mensaje(msg,'Alteración ajena');
    RAISE EXCEPTION 'T40-03: se permitió editar texto de otro autor';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'T40-03 OK: edición ajena rechazada'; END;
  BEGIN
    INSERT INTO comunicacion.lectura_mensaje(mensaje_id,participante_id,leido_en) VALUES(msg,part_otra,clock_timestamp());
    PERFORM comunicacion.validar_integridad();
    RAISE EXCEPTION 'T40-04: se permitió leer desde otra conversación';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T40-04 OK: lectura entre conversaciones rechazada'; END;
  BEGIN
    INSERT INTO comunicacion.mensaje(autor_participante_id,enviado_en) VALUES(part2,clock_timestamp());
    PERFORM comunicacion.validar_integridad();
    RAISE EXCEPTION 'T40-05: se permitió mensaje sin texto ni archivo';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T40-05 OK: contenido vacío rechazado al validar transacción'; END;
  BEGIN
    UPDATE comunicacion.mensaje SET autor_participante_id=part2 WHERE id=msg;
    RAISE EXCEPTION 'T40-06: se permitió reasignar autor';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T40-06 OK: autor inmutable'; END;
  BEGIN
    UPDATE comunicacion.lectura_mensaje SET leido_en=clock_timestamp()+INTERVAL '1 second' WHERE mensaje_id=msg AND participante_id=part2;
    RAISE EXCEPTION 'T40-07: se permitió sobrescribir primera lectura';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T40-07 OK: primera lectura inmutable'; END;

  PERFORM set_config('app.usuario_id',usuarios[1]::text,true);
  CALL comunicacion.registrar_archivo('diagnostico_ficticio.pdf','pruebas_sin_storage',sufijo||'/diagnostico.pdf','application/pdf',1234,archivo);
  CALL comunicacion.validar_archivo(archivo,'validado',decode(repeat('11',32),'hex'),false);
  CALL comunicacion.enviar_mensaje(conv,NULL,ARRAY[archivo],msg_archivo);
  PERFORM comunicacion.validar_integridad();
  RAISE NOTICE 'T40-08 OK: mensaje sin texto con adjunto privado validado';
  BEGIN
    UPDATE comunicacion.archivo a SET visibilidad='publico' WHERE a.id=archivo;
    RAISE EXCEPTION 'T40-09: se hizo público archivo privado asociado';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T40-09 OK: audiencia de archivo asociado protegida'; END;
  BEGIN
    UPDATE comunicacion.archivo a SET clave_objeto='otra-clave' WHERE a.id=archivo;
    RAISE EXCEPTION 'T40-10: se reemplazó un objeto validado';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T40-10 OK: contenido/ubicación validados inmutables'; END;
  BEGIN
    UPDATE comunicacion.archivo a SET estado='rechazado' WHERE a.id=archivo;
    PERFORM comunicacion.validar_integridad();
    RAISE EXCEPTION 'T40-11: se invalidó silenciosamente un adjunto existente';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T40-11 OK: asociación conserva validación'; END;
  CALL comunicacion.registrar_archivo('pendiente.pdf','pruebas_sin_storage',sufijo||'/pendiente.pdf','application/pdf',42,pendiente);
  BEGIN
    adj:=NULL; CALL comunicacion.adjuntar_archivo(pendiente,'mensaje',msg,NULL,'compartido',adj);
    RAISE EXCEPTION 'T40-12: se adjuntó archivo pendiente';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T40-12 OK: archivo pendiente rechazado'; END;

  -- Dos archivos cargados por la tercera persona para probar acceso del primero sin atajo de propiedad.
  PERFORM set_config('app.usuario_id',usuarios[3]::text,true);
  CALL comunicacion.registrar_archivo('informe_interno.pdf','pruebas_sin_storage',sufijo||'/interno.pdf','application/pdf',93,interno);
  CALL comunicacion.validar_archivo(interno,'validado',decode(repeat('22',32),'hex'),false);
  CALL comunicacion.enviar_mensaje(conv,'Referencia a informe interno',ARRAY[]::bigint[],msg_interno);
  -- Corrección 06: el modelo aprobado (ck_adjunto_mensaje_compartido) prohíbe adjuntos internos
  -- en mensajes; la conversación define la audiencia. Se comprueba el rechazo y el archivo
  -- queda sin compartir, de modo que T40-25 sigue verificando que otro participante no lo obtiene.
  BEGIN
    adj:=NULL; CALL comunicacion.adjuntar_archivo(interno,'mensaje',msg_interno,NULL,'interno',adj);
    RAISE EXCEPTION 'T40-12b: se aceptó un adjunto interno en un mensaje';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T40-12b OK: adjunto interno en mensaje rechazado'; END;
  CALL comunicacion.registrar_archivo('adjunto_retirado.pdf','pruebas_sin_storage',sufijo||'/retirado.pdf','application/pdf',94,retirado);
  CALL comunicacion.validar_archivo(retirado,'validado',decode(repeat('33',32),'hex'),false);
  CALL comunicacion.enviar_mensaje(conv,'Mensaje para retirar',ARRAY[retirado],msg_retirado);
  CALL comunicacion.retirar_mensaje(msg_retirado,'Retiro ficticio solicitado por autor');
  IF (SELECT contenido IS NOT NULL FROM comunicacion.v_mensajes_visibles WHERE id=msg_retirado) THEN
    RAISE EXCEPTION 'T40-13: la vista expone texto retirado';
  END IF;
  BEGIN
    UPDATE comunicacion.mensaje SET retirado=false,motivo_retiro=NULL WHERE id=msg_retirado;
    RAISE EXCEPTION 'T40-13: se revirtió un retiro';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T40-13 OK: retiro irreversible y vista sin texto'; END;

  BEGIN
    UPDATE comunicacion.participante_conversacion SET salio_en=clock_timestamp() WHERE id=part_otra;
    PERFORM comunicacion.validar_integridad();
    RAISE EXCEPTION 'T40-14: conversación abierta quedó sin participantes';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T40-14 OK: último participante vigente protegido'; END;
  CALL comunicacion.cerrar_conversacion(otra);
  BEGIN
    INSERT INTO comunicacion.mensaje(autor_participante_id,contenido,enviado_en) VALUES(part_otra,'Mensaje tardío',clock_timestamp());
    RAISE EXCEPTION 'T40-15: se envió en conversación cerrada';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T40-15 OK: conversación cerrada no admite mensajes'; END;

  CALL comunicacion.registrar_notificacion(usuarios[2],'general','Aviso ficticio','Contenido de prueba',evento,NULL,NULL,NULL,n1);
  CALL comunicacion.registrar_notificacion(usuarios[2],'general','Aviso ficticio','Contenido de prueba',evento,NULL,NULL,NULL,n2);
  IF n1<>n2 THEN RAISE EXCEPTION 'T40-16: evento duplicado creó otra notificación'; END IF;
  RAISE NOTICE 'T40-16 OK: notificación deduplicada por evento, destinatario y tipo';
  BEGIN
    CALL comunicacion.registrar_notificacion(usuarios[2],'general','Aviso alterado','Contenido de prueba',evento,NULL,NULL,NULL,n2);
    RAISE EXCEPTION 'T40-17: un reintento cambió contenido';
  EXCEPTION WHEN invalid_parameter_value THEN RAISE NOTICE 'T40-17 OK: idempotencia no admite contenido distinto'; END;
  PERFORM set_config('app.usuario_id',usuarios[1]::text,true);
  BEGIN
    CALL comunicacion.marcar_notificacion_leida(n1);
    RAISE EXCEPTION 'T40-18: persona ajena marcó lectura';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'T40-18 OK: lectura solo por destinatario'; END;
  PERFORM set_config('app.usuario_id',usuarios[2]::text,true);
  CALL comunicacion.marcar_notificacion_leida(n1);
  SELECT leida_en INTO instante FROM comunicacion.notificacion WHERE id=n1;
  CALL comunicacion.marcar_notificacion_leida(n1);
  IF (SELECT leida_en FROM comunicacion.notificacion WHERE id=n1) IS DISTINCT FROM instante THEN
    RAISE EXCEPTION 'T40-19: reintento modificó fecha de primera lectura';
  END IF;
  RAISE NOTICE 'T40-19 OK: lectura de notificación idempotente';
  CALL comunicacion.encolar_entrega(n1,'email','destinatario@example.invalid',idempotencia,e1);
  CALL comunicacion.encolar_entrega(n1,'email','destinatario@example.invalid',idempotencia,e2);
  IF e1<>e2 THEN RAISE EXCEPTION 'T40-20: intento duplicado'; END IF;
  RAISE NOTICE 'T40-20 OK: clave de entrega idempotente';
  BEGIN
    CALL comunicacion.registrar_resultado_entrega(e1,'enviada','proveedor_ficticio','referencia_1',NULL);
    RAISE EXCEPTION 'T40-21: envío se registró sin reclamar';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T40-21 OK: reclamar precede al resultado'; END;
  CALL comunicacion.reclamar_entrega(e1);
  CALL comunicacion.registrar_resultado_entrega(e1,'enviada','proveedor_ficticio','referencia_1',NULL);
  CALL comunicacion.registrar_resultado_entrega(e1,'entregada','proveedor_ficticio','referencia_1',NULL);
  CALL comunicacion.registrar_resultado_entrega(e1,'entregada','proveedor_ficticio','referencia_1',NULL);
  RAISE NOTICE 'T40-22 OK: pendiente -> enviando -> enviada -> entregada y resultado idempotente';
  BEGIN
    CALL comunicacion.encolar_entrega(n1,'email','destinatario@example.invalid',gen_random_uuid(),intento2);
    RAISE EXCEPTION 'T40-23: se duplicó una entrega confirmada por el mismo canal';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T40-23 OK: entrega confirmada no se reencola'; END;
  BEGIN
    CALL comunicacion.registrar_resultado_entrega(e1,'fallida','proveedor_ficticio','referencia_1','Error tardío ficticio');
    RAISE EXCEPTION 'T40-24: se alteró intento entregado';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T40-24 OK: resultado final inmutable'; END;

  INSERT INTO t40_contexto VALUES ('usuario_1',usuarios[1]),('conversacion',conv),('mensaje',msg),
    ('archivo_compartido',archivo),('archivo_interno',interno),('archivo_retirado',retirado),('mensaje_retirado',msg_retirado);
  PERFORM comunicacion.validar_integridad();
  -- Fuerza todos los validadores diferidos antes de cambiar de principal SQL.
  SET CONSTRAINTS ALL IMMEDIATE;
  SET CONSTRAINTS ALL DEFERRED;
END $pruebas$;

-- SET ROLE conservaría session_user=postgres y permitiría el acceso DBA.
-- Este cambio prueba el permiso real de la aplicación; st_app sigue siendo NOLOGIN.
SET SESSION AUTHORIZATION st_app;
DO $acceso$
DECLARE uid bigint; conv bigint; msg bigint; archivo bigint; interno bigint; retirado bigint; adj bigint;
BEGIN
  SELECT valor INTO uid FROM pg_temp.t40_contexto WHERE clave='usuario_1';
  SELECT valor INTO conv FROM pg_temp.t40_contexto WHERE clave='conversacion';
  SELECT valor INTO msg FROM pg_temp.t40_contexto WHERE clave='mensaje';
  SELECT valor INTO archivo FROM pg_temp.t40_contexto WHERE clave='archivo_compartido';
  SELECT valor INTO interno FROM pg_temp.t40_contexto WHERE clave='archivo_interno';
  SELECT valor INTO retirado FROM pg_temp.t40_contexto WHERE clave='archivo_retirado';
  PERFORM set_config('app.usuario_id',uid::text,true);
  IF identidad.es_dba() THEN RAISE EXCEPTION 'T40-25: el principal de prueba conserva privilegios DBA'; END IF;
  IF NOT comunicacion.puede_leer_archivo(archivo) THEN RAISE EXCEPTION 'T40-25: cargador no puede leer su archivo válido'; END IF;
  IF comunicacion.puede_leer_archivo(interno) THEN RAISE EXCEPTION 'T40-25: participante obtuvo archivo interno'; END IF;
  RAISE NOTICE 'T40-25 OK: participante normal no obtiene adjunto interno';
  BEGIN
    CALL comunicacion.adjuntar_archivo(archivo,'mensaje',msg,NULL,'interno',adj);
    RAISE EXCEPTION 'T40-26: participante creó asociación interna sin permiso de gestión';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'T40-26 OK: adjunto interno exige gestión de conversación'; END;
  IF comunicacion.puede_leer_archivo(retirado) THEN RAISE EXCEPTION 'T40-27: destinatario obtiene archivo solo vinculado a mensaje retirado'; END IF;
  RAISE NOTICE 'T40-27 OK: retiro oculta adjunto al destinatario sin otras asociaciones';
  BEGIN
    EXECUTE 'UPDATE comunicacion.mensaje SET contenido=''Cambio directo'' WHERE id=$1' USING msg;
    RAISE EXCEPTION 'T40-28: st_app modificó tabla directamente';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'T40-28 OK: rol de aplicación sin escritura directa'; END;
  PERFORM set_config('app.usuario_id','',true);
  PERFORM set_config('app.invitado_token','',true);
  IF comunicacion.puede_leer_archivo(archivo) THEN RAISE EXCEPTION 'T40-29: contexto anónimo obtuvo archivo privado'; END IF;
  RAISE NOTICE 'T40-29 OK: anonimato sin concesión no obtiene archivo privado';
END $acceso$;
RESET SESSION AUTHORIZATION;
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK;
-- Resultado esperado al ejecutar con éxito: 29 avisos T40-.. OK y ROLLBACK.
-- Si psql se detiene por error con ON_ERROR_STOP: ejecutar ROLLBACK; RESET SESSION AUTHORIZATION;
