-- Corrección 04: contacto histórico de cotización con valores del perfil como respaldo.
-- Mantiene la firma, privilegios y la restricción de contacto obligatorio.
BEGIN;
DO $precondiciones$
BEGIN
 IF current_database()<>'systemic_tech_db' THEN RAISE EXCEPTION 'Base incorrecta'; END IF;
 IF to_regprocedure('comercial.solicitar_cotizacion(bigint,text,text,text,text,text,bigint)') IS NULL THEN
   RAISE EXCEPTION 'El procedimiento de solicitudes de cotización no está instalado';
 END IF;
END $precondiciones$;
SET LOCAL ROLE st_owner;
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
COMMIT;
