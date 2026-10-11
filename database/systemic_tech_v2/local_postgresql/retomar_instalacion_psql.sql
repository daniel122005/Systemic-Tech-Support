-- Recuperación del fallo de compilación en responder_cotizacion.
-- Solo para la base creada por instalar_psql.sql cuya transacción estructural falló.
-- No elimina bases, roles, esquemas ni datos previamente confirmados.
\set ON_ERROR_STOP on
ROLLBACK;
\connect systemic_tech_db
SET client_encoding TO 'UTF8';
DO $precondiciones$
BEGIN
 IF current_database()<>'systemic_tech_db' THEN
   RAISE EXCEPTION 'La recuperación requiere systemic_tech_db';
 END IF;
 IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname=session_user) THEN
   RAISE EXCEPTION 'Ejecute la recuperación con el mismo usuario postgres/superusuario';
 END IF;
 IF (SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname=current_database())<>'st_owner' THEN
   RAISE EXCEPTION 'El propietario no coincide con el instalador original. No se modificó la estructura';
 END IF;
 IF EXISTS(SELECT 1 FROM pg_namespace WHERE nspname IN
   ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria')) THEN
   RAISE EXCEPTION 'Hay esquemas del sistema ya confirmados. Se detuvo la recuperación para conservarlos; no vuelva a instalar';
 END IF;
 IF (SELECT count(*) FROM pg_roles WHERE rolname IN
   ('st_owner','st_dba','st_app','st_worker','st_lectura','st_administracion','st_backend','st_trabajador','st_consulta'))<>9 THEN
   RAISE EXCEPTION 'Faltan roles del instalador original. No se modificó la estructura';
 END IF;
END $precondiciones$;
\ir estructura_y_logica.sql
\ir 70_datos_demo.sql
\ir 80_verificacion.sql
\echo INSTALACION Y VERIFICACION BASICA TERMINADAS
