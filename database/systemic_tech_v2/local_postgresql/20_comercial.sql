-- SYSTEMIC TECH & SUPPORT. T06–T09: inventario, pedidos, cotizaciones y factura.
-- Se instala después de los auxiliares de identidad y antes de conceder EXECUTE.
-- No COMMIT dentro de procedimientos: cada CALL es atómico con su llamador.
BEGIN;
SET LOCAL search_path = pg_catalog, pg_temp;

CREATE OR REPLACE FUNCTION comercial.persona_cotizacion(p_id bigint)
RETURNS bigint LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
 SELECT coalesce(c.persona_directa_id,s.persona_id)
 FROM comercial.cotizacion c LEFT JOIN comercial.solicitud_cotizacion s ON s.id=c.solicitud_cotizacion_id
 WHERE c.id=p_id
$$;

CREATE OR REPLACE FUNCTION inventario.existencia_disponible(p_producto bigint)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
 SELECT i.saldo-coalesce((SELECT sum(d.cantidad) FROM inventario.reserva_inventario r
 JOIN comercial.detalle_pedido d ON d.id=r.detalle_pedido_id
 WHERE d.producto_id=i.producto_id AND r.estado='activa'),0)
 FROM inventario.inventario i WHERE i.producto_id=p_producto
$$;

CREATE OR REPLACE FUNCTION comercial.total_pedido(p_id bigint)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
 SELECT coalesce(sum(d.total),0) FROM comercial.detalle_pedido d WHERE d.pedido_id=p_id
$$;
CREATE OR REPLACE FUNCTION comercial.total_cotizacion(p_version bigint)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
 SELECT coalesce(sum(d.total),0) FROM comercial.detalle_cotizacion d WHERE d.version_cotizacion_id=p_version
$$;
CREATE OR REPLACE FUNCTION comercial.total_factura(p_id bigint)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS $$
 SELECT coalesce(sum(d.total),0) FROM comercial.detalle_factura d WHERE d.factura_id=p_id
$$;

-- Función pura: distribución acumulativa que conserva el residual de centavos.
CREATE OR REPLACE FUNCTION comercial.repartir_importes(
 p_q numeric,p_b numeric,p_d numeric,p_i numeric,p_precio numeric,p_tasa numeric,
 p_usado_q numeric,p_usado_b numeric,p_usado_d numeric,p_usado_i numeric,p_nueva_q numeric)
RETURNS TABLE(descuento numeric,ajuste_base numeric,ajuste_impuesto numeric)
LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_b numeric; v_i numeric;
BEGIN
 IF p_q<=0 OR p_nueva_q<=0 OR p_usado_q+p_nueva_q>p_q THEN
  RAISE EXCEPTION 'Cantidad aplicada supera la cantidad autorizada';
 END IF;
 descuento:=round(p_d*(p_usado_q+p_nueva_q)/p_q,2)-p_usado_d;
 v_b:=round(p_b*(p_usado_q+p_nueva_q)/p_q,2)-p_usado_b;
 v_i:=round(p_i*(p_usado_q+p_nueva_q)/p_q,2)-p_usado_i;
 IF descuento<0 OR v_b<0 OR v_i<0 OR p_usado_b+v_b>p_b OR p_usado_d+descuento>p_d OR p_usado_i+v_i>p_i THEN
  RAISE EXCEPTION 'La aplicación no conserva importes no negativos y techo; requiere revisión comercial';
 END IF;
 ajuste_base:=v_b-(round(p_nueva_q*p_precio,2)-descuento);
 ajuste_impuesto:=v_i-round(v_b*p_tasa,2);
 RETURN NEXT;
END $$;

-- Los guards obtienen el mismo bloqueo global antes de inspeccionar padres.
-- Las ACL cierran DML crítico a la aplicación; los guards también frenan DML del propietario accidental.
CREATE OR REPLACE FUNCTION comercial.proteger_fila()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_estado text; v_id bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();
 IF TG_OP='UPDATE' AND TG_TABLE_NAME NOT IN ('detalle_carrito','reserva_inventario','inventario')
 AND to_jsonb(NEW)->'id' IS DISTINCT FROM to_jsonb(OLD)->'id' THEN
  RAISE EXCEPTION 'No se reasigna la identidad de una fila';
 END IF;
 IF TG_TABLE_NAME='movimiento_inventario' THEN
  IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'El libro de movimientos es inmutable; registre una compensación'; END IF;
  NEW.actor_persona_id:=identidad.actor_persona_actual(); NEW.actor_sistema:=identidad.actor_sistema_actual();
 ELSIF TG_TABLE_NAME='producto' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Los productos se desactivan, no se eliminan'; END IF;
  IF TG_OP='UPDATE' AND NEW.unidad IS DISTINCT FROM OLD.unidad AND
  (EXISTS(SELECT 1 FROM inventario.movimiento_inventario WHERE producto_id=OLD.id)
   OR EXISTS(SELECT 1 FROM comercial.detalle_pedido WHERE producto_id=OLD.id)
   OR EXISTS(SELECT 1 FROM comercial.detalle_cotizacion WHERE producto_id=OLD.id)) THEN
   RAISE EXCEPTION 'Unidad histórica no modificable; cree otro producto';
  END IF;
 ELSIF TG_TABLE_NAME='reserva_inventario' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Una reserva se cierra y conserva'; END IF;
  IF TG_OP='UPDATE' AND (OLD.estado<>'activa' OR NEW.estado='activa'
     OR NEW.detalle_pedido_id<>OLD.detalle_pedido_id OR NEW.creada_en<>OLD.creada_en) THEN
   RAISE EXCEPTION 'Reserva cerrada o cambio de identidad no permitido';
  END IF;
 ELSIF TG_TABLE_NAME='detalle_pedido' THEN
  v_id:=CASE WHEN TG_OP='DELETE' THEN OLD.pedido_id ELSE NEW.pedido_id END;
  SELECT estado INTO v_estado FROM comercial.pedido WHERE id=v_id FOR UPDATE;
  IF v_estado IS DISTINCT FROM 'borrador' THEN RAISE EXCEPTION 'Detalle de pedido confirmado es inmutable'; END IF;
  IF TG_OP='UPDATE' AND NEW.pedido_id<>OLD.pedido_id THEN RAISE EXCEPTION 'No se traslada una línea entre pedidos'; END IF;
 ELSIF TG_TABLE_NAME='pedido' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'El pedido se cancela y conserva'; END IF;
  IF TG_OP='UPDATE' AND OLD.estado<>'borrador' AND
   (to_jsonb(NEW)-ARRAY['estado','updated_at','completado_en','cancelado_en','motivo_cancelacion']) IS DISTINCT FROM
   (to_jsonb(OLD)-ARRAY['estado','updated_at','completado_en','cancelado_en','motivo_cancelacion']) THEN
   RAISE EXCEPTION 'Las condiciones del pedido quedaron congeladas';
  END IF;
 ELSIF TG_TABLE_NAME='detalle_cotizacion' THEN
  v_id:=CASE WHEN TG_OP='DELETE' THEN OLD.version_cotizacion_id ELSE NEW.version_cotizacion_id END;
  SELECT estado INTO v_estado FROM comercial.version_cotizacion WHERE id=v_id FOR UPDATE;
  IF v_estado IS DISTINCT FROM 'borrador' THEN RAISE EXCEPTION 'Una oferta enviada tiene líneas inmutables'; END IF;
  IF TG_OP='UPDATE' AND NEW.version_cotizacion_id<>OLD.version_cotizacion_id THEN RAISE EXCEPTION 'No se traslada una línea entre versiones'; END IF;
 ELSIF TG_TABLE_NAME='version_cotizacion' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Una versión se anula y conserva'; END IF;
  IF TG_OP='UPDATE' AND (NEW.cotizacion_id<>OLD.cotizacion_id OR NEW.numero_version<>OLD.numero_version) THEN
   RAISE EXCEPTION 'Identidad de versión inmutable';
  END IF;
  IF TG_OP='UPDATE' AND OLD.estado<>'borrador' AND
   (to_jsonb(NEW)-ARRAY['estado','updated_at','respondida_en','respondida_por_persona_id','evidencia_respuesta']) IS DISTINCT FROM
   (to_jsonb(OLD)-ARRAY['estado','updated_at','respondida_en','respondida_por_persona_id','evidencia_respuesta']) THEN
   RAISE EXCEPTION 'Contenido y vigencia de oferta enviada son inmutables';
  END IF;
 ELSIF TG_TABLE_NAME='cotizacion' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'La negociación se anula y conserva'; END IF;
  IF TG_OP='UPDATE' AND (NEW.numero<>OLD.numero OR NEW.solicitud_cotizacion_id IS DISTINCT FROM OLD.solicitud_cotizacion_id
     OR NEW.persona_directa_id IS DISTINCT FROM OLD.persona_directa_id) THEN RAISE EXCEPTION 'Titular de cotización inmutable'; END IF;
 ELSIF TG_TABLE_NAME='solicitud_cotizacion' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'La solicitud se cancela y conserva'; END IF;
  IF TG_OP='UPDATE' AND (NEW.persona_id<>OLD.persona_id OR NEW.contacto_nombre<>OLD.contacto_nombre
    OR NEW.contacto_correo IS DISTINCT FROM OLD.contacto_correo OR NEW.contacto_telefono IS DISTINCT FROM OLD.contacto_telefono) THEN
   RAISE EXCEPTION 'Titular y contacto recibido de solicitud son históricos';
  END IF;
 ELSIF TG_TABLE_NAME='detalle_factura' THEN
  v_id:=CASE WHEN TG_OP='DELETE' THEN OLD.factura_id ELSE NEW.factura_id END;
  SELECT estado INTO v_estado FROM comercial.factura WHERE id=v_id FOR UPDATE;
  IF v_estado IS DISTINCT FROM 'borrador' THEN RAISE EXCEPTION 'Detalle de factura emitida es inmutable'; END IF;
  IF TG_OP='UPDATE' AND NEW.factura_id<>OLD.factura_id THEN RAISE EXCEPTION 'No se traslada una línea entre facturas'; END IF;
 ELSIF TG_TABLE_NAME='factura' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'La factura se conserva incluso anulada'; END IF;
  IF TG_OP='UPDATE' AND OLD.estado<>'borrador' AND
   (to_jsonb(NEW)-ARRAY['estado','updated_at','anulada_en','motivo_anulacion']) IS DISTINCT FROM
   (to_jsonb(OLD)-ARRAY['estado','updated_at','anulada_en','motivo_anulacion']) THEN
   RAISE EXCEPTION 'La factura emitida es inmutable';
  END IF;
 ELSIF TG_TABLE_NAME='detalle_carrito' THEN
  v_id:=CASE WHEN TG_OP='DELETE' THEN OLD.carrito_id ELSE NEW.carrito_id END;
  SELECT estado INTO v_estado FROM comercial.carrito WHERE id=v_id FOR UPDATE;
  IF v_estado IS DISTINCT FROM 'abierto' THEN RAISE EXCEPTION 'Carrito cerrado'; END IF;
  IF TG_OP='UPDATE' AND (NEW.carrito_id<>OLD.carrito_id OR NEW.producto_id<>OLD.producto_id) THEN RAISE EXCEPTION 'Clave de detalle de carrito inmutable'; END IF;
 ELSIF TG_TABLE_NAME='carrito' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'El carrito se abandona y conserva'; END IF;
  IF TG_OP='UPDATE' AND OLD.estado<>'abierto' AND (to_jsonb(NEW)-'updated_at') IS DISTINCT FROM (to_jsonb(OLD)-'updated_at') THEN
   RAISE EXCEPTION 'Carrito cerrado inmutable';
  END IF;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION inventario.inicializar_saldo()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
 INSERT INTO inventario.inventario(producto_id,saldo) VALUES(NEW.id,0); RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION inventario.aplicar_movimiento()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
 UPDATE inventario.inventario SET saldo=saldo+NEW.delta,updated_at=clock_timestamp() WHERE producto_id=NEW.producto_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Producto sin fila de inventario'; END IF;
 RETURN NEW;
