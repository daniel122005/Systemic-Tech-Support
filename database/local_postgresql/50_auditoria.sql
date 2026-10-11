-- Auditoría, historial, transiciones y revocación coordinada.
BEGIN;

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
COMMIT;
