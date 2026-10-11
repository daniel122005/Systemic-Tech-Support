\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace
 WHERE c.relkind='r' AND s.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria');
 IF n<>62 THEN RAISE EXCEPTION 'Se esperaban 62 tablas y se encontraron %',n; END IF;
 IF EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace
 WHERE c.relkind='r' AND s.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria') AND NOT c.relrowsecurity) THEN RAISE EXCEPTION 'Tabla sin RLS'; END IF;
 IF has_table_privilege('st_app','inventario.movimiento_inventario','INSERT')
 OR has_table_privilege('st_app','comercial.pedido','UPDATE')
 OR has_table_privilege('st_app','identidad.credencial','SELECT') THEN RAISE EXCEPTION 'Privilegios excesivos de aplicación'; END IF;
 IF has_function_privilege('st_app','comercial.validar_integridad()','EXECUTE') THEN RAISE EXCEPTION 'Validador interno expuesto'; END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria')
 AND p.prosecdef AND NOT coalesce(p.proconfig::text LIKE '%search_path=pg_catalog, pg_temp%' OR p.proconfig::text LIKE '%search_path=pg_catalog,pg_temp%',false)) THEN RAISE EXCEPTION 'Rutina de privilegios elevados sin search_path controlado'; END IF;
 PERFORM comercial.validar_integridad();
 -- Servicios, identidad e historial usan funciones RETURNS trigger: se ejecutan
 -- mediante sus constraint triggers al validar las transacciones de datos/pruebas.
 PERFORM comunicacion.validar_integridad();
 RAISE NOTICE 'Estructura, políticas, privilegios e invariantes comprobados';
END $$;
SET CONSTRAINTS ALL IMMEDIATE;
COMMIT;
SELECT * FROM inventario.v_inventario_actual ORDER BY producto_id;
SELECT * FROM comercial.v_resumen_pedidos ORDER BY id;
SELECT * FROM comercial.v_facturas_cliente ORDER BY id;
SELECT * FROM proyectos.v_avance_proyecto ORDER BY id;
SELECT proceso,codigo,estado,fecha FROM comercial.v_historial_cliente ORDER BY fecha DESC LIMIT 20;
SELECT operacion,esquema_objeto,tabla_objeto,count(*) AS eventos FROM auditoria.evento_auditoria GROUP BY 1,2,3 ORDER BY 2,3,1;