END $$;

-- Validación diferible: revisa el estado final, nunca la mitad de entrega/reserva.
CREATE OR REPLACE FUNCTION comercial.validar_integridad()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();
 IF EXISTS(SELECT 1 FROM inventario.producto p LEFT JOIN inventario.inventario i ON i.producto_id=p.id
  WHERE i.producto_id IS NULL OR i.saldo<>(SELECT coalesce(sum(m.delta),0) FROM inventario.movimiento_inventario m WHERE m.producto_id=p.id)
  OR i.saldo<(SELECT coalesce(sum(d.cantidad),0) FROM inventario.reserva_inventario r JOIN comercial.detalle_pedido d ON d.id=r.detalle_pedido_id WHERE d.producto_id=p.id AND r.estado='activa')) THEN
  RAISE EXCEPTION 'T06: saldo, libro de movimientos y reservas no concuerdan';
 END IF;
 IF EXISTS(SELECT 1 FROM inventario.movimiento_inventario m LEFT JOIN comercial.detalle_pedido d ON d.id=m.detalle_pedido_id
   LEFT JOIN comercial.pedido p ON p.id=d.pedido_id LEFT JOIN inventario.movimiento_inventario original ON original.id=m.compensa_movimiento_id
   WHERE (m.detalle_pedido_id IS NOT NULL AND (m.producto_id<>d.producto_id OR m.delta<>-d.cantidad OR m.tipo<>'salida' OR p.estado<>'completado'))
   OR (m.compensa_movimiento_id IS NOT NULL AND (m.producto_id<>original.producto_id OR m.delta*original.delta>=0))) THEN
  RAISE EXCEPTION 'T06: salida o compensación incoherente con su referencia';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.detalle_pedido d JOIN comercial.pedido p ON p.id=d.pedido_id
   LEFT JOIN inventario.reserva_inventario r ON r.detalle_pedido_id=d.id
   LEFT JOIN inventario.movimiento_inventario m ON m.detalle_pedido_id=d.id
   WHERE (p.estado IN ('confirmado','en_preparacion') AND r.estado IS DISTINCT FROM 'activa')
   OR (p.estado='completado' AND (r.estado IS DISTINCT FROM 'consumida' OR m.id IS NULL))
   OR (p.estado='cancelado' AND p.confirmado_en IS NOT NULL AND r.estado IS DISTINCT FROM 'liberada')
   OR (p.estado='borrador' AND r.detalle_pedido_id IS NOT NULL)
   OR (p.estado='cancelado' AND p.confirmado_en IS NULL AND r.detalle_pedido_id IS NOT NULL)
   OR (p.estado<>'completado' AND m.id IS NOT NULL)) THEN RAISE EXCEPTION 'T06: reserva/entrega no corresponde al estado del pedido'; END IF;
 IF EXISTS(SELECT 1 FROM comercial.pedido p LEFT JOIN comercial.carrito c ON c.id=p.carrito_id
   WHERE (p.carrito_id IS NOT NULL AND (c.cliente_id IS DISTINCT FROM p.cliente_id OR c.estado<>'convertido'))
   OR (p.estado IN ('confirmado','en_preparacion','completado') AND NOT EXISTS(SELECT 1 FROM comercial.detalle_pedido d WHERE d.pedido_id=p.id))
   OR (p.estado='cancelado' AND EXISTS(SELECT 1 FROM comercial.factura f WHERE f.pedido_id=p.id AND f.estado='emitida'))) THEN
  RAISE EXCEPTION 'T07: pedido vacío, carrito incompatible o cancelación con factura vigente';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.pedido p JOIN identidad.cliente c ON c.id=p.cliente_id
  LEFT JOIN comercial.version_cotizacion v ON v.id=p.version_cotizacion_id
  WHERE p.version_cotizacion_id IS NOT NULL AND (v.estado<>'aceptada' OR v.moneda<>p.moneda OR comercial.persona_cotizacion(v.cotizacion_id)<>c.persona_id)) THEN
  RAISE EXCEPTION 'T07: versión cotizada no aceptada o no corresponde al cliente/moneda';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.detalle_pedido d JOIN comercial.pedido p ON p.id=d.pedido_id
  LEFT JOIN comercial.detalle_cotizacion q ON q.id=d.detalle_cotizacion_id
  WHERE (p.version_cotizacion_id IS NULL AND (d.detalle_cotizacion_id IS NOT NULL OR d.ajuste_base<>0 OR d.ajuste_impuesto<>0))
   OR (p.version_cotizacion_id IS NOT NULL AND (q.id IS NULL OR q.version_cotizacion_id<>p.version_cotizacion_id OR q.clase<>'producto'
     OR q.producto_id<>d.producto_id OR q.descripcion<>d.descripcion OR q.unidad<>d.unidad OR q.precio_unitario<>d.precio_unitario OR q.tasa_impuesto<>d.tasa_impuesto))) THEN
  RAISE EXCEPTION 'T07: condiciones del detalle no corresponden a su fuente';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.detalle_cotizacion q JOIN comercial.detalle_pedido d ON d.detalle_cotizacion_id=q.id
  JOIN comercial.pedido p ON p.id=d.pedido_id WHERE p.estado IN ('confirmado','en_preparacion','completado')
  GROUP BY q.id HAVING sum(d.cantidad)>q.cantidad OR sum(d.subtotal)>q.subtotal OR sum(d.descuento_importe)>q.descuento_importe OR sum(d.impuesto_importe)>q.impuesto_importe) THEN
  RAISE EXCEPTION 'T07: pedidos exceden cantidad o importe de la cotización';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.cotizacion c WHERE NOT EXISTS(SELECT 1 FROM comercial.version_cotizacion v WHERE v.cotizacion_id=c.id)
  OR ((c.estado='aceptada') IS DISTINCT FROM EXISTS(SELECT 1 FROM comercial.version_cotizacion v WHERE v.cotizacion_id=c.id AND v.estado='aceptada'))) THEN
  RAISE EXCEPTION 'T08: negociación sin versión o aceptación incoherente';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.version_cotizacion v WHERE
   (v.enviada_en IS NOT NULL AND NOT EXISTS(SELECT 1 FROM comercial.detalle_cotizacion d WHERE d.version_cotizacion_id=v.id))
   OR (v.respondida_por_persona_id IS NOT NULL AND v.respondida_por_persona_id<>comercial.persona_cotizacion(v.cotizacion_id))) THEN
  RAISE EXCEPTION 'T08: oferta vacía o respondida por otra persona';
 END IF;
 -- Encabezado de factura: cada origen conserva su ruta y moneda.
 IF EXISTS(SELECT 1 FROM comercial.factura f
  LEFT JOIN comercial.pedido p ON p.id=f.pedido_id
  LEFT JOIN servicios.orden_servicio o ON o.id=f.orden_servicio_id
  LEFT JOIN proyectos.proyecto y ON y.id=f.proyecto_id
  LEFT JOIN comercial.version_cotizacion v ON v.id=coalesce(o.version_cotizacion_id,y.version_cotizacion_id)
  WHERE (f.pedido_id IS NOT NULL AND f.moneda<>p.moneda)
   OR (f.orden_servicio_id IS NOT NULL AND f.moneda<>coalesce(v.moneda,o.moneda))
   OR (f.proyecto_id IS NOT NULL AND f.moneda<>coalesce(v.moneda,y.moneda))
   OR (f.estado='emitida' AND ((f.pedido_id IS NOT NULL AND p.estado NOT IN ('confirmado','en_preparacion','completado'))
      OR o.estado='cancelada' OR y.estado='cancelado'
      OR NOT EXISTS(SELECT 1 FROM comercial.detalle_factura d WHERE d.factura_id=f.id)))) THEN
  RAISE EXCEPTION 'T09: moneda, origen o líneas de factura no válidos';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.detalle_factura d JOIN comercial.factura f ON f.id=d.factura_id
  LEFT JOIN comercial.detalle_pedido p ON p.id=d.detalle_pedido_id
  LEFT JOIN servicios.orden_servicio o ON o.id=f.orden_servicio_id
  LEFT JOIN servicios.solicitud_servicio s ON s.id=o.solicitud_servicio_id
  LEFT JOIN proyectos.proyecto y ON y.id=f.proyecto_id
  LEFT JOIN comercial.detalle_cotizacion q ON q.id=d.detalle_cotizacion_id
  WHERE (f.pedido_id IS NOT NULL AND (p.id IS NULL OR p.pedido_id<>f.pedido_id OR d.detalle_cotizacion_id IS NOT NULL
      OR d.unidad<>p.unidad OR d.precio_unitario<>p.precio_unitario OR d.descripcion<>p.descripcion OR d.tasa_impuesto<>p.tasa_impuesto))
   OR (f.pedido_id IS NULL AND d.detalle_pedido_id IS NOT NULL)
   OR (f.pedido_id IS NULL AND coalesce(o.version_cotizacion_id,y.version_cotizacion_id) IS NOT NULL AND
      (q.id IS NULL OR q.version_cotizacion_id<>coalesce(o.version_cotizacion_id,y.version_cotizacion_id)
       OR (f.proyecto_id IS NOT NULL AND q.clase<>'libre') OR (f.orden_servicio_id IS NOT NULL AND
         (q.clase NOT IN ('servicio','libre') OR (q.clase='servicio' AND q.servicio_ofrecido_id<>s.servicio_ofrecido_id)))
       OR d.unidad<>q.unidad OR d.precio_unitario<>q.precio_unitario OR d.descripcion<>q.descripcion OR d.tasa_impuesto<>q.tasa_impuesto))
   OR (f.pedido_id IS NULL AND coalesce(o.version_cotizacion_id,y.version_cotizacion_id) IS NULL AND
      (d.detalle_cotizacion_id IS NOT NULL OR d.ajuste_base<>0 OR d.tasa_impuesto<>coalesce(o.tasa_impuesto_autorizada,y.tasa_impuesto_autorizada)))) THEN
  RAISE EXCEPTION 'T09: línea de factura no corresponde a su ruta o condiciones';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.detalle_pedido p JOIN comercial.detalle_factura d ON d.detalle_pedido_id=p.id
  JOIN comercial.factura f ON f.id=d.factura_id WHERE f.estado='emitida'
  GROUP BY p.id HAVING sum(d.cantidad)>p.cantidad OR sum(d.subtotal)>p.subtotal OR sum(d.descuento_importe)>p.descuento_importe OR sum(d.impuesto_importe)>p.impuesto_importe) THEN
  RAISE EXCEPTION 'T09: facturas exceden cantidad o importes del pedido';
 END IF;
 IF EXISTS(SELECT 1 FROM comercial.detalle_cotizacion q JOIN comercial.detalle_factura d ON d.detalle_cotizacion_id=q.id
  JOIN comercial.factura f ON f.id=d.factura_id WHERE f.estado='emitida'
  GROUP BY q.id HAVING sum(d.cantidad)>q.cantidad OR sum(d.subtotal)>q.subtotal OR sum(d.descuento_importe)>q.descuento_importe OR sum(d.impuesto_importe)>q.impuesto_importe) THEN
  RAISE EXCEPTION 'T09: facturas entre procesos exceden capacidad compartida de cotización';
 END IF;
 IF EXISTS(SELECT 1 FROM servicios.orden_servicio o JOIN comercial.factura f ON f.orden_servicio_id=o.id
  JOIN comercial.detalle_factura d ON d.factura_id=f.id WHERE o.version_cotizacion_id IS NULL AND f.estado='emitida'
  GROUP BY o.id HAVING sum(d.subtotal)>o.importe_base_autorizado OR sum(d.impuesto_importe)>round(o.importe_base_autorizado*o.tasa_impuesto_autorizada,2))
 OR EXISTS(SELECT 1 FROM proyectos.proyecto y JOIN comercial.factura f ON f.proyecto_id=y.id
  JOIN comercial.detalle_factura d ON d.factura_id=f.id WHERE y.version_cotizacion_id IS NULL AND f.estado='emitida'
  GROUP BY y.id HAVING sum(d.subtotal)>y.importe_base_autorizado OR sum(d.impuesto_importe)>round(y.importe_base_autorizado*y.tasa_impuesto_autorizada,2)) THEN
  RAISE EXCEPTION 'T09: facturación directa supera autorización de origen';
 END IF;
