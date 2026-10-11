-- Paso posterior a retomar_datos_psql.sql: completa los datos ficticios (71) y repite la verificación básica.
-- No borra ni reemplaza datos. Si el complemento ya existe, se detiene sin cambios.
\set ON_ERROR_STOP on
\connect systemic_tech_db
SET client_encoding TO 'UTF8';
BEGIN;
\ir 71_datos_demo_complemento.sql
COMMIT;
\ir 80_verificacion.sql
\echo COMPLEMENTO DE DATOS Y VERIFICACION BASICA TERMINADOS
