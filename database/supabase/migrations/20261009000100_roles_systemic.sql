-- Systemic Tech & Support — migración para Supabase generada por herramientas/generar_supabase.py
-- Origen: módulos locales verificados en PostgreSQL 18.3 y 17.6. No editar a mano: regenerar.
-- Compatible con Supabase CLI (supabase db push / db reset) y con el SQL Editor (pegar completo).
-- 1/6. Roles técnicos. Equivale a 00_roles.sql adaptado a Supabase.
-- En Supabase `postgres` no es superusuario pero tiene CREATEROLE; al crear cada rol recibe ADMIN OPTION.
-- Es idempotente: si el rol existe, solo se reafirman sus atributos de seguridad.
DO $roles$
DECLARE r record;
BEGIN
  IF current_setting('server_version_num')::integer < 170000 THEN
    RAISE EXCEPTION 'Systemic Tech requiere PostgreSQL 17 o posterior';
  END IF;
  IF current_database() <> 'postgres' THEN
    RAISE EXCEPTION 'En Supabase la base de datos debe ser postgres';
  END IF;
  FOR r IN SELECT * FROM (VALUES
      ('st_owner',false),('st_dba',false),('st_app',false),('st_worker',false),('st_lectura',false),
      ('st_administracion',false),('st_backend',true),('st_trabajador',true),('st_consulta',true)) AS t(nombre,login)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r.nombre) THEN
      EXECUTE format('CREATE ROLE %I %s NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS INHERIT',
                     r.nombre, CASE WHEN r.login THEN 'LOGIN' ELSE 'NOLOGIN' END);
    ELSE
      EXECUTE format('ALTER ROLE %I %s NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
                     r.nombre, CASE WHEN r.login THEN 'LOGIN' ELSE 'NOLOGIN' END);
    END IF;
  END LOOP;
END
$roles$;
-- Sin contraseña: se fija después con \password desde psql (nunca en un archivo del repositorio).
GRANT st_owner TO st_dba;
GRANT st_app TO st_backend, st_administracion;
GRANT st_worker TO st_trabajador;
GRANT st_lectura TO st_consulta;
-- `postgres` es el administrador del proyecto Supabase: actúa como el DBA del modelo
-- (en local ese papel lo tiene el superusuario). Necesita SET ROLE st_owner para instalar.
GRANT st_dba TO postgres;