END $$;

CREATE OR REPLACE FUNCTION comercial.validar_integridad_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN PERFORM comercial.validar_integridad(); RETURN NULL; END $$;

DO $triggers$
DECLARE v text;
BEGIN
 FOREACH v IN ARRAY ARRAY['inventario.producto','inventario.inventario','inventario.movimiento_inventario','inventario.reserva_inventario',
 'comercial.pedido','comercial.detalle_pedido','comercial.cotizacion','comercial.version_cotizacion','comercial.detalle_cotizacion',
 'comercial.factura','comercial.detalle_factura','comercial.carrito','comercial.detalle_carrito','comercial.solicitud_cotizacion'] LOOP
  EXECUTE format('CREATE TRIGGER b20_guard BEFORE INSERT OR UPDATE OR DELETE ON %s FOR EACH ROW EXECUTE FUNCTION comercial.proteger_fila()',v);
  EXECUTE format('CREATE CONSTRAINT TRIGGER z20_integridad AFTER INSERT OR UPDATE OR DELETE ON %s DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION comercial.validar_integridad_trigger()',v);
 END LOOP;
 FOREACH v IN ARRAY ARRAY['servicios.orden_servicio','servicios.solicitud_servicio','proyectos.proyecto','proyectos.solicitud_desarrollo','identidad.cliente'] LOOP
  EXECUTE format('CREATE CONSTRAINT TRIGGER z20_integridad AFTER INSERT OR UPDATE OR DELETE ON %s DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION comercial.validar_integridad_trigger()',v);
 END LOOP;
