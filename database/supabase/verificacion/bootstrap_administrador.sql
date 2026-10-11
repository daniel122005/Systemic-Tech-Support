-- Asigna el rol de negocio "administrador" a la primera cuenta real (RF-32, RF-42).
-- Pasos: 1) la persona se registra en la plataforma con Supabase Auth y confirma su correo;
--        2) ejecute este script en el SQL Editor como postgres, cambiando SOLO el correo de la línea marcada.
-- Es idempotente: si la cuenta ya tiene el rol vigente, no hace nada.
DO $bootstrap$
DECLARE
  v_correo text := lower(btrim('admin@su-dominio.com'));   -- <<< CAMBIE ESTE CORREO
  v_usuario bigint; v_rol bigint;
BEGIN
  IF NOT identidad.es_dba() THEN RAISE EXCEPTION 'Ejecute como postgres (DBA del proyecto)'; END IF;
  IF v_correo LIKE '%su-dominio.com' THEN RAISE EXCEPTION 'Edite el correo antes de ejecutar'; END IF;
  SELECT u.id INTO v_usuario FROM identidad.usuario u
   WHERE u.correo_acceso = v_correo AND u.emisor_externo = 'supabase-auth' AND u.estado = 'activo';
  IF v_usuario IS NULL THEN
    RAISE EXCEPTION 'No hay una cuenta activa de Supabase Auth con el correo % (¿confirmó su correo?)', v_correo;
  END IF;
  SELECT id INTO STRICT v_rol FROM identidad.rol WHERE codigo = 'administrador';
  IF EXISTS (SELECT 1 FROM identidad.usuario_rol WHERE usuario_id = v_usuario AND rol_id = v_rol
             AND inicia_en <= clock_timestamp() AND (termina_en IS NULL OR termina_en > clock_timestamp())) THEN
    RAISE NOTICE 'La cuenta % ya es administradora', v_correo;
    RETURN;
  END IF;
  PERFORM set_config('app.motivo', 'Alta del primer administrador de la plataforma', true);
  CALL identidad.asignar_rol(v_usuario, v_rol);
  RAISE NOTICE 'Rol administrador asignado a % (usuario_id %)', v_correo, v_usuario;
END
$bootstrap$;
