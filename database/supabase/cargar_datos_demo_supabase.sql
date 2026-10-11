-- OPCIONAL y SOLO para un proyecto de desarrollo/pruebas: carga los datos ficticios.
-- NUNCA en el proyecto de producción (estos datos no se pueden borrar fácilmente).
\set ON_ERROR_STOP on
\encoding UTF8
BEGIN;
\ir seed.sql
COMMIT;
\echo 'DATOS DE DEMOSTRACION CARGADOS EN SUPABASE'
