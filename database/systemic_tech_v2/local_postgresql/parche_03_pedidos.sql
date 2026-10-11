-- Corrección 03: evita colisiones de alias SQL con el registro de detalle.
-- CREATE OR REPLACE conserva firmas, propiedad, permisos y dependencias.
BEGIN;
DO $precondiciones$
BEGIN
 IF current_database()<>'systemic_tech_db' THEN RAISE EXCEPTION 'Base de datos incorrecta'; END IF;
 IF to_regprocedure('comercial.confirmar_pedido(bigint,uuid)') IS NULL
 OR to_regprocedure('comercial.cambiar_estado_pedido(bigint,text,text)') IS NULL THEN
   RAISE EXCEPTION 'La estructura de pedidos no está instalada';
 END IF;
END $precondiciones$;
SET LOCAL ROLE st_owner;
CREATE OR REPLACE PROCEDURE comercial.confirmar_pedido(p_pedido bigint,p_operacion uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE p comercial.pedido%ROWTYPE; d record; q comercial.detalle_cotizacion%ROWTYPE; a record; u record;
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('pedido','editar',p_pedido);
 SELECT * INTO STRICT p FROM comercial.pedido WHERE id=p_pedido FOR UPDATE;
 IF p_operacion IS NULL THEN RAISE EXCEPTION 'Falta identificador idempotente'; END IF;
 IF p.operacion_confirmacion_id IS NOT NULL THEN
  IF p.operacion_confirmacion_id<>p_operacion THEN RAISE EXCEPTION 'Pedido confirmado mediante otra operación'; END IF; RETURN;
 END IF;
 IF p.estado<>'borrador' THEN RAISE EXCEPTION 'Solo se confirma un borrador'; END IF;
 IF NOT EXISTS(SELECT 1 FROM comercial.detalle_pedido WHERE pedido_id=p_pedido) THEN RAISE EXCEPTION 'Pedido vacío'; END IF;
 PERFORM i.producto_id FROM inventario.inventario i JOIN comercial.detalle_pedido linea_bloqueo ON linea_bloqueo.producto_id=i.producto_id WHERE linea_bloqueo.pedido_id=p_pedido ORDER BY i.producto_id FOR UPDATE OF i;
 FOR d IN SELECT * FROM comercial.detalle_pedido WHERE pedido_id=p_pedido ORDER BY numero_linea,id LOOP
  IF p.version_cotizacion_id IS NOT NULL THEN
   SELECT * INTO STRICT q FROM comercial.detalle_cotizacion WHERE id=d.detalle_cotizacion_id FOR UPDATE;
   SELECT coalesce(sum(x.cantidad),0) uq,coalesce(sum(x.subtotal),0) ub,coalesce(sum(x.descuento_importe),0) ud,coalesce(sum(x.impuesto_importe),0) ui INTO u
    FROM comercial.detalle_pedido x JOIN comercial.pedido h ON h.id=x.pedido_id
    WHERE x.detalle_cotizacion_id=q.id AND (h.estado IN ('confirmado','en_preparacion','completado') OR (h.id=p_pedido AND (x.numero_linea,x.id)<(d.numero_linea,d.id)));
   SELECT * INTO a FROM comercial.repartir_importes(q.cantidad,q.subtotal,q.descuento_importe,q.impuesto_importe,q.precio_unitario,q.tasa_impuesto,u.uq,u.ub,u.ud,u.ui,d.cantidad);
   UPDATE comercial.detalle_pedido SET descuento_importe=a.descuento,ajuste_base=a.ajuste_base,ajuste_impuesto=a.ajuste_impuesto WHERE id=d.id;
  END IF;
  IF inventario.existencia_disponible(d.producto_id)<d.cantidad THEN RAISE EXCEPTION 'Existencia insuficiente para producto %',d.producto_id; END IF;
  INSERT INTO inventario.reserva_inventario(detalle_pedido_id) VALUES(d.id);
 END LOOP;
 UPDATE comercial.pedido SET estado='confirmado',confirmado_en=clock_timestamp(),operacion_confirmacion_id=p_operacion WHERE id=p_pedido;
 PERFORM comercial.validar_integridad();
END $$;

CREATE OR REPLACE PROCEDURE comercial.cambiar_estado_pedido(p_pedido bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE p comercial.pedido%ROWTYPE; d record;
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('pedido','gestionar',p_pedido);
 SELECT * INTO STRICT p FROM comercial.pedido WHERE id=p_pedido FOR UPDATE;
 PERFORM set_config('app.motivo',coalesce(nullif(btrim(p_motivo),''),'Cambio de pedido'),true);
 IF p.estado=p_estado THEN RETURN; END IF;
 IF p_estado NOT IN ('en_preparacion','completado','cancelado') THEN RAISE EXCEPTION 'Use confirmar_pedido para confirmar'; END IF;
 IF p.estado IN ('completado','cancelado') THEN RAISE EXCEPTION 'Pedido terminal'; END IF;
 IF p_estado IN ('en_preparacion','completado') AND p.estado NOT IN ('confirmado','en_preparacion') THEN RAISE EXCEPTION 'Pedido sin confirmar'; END IF;
 PERFORM i.producto_id FROM inventario.inventario i JOIN comercial.detalle_pedido linea_bloqueo ON linea_bloqueo.producto_id=i.producto_id WHERE linea_bloqueo.pedido_id=p_pedido ORDER BY i.producto_id FOR UPDATE OF i;
 IF p_estado='cancelado' THEN
  IF p_motivo IS NULL OR btrim(p_motivo)='' THEN RAISE EXCEPTION 'Cancelación requiere motivo'; END IF;
  IF EXISTS(SELECT 1 FROM comercial.factura WHERE pedido_id=p_pedido AND estado='emitida') THEN RAISE EXCEPTION 'Pedido tiene facturas vigentes'; END IF;
  UPDATE inventario.reserva_inventario r SET estado='liberada',cerrada_en=clock_timestamp(),motivo_liberacion=p_motivo
   FROM comercial.detalle_pedido linea_reservada WHERE linea_reservada.id=r.detalle_pedido_id AND linea_reservada.pedido_id=p_pedido AND r.estado='activa';
  UPDATE comercial.pedido SET estado='cancelado',cancelado_en=clock_timestamp(),motivo_cancelacion=p_motivo WHERE id=p_pedido;
 ELSIF p_estado='completado' THEN
  UPDATE inventario.reserva_inventario r SET estado='consumida',cerrada_en=clock_timestamp()
   FROM comercial.detalle_pedido linea_reservada WHERE linea_reservada.id=r.detalle_pedido_id AND linea_reservada.pedido_id=p_pedido AND r.estado='activa';
  UPDATE comercial.pedido SET estado='completado',completado_en=clock_timestamp() WHERE id=p_pedido;
  FOR d IN SELECT * FROM comercial.detalle_pedido WHERE pedido_id=p_pedido ORDER BY producto_id,id LOOP
   INSERT INTO inventario.movimiento_inventario(producto_id,tipo,delta,motivo,detalle_pedido_id,operacion_id,actor_persona_id,actor_sistema)
    VALUES(d.producto_id,'salida',-d.cantidad,coalesce(nullif(btrim(p_motivo),''),'Entrega completa del pedido'),d.id,gen_random_uuid(),identidad.actor_persona_actual(),identidad.actor_sistema_actual());
  END LOOP;
 ELSE UPDATE comercial.pedido SET estado=p_estado WHERE id=p_pedido;
 END IF;
 PERFORM comercial.validar_integridad();
END $$;
COMMIT;
