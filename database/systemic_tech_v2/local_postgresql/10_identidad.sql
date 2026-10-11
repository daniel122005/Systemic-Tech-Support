-- Identidad y autorización para un backend confiable. Nunca exponer credenciales SQL al navegador.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;

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
 WHERE a.token_hash=public.digest(token,'sha256') AND a.revocado_en IS NULL
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
 EXECUTE format('INSERT INTO identidad.acceso_invitado(persona_id,token_hash,medio_verificacion,destino_verificado,verificado_en,emitido_en,vence_en,version_cotizacion_id,%I) VALUES($1,public.digest($2,''sha256''),$3,$4,$5,clock_timestamp(),$6,$7,$8) RETURNING id',col)
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
 SELECT * INTO r FROM identidad.recuperacion_acceso WHERE token_hash=public.digest(p_token,'sha256') AND consumida_en IS NULL AND vence_en>clock_timestamp() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Token inválido, vencido o consumido' USING ERRCODE='28000'; END IF;
 UPDATE identidad.credencial SET password_hash=p_hash_argon2,cambiada_en=clock_timestamp() WHERE usuario_id=r.usuario_id;
 UPDATE identidad.recuperacion_acceso SET consumida_en=clock_timestamp() WHERE usuario_id=r.usuario_id AND consumida_en IS NULL;
 UPDATE identidad.sesion SET revocada_en=clock_timestamp() WHERE usuario_id=r.usuario_id AND revocada_en IS NULL;
END $$;

COMMIT;
