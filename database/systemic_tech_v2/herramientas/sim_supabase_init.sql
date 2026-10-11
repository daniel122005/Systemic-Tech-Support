-- SIMULACIÓN LOCAL de las condiciones de permisos de un proyecto Supabase (PostgreSQL 17).
-- Basada en supabase/postgres: migrations/db/init-scripts y migrations/10000000000000_demote-postgres.sql.
-- No sustituye `supabase start` (imagen oficial). Ejecutar como el superusuario supabase_admin.
\set ON_ERROR_STOP on
create schema if not exists extensions;
create extension if not exists "uuid-ossp" with schema extensions;
create extension if not exists pgcrypto   with schema extensions;

create role anon          nologin noinherit;
create role authenticated nologin noinherit;
create role service_role  nologin noinherit bypassrls;
create user authenticator noinherit;
grant anon, authenticated, service_role to authenticator;

-- Rol postgres degradado, como en Supabase gestionado.
create role postgres login nosuperuser createdb createrole replication bypassrls;
grant all on database postgres to postgres;                 -- sin GRANT OPTION
grant usage on schema public to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant all on tables    to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to postgres, anon, authenticated, service_role;
grant usage on schema extensions to postgres, anon, authenticated, service_role;
grant all on schema extensions to postgres;                 -- sin GRANT OPTION
grant all privileges on all routines in schema extensions to postgres with grant option;
alter default privileges in schema extensions grant all on routines to postgres with grant option;
grant anon, authenticated, service_role to postgres with admin option;

-- Esquema auth mínimo con las columnas de auth.users que usa la integración.
create schema auth authorization supabase_admin;
create user supabase_auth_admin noinherit createrole login noreplication;
create table auth.users (
  instance_id uuid, id uuid primary key, aud varchar(255), role varchar(255),
  email varchar(255) unique, encrypted_password varchar(255),
  email_confirmed_at timestamptz, phone text unique, phone_confirmed_at timestamptz,
  raw_app_meta_data jsonb, raw_user_meta_data jsonb, is_super_admin boolean,
  banned_until timestamptz, deleted_at timestamptz, last_sign_in_at timestamptz, confirmed_at timestamptz, is_anonymous boolean not null default false,
  is_sso_user boolean not null default false,
  created_at timestamptz default now(), updated_at timestamptz default now()
);
alter table auth.users owner to supabase_auth_admin;
grant all on schema auth to supabase_auth_admin;
grant usage on schema auth to anon, authenticated, service_role;
grant all on schema auth to postgres;
revoke create on schema auth from postgres;
grant all on all tables in schema auth to postgres;
create or replace function auth.uid() returns uuid language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'))::uuid $$;
alter role postgres set search_path to "$user", public, extensions;
select 'Simulación Supabase preparada' as resultado;
