-- Fases 5-8, T10/T11/T12. Metadatos y cola transaccional; no envía archivos ni mensajes externos.
-- Dependencias: identidad.bloquear_operacion/exigir_permiso/actor_*_actual/persona_*acceder.
BEGIN;
SET LOCAL ROLE st_owner;

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
COMMIT;
