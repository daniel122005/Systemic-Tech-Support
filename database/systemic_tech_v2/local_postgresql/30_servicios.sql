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
