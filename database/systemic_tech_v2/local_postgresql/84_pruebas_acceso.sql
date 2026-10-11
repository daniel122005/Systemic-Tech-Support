\set ON_ERROR_STOP on
-- Lecturas con identidad SQL real de aplicación, sobre datos ficticios del instalador.
BEGIN;
CREATE TEMP TABLE contexto_acceso(uid bigint,cliente bigint) ON COMMIT DROP;
INSERT INTO contexto_acceso SELECT u.id,c.id FROM identidad.usuario u JOIN identidad.cliente c ON c.persona_id=u.persona_id WHERE c.codigo='DEMO-CLIENTE-001';
GRANT SELECT ON contexto_acceso TO st_app;
SET SESSION AUTHORIZATION st_app;
DO $$
DECLARE u bigint; c bigint; n bigint; fallo boolean:=false;
BEGIN
 SELECT uid,cliente INTO STRICT u,c FROM pg_temp.contexto_acceso;
 PERFORM set_config('app.usuario_id',u::text,true);
 PERFORM set_config('app.invitado_token','',true);
 IF identidad.es_dba() THEN RAISE EXCEPTION 'A01: la prueba conserva privilegios de DBA'; END IF;
 SELECT count(*) INTO n FROM identidad.cliente WHERE id<>c;
 IF n<>0 THEN RAISE EXCEPTION 'A02: datos de otro cliente visibles'; END IF;
 SELECT count(*) INTO n FROM comercial.v_resumen_pedidos;
 IF n<>2 THEN RAISE EXCEPTION 'A03: se esperaban dos pedidos del cliente demo, encontrados %',n; END IF;
 SELECT count(*) INTO n FROM inventario.v_productos_disponibles;
 IF n<>2 THEN RAISE EXCEPTION 'A04: catálogo demo incompleto'; END IF;
 SELECT count(*) INTO n FROM comercial.v_facturas_cliente;
 IF n<>1 THEN RAISE EXCEPTION 'A05: factura del cliente no visible'; END IF;
 BEGIN PERFORM password_hash FROM identidad.credencial;
 EXCEPTION WHEN insufficient_privilege THEN fallo:=true; END;
 IF NOT fallo THEN RAISE EXCEPTION 'A06: acceso directo al almacén de credenciales'; END IF;
 PERFORM set_config('app.usuario_id','',true);
 SELECT count(*) INTO n FROM comercial.pedido;
 IF n<>0 THEN RAISE EXCEPTION 'A07: contexto anónimo sin token obtiene pedidos'; END IF;
 SELECT count(*) INTO n FROM inventario.v_productos_disponibles;
 IF n<>2 THEN RAISE EXCEPTION 'A08: anonimato no puede consultar catálogo público'; END IF;
 RAISE NOTICE 'A01-A08 OK: cliente, anonimato, catálogo y privilegios SQL';
END $$;
RESET SESSION AUTHORIZATION;
ROLLBACK;
