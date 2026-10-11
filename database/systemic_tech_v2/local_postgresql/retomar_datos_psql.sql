-- Para la estructura ya confirmada y la primera carga demo fallida.
-- Conserva tablas, funciones, roles, políticas y demás objetos instalados.
\set ON_ERROR_STOP on
ROLLBACK;
\connect systemic_tech_db
SET client_encoding TO 'UTF8';
DO $precondiciones$
DECLARE v_tabla record; v_tiene_filas boolean; v_numero_tablas integer;
BEGIN
 IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname=session_user) THEN
   RAISE EXCEPTION 'Ejecute este archivo con el mismo usuario postgres/superusuario';
 END IF;
 SELECT count(*) INTO v_numero_tablas FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE c.relkind='r' AND n.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria');
 IF v_numero_tablas<>62 THEN
   RAISE EXCEPTION 'Se esperaban 62 tablas instaladas; se encontraron %. No se cargaron datos',v_numero_tablas;
 END IF;
 -- La carga previa era una sola transacción: tras ROLLBACK sus filas no deben existir.
 FOR v_tabla IN SELECT n.nspname AS esquema,c.relname AS tabla
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE c.relkind='r' AND n.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria') LOOP
   EXECUTE format('SELECT EXISTS(SELECT 1 FROM %I.%I)',v_tabla.esquema,v_tabla.tabla) INTO v_tiene_filas;
   IF v_tiene_filas THEN
     RAISE EXCEPTION 'Ya hay filas confirmadas en %.%. Se detuvo la carga para conservarlas y evitar duplicados',v_tabla.esquema,v_tabla.tabla;
   END IF;
 END LOOP;
END $precondiciones$;
\ir parche_03_pedidos.sql
\ir parche_04_contacto_cotizacion.sql
\ir parche_05_trigger_proyectos.sql
\ir 70_datos_demo.sql
\ir 80_verificacion.sql
\echo DATOS DE DEMOSTRACION Y VERIFICACION BASICA TERMINADOS
