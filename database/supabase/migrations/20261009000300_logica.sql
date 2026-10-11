-- Systemic Tech & Support — migración para Supabase generada por herramientas/generar_supabase.py
-- Origen: módulos locales verificados en PostgreSQL 18.3 y 17.6. No editar a mano: regenerar.
-- Compatible con Supabase CLI (supabase db push / db reset) y con el SQL Editor (pegar completo).
-- 3/6. Programación: identidad, comercial, servicios/proyectos, comunicación, auditoría.
DO $precondiciones$
BEGIN
  IF current_setting('server_version_num')::integer < 170000 THEN
    RAISE EXCEPTION 'Systemic Tech requiere PostgreSQL 17 o posterior (verificado en 17.6 y 18.3)';
  END IF;
  IF current_database() <> 'postgres' THEN
    RAISE EXCEPTION 'En Supabase la base de datos debe ser postgres; conectado a %', current_database();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'st_owner') THEN
    RAISE EXCEPTION 'Aplique antes la migración de roles (..._roles_systemic.sql)';
  END IF;
END
$precondiciones$;

SET ROLE st_owner;
SET search_path = pg_catalog, public;

-- MÓDULO 10_identidad
-- Identidad y autorización para un backend confiable. Nunca exponer credenciales SQL al navegador.

CREATE FUNCTION identidad.es_dba() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
 SELECT coalesce((SELECT rolsuper FROM pg_roles WHERE rolname=session_user),false)
     OR pg_has_role(session_user,'st_dba','MEMBER')
$$;

CREATE FUNCTION identidad.bloquear_operacion() RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF current_setting('transaction_isolation') <> 'read committed' THEN
   RAISE EXCEPTION 'Las operaciones de esta versión requieren READ COMMITTED' USING ERRCODE='25001';
 END IF;
 PERFORM pg_advisory_xact_lock(20260913,1);
 IF nullif(current_setting('app.correlacion_id',true),'') IS NULL THEN
   PERFORM set_config('app.correlacion_id',gen_random_uuid()::text,true);
 END IF;
END $$;

CREATE FUNCTION identidad.acceso_invitado_actual() RETURNS bigint
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE token text:=nullif(current_setting('app.invitado_token',true),''); r bigint;
BEGIN
 IF token IS NULL OR length(token)<32 OR length(token)>512 THEN RETURN NULL; END IF;
 SELECT a.id INTO r FROM identidad.acceso_invitado a JOIN identidad.persona p ON p.id=a.persona_id
 WHERE a.token_hash=pg_catalog.sha256(convert_to(token,'UTF8')) AND a.revocado_en IS NULL
   AND a.verificado_en<=clock_timestamp() AND a.emitido_en<=clock_timestamp()
   AND a.vence_en>clock_timestamp() AND p.activo;
 RETURN r;
END $$;

CREATE FUNCTION identidad.actor_persona_actual() RETURNS bigint
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE u text:=nullif(current_setting('app.usuario_id',true),''); r bigint;
BEGIN
 IF u IS NOT NULL THEN
   IF u !~ '^[0-9]+$' THEN RAISE EXCEPTION 'Contexto de usuario inválido' USING ERRCODE='28000'; END IF;
   SELECT x.persona_id INTO r FROM identidad.usuario x JOIN identidad.persona p ON p.id=x.persona_id WHERE x.id=u::bigint AND x.estado='activo' AND p.activo;
 ELSE
   SELECT persona_id INTO r FROM identidad.acceso_invitado WHERE id=identidad.acceso_invitado_actual();
 END IF;
 RETURN r;
END $$;

CREATE FUNCTION identidad.actor_sistema_actual() RETURNS text
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF identidad.actor_persona_actual() IS NOT NULL THEN RETURN NULL; END IF;
 IF identidad.es_dba() THEN RETURN 'dba:'||session_user; END IF;
 IF pg_has_role(session_user,'st_worker','MEMBER') THEN RETURN 'worker:'||session_user; END IF;
 RETURN 'backend:sin_cuenta';
END $$;

CREATE FUNCTION identidad.persona_titular(p_recurso text,p_id bigint) RETURNS bigint
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE r bigint; j jsonb; k text;
BEGIN
 IF p_id IS NULL THEN RETURN NULL; END IF;
 CASE p_recurso
 WHEN 'persona' THEN SELECT id INTO r FROM identidad.persona WHERE id=p_id;
 WHEN 'usuario' THEN SELECT persona_id INTO r FROM identidad.usuario WHERE id=p_id;
 WHEN 'cliente' THEN SELECT persona_id INTO r FROM identidad.cliente WHERE id=p_id;
 WHEN 'empleado' THEN SELECT persona_id INTO r FROM identidad.empleado WHERE id=p_id;
 WHEN 'pedido' THEN SELECT c.persona_id INTO r FROM comercial.pedido p JOIN identidad.cliente c ON c.id=p.cliente_id WHERE p.id=p_id;
 WHEN 'detalle_pedido' THEN SELECT identidad.persona_titular('pedido',pedido_id) INTO r FROM comercial.detalle_pedido WHERE id=p_id;
 WHEN 'carrito' THEN SELECT c.persona_id INTO r FROM comercial.carrito p JOIN identidad.cliente c ON c.id=p.cliente_id WHERE p.id=p_id;
 WHEN 'solicitud_cotizacion' THEN SELECT persona_id INTO r FROM comercial.solicitud_cotizacion WHERE id=p_id;
 WHEN 'cotizacion' THEN SELECT coalesce(c.persona_directa_id,s.persona_id) INTO r FROM comercial.cotizacion c LEFT JOIN comercial.solicitud_cotizacion s ON s.id=c.solicitud_cotizacion_id WHERE c.id=p_id;
 WHEN 'version_cotizacion' THEN SELECT identidad.persona_titular('cotizacion',cotizacion_id) INTO r FROM comercial.version_cotizacion WHERE id=p_id;
 WHEN 'detalle_cotizacion' THEN SELECT identidad.persona_titular('version_cotizacion',version_cotizacion_id) INTO r FROM comercial.detalle_cotizacion WHERE id=p_id;
 WHEN 'equipo_cliente' THEN SELECT c.persona_id INTO r FROM servicios.equipo_cliente e JOIN identidad.cliente c ON c.id=e.cliente_id WHERE e.id=p_id;
 WHEN 'solicitud_servicio' THEN SELECT c.persona_id INTO r FROM servicios.solicitud_servicio s JOIN identidad.cliente c ON c.id=s.cliente_id WHERE s.id=p_id;
 WHEN 'orden_servicio' THEN SELECT identidad.persona_titular('solicitud_servicio',solicitud_servicio_id) INTO r FROM servicios.orden_servicio WHERE id=p_id;
 WHEN 'solicitud_desarrollo' THEN SELECT c.persona_id INTO r FROM proyectos.solicitud_desarrollo s JOIN identidad.cliente c ON c.id=s.cliente_id WHERE s.id=p_id;
 WHEN 'proyecto' THEN SELECT identidad.persona_titular('solicitud_desarrollo',solicitud_desarrollo_id) INTO r FROM proyectos.proyecto WHERE id=p_id;
 WHEN 'etapa_proyecto' THEN SELECT identidad.persona_titular('proyecto',proyecto_id) INTO r FROM proyectos.etapa_proyecto WHERE id=p_id;
 WHEN 'factura' THEN
   SELECT CASE WHEN pedido_id IS NOT NULL THEN identidad.persona_titular('pedido',pedido_id)
     WHEN orden_servicio_id IS NOT NULL THEN identidad.persona_titular('orden_servicio',orden_servicio_id)
     ELSE identidad.persona_titular('proyecto',proyecto_id) END INTO r FROM comercial.factura WHERE id=p_id;
 WHEN 'notificacion' THEN SELECT u.persona_id INTO r FROM comunicacion.notificacion n JOIN identidad.usuario u ON u.id=n.destinatario_usuario_id WHERE n.id=p_id;
 WHEN 'mensaje' THEN SELECT identidad.persona_titular('conversacion',a.conversacion_id) INTO r FROM comunicacion.mensaje m JOIN comunicacion.participante_conversacion a ON a.id=m.autor_participante_id WHERE m.id=p_id;
 WHEN 'conversacion' THEN
   SELECT to_jsonb(c) INTO j FROM comunicacion.conversacion c WHERE c.id=p_id;
   FOREACH k IN ARRAY ARRAY['pedido','solicitud_servicio','orden_servicio','solicitud_cotizacion','cotizacion','solicitud_desarrollo','proyecto'] LOOP
     IF j->>(k||'_id') IS NOT NULL THEN RETURN identidad.persona_titular(k,(j->>(k||'_id'))::bigint); END IF;
   END LOOP;
 ELSE RETURN NULL;
 END CASE;
 RETURN r;
END $$;

CREATE FUNCTION identidad.persona_tiene_permiso(p_persona bigint,p_recurso text,p_accion text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM identidad.usuario u JOIN identidad.persona pe ON pe.id=u.persona_id
 JOIN identidad.usuario_rol ur ON ur.usuario_id=u.id JOIN identidad.rol r ON r.id=ur.rol_id
 JOIN identidad.rol_permiso rp ON rp.rol_id=r.id JOIN identidad.permiso p ON p.id=rp.permiso_id
 WHERE u.persona_id=p_persona AND u.estado='activo' AND pe.activo AND r.activo
 AND ur.inicia_en<=statement_timestamp() AND (ur.termina_en IS NULL OR ur.termina_en>statement_timestamp())
 AND p.recurso=p_recurso AND (p.accion=p_accion OR p.accion='gestionar'))
$$;

CREATE FUNCTION identidad.empleado_habilitado(p_empleado bigint,p_recurso text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM identidad.empleado e WHERE e.id=p_empleado AND e.activo
 AND identidad.persona_tiene_permiso(e.persona_id,p_recurso,'gestionar'))
$$;

CREATE FUNCTION identidad.persona_puede_acceder(p_persona bigint,p_recurso text,p_registro_id bigint,p_accion text DEFAULT 'leer') RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE j jsonb; k text;
BEGIN
 IF p_persona IS NULL OR NOT EXISTS(SELECT 1 FROM identidad.persona WHERE id=p_persona AND activo) THEN RETURN false; END IF;
 IF identidad.persona_tiene_permiso(p_persona,p_recurso,p_accion) THEN RETURN true; END IF;
 IF p_accion NOT IN ('leer','editar','crear','responder','calificar') THEN RETURN false; END IF;
 IF p_recurso='conversacion' THEN
   IF NOT EXISTS(SELECT 1 FROM comunicacion.participante_conversacion WHERE conversacion_id=p_registro_id AND persona_id=p_persona AND salio_en IS NULL) THEN RETURN false; END IF;
   SELECT to_jsonb(c) INTO j FROM comunicacion.conversacion c WHERE c.id=p_registro_id;
   FOREACH k IN ARRAY ARRAY['pedido','solicitud_servicio','orden_servicio','solicitud_cotizacion','cotizacion','solicitud_desarrollo','proyecto'] LOOP
     IF j->>(k||'_id') IS NOT NULL THEN RETURN identidad.persona_puede_acceder(p_persona,k,(j->>(k||'_id'))::bigint,'leer'); END IF;
   END LOOP;
   RETURN true;
 ELSIF p_recurso='mensaje' THEN
   RETURN EXISTS(SELECT 1 FROM comunicacion.mensaje m JOIN comunicacion.participante_conversacion p ON p.id=m.autor_participante_id
     WHERE m.id=p_registro_id AND identidad.persona_puede_acceder(p_persona,'conversacion',p.conversacion_id,'leer'));
 END IF;
 IF p_registro_id IS NOT NULL AND identidad.persona_titular(p_recurso,p_registro_id)=p_persona THEN
   RETURN p_accion='leer'
      OR (p_accion='responder' AND p_recurso IN ('cotizacion','version_cotizacion'))
      OR (p_accion='calificar' AND p_recurso='orden_servicio')
      OR (p_accion='editar' AND p_recurso IN ('persona','usuario','cliente','carrito','pedido','solicitud_servicio','solicitud_cotizacion','solicitud_desarrollo'))
      OR (p_accion='crear' AND p_recurso='cliente');
 END IF;
 RETURN false;
END $$;

CREATE FUNCTION identidad.puede_acceder(p_recurso text,p_registro_id bigint,p_accion text DEFAULT 'leer') RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE persona bigint; uid text:=nullif(current_setting('app.usuario_id',true),''); a identidad.acceso_invitado%ROWTYPE; k text; j jsonb;
BEGIN
 IF identidad.es_dba() THEN RETURN true; END IF;
 IF pg_has_role(session_user,'st_worker','MEMBER') AND p_recurso IN ('archivo','notificacion','acceso_invitado','sesion','recuperacion_acceso') THEN RETURN true; END IF;
 IF uid IS NOT NULL THEN
   IF uid !~ '^[0-9]+$' THEN RETURN false; END IF;
   SELECT u.persona_id INTO persona FROM identidad.usuario u JOIN identidad.persona p ON p.id=u.persona_id
   WHERE u.id=uid::bigint AND u.estado='activo' AND p.activo;
   RETURN coalesce(identidad.persona_puede_acceder(persona,p_recurso,p_registro_id,p_accion),false);
 END IF;
 SELECT * INTO a FROM identidad.acceso_invitado WHERE id=identidad.acceso_invitado_actual();
 IF NOT FOUND THEN RETURN false; END IF;
 j:=to_jsonb(a);
 IF p_recurso='version_cotizacion' THEN
   IF a.version_cotizacion_id IS DISTINCT FROM p_registro_id THEN RETURN false; END IF;
   k:='cotizacion';
 ELSE k:=p_recurso;
 END IF;
 IF NOT (k=ANY(ARRAY['pedido','solicitud_servicio','orden_servicio','solicitud_cotizacion','cotizacion','solicitud_desarrollo','proyecto','factura','conversacion'])) THEN RETURN false; END IF;
 IF p_recurso<>'version_cotizacion' AND (j->>(k||'_id'))::bigint IS DISTINCT FROM p_registro_id THEN RETURN false; END IF;
 IF p_accion='responder' AND a.version_cotizacion_id IS NULL THEN RETURN false; END IF;
 RETURN EXISTS(SELECT 1 FROM identidad.acceso_invitado_permiso ap JOIN identidad.permiso p ON p.id=ap.permiso_id
 WHERE ap.acceso_invitado_id=a.id AND p.recurso=k AND p.accion=p_accion)
 AND identidad.persona_puede_acceder(a.persona_id,k,(j->>(k||'_id'))::bigint,p_accion);
END $$;

CREATE FUNCTION identidad.exigir_permiso(p_recurso text,p_accion text,p_registro_id bigint DEFAULT NULL) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF identidad.es_dba() THEN RETURN; END IF;
 -- El rol SQL del backend es privado y confiable. Las altas públicas se validan en sus APIs.
 IF p_registro_id IS NULL AND p_accion='crear' AND p_recurso IN ('usuario','persona','cliente','pedido','carrito','solicitud_servicio','solicitud_desarrollo','solicitud_cotizacion','conversacion','archivo')
    AND pg_has_role(session_user,'st_app','MEMBER') THEN RETURN; END IF;
 IF NOT identidad.puede_acceder(p_recurso,p_registro_id,p_accion) THEN
   RAISE EXCEPTION 'Acceso no autorizado a %.%',p_recurso,p_accion USING ERRCODE='42501';
 END IF;
END $$;

