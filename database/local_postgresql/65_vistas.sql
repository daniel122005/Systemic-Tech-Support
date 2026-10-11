BEGIN;
CREATE FUNCTION inventario.consultar_disponibilidad(p_producto bigint) RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
 SELECT inventario.existencia_disponible(p.id) FROM inventario.producto p
 WHERE p.id=p_producto AND ((p.activo AND p.publicado) OR identidad.puede_acceder('inventario',p.id,'leer'))
$$;
GRANT EXECUTE ON FUNCTION inventario.consultar_disponibilidad(bigint) TO st_app,st_lectura;
-- Vista pública: no revela movimientos ni información de compradores.
CREATE VIEW inventario.v_productos_disponibles WITH(security_barrier=true) AS
SELECT p.id,p.sku,p.nombre,p.descripcion,p.categoria_id,c.nombre AS categoria,p.unidad,
 p.precio_vigente,p.moneda,inventario.consultar_disponibilidad(p.id) AS stock_disponible
FROM inventario.producto p JOIN inventario.categoria c ON c.id=p.categoria_id
WHERE p.activo AND p.publicado AND c.activa;
-- Adaptación académica de un sinónimo: nombre alternativo mediante VIEW.
CREATE VIEW inventario.productos WITH(security_barrier=true) AS
SELECT * FROM inventario.v_productos_disponibles;
COMMENT ON VIEW inventario.productos IS 'Alias mediante vista, NO un CREATE SYNONYM nativo. Expone únicamente el catálogo público.';

CREATE VIEW inventario.v_inventario_actual WITH(security_barrier=true) AS
SELECT p.id AS producto_id,p.sku,p.nombre,p.unidad,i.saldo AS existencia_fisica,
 i.saldo-inventario.consultar_disponibilidad(p.id) AS cantidad_reservada,
 inventario.consultar_disponibilidad(p.id) AS cantidad_disponible
FROM inventario.producto p JOIN inventario.inventario i ON i.producto_id=p.id
WHERE identidad.puede_acceder('inventario',p.id,'leer');

CREATE VIEW comercial.v_resumen_pedidos WITH(security_invoker=true) AS
SELECT p.id,p.numero,p.cliente_id,p.estado,p.moneda,p.created_at,
 count(d.id) AS lineas,coalesce(sum(d.cantidad),0) AS unidades,
 coalesce(sum(d.subtotal),0) AS subtotal,coalesce(sum(d.impuesto_importe),0) AS impuestos,
 coalesce(sum(d.total),0) AS total
FROM comercial.pedido p LEFT JOIN comercial.detalle_pedido d ON d.pedido_id=p.id GROUP BY p.id;

CREATE VIEW comercial.v_cotizaciones_vigentes WITH(security_invoker=true) AS
SELECT c.id AS cotizacion_id,c.numero,v.id AS version_id,v.numero_version,v.moneda,v.vigente_hasta,
 coalesce(sum(d.total),0) AS total
FROM comercial.cotizacion c JOIN comercial.version_cotizacion v ON v.cotizacion_id=c.id
LEFT JOIN comercial.detalle_cotizacion d ON d.version_cotizacion_id=v.id
WHERE c.estado='abierta' AND v.estado='enviada' AND v.vigente_hasta>statement_timestamp()
GROUP BY c.id,v.id;

CREATE VIEW comercial.v_facturas_cliente WITH(security_invoker=true) AS
SELECT f.id,f.numero,f.estado,f.moneda,f.receptor_nombre,f.emitida_en,f.pedido_id,f.orden_servicio_id,f.proyecto_id,
 coalesce(sum(d.subtotal),0) AS subtotal,coalesce(sum(d.impuesto_importe),0) AS impuestos,
 coalesce(sum(d.total),0) AS total
FROM comercial.factura f LEFT JOIN comercial.detalle_factura d ON d.factura_id=f.id GROUP BY f.id;

