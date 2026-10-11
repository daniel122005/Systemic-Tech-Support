\set ON_ERROR_STOP on
-- Pruebas T01-T05. Ejecutar DESPUÉS del instalador completo como superusuario/st_dba.
-- Personas, correos y equipos sintéticos. ROLLBACK conserva los datos previos.
-- Como en PostgreSQL los nextval no se revierten, la prueba puede dejar huecos en IDs.
BEGIN;
SET LOCAL TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET LOCAL search_path=pg_catalog,public;
CREATE TEMP TABLE pruebas_servicios(codigo text PRIMARY KEY,resultado text NOT NULL) ON COMMIT DROP;
CREATE FUNCTION pg_temp.comprobar(p_ok boolean,p_codigo text,p_descripcion text) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN
 IF p_ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'Fallo %: %',p_codigo,p_descripcion; END IF;
 INSERT INTO pg_temp.pruebas_servicios VALUES(p_codigo,p_descripcion);
END $$;
CREATE FUNCTION pg_temp.rechaza(p_sql text,p_sqlstate text,p_codigo text,p_descripcion text) RETURNS void
LANGUAGE plpgsql AS $$ DECLARE rechazado boolean:=false; BEGIN
 BEGIN
   EXECUTE p_sql;
   SET CONSTRAINTS ALL IMMEDIATE;
 EXCEPTION WHEN OTHERS THEN
   -- p_sqlstate admite alternativas separadas por '|': PostgreSQL 18 usa 23001 para FK RESTRICT; 17 usa 23503.
   IF NOT (SQLSTATE = ANY(string_to_array(p_sqlstate,'|'))) THEN RAISE; END IF;
   rechazado:=true;
 END;
 SET CONSTRAINTS ALL DEFERRED;
 PERFORM pg_temp.comprobar(rechazado,p_codigo,p_descripcion);
END $$;

DO $pruebas$
DECLARE
 pc bigint;pc2 bigint;pe bigint;cliente bigint;cliente2 bigint;empleado bigint;usuario bigint;
 rol bigint;perm bigint;oferta bigint;oferta_m bigint;equipo bigint;equipo2 bigint;sol bigint;solm bigint;
 orden bigint;ordenm bigint;asig bigint;ventana bigint;cita bigint;cita2 bigint;cita3 bigint;
 sd bigint;sd2 bigint;proy bigint;proy2 bigint;miembro bigint;miembro2 bigint;etapa bigint;etapa2 bigint;avance bigint;
 acceso bigint;token text:=encode(public.gen_random_bytes(32),'hex');
 sello text:=replace(gen_random_uuid()::text,'-','');inicio timestamptz:=transaction_timestamp()+interval '10 days';