CREATE PROCEDURE identidad.registrar_cliente_invitado(p_nombres text,p_apellidos text,p_correo text,p_telefono text,INOUT p_cliente_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE pid bigint;
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('cliente','crear');
 IF p_cliente_id IS NOT NULL THEN RAISE EXCEPTION 'Un alta nueva no reutiliza un cliente recibido del navegador'; END IF;
 INSERT INTO identidad.persona(nombres,apellidos,correo_contacto,telefono) VALUES(p_nombres,p_apellidos,p_correo,p_telefono) RETURNING id INTO pid;
 INSERT INTO identidad.cliente(persona_id,codigo) VALUES(pid,'CLI-'||gen_random_uuid()) RETURNING id INTO p_cliente_id;
END $$;

CREATE PROCEDURE identidad.registrar_usuario(p_nombres text,p_apellidos text,p_correo text,p_telefono text,p_origen text,p_emisor text,p_sujeto text,p_password_hash text,INOUT p_usuario_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE pid bigint;
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('usuario','crear');
 IF p_usuario_id IS NOT NULL THEN RAISE EXCEPTION 'El registro de cuenta crea una identidad nueva'; END IF;
 IF p_origen='local' AND (p_password_hash IS NULL OR p_password_hash !~ '^\$argon2id\$v=19\$') THEN RAISE EXCEPTION 'El backend debe aportar un hash Argon2id, nunca la contraseña'; END IF;
 IF p_origen='externo' AND p_password_hash IS NOT NULL THEN RAISE EXCEPTION 'Una cuenta externa no duplica contraseña'; END IF;
 INSERT INTO identidad.persona(nombres,apellidos,correo_contacto,telefono) VALUES(p_nombres,p_apellidos,lower(btrim(p_correo)),p_telefono) RETURNING id INTO pid;
 INSERT INTO identidad.usuario(persona_id,correo_acceso,origen_auth,emisor_externo,sujeto_externo)
 VALUES(pid,lower(btrim(p_correo)),p_origen,p_emisor,p_sujeto) RETURNING id INTO p_usuario_id;
 INSERT INTO identidad.cliente(persona_id,codigo) VALUES(pid,'CLI-'||gen_random_uuid());
 IF p_origen='local' THEN INSERT INTO identidad.credencial(usuario_id,password_hash) VALUES(p_usuario_id,p_password_hash); END IF;
END $$;

CREATE PROCEDURE identidad.actualizar_perfil(p_persona_id bigint,p_nombres text,p_apellidos text,p_correo text,p_telefono text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('persona','editar',p_persona_id);
 UPDATE identidad.persona SET nombres=p_nombres,apellidos=p_apellidos,correo_contacto=p_correo,telefono=p_telefono WHERE id=p_persona_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Persona inexistente'; END IF;
END $$;

CREATE PROCEDURE identidad.administrar_registro(p_entidad text,p_datos jsonb,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE destino text; recurso text; permitidos text[]; clave text; cols text; vals text; cambios text;
BEGIN
 PERFORM identidad.bloquear_operacion();
 CASE p_entidad
 WHEN 'persona' THEN destino:='identidad.persona';recurso:='cliente';permitidos:=ARRAY['nombres','apellidos','correo_contacto','telefono','activo'];
 WHEN 'cliente' THEN destino:='identidad.cliente';recurso:='cliente';permitidos:=ARRAY['persona_id','codigo','observaciones','activo'];
 WHEN 'empleado' THEN destino:='identidad.empleado';recurso:='empleado';permitidos:=ARRAY['persona_id','codigo','cargo','fecha_vinculacion','activo'];
 WHEN 'usuario' THEN destino:='identidad.usuario';recurso:='usuario';permitidos:=ARRAY['persona_id','correo_acceso','estado','origen_auth','emisor_externo','sujeto_externo','verificado_en'];
 WHEN 'rol' THEN destino:='identidad.rol';recurso:='rol';permitidos:=ARRAY['codigo','nombre','descripcion','activo'];
 WHEN 'permiso' THEN destino:='identidad.permiso';recurso:='rol';permitidos:=ARRAY['codigo','recurso','accion','descripcion'];
 WHEN 'categoria' THEN destino:='inventario.categoria';recurso:='producto';permitidos:=ARRAY['nombre','descripcion','activa'];
 WHEN 'servicio_ofrecido' THEN destino:='servicios.servicio_ofrecido';recurso:='orden_servicio';permitidos:=ARRAY['codigo','nombre','descripcion','modalidad','duracion_estimada_min','precio_referencia','moneda','publicado'];
 WHEN 'producto_imagen' THEN destino:='inventario.producto_imagen';recurso:='producto';permitidos:=ARRAY['producto_id','archivo_id','orden','texto_alternativo','principal'];
 ELSE RAISE EXCEPTION 'Entidad administrativa no admitida' USING ERRCODE='22023'; END CASE;
 PERFORM identidad.exigir_permiso(recurso,'gestionar');
 IF jsonb_typeof(p_datos)<>'object' OR p_datos='{}'::jsonb THEN RAISE EXCEPTION 'Se requiere objeto de atributos'; END IF;
 FOR clave IN SELECT jsonb_object_keys(p_datos) LOOP
   IF NOT clave=ANY(permitidos) THEN RAISE EXCEPTION 'Atributo no permitido: %',clave USING ERRCODE='22023'; END IF;
   IF p_id IS NOT NULL AND clave IN ('persona_id','origen_auth','emisor_externo','sujeto_externo','recurso','accion') THEN RAISE EXCEPTION 'Referencia o identidad inmutable: %',clave; END IF;
 END LOOP;
 SELECT string_agg(format('%I',k),',' ORDER BY k),string_agg(format('r.%I',k),',' ORDER BY k),string_agg(format('%I=r.%I',k,k),',' ORDER BY k)
 INTO cols,vals,cambios FROM jsonb_object_keys(p_datos) k;
 IF p_id IS NULL THEN
   EXECUTE format('INSERT INTO %s (%s) SELECT %s FROM jsonb_populate_record(NULL::%s,$1) r RETURNING id',destino,cols,vals,destino) INTO p_id USING p_datos;
 ELSE
   EXECUTE format('UPDATE %s t SET %s FROM jsonb_populate_record(NULL::%s,$1) r WHERE t.id=$2 RETURNING t.id',destino,cambios,destino) INTO p_id USING p_datos,p_id;
   IF p_id IS NULL THEN RAISE EXCEPTION 'Registro no encontrado'; END IF;
 END IF;
END $$;

CREATE PROCEDURE identidad.asignar_rol(p_usuario bigint,p_rol bigint,p_hasta timestamptz DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('rol','gestionar');
 INSERT INTO identidad.usuario_rol(usuario_id,rol_id,termina_en,actor_persona_id,actor_sistema)
 VALUES(p_usuario,p_rol,p_hasta,identidad.actor_persona_actual(),identidad.actor_sistema_actual());
END $$;

CREATE PROCEDURE identidad.revocar_rol(p_asignacion bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('rol','gestionar');
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Debe indicar motivo'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE identidad.usuario_rol SET termina_en=greatest(clock_timestamp(),inicia_en+INTERVAL '1 microsecond') WHERE id=p_asignacion AND (termina_en IS NULL OR termina_en>clock_timestamp());
 IF NOT FOUND THEN RAISE EXCEPTION 'Asignación inexistente o ya revocada'; END IF;
END $$;

CREATE PROCEDURE identidad.configurar_permiso_rol(p_rol bigint,p_permiso bigint,p_conceder boolean,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('rol','gestionar');
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Debe indicar motivo'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 IF p_conceder THEN
   INSERT INTO identidad.rol_permiso(rol_id,permiso_id,actor_persona_id,actor_sistema)
   VALUES(p_rol,p_permiso,identidad.actor_persona_actual(),identidad.actor_sistema_actual()) ON CONFLICT DO NOTHING;
 ELSE DELETE FROM identidad.rol_permiso WHERE rol_id=p_rol AND permiso_id=p_permiso; END IF;
END $$;

CREATE PROCEDURE identidad.emitir_acceso_invitado(p_persona bigint,p_recurso text,p_registro bigint,p_version bigint,p_medio text,p_destino text,p_verificado timestamptz,p_vence timestamptz,p_token text,p_acciones text[],INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE col text; acc text; per bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('acceso_invitado','gestionar');
 IF p_id IS NOT NULL OR p_token IS NULL OR length(p_token)<43 OR length(p_token)>512 THEN RAISE EXCEPTION 'Alta nueva exige token aleatorio de al menos 256 bits generado por backend'; END IF;
 IF NOT p_recurso=ANY(ARRAY['pedido','solicitud_servicio','orden_servicio','solicitud_cotizacion','cotizacion','solicitud_desarrollo','proyecto','factura','conversacion']) THEN RAISE EXCEPTION 'Contexto invitado no admitido'; END IF;
 IF p_verificado>clock_timestamp() OR p_vence<=clock_timestamp() OR p_vence>clock_timestamp()+INTERVAL '30 days' THEN RAISE EXCEPTION 'Vigencia inválida: la concesión requiere verificación previa y máximo 30 días'; END IF;
 IF NOT identidad.persona_puede_acceder(p_persona,p_recurso,p_registro,'leer') THEN RAISE EXCEPTION 'Persona no titular ni participante autorizado'; END IF;
 IF p_version IS NOT NULL AND (p_recurso<>'cotizacion' OR NOT EXISTS(SELECT 1 FROM comercial.version_cotizacion WHERE id=p_version AND cotizacion_id=p_registro)) THEN RAISE EXCEPTION 'Versión ajena al contexto'; END IF;
 IF p_acciones IS NULL OR cardinality(p_acciones)=0 THEN RAISE EXCEPTION 'Concesión sin acciones'; END IF;
 col:=p_recurso||'_id';
 EXECUTE format('INSERT INTO identidad.acceso_invitado(persona_id,token_hash,medio_verificacion,destino_verificado,verificado_en,emitido_en,vence_en,version_cotizacion_id,%I) VALUES($1,pg_catalog.sha256(convert_to($2,''UTF8'')),$3,$4,$5,clock_timestamp(),$6,$7,$8) RETURNING id',col)
 INTO p_id USING p_persona,p_token,p_medio,p_destino,p_verificado,p_vence,p_version,p_registro;
 FOREACH acc IN ARRAY p_acciones LOOP
   IF acc<>'leer' AND NOT(acc='responder' AND p_recurso='cotizacion' AND p_version IS NOT NULL) AND NOT(acc='calificar' AND p_recurso='orden_servicio') AND NOT(acc='editar' AND p_recurso IN ('pedido','solicitud_servicio','solicitud_cotizacion','solicitud_desarrollo')) THEN RAISE EXCEPTION 'Acción de invitado no admitida'; END IF;
   SELECT id INTO per FROM identidad.permiso WHERE recurso=p_recurso AND accion=acc;
   IF per IS NULL THEN RAISE EXCEPTION 'Acción sin permiso configurado'; END IF;
   INSERT INTO identidad.acceso_invitado_permiso VALUES(p_id,per) ON CONFLICT DO NOTHING;
 END LOOP;
END $$;

CREATE PROCEDURE identidad.revocar_acceso_invitado(p_id bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('acceso_invitado','gestionar');
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Debe indicar motivo'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE identidad.acceso_invitado SET revocado_en=clock_timestamp() WHERE id=p_id AND revocado_en IS NULL;
END $$;

CREATE PROCEDURE identidad.registrar_sesion(p_usuario bigint,p_refresh_hash bytea,p_vence timestamptz,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('usuario','leer',p_usuario);
 IF p_id IS NOT NULL OR p_vence<=clock_timestamp() OR NOT EXISTS(SELECT 1 FROM identidad.usuario WHERE id=p_usuario AND estado='activo' AND origen_auth='local') THEN RAISE EXCEPTION 'Sesión local inválida'; END IF;
 INSERT INTO identidad.sesion(usuario_id,refresh_hash,vence_en) VALUES(p_usuario,p_refresh_hash,p_vence) RETURNING id INTO p_id;
END $$;

CREATE PROCEDURE identidad.cerrar_sesion(p_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE u bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();SELECT usuario_id INTO u FROM identidad.sesion WHERE id=p_id;
 IF u IS NULL THEN RAISE EXCEPTION 'Sesión inexistente'; END IF;
 PERFORM identidad.exigir_permiso('usuario','leer',u);
 UPDATE identidad.sesion SET revocada_en=clock_timestamp() WHERE id=p_id AND revocada_en IS NULL;
END $$;

CREATE PROCEDURE identidad.preparar_recuperacion(p_usuario bigint,p_hash bytea,p_vence timestamptz,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('recuperacion_acceso','gestionar');
 IF p_id IS NOT NULL OR p_vence<=clock_timestamp() OR p_vence>clock_timestamp()+INTERVAL '1 hour' THEN RAISE EXCEPTION 'Recuperación exige vigencia máxima de una hora'; END IF;
 IF NOT EXISTS(SELECT 1 FROM identidad.usuario WHERE id=p_usuario AND origen_auth='local' AND estado IN ('activo','pendiente')) THEN RAISE EXCEPTION 'Cuenta no recuperable'; END IF;
 INSERT INTO identidad.recuperacion_acceso(usuario_id,token_hash,vence_en) VALUES(p_usuario,p_hash,p_vence) RETURNING id INTO p_id;
END $$;

CREATE PROCEDURE identidad.consumir_recuperacion(p_token text,p_hash_argon2 text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE r identidad.recuperacion_acceso%ROWTYPE;
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('recuperacion_acceso','gestionar');
 IF p_hash_argon2 IS NULL OR p_hash_argon2 !~ '^\$argon2id\$v=19\$' THEN RAISE EXCEPTION 'El backend debe aportar hash Argon2id válido'; END IF;
 SELECT * INTO r FROM identidad.recuperacion_acceso WHERE token_hash=pg_catalog.sha256(convert_to(p_token,'UTF8')) AND consumida_en IS NULL AND vence_en>clock_timestamp() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Token inválido, vencido o consumido' USING ERRCODE='28000'; END IF;
 UPDATE identidad.credencial SET password_hash=p_hash_argon2,cambiada_en=clock_timestamp() WHERE usuario_id=r.usuario_id;
 UPDATE identidad.recuperacion_acceso SET consumida_en=clock_timestamp() WHERE usuario_id=r.usuario_id AND consumida_en IS NULL;
 UPDATE identidad.sesion SET revocada_en=clock_timestamp() WHERE usuario_id=r.usuario_id AND revocada_en IS NULL;
END $$;


-- MÓDULO 20_comercial
-- SYSTEMIC TECH & SUPPORT. T06–T09: inventario, pedidos, cotizaciones y factura.
-- Se instala después de los auxiliares de identidad y antes de conceder EXECUTE.
-- No COMMIT dentro de procedimientos: cada CALL es atómico con su llamador.
SET search_path = pg_catalog, pg_temp;

CREATE OR REPLACE FUNCTION comercial.persona_cotizacion(p_id bigint)
RETURNS bigint LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
 SELECT coalesce(c.persona_directa_id,s.persona_id)
 FROM comercial.cotizacion c LEFT JOIN comercial.solicitud_cotizacion s ON s.id=c.solicitud_cotizacion_id
 WHERE c.id=p_id
$$;

CREATE OR REPLACE FUNCTION inventario.existencia_disponible(p_producto bigint)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
 SELECT i.saldo-coalesce((SELECT sum(d.cantidad) FROM inventario.reserva_inventario r
 JOIN comercial.detalle_pedido d ON d.id=r.detalle_pedido_id
 WHERE d.producto_id=i.producto_id AND r.estado='activa'),0)
 FROM inventario.inventario i WHERE i.producto_id=p_producto
$$;

CREATE OR REPLACE FUNCTION comercial.total_pedido(p_id bigint)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
 SELECT coalesce(sum(d.total),0) FROM comercial.detalle_pedido d WHERE d.pedido_id=p_id
$$;
CREATE OR REPLACE FUNCTION comercial.total_cotizacion(p_version bigint)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
 SELECT coalesce(sum(d.total),0) FROM comercial.detalle_cotizacion d WHERE d.version_cotizacion_id=p_version
$$;
CREATE OR REPLACE FUNCTION comercial.total_factura(p_id bigint)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
 SELECT coalesce(sum(d.total),0) FROM comercial.detalle_factura d WHERE d.factura_id=p_id
$$;

-- Función pura: distribución acumulativa que conserva el residual de centavos.
CREATE OR REPLACE FUNCTION comercial.repartir_importes(
 p_q numeric,p_b numeric,p_d numeric,p_i numeric,p_precio numeric,p_tasa numeric,
 p_usado_q numeric,p_usado_b numeric,p_usado_d numeric,p_usado_i numeric,p_nueva_q numeric)
RETURNS TABLE(descuento numeric,ajuste_base numeric,ajuste_impuesto numeric)
LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_b numeric; v_i numeric;
BEGIN
 IF p_q<=0 OR p_nueva_q<=0 OR p_usado_q+p_nueva_q>p_q THEN
  RAISE EXCEPTION 'Cantidad aplicada supera la cantidad autorizada';
 END IF;
 descuento:=round(p_d*(p_usado_q+p_nueva_q)/p_q,2)-p_usado_d;
 v_b:=round(p_b*(p_usado_q+p_nueva_q)/p_q,2)-p_usado_b;
 v_i:=round(p_i*(p_usado_q+p_nueva_q)/p_q,2)-p_usado_i;
 IF descuento<0 OR v_b<0 OR v_i<0 OR p_usado_b+v_b>p_b OR p_usado_d+descuento>p_d OR p_usado_i+v_i>p_i THEN
  RAISE EXCEPTION 'La aplicación no conserva importes no negativos y techo; requiere revisión comercial';
 END IF;
 ajuste_base:=v_b-(round(p_nueva_q*p_precio,2)-descuento);
 ajuste_impuesto:=v_i-round(v_b*p_tasa,2);
 RETURN NEXT;
END $$;

-- Los guards obtienen el mismo bloqueo global antes de inspeccionar padres.
-- Las ACL cierran DML crítico a la aplicación; los guards también frenan DML del propietario accidental.
CREATE OR REPLACE FUNCTION comercial.proteger_fila()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_estado text; v_id bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();
 IF TG_OP='UPDATE' AND TG_TABLE_NAME NOT IN ('detalle_carrito','reserva_inventario','inventario')
 AND to_jsonb(NEW)->'id' IS DISTINCT FROM to_jsonb(OLD)->'id' THEN
  RAISE EXCEPTION 'No se reasigna la identidad de una fila';
 END IF;
 IF TG_TABLE_NAME='movimiento_inventario' THEN
  IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'El libro de movimientos es inmutable; registre una compensación'; END IF;
  NEW.actor_persona_id:=identidad.actor_persona_actual(); NEW.actor_sistema:=identidad.actor_sistema_actual();
 ELSIF TG_TABLE_NAME='producto' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Los productos se desactivan, no se eliminan'; END IF;
  IF TG_OP='UPDATE' AND NEW.unidad IS DISTINCT FROM OLD.unidad AND
  (EXISTS(SELECT 1 FROM inventario.movimiento_inventario WHERE producto_id=OLD.id)
   OR EXISTS(SELECT 1 FROM comercial.detalle_pedido WHERE producto_id=OLD.id)
   OR EXISTS(SELECT 1 FROM comercial.detalle_cotizacion WHERE producto_id=OLD.id)) THEN
   RAISE EXCEPTION 'Unidad histórica no modificable; cree otro producto';
  END IF;
 ELSIF TG_TABLE_NAME='reserva_inventario' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Una reserva se cierra y conserva'; END IF;
  IF TG_OP='UPDATE' AND (OLD.estado<>'activa' OR NEW.estado='activa'
     OR NEW.detalle_pedido_id<>OLD.detalle_pedido_id OR NEW.creada_en<>OLD.creada_en) THEN
   RAISE EXCEPTION 'Reserva cerrada o cambio de identidad no permitido';
  END IF;
 ELSIF TG_TABLE_NAME='detalle_pedido' THEN
  v_id:=CASE WHEN TG_OP='DELETE' THEN OLD.pedido_id ELSE NEW.pedido_id END;
  SELECT estado INTO v_estado FROM comercial.pedido WHERE id=v_id FOR UPDATE;
  IF v_estado IS DISTINCT FROM 'borrador' THEN RAISE EXCEPTION 'Detalle de pedido confirmado es inmutable'; END IF;
  IF TG_OP='UPDATE' AND NEW.pedido_id<>OLD.pedido_id THEN RAISE EXCEPTION 'No se traslada una línea entre pedidos'; END IF;
 ELSIF TG_TABLE_NAME='pedido' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'El pedido se cancela y conserva'; END IF;
  IF TG_OP='UPDATE' AND OLD.estado<>'borrador' AND
   (to_jsonb(NEW)-ARRAY['estado','updated_at','completado_en','cancelado_en','motivo_cancelacion']) IS DISTINCT FROM
   (to_jsonb(OLD)-ARRAY['estado','updated_at','completado_en','cancelado_en','motivo_cancelacion']) THEN
   RAISE EXCEPTION 'Las condiciones del pedido quedaron congeladas';
  END IF;
 ELSIF TG_TABLE_NAME='detalle_cotizacion' THEN
  v_id:=CASE WHEN TG_OP='DELETE' THEN OLD.version_cotizacion_id ELSE NEW.version_cotizacion_id END;
  SELECT estado INTO v_estado FROM comercial.version_cotizacion WHERE id=v_id FOR UPDATE;
  IF v_estado IS DISTINCT FROM 'borrador' THEN RAISE EXCEPTION 'Una oferta enviada tiene líneas inmutables'; END IF;
  IF TG_OP='UPDATE' AND NEW.version_cotizacion_id<>OLD.version_cotizacion_id THEN RAISE EXCEPTION 'No se traslada una línea entre versiones'; END IF;
 ELSIF TG_TABLE_NAME='version_cotizacion' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Una versión se anula y conserva'; END IF;
  IF TG_OP='UPDATE' AND (NEW.cotizacion_id<>OLD.cotizacion_id OR NEW.numero_version<>OLD.numero_version) THEN
   RAISE EXCEPTION 'Identidad de versión inmutable';
  END IF;
  IF TG_OP='UPDATE' AND OLD.estado<>'borrador' AND
   (to_jsonb(NEW)-ARRAY['estado','updated_at','respondida_en','respondida_por_persona_id','evidencia_respuesta']) IS DISTINCT FROM
   (to_jsonb(OLD)-ARRAY['estado','updated_at','respondida_en','respondida_por_persona_id','evidencia_respuesta']) THEN
   RAISE EXCEPTION 'Contenido y vigencia de oferta enviada son inmutables';
  END IF;
 ELSIF TG_TABLE_NAME='cotizacion' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'La negociación se anula y conserva'; END IF;
  IF TG_OP='UPDATE' AND (NEW.numero<>OLD.numero OR NEW.solicitud_cotizacion_id IS DISTINCT FROM OLD.solicitud_cotizacion_id
     OR NEW.persona_directa_id IS DISTINCT FROM OLD.persona_directa_id) THEN RAISE EXCEPTION 'Titular de cotización inmutable'; END IF;
 ELSIF TG_TABLE_NAME='solicitud_cotizacion' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'La solicitud se cancela y conserva'; END IF;
  IF TG_OP='UPDATE' AND (NEW.persona_id<>OLD.persona_id OR NEW.contacto_nombre<>OLD.contacto_nombre
    OR NEW.contacto_correo IS DISTINCT FROM OLD.contacto_correo OR NEW.contacto_telefono IS DISTINCT FROM OLD.contacto_telefono) THEN
   RAISE EXCEPTION 'Titular y contacto recibido de solicitud son históricos';
  END IF;
 ELSIF TG_TABLE_NAME='detalle_factura' THEN
  v_id:=CASE WHEN TG_OP='DELETE' THEN OLD.factura_id ELSE NEW.factura_id END;
  SELECT estado INTO v_estado FROM comercial.factura WHERE id=v_id FOR UPDATE;
  IF v_estado IS DISTINCT FROM 'borrador' THEN RAISE EXCEPTION 'Detalle de factura emitida es inmutable'; END IF;
  IF TG_OP='UPDATE' AND NEW.factura_id<>OLD.factura_id THEN RAISE EXCEPTION 'No se traslada una línea entre facturas'; END IF;
 ELSIF TG_TABLE_NAME='factura' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'La factura se conserva incluso anulada'; END IF;
  IF TG_OP='UPDATE' AND OLD.estado<>'borrador' AND
   (to_jsonb(NEW)-ARRAY['estado','updated_at','anulada_en','motivo_anulacion']) IS DISTINCT FROM
   (to_jsonb(OLD)-ARRAY['estado','updated_at','anulada_en','motivo_anulacion']) THEN
   RAISE EXCEPTION 'La factura emitida es inmutable';
  END IF;
 ELSIF TG_TABLE_NAME='detalle_carrito' THEN
  v_id:=CASE WHEN TG_OP='DELETE' THEN OLD.carrito_id ELSE NEW.carrito_id END;
  SELECT estado INTO v_estado FROM comercial.carrito WHERE id=v_id FOR UPDATE;
  IF v_estado IS DISTINCT FROM 'abierto' THEN RAISE EXCEPTION 'Carrito cerrado'; END IF;
  IF TG_OP='UPDATE' AND (NEW.carrito_id<>OLD.carrito_id OR NEW.producto_id<>OLD.producto_id) THEN RAISE EXCEPTION 'Clave de detalle de carrito inmutable'; END IF;
 ELSIF TG_TABLE_NAME='carrito' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'El carrito se abandona y conserva'; END IF;
  IF TG_OP='UPDATE' AND OLD.estado<>'abierto' AND (to_jsonb(NEW)-'updated_at') IS DISTINCT FROM (to_jsonb(OLD)-'updated_at') THEN
   RAISE EXCEPTION 'Carrito cerrado inmutable';
  END IF;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION inventario.inicializar_saldo()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
 INSERT INTO inventario.inventario(producto_id,saldo) VALUES(NEW.id,0); RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION inventario.aplicar_movimiento()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
 UPDATE inventario.inventario SET saldo=saldo+NEW.delta,updated_at=clock_timestamp() WHERE producto_id=NEW.producto_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Producto sin fila de inventario'; END IF;
 RETURN NEW;
END $$;

-- Validación diferible: revisa el estado final, nunca la mitad de entrega/reserva.
CREATE OR REPLACE FUNCTION comercial.validar_integridad()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();
 IF EXISTS(SELECT 1 FROM inventario.producto p LEFT JOIN inventario.inventario i ON i.producto_id=p.id
  WHERE i.producto_id IS NULL OR i.saldo<>(SELECT coalesce(sum(m.delta),0) FROM inventario.movimiento_inventario m WHERE m.producto_id=p.id)
  OR i.saldo<(SELECT coalesce(sum(d.cantidad),0) FROM inventario.reserva_inventario r JOIN comercial.detalle_pedido d ON d.id=r.detalle_pedido_id WHERE d.producto_id=p.id AND r.estado='activa')) THEN
  RAISE EXCEPTION 'T06: saldo, libro de movimientos y reservas no concuerdan';
 END IF;
 IF EXISTS(SELECT 1 FROM inventario.movimiento_inventario m LEFT JOIN comercial.detalle_pedido d ON d.id=m.detalle_pedido_id
   LEFT JOIN comercial.pedido p ON p.id=d.pedido_id LEFT JOIN inventario.movimiento_inventario original ON original.id=m.compensa_movimiento_id
   WHERE (m.detalle_pedido_id IS NOT NULL AND (m.producto_id<>d.producto_id OR m.delta<>-d.cantidad OR m.tipo<>'salida' OR p.estado<>'completado'))
   OR (m.compensa_movimiento_id IS NOT NULL AND (m.producto_id<>original.producto_id OR m.delta*original.delta>=0))) THEN
  RAISE EXCEPTION 'T06: salida o compensación incoherente con su referencia';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.detalle_pedido d JOIN comercial.pedido p ON p.id=d.pedido_id
   LEFT JOIN inventario.reserva_inventario r ON r.detalle_pedido_id=d.id
   LEFT JOIN inventario.movimiento_inventario m ON m.detalle_pedido_id=d.id
   WHERE (p.estado IN ('confirmado','en_preparacion') AND r.estado IS DISTINCT FROM 'activa')
   OR (p.estado='completado' AND (r.estado IS DISTINCT FROM 'consumida' OR m.id IS NULL))
   OR (p.estado='cancelado' AND p.confirmado_en IS NOT NULL AND r.estado IS DISTINCT FROM 'liberada')
   OR (p.estado='borrador' AND r.detalle_pedido_id IS NOT NULL)
   OR (p.estado='cancelado' AND p.confirmado_en IS NULL AND r.detalle_pedido_id IS NOT NULL)
   OR (p.estado<>'completado' AND m.id IS NOT NULL)) THEN RAISE EXCEPTION 'T06: reserva/entrega no corresponde al estado del pedido'; END IF;
 IF EXISTS(SELECT 1 FROM comercial.pedido p LEFT JOIN comercial.carrito c ON c.id=p.carrito_id
   WHERE (p.carrito_id IS NOT NULL AND (c.cliente_id IS DISTINCT FROM p.cliente_id OR c.estado<>'convertido'))
   OR (p.estado IN ('confirmado','en_preparacion','completado') AND NOT EXISTS(SELECT 1 FROM comercial.detalle_pedido d WHERE d.pedido_id=p.id))
   OR (p.estado='cancelado' AND EXISTS(SELECT 1 FROM comercial.factura f WHERE f.pedido_id=p.id AND f.estado='emitida'))) THEN
  RAISE EXCEPTION 'T07: pedido vacío, carrito incompatible o cancelación con factura vigente';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.pedido p JOIN identidad.cliente c ON c.id=p.cliente_id
  LEFT JOIN comercial.version_cotizacion v ON v.id=p.version_cotizacion_id
  WHERE p.version_cotizacion_id IS NOT NULL AND (v.estado<>'aceptada' OR v.moneda<>p.moneda OR comercial.persona_cotizacion(v.cotizacion_id)<>c.persona_id)) THEN
  RAISE EXCEPTION 'T07: versión cotizada no aceptada o no corresponde al cliente/moneda';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.detalle_pedido d JOIN comercial.pedido p ON p.id=d.pedido_id
  LEFT JOIN comercial.detalle_cotizacion q ON q.id=d.detalle_cotizacion_id
  WHERE (p.version_cotizacion_id IS NULL AND (d.detalle_cotizacion_id IS NOT NULL OR d.ajuste_base<>0 OR d.ajuste_impuesto<>0))
   OR (p.version_cotizacion_id IS NOT NULL AND (q.id IS NULL OR q.version_cotizacion_id<>p.version_cotizacion_id OR q.clase<>'producto'
     OR q.producto_id<>d.producto_id OR q.descripcion<>d.descripcion OR q.unidad<>d.unidad OR q.precio_unitario<>d.precio_unitario OR q.tasa_impuesto<>d.tasa_impuesto))) THEN
  RAISE EXCEPTION 'T07: condiciones del detalle no corresponden a su fuente';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.detalle_cotizacion q JOIN comercial.detalle_pedido d ON d.detalle_cotizacion_id=q.id
  JOIN comercial.pedido p ON p.id=d.pedido_id WHERE p.estado IN ('confirmado','en_preparacion','completado')
  GROUP BY q.id HAVING sum(d.cantidad)>q.cantidad OR sum(d.subtotal)>q.subtotal OR sum(d.descuento_importe)>q.descuento_importe OR sum(d.impuesto_importe)>q.impuesto_importe) THEN
  RAISE EXCEPTION 'T07: pedidos exceden cantidad o importe de la cotización';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.cotizacion c WHERE NOT EXISTS(SELECT 1 FROM comercial.version_cotizacion v WHERE v.cotizacion_id=c.id)
  OR ((c.estado='aceptada') IS DISTINCT FROM EXISTS(SELECT 1 FROM comercial.version_cotizacion v WHERE v.cotizacion_id=c.id AND v.estado='aceptada'))) THEN
  RAISE EXCEPTION 'T08: negociación sin versión o aceptación incoherente';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.version_cotizacion v WHERE
   (v.enviada_en IS NOT NULL AND NOT EXISTS(SELECT 1 FROM comercial.detalle_cotizacion d WHERE d.version_cotizacion_id=v.id))
   OR (v.respondida_por_persona_id IS NOT NULL AND v.respondida_por_persona_id<>comercial.persona_cotizacion(v.cotizacion_id))) THEN
  RAISE EXCEPTION 'T08: oferta vacía o respondida por otra persona';
 END IF;
 -- Encabezado de factura: cada origen conserva su ruta y moneda.
 IF EXISTS(SELECT 1 FROM comercial.factura f
  LEFT JOIN comercial.pedido p ON p.id=f.pedido_id
  LEFT JOIN servicios.orden_servicio o ON o.id=f.orden_servicio_id
  LEFT JOIN proyectos.proyecto y ON y.id=f.proyecto_id
  LEFT JOIN comercial.version_cotizacion v ON v.id=coalesce(o.version_cotizacion_id,y.version_cotizacion_id)
  WHERE (f.pedido_id IS NOT NULL AND f.moneda<>p.moneda)
   OR (f.orden_servicio_id IS NOT NULL AND f.moneda<>coalesce(v.moneda,o.moneda))
   OR (f.proyecto_id IS NOT NULL AND f.moneda<>coalesce(v.moneda,y.moneda))
   OR (f.estado='emitida' AND ((f.pedido_id IS NOT NULL AND p.estado NOT IN ('confirmado','en_preparacion','completado'))
      OR o.estado='cancelada' OR y.estado='cancelado'
      OR NOT EXISTS(SELECT 1 FROM comercial.detalle_factura d WHERE d.factura_id=f.id)))) THEN
  RAISE EXCEPTION 'T09: moneda, origen o líneas de factura no válidos';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.detalle_factura d JOIN comercial.factura f ON f.id=d.factura_id
  LEFT JOIN comercial.detalle_pedido p ON p.id=d.detalle_pedido_id
  LEFT JOIN servicios.orden_servicio o ON o.id=f.orden_servicio_id
  LEFT JOIN servicios.solicitud_servicio s ON s.id=o.solicitud_servicio_id
  LEFT JOIN proyectos.proyecto y ON y.id=f.proyecto_id
  LEFT JOIN comercial.detalle_cotizacion q ON q.id=d.detalle_cotizacion_id
  WHERE (f.pedido_id IS NOT NULL AND (p.id IS NULL OR p.pedido_id<>f.pedido_id OR d.detalle_cotizacion_id IS NOT NULL
      OR d.unidad<>p.unidad OR d.precio_unitario<>p.precio_unitario OR d.descripcion<>p.descripcion OR d.tasa_impuesto<>p.tasa_impuesto))
   OR (f.pedido_id IS NULL AND d.detalle_pedido_id IS NOT NULL)
   OR (f.pedido_id IS NULL AND coalesce(o.version_cotizacion_id,y.version_cotizacion_id) IS NOT NULL AND
      (q.id IS NULL OR q.version_cotizacion_id<>coalesce(o.version_cotizacion_id,y.version_cotizacion_id)
       OR (f.proyecto_id IS NOT NULL AND q.clase<>'libre') OR (f.orden_servicio_id IS NOT NULL AND
         (q.clase NOT IN ('servicio','libre') OR (q.clase='servicio' AND q.servicio_ofrecido_id<>s.servicio_ofrecido_id)))
       OR d.unidad<>q.unidad OR d.precio_unitario<>q.precio_unitario OR d.descripcion<>q.descripcion OR d.tasa_impuesto<>q.tasa_impuesto))
   OR (f.pedido_id IS NULL AND coalesce(o.version_cotizacion_id,y.version_cotizacion_id) IS NULL AND
      (d.detalle_cotizacion_id IS NOT NULL OR d.ajuste_base<>0 OR d.tasa_impuesto<>coalesce(o.tasa_impuesto_autorizada,y.tasa_impuesto_autorizada)))) THEN
  RAISE EXCEPTION 'T09: línea de factura no corresponde a su ruta o condiciones';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.detalle_pedido p JOIN comercial.detalle_factura d ON d.detalle_pedido_id=p.id
  JOIN comercial.factura f ON f.id=d.factura_id WHERE f.estado='emitida'
  GROUP BY p.id HAVING sum(d.cantidad)>p.cantidad OR sum(d.subtotal)>p.subtotal OR sum(d.descuento_importe)>p.descuento_importe OR sum(d.impuesto_importe)>p.impuesto_importe) THEN
  RAISE EXCEPTION 'T09: facturas exceden cantidad o importes del pedido';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.detalle_cotizacion q JOIN comercial.detalle_factura d ON d.detalle_cotizacion_id=q.id
  JOIN comercial.factura f ON f.id=d.factura_id WHERE f.estado='emitida'
  GROUP BY q.id HAVING sum(d.cantidad)>q.cantidad OR sum(d.subtotal)>q.subtotal OR sum(d.descuento_importe)>q.descuento_importe OR sum(d.impuesto_importe)>q.impuesto_importe) THEN
  RAISE EXCEPTION 'T09: facturas entre procesos exceden capacidad compartida de cotización';
 END IF;
 IF EXISTS(SELECT 1 FROM servicios.orden_servicio o JOIN comercial.factura f ON f.orden_servicio_id=o.id
  JOIN comercial.detalle_factura d ON d.factura_id=f.id WHERE o.version_cotizacion_id IS NULL AND f.estado='emitida'
  GROUP BY o.id HAVING sum(d.subtotal)>o.importe_base_autorizado OR sum(d.impuesto_importe)>round(o.importe_base_autorizado*o.tasa_impuesto_autorizada,2))
 OR EXISTS(SELECT 1 FROM proyectos.proyecto y JOIN comercial.factura f ON f.proyecto_id=y.id
  JOIN comercial.detalle_factura d ON d.factura_id=f.id WHERE y.version_cotizacion_id IS NULL AND f.estado='emitida'
  GROUP BY y.id HAVING sum(d.subtotal)>y.importe_base_autorizado OR sum(d.impuesto_importe)>round(y.importe_base_autorizado*y.tasa_impuesto_autorizada,2)) THEN
  RAISE EXCEPTION 'T09: facturación directa supera autorización de origen';
 END IF;
END $$;

CREATE OR REPLACE FUNCTION comercial.validar_integridad_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN PERFORM comercial.validar_integridad(); RETURN NULL; END $$;

DO $triggers$
DECLARE v text;
BEGIN
 FOREACH v IN ARRAY ARRAY['inventario.producto','inventario.inventario','inventario.movimiento_inventario','inventario.reserva_inventario',
 'comercial.pedido','comercial.detalle_pedido','comercial.cotizacion','comercial.version_cotizacion','comercial.detalle_cotizacion',
 'comercial.factura','comercial.detalle_factura','comercial.carrito','comercial.detalle_carrito','comercial.solicitud_cotizacion'] LOOP
  EXECUTE format('CREATE TRIGGER b20_guard BEFORE INSERT OR UPDATE OR DELETE ON %s FOR EACH ROW EXECUTE FUNCTION comercial.proteger_fila()',v);
  EXECUTE format('CREATE CONSTRAINT TRIGGER z20_integridad AFTER INSERT OR UPDATE OR DELETE ON %s DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION comercial.validar_integridad_trigger()',v);
 END LOOP;
 FOREACH v IN ARRAY ARRAY['servicios.orden_servicio','servicios.solicitud_servicio','proyectos.proyecto','proyectos.solicitud_desarrollo','identidad.cliente'] LOOP
  EXECUTE format('CREATE CONSTRAINT TRIGGER z20_integridad AFTER INSERT OR UPDATE OR DELETE ON %s DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION comercial.validar_integridad_trigger()',v);
 END LOOP;
END $triggers$;
CREATE TRIGGER c20_inicializar AFTER INSERT ON inventario.producto FOR EACH ROW EXECUTE FUNCTION inventario.inicializar_saldo();
CREATE TRIGGER c20_aplicar AFTER INSERT ON inventario.movimiento_inventario FOR EACH ROW EXECUTE FUNCTION inventario.aplicar_movimiento();

-- API: movimientos manuales no admiten detalle_pedido; la entrega lo gestiona.
CREATE OR REPLACE PROCEDURE inventario.registrar_movimiento(p_producto bigint,p_tipo text,p_delta numeric,p_motivo text,p_operacion uuid,p_compensa bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE m inventario.movimiento_inventario%ROWTYPE;
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('inventario','gestionar',p_producto);
 SELECT * INTO m FROM inventario.movimiento_inventario WHERE operacion_id=p_operacion;
 IF FOUND THEN
  IF m.producto_id<>p_producto OR m.tipo<>p_tipo OR m.delta<>p_delta OR m.motivo<>p_motivo OR m.compensa_movimiento_id IS DISTINCT FROM p_compensa OR m.detalle_pedido_id IS NOT NULL THEN
   RAISE EXCEPTION 'La clave idempotente ya representa otro movimiento';
  END IF; RETURN;
 END IF;
 PERFORM 1 FROM inventario.inventario WHERE producto_id=p_producto FOR UPDATE;
 INSERT INTO inventario.movimiento_inventario(producto_id,tipo,delta,motivo,operacion_id,compensa_movimiento_id,actor_persona_id,actor_sistema)
 VALUES(p_producto,p_tipo,p_delta,p_motivo,p_operacion,p_compensa,identidad.actor_persona_actual(),identidad.actor_sistema_actual());
 PERFORM comercial.validar_integridad();
END $$;

CREATE OR REPLACE PROCEDURE inventario.guardar_producto(INOUT p_id bigint,p_sku text,p_categoria bigint,p_nombre text,p_descripcion text,p_unidad text,p_precio numeric,p_moneda text,p_publicado boolean,p_activo boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('producto','gestionar',p_id);
 IF p_id IS NULL THEN
  INSERT INTO inventario.producto(sku,categoria_id,nombre,descripcion,unidad,precio_vigente,moneda,publicado,activo)
  VALUES(p_sku,p_categoria,p_nombre,p_descripcion,p_unidad,p_precio,p_moneda,p_publicado,p_activo) RETURNING id INTO p_id;
 ELSE
  UPDATE inventario.producto SET sku=p_sku,categoria_id=p_categoria,nombre=p_nombre,descripcion=p_descripcion,unidad=p_unidad,
    precio_vigente=p_precio,moneda=p_moneda,publicado=p_publicado,activo=p_activo WHERE id=p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Producto inexistente'; END IF;
 END IF;
END $$;

CREATE OR REPLACE PROCEDURE comercial.crear_pedido(INOUT p_id bigint,p_cliente bigint,p_moneda text,p_nombre text,p_correo text,p_telefono text,p_version bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('cliente','crear',p_cliente);
 IF p_id IS NOT NULL THEN RAISE EXCEPTION 'Para crear un pedido el identificador de salida debe ser NULL'; END IF;
 INSERT INTO comercial.pedido(cliente_id,moneda,receptor_nombre,receptor_correo,receptor_telefono,version_cotizacion_id)
 VALUES(p_cliente,p_moneda,p_nombre,p_correo,p_telefono,p_version) RETURNING id INTO p_id;
END $$;

CREATE OR REPLACE PROCEDURE comercial.guardar_detalle_pedido(INOUT p_id bigint,p_pedido bigint,p_numero integer,p_producto bigint,p_cantidad numeric,p_tasa numeric,p_descuento numeric DEFAULT 0,p_detalle_cotizacion bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE pr inventario.producto%ROWTYPE; q comercial.detalle_cotizacion%ROWTYPE; pe comercial.pedido%ROWTYPE;
 v_descripcion text; v_unidad text; v_precio numeric; v_tasa numeric; v_descuento numeric;
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('pedido','gestionar',p_pedido);
 SELECT * INTO STRICT pe FROM comercial.pedido WHERE id=p_pedido FOR UPDATE;
 IF pe.estado<>'borrador' THEN RAISE EXCEPTION 'El pedido ya no es borrador'; END IF;
 SELECT * INTO STRICT pr FROM inventario.producto WHERE id=p_producto;
 IF NOT pr.activo OR NOT pr.publicado THEN RAISE EXCEPTION 'Producto no disponible para venta'; END IF;
 IF pe.version_cotizacion_id IS NOT NULL THEN
  SELECT * INTO STRICT q FROM comercial.detalle_cotizacion WHERE id=p_detalle_cotizacion;
  IF q.version_cotizacion_id<>pe.version_cotizacion_id OR q.clase<>'producto' OR q.producto_id<>p_producto THEN RAISE EXCEPTION 'Línea cotizada incompatible'; END IF;
  v_descripcion:=q.descripcion; v_unidad:=q.unidad; v_precio:=q.precio_unitario; v_tasa:=q.tasa_impuesto; v_descuento:=0;
 ELSE
  IF p_detalle_cotizacion IS NOT NULL OR pr.moneda<>pe.moneda THEN RAISE EXCEPTION 'Moneda o fuente incompatible'; END IF;
  v_descripcion:=pr.nombre; v_unidad:=pr.unidad; v_precio:=pr.precio_vigente; v_tasa:=p_tasa; v_descuento:=p_descuento;
 END IF;
 IF p_id IS NULL THEN
  INSERT INTO comercial.detalle_pedido(pedido_id,numero_linea,producto_id,detalle_cotizacion_id,descripcion,cantidad,unidad,precio_unitario,descuento_importe,tasa_impuesto)
   VALUES(p_pedido,p_numero,p_producto,p_detalle_cotizacion,v_descripcion,p_cantidad,v_unidad,v_precio,v_descuento,v_tasa) RETURNING id INTO p_id;
 ELSE
  UPDATE comercial.detalle_pedido SET numero_linea=p_numero,producto_id=p_producto,detalle_cotizacion_id=p_detalle_cotizacion,descripcion=v_descripcion,
    cantidad=p_cantidad,unidad=v_unidad,precio_unitario=v_precio,descuento_importe=v_descuento,tasa_impuesto=v_tasa,ajuste_base=0,ajuste_impuesto=0 WHERE id=p_id AND pedido_id=p_pedido;
  IF NOT FOUND THEN RAISE EXCEPTION 'Detalle no pertenece al pedido'; END IF;
 END IF;
END $$;

CREATE OR REPLACE PROCEDURE comercial.confirmar_pedido(p_pedido bigint,p_operacion uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE p comercial.pedido%ROWTYPE; d record; q comercial.detalle_cotizacion%ROWTYPE; a record; u record;
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('pedido','editar',p_pedido);
 SELECT * INTO STRICT p FROM comercial.pedido WHERE id=p_pedido FOR UPDATE;
 IF p_operacion IS NULL THEN RAISE EXCEPTION 'Falta identificador idempotente'; END IF;
 IF p.operacion_confirmacion_id IS NOT NULL THEN
  IF p.operacion_confirmacion_id<>p_operacion THEN RAISE EXCEPTION 'Pedido confirmado mediante otra operación'; END IF; RETURN;
 END IF;
 IF p.estado<>'borrador' THEN RAISE EXCEPTION 'Solo se confirma un borrador'; END IF;
 IF NOT EXISTS(SELECT 1 FROM comercial.detalle_pedido WHERE pedido_id=p_pedido) THEN RAISE EXCEPTION 'Pedido vacío'; END IF;
 PERFORM i.producto_id FROM inventario.inventario i JOIN comercial.detalle_pedido linea_bloqueo ON linea_bloqueo.producto_id=i.producto_id WHERE linea_bloqueo.pedido_id=p_pedido ORDER BY i.producto_id FOR UPDATE OF i;
 FOR d IN SELECT * FROM comercial.detalle_pedido WHERE pedido_id=p_pedido ORDER BY numero_linea,id LOOP
  IF p.version_cotizacion_id IS NOT NULL THEN
   SELECT * INTO STRICT q FROM comercial.detalle_cotizacion WHERE id=d.detalle_cotizacion_id FOR UPDATE;
   SELECT coalesce(sum(x.cantidad),0) uq,coalesce(sum(x.subtotal),0) ub,coalesce(sum(x.descuento_importe),0) ud,coalesce(sum(x.impuesto_importe),0) ui INTO u
    FROM comercial.detalle_pedido x JOIN comercial.pedido h ON h.id=x.pedido_id
    WHERE x.detalle_cotizacion_id=q.id AND (h.estado IN ('confirmado','en_preparacion','completado') OR (h.id=p_pedido AND (x.numero_linea,x.id)<(d.numero_linea,d.id)));
   SELECT * INTO a FROM comercial.repartir_importes(q.cantidad,q.subtotal,q.descuento_importe,q.impuesto_importe,q.precio_unitario,q.tasa_impuesto,u.uq,u.ub,u.ud,u.ui,d.cantidad);
   UPDATE comercial.detalle_pedido SET descuento_importe=a.descuento,ajuste_base=a.ajuste_base,ajuste_impuesto=a.ajuste_impuesto WHERE id=d.id;
  END IF;
  IF inventario.existencia_disponible(d.producto_id)<d.cantidad THEN RAISE EXCEPTION 'Existencia insuficiente para producto %',d.producto_id; END IF;
  INSERT INTO inventario.reserva_inventario(detalle_pedido_id) VALUES(d.id);
 END LOOP;
 UPDATE comercial.pedido SET estado='confirmado',confirmado_en=clock_timestamp(),operacion_confirmacion_id=p_operacion WHERE id=p_pedido;
 PERFORM comercial.validar_integridad();
END $$;

CREATE OR REPLACE PROCEDURE comercial.cambiar_estado_pedido(p_pedido bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE p comercial.pedido%ROWTYPE; d record;
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('pedido','gestionar',p_pedido);
 SELECT * INTO STRICT p FROM comercial.pedido WHERE id=p_pedido FOR UPDATE;
 PERFORM set_config('app.motivo',coalesce(nullif(btrim(p_motivo),''),'Cambio de pedido'),true);
 IF p.estado=p_estado THEN RETURN; END IF;
 IF p_estado NOT IN ('en_preparacion','completado','cancelado') THEN RAISE EXCEPTION 'Use confirmar_pedido para confirmar'; END IF;
 IF p.estado IN ('completado','cancelado') THEN RAISE EXCEPTION 'Pedido terminal'; END IF;
 IF p_estado IN ('en_preparacion','completado') AND p.estado NOT IN ('confirmado','en_preparacion') THEN RAISE EXCEPTION 'Pedido sin confirmar'; END IF;
 PERFORM i.producto_id FROM inventario.inventario i JOIN comercial.detalle_pedido linea_bloqueo ON linea_bloqueo.producto_id=i.producto_id WHERE linea_bloqueo.pedido_id=p_pedido ORDER BY i.producto_id FOR UPDATE OF i;
 IF p_estado='cancelado' THEN
  IF p_motivo IS NULL OR btrim(p_motivo)='' THEN RAISE EXCEPTION 'Cancelación requiere motivo'; END IF;
  IF EXISTS(SELECT 1 FROM comercial.factura WHERE pedido_id=p_pedido AND estado='emitida') THEN RAISE EXCEPTION 'Pedido tiene facturas vigentes'; END IF;
  UPDATE inventario.reserva_inventario r SET estado='liberada',cerrada_en=clock_timestamp(),motivo_liberacion=p_motivo
   FROM comercial.detalle_pedido linea_reservada WHERE linea_reservada.id=r.detalle_pedido_id AND linea_reservada.pedido_id=p_pedido AND r.estado='activa';
  UPDATE comercial.pedido SET estado='cancelado',cancelado_en=clock_timestamp(),motivo_cancelacion=p_motivo WHERE id=p_pedido;
 ELSIF p_estado='completado' THEN
  UPDATE inventario.reserva_inventario r SET estado='consumida',cerrada_en=clock_timestamp()
   FROM comercial.detalle_pedido linea_reservada WHERE linea_reservada.id=r.detalle_pedido_id AND linea_reservada.pedido_id=p_pedido AND r.estado='activa';
  UPDATE comercial.pedido SET estado='completado',completado_en=clock_timestamp() WHERE id=p_pedido;
  FOR d IN SELECT * FROM comercial.detalle_pedido WHERE pedido_id=p_pedido ORDER BY producto_id,id LOOP
   INSERT INTO inventario.movimiento_inventario(producto_id,tipo,delta,motivo,detalle_pedido_id,operacion_id,actor_persona_id,actor_sistema)
    VALUES(d.producto_id,'salida',-d.cantidad,coalesce(nullif(btrim(p_motivo),''),'Entrega completa del pedido'),d.id,gen_random_uuid(),identidad.actor_persona_actual(),identidad.actor_sistema_actual());
  END LOOP;
 ELSE UPDATE comercial.pedido SET estado=p_estado WHERE id=p_pedido;
 END IF;
 PERFORM comercial.validar_integridad();
END $$;

-- Carrito anónimo: el backend genera el secreto aleatorio; solamente se guarda SHA-256.
CREATE FUNCTION comercial.exigir_carrito(p_id bigint,p_token text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE c comercial.carrito%ROWTYPE;
BEGIN
 SELECT * INTO STRICT c FROM comercial.carrito WHERE id=p_id FOR UPDATE;
 IF identidad.es_dba() THEN RETURN; END IF;
 IF c.cliente_id IS NOT NULL THEN PERFORM identidad.exigir_permiso('carrito','editar',p_id); RETURN; END IF;
 IF p_token IS NULL OR length(p_token)<43 OR length(p_token)>512 OR c.sesion_anonima_hash IS DISTINCT FROM pg_catalog.sha256(convert_to(p_token,'UTF8')) THEN
  RAISE EXCEPTION 'Secreto de carrito inválido' USING ERRCODE='42501';
 END IF;
END $$;

CREATE PROCEDURE comercial.crear_carrito(p_cliente bigint,p_token text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('carrito','crear');
 IF p_id IS NOT NULL THEN RAISE EXCEPTION 'El identificador de alta debe ser NULL'; END IF;
 IF p_cliente IS NOT NULL THEN
  PERFORM identidad.exigir_permiso('cliente','crear',p_cliente);
  IF p_token IS NOT NULL THEN RAISE EXCEPTION 'Carrito de cliente no usa secreto anónimo'; END IF;
 ELSE
  IF p_token IS NULL OR length(p_token)<43 OR length(p_token)>512 THEN RAISE EXCEPTION 'El backend debe generar un secreto aleatorio de 256 bits'; END IF;
 END IF;
 INSERT INTO comercial.carrito(cliente_id,sesion_anonima_hash) VALUES(p_cliente,CASE WHEN p_token IS NULL THEN NULL ELSE pg_catalog.sha256(convert_to(p_token,'UTF8')) END) RETURNING id INTO p_id;
END $$;

CREATE PROCEDURE comercial.editar_carrito(p_id bigint,p_token text,p_producto bigint,p_cantidad numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM comercial.exigir_carrito(p_id,p_token);
 IF NOT EXISTS(SELECT 1 FROM comercial.carrito WHERE id=p_id AND estado='abierto') THEN RAISE EXCEPTION 'Carrito cerrado'; END IF;
 IF p_cantidad=0 THEN DELETE FROM comercial.detalle_carrito WHERE carrito_id=p_id AND producto_id=p_producto; RETURN; END IF;
 IF NOT EXISTS(SELECT 1 FROM inventario.producto WHERE id=p_producto AND activo AND publicado) THEN RAISE EXCEPTION 'Producto no disponible'; END IF;
 INSERT INTO comercial.detalle_carrito(carrito_id,producto_id,cantidad) VALUES(p_id,p_producto,p_cantidad)
 ON CONFLICT(carrito_id,producto_id) DO UPDATE SET cantidad=EXCLUDED.cantidad;
END $$;

CREATE PROCEDURE comercial.abandonar_carrito(p_id bigint,p_token text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM comercial.exigir_carrito(p_id,p_token);
 UPDATE comercial.carrito SET estado='abandonado' WHERE id=p_id AND estado='abierto';
 IF NOT FOUND THEN RAISE EXCEPTION 'Carrito cerrado'; END IF;
END $$;

-- La tasa es una decisión del backend autorizado; nunca se copia sin validar del navegador.
CREATE PROCEDURE comercial.convertir_carrito(p_carrito bigint,p_token text,p_nombres text,p_apellidos text,p_correo text,p_telefono text,p_moneda text,p_tasa numeric,INOUT p_pedido bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE c comercial.carrito%ROWTYPE; cli bigint; persona bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('pedido','crear');PERFORM comercial.exigir_carrito(p_carrito,p_token);
 IF p_pedido IS NOT NULL THEN RAISE EXCEPTION 'El identificador de salida debe ser NULL'; END IF;
 SELECT * INTO STRICT c FROM comercial.carrito WHERE id=p_carrito FOR UPDATE;
 IF c.estado<>'abierto' THEN RAISE EXCEPTION 'El carrito ya fue convertido o abandonado'; END IF;
 IF NOT EXISTS(SELECT 1 FROM comercial.detalle_carrito WHERE carrito_id=p_carrito) THEN RAISE EXCEPTION 'Carrito vacío'; END IF;
 IF EXISTS(SELECT 1 FROM comercial.detalle_carrito d JOIN inventario.producto p ON p.id=d.producto_id WHERE d.carrito_id=p_carrito AND (NOT p.activo OR NOT p.publicado OR p.moneda<>p_moneda)) THEN RAISE EXCEPTION 'Producto inactivo o moneda incompatible'; END IF;
 cli:=c.cliente_id;
 IF cli IS NULL THEN
  INSERT INTO identidad.persona(nombres,apellidos,correo_contacto,telefono) VALUES(p_nombres,p_apellidos,p_correo,p_telefono) RETURNING id INTO persona;
  INSERT INTO identidad.cliente(persona_id,codigo) VALUES(persona,'CLI-'||gen_random_uuid()) RETURNING id INTO cli;
  UPDATE comercial.carrito SET cliente_id=cli,sesion_anonima_hash=NULL WHERE id=p_carrito;
 END IF;
 INSERT INTO comercial.pedido(cliente_id,carrito_id,moneda,receptor_nombre,receptor_correo,receptor_telefono)
 VALUES(cli,p_carrito,p_moneda,concat_ws(' ',p_nombres,p_apellidos),p_correo,p_telefono) RETURNING id INTO p_pedido;
 INSERT INTO comercial.detalle_pedido(pedido_id,numero_linea,producto_id,descripcion,cantidad,unidad,precio_unitario,tasa_impuesto)
 SELECT p_pedido,(row_number() OVER(ORDER BY d.producto_id))::integer,p.id,p.nombre,d.cantidad,p.unidad,p.precio_vigente,p_tasa
 FROM comercial.detalle_carrito d JOIN inventario.producto p ON p.id=d.producto_id WHERE d.carrito_id=p_carrito;
 UPDATE comercial.carrito SET estado='convertido' WHERE id=p_carrito;
 -- Se entrega un borrador con precios del instante de conversión. Confirmar exige identidad o acceso verificado al pedido.
 PERFORM comercial.validar_integridad();
END $$;

CREATE PROCEDURE comercial.quitar_detalle_pedido(p_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE pid bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();SELECT pedido_id INTO STRICT pid FROM comercial.detalle_pedido WHERE id=p_id;
 PERFORM identidad.exigir_permiso('pedido','gestionar',pid);DELETE FROM comercial.detalle_pedido WHERE id=p_id;
END $$;

-- Alta pública con persona nueva o titular autenticado; no acepta apropiarse de una identidad existente.
CREATE OR REPLACE PROCEDURE comercial.solicitar_cotizacion(p_persona bigint,p_nombres text,p_apellidos text,p_correo text,p_telefono text,p_necesidad text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v_persona bigint:=p_persona; v_perfil identidad.persona%ROWTYPE;
 v_nombres text:=nullif(btrim(p_nombres),''); v_apellidos text:=nullif(btrim(p_apellidos),'');
 v_correo text:=nullif(btrim(p_correo),''); v_telefono text:=nullif(btrim(p_telefono),'');
 v_contacto_nombre text;
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('solicitud_cotizacion','crear');
 IF p_id IS NOT NULL THEN RAISE EXCEPTION 'El identificador de alta debe ser NULL'; END IF;
 IF v_persona IS NOT NULL THEN
   PERFORM identidad.exigir_permiso('persona','editar',v_persona);
   SELECT pe.* INTO STRICT v_perfil FROM identidad.persona pe WHERE pe.id=v_persona;
   IF NOT v_perfil.activo THEN RAISE EXCEPTION 'El solicitante está inactivo' USING ERRCODE='22023'; END IF;
   -- Los datos explícitos son el contacto de esta solicitud; lo omitido se toma del perfil.
   v_nombres:=coalesce(v_nombres,nullif(btrim(v_perfil.nombres),''));
   v_apellidos:=coalesce(v_apellidos,nullif(btrim(v_perfil.apellidos),''));
   v_correo:=coalesce(v_correo,nullif(btrim(v_perfil.correo_contacto),''));
   v_telefono:=coalesce(v_telefono,nullif(btrim(v_perfil.telefono),''));
 END IF;
 v_contacto_nombre:=nullif(btrim(concat_ws(' ',v_nombres,v_apellidos)),'');
 IF v_nombres IS NULL OR v_contacto_nombre IS NULL THEN
   RAISE EXCEPTION 'La solicitud requiere el nombre del contacto' USING ERRCODE='22023';
 END IF;
 IF v_correo IS NULL AND v_telefono IS NULL THEN
   RAISE EXCEPTION 'La solicitud requiere al menos un correo o teléfono de contacto' USING ERRCODE='22023';
 END IF;
 IF v_persona IS NULL THEN
   INSERT INTO identidad.persona(nombres,apellidos,correo_contacto,telefono)
   VALUES(v_nombres,v_apellidos,v_correo,v_telefono) RETURNING id INTO v_persona;
 END IF;
 INSERT INTO comercial.solicitud_cotizacion(codigo,persona_id,necesidad,contacto_nombre,contacto_correo,contacto_telefono)
 VALUES('SC-'||gen_random_uuid(),v_persona,p_necesidad,v_contacto_nombre,v_correo,v_telefono) RETURNING id INTO p_id;
END $$;

CREATE PROCEDURE comercial.cambiar_estado_solicitud_cotizacion(p_id bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('solicitud_cotizacion','gestionar',p_id);
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Debe indicar motivo'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE comercial.solicitud_cotizacion SET estado=p_estado WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Solicitud inexistente'; END IF;
END $$;

CREATE PROCEDURE comercial.crear_cotizacion(p_solicitud bigint,p_persona bigint,p_moneda text,p_condiciones text,p_nombre text,p_correo text,p_telefono text,p_vigente_hasta timestamptz,INOUT p_id bigint DEFAULT NULL,INOUT p_version bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('cotizacion','gestionar');
 IF p_id IS NOT NULL OR p_version IS NOT NULL THEN RAISE EXCEPTION 'Los identificadores de alta deben ser NULL'; END IF;
 IF p_vigente_hasta<=clock_timestamp() THEN RAISE EXCEPTION 'La vigencia debe ser futura'; END IF;
 INSERT INTO comercial.cotizacion(solicitud_cotizacion_id,persona_directa_id) VALUES(p_solicitud,p_persona) RETURNING id INTO p_id;
 INSERT INTO comercial.version_cotizacion(cotizacion_id,numero_version,moneda,condiciones,destinatario_nombre,destinatario_correo,destinatario_telefono,vigente_hasta)
 VALUES(p_id,1,p_moneda,p_condiciones,p_nombre,p_correo,p_telefono,p_vigente_hasta) RETURNING id INTO p_version;
END $$;

CREATE PROCEDURE comercial.revisar_cotizacion(p_cotizacion bigint,p_moneda text,p_condiciones text,p_nombre text,p_correo text,p_telefono text,p_vigente_hasta timestamptz,p_copiar_version bigint,INOUT p_version bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE c comercial.cotizacion%ROWTYPE; n integer;
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('cotizacion','gestionar',p_cotizacion);
 SELECT * INTO STRICT c FROM comercial.cotizacion WHERE id=p_cotizacion FOR UPDATE;
 IF p_version IS NOT NULL OR c.estado NOT IN ('abierta','cerrada') THEN RAISE EXCEPTION 'Solo negociación abierta/cerrada admite un nuevo borrador'; END IF;
 IF p_vigente_hasta<=clock_timestamp() THEN RAISE EXCEPTION 'La vigencia debe ser futura'; END IF;
 IF p_copiar_version IS NOT NULL AND NOT EXISTS(SELECT 1 FROM comercial.version_cotizacion WHERE id=p_copiar_version AND cotizacion_id=p_cotizacion AND moneda=p_moneda) THEN RAISE EXCEPTION 'La versión a copiar debe pertenecer a la negociación y moneda'; END IF;
 SELECT coalesce(max(numero_version),0)+1 INTO n FROM comercial.version_cotizacion WHERE cotizacion_id=p_cotizacion;
 UPDATE comercial.cotizacion SET estado='abierta' WHERE id=p_cotizacion AND estado='cerrada';
 INSERT INTO comercial.version_cotizacion(cotizacion_id,numero_version,moneda,condiciones,destinatario_nombre,destinatario_correo,destinatario_telefono,vigente_hasta)
 VALUES(p_cotizacion,n,p_moneda,p_condiciones,p_nombre,p_correo,p_telefono,p_vigente_hasta) RETURNING id INTO p_version;
 IF p_copiar_version IS NOT NULL THEN
  INSERT INTO comercial.detalle_cotizacion(version_cotizacion_id,numero_linea,clase,producto_id,servicio_ofrecido_id,descripcion,cantidad,unidad,precio_unitario,descuento_importe,tasa_impuesto)
  SELECT p_version,numero_linea,clase,producto_id,servicio_ofrecido_id,descripcion,cantidad,unidad,precio_unitario,descuento_importe,tasa_impuesto FROM comercial.detalle_cotizacion WHERE version_cotizacion_id=p_copiar_version;
 END IF;
END $$;

CREATE PROCEDURE comercial.editar_version_cotizacion(p_version bigint,p_condiciones text,p_nombre text,p_correo text,p_telefono text,p_vigente_hasta timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE c bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();SELECT cotizacion_id INTO STRICT c FROM comercial.version_cotizacion WHERE id=p_version;
 PERFORM identidad.exigir_permiso('cotizacion','gestionar',c);
 IF p_vigente_hasta<=clock_timestamp() THEN RAISE EXCEPTION 'La vigencia debe ser futura'; END IF;
 UPDATE comercial.version_cotizacion SET condiciones=p_condiciones,destinatario_nombre=p_nombre,destinatario_correo=p_correo,destinatario_telefono=p_telefono,vigente_hasta=p_vigente_hasta WHERE id=p_version AND estado='borrador';
 IF NOT FOUND THEN RAISE EXCEPTION 'Versión inexistente o ya enviada'; END IF;
END $$;

CREATE PROCEDURE comercial.guardar_detalle_cotizacion(p_version bigint,p_numero integer,p_clase text,p_producto bigint,p_servicio bigint,p_descripcion text,p_cantidad numeric,p_unidad text,p_precio numeric,p_descuento numeric,p_tasa numeric,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE c bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();SELECT cotizacion_id INTO STRICT c FROM comercial.version_cotizacion WHERE id=p_version;
 PERFORM identidad.exigir_permiso('cotizacion','gestionar',c);
 IF p_id IS NULL THEN
  INSERT INTO comercial.detalle_cotizacion(version_cotizacion_id,numero_linea,clase,producto_id,servicio_ofrecido_id,descripcion,cantidad,unidad,precio_unitario,descuento_importe,tasa_impuesto)
  VALUES(p_version,p_numero,p_clase,p_producto,p_servicio,p_descripcion,p_cantidad,p_unidad,p_precio,p_descuento,p_tasa) RETURNING id INTO p_id;
 ELSE
  UPDATE comercial.detalle_cotizacion SET numero_linea=p_numero,clase=p_clase,producto_id=p_producto,servicio_ofrecido_id=p_servicio,descripcion=p_descripcion,cantidad=p_cantidad,unidad=p_unidad,precio_unitario=p_precio,descuento_importe=p_descuento,tasa_impuesto=p_tasa WHERE id=p_id AND version_cotizacion_id=p_version;
  IF NOT FOUND THEN RAISE EXCEPTION 'Detalle ajeno a versión'; END IF;
 END IF;
END $$;

CREATE PROCEDURE comercial.quitar_detalle_cotizacion(p_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE c bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();SELECT v.cotizacion_id INTO STRICT c FROM comercial.detalle_cotizacion d JOIN comercial.version_cotizacion v ON v.id=d.version_cotizacion_id WHERE d.id=p_id;
 PERFORM identidad.exigir_permiso('cotizacion','gestionar',c);DELETE FROM comercial.detalle_cotizacion WHERE id=p_id;
END $$;

CREATE PROCEDURE comercial.enviar_cotizacion(p_version bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v comercial.version_cotizacion%ROWTYPE;
BEGIN
 PERFORM identidad.bloquear_operacion();SELECT * INTO STRICT v FROM comercial.version_cotizacion WHERE id=p_version FOR UPDATE;
 PERFORM identidad.exigir_permiso('cotizacion','gestionar',v.cotizacion_id);
 IF v.estado<>'borrador' OR v.vigente_hasta<=clock_timestamp() THEN RAISE EXCEPTION 'Borrador no vigente'; END IF;
 IF NOT EXISTS(SELECT 1 FROM comercial.cotizacion WHERE id=v.cotizacion_id AND estado='abierta') OR NOT EXISTS(SELECT 1 FROM comercial.detalle_cotizacion WHERE version_cotizacion_id=p_version) THEN RAISE EXCEPTION 'Negociación cerrada u oferta vacía'; END IF;
 PERFORM set_config('app.motivo',coalesce(nullif(btrim(p_motivo),''),'Envío de oferta'),true);
 UPDATE comercial.version_cotizacion SET estado='reemplazada' WHERE cotizacion_id=v.cotizacion_id AND estado='enviada';
 UPDATE comercial.version_cotizacion SET estado='enviada',enviada_en=clock_timestamp() WHERE id=p_version;
 PERFORM comercial.validar_integridad();
END $$;

CREATE PROCEDURE comercial.responder_cotizacion(p_version bigint,p_aceptar boolean,p_evidencia text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v comercial.version_cotizacion%ROWTYPE; titular bigint; actor bigint; momento timestamptz;
BEGIN
 PERFORM identidad.bloquear_operacion();SELECT * INTO STRICT v FROM comercial.version_cotizacion WHERE id=p_version FOR UPDATE;
 PERFORM identidad.exigir_permiso('version_cotizacion','responder',p_version);
 titular:=comercial.persona_cotizacion(v.cotizacion_id);actor:=identidad.actor_persona_actual();
 IF NOT identidad.es_dba() AND actor IS DISTINCT FROM titular THEN RAISE EXCEPTION 'La respuesta corresponde exclusivamente al destinatario'; END IF;
 momento:=clock_timestamp();
 IF p_aceptar IS NULL OR nullif(btrim(p_evidencia),'') IS NULL THEN RAISE EXCEPTION 'Respuesta y evidencia obligatorias'; END IF;
 IF ((p_aceptar AND v.estado='aceptada') OR (NOT p_aceptar AND v.estado='rechazada'))
    AND v.evidencia_respuesta=p_evidencia THEN RETURN; END IF;
 IF v.estado<>'enviada' OR momento>v.vigente_hasta OR NOT EXISTS(SELECT 1 FROM comercial.cotizacion WHERE id=v.cotizacion_id AND estado='abierta') THEN RAISE EXCEPTION 'La versión no está disponible para responder'; END IF;
 PERFORM set_config('app.motivo',p_evidencia,true);
 UPDATE comercial.version_cotizacion SET estado=CASE WHEN p_aceptar THEN 'aceptada' ELSE 'rechazada' END,respondida_en=momento,respondida_por_persona_id=titular,evidencia_respuesta=p_evidencia WHERE id=p_version;
 -- Aceptar cierra cualquier borrador alternativo. La evidencia de una versión aceptada nunca se reescribe.
 IF p_aceptar THEN UPDATE comercial.version_cotizacion SET estado='anulada' WHERE cotizacion_id=v.cotizacion_id AND estado='borrador'; END IF;
 UPDATE comercial.cotizacion SET estado=CASE WHEN p_aceptar THEN 'aceptada' ELSE 'cerrada' END WHERE id=v.cotizacion_id;
 PERFORM comercial.validar_integridad();
END $$;

CREATE PROCEDURE comercial.anular_cotizacion(p_cotizacion bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('cotizacion','gestionar',p_cotizacion);
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Debe indicar motivo'; END IF;
 IF NOT EXISTS(SELECT 1 FROM comercial.cotizacion WHERE id=p_cotizacion AND estado IN ('abierta','cerrada')) THEN RAISE EXCEPTION 'Una negociación aceptada o anulada no se anula'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE comercial.version_cotizacion SET estado='anulada' WHERE cotizacion_id=p_cotizacion AND estado IN ('borrador','enviada');
 UPDATE comercial.cotizacion SET estado='anulada' WHERE id=p_cotizacion;
END $$;

CREATE PROCEDURE comercial.crear_factura(p_pedido bigint,p_orden bigint,p_proyecto bigint,p_nombre text,p_identificacion text,p_correo text,p_telefono text,p_direccion text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE moneda text;
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('factura','gestionar');
 IF p_id IS NOT NULL OR num_nonnulls(p_pedido,p_orden,p_proyecto)<>1 THEN RAISE EXCEPTION 'Alta de factura requiere un solo origen'; END IF;
 IF p_pedido IS NOT NULL THEN SELECT p.moneda INTO STRICT moneda FROM comercial.pedido p WHERE id=p_pedido;
 ELSIF p_orden IS NOT NULL THEN SELECT coalesce(v.moneda,o.moneda) INTO STRICT moneda FROM servicios.orden_servicio o LEFT JOIN comercial.version_cotizacion v ON v.id=o.version_cotizacion_id WHERE o.id=p_orden;
 ELSE SELECT coalesce(v.moneda,y.moneda) INTO STRICT moneda FROM proyectos.proyecto y LEFT JOIN comercial.version_cotizacion v ON v.id=y.version_cotizacion_id WHERE y.id=p_proyecto; END IF;
 INSERT INTO comercial.factura(pedido_id,orden_servicio_id,proyecto_id,moneda,receptor_nombre,receptor_identificacion,receptor_correo,receptor_telefono,receptor_direccion)
 VALUES(p_pedido,p_orden,p_proyecto,moneda,p_nombre,p_identificacion,p_correo,p_telefono,p_direccion) RETURNING id INTO p_id;
END $$;

-- Una línea toma precio, descripción, unidad y tasa de la fuente congelada.
-- Para servicio/proyecto directo se recibe una base por unidad y tasa derivada de autorización.
CREATE PROCEDURE comercial.guardar_detalle_factura(p_factura bigint,p_numero integer,p_detalle_pedido bigint,p_detalle_cotizacion bigint,p_cantidad numeric,p_descripcion text,p_unidad text,p_precio_directo numeric,p_descuento_directo numeric,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE f comercial.factura%ROWTYPE; fuente record; descripcion text; unidad text; precio numeric; tasa numeric; descuento numeric:=0; version_id bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('factura','gestionar',p_factura);
 SELECT * INTO STRICT f FROM comercial.factura WHERE id=p_factura FOR UPDATE;
 IF f.estado<>'borrador' THEN RAISE EXCEPTION 'Factura emitida'; END IF;
 IF f.pedido_id IS NOT NULL THEN
  SELECT * INTO STRICT fuente FROM comercial.detalle_pedido WHERE id=p_detalle_pedido AND pedido_id=f.pedido_id;
  IF p_detalle_cotizacion IS NOT NULL THEN RAISE EXCEPTION 'Factura de pedido no consume otra vez cotización'; END IF;
 ELSE
  IF p_detalle_pedido IS NOT NULL THEN RAISE EXCEPTION 'Detalle de pedido ajeno al origen'; END IF;
  IF f.orden_servicio_id IS NOT NULL THEN SELECT o.version_cotizacion_id,o.tasa_impuesto_autorizada INTO version_id,tasa FROM servicios.orden_servicio o WHERE id=f.orden_servicio_id;
  ELSE SELECT y.version_cotizacion_id,y.tasa_impuesto_autorizada INTO version_id,tasa FROM proyectos.proyecto y WHERE id=f.proyecto_id; END IF;
  IF version_id IS NOT NULL THEN
   SELECT * INTO STRICT fuente FROM comercial.detalle_cotizacion WHERE id=p_detalle_cotizacion AND version_cotizacion_id=version_id;
  ELSIF p_detalle_cotizacion IS NOT NULL THEN RAISE EXCEPTION 'Origen directo no tiene línea cotizada'; END IF;
 END IF;
 IF f.pedido_id IS NOT NULL OR version_id IS NOT NULL THEN
  descripcion:=fuente.descripcion;unidad:=fuente.unidad;precio:=fuente.precio_unitario;tasa:=fuente.tasa_impuesto;
 ELSE descripcion:=p_descripcion;unidad:=p_unidad;precio:=p_precio_directo;descuento:=p_descuento_directo; END IF;
 IF p_id IS NULL THEN
  INSERT INTO comercial.detalle_factura(factura_id,numero_linea,detalle_pedido_id,detalle_cotizacion_id,descripcion,cantidad,unidad,precio_unitario,descuento_importe,tasa_impuesto)
  VALUES(p_factura,p_numero,p_detalle_pedido,p_detalle_cotizacion,descripcion,p_cantidad,unidad,precio,descuento,tasa) RETURNING id INTO p_id;
 ELSE
  UPDATE comercial.detalle_factura d SET numero_linea=p_numero,detalle_pedido_id=p_detalle_pedido,detalle_cotizacion_id=p_detalle_cotizacion,descripcion=guardar_detalle_factura.descripcion,cantidad=p_cantidad,unidad=guardar_detalle_factura.unidad,precio_unitario=precio,descuento_importe=descuento,tasa_impuesto=tasa,ajuste_base=0,ajuste_impuesto=0 WHERE d.id=p_id AND factura_id=p_factura;
  IF NOT FOUND THEN RAISE EXCEPTION 'Detalle ajeno a factura'; END IF;
 END IF;
END $$;

CREATE PROCEDURE comercial.quitar_detalle_factura(p_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE f bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();SELECT factura_id INTO STRICT f FROM comercial.detalle_factura WHERE id=p_id;
 PERFORM identidad.exigir_permiso('factura','gestionar',f);DELETE FROM comercial.detalle_factura WHERE id=p_id;
END $$;

CREATE PROCEDURE comercial.emitir_factura(p_factura bigint,p_operacion uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE f comercial.factura%ROWTYPE; d record; fuente record; u record; a record; techo numeric; tasa numeric; total_base numeric; total_impuesto numeric; nueva_base numeric; nuevo_impuesto numeric;
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('factura','gestionar',p_factura);
 SELECT * INTO STRICT f FROM comercial.factura WHERE id=p_factura FOR UPDATE;
 IF p_operacion IS NULL THEN RAISE EXCEPTION 'Falta identificador idempotente'; END IF;
 IF f.operacion_emision_id IS NOT NULL THEN
  IF f.operacion_emision_id<>p_operacion THEN RAISE EXCEPTION 'Factura emitida mediante otra operación'; END IF;RETURN;
 END IF;
 IF f.estado<>'borrador' OR NOT EXISTS(SELECT 1 FROM comercial.detalle_factura WHERE factura_id=p_factura) THEN RAISE EXCEPTION 'Factura no es borrador o está vacía'; END IF;
 IF f.orden_servicio_id IS NOT NULL THEN SELECT importe_base_autorizado,tasa_impuesto_autorizada INTO techo,tasa FROM servicios.orden_servicio WHERE id=f.orden_servicio_id;
 ELSIF f.proyecto_id IS NOT NULL THEN SELECT importe_base_autorizado,tasa_impuesto_autorizada INTO techo,tasa FROM proyectos.proyecto WHERE id=f.proyecto_id; END IF;
 FOR d IN SELECT * FROM comercial.detalle_factura WHERE factura_id=p_factura ORDER BY numero_linea,id LOOP
  IF d.detalle_pedido_id IS NOT NULL OR d.detalle_cotizacion_id IS NOT NULL THEN
   IF d.detalle_pedido_id IS NOT NULL THEN SELECT * INTO STRICT fuente FROM comercial.detalle_pedido WHERE id=d.detalle_pedido_id FOR UPDATE;
   ELSE SELECT * INTO STRICT fuente FROM comercial.detalle_cotizacion WHERE id=d.detalle_cotizacion_id FOR UPDATE; END IF;
   SELECT coalesce(sum(x.cantidad),0) uq,coalesce(sum(x.subtotal),0) ub,coalesce(sum(x.descuento_importe),0) ud,coalesce(sum(x.impuesto_importe),0) ui INTO u
   FROM comercial.detalle_factura x JOIN comercial.factura h ON h.id=x.factura_id
   WHERE ((d.detalle_pedido_id IS NOT NULL AND x.detalle_pedido_id=d.detalle_pedido_id) OR (d.detalle_cotizacion_id IS NOT NULL AND x.detalle_cotizacion_id=d.detalle_cotizacion_id))
     AND (h.estado='emitida' OR (h.id=p_factura AND (x.numero_linea,x.id)<(d.numero_linea,d.id)));
   SELECT * INTO a FROM comercial.repartir_importes(fuente.cantidad,fuente.subtotal,fuente.descuento_importe,fuente.impuesto_importe,fuente.precio_unitario,fuente.tasa_impuesto,u.uq,u.ub,u.ud,u.ui,d.cantidad);
   UPDATE comercial.detalle_factura SET descuento_importe=a.descuento,ajuste_base=a.ajuste_base,ajuste_impuesto=a.ajuste_impuesto WHERE id=d.id;
  ELSE
   IF techo IS NULL OR tasa IS NULL THEN RAISE EXCEPTION 'Factura cotizada requiere fuente en cada línea'; END IF;
   SELECT coalesce(sum(x.subtotal),0),coalesce(sum(x.impuesto_importe),0) INTO total_base,total_impuesto
   FROM comercial.detalle_factura x JOIN comercial.factura h ON h.id=x.factura_id
   WHERE ((f.orden_servicio_id IS NOT NULL AND h.orden_servicio_id=f.orden_servicio_id) OR (f.proyecto_id IS NOT NULL AND h.proyecto_id=f.proyecto_id))
     AND (h.estado='emitida' OR (h.id=p_factura AND (x.numero_linea,x.id)<(d.numero_linea,d.id)));
   nueva_base:=round(d.cantidad*d.precio_unitario,2)-d.descuento_importe;
   nuevo_impuesto:=round((total_base+nueva_base)*tasa,2)-total_impuesto;
   IF nueva_base<0 OR total_base+nueva_base>techo OR nuevo_impuesto<0 OR total_impuesto+nuevo_impuesto>round(techo*tasa,2) THEN RAISE EXCEPTION 'Factura supera autorización o requiere revisión de redondeo tras anulación'; END IF;
   UPDATE comercial.detalle_factura SET ajuste_base=0,ajuste_impuesto=nuevo_impuesto-round(nueva_base*tasa,2) WHERE id=d.id;
  END IF;
 END LOOP;
 UPDATE comercial.factura SET estado='emitida',numero=nextval('comercial.seq_factura'::regclass),emitida_en=clock_timestamp(),operacion_emision_id=p_operacion WHERE id=p_factura;
 PERFORM comercial.validar_integridad();
END $$;

CREATE PROCEDURE comercial.anular_factura(p_factura bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('factura','gestionar',p_factura);
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Debe indicar motivo de anulación'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE comercial.factura SET estado='anulada',anulada_en=clock_timestamp(),motivo_anulacion=p_motivo WHERE id=p_factura AND estado='emitida';
 IF NOT FOUND THEN RAISE EXCEPTION 'Solo se anula una factura emitida'; END IF;
 PERFORM comercial.validar_integridad();
END $$;


-- MÓDULO 30_servicios
-- Fase 5. Servicios técnicos y desarrollo. Se instala después de los helpers de identidad.
-- Las comprobaciones diferibles consultan el estado final de la transacción.
-- El mutex global de escritura simplifica la demostración y serializa operaciones; para
-- mayor volumen deberá sustituirse por bloqueos ordenados de los agregados afectados.

CREATE FUNCTION servicios.validar_integridad() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM servicios.solicitud_servicio s
    JOIN servicios.servicio_ofrecido o ON o.id=s.servicio_ofrecido_id
    LEFT JOIN servicios.equipo_cliente e ON e.id=s.equipo_cliente_id
    WHERE (s.equipo_cliente_id IS NOT NULL AND e.cliente_id IS DISTINCT FROM s.cliente_id)
       OR (o.modalidad='reparacion' AND s.equipo_cliente_id IS NULL)
       OR (o.modalidad='mantenimiento' AND s.equipo_cliente_id IS NULL AND nullif(btrim(s.alcance),'') IS NULL)
  ) THEN RAISE EXCEPTION 'T01: equipo, titular o alcance de solicitud incoherentes' USING ERRCODE='23514'; END IF;
  IF EXISTS (
    SELECT 1 FROM servicios.orden_servicio o
    JOIN servicios.solicitud_servicio s ON s.id=o.solicitud_servicio_id
    JOIN servicios.servicio_ofrecido f ON f.id=s.servicio_ofrecido_id
    LEFT JOIN servicios.reparacion r ON r.orden_servicio_id=o.id
    LEFT JOIN servicios.mantenimiento m ON m.orden_servicio_id=o.id
    WHERE (s.estado<>'aceptada' AND NOT(s.estado='cancelada' AND o.estado='cancelada'))
       OR (f.modalidad='reparacion' AND (r.orden_servicio_id IS NULL OR m.orden_servicio_id IS NOT NULL))
       OR (f.modalidad='mantenimiento' AND (m.orden_servicio_id IS NULL OR r.orden_servicio_id IS NOT NULL))
       OR (o.estado='finalizada' AND f.modalidad='reparacion' AND
           (nullif(btrim(r.diagnostico),'') IS NULL OR nullif(btrim(r.solucion),'') IS NULL OR nullif(btrim(r.resultado_pruebas),'') IS NULL))
       OR (o.estado='finalizada' AND f.modalidad='mantenimiento' AND
           (nullif(btrim(m.actividades_realizadas),'') IS NULL OR nullif(btrim(m.hallazgos),'') IS NULL))
       OR (o.estado='en_ejecucion' AND NOT EXISTS (
          SELECT 1 FROM servicios.asignacion_servicio a WHERE a.orden_servicio_id=o.id
          AND a.es_principal AND a.termina_en IS NULL AND a.inicia_en<=clock_timestamp()
          AND identidad.empleado_habilitado(a.empleado_id,'orden_servicio')))
  ) THEN RAISE EXCEPTION 'T02: orden sin solicitud apta, subtipo, informe o responsable habilitado' USING ERRCODE='23514'; END IF;
  IF EXISTS (
    SELECT 1 FROM servicios.cita_servicio c
    JOIN servicios.solicitud_servicio s ON s.id=c.solicitud_servicio_id
    LEFT JOIN servicios.cita_servicio anterior ON anterior.id=c.sustituye_cita_id
    WHERE (c.sustituye_cita_id IS NOT NULL AND
          (anterior.solicitud_servicio_id<>c.solicitud_servicio_id OR anterior.estado<>'cancelada'))
      OR (c.estado='confirmada' AND c.fin>clock_timestamp() AND
          (s.estado IN ('cancelada','rechazada') OR NOT identidad.empleado_habilitado(c.tecnico_id,'orden_servicio')
           OR NOT EXISTS (SELECT 1 FROM servicios.disponibilidad_tecnico d WHERE d.empleado_id=c.tecnico_id
                 AND d.habilitada AND d.inicio<=c.inicio AND d.fin>=c.fin)))
  ) THEN RAISE EXCEPTION 'T03: cita sin disponibilidad, técnico habilitado o sustitución válida' USING ERRCODE='23514'; END IF;
  IF EXISTS (
    SELECT 1 FROM servicios.calificacion_servicio v
    JOIN servicios.orden_servicio o ON o.id=v.orden_servicio_id
    JOIN servicios.solicitud_servicio s ON s.id=o.solicitud_servicio_id
    JOIN identidad.cliente c ON c.id=s.cliente_id
    WHERE o.estado<>'finalizada' OR v.autor_persona_id<>c.persona_id
  ) THEN RAISE EXCEPTION 'T04: solo el titular puede valorar una orden finalizada' USING ERRCODE='23514'; END IF;
  IF EXISTS (
    SELECT 1 FROM proyectos.proyecto p
    JOIN proyectos.solicitud_desarrollo s ON s.id=p.solicitud_desarrollo_id
    WHERE (s.estado<>'aprobada' AND NOT(s.estado='cancelada' AND p.estado='cancelado'))
       OR (p.estado='en_ejecucion' AND
          (NOT EXISTS(SELECT 1 FROM proyectos.etapa_proyecto e WHERE e.proyecto_id=p.id)
           OR NOT EXISTS(SELECT 1 FROM proyectos.miembro_proyecto m WHERE m.proyecto_id=p.id AND m.es_principal
                AND m.termina_en IS NULL AND m.inicia_en<=clock_timestamp()
                AND identidad.empleado_habilitado(m.empleado_id,'proyecto'))))
  ) THEN RAISE EXCEPTION 'T05: proyecto sin aprobación, etapas o responsable habilitado' USING ERRCODE='23514'; END IF;
  IF EXISTS (
    SELECT 1 FROM proyectos.avance_proyecto a
    JOIN proyectos.etapa_proyecto e ON e.id=a.etapa_proyecto_id
    JOIN proyectos.miembro_proyecto m ON m.id=a.miembro_proyecto_id
    WHERE e.proyecto_id<>m.proyecto_id OR a.registrado_en<m.inicia_en OR
          (m.termina_en IS NOT NULL AND a.registrado_en>=m.termina_en)
  ) THEN RAISE EXCEPTION 'T05: avance fuera del proyecto o período de su autor' USING ERRCODE='23514'; END IF;
  RETURN NULL;
END $$;

-- Disparar también ante alteraciones de padres evita que una fila válida quede inválida.
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['servicios.solicitud_servicio','servicios.servicio_ofrecido',
    'servicios.equipo_cliente','servicios.orden_servicio','servicios.reparacion',
    'servicios.mantenimiento','servicios.asignacion_servicio','servicios.cita_servicio',
    'servicios.disponibilidad_tecnico','servicios.calificacion_servicio',
    'proyectos.solicitud_desarrollo','proyectos.proyecto','proyectos.etapa_proyecto',
    'proyectos.miembro_proyecto','proyectos.avance_proyecto','identidad.cliente',
    'identidad.empleado','identidad.usuario','identidad.usuario_rol','identidad.rol_permiso']
  LOOP
    EXECUTE format('CREATE CONSTRAINT TRIGGER validar_servicios_proyectos AFTER INSERT OR UPDATE OR DELETE ON %s DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION servicios.validar_integridad()',t);
  END LOOP;
END $$;

CREATE FUNCTION servicios.proteger_datos() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v_id bigint; v_estado text;
BEGIN
  PERFORM identidad.bloquear_operacion();
  IF TG_TABLE_NAME='servicio_ofrecido' THEN
   IF TG_OP='UPDATE' AND NEW.modalidad IS DISTINCT FROM OLD.modalidad AND
      EXISTS(SELECT 1 FROM servicios.solicitud_servicio WHERE servicio_ofrecido_id=OLD.id) THEN
    RAISE EXCEPTION 'La modalidad de una oferta utilizada es inmutable' USING ERRCODE='23514'; END IF;
  ELSIF TG_TABLE_NAME='equipo_cliente' THEN
   IF TG_OP='UPDATE' AND NEW.cliente_id IS DISTINCT FROM OLD.cliente_id AND
      EXISTS(SELECT 1 FROM servicios.solicitud_servicio WHERE equipo_cliente_id=OLD.id) THEN
    RAISE EXCEPTION 'El titular de un equipo con historial no se modifica' USING ERRCODE='23514'; END IF;
  ELSIF TG_TABLE_NAME='solicitud_servicio' THEN
   IF TG_OP='UPDATE' AND
      ROW(NEW.cliente_id,NEW.servicio_ofrecido_id,NEW.equipo_cliente_id) IS DISTINCT FROM
      ROW(OLD.cliente_id,OLD.servicio_ofrecido_id,OLD.equipo_cliente_id) AND
      EXISTS(SELECT 1 FROM servicios.orden_servicio WHERE solicitud_servicio_id=OLD.id) THEN
    RAISE EXCEPTION 'La identidad de una solicitud con orden es inmutable' USING ERRCODE='23514'; END IF;
  ELSIF TG_TABLE_NAME='calificacion_servicio' THEN
   IF TG_OP='UPDATE' AND
      ROW(NEW.orden_servicio_id,NEW.autor_persona_id) IS DISTINCT FROM ROW(OLD.orden_servicio_id,OLD.autor_persona_id) THEN
    RAISE EXCEPTION 'Orden y autor de calificación son inmutables' USING ERRCODE='23514'; END IF;
  ELSIF TG_TABLE_NAME IN ('reparacion','mantenimiento') AND TG_OP IN ('UPDATE','DELETE') THEN
    SELECT estado INTO v_estado FROM servicios.orden_servicio WHERE id=OLD.orden_servicio_id;
    IF v_estado IN ('finalizada','cancelada') THEN
      RAISE EXCEPTION 'El informe técnico cerrado se conserva' USING ERRCODE='23514';
    END IF;
    IF TG_OP='UPDATE' AND NEW.orden_servicio_id<>OLD.orden_servicio_id THEN
      RAISE EXCEPTION 'El informe no puede trasladarse a otra orden' USING ERRCODE='23514';
    END IF;
  ELSIF TG_TABLE_NAME='orden_servicio' AND TG_OP='UPDATE' THEN
    IF NEW.solicitud_servicio_id<>OLD.solicitud_servicio_id THEN
      RAISE EXCEPTION 'La solicitud de origen es inmutable' USING ERRCODE='23514';
    END IF;
    IF ROW(NEW.version_cotizacion_id,NEW.importe_base_autorizado,NEW.tasa_impuesto_autorizada,NEW.moneda)
       IS DISTINCT FROM ROW(OLD.version_cotizacion_id,OLD.importe_base_autorizado,OLD.tasa_impuesto_autorizada,OLD.moneda)
       AND EXISTS(SELECT 1 FROM comercial.factura WHERE orden_servicio_id=OLD.id) THEN
      RAISE EXCEPTION 'La autorización económica se congela al iniciar facturación' USING ERRCODE='23514';
    END IF;
    IF NEW.estado='cancelada' AND EXISTS(SELECT 1 FROM comercial.factura WHERE orden_servicio_id=OLD.id AND estado='emitida') THEN
      RAISE EXCEPTION 'Resuelva la facturación vigente antes de cancelar' USING ERRCODE='23514';
    END IF;
  ELSIF TG_TABLE_NAME='asignacion_servicio' THEN
    IF TG_OP='INSERT' THEN
      IF NEW.inicia_en>clock_timestamp() OR NEW.termina_en IS NOT NULL OR NOT identidad.empleado_habilitado(NEW.empleado_id,'orden_servicio') THEN
        RAISE EXCEPTION 'Asignación efectiva requiere empleado habilitado y período abierto actual' USING ERRCODE='23514';
      END IF;
    ELSIF TG_OP='UPDATE' THEN
      IF ROW(NEW.orden_servicio_id,NEW.empleado_id,NEW.inicia_en,NEW.es_principal,NEW.funcion)
        IS DISTINCT FROM ROW(OLD.orden_servicio_id,OLD.empleado_id,OLD.inicia_en,OLD.es_principal,OLD.funcion)
        OR OLD.termina_en IS NOT NULL OR NEW.termina_en IS NULL OR NEW.termina_en>clock_timestamp() THEN
        RAISE EXCEPTION 'Una asignación se cierra; una nueva fila registra la sustitución' USING ERRCODE='23514';
      END IF;
    ELSE RAISE EXCEPTION 'Se conservan los períodos de asignación' USING ERRCODE='23514'; END IF;
  END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$;

DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['servicio_ofrecido','equipo_cliente','solicitud_servicio','calificacion_servicio',
   'reparacion','mantenimiento','orden_servicio','asignacion_servicio'] LOOP
   EXECUTE format('CREATE TRIGGER proteger_datos_servicio BEFORE INSERT OR UPDATE OR DELETE ON servicios.%I FOR EACH ROW EXECUTE FUNCTION servicios.proteger_datos()',t);
 END LOOP;
END $$;

CREATE FUNCTION proyectos.proteger_datos() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v_proyecto bigint; v_estado text; v_iniciado timestamptz; v_miembro proyectos.miembro_proyecto%ROWTYPE;
BEGIN
 PERFORM identidad.bloquear_operacion();
 IF TG_TABLE_NAME='avance_proyecto' THEN
   IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Los avances se corrigen mediante un nuevo reporte' USING ERRCODE='23514'; END IF;
   SELECT * INTO STRICT v_miembro FROM proyectos.miembro_proyecto WHERE id=NEW.miembro_proyecto_id;
   SELECT e.proyecto_id,p.estado INTO v_proyecto,v_estado FROM proyectos.etapa_proyecto e
      JOIN proyectos.proyecto p ON p.id=e.proyecto_id WHERE e.id=NEW.etapa_proyecto_id;
   IF v_miembro.proyecto_id<>v_proyecto OR v_miembro.termina_en IS NOT NULL OR
      NOT identidad.empleado_habilitado(v_miembro.empleado_id,'proyecto') OR v_estado<>'en_ejecucion' THEN
     RAISE EXCEPTION 'El avance exige un miembro habilitado del proyecto en ejecución' USING ERRCODE='23514';
   END IF;
   -- La fecha procede del servidor; el llamante no puede introducir avances retrospectivos.
   NEW.registrado_en:=clock_timestamp();
 ELSIF TG_TABLE_NAME='miembro_proyecto' THEN
   IF TG_OP='INSERT' THEN
     IF NEW.inicia_en>clock_timestamp() OR NEW.termina_en IS NOT NULL OR NOT identidad.empleado_habilitado(NEW.empleado_id,'proyecto') THEN
       RAISE EXCEPTION 'El miembro requiere empleado habilitado y período abierto actual' USING ERRCODE='23514';
     END IF;
   ELSIF TG_OP='UPDATE' THEN
     IF ROW(NEW.proyecto_id,NEW.empleado_id,NEW.inicia_en,NEW.es_principal,NEW.funcion)
        IS DISTINCT FROM ROW(OLD.proyecto_id,OLD.empleado_id,OLD.inicia_en,OLD.es_principal,OLD.funcion)
        OR OLD.termina_en IS NOT NULL OR NEW.termina_en IS NULL OR NEW.termina_en>clock_timestamp() THEN
       RAISE EXCEPTION 'La participación se cierra; la sustitución crea un período nuevo' USING ERRCODE='23514';
     END IF;
   ELSE RAISE EXCEPTION 'Se conservan los períodos de participación' USING ERRCODE='23514'; END IF;
 ELSIF TG_TABLE_NAME='etapa_proyecto' THEN
   IF TG_OP='UPDATE' AND NEW.proyecto_id<>OLD.proyecto_id THEN
     RAISE EXCEPTION 'La etapa no puede trasladarse a otro proyecto' USING ERRCODE='23514';
   END IF;
   IF TG_OP='DELETE' THEN v_proyecto:=OLD.proyecto_id; ELSE v_proyecto:=NEW.proyecto_id; END IF;
   SELECT iniciado_en,estado INTO v_iniciado,v_estado FROM proyectos.proyecto WHERE id=v_proyecto;
   IF v_estado IN ('finalizado','cancelado') THEN RAISE EXCEPTION 'El plan cerrado se conserva' USING ERRCODE='23514'; END IF;
   IF v_iniciado IS NOT NULL THEN
     PERFORM identidad.exigir_permiso('proyecto','gestionar',v_proyecto);
     IF nullif(btrim(current_setting('app.motivo',true)),'') IS NULL THEN
       RAISE EXCEPTION 'Revisar el plan iniciado exige motivo registrado en auditoría' USING ERRCODE='23514';
     END IF;
   END IF;
 ELSIF TG_TABLE_NAME='proyecto' AND TG_OP='UPDATE' THEN
   IF NEW.solicitud_desarrollo_id<>OLD.solicitud_desarrollo_id THEN
     RAISE EXCEPTION 'El origen del proyecto es inmutable' USING ERRCODE='23514';
   END IF;
   IF ROW(NEW.version_cotizacion_id,NEW.importe_base_autorizado,NEW.tasa_impuesto_autorizada,NEW.moneda)
       IS DISTINCT FROM ROW(OLD.version_cotizacion_id,OLD.importe_base_autorizado,OLD.tasa_impuesto_autorizada,OLD.moneda)
       AND EXISTS(SELECT 1 FROM comercial.factura WHERE proyecto_id=OLD.id) THEN
     RAISE EXCEPTION 'La autorización económica se congela al iniciar facturación' USING ERRCODE='23514';
   END IF;
   IF NEW.estado='cancelado' AND EXISTS(SELECT 1 FROM comercial.factura WHERE proyecto_id=OLD.id AND estado='emitida') THEN
     RAISE EXCEPTION 'Resuelva la facturación vigente antes de cancelar el proyecto' USING ERRCODE='23514';
   END IF;
   IF OLD.iniciado_en IS NOT NULL AND ROW(NEW.alcance_acordado,NEW.inicio_planificado,NEW.fin_planificado)
     IS DISTINCT FROM ROW(OLD.alcance_acordado,OLD.inicio_planificado,OLD.fin_planificado) THEN
     PERFORM identidad.exigir_permiso('proyecto','gestionar',OLD.id);
     IF nullif(btrim(current_setting('app.motivo',true)),'') IS NULL THEN
       RAISE EXCEPTION 'La revisión del alcance exige motivo de auditoría' USING ERRCODE='23514';
     END IF;
   END IF;
 ELSIF TG_TABLE_NAME='solicitud_desarrollo' THEN
   -- Primero determinar tabla y evento; solo esta tabla tiene cliente_id.
   IF TG_OP='UPDATE' THEN
     IF NEW.cliente_id IS DISTINCT FROM OLD.cliente_id AND
        EXISTS(SELECT 1 FROM proyectos.proyecto WHERE solicitud_desarrollo_id=OLD.id) THEN
       RAISE EXCEPTION 'La titularidad de la solicitud aprobada es inmutable' USING ERRCODE='23514';
     END IF;
   END IF;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END $$;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['avance_proyecto','miembro_proyecto','etapa_proyecto','proyecto','solicitud_desarrollo'] LOOP
   EXECUTE format('CREATE TRIGGER proteger_datos_proyecto BEFORE INSERT OR UPDATE OR DELETE ON proyectos.%I FOR EACH ROW EXECUTE FUNCTION proyectos.proteger_datos()',t);
 END LOOP;
END $$;

-- Alta pública inicial: solo reutiliza una persona y cliente creados en la misma
-- transacción por el backend privado. No habilita tomar un identificador ajeno existente.
CREATE FUNCTION servicios.exigir_cliente_alta(p_cliente bigint) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF identidad.es_dba() THEN RETURN; END IF;
 IF EXISTS(SELECT 1 FROM identidad.cliente WHERE id=p_cliente AND activo AND persona_id=identidad.actor_persona_actual()) THEN RETURN; END IF;
 IF identidad.actor_persona_actual() IS NULL AND pg_has_role(session_user,'st_app','MEMBER') AND EXISTS(
   SELECT 1 FROM identidad.cliente c JOIN identidad.persona p ON p.id=c.persona_id WHERE c.id=p_cliente
   AND c.activo AND p.activo AND c.xmin::text=(pg_current_xact_id()::text::numeric % 4294967296)::text
   AND p.xmin::text=(pg_current_xact_id()::text::numeric % 4294967296)::text
 ) THEN RETURN; END IF;
 PERFORM identidad.exigir_permiso('cliente','gestionar',p_cliente);
END $$;

CREATE PROCEDURE servicios.registrar_equipo(p_cliente bigint,p_tipo text,p_descripcion text,p_marca text,p_modelo text,p_serie text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM servicios.exigir_cliente_alta(p_cliente);
 INSERT INTO servicios.equipo_cliente(cliente_id,tipo,descripcion,marca,modelo,numero_serie)
 VALUES(p_cliente,p_tipo,p_descripcion,p_marca,p_modelo,p_serie) RETURNING id INTO p_id;
END $$;

CREATE PROCEDURE servicios.solicitar_servicio(p_cliente bigint,p_oferta bigint,p_equipo bigint,p_necesidad text,p_alcance text,p_fecha timestamptz,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('solicitud_servicio','crear',NULL);
 PERFORM servicios.exigir_cliente_alta(p_cliente);
 IF NOT EXISTS(SELECT 1 FROM servicios.servicio_ofrecido WHERE id=p_oferta AND publicado) THEN
   RAISE EXCEPTION 'La oferta no está publicada' USING ERRCODE='23514'; END IF;
 PERFORM set_config('app.motivo','Solicitud técnica recibida',true);
 INSERT INTO servicios.solicitud_servicio(codigo,cliente_id,servicio_ofrecido_id,equipo_cliente_id,necesidad,alcance,fecha_preferida)
 VALUES('SOL-'||gen_random_uuid()::text,p_cliente,p_oferta,p_equipo,p_necesidad,p_alcance,p_fecha) RETURNING id INTO p_id;
END $$;

CREATE PROCEDURE servicios.cambiar_estado_solicitud(p_id bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('solicitud_servicio','gestionar',p_id);
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Indique el motivo' USING ERRCODE='22023'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 IF p_estado='cancelada' THEN
   IF EXISTS(SELECT 1 FROM servicios.orden_servicio WHERE solicitud_servicio_id=p_id AND estado='finalizada') THEN
     RAISE EXCEPTION 'Una atención finalizada no puede cancelarse' USING ERRCODE='23514'; END IF;
   UPDATE servicios.orden_servicio SET estado='cancelada' WHERE solicitud_servicio_id=p_id AND estado<>'cancelada';
   UPDATE servicios.cita_servicio SET estado='cancelada',motivo_cancelacion=p_motivo
     WHERE solicitud_servicio_id=p_id AND estado IN ('propuesta','confirmada');
 END IF;
 UPDATE servicios.solicitud_servicio SET estado=p_estado WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Solicitud inexistente' USING ERRCODE='P0002'; END IF;
END $$;

CREATE PROCEDURE servicios.aceptar_solicitud(p_solicitud bigint,p_importe numeric,p_tasa numeric,p_moneda text,p_version bigint,p_tipo_mantenimiento text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v_modalidad text; v_estado text;
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('solicitud_servicio','gestionar',p_solicitud);
 SELECT s.estado,f.modalidad INTO STRICT v_estado,v_modalidad FROM servicios.solicitud_servicio s
 JOIN servicios.servicio_ofrecido f ON f.id=s.servicio_ofrecido_id WHERE s.id=p_solicitud FOR UPDATE OF s;
 IF v_estado<>'en_evaluacion' THEN RAISE EXCEPTION 'La solicitud debe estar en evaluación' USING ERRCODE='23514'; END IF;
 PERFORM set_config('app.motivo','Solicitud aceptada y orden técnica creada',true);
 UPDATE servicios.solicitud_servicio SET estado='aceptada' WHERE id=p_solicitud;
 INSERT INTO servicios.orden_servicio(codigo,solicitud_servicio_id,version_cotizacion_id,importe_base_autorizado,tasa_impuesto_autorizada,moneda)
 VALUES('OT-'||gen_random_uuid()::text,p_solicitud,p_version,p_importe,p_tasa,p_moneda) RETURNING id INTO p_id;
 IF v_modalidad='reparacion' THEN INSERT INTO servicios.reparacion(orden_servicio_id) VALUES(p_id);
 ELSE INSERT INTO servicios.mantenimiento(orden_servicio_id,tipo_mantenimiento) VALUES(p_id,p_tipo_mantenimiento); END IF;
END $$;

CREATE PROCEDURE servicios.registrar_disponibilidad(p_empleado bigint,p_inicio timestamptz,p_fin timestamptz,p_observaciones text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('orden_servicio','gestionar',NULL);
 IF NOT identidad.empleado_habilitado(p_empleado,'orden_servicio') THEN RAISE EXCEPTION 'Técnico no habilitado' USING ERRCODE='23514'; END IF;
 INSERT INTO servicios.disponibilidad_tecnico(empleado_id,inicio,fin,observaciones)
 VALUES(p_empleado,p_inicio,p_fin,p_observaciones) RETURNING id INTO p_id;
END $$;

CREATE PROCEDURE servicios.editar_disponibilidad(p_id bigint,p_inicio timestamptz,p_fin timestamptz,p_habilitada boolean,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('orden_servicio','gestionar',NULL);
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE servicios.disponibilidad_tecnico SET inicio=p_inicio,fin=p_fin,habilitada=p_habilitada,observaciones=p_motivo WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Ventana inexistente' USING ERRCODE='P0002'; END IF;
END $$;

CREATE PROCEDURE servicios.programar_cita(p_solicitud bigint,p_tecnico bigint,p_inicio timestamptz,p_fin timestamptz,p_modalidad text,p_lugar text,p_confirmar boolean,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();
 IF p_confirmar THEN PERFORM identidad.exigir_permiso('solicitud_servicio','gestionar',p_solicitud);
 ELSE PERFORM identidad.exigir_permiso('solicitud_servicio','editar',p_solicitud); END IF;
 INSERT INTO servicios.cita_servicio(solicitud_servicio_id,tecnico_id,inicio,fin,modalidad_atencion,lugar,estado)
 VALUES(p_solicitud,p_tecnico,p_inicio,p_fin,p_modalidad,p_lugar,CASE WHEN p_confirmar THEN 'confirmada' ELSE 'propuesta' END) RETURNING id INTO p_id;
END $$;

CREATE PROCEDURE servicios.cambiar_estado_cita(p_id bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v_solicitud bigint; v_estado text;
BEGIN
 PERFORM identidad.bloquear_operacion();
 SELECT solicitud_servicio_id,estado INTO STRICT v_solicitud,v_estado FROM servicios.cita_servicio WHERE id=p_id FOR UPDATE;
 PERFORM identidad.exigir_permiso('solicitud_servicio','gestionar',v_solicitud);
 IF NOT ((v_estado='propuesta' AND p_estado IN ('confirmada','cancelada')) OR
         (v_estado='confirmada' AND p_estado IN ('realizada','cancelada'))) THEN
   RAISE EXCEPTION 'Transición de cita no permitida' USING ERRCODE='23514'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE servicios.cita_servicio SET estado=p_estado,motivo_cancelacion=CASE WHEN p_estado='cancelada' THEN p_motivo END WHERE id=p_id;
END $$;

CREATE PROCEDURE servicios.reprogramar_cita(p_anterior bigint,p_tecnico bigint,p_inicio timestamptz,p_fin timestamptz,p_motivo text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v_cita servicios.cita_servicio%ROWTYPE;
BEGIN
 PERFORM identidad.bloquear_operacion(); SELECT * INTO STRICT v_cita FROM servicios.cita_servicio WHERE id=p_anterior FOR UPDATE;
 PERFORM identidad.exigir_permiso('solicitud_servicio','gestionar',v_cita.solicitud_servicio_id);
 IF v_cita.estado NOT IN ('propuesta','confirmada') THEN RAISE EXCEPTION 'La cita no es reprogramable' USING ERRCODE='23514'; END IF;
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Indique motivo de reprogramación' USING ERRCODE='22023'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE servicios.cita_servicio SET estado='cancelada',motivo_cancelacion=p_motivo WHERE id=p_anterior;
 INSERT INTO servicios.cita_servicio(solicitud_servicio_id,tecnico_id,inicio,fin,modalidad_atencion,lugar,estado,sustituye_cita_id)
 VALUES(v_cita.solicitud_servicio_id,p_tecnico,p_inicio,p_fin,v_cita.modalidad_atencion,v_cita.lugar,'confirmada',p_anterior) RETURNING id INTO p_id;
END $$;

CREATE PROCEDURE servicios.asignar_tecnico(p_orden bigint,p_empleado bigint,p_funcion text,p_principal boolean,p_motivo text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v_ahora timestamptz; v_estado text;
BEGIN
 PERFORM identidad.bloquear_operacion(); v_ahora:=clock_timestamp(); PERFORM identidad.exigir_permiso('orden_servicio','gestionar',p_orden);
 SELECT estado INTO STRICT v_estado FROM servicios.orden_servicio WHERE id=p_orden FOR UPDATE;
 IF v_estado IN ('finalizada','cancelada') THEN RAISE EXCEPTION 'La orden está cerrada' USING ERRCODE='23514'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE servicios.asignacion_servicio SET termina_en=v_ahora WHERE orden_servicio_id=p_orden AND termina_en IS NULL
 AND (empleado_id=p_empleado OR (p_principal AND es_principal));
 INSERT INTO servicios.asignacion_servicio(orden_servicio_id,empleado_id,funcion,es_principal,inicia_en,actor_persona_id,actor_sistema)
 VALUES(p_orden,p_empleado,p_funcion,p_principal,v_ahora,identidad.actor_persona_actual(),identidad.actor_sistema_actual()) RETURNING id INTO p_id;
 IF v_estado='pendiente_asignacion' THEN UPDATE servicios.orden_servicio SET estado='asignada' WHERE id=p_orden; END IF;
END $$;

CREATE PROCEDURE servicios.retirar_tecnico(p_asignacion bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v_orden bigint;
BEGIN
 PERFORM identidad.bloquear_operacion(); SELECT orden_servicio_id INTO STRICT v_orden FROM servicios.asignacion_servicio WHERE id=p_asignacion;
 PERFORM identidad.exigir_permiso('orden_servicio','gestionar',v_orden); PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE servicios.asignacion_servicio SET termina_en=clock_timestamp() WHERE id=p_asignacion AND termina_en IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION 'Asignación ya cerrada' USING ERRCODE='23514'; END IF;
END $$;

CREATE PROCEDURE servicios.registrar_informe_reparacion(p_orden bigint,p_diagnostico text,p_falla text,p_solucion text,p_pruebas text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('orden_servicio','gestionar',p_orden);
 UPDATE servicios.reparacion SET diagnostico=p_diagnostico,falla_determinada=p_falla,solucion=p_solucion,resultado_pruebas=p_pruebas WHERE orden_servicio_id=p_orden;
 IF NOT FOUND THEN RAISE EXCEPTION 'Orden de reparación inexistente' USING ERRCODE='P0002'; END IF;
END $$;

CREATE PROCEDURE servicios.registrar_informe_mantenimiento(p_orden bigint,p_actividades text,p_hallazgos text,p_recomendaciones text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('orden_servicio','gestionar',p_orden);
 UPDATE servicios.mantenimiento SET actividades_realizadas=p_actividades,hallazgos=p_hallazgos,recomendaciones=p_recomendaciones WHERE orden_servicio_id=p_orden;
 IF NOT FOUND THEN RAISE EXCEPTION 'Orden de mantenimiento inexistente' USING ERRCODE='P0002'; END IF;
END $$;

CREATE PROCEDURE servicios.cambiar_estado_orden(p_id bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('orden_servicio','gestionar',p_id);
 IF p_estado='finalizada' THEN RAISE EXCEPTION 'Utilice cerrar_servicio con el informe completo' USING ERRCODE='22023'; END IF;
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Indique motivo' USING ERRCODE='22023'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE servicios.orden_servicio SET estado=p_estado,iniciada_en=CASE WHEN p_estado='en_ejecucion' THEN coalesce(iniciada_en,clock_timestamp()) ELSE iniciada_en END WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Orden inexistente' USING ERRCODE='P0002'; END IF;
END $$;

CREATE PROCEDURE servicios.cerrar_servicio(p_id bigint,p_resumen text,p_observaciones text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('orden_servicio','gestionar',p_id);
 PERFORM set_config('app.motivo','Servicio finalizado: '||coalesce(p_resumen,''),true);
 UPDATE servicios.orden_servicio SET estado='finalizada',finalizada_en=clock_timestamp(),resumen_trabajo=p_resumen,observaciones_cierre=p_observaciones WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Orden inexistente' USING ERRCODE='P0002'; END IF;
END $$;

CREATE PROCEDURE servicios.calificar_servicio(p_orden bigint,p_puntuacion smallint,p_comentario text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('orden_servicio','calificar',p_orden);
 INSERT INTO servicios.calificacion_servicio(orden_servicio_id,autor_persona_id,puntuacion,comentario)
 VALUES(p_orden,identidad.actor_persona_actual(),p_puntuacion,p_comentario)
 ON CONFLICT (orden_servicio_id) DO UPDATE SET puntuacion=EXCLUDED.puntuacion,comentario=EXCLUDED.comentario
 WHERE servicios.calificacion_servicio.autor_persona_id=EXCLUDED.autor_persona_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'La valoración pertenece a otro autor' USING ERRCODE='42501'; END IF;
END $$;

CREATE PROCEDURE proyectos.solicitar_desarrollo(p_cliente bigint,p_necesidades text,p_objetivos text,p_alcance text,p_presupuesto numeric,p_moneda text,p_fecha date,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('solicitud_desarrollo','crear',NULL);
 PERFORM servicios.exigir_cliente_alta(p_cliente);
 PERFORM set_config('app.motivo','Solicitud de desarrollo recibida',true);
 INSERT INTO proyectos.solicitud_desarrollo(codigo,cliente_id,necesidades,objetivos,alcance_deseado,presupuesto_orientativo,moneda_orientativa,fecha_deseada)
 VALUES('SD-'||gen_random_uuid()::text,p_cliente,p_necesidades,p_objetivos,p_alcance,p_presupuesto,p_moneda,p_fecha) RETURNING id INTO p_id;
END $$;

CREATE PROCEDURE proyectos.cambiar_estado_solicitud(p_id bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('solicitud_desarrollo','gestionar',p_id);
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Indique motivo' USING ERRCODE='22023'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 IF p_estado='cancelada' THEN
   IF EXISTS(SELECT 1 FROM proyectos.proyecto WHERE solicitud_desarrollo_id=p_id AND estado='finalizado') THEN
     RAISE EXCEPTION 'El proyecto finalizado se conserva' USING ERRCODE='23514'; END IF;
   UPDATE proyectos.proyecto SET estado='cancelado' WHERE solicitud_desarrollo_id=p_id AND estado<>'cancelado';
 END IF;
 UPDATE proyectos.solicitud_desarrollo SET estado=p_estado WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Solicitud inexistente' USING ERRCODE='P0002'; END IF;
END $$;

CREATE PROCEDURE proyectos.aprobar_solicitud(p_solicitud bigint,p_nombre text,p_descripcion text,p_alcance text,p_importe numeric,p_tasa numeric,p_moneda text,p_version bigint,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v_estado text;
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('solicitud_desarrollo','gestionar',p_solicitud);
 SELECT estado INTO STRICT v_estado FROM proyectos.solicitud_desarrollo WHERE id=p_solicitud FOR UPDATE;
 IF v_estado<>'en_evaluacion' THEN RAISE EXCEPTION 'La solicitud debe estar en evaluación' USING ERRCODE='23514'; END IF;
 PERFORM set_config('app.motivo','Solicitud aprobada y proyecto creado',true);
 UPDATE proyectos.solicitud_desarrollo SET estado='aprobada' WHERE id=p_solicitud;
 INSERT INTO proyectos.proyecto(codigo,solicitud_desarrollo_id,nombre,descripcion,alcance_acordado,version_cotizacion_id,importe_base_autorizado,tasa_impuesto_autorizada,moneda)
 VALUES('PRY-'||gen_random_uuid()::text,p_solicitud,p_nombre,p_descripcion,p_alcance,p_version,p_importe,p_tasa,p_moneda) RETURNING id INTO p_id;
END $$;

CREATE PROCEDURE proyectos.asignar_miembro(p_proyecto bigint,p_empleado bigint,p_funcion text,p_principal boolean,p_motivo text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v_ahora timestamptz; v_estado text;
BEGIN
 PERFORM identidad.bloquear_operacion(); v_ahora:=clock_timestamp(); PERFORM identidad.exigir_permiso('proyecto','gestionar',p_proyecto);
 SELECT estado INTO STRICT v_estado FROM proyectos.proyecto WHERE id=p_proyecto FOR UPDATE;
 IF v_estado IN ('finalizado','cancelado') THEN RAISE EXCEPTION 'Proyecto cerrado' USING ERRCODE='23514'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE proyectos.miembro_proyecto SET termina_en=v_ahora WHERE proyecto_id=p_proyecto AND termina_en IS NULL
 AND (empleado_id=p_empleado OR (p_principal AND es_principal));
 INSERT INTO proyectos.miembro_proyecto(proyecto_id,empleado_id,funcion,es_principal,inicia_en,actor_persona_id,actor_sistema)
 VALUES(p_proyecto,p_empleado,p_funcion,p_principal,v_ahora,identidad.actor_persona_actual(),identidad.actor_sistema_actual()) RETURNING id INTO p_id;
END $$;

CREATE PROCEDURE proyectos.retirar_miembro(p_miembro bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v_proyecto bigint;
BEGIN
 PERFORM identidad.bloquear_operacion(); SELECT proyecto_id INTO STRICT v_proyecto FROM proyectos.miembro_proyecto WHERE id=p_miembro;
 PERFORM identidad.exigir_permiso('proyecto','gestionar',v_proyecto); PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE proyectos.miembro_proyecto SET termina_en=clock_timestamp() WHERE id=p_miembro AND termina_en IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION 'Miembro ya retirado' USING ERRCODE='23514'; END IF;
END $$;

CREATE PROCEDURE proyectos.definir_etapa(p_proyecto bigint,p_nombre text,p_descripcion text,p_orden integer,p_peso numeric,p_inicio date,p_fin date,p_motivo text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('proyecto','gestionar',p_proyecto);
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Indique motivo de definición o revisión' USING ERRCODE='22023'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 IF p_id IS NULL THEN
   INSERT INTO proyectos.etapa_proyecto(proyecto_id,nombre,descripcion,orden,peso,inicio_planificado,fin_planificado)
   VALUES(p_proyecto,p_nombre,p_descripcion,p_orden,p_peso,p_inicio,p_fin) RETURNING id INTO p_id;
 ELSE
   UPDATE proyectos.etapa_proyecto SET nombre=p_nombre,descripcion=p_descripcion,orden=p_orden,peso=p_peso,inicio_planificado=p_inicio,fin_planificado=p_fin
   WHERE id=p_id AND proyecto_id=p_proyecto;
   IF NOT FOUND THEN RAISE EXCEPTION 'Etapa inexistente o de otro proyecto' USING ERRCODE='P0002'; END IF;
 END IF;
END $$;

CREATE PROCEDURE proyectos.revisar_alcance(p_id bigint,p_alcance text,p_inicio date,p_fin date,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('proyecto','gestionar',p_id);
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Indique motivo de revisión' USING ERRCODE='22023'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE proyectos.proyecto SET alcance_acordado=p_alcance,inicio_planificado=p_inicio,fin_planificado=p_fin
 WHERE id=p_id AND estado NOT IN ('finalizado','cancelado');
 IF NOT FOUND THEN RAISE EXCEPTION 'Proyecto inexistente o cerrado' USING ERRCODE='23514'; END IF;
END $$;

CREATE PROCEDURE proyectos.cambiar_estado_proyecto(p_id bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('proyecto','gestionar',p_id);
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Indique motivo' USING ERRCODE='22023'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE proyectos.proyecto SET estado=p_estado,
 iniciado_en=CASE WHEN p_estado='en_ejecucion' THEN coalesce(iniciado_en,clock_timestamp()) ELSE iniciado_en END,
 finalizado_en=CASE WHEN p_estado='finalizado' THEN clock_timestamp() ELSE finalizado_en END WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Proyecto inexistente' USING ERRCODE='P0002'; END IF;
END $$;

CREATE PROCEDURE proyectos.registrar_avance(p_etapa bigint,p_miembro bigint,p_porcentaje numeric,p_descripcion text,p_observaciones text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v_proyecto bigint; v_persona bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();
 SELECT proyecto_id INTO STRICT v_proyecto FROM proyectos.etapa_proyecto WHERE id=p_etapa;
 PERFORM identidad.exigir_permiso('proyecto','gestionar',v_proyecto);
 SELECT e.persona_id INTO STRICT v_persona FROM proyectos.miembro_proyecto m JOIN identidad.empleado e ON e.id=m.empleado_id WHERE m.id=p_miembro;
 IF v_persona IS DISTINCT FROM identidad.actor_persona_actual() THEN
   RAISE EXCEPTION 'El autor del avance debe ser el miembro autenticado' USING ERRCODE='42501'; END IF;
 INSERT INTO proyectos.avance_proyecto(etapa_proyecto_id,miembro_proyecto_id,porcentaje,descripcion,observaciones)
 VALUES(p_etapa,p_miembro,p_porcentaje,p_descripcion,p_observaciones) RETURNING id INTO p_id;
END $$;

-- Funciones de lectura: RETURN produce datos; los procedimientos anteriores modifican
-- un agregado dentro de la transacción de CALL, sin COMMIT interno.
CREATE FUNCTION proyectos.obtener_avance(p_proyecto bigint) RETURNS numeric
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v_avance numeric;
BEGIN
 PERFORM identidad.exigir_permiso('proyecto','leer',p_proyecto);
 SELECT coalesce(round(sum(e.peso*coalesce(a.porcentaje,0))/nullif(sum(e.peso),0),2),0)
 INTO v_avance FROM proyectos.etapa_proyecto e
 LEFT JOIN LATERAL(SELECT porcentaje FROM proyectos.avance_proyecto WHERE etapa_proyecto_id=e.id ORDER BY registrado_en DESC,id DESC LIMIT 1) a ON true
 WHERE e.proyecto_id=p_proyecto;
 RETURN v_avance;
END $$;

CREATE VIEW servicios.v_servicios_publicados WITH(security_invoker=true) AS
SELECT id,codigo,nombre,descripcion,modalidad,duracion_estimada_min,precio_referencia,moneda
FROM servicios.servicio_ofrecido WHERE publicado;

CREATE VIEW servicios.v_servicios_activos WITH(security_invoker=true) AS
SELECT o.id,o.codigo,s.cliente_id,f.nombre AS servicio,f.modalidad,o.estado,o.iniciada_en,
 a.empleado_id AS responsable_principal,o.created_at
FROM servicios.orden_servicio o JOIN servicios.solicitud_servicio s ON s.id=o.solicitud_servicio_id
JOIN servicios.servicio_ofrecido f ON f.id=s.servicio_ofrecido_id
LEFT JOIN servicios.asignacion_servicio a ON a.orden_servicio_id=o.id AND a.es_principal AND a.termina_en IS NULL
WHERE o.estado NOT IN ('finalizada','cancelada');

CREATE VIEW proyectos.v_avance_etapa WITH(security_invoker=true) AS
SELECT e.id AS etapa_id,e.proyecto_id,e.nombre,e.orden,e.peso,coalesce(a.porcentaje,0) AS porcentaje,
 a.registrado_en AS ultimo_reporte_en,a.descripcion AS ultimo_reporte
FROM proyectos.etapa_proyecto e
LEFT JOIN LATERAL(SELECT porcentaje,registrado_en,descripcion FROM proyectos.avance_proyecto
 WHERE etapa_proyecto_id=e.id ORDER BY registrado_en DESC,id DESC LIMIT 1) a ON true;

CREATE VIEW proyectos.v_avance_proyecto WITH(security_invoker=true) AS
SELECT p.id,p.codigo,p.nombre,s.cliente_id,p.estado,count(e.etapa_id) AS cantidad_etapas,
 coalesce(round(sum(e.peso*e.porcentaje)/nullif(sum(e.peso),0),2),0) AS porcentaje_avance
FROM proyectos.proyecto p JOIN proyectos.solicitud_desarrollo s ON s.id=p.solicitud_desarrollo_id
LEFT JOIN proyectos.v_avance_etapa e ON e.proyecto_id=p.id
GROUP BY p.id,p.codigo,p.nombre,s.cliente_id,p.estado;

COMMENT ON FUNCTION proyectos.obtener_avance(bigint) IS 'Promedio de los últimos avances por etapa, ponderado por peso; etapas sin reportes valen cero. No almacena porcentaje redundante.';
COMMENT ON FUNCTION servicios.validar_integridad() IS 'T01-T05: validación diferible del estado final del módulo y sus padres; adecuada al volumen inicial, requiere acotar a agregados para escalar.';

-- MÓDULO 40_comunicacion
-- Fases 5-8, T10/T11/T12. Metadatos y cola transaccional; no envía archivos ni mensajes externos.
-- Dependencias: identidad.bloquear_operacion/exigir_permiso/actor_*_actual/persona_*acceder.

CREATE FUNCTION comunicacion.contexto_de_fila(p_fila jsonb, OUT recurso text, OUT registro_id bigint)
RETURNS record LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog,pg_temp AS $$
DECLARE k text;
BEGIN
  FOREACH k IN ARRAY ARRAY['pedido','solicitud_servicio','orden_servicio','solicitud_cotizacion','cotizacion','solicitud_desarrollo','proyecto','factura','mensaje'] LOOP
    IF p_fila ->> (k||'_id') IS NOT NULL THEN
      recurso:=k; registro_id:=(p_fila ->> (k||'_id'))::bigint; RETURN;
    END IF;
  END LOOP;
  recurso:=NULL; registro_id:=NULL;
END $$;

CREATE FUNCTION comunicacion.puede_leer_archivo(p_archivo_id bigint)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE f comunicacion.archivo%ROWTYPE; a record; ctx record; v_conversacion bigint;
BEGIN
  SELECT * INTO f FROM comunicacion.archivo WHERE id=p_archivo_id;
  IF NOT FOUND OR f.estado<>'validado' THEN RETURN false; END IF;
  IF f.visibilidad='publico' THEN RETURN true; END IF;
  IF f.actor_persona_id IS NOT NULL AND f.actor_persona_id=identidad.actor_persona_actual() THEN RETURN true; END IF;
  FOR a IN SELECT * FROM comunicacion.adjunto WHERE archivo_id=p_archivo_id LOOP
    SELECT * INTO ctx FROM comunicacion.contexto_de_fila(to_jsonb(a));
    IF ctx.recurso='mensaje' THEN
      SELECT p.conversacion_id INTO v_conversacion FROM comunicacion.mensaje m
      JOIN comunicacion.participante_conversacion p ON p.id=m.autor_participante_id
      WHERE m.id=ctx.registro_id AND NOT m.retirado;
      IF v_conversacion IS NOT NULL AND identidad.puede_acceder('conversacion',v_conversacion,
        CASE WHEN a.visibilidad='interno' THEN 'gestionar' ELSE 'leer' END) THEN RETURN true; END IF;
    ELSIF identidad.puede_acceder(ctx.recurso,ctx.registro_id,
                 CASE WHEN a.visibilidad='interno' THEN 'gestionar' ELSE 'leer' END) THEN RETURN true;
    END IF;
  END LOOP;
  FOR a IN SELECT factura_id FROM comercial.comprobante_factura WHERE archivo_id=p_archivo_id LOOP
    IF identidad.puede_acceder('factura',a.factura_id,'leer') THEN RETURN true; END IF;
  END LOOP;
  RETURN false;
END $$;

CREATE FUNCTION comunicacion.validar_integridad()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
  IF EXISTS(SELECT 1 FROM comunicacion.conversacion c WHERE
    NOT EXISTS(SELECT 1 FROM comunicacion.participante_conversacion p WHERE p.conversacion_id=c.id)
    OR (c.estado='abierta' AND NOT EXISTS(SELECT 1 FROM comunicacion.participante_conversacion p WHERE p.conversacion_id=c.id AND p.salio_en IS NULL))) THEN
    RAISE EXCEPTION 'T10: conversación sin participantes, o abierta sin participante vigente' USING ERRCODE='23514';
  END IF;
  IF EXISTS(SELECT 1 FROM comunicacion.mensaje m JOIN comunicacion.participante_conversacion p ON p.id=m.autor_participante_id
    WHERE m.enviado_en<p.incorporado_en OR (p.salio_en IS NOT NULL AND m.enviado_en>=p.salio_en)
    OR (m.contenido IS NULL AND NOT EXISTS(SELECT 1 FROM comunicacion.adjunto a JOIN comunicacion.archivo f ON f.id=a.archivo_id
      WHERE a.mensaje_id=m.id AND f.estado='validado'))) THEN
    RAISE EXCEPTION 'T10: autor no vigente al enviar o mensaje sin texto/archivo válido' USING ERRCODE='23514';
  END IF;
  IF EXISTS(SELECT 1 FROM comunicacion.lectura_mensaje l JOIN comunicacion.mensaje m ON m.id=l.mensaje_id
    JOIN comunicacion.participante_conversacion a ON a.id=m.autor_participante_id
    JOIN comunicacion.participante_conversacion p ON p.id=l.participante_id
    WHERE p.conversacion_id<>a.conversacion_id OR l.leido_en<m.enviado_en OR l.leido_en<p.incorporado_en
      OR (p.salio_en IS NOT NULL AND l.leido_en>=p.salio_en)) THEN
    RAISE EXCEPTION 'T10: lectura fuera de conversación o del intervalo de participación' USING ERRCODE='23514';
  END IF;
  IF EXISTS(SELECT 1 FROM comunicacion.adjunto a JOIN comunicacion.archivo f ON f.id=a.archivo_id
    WHERE f.estado<>'validado' OR f.visibilidad<>'privado')
    OR EXISTS(SELECT 1 FROM comercial.comprobante_factura c JOIN comunicacion.archivo f ON f.id=c.archivo_id
    WHERE f.estado<>'validado' OR f.visibilidad<>'privado') THEN
    RAISE EXCEPTION 'T11: adjuntos/comprobantes requieren archivo validado y privado' USING ERRCODE='23514';
  END IF;
  IF EXISTS(SELECT 1 FROM inventario.producto_imagen i JOIN comunicacion.archivo f ON f.id=i.archivo_id
    WHERE f.estado<>'validado' OR f.visibilidad<>'publico' OR f.tipo_contenido NOT LIKE 'image/%') THEN
    RAISE EXCEPTION 'T11: imagen de catálogo requiere archivo validado, público y de imagen' USING ERRCODE='23514';
  END IF;
  IF EXISTS(SELECT 1 FROM comunicacion.notificacion n JOIN comercial.version_cotizacion v ON v.id=n.version_cotizacion_id
    WHERE n.cotizacion_id IS DISTINCT FROM v.cotizacion_id) THEN
    RAISE EXCEPTION 'T12: versión ajena al contexto de cotización' USING ERRCODE='23514';
  END IF;
END $$;

CREATE FUNCTION comunicacion.validar_integridad_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
  PERFORM identidad.bloquear_operacion();
  PERFORM comunicacion.validar_integridad();
  RETURN NULL;
END $$;

CREATE FUNCTION comunicacion.proteger_fila()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE c comunicacion.conversacion%ROWTYPE; p comunicacion.participante_conversacion%ROWTYPE;
        ctx record; v_persona bigint; anterior jsonb; nuevo jsonb;
BEGIN
  PERFORM identidad.bloquear_operacion();
  IF TG_OP='DELETE' THEN
    IF TG_TABLE_NAME IN ('conversacion','participante_conversacion','mensaje','lectura_mensaje','notificacion','entrega_notificacion') THEN
      RAISE EXCEPTION 'T10/T12: se conserva el historial de %',TG_TABLE_NAME USING ERRCODE='23514';
    END IF;
    RETURN OLD;
  END IF;
  IF TG_OP='UPDATE' THEN
    IF to_jsonb(NEW)->'id' IS DISTINCT FROM to_jsonb(OLD)->'id' THEN
      RAISE EXCEPTION 'No se reasigna la identidad de %',TG_TABLE_NAME USING ERRCODE='23514';
    END IF;
    IF TG_TABLE_NAME='conversacion' THEN
      SELECT * INTO ctx FROM comunicacion.contexto_de_fila(to_jsonb(OLD));
      IF (to_jsonb(NEW)-ARRAY['asunto','estado','updated_at']) IS DISTINCT FROM
         (to_jsonb(OLD)-ARRAY['asunto','estado','updated_at']) THEN
        RAISE EXCEPTION 'T10: contexto y creación de conversación inmutables' USING ERRCODE='23514';
      END IF;
    ELSIF TG_TABLE_NAME='participante_conversacion' THEN
      IF (NEW.conversacion_id,NEW.persona_id,NEW.incorporado_en) IS DISTINCT FROM (OLD.conversacion_id,OLD.persona_id,OLD.incorporado_en)
       OR (OLD.salio_en IS NOT NULL AND NEW.salio_en IS DISTINCT FROM OLD.salio_en) THEN
        RAISE EXCEPTION 'T10: no reasignar/reabrir una participación ni cambiar su intervalo pasado' USING ERRCODE='23514';
      END IF;
    ELSIF TG_TABLE_NAME='mensaje' THEN
      IF (NEW.autor_participante_id,NEW.enviado_en) IS DISTINCT FROM (OLD.autor_participante_id,OLD.enviado_en)
       OR (OLD.retirado AND NOT NEW.retirado) THEN
        RAISE EXCEPTION 'T10: autor/fecha inmutables y retiro irreversible' USING ERRCODE='23514';
      END IF;
    ELSIF TG_TABLE_NAME='lectura_mensaje' THEN
      IF NEW IS DISTINCT FROM OLD THEN RAISE EXCEPTION 'T10: la primera lectura es inmutable' USING ERRCODE='23514'; END IF;
    ELSIF TG_TABLE_NAME='adjunto' THEN
      IF (to_jsonb(NEW)-'descripcion') IS DISTINCT FROM (to_jsonb(OLD)-'descripcion') THEN
        RAISE EXCEPTION 'T11: asociación inmutable; crear una asociación nueva autorizada' USING ERRCODE='23514';
      END IF;
    ELSIF TG_TABLE_NAME='archivo' THEN
      IF (NEW.actor_persona_id,NEW.actor_sistema,NEW.created_at) IS DISTINCT FROM (OLD.actor_persona_id,OLD.actor_sistema,OLD.created_at) THEN
        RAISE EXCEPTION 'T11: no reasignar cargador ni creación del archivo' USING ERRCODE='23514';
      END IF;
      IF OLD.estado='validado' AND
         (NEW.almacen,NEW.clave_objeto,NEW.tipo_contenido,NEW.tamano_bytes,NEW.sha256) IS DISTINCT FROM
         (OLD.almacen,OLD.clave_objeto,OLD.tipo_contenido,OLD.tamano_bytes,OLD.sha256) THEN
        RAISE EXCEPTION 'T11: un objeto validado no se reemplaza silenciosamente; registrar otro archivo' USING ERRCODE='23514';
      END IF;
      IF NEW.visibilidad IS DISTINCT FROM OLD.visibilidad AND
        (EXISTS(SELECT 1 FROM comunicacion.adjunto WHERE archivo_id=OLD.id)
         OR EXISTS(SELECT 1 FROM comercial.comprobante_factura WHERE archivo_id=OLD.id)
         OR EXISTS(SELECT 1 FROM inventario.producto_imagen WHERE archivo_id=OLD.id)) THEN
        RAISE EXCEPTION 'T11: archivo asociado no cambia audiencia; copiar en un objeto separado' USING ERRCODE='23514';
      END IF;
    ELSIF TG_TABLE_NAME='notificacion' THEN
      IF (to_jsonb(NEW)-'leida_en') IS DISTINCT FROM (to_jsonb(OLD)-'leida_en')
       OR (OLD.leida_en IS NOT NULL AND NEW.leida_en IS DISTINCT FROM OLD.leida_en) THEN
        RAISE EXCEPTION 'T12: notificación inmutable salvo primera lectura' USING ERRCODE='23514';
      END IF;
    ELSIF TG_TABLE_NAME='entrega_notificacion' THEN
      IF (NEW.notificacion_id,NEW.canal,NEW.destino,NEW.numero_intento,NEW.idempotencia_id,NEW.created_at)
        IS DISTINCT FROM (OLD.notificacion_id,OLD.canal,OLD.destino,OLD.numero_intento,OLD.idempotencia_id,OLD.created_at) THEN
        RAISE EXCEPTION 'T12: destino y clave de intento inmutables' USING ERRCODE='23514';
      END IF;
      IF OLD.estado<>NEW.estado AND NOT
        ((OLD.estado='pendiente' AND NEW.estado='enviando') OR
         (OLD.estado='enviando' AND NEW.estado IN ('enviada','fallida')) OR
         (OLD.estado='enviada' AND NEW.estado IN ('entregada','fallida'))) THEN
        RAISE EXCEPTION 'T12: transición de intento no permitida: % -> %',OLD.estado,NEW.estado USING ERRCODE='23514';
      END IF;
      IF OLD.estado IN ('entregada','fallida') AND (to_jsonb(NEW)-'updated_at') IS DISTINCT FROM (to_jsonb(OLD)-'updated_at') THEN
        RAISE EXCEPTION 'T12: intento terminado se conserva; reintentar crea otro' USING ERRCODE='23514';
      END IF;
    END IF;
  END IF;
  IF TG_OP='INSERT' AND TG_TABLE_NAME='mensaje' THEN
    SELECT * INTO p FROM comunicacion.participante_conversacion WHERE id=NEW.autor_participante_id;
    SELECT * INTO c FROM comunicacion.conversacion WHERE id=p.conversacion_id;
    IF c.estado IS DISTINCT FROM 'abierta' OR p.salio_en IS NOT NULL THEN
      RAISE EXCEPTION 'T10: enviar requiere conversación abierta y participación activa' USING ERRCODE='23514';
    END IF;
  ELSIF TG_OP='INSERT' AND TG_TABLE_NAME='participante_conversacion' THEN
    SELECT * INTO c FROM comunicacion.conversacion WHERE id=NEW.conversacion_id;
    SELECT * INTO ctx FROM comunicacion.contexto_de_fila(to_jsonb(c));
    IF c.estado IS DISTINCT FROM 'abierta' OR
       (ctx.recurso IS NOT NULL AND NOT identidad.persona_puede_acceder(NEW.persona_id,ctx.recurso,ctx.registro_id,'leer')) THEN
      RAISE EXCEPTION 'T10: participante sin acceso al contexto, o conversación cerrada' USING ERRCODE='23514';
    END IF;
  ELSIF TG_OP='INSERT' AND TG_TABLE_NAME='notificacion' THEN
    SELECT persona_id INTO v_persona FROM identidad.usuario WHERE id=NEW.destinatario_usuario_id;
    SELECT * INTO ctx FROM comunicacion.contexto_de_fila(to_jsonb(NEW));
    IF ctx.recurso IS NOT NULL AND NOT identidad.persona_puede_acceder(v_persona,ctx.recurso,ctx.registro_id,'leer') THEN
      RAISE EXCEPTION 'T12: destinatario sin acceso al proceso notificado' USING ERRCODE='23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;

CREATE PROCEDURE comunicacion.crear_conversacion(p_asunto text,p_recurso text,p_registro_id bigint,
 p_participantes bigint[],INOUT p_conversacion_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE persona bigint; v_actor bigint;
BEGIN
  PERFORM identidad.bloquear_operacion();
  IF p_recurso IS NOT NULL THEN
    IF p_recurso NOT IN ('pedido','solicitud_servicio','orden_servicio','solicitud_cotizacion','cotizacion','solicitud_desarrollo','proyecto') OR p_registro_id IS NULL THEN
      RAISE EXCEPTION 'Contexto de conversación inválido' USING ERRCODE='22023';
    END IF;
    PERFORM identidad.exigir_permiso(p_recurso,'leer',p_registro_id);
  ELSE
    IF p_registro_id IS NOT NULL THEN RAISE EXCEPTION 'Id sin contexto' USING ERRCODE='22023'; END IF;
    PERFORM identidad.exigir_permiso('conversacion','crear',NULL);
  END IF;
  v_actor:=identidad.actor_persona_actual();
  IF coalesce(cardinality(p_participantes),0)=0 OR array_position(p_participantes,NULL) IS NOT NULL THEN
    RAISE EXCEPTION 'Debe proporcionar participantes válidos' USING ERRCODE='22023';
  END IF;
  IF v_actor IS NOT NULL AND NOT (v_actor=ANY(p_participantes)) THEN
    RAISE EXCEPTION 'El creador debe participar en la conversación' USING ERRCODE='42501';
  END IF;
  INSERT INTO comunicacion.conversacion(asunto,pedido_id,solicitud_servicio_id,orden_servicio_id,solicitud_cotizacion_id,cotizacion_id,solicitud_desarrollo_id,proyecto_id)
  VALUES(p_asunto,CASE WHEN p_recurso='pedido' THEN p_registro_id END,CASE WHEN p_recurso='solicitud_servicio' THEN p_registro_id END,
    CASE WHEN p_recurso='orden_servicio' THEN p_registro_id END,CASE WHEN p_recurso='solicitud_cotizacion' THEN p_registro_id END,
    CASE WHEN p_recurso='cotizacion' THEN p_registro_id END,CASE WHEN p_recurso='solicitud_desarrollo' THEN p_registro_id END,
    CASE WHEN p_recurso='proyecto' THEN p_registro_id END) RETURNING id INTO p_conversacion_id;
  FOREACH persona IN ARRAY p_participantes LOOP
    INSERT INTO comunicacion.participante_conversacion(conversacion_id,persona_id,funcion,incorporado_en)
    VALUES(p_conversacion_id,persona,'participante',clock_timestamp());
  END LOOP;
END $$;

CREATE PROCEDURE comunicacion.gestionar_participante(p_conversacion_id bigint,p_persona_id bigint,p_accion text,p_funcion text DEFAULT 'participante')
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
  PERFORM identidad.bloquear_operacion();
  PERFORM identidad.exigir_permiso('conversacion','gestionar',p_conversacion_id);
  IF p_accion='agregar' THEN
    INSERT INTO comunicacion.participante_conversacion(conversacion_id,persona_id,funcion,incorporado_en)
    VALUES(p_conversacion_id,p_persona_id,p_funcion,clock_timestamp());
  ELSIF p_accion='retirar' THEN
    UPDATE comunicacion.participante_conversacion SET salio_en=clock_timestamp()
    WHERE conversacion_id=p_conversacion_id AND persona_id=p_persona_id AND salio_en IS NULL;
    IF NOT FOUND THEN RAISE EXCEPTION 'Participante activo inexistente' USING ERRCODE='P0002'; END IF;
  ELSE RAISE EXCEPTION 'Acción de participante inválida' USING ERRCODE='22023'; END IF;
END $$;

CREATE PROCEDURE comunicacion.cerrar_conversacion(p_conversacion_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
  PERFORM identidad.bloquear_operacion();
  PERFORM identidad.exigir_permiso('conversacion','gestionar',p_conversacion_id);
  UPDATE comunicacion.conversacion SET estado='cerrada' WHERE id=p_conversacion_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Conversación inexistente' USING ERRCODE='P0002'; END IF;
END $$;

CREATE PROCEDURE comunicacion.registrar_archivo(p_nombre text,p_almacen text,p_clave text,p_tipo text,p_bytes bigint,
 INOUT p_archivo_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
  PERFORM identidad.bloquear_operacion();
  PERFORM identidad.exigir_permiso('archivo','crear',NULL);
  INSERT INTO comunicacion.archivo(nombre_original,almacen,clave_objeto,tipo_contenido,tamano_bytes,actor_persona_id,actor_sistema)
  VALUES(p_nombre,p_almacen,p_clave,p_tipo,p_bytes,identidad.actor_persona_actual(),identidad.actor_sistema_actual()) RETURNING id INTO p_archivo_id;
END $$;

CREATE PROCEDURE comunicacion.validar_archivo(p_archivo_id bigint,p_estado text,p_sha256 bytea,p_publico boolean DEFAULT false)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
  PERFORM identidad.bloquear_operacion();
  PERFORM identidad.exigir_permiso('archivo','gestionar',p_archivo_id);
  IF p_estado NOT IN ('validado','rechazado') OR p_estado IS NULL OR p_publico IS NULL OR
    (p_estado='validado' AND (p_sha256 IS NULL OR octet_length(p_sha256)<>32)) THEN
    RAISE EXCEPTION 'Resultado de validación inválido; archivo validado exige huella de 32 bytes' USING ERRCODE='22023';
  END IF;
  UPDATE comunicacion.archivo SET estado=p_estado,sha256=p_sha256,visibilidad=CASE WHEN p_publico THEN 'publico' ELSE 'privado' END
  WHERE id=p_archivo_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Archivo inexistente' USING ERRCODE='P0002'; END IF;
END $$;

CREATE PROCEDURE comunicacion.adjuntar_archivo(p_archivo_id bigint,p_recurso text,p_registro_id bigint,p_descripcion text DEFAULT NULL,
 p_visibilidad text DEFAULT 'compartido',INOUT p_adjunto_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE conv bigint; autor bigint; f comunicacion.archivo%ROWTYPE;
BEGIN
  PERFORM identidad.bloquear_operacion();
  IF p_recurso IS NULL OR p_registro_id IS NULL OR p_recurso NOT IN
    ('mensaje','pedido','solicitud_servicio','orden_servicio','solicitud_cotizacion','cotizacion','solicitud_desarrollo','proyecto','factura') THEN
    RAISE EXCEPTION 'Contexto de adjunto inválido' USING ERRCODE='22023';
  END IF;
  IF p_recurso='mensaje' THEN
    SELECT p.conversacion_id,p.persona_id INTO conv,autor FROM comunicacion.mensaje m
    JOIN comunicacion.participante_conversacion p ON p.id=m.autor_participante_id WHERE m.id=p_registro_id;
    PERFORM identidad.exigir_permiso('conversacion',CASE WHEN p_visibilidad='interno' THEN 'gestionar' ELSE 'leer' END,conv);
    IF autor IS DISTINCT FROM identidad.actor_persona_actual() THEN PERFORM identidad.exigir_permiso('conversacion','gestionar',conv); END IF;
  ELSE
    PERFORM identidad.exigir_permiso(p_recurso,CASE WHEN p_visibilidad='interno' THEN 'gestionar' ELSE 'leer' END,p_registro_id);
  END IF;
  SELECT * INTO f FROM comunicacion.archivo WHERE id=p_archivo_id;
  IF NOT FOUND OR f.estado<>'validado' OR f.visibilidad<>'privado' THEN
    RAISE EXCEPTION 'Adjuntar requiere archivo validado y privado' USING ERRCODE='23514';
  END IF;
  IF NOT comunicacion.puede_leer_archivo(p_archivo_id) THEN PERFORM identidad.exigir_permiso('archivo','gestionar',p_archivo_id); END IF;
  INSERT INTO comunicacion.adjunto(archivo_id,mensaje_id,pedido_id,solicitud_servicio_id,orden_servicio_id,solicitud_cotizacion_id,cotizacion_id,solicitud_desarrollo_id,proyecto_id,factura_id,descripcion,visibilidad,adjuntado_en)
  VALUES(p_archivo_id,CASE WHEN p_recurso='mensaje' THEN p_registro_id END,CASE WHEN p_recurso='pedido' THEN p_registro_id END,
   CASE WHEN p_recurso='solicitud_servicio' THEN p_registro_id END,CASE WHEN p_recurso='orden_servicio' THEN p_registro_id END,
   CASE WHEN p_recurso='solicitud_cotizacion' THEN p_registro_id END,CASE WHEN p_recurso='cotizacion' THEN p_registro_id END,
   CASE WHEN p_recurso='solicitud_desarrollo' THEN p_registro_id END,CASE WHEN p_recurso='proyecto' THEN p_registro_id END,
   CASE WHEN p_recurso='factura' THEN p_registro_id END,p_descripcion,p_visibilidad,clock_timestamp()) RETURNING id INTO p_adjunto_id;
END $$;

CREATE PROCEDURE comunicacion.enviar_mensaje(p_conversacion_id bigint,p_contenido text,p_archivos bigint[] DEFAULT ARRAY[]::bigint[],
 INOUT p_mensaje_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE part bigint; f bigint; a bigint;
BEGIN
  PERFORM identidad.bloquear_operacion();
  PERFORM identidad.exigir_permiso('conversacion','leer',p_conversacion_id);
  SELECT id INTO part FROM comunicacion.participante_conversacion WHERE conversacion_id=p_conversacion_id
    AND persona_id=identidad.actor_persona_actual() AND salio_en IS NULL;
  IF part IS NULL THEN RAISE EXCEPTION 'El autor debe ser un participante humano autenticado activo' USING ERRCODE='42501'; END IF;
  INSERT INTO comunicacion.mensaje(autor_participante_id,contenido,enviado_en)
    VALUES(part,NULLIF(btrim(p_contenido),''),clock_timestamp()) RETURNING id INTO p_mensaje_id;
  FOREACH f IN ARRAY coalesce(p_archivos,ARRAY[]::bigint[]) LOOP
    a:=NULL; CALL comunicacion.adjuntar_archivo(f,'mensaje',p_mensaje_id,NULL,'compartido',a);
  END LOOP;
END $$;

CREATE PROCEDURE comunicacion.editar_mensaje(p_mensaje_id bigint,p_contenido text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE r record;
BEGIN
  PERFORM identidad.bloquear_operacion();
  SELECT m.*,p.persona_id,p.conversacion_id INTO r FROM comunicacion.mensaje m JOIN comunicacion.participante_conversacion p
    ON p.id=m.autor_participante_id WHERE m.id=p_mensaje_id;
  IF NOT FOUND OR r.persona_id IS DISTINCT FROM identidad.actor_persona_actual() THEN
    RAISE EXCEPTION 'Solo el autor puede editar el mensaje' USING ERRCODE='42501'; END IF;
  PERFORM identidad.exigir_permiso('conversacion','leer',r.conversacion_id);
  IF r.retirado THEN RAISE EXCEPTION 'Mensaje retirado no se edita' USING ERRCODE='23514'; END IF;
  UPDATE comunicacion.mensaje SET contenido=NULLIF(btrim(p_contenido),''),editado_en=clock_timestamp() WHERE id=p_mensaje_id;
END $$;

CREATE PROCEDURE comunicacion.retirar_mensaje(p_mensaje_id bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE r record;
BEGIN
  PERFORM identidad.bloquear_operacion();
  SELECT p.persona_id,p.conversacion_id INTO r FROM comunicacion.mensaje m JOIN comunicacion.participante_conversacion p
    ON p.id=m.autor_participante_id WHERE m.id=p_mensaje_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Mensaje inexistente' USING ERRCODE='P0002'; END IF;
  IF r.persona_id IS DISTINCT FROM identidad.actor_persona_actual() THEN
    PERFORM identidad.exigir_permiso('conversacion','gestionar',r.conversacion_id);
  ELSE PERFORM identidad.exigir_permiso('conversacion','leer',r.conversacion_id); END IF;
  UPDATE comunicacion.mensaje SET retirado=true,motivo_retiro=p_motivo WHERE id=p_mensaje_id AND NOT retirado;
END $$;

CREATE PROCEDURE comunicacion.marcar_mensaje_leido(p_mensaje_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE conv bigint; part bigint;
BEGIN
  PERFORM identidad.bloquear_operacion();
  SELECT p.conversacion_id INTO conv FROM comunicacion.mensaje m JOIN comunicacion.participante_conversacion p ON p.id=m.autor_participante_id WHERE m.id=p_mensaje_id;
  PERFORM identidad.exigir_permiso('conversacion','leer',conv);
  SELECT id INTO part FROM comunicacion.participante_conversacion WHERE conversacion_id=conv AND persona_id=identidad.actor_persona_actual() AND salio_en IS NULL;
  IF part IS NULL THEN RAISE EXCEPTION 'Lector no es participante activo' USING ERRCODE='42501'; END IF;
  INSERT INTO comunicacion.lectura_mensaje(mensaje_id,participante_id,leido_en) VALUES(p_mensaje_id,part,clock_timestamp()) ON CONFLICT DO NOTHING;
END $$;

CREATE PROCEDURE comunicacion.registrar_notificacion(p_usuario_id bigint,p_tipo text,p_titulo text,p_contenido text,p_evento uuid,
 p_recurso text DEFAULT NULL,p_registro_id bigint DEFAULT NULL,p_version_id bigint DEFAULT NULL,INOUT p_notificacion_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE n comunicacion.notificacion%ROWTYPE; ctx record;
BEGIN
  PERFORM identidad.bloquear_operacion();
  PERFORM identidad.exigir_permiso('notificacion','gestionar',NULL);
  IF (p_recurso IS NULL)<>(p_registro_id IS NULL) OR (p_recurso IS NOT NULL AND p_recurso NOT IN
    ('pedido','solicitud_servicio','orden_servicio','solicitud_cotizacion','cotizacion','solicitud_desarrollo','proyecto','factura')) THEN
    RAISE EXCEPTION 'Contexto de notificación inválido' USING ERRCODE='22023'; END IF;
  SELECT * INTO n FROM comunicacion.notificacion WHERE destinatario_usuario_id=p_usuario_id AND evento_id=p_evento AND tipo=p_tipo;
  IF FOUND THEN
    SELECT * INTO ctx FROM comunicacion.contexto_de_fila(to_jsonb(n));
    IF (n.titulo,n.contenido,n.version_cotizacion_id,ctx.recurso,ctx.registro_id) IS DISTINCT FROM
      (p_titulo,p_contenido,p_version_id,p_recurso,p_registro_id) THEN
      RAISE EXCEPTION 'Reintento de evento con contenido diferente' USING ERRCODE='22023'; END IF;
    p_notificacion_id:=n.id; RETURN;
  END IF;
  INSERT INTO comunicacion.notificacion(destinatario_usuario_id,tipo,titulo,contenido,evento_id,version_cotizacion_id,pedido_id,
    solicitud_servicio_id,orden_servicio_id,solicitud_cotizacion_id,cotizacion_id,solicitud_desarrollo_id,proyecto_id,factura_id)
  VALUES(p_usuario_id,p_tipo,p_titulo,p_contenido,p_evento,p_version_id,CASE WHEN p_recurso='pedido' THEN p_registro_id END,
    CASE WHEN p_recurso='solicitud_servicio' THEN p_registro_id END,CASE WHEN p_recurso='orden_servicio' THEN p_registro_id END,
    CASE WHEN p_recurso='solicitud_cotizacion' THEN p_registro_id END,CASE WHEN p_recurso='cotizacion' THEN p_registro_id END,
    CASE WHEN p_recurso='solicitud_desarrollo' THEN p_registro_id END,CASE WHEN p_recurso='proyecto' THEN p_registro_id END,
    CASE WHEN p_recurso='factura' THEN p_registro_id END) RETURNING id INTO p_notificacion_id;
END $$;

CREATE PROCEDURE comunicacion.marcar_notificacion_leida(p_notificacion_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
  PERFORM identidad.bloquear_operacion();
  UPDATE comunicacion.notificacion n SET leida_en=clock_timestamp() FROM identidad.usuario u
  WHERE n.id=p_notificacion_id AND u.id=n.destinatario_usuario_id AND u.persona_id=identidad.actor_persona_actual() AND n.leida_en IS NULL;
  IF NOT FOUND AND NOT EXISTS(SELECT 1 FROM comunicacion.notificacion n JOIN identidad.usuario u ON u.id=n.destinatario_usuario_id
    WHERE n.id=p_notificacion_id AND u.persona_id=identidad.actor_persona_actual()) THEN
    RAISE EXCEPTION 'Notificación no pertenece al actor' USING ERRCODE='42501'; END IF;
END $$;

CREATE PROCEDURE comunicacion.encolar_entrega(p_notificacion_id bigint,p_canal text,p_destino text,p_idempotencia uuid,
 INOUT p_entrega_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE e comunicacion.entrega_notificacion%ROWTYPE; n integer;
BEGIN
  PERFORM identidad.bloquear_operacion();
  PERFORM identidad.exigir_permiso('notificacion','gestionar',NULL);
  SELECT * INTO e FROM comunicacion.entrega_notificacion WHERE idempotencia_id=p_idempotencia;
  IF FOUND THEN
    IF (e.notificacion_id,e.canal,e.destino) IS DISTINCT FROM (p_notificacion_id,p_canal,p_destino) THEN
      RAISE EXCEPTION 'Clave de entrega reutilizada con otro destino/contenido' USING ERRCODE='22023'; END IF;
    p_entrega_id:=e.id; RETURN;
  END IF;
  IF EXISTS(SELECT 1 FROM comunicacion.entrega_notificacion WHERE notificacion_id=p_notificacion_id AND canal=p_canal AND estado IN ('pendiente','enviando','enviada','entregada')) THEN
    RAISE EXCEPTION 'Ya existe un intento pendiente, en tránsito o entregado para ese canal' USING ERRCODE='23514'; END IF;
  SELECT coalesce(max(numero_intento),0)+1 INTO n FROM comunicacion.entrega_notificacion WHERE notificacion_id=p_notificacion_id AND canal=p_canal;
  INSERT INTO comunicacion.entrega_notificacion(notificacion_id,canal,destino,numero_intento,idempotencia_id)
  VALUES(p_notificacion_id,p_canal,p_destino,n,p_idempotencia) RETURNING id INTO p_entrega_id;
END $$;

CREATE PROCEDURE comunicacion.reclamar_entrega(p_entrega_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
  PERFORM identidad.bloquear_operacion();
  PERFORM identidad.exigir_permiso('notificacion','gestionar',NULL);
  UPDATE comunicacion.entrega_notificacion SET estado='enviando',iniciada_en=clock_timestamp() WHERE id=p_entrega_id AND estado='pendiente';
  IF NOT FOUND THEN RAISE EXCEPTION 'Intento inexistente o ya reclamado' USING ERRCODE='23514'; END IF;
END $$;

CREATE PROCEDURE comunicacion.registrar_resultado_entrega(p_entrega_id bigint,p_estado text,p_proveedor text DEFAULT NULL,
 p_referencia text DEFAULT NULL,p_error text DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE e comunicacion.entrega_notificacion%ROWTYPE; t timestamptz;
BEGIN
  PERFORM identidad.bloquear_operacion();
  PERFORM identidad.exigir_permiso('notificacion','gestionar',NULL);
  SELECT * INTO e FROM comunicacion.entrega_notificacion WHERE id=p_entrega_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Intento inexistente' USING ERRCODE='P0002'; END IF;
  IF p_estado IS NULL OR p_estado NOT IN ('enviada','entregada','fallida') THEN RAISE EXCEPTION 'Resultado inválido' USING ERRCODE='22023'; END IF;
  IF e.estado=p_estado THEN
    IF (e.proveedor,e.referencia_proveedor,e.error) IS DISTINCT FROM (p_proveedor,p_referencia,p_error) THEN
      RAISE EXCEPTION 'Reintento del resultado con evidencia diferente' USING ERRCODE='22023'; END IF;
    RETURN;
  END IF;
  t:=clock_timestamp();
  UPDATE comunicacion.entrega_notificacion SET estado=p_estado,proveedor=p_proveedor,referencia_proveedor=p_referencia,error=p_error,
    finalizada_en=coalesce(finalizada_en,t),entregada_en=CASE WHEN p_estado='entregada' THEN t ELSE NULL END WHERE id=p_entrega_id;
END $$;

CREATE VIEW comunicacion.v_mensajes_visibles WITH (security_barrier=true) AS
 SELECT m.id,p.conversacion_id,p.persona_id AS autor_persona_id,
 CASE WHEN m.retirado THEN NULL ELSE m.contenido END AS contenido,m.enviado_en,m.editado_en,m.retirado
 FROM comunicacion.mensaje m JOIN comunicacion.participante_conversacion p ON p.id=m.autor_participante_id
 WHERE identidad.puede_acceder('conversacion',p.conversacion_id,'leer');

CREATE VIEW comunicacion.v_notificaciones_propias WITH (security_barrier=true) AS
 SELECT n.* FROM comunicacion.notificacion n JOIN identidad.usuario u ON u.id=n.destinatario_usuario_id
 WHERE u.persona_id=identidad.actor_persona_actual();

CREATE FUNCTION comunicacion.contar_mensajes_no_leidos(p_conversacion_id bigint)
RETURNS bigint LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE part bigint; total bigint;
BEGIN
  PERFORM identidad.exigir_permiso('conversacion','leer',p_conversacion_id);
  SELECT id INTO part FROM comunicacion.participante_conversacion WHERE conversacion_id=p_conversacion_id
    AND persona_id=identidad.actor_persona_actual() AND salio_en IS NULL;
  IF part IS NULL THEN RETURN 0; END IF;
  SELECT count(*) INTO total FROM comunicacion.mensaje m JOIN comunicacion.participante_conversacion p ON p.id=m.autor_participante_id
    WHERE p.conversacion_id=p_conversacion_id AND m.autor_participante_id<>part AND NOT m.retirado
    AND NOT EXISTS(SELECT 1 FROM comunicacion.lectura_mensaje l WHERE l.mensaje_id=m.id AND l.participante_id=part);
  RETURN total;
END $$;

DO $triggers$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['conversacion','participante_conversacion','mensaje','lectura_mensaje','adjunto','archivo','notificacion','entrega_notificacion'] LOOP
    EXECUTE format('CREATE TRIGGER t10_guard_%I BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.%I FOR EACH ROW EXECUTE FUNCTION comunicacion.proteger_fila()',t,t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['conversacion','participante_conversacion','mensaje','lectura_mensaje','adjunto','archivo','notificacion'] LOOP
    EXECUTE format('CREATE CONSTRAINT TRIGGER t10_integridad_%I AFTER INSERT OR UPDATE OR DELETE ON comunicacion.%I DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION comunicacion.validar_integridad_trigger()',t,t);
  END LOOP;
END $triggers$;
CREATE CONSTRAINT TRIGGER t11_integridad_producto_imagen AFTER INSERT OR UPDATE OR DELETE ON inventario.producto_imagen
 DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION comunicacion.validar_integridad_trigger();
CREATE CONSTRAINT TRIGGER t11_integridad_comprobante AFTER INSERT OR UPDATE OR DELETE ON comercial.comprobante_factura
 DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION comunicacion.validar_integridad_trigger();
CREATE CONSTRAINT TRIGGER t12_integridad_version AFTER UPDATE ON comercial.version_cotizacion
 DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION comunicacion.validar_integridad_trigger();

-- GRANT únicamente a APIs públicas de esta lista en la fase 6. Los validadores nunca se exponen como RPC.
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA comunicacion FROM PUBLIC;
REVOKE ALL ON ALL PROCEDURES IN SCHEMA comunicacion FROM PUBLIC;

-- MÓDULO 50_auditoria
-- Auditoría, historial, transiciones y revocación coordinada.

-- La identidad auditada sobrevive a una desactivación realizada en esta transacción.
-- Este auxiliar no concede autorización y no se expone a la aplicación.
CREATE FUNCTION auditoria.persona_responsable() RETURNS bigint
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE u text:=nullif(current_setting('app.usuario_id',true),''); r bigint;
BEGIN
 IF u IS NOT NULL AND u ~ '^[0-9]+$' THEN SELECT persona_id INTO r FROM identidad.usuario WHERE id=u::bigint;
 ELSE r:=identidad.actor_persona_actual(); END IF;
 RETURN r;
END $$;
CREATE FUNCTION auditoria.sistema_responsable() RETURNS text
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF auditoria.persona_responsable() IS NOT NULL THEN RETURN NULL; END IF;
 RETURN identidad.actor_sistema_actual();
END $$;

CREATE FUNCTION identidad.proteger_basico() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE a jsonb; b jsonb; c text;
BEGIN
 PERFORM identidad.bloquear_operacion();
 IF TG_OP='UPDATE' THEN
   a:=to_jsonb(OLD);b:=to_jsonb(NEW);
   FOREACH c IN ARRAY TG_ARGV LOOP
     IF a->c IS DISTINCT FROM b->c THEN RAISE EXCEPTION 'Identidad o vínculo inmutable: %.%',TG_TABLE_NAME,c USING ERRCODE='23514'; END IF;
   END LOOP;
   IF a ? 'created_at' AND a->'created_at' IS DISTINCT FROM b->'created_at' THEN RAISE EXCEPTION 'created_at es inmutable'; END IF;
   IF b ? 'updated_at' THEN NEW:=jsonb_populate_record(NEW,jsonb_build_object('updated_at',greatest(clock_timestamp(),(a->>'updated_at')::timestamptz))); END IF;
 END IF;
 IF TG_OP='INSERT' AND to_jsonb(NEW) ? 'actor_persona_id' THEN
   NEW:=jsonb_populate_record(NEW,jsonb_build_object('actor_persona_id',auditoria.persona_responsable(),'actor_sistema',auditoria.sistema_responsable()));
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END $$;

CREATE FUNCTION auditoria.solo_anexar() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 RAISE EXCEPTION 'La evidencia histórica no se modifica ni se elimina' USING ERRCODE='23514';
END $$;

CREATE FUNCTION auditoria.registrar_cambio() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE a jsonb; b jsonb; clave jsonb:='{}'::jsonb; k text; fila jsonb;
BEGIN
 IF TG_OP<>'INSERT' THEN a:=to_jsonb(OLD)-ARRAY['password_hash','token_hash','refresh_hash','sesion_anonima_hash']; END IF;
 IF TG_OP<>'DELETE' THEN b:=to_jsonb(NEW)-ARRAY['password_hash','token_hash','refresh_hash','sesion_anonima_hash']; END IF;
 fila:=coalesce(b,a);
 IF nullif(current_setting('app.motivo',true),'') IS NOT NULL THEN
   IF a IS NOT NULL THEN a:=a||jsonb_build_object('_auditoria',jsonb_build_object('motivo',current_setting('app.motivo',true))); END IF;
   IF b IS NOT NULL THEN b:=b||jsonb_build_object('_auditoria',jsonb_build_object('motivo',current_setting('app.motivo',true))); END IF;
 END IF;
 FOREACH k IN ARRAY TG_ARGV LOOP clave:=clave||jsonb_build_object(k,fila->k); END LOOP;
 INSERT INTO auditoria.evento_auditoria(operacion,esquema_objeto,tabla_objeto,clave_registro,valores_anteriores,valores_nuevos,usuario_conexion,rol_efectivo,correlacion_id,actor_persona_id,actor_sistema)
 VALUES(TG_OP,TG_TABLE_SCHEMA,TG_TABLE_NAME,clave,a,b,session_user,coalesce(nullif(current_setting('role',true),'none'),session_user),
 coalesce(nullif(current_setting('app.correlacion_id',true),'')::uuid,gen_random_uuid()),auditoria.persona_responsable(),auditoria.sistema_responsable());
 RETURN NULL;
END $$;

CREATE FUNCTION auditoria.verificar_transicion() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE mapa jsonb; destinos jsonb;
BEGIN
 IF NEW.estado IS NOT DISTINCT FROM OLD.estado THEN RETURN NEW; END IF;
 mapa:='{"comercial.pedido":{"borrador":["confirmado","cancelado"],"confirmado":["en_preparacion","completado","cancelado"],"en_preparacion":["completado","cancelado"]},"comercial.cotizacion":{"abierta":["aceptada","cerrada","anulada"],"cerrada":["abierta","anulada"]},"comercial.version_cotizacion":{"borrador":["enviada","anulada"],"enviada":["aceptada","rechazada","reemplazada","anulada"]},"comercial.solicitud_cotizacion":{"recibida":["en_evaluacion","cancelada"],"en_evaluacion":["atendida","rechazada","cancelada"]},"comercial.factura":{"borrador":["emitida"],"emitida":["anulada"]},"servicios.solicitud_servicio":{"recibida":["en_evaluacion","cancelada"],"en_evaluacion":["aceptada","rechazada","cancelada"],"aceptada":["cancelada"]},"servicios.orden_servicio":{"pendiente_asignacion":["asignada","cancelada"],"asignada":["pendiente_asignacion","en_ejecucion","cancelada"],"en_ejecucion":["pausada","finalizada","cancelada"],"pausada":["en_ejecucion","cancelada"]},"proyectos.solicitud_desarrollo":{"recibida":["en_evaluacion","cancelada"],"en_evaluacion":["aprobada","rechazada","cancelada"],"aprobada":["cancelada"]},"proyectos.proyecto":{"planificado":["en_ejecucion","cancelado"],"en_ejecucion":["suspendido","finalizado","cancelado"],"suspendido":["en_ejecucion","cancelado"]}}'::jsonb;
 destinos:=mapa->(TG_TABLE_SCHEMA||'.'||TG_TABLE_NAME)->OLD.estado;
 IF destinos IS NULL OR NOT destinos ? NEW.estado THEN
   RAISE EXCEPTION 'Transición no permitida en %: % -> %',TG_TABLE_NAME,OLD.estado,NEW.estado USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;

CREATE FUNCTION auditoria.registrar_estado() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE destino text:=TG_ARGV[0];fk text:=TG_ARGV[1];num integer;prev text;motivo text;
BEGIN
 IF TG_OP='UPDATE' AND OLD.estado IS NOT DISTINCT FROM NEW.estado THEN RETURN NULL; END IF;
 PERFORM identidad.bloquear_operacion();
 IF TG_OP='UPDATE' THEN prev:=OLD.estado; END IF;
 motivo:=coalesce(nullif(current_setting('app.motivo',true),''),lower(TG_OP)||':'||TG_TABLE_NAME);
 EXECUTE format('SELECT coalesce(max(numero_evento),0)+1 FROM %s WHERE %I=$1',destino,fk) INTO num USING NEW.id;
 EXECUTE format('INSERT INTO %s(%I,numero_evento,estado_anterior,estado_nuevo,motivo,correlacion_id,actor_persona_id,actor_sistema) VALUES($1,$2,$3,$4,$5,$6,$7,$8)',destino,fk)
 USING NEW.id,num,prev,NEW.estado,motivo,nullif(current_setting('app.correlacion_id',true),'')::uuid,auditoria.persona_responsable(),auditoria.sistema_responsable();
 RETURN NULL;
END $$;

CREATE FUNCTION auditoria.registrar_estado_version() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE n integer;ep text;prev text;
BEGIN
 IF TG_OP='UPDATE' AND OLD.estado IS NOT DISTINCT FROM NEW.estado THEN RETURN NULL; END IF;
 PERFORM identidad.bloquear_operacion();
 SELECT estado INTO ep FROM comercial.cotizacion WHERE id=NEW.cotizacion_id;
 SELECT coalesce(max(numero_evento),0)+1 INTO n FROM comercial.historial_cotizacion WHERE cotizacion_id=NEW.cotizacion_id;
 IF TG_OP='UPDATE' THEN prev:=OLD.estado; END IF;
 INSERT INTO comercial.historial_cotizacion(cotizacion_id,numero_evento,estado_anterior,estado_nuevo,motivo,correlacion_id,actor_persona_id,actor_sistema,version_cotizacion_id,estado_version_anterior,estado_version_nuevo)
 VALUES(NEW.cotizacion_id,n,ep,ep,coalesce(nullif(current_setting('app.motivo',true),''),'version:'||NEW.estado),
 nullif(current_setting('app.correlacion_id',true),'')::uuid,auditoria.persona_responsable(),auditoria.sistema_responsable(),NEW.id,prev,NEW.estado);
 RETURN NULL;
END $$;

CREATE FUNCTION identidad.validar_identidad() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE a record;k text; j jsonb;ctx text;rid bigint;
BEGIN
 IF EXISTS(SELECT 1 FROM identidad.credencial c JOIN identidad.usuario u ON u.id=c.usuario_id WHERE u.origen_auth<>'local')
 OR EXISTS(SELECT 1 FROM identidad.sesion s JOIN identidad.usuario u ON u.id=s.usuario_id WHERE u.origen_auth<>'local')
 OR EXISTS(SELECT 1 FROM identidad.recuperacion_acceso s JOIN identidad.usuario u ON u.id=s.usuario_id WHERE u.origen_auth<>'local') THEN
   RAISE EXCEPTION 'Credenciales, sesiones y recuperación propias requieren cuenta local' USING ERRCODE='23514';
 END IF;
 IF EXISTS(SELECT 1 FROM identidad.usuario u WHERE u.origen_auth='local' AND u.estado='activo' AND NOT EXISTS(SELECT 1 FROM identidad.credencial c WHERE c.usuario_id=u.id)) THEN
   RAISE EXCEPTION 'Una cuenta local activa requiere credencial' USING ERRCODE='23514';
 END IF;
 FOR a IN SELECT * FROM identidad.acceso_invitado WHERE revocado_en IS NULL AND vence_en>clock_timestamp() LOOP
   j:=to_jsonb(a);ctx:=NULL;rid:=NULL;
   FOREACH k IN ARRAY ARRAY['pedido','solicitud_servicio','orden_servicio','solicitud_cotizacion','cotizacion','solicitud_desarrollo','proyecto','factura','conversacion'] LOOP
     IF j->>(k||'_id') IS NOT NULL THEN ctx:=k;rid:=(j->>(k||'_id'))::bigint;EXIT;END IF;
   END LOOP;
   IF NOT identidad.persona_puede_acceder(a.persona_id,ctx,rid,'leer') THEN RAISE EXCEPTION 'Concesión invitada ajena a su titular' USING ERRCODE='23514'; END IF;
   IF a.version_cotizacion_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM comercial.version_cotizacion WHERE id=a.version_cotizacion_id AND cotizacion_id=a.cotizacion_id) THEN RAISE EXCEPTION 'Versión de acceso invitado ajena' USING ERRCODE='23514'; END IF;
   IF NOT EXISTS(SELECT 1 FROM identidad.acceso_invitado_permiso WHERE acceso_invitado_id=a.id) THEN RAISE EXCEPTION 'Concesión invitada sin acciones' USING ERRCODE='23514'; END IF;
   IF EXISTS(SELECT 1 FROM identidad.acceso_invitado_permiso ap JOIN identidad.permiso p ON p.id=ap.permiso_id WHERE ap.acceso_invitado_id=a.id AND
       (p.recurso<>ctx OR NOT(p.accion='leer' OR (p.accion='responder' AND ctx='cotizacion' AND a.version_cotizacion_id IS NOT NULL)
       OR (p.accion='calificar' AND ctx='orden_servicio') OR (p.accion='editar' AND ctx IN ('pedido','solicitud_servicio','solicitud_cotizacion','solicitud_desarrollo'))))) THEN
       RAISE EXCEPTION 'Permisos invitados excesivos o ajenos al contexto' USING ERRCODE='23514';
   END IF;
 END LOOP;
 RETURN NULL;
END $$;

CREATE FUNCTION identidad.proteger_acceso() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF TG_TABLE_NAME='acceso_invitado' THEN
   IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Revocar acceso, no borrarlo' USING ERRCODE='23514';END IF;
   IF TG_OP='UPDATE' AND (to_jsonb(OLD)-'revocado_en' IS DISTINCT FROM to_jsonb(NEW)-'revocado_en' OR OLD.revocado_en IS NOT NULL OR NEW.revocado_en IS NULL) THEN
     RAISE EXCEPTION 'La concesión es inmutable; revocar y emitir otra' USING ERRCODE='23514';END IF;
 ELSE
   IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Las acciones de la concesión son inmutables' USING ERRCODE='23514';END IF;
   IF NOT EXISTS(SELECT 1 FROM identidad.acceso_invitado a WHERE a.id=NEW.acceso_invitado_id
        AND a.xmin::text=(pg_current_xact_id()::text::numeric % 4294967296)::text AND a.revocado_en IS NULL) THEN
     RAISE EXCEPTION 'No ampliar acciones de una concesión previamente confirmada' USING ERRCODE='23514';END IF;
 END IF;
 RETURN NEW;
END $$;

CREATE FUNCTION identidad.sincronizar_habilitaciones() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE instante timestamptz:=clock_timestamp();
BEGIN
 -- Llamador posee el mutex. La revocación tiene prioridad sobre la continuidad operativa.
 UPDATE servicios.asignacion_servicio a SET termina_en=greatest(instante,a.inicia_en+INTERVAL '1 microsecond')
 WHERE a.inicia_en<=instante AND (a.termina_en IS NULL OR a.termina_en>instante) AND NOT identidad.empleado_habilitado(a.empleado_id,'orden_servicio');
 UPDATE proyectos.miembro_proyecto m SET termina_en=greatest(instante,m.inicia_en+INTERVAL '1 microsecond')
 WHERE m.inicia_en<=instante AND (m.termina_en IS NULL OR m.termina_en>instante) AND NOT identidad.empleado_habilitado(m.empleado_id,'proyecto');
 UPDATE servicios.orden_servicio o SET estado=CASE WHEN o.estado='en_ejecucion' THEN 'pausada' ELSE 'pendiente_asignacion' END
 WHERE o.estado IN ('asignada','en_ejecucion') AND NOT EXISTS(SELECT 1 FROM servicios.asignacion_servicio a WHERE a.orden_servicio_id=o.id AND a.es_principal
 AND a.inicia_en<=instante AND (a.termina_en IS NULL OR a.termina_en>instante) AND identidad.empleado_habilitado(a.empleado_id,'orden_servicio'));
 UPDATE proyectos.proyecto p SET estado='suspendido' WHERE p.estado='en_ejecucion' AND NOT EXISTS(SELECT 1 FROM proyectos.miembro_proyecto m
 WHERE m.proyecto_id=p.id AND m.es_principal AND m.inicia_en<=instante AND (m.termina_en IS NULL OR m.termina_en>instante) AND identidad.empleado_habilitado(m.empleado_id,'proyecto'));
 UPDATE servicios.cita_servicio SET estado='cancelada',motivo_cancelacion='Técnico sin autorización vigente'
 WHERE estado='confirmada' AND fin>instante AND NOT identidad.empleado_habilitado(tecnico_id,'orden_servicio');
 UPDATE identidad.acceso_invitado a SET revocado_en=instante WHERE a.revocado_en IS NULL AND EXISTS(SELECT 1 FROM identidad.persona p WHERE p.id=a.persona_id AND NOT p.activo);
END $$;

CREATE FUNCTION identidad.revisar_habilitaciones_trigger() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.sincronizar_habilitaciones();RETURN NULL;
END $$;

CREATE PROCEDURE identidad.procesar_vencimientos()
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('usuario','gestionar');PERFORM identidad.sincronizar_habilitaciones();
END $$;

CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado_permiso FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('acceso_invitado_id','permiso_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado_permiso FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('acceso_invitado_id','permiso_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.cliente FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','persona_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.cliente FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.credencial FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('usuario_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.credencial FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('usuario_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.empleado FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','persona_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.empleado FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.permiso FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.permiso FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.persona FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.persona FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.recuperacion_acceso FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.recuperacion_acceso FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.rol FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.rol FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.rol_permiso FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('rol_id','permiso_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.rol_permiso FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('rol_id','permiso_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.sesion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.sesion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.usuario FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','persona_id','origen_auth','emisor_externo','sujeto_externo');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.usuario FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.usuario_rol FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','usuario_id','rol_id','inicia_en');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.usuario_rol FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON inventario.categoria FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON inventario.categoria FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON inventario.inventario FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('producto_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON inventario.inventario FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('producto_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON inventario.movimiento_inventario FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON inventario.movimiento_inventario FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON inventario.producto FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON inventario.producto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON inventario.producto_imagen FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON inventario.producto_imagen FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON inventario.reserva_inventario FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('detalle_pedido_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON inventario.reserva_inventario FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('detalle_pedido_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.carrito FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.carrito FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.comprobante_factura FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.comprobante_factura FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.cotizacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','solicitud_cotizacion_id','persona_directa_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON comercial.cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON comercial.cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('comercial.historial_cotizacion','cotizacion_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.detalle_carrito FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('carrito_id','producto_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.detalle_carrito FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('carrito_id','producto_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.detalle_cotizacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.detalle_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.detalle_factura FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.detalle_factura FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.detalle_pedido FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.detalle_pedido FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.factura FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.factura FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON comercial.factura FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON comercial.factura FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('comercial.historial_factura','factura_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.historial_cotizacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON comercial.historial_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.historial_factura FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON comercial.historial_factura FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_factura FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.historial_pedido FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON comercial.historial_pedido FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_pedido FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.historial_solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON comercial.historial_solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.pedido FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','cliente_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.pedido FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON comercial.pedido FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON comercial.pedido FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('comercial.historial_pedido','pedido_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','persona_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON comercial.solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON comercial.solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('comercial.historial_solicitud_cotizacion','solicitud_cotizacion_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.version_cotizacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','cotizacion_id','numero_version');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.version_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON comercial.version_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.asignacion_servicio FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.asignacion_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.calificacion_servicio FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('orden_servicio_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.calificacion_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('orden_servicio_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.cita_servicio FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.cita_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.disponibilidad_tecnico FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.disponibilidad_tecnico FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.equipo_cliente FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','cliente_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.equipo_cliente FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.historial_servicio FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON servicios.historial_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.historial_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.historial_solicitud_servicio FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON servicios.historial_solicitud_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.historial_solicitud_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.mantenimiento FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('orden_servicio_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.mantenimiento FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('orden_servicio_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.orden_servicio FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','solicitud_servicio_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.orden_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON servicios.orden_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON servicios.orden_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('servicios.historial_servicio','orden_servicio_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.reparacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('orden_servicio_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.reparacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('orden_servicio_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.servicio_ofrecido FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.servicio_ofrecido FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.solicitud_servicio FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','cliente_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.solicitud_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON servicios.solicitud_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON servicios.solicitud_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('servicios.historial_solicitud_servicio','solicitud_servicio_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON proyectos.avance_proyecto FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON proyectos.avance_proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON proyectos.etapa_proyecto FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON proyectos.etapa_proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON proyectos.historial_proyecto FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON proyectos.historial_proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON proyectos.historial_proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON proyectos.historial_solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON proyectos.historial_solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON proyectos.historial_solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON proyectos.miembro_proyecto FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON proyectos.miembro_proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON proyectos.proyecto FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','solicitud_desarrollo_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON proyectos.proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON proyectos.proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON proyectos.proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('proyectos.historial_proyecto','proyecto_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON proyectos.solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','cliente_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON proyectos.solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON proyectos.solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON proyectos.solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('proyectos.historial_solicitud_desarrollo','solicitud_desarrollo_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.adjunto FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.adjunto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.archivo FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.archivo FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.conversacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.conversacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.entrega_notificacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.entrega_notificacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.lectura_mensaje FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('mensaje_id','participante_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.lectura_mensaje FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('mensaje_id','participante_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.mensaje FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.mensaje FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.notificacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.notificacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.participante_conversacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.participante_conversacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON auditoria.evento_auditoria FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON auditoria.evento_auditoria FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z50_historial_version AFTER INSERT OR UPDATE ON comercial.version_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado_version();
CREATE TRIGGER a20_concesion BEFORE INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado FOR EACH ROW EXECUTE FUNCTION identidad.proteger_acceso();
CREATE TRIGGER a20_concesion BEFORE INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado_permiso FOR EACH ROW EXECUTE FUNCTION identidad.proteger_acceso();
CREATE CONSTRAINT TRIGGER z95_identidad AFTER INSERT OR UPDATE OR DELETE ON identidad.usuario DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identidad.validar_identidad();
CREATE CONSTRAINT TRIGGER z95_identidad AFTER INSERT OR UPDATE OR DELETE ON identidad.credencial DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identidad.validar_identidad();
CREATE CONSTRAINT TRIGGER z95_identidad AFTER INSERT OR UPDATE OR DELETE ON identidad.sesion DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identidad.validar_identidad();
CREATE CONSTRAINT TRIGGER z95_identidad AFTER INSERT OR UPDATE OR DELETE ON identidad.recuperacion_acceso DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identidad.validar_identidad();
CREATE CONSTRAINT TRIGGER z95_identidad AFTER INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identidad.validar_identidad();
CREATE CONSTRAINT TRIGGER z95_identidad AFTER INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado_permiso DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identidad.validar_identidad();
CREATE CONSTRAINT TRIGGER z95_identidad AFTER INSERT OR UPDATE OR DELETE ON identidad.permiso DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identidad.validar_identidad();
CREATE TRIGGER z30_habilitaciones AFTER UPDATE OR DELETE ON identidad.persona FOR EACH STATEMENT EXECUTE FUNCTION identidad.revisar_habilitaciones_trigger();
CREATE TRIGGER z30_habilitaciones AFTER UPDATE OR DELETE ON identidad.usuario FOR EACH STATEMENT EXECUTE FUNCTION identidad.revisar_habilitaciones_trigger();
CREATE TRIGGER z30_habilitaciones AFTER UPDATE OR DELETE ON identidad.empleado FOR EACH STATEMENT EXECUTE FUNCTION identidad.revisar_habilitaciones_trigger();
CREATE TRIGGER z30_habilitaciones AFTER UPDATE OR DELETE ON identidad.usuario_rol FOR EACH STATEMENT EXECUTE FUNCTION identidad.revisar_habilitaciones_trigger();
CREATE TRIGGER z30_habilitaciones AFTER UPDATE OR DELETE ON identidad.rol_permiso FOR EACH STATEMENT EXECUTE FUNCTION identidad.revisar_habilitaciones_trigger();
CREATE TRIGGER z30_habilitaciones AFTER UPDATE OR DELETE ON identidad.rol FOR EACH STATEMENT EXECUTE FUNCTION identidad.revisar_habilitaciones_trigger();
CREATE TRIGGER z30_habilitaciones AFTER UPDATE OR DELETE ON identidad.permiso FOR EACH STATEMENT EXECUTE FUNCTION identidad.revisar_habilitaciones_trigger();

CREATE FUNCTION auditoria.validar_historial() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN

 IF EXISTS(SELECT 1 FROM comercial.pedido p LEFT JOIN LATERAL(SELECT estado_nuevo FROM comercial.historial_pedido h WHERE h.pedido_id=p.id ORDER BY numero_evento DESC LIMIT 1) h ON true
 WHERE p.estado IS DISTINCT FROM h.estado_nuevo) THEN RAISE EXCEPTION 'Historial y estado divergentes: comercial.pedido' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM comercial.historial_pedido GROUP BY pedido_id HAVING min(numero_evento)<>1 OR count(*)<>max(numero_evento)) THEN RAISE EXCEPTION 'Ordinales históricos discontinuos: comercial.historial_pedido' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM(SELECT numero_evento,estado_anterior,lag(estado_nuevo) OVER(PARTITION BY pedido_id ORDER BY numero_evento) previo FROM comercial.historial_pedido) s WHERE numero_evento>1 AND estado_anterior IS DISTINCT FROM previo)
 THEN RAISE EXCEPTION 'Cadena histórica incoherente: comercial.historial_pedido' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM comercial.cotizacion p LEFT JOIN LATERAL(SELECT estado_nuevo FROM comercial.historial_cotizacion h WHERE h.cotizacion_id=p.id ORDER BY numero_evento DESC LIMIT 1) h ON true
 WHERE p.estado IS DISTINCT FROM h.estado_nuevo) THEN RAISE EXCEPTION 'Historial y estado divergentes: comercial.cotizacion' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM comercial.historial_cotizacion GROUP BY cotizacion_id HAVING min(numero_evento)<>1 OR count(*)<>max(numero_evento)) THEN RAISE EXCEPTION 'Ordinales históricos discontinuos: comercial.historial_cotizacion' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM(SELECT numero_evento,estado_anterior,lag(estado_nuevo) OVER(PARTITION BY cotizacion_id ORDER BY numero_evento) previo FROM comercial.historial_cotizacion) s WHERE numero_evento>1 AND estado_anterior IS DISTINCT FROM previo)
 THEN RAISE EXCEPTION 'Cadena histórica incoherente: comercial.historial_cotizacion' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM comercial.solicitud_cotizacion p LEFT JOIN LATERAL(SELECT estado_nuevo FROM comercial.historial_solicitud_cotizacion h WHERE h.solicitud_cotizacion_id=p.id ORDER BY numero_evento DESC LIMIT 1) h ON true
 WHERE p.estado IS DISTINCT FROM h.estado_nuevo) THEN RAISE EXCEPTION 'Historial y estado divergentes: comercial.solicitud_cotizacion' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM comercial.historial_solicitud_cotizacion GROUP BY solicitud_cotizacion_id HAVING min(numero_evento)<>1 OR count(*)<>max(numero_evento)) THEN RAISE EXCEPTION 'Ordinales históricos discontinuos: comercial.historial_solicitud_cotizacion' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM(SELECT numero_evento,estado_anterior,lag(estado_nuevo) OVER(PARTITION BY solicitud_cotizacion_id ORDER BY numero_evento) previo FROM comercial.historial_solicitud_cotizacion) s WHERE numero_evento>1 AND estado_anterior IS DISTINCT FROM previo)
 THEN RAISE EXCEPTION 'Cadena histórica incoherente: comercial.historial_solicitud_cotizacion' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM comercial.factura p LEFT JOIN LATERAL(SELECT estado_nuevo FROM comercial.historial_factura h WHERE h.factura_id=p.id ORDER BY numero_evento DESC LIMIT 1) h ON true
 WHERE p.estado IS DISTINCT FROM h.estado_nuevo) THEN RAISE EXCEPTION 'Historial y estado divergentes: comercial.factura' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM comercial.historial_factura GROUP BY factura_id HAVING min(numero_evento)<>1 OR count(*)<>max(numero_evento)) THEN RAISE EXCEPTION 'Ordinales históricos discontinuos: comercial.historial_factura' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM(SELECT numero_evento,estado_anterior,lag(estado_nuevo) OVER(PARTITION BY factura_id ORDER BY numero_evento) previo FROM comercial.historial_factura) s WHERE numero_evento>1 AND estado_anterior IS DISTINCT FROM previo)
 THEN RAISE EXCEPTION 'Cadena histórica incoherente: comercial.historial_factura' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM servicios.solicitud_servicio p LEFT JOIN LATERAL(SELECT estado_nuevo FROM servicios.historial_solicitud_servicio h WHERE h.solicitud_servicio_id=p.id ORDER BY numero_evento DESC LIMIT 1) h ON true
 WHERE p.estado IS DISTINCT FROM h.estado_nuevo) THEN RAISE EXCEPTION 'Historial y estado divergentes: servicios.solicitud_servicio' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM servicios.historial_solicitud_servicio GROUP BY solicitud_servicio_id HAVING min(numero_evento)<>1 OR count(*)<>max(numero_evento)) THEN RAISE EXCEPTION 'Ordinales históricos discontinuos: servicios.historial_solicitud_servicio' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM(SELECT numero_evento,estado_anterior,lag(estado_nuevo) OVER(PARTITION BY solicitud_servicio_id ORDER BY numero_evento) previo FROM servicios.historial_solicitud_servicio) s WHERE numero_evento>1 AND estado_anterior IS DISTINCT FROM previo)
 THEN RAISE EXCEPTION 'Cadena histórica incoherente: servicios.historial_solicitud_servicio' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM servicios.orden_servicio p LEFT JOIN LATERAL(SELECT estado_nuevo FROM servicios.historial_servicio h WHERE h.orden_servicio_id=p.id ORDER BY numero_evento DESC LIMIT 1) h ON true
 WHERE p.estado IS DISTINCT FROM h.estado_nuevo) THEN RAISE EXCEPTION 'Historial y estado divergentes: servicios.orden_servicio' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM servicios.historial_servicio GROUP BY orden_servicio_id HAVING min(numero_evento)<>1 OR count(*)<>max(numero_evento)) THEN RAISE EXCEPTION 'Ordinales históricos discontinuos: servicios.historial_servicio' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM(SELECT numero_evento,estado_anterior,lag(estado_nuevo) OVER(PARTITION BY orden_servicio_id ORDER BY numero_evento) previo FROM servicios.historial_servicio) s WHERE numero_evento>1 AND estado_anterior IS DISTINCT FROM previo)
 THEN RAISE EXCEPTION 'Cadena histórica incoherente: servicios.historial_servicio' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM proyectos.solicitud_desarrollo p LEFT JOIN LATERAL(SELECT estado_nuevo FROM proyectos.historial_solicitud_desarrollo h WHERE h.solicitud_desarrollo_id=p.id ORDER BY numero_evento DESC LIMIT 1) h ON true
 WHERE p.estado IS DISTINCT FROM h.estado_nuevo) THEN RAISE EXCEPTION 'Historial y estado divergentes: proyectos.solicitud_desarrollo' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM proyectos.historial_solicitud_desarrollo GROUP BY solicitud_desarrollo_id HAVING min(numero_evento)<>1 OR count(*)<>max(numero_evento)) THEN RAISE EXCEPTION 'Ordinales históricos discontinuos: proyectos.historial_solicitud_desarrollo' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM(SELECT numero_evento,estado_anterior,lag(estado_nuevo) OVER(PARTITION BY solicitud_desarrollo_id ORDER BY numero_evento) previo FROM proyectos.historial_solicitud_desarrollo) s WHERE numero_evento>1 AND estado_anterior IS DISTINCT FROM previo)
 THEN RAISE EXCEPTION 'Cadena histórica incoherente: proyectos.historial_solicitud_desarrollo' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM proyectos.proyecto p LEFT JOIN LATERAL(SELECT estado_nuevo FROM proyectos.historial_proyecto h WHERE h.proyecto_id=p.id ORDER BY numero_evento DESC LIMIT 1) h ON true
 WHERE p.estado IS DISTINCT FROM h.estado_nuevo) THEN RAISE EXCEPTION 'Historial y estado divergentes: proyectos.proyecto' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM proyectos.historial_proyecto GROUP BY proyecto_id HAVING min(numero_evento)<>1 OR count(*)<>max(numero_evento)) THEN RAISE EXCEPTION 'Ordinales históricos discontinuos: proyectos.historial_proyecto' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT 1 FROM(SELECT numero_evento,estado_anterior,lag(estado_nuevo) OVER(PARTITION BY proyecto_id ORDER BY numero_evento) previo FROM proyectos.historial_proyecto) s WHERE numero_evento>1 AND estado_anterior IS DISTINCT FROM previo)
 THEN RAISE EXCEPTION 'Cadena histórica incoherente: proyectos.historial_proyecto' USING ERRCODE='23514'; END IF;
 RETURN NULL;END $$;
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.pedido DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.cotizacion DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.solicitud_cotizacion DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.factura DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON servicios.solicitud_servicio DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON servicios.orden_servicio DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON proyectos.solicitud_desarrollo DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON proyectos.proyecto DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_pedido DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_cotizacion DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_solicitud_cotizacion DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_factura DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON servicios.historial_solicitud_servicio DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON servicios.historial_servicio DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON proyectos.historial_solicitud_desarrollo DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON proyectos.historial_proyecto DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();

CREATE FUNCTION comunicacion.notificar_estado() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE persona bigint; u bigint; tipo text; recurso text:=TG_TABLE_NAME; ctx text; texto text; vers bigint; rid bigint;
BEGIN
 IF TG_OP='INSERT' OR OLD.estado IS NOT DISTINCT FROM NEW.estado THEN RETURN NULL;END IF;
 IF recurso='version_cotizacion' THEN rid:=NEW.cotizacion_id;persona:=identidad.persona_titular('cotizacion',NEW.cotizacion_id);ctx:='cotizacion_id';tipo:='cambio_cotizacion';vers:=NEW.id;
 ELSE rid:=NEW.id;persona:=identidad.persona_titular(recurso,NEW.id);ctx:=recurso||'_id';
   tipo:=CASE recurso WHEN 'pedido' THEN 'cambio_pedido' WHEN 'orden_servicio' THEN 'cambio_servicio' WHEN 'cotizacion' THEN 'cambio_cotizacion'
     WHEN 'proyecto' THEN 'cambio_proyecto' WHEN 'factura' THEN 'factura_emitida' ELSE 'cambio_solicitud' END;
 END IF;
 IF recurso='factura' AND NEW.estado<>'emitida' THEN RETURN NULL;END IF;
 SELECT id INTO u FROM identidad.usuario WHERE persona_id=persona AND estado='activo';
 IF u IS NULL THEN RETURN NULL;END IF;
 texto:=replace(recurso,'_',' ')||': '||OLD.estado||' → '||NEW.estado;
 EXECUTE format('INSERT INTO comunicacion.notificacion(destinatario_usuario_id,tipo,titulo,contenido,evento_id,version_cotizacion_id,%I) VALUES($1,$2,$3,$3,$4,$5,$6) ON CONFLICT DO NOTHING',ctx)
 USING u,tipo,texto,gen_random_uuid(),vers,rid;
 RETURN NULL;
END $$;

CREATE TRIGGER z70_notificar AFTER UPDATE ON comercial.pedido FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON comercial.cotizacion FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON comercial.solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON comercial.factura FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON servicios.solicitud_servicio FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON servicios.orden_servicio FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON proyectos.solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON proyectos.proyecto FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON comercial.version_cotizacion FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();

-- MÓDULO 55_autenticacion_backend
CREATE FUNCTION identidad.datos_autenticacion(p_correo text)
RETURNS TABLE(usuario_id bigint,password_hash text,estado text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF NOT identidad.es_dba() AND NOT pg_has_role(session_user,'st_worker','MEMBER') THEN RAISE EXCEPTION 'Solo servicio de autenticación' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT u.id,c.password_hash,u.estado FROM identidad.usuario u
 JOIN identidad.persona p ON p.id=u.persona_id JOIN identidad.credencial c ON c.usuario_id=u.id
 WHERE u.correo_acceso=lower(btrim(p_correo)) AND u.origen_auth='local' AND p.activo AND u.estado IN ('pendiente','activo');
END $$;
CREATE PROCEDURE identidad.confirmar_correo(p_usuario bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();
 IF NOT identidad.es_dba() AND NOT pg_has_role(session_user,'st_worker','MEMBER') THEN RAISE EXCEPTION 'Solo servicio de autenticación' USING ERRCODE='42501'; END IF;
 UPDATE identidad.usuario SET estado='activo',verificado_en=clock_timestamp() WHERE id=p_usuario AND estado='pendiente';
 IF NOT FOUND THEN RAISE EXCEPTION 'La cuenta no está pendiente'; END IF;
END $$;
CREATE FUNCTION identidad.estado_sesion(p_sesion bigint,p_hash bytea)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE u bigint;
BEGIN
 IF NOT identidad.es_dba() AND NOT pg_has_role(session_user,'st_worker','MEMBER') THEN RAISE EXCEPTION 'Solo servicio de autenticación' USING ERRCODE='42501'; END IF;
 SELECT s.usuario_id INTO u FROM identidad.sesion s JOIN identidad.usuario x ON x.id=s.usuario_id
 JOIN identidad.persona p ON p.id=x.persona_id WHERE s.id=p_sesion AND s.refresh_hash=p_hash
 AND s.revocada_en IS NULL AND s.inicia_en<=clock_timestamp() AND s.vence_en>clock_timestamp() AND x.estado='activo' AND p.activo;
 RETURN u;
END $$;
CREATE PROCEDURE comercial.vincular_comprobante(p_factura bigint,p_archivo bigint,p_clase text,p_descripcion text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('factura','gestionar',p_factura);
 IF p_id IS NOT NULL THEN RAISE EXCEPTION 'El identificador de alta debe ser NULL'; END IF;
 IF NOT EXISTS(SELECT 1 FROM comercial.factura WHERE id=p_factura AND estado IN ('emitida','anulada')) THEN RAISE EXCEPTION 'Comprobante requiere factura emitida'; END IF;
 IF NOT comunicacion.puede_leer_archivo(p_archivo) THEN PERFORM identidad.exigir_permiso('archivo','gestionar',p_archivo); END IF;
 IF NOT EXISTS(SELECT 1 FROM comunicacion.archivo WHERE id=p_archivo AND estado='validado' AND visibilidad='privado') THEN RAISE EXCEPTION 'Comprobante requiere archivo privado validado'; END IF;
 INSERT INTO comercial.comprobante_factura(factura_id,archivo_id,clase_documento,descripcion)
 VALUES(p_factura,p_archivo,p_clase,p_descripcion) RETURNING id INTO p_id;
END $$;

RESET search_path;
RESET ROLE;