END $triggers$;
CREATE TRIGGER c20_inicializar AFTER INSERT ON inventario.producto FOR EACH ROW EXECUTE FUNCTION inventario.inicializar_saldo();
CREATE TRIGGER c20_aplicar AFTER INSERT ON inventario.movimiento_inventario FOR EACH ROW EXECUTE FUNCTION inventario.aplicar_movimiento();

-- API: movimientos manuales no admiten detalle_pedido; la entrega lo gestiona.
CREATE OR REPLACE PROCEDURE inventario.registrar_movimiento(p_producto bigint,p_tipo text,p_delta numeric,p_motivo text,p_operacion uuid,p_compensa bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE m inventario.movimiento_inventario%ROWTYPE;
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('inventario','gestionar',p_producto);
 SELECT * INTO m FROM inventario.movimiento_inventario WHERE operacion_id=p_operacion;
 IF FOUND THEN
  IF m.producto_id<>p_producto OR m.tipo<>p_tipo OR m.delta<>p_delta OR m.motivo<>p_motivo OR m.compensa_movimiento_id IS DISTINCT FROM p_compensa OR m.detalle_pedido_id IS NOT NULL THEN
   RAISE EXCEPTION 'La clave idempotente ya representa otro movimiento';
  END IF; RETURN;
 END IF;
 PERFORM 1 FROM inventario.inventario WHERE producto_id=p_producto FOR UPDATE;
 INSERT INTO inventario.movimiento_inventario(producto_id,tipo,delta,motivo,operacion_id,compensa_movimiento_id,actor_persona_id,actor_sistema)
 VALUES(p_producto,p_tipo,p_delta,p_motivo,p_operacion,p_compensa,identidad.actor_persona_actual(),identidad.actor_sistema_actual());
 PERFORM comercial.validar_integridad();
END $$;

CREATE OR REPLACE PROCEDURE inventario.guardar_producto(INOUT p_id bigint,p_sku text,p_categoria bigint,p_nombre text,p_descripcion text,p_unidad text,p_precio numeric,p_moneda text,p_publicado boolean,p_activo boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('producto','gestionar',p_id);
 IF p_id IS NULL THEN
  INSERT INTO inventario.producto(sku,categoria_id,nombre,descripcion,unidad,precio_vigente,moneda,publicado,activo)
  VALUES(p_sku,p_categoria,p_nombre,p_descripcion,p_unidad,p_precio,p_moneda,p_publicado,p_activo) RETURNING id INTO p_id;
 ELSE
  UPDATE inventario.producto SET sku=p_sku,categoria_id=p_categoria,nombre=p_nombre,descripcion=p_descripcion,unidad=p_unidad,
    precio_vigente=p_precio,moneda=p_moneda,publicado=p_publicado,activo=p_activo WHERE id=p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Producto inexistente'; END IF;
 END IF;
END $$;

CREATE OR REPLACE PROCEDURE comercial.crear_pedido(INOUT p_id bigint,p_cliente bigint,p_moneda text,p_nombre text,p_correo text,p_telefono text,p_version bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('cliente','crear',p_cliente);
 IF p_id IS NOT NULL THEN RAISE EXCEPTION 'Para crear un pedido el identificador de salida debe ser NULL'; END IF;
 INSERT INTO comercial.pedido(cliente_id,moneda,receptor_nombre,receptor_correo,receptor_telefono,version_cotizacion_id)
 VALUES(p_cliente,p_moneda,p_nombre,p_correo,p_telefono,p_version) RETURNING id INTO p_id;
END $$;

CREATE OR REPLACE PROCEDURE comercial.guardar_detalle_pedido(INOUT p_id bigint,p_pedido bigint,p_numero integer,p_producto bigint,p_cantidad numeric,p_tasa numeric,p_descuento numeric DEFAULT 0,p_detalle_cotizacion bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE pr inventario.producto%ROWTYPE; q comercial.detalle_cotizacion%ROWTYPE; pe comercial.pedido%ROWTYPE;
 v_descripcion text; v_unidad text; v_precio numeric; v_tasa numeric; v_descuento numeric;
BEGIN
 PERFORM identidad.bloquear_operacion(); PERFORM identidad.exigir_permiso('pedido','gestionar',p_pedido);
 SELECT * INTO STRICT pe FROM comercial.pedido WHERE id=p_pedido FOR UPDATE;
 IF pe.estado<>'borrador' THEN RAISE EXCEPTION 'El pedido ya no es borrador'; END IF;
 SELECT * INTO STRICT pr FROM inventario.producto WHERE id=p_producto;
 IF NOT pr.activo OR NOT pr.publicado THEN RAISE EXCEPTION 'Producto no disponible para venta'; END IF;
 IF pe.version_cotizacion_id IS NOT NULL THEN
  SELECT * INTO STRICT q FROM comercial.detalle_cotizacion WHERE id=p_detalle_cotizacion;
  IF q.version_cotizacion_id<>pe.version_cotizacion_id OR q.clase<>'producto' OR q.producto_id<>p_producto THEN RAISE EXCEPTION 'Línea cotizada incompatible'; END IF;
  v_descripcion:=q.descripcion; v_unidad:=q.unidad; v_precio:=q.precio_unitario; v_tasa:=q.tasa_impuesto; v_descuento:=0;
 ELSE
  IF p_detalle_cotizacion IS NOT NULL OR pr.moneda<>pe.moneda THEN RAISE EXCEPTION 'Moneda o fuente incompatible'; END IF;
  v_descripcion:=pr.nombre; v_unidad:=pr.unidad; v_precio:=pr.precio_vigente; v_tasa:=p_tasa; v_descuento:=p_descuento;
 END IF;
 IF p_id IS NULL THEN
  INSERT INTO comercial.detalle_pedido(pedido_id,numero_linea,producto_id,detalle_cotizacion_id,descripcion,cantidad,unidad,precio_unitario,descuento_importe,tasa_impuesto)
   VALUES(p_pedido,p_numero,p_producto,p_detalle_cotizacion,v_descripcion,p_cantidad,v_unidad,v_precio,v_descuento,v_tasa) RETURNING id INTO p_id;
 ELSE
  UPDATE comercial.detalle_pedido SET numero_linea=p_numero,producto_id=p_producto,detalle_cotizacion_id=p_detalle_cotizacion,descripcion=v_descripcion,
    cantidad=p_cantidad,unidad=v_unidad,precio_unitario=v_precio,descuento_importe=v_descuento,tasa_impuesto=v_tasa,ajuste_base=0,ajuste_impuesto=0 WHERE id=p_id AND pedido_id=p_pedido;
  IF NOT FOUND THEN RAISE EXCEPTION 'Detalle no pertenece al pedido'; END IF;
 END IF;
END $$;

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

-- Carrito anónimo: el backend genera el secreto aleatorio; solamente se guarda SHA-256.
CREATE FUNCTION comercial.exigir_carrito(p_id bigint,p_token text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE c comercial.carrito%ROWTYPE;
BEGIN
 SELECT * INTO STRICT c FROM comercial.carrito WHERE id=p_id FOR UPDATE;
 IF identidad.es_dba() THEN RETURN; END IF;
 IF c.cliente_id IS NOT NULL THEN PERFORM identidad.exigir_permiso('carrito','editar',p_id); RETURN; END IF;
 IF p_token IS NULL OR length(p_token)<43 OR length(p_token)>512 OR c.sesion_anonima_hash IS DISTINCT FROM public.digest(p_token,'sha256') THEN
  RAISE EXCEPTION 'Secreto de carrito inválido' USING ERRCODE='42501';
 END IF;
END $$;

CREATE PROCEDURE comercial.crear_carrito(p_cliente bigint,p_token text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('carrito','crear');
 IF p_id IS NOT NULL THEN RAISE EXCEPTION 'El identificador de alta debe ser NULL'; END IF;
 IF p_cliente IS NOT NULL THEN
  PERFORM identidad.exigir_permiso('cliente','crear',p_cliente);
  IF p_token IS NOT NULL THEN RAISE EXCEPTION 'Carrito de cliente no usa secreto anónimo'; END IF;
 ELSE
  IF p_token IS NULL OR length(p_token)<43 OR length(p_token)>512 THEN RAISE EXCEPTION 'El backend debe generar un secreto aleatorio de 256 bits'; END IF;
 END IF;
 INSERT INTO comercial.carrito(cliente_id,sesion_anonima_hash) VALUES(p_cliente,CASE WHEN p_token IS NULL THEN NULL ELSE public.digest(p_token,'sha256') END) RETURNING id INTO p_id;
END $$;

CREATE PROCEDURE comercial.editar_carrito(p_id bigint,p_token text,p_producto bigint,p_cantidad numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM comercial.exigir_carrito(p_id,p_token);
 IF NOT EXISTS(SELECT 1 FROM comercial.carrito WHERE id=p_id AND estado='abierto') THEN RAISE EXCEPTION 'Carrito cerrado'; END IF;
 IF p_cantidad=0 THEN DELETE FROM comercial.detalle_carrito WHERE carrito_id=p_id AND producto_id=p_producto; RETURN; END IF;
 IF NOT EXISTS(SELECT 1 FROM inventario.producto WHERE id=p_producto AND activo AND publicado) THEN RAISE EXCEPTION 'Producto no disponible'; END IF;
 INSERT INTO comercial.detalle_carrito(carrito_id,producto_id,cantidad) VALUES(p_id,p_producto,p_cantidad)
 ON CONFLICT(carrito_id,producto_id) DO UPDATE SET cantidad=EXCLUDED.cantidad;
END $$;

CREATE PROCEDURE comercial.abandonar_carrito(p_id bigint,p_token text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM comercial.exigir_carrito(p_id,p_token);
 UPDATE comercial.carrito SET estado='abandonado' WHERE id=p_id AND estado='abierto';
 IF NOT FOUND THEN RAISE EXCEPTION 'Carrito cerrado'; END IF;
END $$;

-- La tasa es una decisión del backend autorizado; nunca se copia sin validar del navegador.
CREATE PROCEDURE comercial.convertir_carrito(p_carrito bigint,p_token text,p_nombres text,p_apellidos text,p_correo text,p_telefono text,p_moneda text,p_tasa numeric,INOUT p_pedido bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE c comercial.carrito%ROWTYPE; cli bigint; persona bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('pedido','crear');PERFORM comercial.exigir_carrito(p_carrito,p_token);
 IF p_pedido IS NOT NULL THEN RAISE EXCEPTION 'El identificador de salida debe ser NULL'; END IF;
 SELECT * INTO STRICT c FROM comercial.carrito WHERE id=p_carrito FOR UPDATE;
 IF c.estado<>'abierto' THEN RAISE EXCEPTION 'El carrito ya fue convertido o abandonado'; END IF;
 IF NOT EXISTS(SELECT 1 FROM comercial.detalle_carrito WHERE carrito_id=p_carrito) THEN RAISE EXCEPTION 'Carrito vacío'; END IF;
 IF EXISTS(SELECT 1 FROM comercial.detalle_carrito d JOIN inventario.producto p ON p.id=d.producto_id WHERE d.carrito_id=p_carrito AND (NOT p.activo OR NOT p.publicado OR p.moneda<>p_moneda)) THEN RAISE EXCEPTION 'Producto inactivo o moneda incompatible'; END IF;
 cli:=c.cliente_id;
 IF cli IS NULL THEN
  INSERT INTO identidad.persona(nombres,apellidos,correo_contacto,telefono) VALUES(p_nombres,p_apellidos,p_correo,p_telefono) RETURNING id INTO persona;
  INSERT INTO identidad.cliente(persona_id,codigo) VALUES(persona,'CLI-'||gen_random_uuid()) RETURNING id INTO cli;
  UPDATE comercial.carrito SET cliente_id=cli,sesion_anonima_hash=NULL WHERE id=p_carrito;
 END IF;
 INSERT INTO comercial.pedido(cliente_id,carrito_id,moneda,receptor_nombre,receptor_correo,receptor_telefono)
 VALUES(cli,p_carrito,p_moneda,concat_ws(' ',p_nombres,p_apellidos),p_correo,p_telefono) RETURNING id INTO p_pedido;
 INSERT INTO comercial.detalle_pedido(pedido_id,numero_linea,producto_id,descripcion,cantidad,unidad,precio_unitario,tasa_impuesto)
 SELECT p_pedido,(row_number() OVER(ORDER BY d.producto_id))::integer,p.id,p.nombre,d.cantidad,p.unidad,p.precio_vigente,p_tasa
 FROM comercial.detalle_carrito d JOIN inventario.producto p ON p.id=d.producto_id WHERE d.carrito_id=p_carrito;
 UPDATE comercial.carrito SET estado='convertido' WHERE id=p_carrito;
 -- Se entrega un borrador con precios del instante de conversión. Confirmar exige identidad o acceso verificado al pedido.
 PERFORM comercial.validar_integridad();
END $$;

CREATE PROCEDURE comercial.quitar_detalle_pedido(p_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE pid bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();SELECT pedido_id INTO STRICT pid FROM comercial.detalle_pedido WHERE id=p_id;
 PERFORM identidad.exigir_permiso('pedido','gestionar',pid);DELETE FROM comercial.detalle_pedido WHERE id=p_id;
END $$;

-- Alta pública con persona nueva o titular autenticado; no acepta apropiarse de una identidad existente.
CREATE OR REPLACE PROCEDURE comercial.solicitar_cotizacion(p_persona bigint,p_nombres text,p_apellidos text,p_correo text,p_telefono text,p_necesidad text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v_persona bigint:=p_persona; v_perfil identidad.persona%ROWTYPE;
 v_nombres text:=nullif(btrim(p_nombres),''); v_apellidos text:=nullif(btrim(p_apellidos),'');
 v_correo text:=nullif(btrim(p_correo),''); v_telefono text:=nullif(btrim(p_telefono),'');
 v_contacto_nombre text;
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('solicitud_cotizacion','crear');
 IF p_id IS NOT NULL THEN RAISE EXCEPTION 'El identificador de alta debe ser NULL'; END IF;
 IF v_persona IS NOT NULL THEN
   PERFORM identidad.exigir_permiso('persona','editar',v_persona);
   SELECT pe.* INTO STRICT v_perfil FROM identidad.persona pe WHERE pe.id=v_persona;
   IF NOT v_perfil.activo THEN RAISE EXCEPTION 'El solicitante está inactivo' USING ERRCODE='22023'; END IF;
   -- Los datos explícitos son el contacto de esta solicitud; lo omitido se toma del perfil.
   v_nombres:=coalesce(v_nombres,nullif(btrim(v_perfil.nombres),''));
   v_apellidos:=coalesce(v_apellidos,nullif(btrim(v_perfil.apellidos),''));
   v_correo:=coalesce(v_correo,nullif(btrim(v_perfil.correo_contacto),''));
   v_telefono:=coalesce(v_telefono,nullif(btrim(v_perfil.telefono),''));
 END IF;
 v_contacto_nombre:=nullif(btrim(concat_ws(' ',v_nombres,v_apellidos)),'');
 IF v_nombres IS NULL OR v_contacto_nombre IS NULL THEN
   RAISE EXCEPTION 'La solicitud requiere el nombre del contacto' USING ERRCODE='22023';
 END IF;
 IF v_correo IS NULL AND v_telefono IS NULL THEN
   RAISE EXCEPTION 'La solicitud requiere al menos un correo o teléfono de contacto' USING ERRCODE='22023';
 END IF;
 IF v_persona IS NULL THEN
   INSERT INTO identidad.persona(nombres,apellidos,correo_contacto,telefono)
   VALUES(v_nombres,v_apellidos,v_correo,v_telefono) RETURNING id INTO v_persona;
 END IF;
 INSERT INTO comercial.solicitud_cotizacion(codigo,persona_id,necesidad,contacto_nombre,contacto_correo,contacto_telefono)
 VALUES('SC-'||gen_random_uuid(),v_persona,p_necesidad,v_contacto_nombre,v_correo,v_telefono) RETURNING id INTO p_id;
END $$;

CREATE PROCEDURE comercial.cambiar_estado_solicitud_cotizacion(p_id bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('solicitud_cotizacion','gestionar',p_id);
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Debe indicar motivo'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE comercial.solicitud_cotizacion SET estado=p_estado WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Solicitud inexistente'; END IF;
END $$;

CREATE PROCEDURE comercial.crear_cotizacion(p_solicitud bigint,p_persona bigint,p_moneda text,p_condiciones text,p_nombre text,p_correo text,p_telefono text,p_vigente_hasta timestamptz,INOUT p_id bigint DEFAULT NULL,INOUT p_version bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('cotizacion','gestionar');
 IF p_id IS NOT NULL OR p_version IS NOT NULL THEN RAISE EXCEPTION 'Los identificadores de alta deben ser NULL'; END IF;
 IF p_vigente_hasta<=clock_timestamp() THEN RAISE EXCEPTION 'La vigencia debe ser futura'; END IF;
 INSERT INTO comercial.cotizacion(solicitud_cotizacion_id,persona_directa_id) VALUES(p_solicitud,p_persona) RETURNING id INTO p_id;
 INSERT INTO comercial.version_cotizacion(cotizacion_id,numero_version,moneda,condiciones,destinatario_nombre,destinatario_correo,destinatario_telefono,vigente_hasta)
 VALUES(p_id,1,p_moneda,p_condiciones,p_nombre,p_correo,p_telefono,p_vigente_hasta) RETURNING id INTO p_version;
END $$;

CREATE PROCEDURE comercial.revisar_cotizacion(p_cotizacion bigint,p_moneda text,p_condiciones text,p_nombre text,p_correo text,p_telefono text,p_vigente_hasta timestamptz,p_copiar_version bigint,INOUT p_version bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE c comercial.cotizacion%ROWTYPE; n integer;
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('cotizacion','gestionar',p_cotizacion);
 SELECT * INTO STRICT c FROM comercial.cotizacion WHERE id=p_cotizacion FOR UPDATE;
 IF p_version IS NOT NULL OR c.estado NOT IN ('abierta','cerrada') THEN RAISE EXCEPTION 'Solo negociación abierta/cerrada admite un nuevo borrador'; END IF;
 IF p_vigente_hasta<=clock_timestamp() THEN RAISE EXCEPTION 'La vigencia debe ser futura'; END IF;
 IF p_copiar_version IS NOT NULL AND NOT EXISTS(SELECT 1 FROM comercial.version_cotizacion WHERE id=p_copiar_version AND cotizacion_id=p_cotizacion AND moneda=p_moneda) THEN RAISE EXCEPTION 'La versión a copiar debe pertenecer a la negociación y moneda'; END IF;
 SELECT coalesce(max(numero_version),0)+1 INTO n FROM comercial.version_cotizacion WHERE cotizacion_id=p_cotizacion;
 UPDATE comercial.cotizacion SET estado='abierta' WHERE id=p_cotizacion AND estado='cerrada';
 INSERT INTO comercial.version_cotizacion(cotizacion_id,numero_version,moneda,condiciones,destinatario_nombre,destinatario_correo,destinatario_telefono,vigente_hasta)
 VALUES(p_cotizacion,n,p_moneda,p_condiciones,p_nombre,p_correo,p_telefono,p_vigente_hasta) RETURNING id INTO p_version;
 IF p_copiar_version IS NOT NULL THEN
  INSERT INTO comercial.detalle_cotizacion(version_cotizacion_id,numero_linea,clase,producto_id,servicio_ofrecido_id,descripcion,cantidad,unidad,precio_unitario,descuento_importe,tasa_impuesto)
  SELECT p_version,numero_linea,clase,producto_id,servicio_ofrecido_id,descripcion,cantidad,unidad,precio_unitario,descuento_importe,tasa_impuesto FROM comercial.detalle_cotizacion WHERE version_cotizacion_id=p_copiar_version;
 END IF;
END $$;

CREATE PROCEDURE comercial.editar_version_cotizacion(p_version bigint,p_condiciones text,p_nombre text,p_correo text,p_telefono text,p_vigente_hasta timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE c bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();SELECT cotizacion_id INTO STRICT c FROM comercial.version_cotizacion WHERE id=p_version;
 PERFORM identidad.exigir_permiso('cotizacion','gestionar',c);
 IF p_vigente_hasta<=clock_timestamp() THEN RAISE EXCEPTION 'La vigencia debe ser futura'; END IF;
 UPDATE comercial.version_cotizacion SET condiciones=p_condiciones,destinatario_nombre=p_nombre,destinatario_correo=p_correo,destinatario_telefono=p_telefono,vigente_hasta=p_vigente_hasta WHERE id=p_version AND estado='borrador';
 IF NOT FOUND THEN RAISE EXCEPTION 'Versión inexistente o ya enviada'; END IF;
END $$;

CREATE PROCEDURE comercial.guardar_detalle_cotizacion(p_version bigint,p_numero integer,p_clase text,p_producto bigint,p_servicio bigint,p_descripcion text,p_cantidad numeric,p_unidad text,p_precio numeric,p_descuento numeric,p_tasa numeric,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE c bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();SELECT cotizacion_id INTO STRICT c FROM comercial.version_cotizacion WHERE id=p_version;
 PERFORM identidad.exigir_permiso('cotizacion','gestionar',c);
 IF p_id IS NULL THEN
  INSERT INTO comercial.detalle_cotizacion(version_cotizacion_id,numero_linea,clase,producto_id,servicio_ofrecido_id,descripcion,cantidad,unidad,precio_unitario,descuento_importe,tasa_impuesto)
  VALUES(p_version,p_numero,p_clase,p_producto,p_servicio,p_descripcion,p_cantidad,p_unidad,p_precio,p_descuento,p_tasa) RETURNING id INTO p_id;
 ELSE
  UPDATE comercial.detalle_cotizacion SET numero_linea=p_numero,clase=p_clase,producto_id=p_producto,servicio_ofrecido_id=p_servicio,descripcion=p_descripcion,cantidad=p_cantidad,unidad=p_unidad,precio_unitario=p_precio,descuento_importe=p_descuento,tasa_impuesto=p_tasa WHERE id=p_id AND version_cotizacion_id=p_version;
  IF NOT FOUND THEN RAISE EXCEPTION 'Detalle ajeno a versión'; END IF;
 END IF;
END $$;

CREATE PROCEDURE comercial.quitar_detalle_cotizacion(p_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE c bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();SELECT v.cotizacion_id INTO STRICT c FROM comercial.detalle_cotizacion d JOIN comercial.version_cotizacion v ON v.id=d.version_cotizacion_id WHERE d.id=p_id;
 PERFORM identidad.exigir_permiso('cotizacion','gestionar',c);DELETE FROM comercial.detalle_cotizacion WHERE id=p_id;
END $$;

CREATE PROCEDURE comercial.enviar_cotizacion(p_version bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v comercial.version_cotizacion%ROWTYPE;
BEGIN
 PERFORM identidad.bloquear_operacion();SELECT * INTO STRICT v FROM comercial.version_cotizacion WHERE id=p_version FOR UPDATE;
 PERFORM identidad.exigir_permiso('cotizacion','gestionar',v.cotizacion_id);
 IF v.estado<>'borrador' OR v.vigente_hasta<=clock_timestamp() THEN RAISE EXCEPTION 'Borrador no vigente'; END IF;
 IF NOT EXISTS(SELECT 1 FROM comercial.cotizacion WHERE id=v.cotizacion_id AND estado='abierta') OR NOT EXISTS(SELECT 1 FROM comercial.detalle_cotizacion WHERE version_cotizacion_id=p_version) THEN RAISE EXCEPTION 'Negociación cerrada u oferta vacía'; END IF;
 PERFORM set_config('app.motivo',coalesce(nullif(btrim(p_motivo),''),'Envío de oferta'),true);
 UPDATE comercial.version_cotizacion SET estado='reemplazada' WHERE cotizacion_id=v.cotizacion_id AND estado='enviada';
 UPDATE comercial.version_cotizacion SET estado='enviada',enviada_en=clock_timestamp() WHERE id=p_version;
 PERFORM comercial.validar_integridad();
END $$;

CREATE PROCEDURE comercial.responder_cotizacion(p_version bigint,p_aceptar boolean,p_evidencia text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE v comercial.version_cotizacion%ROWTYPE; titular bigint; actor bigint; momento timestamptz;
BEGIN
 PERFORM identidad.bloquear_operacion();SELECT * INTO STRICT v FROM comercial.version_cotizacion WHERE id=p_version FOR UPDATE;
 PERFORM identidad.exigir_permiso('version_cotizacion','responder',p_version);
 titular:=comercial.persona_cotizacion(v.cotizacion_id);actor:=identidad.actor_persona_actual();
 IF NOT identidad.es_dba() AND actor IS DISTINCT FROM titular THEN RAISE EXCEPTION 'La respuesta corresponde exclusivamente al destinatario'; END IF;
 momento:=clock_timestamp();
 IF p_aceptar IS NULL OR nullif(btrim(p_evidencia),'') IS NULL THEN RAISE EXCEPTION 'Respuesta y evidencia obligatorias'; END IF;
 IF ((p_aceptar AND v.estado='aceptada') OR (NOT p_aceptar AND v.estado='rechazada'))
    AND v.evidencia_respuesta=p_evidencia THEN RETURN; END IF;
 IF v.estado<>'enviada' OR momento>v.vigente_hasta OR NOT EXISTS(SELECT 1 FROM comercial.cotizacion WHERE id=v.cotizacion_id AND estado='abierta') THEN RAISE EXCEPTION 'La versión no está disponible para responder'; END IF;
 PERFORM set_config('app.motivo',p_evidencia,true);
 UPDATE comercial.version_cotizacion SET estado=CASE WHEN p_aceptar THEN 'aceptada' ELSE 'rechazada' END,respondida_en=momento,respondida_por_persona_id=titular,evidencia_respuesta=p_evidencia WHERE id=p_version;
 -- Aceptar cierra cualquier borrador alternativo. La evidencia de una versión aceptada nunca se reescribe.
 IF p_aceptar THEN UPDATE comercial.version_cotizacion SET estado='anulada' WHERE cotizacion_id=v.cotizacion_id AND estado='borrador'; END IF;
 UPDATE comercial.cotizacion SET estado=CASE WHEN p_aceptar THEN 'aceptada' ELSE 'cerrada' END WHERE id=v.cotizacion_id;
 PERFORM comercial.validar_integridad();
END $$;

CREATE PROCEDURE comercial.anular_cotizacion(p_cotizacion bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('cotizacion','gestionar',p_cotizacion);
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Debe indicar motivo'; END IF;
 IF NOT EXISTS(SELECT 1 FROM comercial.cotizacion WHERE id=p_cotizacion AND estado IN ('abierta','cerrada')) THEN RAISE EXCEPTION 'Una negociación aceptada o anulada no se anula'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE comercial.version_cotizacion SET estado='anulada' WHERE cotizacion_id=p_cotizacion AND estado IN ('borrador','enviada');
 UPDATE comercial.cotizacion SET estado='anulada' WHERE id=p_cotizacion;
END $$;

CREATE PROCEDURE comercial.crear_factura(p_pedido bigint,p_orden bigint,p_proyecto bigint,p_nombre text,p_identificacion text,p_correo text,p_telefono text,p_direccion text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE moneda text;
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('factura','gestionar');
 IF p_id IS NOT NULL OR num_nonnulls(p_pedido,p_orden,p_proyecto)<>1 THEN RAISE EXCEPTION 'Alta de factura requiere un solo origen'; END IF;
 IF p_pedido IS NOT NULL THEN SELECT p.moneda INTO STRICT moneda FROM comercial.pedido p WHERE id=p_pedido;
 ELSIF p_orden IS NOT NULL THEN SELECT coalesce(v.moneda,o.moneda) INTO STRICT moneda FROM servicios.orden_servicio o LEFT JOIN comercial.version_cotizacion v ON v.id=o.version_cotizacion_id WHERE o.id=p_orden;
 ELSE SELECT coalesce(v.moneda,y.moneda) INTO STRICT moneda FROM proyectos.proyecto y LEFT JOIN comercial.version_cotizacion v ON v.id=y.version_cotizacion_id WHERE y.id=p_proyecto; END IF;
 INSERT INTO comercial.factura(pedido_id,orden_servicio_id,proyecto_id,moneda,receptor_nombre,receptor_identificacion,receptor_correo,receptor_telefono,receptor_direccion)
 VALUES(p_pedido,p_orden,p_proyecto,moneda,p_nombre,p_identificacion,p_correo,p_telefono,p_direccion) RETURNING id INTO p_id;
END $$;

-- Una línea toma precio, descripción, unidad y tasa de la fuente congelada.
-- Para servicio/proyecto directo se recibe una base por unidad y tasa derivada de autorización.
CREATE PROCEDURE comercial.guardar_detalle_factura(p_factura bigint,p_numero integer,p_detalle_pedido bigint,p_detalle_cotizacion bigint,p_cantidad numeric,p_descripcion text,p_unidad text,p_precio_directo numeric,p_descuento_directo numeric,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE f comercial.factura%ROWTYPE; fuente record; descripcion text; unidad text; precio numeric; tasa numeric; descuento numeric:=0; version_id bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('factura','gestionar',p_factura);
 SELECT * INTO STRICT f FROM comercial.factura WHERE id=p_factura FOR UPDATE;
 IF f.estado<>'borrador' THEN RAISE EXCEPTION 'Factura emitida'; END IF;
 IF f.pedido_id IS NOT NULL THEN
  SELECT * INTO STRICT fuente FROM comercial.detalle_pedido WHERE id=p_detalle_pedido AND pedido_id=f.pedido_id;
  IF p_detalle_cotizacion IS NOT NULL THEN RAISE EXCEPTION 'Factura de pedido no consume otra vez cotización'; END IF;
 ELSE
  IF p_detalle_pedido IS NOT NULL THEN RAISE EXCEPTION 'Detalle de pedido ajeno al origen'; END IF;
  IF f.orden_servicio_id IS NOT NULL THEN SELECT o.version_cotizacion_id,o.tasa_impuesto_autorizada INTO version_id,tasa FROM servicios.orden_servicio o WHERE id=f.orden_servicio_id;
  ELSE SELECT y.version_cotizacion_id,y.tasa_impuesto_autorizada INTO version_id,tasa FROM proyectos.proyecto y WHERE id=f.proyecto_id; END IF;
  IF version_id IS NOT NULL THEN
   SELECT * INTO STRICT fuente FROM comercial.detalle_cotizacion WHERE id=p_detalle_cotizacion AND version_cotizacion_id=version_id;
  ELSIF p_detalle_cotizacion IS NOT NULL THEN RAISE EXCEPTION 'Origen directo no tiene línea cotizada'; END IF;
 END IF;
 IF f.pedido_id IS NOT NULL OR version_id IS NOT NULL THEN
  descripcion:=fuente.descripcion;unidad:=fuente.unidad;precio:=fuente.precio_unitario;tasa:=fuente.tasa_impuesto;
 ELSE descripcion:=p_descripcion;unidad:=p_unidad;precio:=p_precio_directo;descuento:=p_descuento_directo; END IF;
 IF p_id IS NULL THEN
  INSERT INTO comercial.detalle_factura(factura_id,numero_linea,detalle_pedido_id,detalle_cotizacion_id,descripcion,cantidad,unidad,precio_unitario,descuento_importe,tasa_impuesto)
  VALUES(p_factura,p_numero,p_detalle_pedido,p_detalle_cotizacion,descripcion,p_cantidad,unidad,precio,descuento,tasa) RETURNING id INTO p_id;
 ELSE
  UPDATE comercial.detalle_factura d SET numero_linea=p_numero,detalle_pedido_id=p_detalle_pedido,detalle_cotizacion_id=p_detalle_cotizacion,descripcion=guardar_detalle_factura.descripcion,cantidad=p_cantidad,unidad=guardar_detalle_factura.unidad,precio_unitario=precio,descuento_importe=descuento,tasa_impuesto=tasa,ajuste_base=0,ajuste_impuesto=0 WHERE d.id=p_id AND factura_id=p_factura;
  IF NOT FOUND THEN RAISE EXCEPTION 'Detalle ajeno a factura'; END IF;
 END IF;
END $$;

CREATE PROCEDURE comercial.quitar_detalle_factura(p_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE f bigint;
BEGIN
 PERFORM identidad.bloquear_operacion();SELECT factura_id INTO STRICT f FROM comercial.detalle_factura WHERE id=p_id;
 PERFORM identidad.exigir_permiso('factura','gestionar',f);DELETE FROM comercial.detalle_factura WHERE id=p_id;
END $$;

CREATE PROCEDURE comercial.emitir_factura(p_factura bigint,p_operacion uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE f comercial.factura%ROWTYPE; d record; fuente record; u record; a record; techo numeric; tasa numeric; total_base numeric; total_impuesto numeric; nueva_base numeric; nuevo_impuesto numeric;
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('factura','gestionar',p_factura);
 SELECT * INTO STRICT f FROM comercial.factura WHERE id=p_factura FOR UPDATE;
 IF p_operacion IS NULL THEN RAISE EXCEPTION 'Falta identificador idempotente'; END IF;
 IF f.operacion_emision_id IS NOT NULL THEN
  IF f.operacion_emision_id<>p_operacion THEN RAISE EXCEPTION 'Factura emitida mediante otra operación'; END IF;RETURN;
 END IF;
 IF f.estado<>'borrador' OR NOT EXISTS(SELECT 1 FROM comercial.detalle_factura WHERE factura_id=p_factura) THEN RAISE EXCEPTION 'Factura no es borrador o está vacía'; END IF;
 IF f.orden_servicio_id IS NOT NULL THEN SELECT importe_base_autorizado,tasa_impuesto_autorizada INTO techo,tasa FROM servicios.orden_servicio WHERE id=f.orden_servicio_id;
 ELSIF f.proyecto_id IS NOT NULL THEN SELECT importe_base_autorizado,tasa_impuesto_autorizada INTO techo,tasa FROM proyectos.proyecto WHERE id=f.proyecto_id; END IF;
 FOR d IN SELECT * FROM comercial.detalle_factura WHERE factura_id=p_factura ORDER BY numero_linea,id LOOP
  IF d.detalle_pedido_id IS NOT NULL OR d.detalle_cotizacion_id IS NOT NULL THEN
   IF d.detalle_pedido_id IS NOT NULL THEN SELECT * INTO STRICT fuente FROM comercial.detalle_pedido WHERE id=d.detalle_pedido_id FOR UPDATE;
   ELSE SELECT * INTO STRICT fuente FROM comercial.detalle_cotizacion WHERE id=d.detalle_cotizacion_id FOR UPDATE; END IF;
   SELECT coalesce(sum(x.cantidad),0) uq,coalesce(sum(x.subtotal),0) ub,coalesce(sum(x.descuento_importe),0) ud,coalesce(sum(x.impuesto_importe),0) ui INTO u
   FROM comercial.detalle_factura x JOIN comercial.factura h ON h.id=x.factura_id
   WHERE ((d.detalle_pedido_id IS NOT NULL AND x.detalle_pedido_id=d.detalle_pedido_id) OR (d.detalle_cotizacion_id IS NOT NULL AND x.detalle_cotizacion_id=d.detalle_cotizacion_id))
     AND (h.estado='emitida' OR (h.id=p_factura AND (x.numero_linea,x.id)<(d.numero_linea,d.id)));
   SELECT * INTO a FROM comercial.repartir_importes(fuente.cantidad,fuente.subtotal,fuente.descuento_importe,fuente.impuesto_importe,fuente.precio_unitario,fuente.tasa_impuesto,u.uq,u.ub,u.ud,u.ui,d.cantidad);
   UPDATE comercial.detalle_factura SET descuento_importe=a.descuento,ajuste_base=a.ajuste_base,ajuste_impuesto=a.ajuste_impuesto WHERE id=d.id;
  ELSE
   IF techo IS NULL OR tasa IS NULL THEN RAISE EXCEPTION 'Factura cotizada requiere fuente en cada línea'; END IF;
   SELECT coalesce(sum(x.subtotal),0),coalesce(sum(x.impuesto_importe),0) INTO total_base,total_impuesto
   FROM comercial.detalle_factura x JOIN comercial.factura h ON h.id=x.factura_id
   WHERE ((f.orden_servicio_id IS NOT NULL AND h.orden_servicio_id=f.orden_servicio_id) OR (f.proyecto_id IS NOT NULL AND h.proyecto_id=f.proyecto_id))
     AND (h.estado='emitida' OR (h.id=p_factura AND (x.numero_linea,x.id)<(d.numero_linea,d.id)));
   nueva_base:=round(d.cantidad*d.precio_unitario,2)-d.descuento_importe;
   nuevo_impuesto:=round((total_base+nueva_base)*tasa,2)-total_impuesto;
   IF nueva_base<0 OR total_base+nueva_base>techo OR nuevo_impuesto<0 OR total_impuesto+nuevo_impuesto>round(techo*tasa,2) THEN RAISE EXCEPTION 'Factura supera autorización o requiere revisión de redondeo tras anulación'; END IF;
   UPDATE comercial.detalle_factura SET ajuste_base=0,ajuste_impuesto=nuevo_impuesto-round(nueva_base*tasa,2) WHERE id=d.id;
  END IF;
 END LOOP;
 UPDATE comercial.factura SET estado='emitida',numero=nextval('comercial.seq_factura'::regclass),emitida_en=clock_timestamp(),operacion_emision_id=p_operacion WHERE id=p_factura;
 PERFORM comercial.validar_integridad();
END $$;

CREATE PROCEDURE comercial.anular_factura(p_factura bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('factura','gestionar',p_factura);
 IF nullif(btrim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Debe indicar motivo de anulación'; END IF;
 PERFORM set_config('app.motivo',p_motivo,true);
 UPDATE comercial.factura SET estado='anulada',anulada_en=clock_timestamp(),motivo_anulacion=p_motivo WHERE id=p_factura AND estado='emitida';
 IF NOT FOUND THEN RAISE EXCEPTION 'Solo se anula una factura emitida'; END IF;
 PERFORM comercial.validar_integridad();
END $$;

COMMIT;
