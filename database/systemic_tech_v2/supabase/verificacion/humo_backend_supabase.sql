-- Prueba de humo del rol del backend en Supabase. NO modifica datos (termina en ROLLBACK).
-- Conectarse COMO st_backend (no como postgres), por ejemplo:
--   psql "postgresql://st_backend.<REF_PROYECTO>@<HOST_POOLER>:6543/postgres?sslmode=require" -f humo_backend_supabase.sql
-- psql pedirá la contraseña: no la escriba en la línea de comandos ni en archivos.
BEGIN;
DO $humo$
DECLARE u bigint; n bigint;
BEGIN
  IF session_user <> 'st_backend' THEN RAISE EXCEPTION 'H00: conéctese como st_backend (ahora: %)', session_user; END IF;
  IF identidad.es_dba() THEN RAISE EXCEPTION 'H01: st_backend no debe ser DBA'; END IF;
  -- Sujeto inexistente: sin identidad y sin filas privadas (falla cerrado).
  u := identidad.iniciar_contexto_supabase(gen_random_uuid());
  IF u IS NOT NULL THEN RAISE EXCEPTION 'H02: un sujeto desconocido obtuvo identidad'; END IF;
  SELECT count(*) INTO n FROM comercial.pedido;
  IF n <> 0 THEN RAISE EXCEPTION 'H03: sin identidad se ven % pedidos', n; END IF;
  SELECT count(*) INTO n FROM identidad.persona;
  IF n <> 0 THEN RAISE EXCEPTION 'H04: sin identidad se ven % personas', n; END IF;
  BEGIN
    UPDATE comercial.pedido SET estado = estado WHERE false;
    RAISE EXCEPTION 'H05: el backend tiene UPDATE directo sobre pedidos';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- Catálogo: las consultas públicas siguen disponibles a través del backend (RF-01/RF-07).
  PERFORM count(*) FROM inventario.producto;
  RAISE NOTICE 'Prueba de humo superada: conexión st_backend, contexto fail-closed, RLS y sin escritura directa';
END
$humo$;
ROLLBACK;
