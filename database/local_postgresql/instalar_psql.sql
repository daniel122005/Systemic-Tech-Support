-- Archivo de entrada PARA PSQL. No borra bases ni reutiliza roles existentes.
\set ON_ERROR_STOP on
\encoding UTF8
\connect postgres
DO $$
BEGIN
 IF current_setting('server_version_num')::integer<180000 THEN RAISE EXCEPTION 'Requiere PostgreSQL 18'; END IF;
 IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname=session_user) THEN RAISE EXCEPTION 'Ejecute como postgres/superusuario para crear roles y base'; END IF;
 IF EXISTS(SELECT 1 FROM pg_database WHERE datname='systemic_tech_db') THEN RAISE EXCEPTION 'systemic_tech_db ya existe. No se ha modificado. Revisar antes de instalar'; END IF;
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname IN ('st_owner','st_dba','st_app','st_worker','st_lectura','st_administracion','st_backend','st_trabajador','st_consulta')) THEN RAISE EXCEPTION 'Existen roles st_*. Instalación detenida sin reutilizarlos'; END IF;
END $$;

\ir 00_roles.sql
CREATE DATABASE systemic_tech_db OWNER st_owner ENCODING 'UTF8' TEMPLATE template0;
\connect systemic_tech_db
\ir estructura_y_logica.sql
\ir 70_datos_demo.sql
-- Complemento de datos ficticios (imágenes, archivos, comprobante, entregas, acceso de invitado).
BEGIN;
\ir 71_datos_demo_complemento.sql
COMMIT;
\ir 80_verificacion.sql
\echo INSTALACION Y VERIFICACION BASICA TERMINADAS
