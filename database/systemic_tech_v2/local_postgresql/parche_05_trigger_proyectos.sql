-- Corrección 05: separar los campos específicos de cada tabla en el trigger compartido.
-- Reemplaza la función en su lugar; conserva los triggers y permisos existentes.
BEGIN;
DO $precondiciones$
BEGIN
 IF current_database()<>'systemic_tech_db' THEN RAISE EXCEPTION 'Base incorrecta'; END IF;
 IF to_regprocedure('proyectos.proteger_datos()') IS NULL THEN
   RAISE EXCEPTION 'La función del trigger de proyectos no está instalada';
 END IF;
END $precondiciones$;
SET LOCAL ROLE st_owner;
CREATE OR REPLACE FUNCTION proyectos.proteger_datos() RETURNS trigger
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
COMMIT;
