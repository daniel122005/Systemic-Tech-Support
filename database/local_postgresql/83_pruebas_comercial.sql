\set ON_ERROR_STOP on
-- Ejecutar después de 70_datos_demo.sql como postgres. Todos los cambios se revierten.
BEGIN;
DO $$
DECLARE producto bigint; cliente bigint; pedido bigint; detalle bigint; factura bigint; v bigint;
 existente bigint; op uuid; saldo numeric; fallo boolean;
BEGIN
 SELECT id INTO STRICT producto FROM inventario.producto WHERE sku='DEMO-SSD-001';
 SELECT id INTO STRICT cliente FROM identidad.cliente WHERE codigo='DEMO-CLIENTE-001';
 SELECT p.id,p.operacion_confirmacion_id INTO STRICT existente,op FROM comercial.pedido p
 WHERE p.cliente_id=cliente AND p.estado='confirmado' AND p.version_cotizacion_id IS NOT NULL;
 saldo:=inventario.existencia_disponible(producto);
 CALL comercial.confirmar_pedido(existente,op);
 IF inventario.existencia_disponible(producto)<>saldo THEN RAISE EXCEPTION 'C01: confirmación duplicada alteró reserva'; END IF;
 RAISE NOTICE 'C01 OK: confirmación idempotente';
 fallo:=false;
 BEGIN CALL comercial.confirmar_pedido(existente,gen_random_uuid());
 EXCEPTION WHEN raise_exception THEN fallo:=true; END;
 IF NOT fallo THEN RAISE EXCEPTION 'C02: se aceptó otra clave sobre pedido confirmado'; END IF;
 RAISE NOTICE 'C02 OK: clave discordante rechazada';
 CALL comercial.crear_pedido(pedido,cliente,'COP','Cliente Ejemplo','cliente@example.test',NULL);
 CALL comercial.guardar_detalle_pedido(detalle,pedido,1,producto,100000,0);
 fallo:=false;
 BEGIN CALL comercial.confirmar_pedido(pedido,gen_random_uuid());
 EXCEPTION WHEN raise_exception THEN fallo:=true; END;
 IF NOT fallo OR inventario.existencia_disponible(producto)<>saldo THEN RAISE EXCEPTION 'C03: sobreventa aceptada o reserva parcial'; END IF;
 RAISE NOTICE 'C03 OK: sobreventa rechazada sin reserva parcial';
 fallo:=false;
 BEGIN UPDATE comercial.detalle_pedido SET precio_unitario=1 WHERE pedido_id=existente;
 EXCEPTION WHEN raise_exception THEN fallo:=true; END;
 IF NOT fallo THEN RAISE EXCEPTION 'C04: precio histórico alterado'; END IF;
 RAISE NOTICE 'C04 OK: detalle confirmado inmutable';
 fallo:=false;
 BEGIN UPDATE inventario.inventario i SET saldo=i.saldo+1 WHERE producto_id=producto;
 SET CONSTRAINTS ALL IMMEDIATE;
 EXCEPTION WHEN raise_exception OR check_violation THEN fallo:=true; END;
 SET CONSTRAINTS ALL DEFERRED;
 IF NOT fallo THEN RAISE EXCEPTION 'C05: proyección manipulada sin movimiento'; END IF;
 RAISE NOTICE 'C05 OK: saldo sin movimiento rechazado';
 SELECT id INTO STRICT factura FROM comercial.factura WHERE estado='emitida' AND receptor_identificacion='DEMO-001';
 fallo:=false;
 BEGIN UPDATE comercial.detalle_factura SET precio_unitario=1 WHERE factura_id=factura;
 EXCEPTION WHEN raise_exception THEN fallo:=true; END;
 IF NOT fallo THEN RAISE EXCEPTION 'C06: factura emitida modificada'; END IF;
 RAISE NOTICE 'C06 OK: factura emitida inmutable';
 fallo:=false;
 BEGIN DELETE FROM auditoria.evento_auditoria WHERE id=(SELECT min(id) FROM auditoria.evento_auditoria);
 EXCEPTION WHEN check_violation THEN fallo:=true; END;
 IF NOT fallo THEN RAISE EXCEPTION 'C07: auditoría eliminada'; END IF;
 RAISE NOTICE 'C07 OK: evidencia de auditoría protegida';
 SELECT id INTO STRICT v FROM comercial.version_cotizacion WHERE estado='aceptada' AND destinatario_correo='cliente@example.test';
 fallo:=false;
 BEGIN UPDATE comercial.detalle_cotizacion SET precio_unitario=1 WHERE version_cotizacion_id=v;
 EXCEPTION WHEN raise_exception THEN fallo:=true; END;
 IF NOT fallo THEN RAISE EXCEPTION 'C08: oferta aceptada modificada'; END IF;
 RAISE NOTICE 'C08 OK: versión aceptada y precios protegidos';
 SET CONSTRAINTS ALL IMMEDIATE;
END $$;
ROLLBACK;
