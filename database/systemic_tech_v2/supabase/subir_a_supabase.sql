-- Sube la base de datos de Systemic Tech a Supabase desde SQL Shell (psql).
-- Uso (conectado a Supabase como postgres):  \i 'C:/.../supabase/subir_a_supabase.sql'
-- Aplica las 6 migraciones en orden, cada una en su propia transacción, y verifica al final.
-- NO carga datos ficticios. Si algo falla, se detiene y esa migración no deja nada a medias.
\set ON_ERROR_STOP on
\encoding UTF8
\echo '=== Comprobando que estás conectado a Supabase ==='
DO $$ BEGIN
  IF to_regclass('auth.users') IS NULL THEN RAISE EXCEPTION 'Esta conexión NO es Supabase (no existe auth.users). Revisa Server/Username.'; END IF;
  IF current_setting('server_version_num')::int < 170000 THEN RAISE EXCEPTION 'Tu proyecto usa PostgreSQL %. Se necesita 17 o superior.', current_setting('server_version'); END IF;
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname='identidad') THEN RAISE EXCEPTION 'La base ya parece instalada (existe el esquema identidad). No se repite la instalación.'; END IF;
END $$;
\echo '=== 1/6 roles ==='
BEGIN;
\ir migrations/20261009000100_roles_systemic.sql
COMMIT;
\echo '=== 2/6 estructura (62 tablas) ==='
BEGIN;
\ir migrations/20261009000200_estructura.sql
COMMIT;
\echo '=== 3/6 logica (funciones y procedimientos) ==='
BEGIN;
\ir migrations/20261009000300_logica.sql
COMMIT;
\echo '=== 4/6 seguridad y vistas ==='
BEGIN;
\ir migrations/20261009000400_seguridad_vistas.sql
COMMIT;
\echo '=== 5/6 integracion con Supabase Auth ==='
BEGIN;
\ir migrations/20261009000500_integracion_supabase_auth.sql
COMMIT;
\echo '=== 6/6 roles y permisos de negocio ==='
BEGIN;
\ir migrations/20261009000600_datos_base.sql
COMMIT;
\echo '=== Verificacion ==='
\ir verificacion/verificacion_supabase.sql
\echo 'SUBIDA A SUPABASE TERMINADA'