CREATE VIEW comercial.v_historial_cliente WITH(security_invoker=true) AS
SELECT 'pedido'::text AS proceso,p.id,p.numero::text AS codigo,p.estado,p.created_at AS fecha FROM comercial.pedido p
UNION ALL SELECT 'cotizacion',c.id,c.numero::text,c.estado,c.created_at FROM comercial.cotizacion c
UNION ALL SELECT 'solicitud_cotizacion',s.id,s.codigo,s.estado,s.created_at FROM comercial.solicitud_cotizacion s
UNION ALL SELECT 'solicitud_servicio',s.id,s.codigo,s.estado,s.created_at FROM servicios.solicitud_servicio s
UNION ALL SELECT 'orden_servicio',o.id,o.codigo,o.estado,o.created_at FROM servicios.orden_servicio o
UNION ALL SELECT 'solicitud_desarrollo',s.id,s.codigo,s.estado,s.created_at FROM proyectos.solicitud_desarrollo s
UNION ALL SELECT 'proyecto',p.id,p.codigo,p.estado,p.created_at FROM proyectos.proyecto p
UNION ALL SELECT 'factura',f.id,f.numero::text,f.estado,f.created_at FROM comercial.factura f;

CREATE VIEW servicios.v_calificaciones WITH(security_invoker=true) AS
SELECT o.id AS orden_servicio_id,s.servicio_ofrecido_id,c.puntuacion,c.comentario,c.created_at
FROM servicios.calificacion_servicio c JOIN servicios.orden_servicio o ON o.id=c.orden_servicio_id
JOIN servicios.solicitud_servicio s ON s.id=o.solicitud_servicio_id;

CREATE VIEW comercial.v_carritos_propios WITH(security_invoker=true) AS
SELECT id,cliente_id,estado,created_at,updated_at FROM comercial.carrito;

GRANT SELECT ON inventario.v_productos_disponibles,inventario.productos,inventario.v_inventario_actual,
 comercial.v_resumen_pedidos,comercial.v_cotizaciones_vigentes,comercial.v_facturas_cliente,
 comercial.v_historial_cliente,comercial.v_carritos_propios,servicios.v_calificaciones,
 servicios.v_servicios_publicados,servicios.v_servicios_activos,
 proyectos.v_avance_etapa,proyectos.v_avance_proyecto,
 comunicacion.v_mensajes_visibles,comunicacion.v_notificaciones_propias TO st_app,st_lectura;
CREATE FUNCTION servicios.horarios_disponibles()
RETURNS TABLE(disponibilidad_id bigint,tecnico_id bigint,inicio timestamptz,fin timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
SELECT d.id AS disponibilidad_id,d.empleado_id AS tecnico_id,lower(libre) AS inicio,upper(libre) AS fin
FROM servicios.disponibilidad_tecnico d
CROSS JOIN LATERAL (
 SELECT unnest(tstzmultirange(tstzrange(greatest(d.inicio,statement_timestamp()),greatest(d.fin,statement_timestamp()),'[)')) -
 coalesce(range_agg(tstzrange(c.inicio,c.fin,'[)')),'{}'::tstzmultirange)) AS libre
 FROM servicios.cita_servicio c WHERE c.tecnico_id=d.empleado_id AND c.estado='confirmada'
 AND tstzrange(c.inicio,c.fin,'[)') && tstzrange(d.inicio,d.fin,'[)')
) bloques
WHERE d.habilitada AND d.fin>statement_timestamp() AND identidad.empleado_habilitado(d.empleado_id,'orden_servicio')
$$;
CREATE VIEW servicios.v_horarios_disponibles WITH(security_barrier=true) AS SELECT * FROM servicios.horarios_disponibles();
GRANT EXECUTE ON FUNCTION servicios.horarios_disponibles() TO st_app,st_lectura;
GRANT SELECT ON servicios.v_horarios_disponibles TO st_app,st_lectura;
GRANT EXECUTE ON PROCEDURE comercial.vincular_comprobante(bigint,bigint,text,text,bigint) TO st_app;
CREATE FUNCTION comercial.consultar_carrito(p_id bigint,p_token text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE resultado jsonb;
BEGIN
 PERFORM comercial.exigir_carrito(p_id,p_token);
 SELECT jsonb_build_object('id',c.id,'estado',c.estado,'lineas',coalesce((
 SELECT jsonb_agg(jsonb_build_object('producto_id',d.producto_id,'cantidad',d.cantidad,'nombre',p.nombre,'precio_actual',p.precio_vigente,'moneda',p.moneda) ORDER BY d.producto_id)
 FROM comercial.detalle_carrito d JOIN inventario.producto p ON p.id=d.producto_id WHERE d.carrito_id=c.id),'[]'::jsonb)) INTO resultado
 FROM comercial.carrito c WHERE c.id=p_id;
 RETURN resultado;
END $$;
GRANT EXECUTE ON FUNCTION comercial.consultar_carrito(bigint,text) TO st_app,st_lectura;
COMMIT;