BEGIN
 IF NOT identidad.es_dba() THEN RAISE EXCEPTION 'Las pruebas requieren un DBA autorizado'; END IF;
 PERFORM identidad.bloquear_operacion();
 PERFORM set_config('app.usuario_id','',true); PERFORM set_config('app.invitado_token','',true);
 PERFORM set_config('app.motivo','Pruebas sintéticas T01-T05; se revierten al terminar',true);
 INSERT INTO identidad.persona(nombres,apellidos,correo_contacto) VALUES('Cliente','Demostración','cliente.'||sello||'@example.test') RETURNING id INTO pc;
 INSERT INTO identidad.persona(nombres,apellidos,correo_contacto) VALUES('Cliente','Alternativo','alternativo.'||sello||'@example.test') RETURNING id INTO pc2;
 INSERT INTO identidad.persona(nombres,apellidos,correo_contacto) VALUES('Profesional','Demostración','profesional.'||sello||'@example.test') RETURNING id INTO pe;
 INSERT INTO identidad.cliente(persona_id,codigo) VALUES(pc,'TC-'||sello) RETURNING id INTO cliente;
 INSERT INTO identidad.cliente(persona_id,codigo) VALUES(pc2,'TC2-'||sello) RETURNING id INTO cliente2;
 INSERT INTO identidad.empleado(persona_id,codigo,cargo,fecha_vinculacion) VALUES(pe,'TE-'||sello,'Técnico y desarrollador de prueba',current_date) RETURNING id INTO empleado;
 INSERT INTO identidad.usuario(persona_id,correo_acceso,estado,origen_auth,emisor_externo,sujeto_externo,verificado_en)
 VALUES(pe,'profesional.'||sello||'@example.test','activo','externo','https://identidad.example.test',sello,transaction_timestamp()) RETURNING id INTO usuario;
 INSERT INTO identidad.rol(codigo,nombre,descripcion) VALUES('TR-'||sello,'Profesional de pruebas','Solo existe durante esta transacción') RETURNING id INTO rol;
 INSERT INTO identidad.permiso(codigo,recurso,accion,descripcion) VALUES('TEST-OT-'||sello,'orden_servicio','gestionar','Administrar órdenes') ON CONFLICT(recurso,accion) DO NOTHING;
 SELECT id INTO perm FROM identidad.permiso WHERE recurso='orden_servicio' AND accion='gestionar';
 INSERT INTO identidad.rol_permiso(rol_id,permiso_id,actor_sistema) VALUES(rol,perm,'prueba');
 INSERT INTO identidad.permiso(codigo,recurso,accion,descripcion) VALUES('TEST-PR-'||sello,'proyecto','gestionar','Administrar proyectos') ON CONFLICT(recurso,accion) DO NOTHING;
 SELECT id INTO perm FROM identidad.permiso WHERE recurso='proyecto' AND accion='gestionar';
 INSERT INTO identidad.rol_permiso(rol_id,permiso_id,actor_sistema) VALUES(rol,perm,'prueba');
 INSERT INTO identidad.usuario_rol(usuario_id,rol_id,actor_sistema) VALUES(usuario,rol,'prueba');
 INSERT INTO identidad.permiso(codigo,recurso,accion,descripcion) VALUES('TEST-LEER-'||sello,'orden_servicio','leer','Consultar orden propia') ON CONFLICT(recurso,accion) DO NOTHING;
 INSERT INTO identidad.permiso(codigo,recurso,accion,descripcion) VALUES('TEST-CAL-'||sello,'orden_servicio','calificar','Valorar servicio propio') ON CONFLICT(recurso,accion) DO NOTHING;
 INSERT INTO servicios.servicio_ofrecido(codigo,nombre,descripcion,modalidad,publicado)
 VALUES('TRP-'||sello,'Reparación de portátil','Diagnóstico y corrección de fallo','reparacion',true) RETURNING id INTO oferta;
 INSERT INTO servicios.servicio_ofrecido(codigo,nombre,descripcion,modalidad,publicado)
 VALUES('TMT-'||sello,'Mantenimiento preventivo','Limpieza y revisión funcional','mantenimiento',true) RETURNING id INTO oferta_m;
 CALL servicios.registrar_equipo(cliente,'portatil','Portátil sintético de pruebas','Marca de ejemplo','Modelo laboratorio','SERIE-'||sello,equipo);
 CALL servicios.registrar_equipo(cliente2,'portatil','Equipo de otro cliente',NULL,NULL,NULL,equipo2);
 CALL servicios.solicitar_servicio(cliente,oferta,equipo,'El equipo no inicia',NULL,NULL,sol);
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
 PERFORM pg_temp.comprobar(EXISTS(SELECT 1 FROM servicios.historial_solicitud_servicio WHERE solicitud_servicio_id=sol AND numero_evento=1 AND estado_nuevo='recibida'),'S01','Solicitud de reparación e historial inicial atómicos');
 PERFORM pg_temp.rechaza(format('UPDATE servicios.solicitud_servicio SET equipo_cliente_id=%s WHERE id=%s',equipo2,sol),'23514','S02','Equipo de otro cliente rechazado');
 PERFORM pg_temp.rechaza(format('UPDATE servicios.solicitud_servicio SET equipo_cliente_id=NULL WHERE id=%s',sol),'23514','S03','Reparación sin equipo rechazada');
 PERFORM pg_temp.rechaza(format('UPDATE servicios.servicio_ofrecido SET modalidad=''mantenimiento'' WHERE id=%s',oferta),'23514','S04','Modalidad de oferta con solicitudes inmutable');
 PERFORM pg_temp.rechaza(format('UPDATE servicios.equipo_cliente SET cliente_id=%s WHERE id=%s',cliente2,equipo),'23514','S05','Titularidad histórica de equipo protegida');
 CALL servicios.cambiar_estado_solicitud(sol,'en_evaluacion','Recepción y revisión del equipo');
 CALL servicios.aceptar_solicitud(sol,180000,0,'COP',NULL,NULL,orden);
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
 PERFORM pg_temp.comprobar(EXISTS(SELECT 1 FROM servicios.reparacion WHERE orden_servicio_id=orden) AND NOT EXISTS(SELECT 1 FROM servicios.mantenimiento WHERE orden_servicio_id=orden),'S06','Aceptación crea una orden con subtipo reparación exclusivo');
 PERFORM pg_temp.rechaza(format('INSERT INTO servicios.mantenimiento(orden_servicio_id,tipo_mantenimiento) VALUES(%s,''preventivo'')',orden),'23514','S07','Doble subtipo rechazado');
 PERFORM pg_temp.rechaza(format('DELETE FROM servicios.reparacion WHERE orden_servicio_id=%s',orden),'23514','S08','Orden sin subtipo rechazada al validar la transacción');
 CALL servicios.asignar_tecnico(orden,empleado,'Diagnóstico y reparación',true,'Técnico responsable',asig);
 CALL servicios.cambiar_estado_orden(orden,'en_ejecucion','Diagnóstico iniciado');
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
 PERFORM pg_temp.comprobar((SELECT estado='en_ejecucion' FROM servicios.orden_servicio WHERE id=orden),'S09','La ejecución exige responsable habilitado');
 PERFORM pg_temp.rechaza(format('CALL servicios.retirar_tecnico(%s,''Retiro sin sustituto'')',asig),'23514','S10','Retirar único responsable exige sustitución o pausa');
 PERFORM pg_temp.rechaza(format('CALL servicios.cerrar_servicio(%s,''Reparación terminada'',NULL)',orden),'23514','S11','No se cierra reparación sin informe');
 CALL servicios.registrar_disponibilidad(empleado,inicio,inicio+interval '8 hours','Horario de prueba',ventana);
 CALL servicios.programar_cita(sol,empleado,inicio+interval '1 hour',inicio+interval '2 hours','presencial','Taller de demostración',true,cita);
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
 PERFORM pg_temp.comprobar((SELECT estado='confirmada' FROM servicios.cita_servicio WHERE id=cita),'S12','Cita confirmada dentro de disponibilidad');
 PERFORM pg_temp.rechaza(format('UPDATE servicios.disponibilidad_tecnico SET habilitada=false WHERE id=%s',ventana),'23514','S13','La ventana no puede dejar una cita futura sin cobertura');
 PERFORM pg_temp.rechaza(format('INSERT INTO servicios.cita_servicio(solicitud_servicio_id,tecnico_id,inicio,fin,estado,modalidad_atencion,lugar) VALUES(%s,%s,%L,%L,''confirmada'',''presencial'',''Taller'')',sol,empleado,inicio+interval '90 minutes',inicio+interval '150 minutes'),'23P01','S14','EXCLUDE rechaza citas solapadas');
 CALL servicios.programar_cita(sol,empleado,inicio+interval '2 hours',inicio+interval '3 hours','presencial','Taller de demostración',true,cita2);
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
 PERFORM pg_temp.comprobar(cita2 IS NOT NULL,'S15','Intervalos contiguos permitidos mediante límite final exclusivo');
 CALL servicios.reprogramar_cita(cita,empleado,inicio+interval '4 hours',inicio+interval '5 hours','Cambio acordado de horario',cita3);
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
 PERFORM pg_temp.comprobar((SELECT estado='cancelada' FROM servicios.cita_servicio WHERE id=cita) AND EXISTS(SELECT 1 FROM servicios.cita_servicio WHERE id=cita3 AND sustituye_cita_id=cita),'S16','La reprogramación conserva cita anterior y referencia');
 CALL servicios.registrar_informe_reparacion(orden,'Falla en almacenamiento','Conector sin contacto','Se corrigió conexión y se verificó inicio','Inicio y prueba funcional correctos');
 CALL servicios.cerrar_servicio(orden,'Equipo restaurado','Entrega acordada');
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
 PERFORM pg_temp.comprobar((SELECT estado='finalizada' FROM servicios.orden_servicio WHERE id=orden),'S17','Reparación finalizada con evidencia técnica');
 PERFORM pg_temp.rechaza(format('UPDATE servicios.reparacion SET solucion=''Otro trabajo'' WHERE orden_servicio_id=%s',orden),'23514','S18','Informe finalizado se conserva');
 PERFORM pg_temp.rechaza(format('INSERT INTO servicios.calificacion_servicio(orden_servicio_id,autor_persona_id,puntuacion) VALUES(%s,%s,5)',orden,pc2),'23514','S19','Valoración de persona ajena rechazada');
 CALL identidad.emitir_acceso_invitado(pc,'orden_servicio',orden,NULL,'correo','cliente.'||sello||'@example.test',transaction_timestamp(),transaction_timestamp()+interval '1 day',token,ARRAY['leer','calificar'],acceso);
 PERFORM set_config('app.invitado_token',token,true);
 CALL servicios.calificar_servicio(orden,5::smallint,'Servicio de prueba resuelto');
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
 PERFORM pg_temp.comprobar(EXISTS(SELECT 1 FROM servicios.calificacion_servicio WHERE orden_servicio_id=orden AND autor_persona_id=pc) AND NOT EXISTS(SELECT 1 FROM identidad.usuario WHERE persona_id=pc),'S20','Titular invitado sin cuenta puede valorar con concesión verificada');
 PERFORM set_config('app.invitado_token','',true);
 CALL servicios.solicitar_servicio(cliente,oferta_m,NULL,'Revisión preventiva','Revisión y limpieza de puesto completo',NULL,solm);
 CALL servicios.cambiar_estado_solicitud(solm,'en_evaluacion','Se delimita el alcance');
 CALL servicios.aceptar_solicitud(solm,90000,0,'COP',NULL,'preventivo',ordenm);
 asig:=NULL; CALL servicios.asignar_tecnico(ordenm,empleado,'Mantenimiento',true,'Asignación técnica',asig);
 CALL servicios.cambiar_estado_orden(ordenm,'en_ejecucion','Inicio del mantenimiento');
 CALL servicios.registrar_informe_mantenimiento(ordenm,'Limpieza y pruebas','No se detectaron defectos','Revisión periódica');
 CALL servicios.cerrar_servicio(ordenm,'Mantenimiento realizado',NULL);
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
 PERFORM pg_temp.comprobar(EXISTS(SELECT 1 FROM servicios.mantenimiento WHERE orden_servicio_id=ordenm),'S21','Mantenimiento sin equipo admite alcance explícito y cierre documentado');

 CALL proyectos.solicitar_desarrollo(cliente,'Organizar solicitudes','Reducir tareas manuales','Portal de seguimiento',NULL,NULL,NULL,sd);
 CALL proyectos.cambiar_estado_solicitud(sd,'en_evaluacion','Viabilidad técnica');
 CALL proyectos.aprobar_solicitud(sd,'Portal de ejemplo','Aplicación de demostración','Módulos de solicitudes y seguimiento',1200000,0,'COP',NULL,proy);
 CALL proyectos.asignar_miembro(proy,empleado,'Desarrollador responsable',true,'Asignación inicial',miembro);
 PERFORM pg_temp.rechaza(format('CALL proyectos.cambiar_estado_proyecto(%s,''en_ejecucion'',''Inicio sin etapas'')',proy),'23514','P01','No se ejecuta proyecto sin etapas');
 CALL proyectos.definir_etapa(proy,'Análisis','Definir necesidades y criterios',1,1,NULL,NULL,'Plan inicial',etapa);
 CALL proyectos.definir_etapa(proy,'Construcción','Implementación y revisión',2,3,NULL,NULL,'Plan inicial',etapa2);
 CALL proyectos.cambiar_estado_proyecto(proy,'en_ejecucion','Plan aprobado para ejecución');
 PERFORM set_config('app.usuario_id',usuario::text,true);
 CALL proyectos.registrar_avance(etapa,miembro,100,'Análisis aprobado',NULL,avance);
 avance:=NULL; CALL proyectos.registrar_avance(etapa2,miembro,20,'Primera entrega funcional',NULL,avance);
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
 PERFORM pg_temp.comprobar(proyectos.obtener_avance(proy)=40,'P02','Avance ponderado: (1*100+3*20)/4=40');
 PERFORM pg_temp.rechaza(format('UPDATE proyectos.avance_proyecto SET porcentaje=100 WHERE id=%s',avance),'23514','P03','Avances históricos append-only');
 PERFORM pg_temp.rechaza(format('DELETE FROM proyectos.etapa_proyecto WHERE id=%s',etapa),'23001|23503','P04','Etapa con avances no se elimina');
 PERFORM set_config('app.motivo','',true);
 PERFORM pg_temp.rechaza(format('UPDATE proyectos.etapa_proyecto SET peso=2 WHERE id=%s',etapa),'23514','P05','Revisión de plan iniciado exige motivo');
 CALL proyectos.definir_etapa(proy,'Análisis','Definir necesidades y criterios',1,3,NULL,NULL,'Mayor peso por revisión del alcance',etapa);
 PERFORM pg_temp.comprobar(proyectos.obtener_avance(proy)=60,'P06','Revisión autorizada de pesos recalcula porcentaje sin reescribir avances');
 CALL proyectos.solicitar_desarrollo(cliente,'Segundo proyecto','Prueba de referencias','Módulo independiente',NULL,NULL,NULL,sd2);
 CALL proyectos.cambiar_estado_solicitud(sd2,'en_evaluacion','Revisión');
 CALL proyectos.aprobar_solicitud(sd2,'Proyecto alternativo','Prueba de integridad','Alcance independiente',100000,0,'COP',NULL,proy2);
 CALL proyectos.asignar_miembro(proy2,empleado,'Responsable',true,'Asignación',miembro2);
 PERFORM pg_temp.rechaza(format('CALL proyectos.registrar_avance(%s,%s,50,''Reporte ajeno'',NULL,NULL)',etapa,miembro2),'23514','P07','El autor y la etapa pertenecen al mismo proyecto');
 -- Revocación real: la cuenta pierde habilitación; preservar evidencia, pausar y cancelar agenda.
 UPDATE identidad.usuario u SET estado='bloqueado' WHERE u.id=usuario;
 SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;
 PERFORM pg_temp.comprobar((SELECT estado='suspendido' FROM proyectos.proyecto WHERE id=proy)
   AND (SELECT termina_en IS NOT NULL FROM proyectos.miembro_proyecto WHERE id=miembro)
   AND NOT EXISTS(SELECT 1 FROM servicios.cita_servicio WHERE id IN(cita2,cita3) AND estado='confirmada'),'P08','Revocar cuenta suspende proyecto y cancela futuras citas sin borrar historia');
 PERFORM pg_temp.comprobar((SELECT count(*) FROM proyectos.avance_proyecto a JOIN proyectos.etapa_proyecto e ON e.id=a.etapa_proyecto_id WHERE e.proyecto_id=proy)=2,'P09','La revocación conserva reportes históricos de miembros retirados');
 PERFORM set_config('app.usuario_id','',true);
 SET CONSTRAINTS ALL IMMEDIATE;
END $pruebas$;
SELECT codigo,resultado FROM pg_temp.pruebas_servicios ORDER BY codigo;
SELECT count(*) AS casos_correctos FROM pg_temp.pruebas_servicios;
ROLLBACK;
