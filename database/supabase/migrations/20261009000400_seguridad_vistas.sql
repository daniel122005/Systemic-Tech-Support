-- Systemic Tech & Support — migración para Supabase generada por herramientas/generar_supabase.py
-- Origen: módulos locales verificados en PostgreSQL 18.3 y 17.6. No editar a mano: regenerar.
-- Compatible con Supabase CLI (supabase db push / db reset) y con el SQL Editor (pegar completo).
-- 4/6. Privilegios, RLS (62 políticas) y vistas (60 + 65).
-- A7: se omiten las sentencias sobre la base de datos y el esquema public.
DO $precondiciones$
BEGIN
  IF current_setting('server_version_num')::integer < 170000 THEN
    RAISE EXCEPTION 'Systemic Tech requiere PostgreSQL 17 o posterior (verificado en 17.6 y 18.3)';
  END IF;
  IF current_database() <> 'postgres' THEN
    RAISE EXCEPTION 'En Supabase la base de datos debe ser postgres; conectado a %', current_database();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'st_owner') THEN
    RAISE EXCEPTION 'Aplique antes la migración de roles (..._roles_systemic.sql)';
  END IF;
END
$precondiciones$;

SET ROLE st_owner;
SET search_path = pg_catalog, pg_temp;

-- MÓDULO 60_seguridad
-- Trusted backend contexts only; no browser receives these SQL credentials.
CREATE FUNCTION identidad.fila_visible(p_tabla text,f jsonb) RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF identidad.es_dba() THEN RETURN true; END IF;
 CASE p_tabla
 WHEN 'identidad.acceso_invitado' THEN RETURN coalesce((false),false);
 WHEN 'identidad.acceso_invitado_permiso' THEN RETURN coalesce((false),false);
 WHEN 'identidad.cliente' THEN RETURN coalesce((identidad.puede_acceder('cliente',(f->>'id')::bigint,'leer')),false);
 WHEN 'identidad.credencial' THEN RETURN coalesce((false),false);
 WHEN 'identidad.empleado' THEN RETURN coalesce((identidad.puede_acceder('empleado',(f->>'id')::bigint,'leer')),false);
 WHEN 'identidad.permiso' THEN RETURN coalesce((identidad.puede_acceder('rol',NULL,'gestionar')),false);
 WHEN 'identidad.persona' THEN RETURN coalesce((identidad.puede_acceder('persona',(f->>'id')::bigint,'leer')),false);
 WHEN 'identidad.recuperacion_acceso' THEN RETURN coalesce((false),false);
 WHEN 'identidad.rol' THEN RETURN coalesce((identidad.puede_acceder('rol',NULL,'gestionar')),false);
 WHEN 'identidad.rol_permiso' THEN RETURN coalesce((identidad.puede_acceder('rol',NULL,'gestionar')),false);
 WHEN 'identidad.sesion' THEN RETURN coalesce((false),false);
 WHEN 'identidad.usuario' THEN RETURN coalesce((identidad.puede_acceder('usuario',(f->>'id')::bigint,'leer')),false);
 WHEN 'identidad.usuario_rol' THEN RETURN coalesce((identidad.puede_acceder('usuario',(f->>'usuario_id')::bigint,'leer')),false);
 WHEN 'inventario.categoria' THEN RETURN coalesce(((f->>'activa')::boolean OR identidad.puede_acceder('categoria',(f->>'id')::bigint,'leer')),false);
 WHEN 'inventario.inventario' THEN RETURN coalesce((identidad.puede_acceder('inventario',(f->>'producto_id')::bigint,'leer')),false);
 WHEN 'inventario.movimiento_inventario' THEN RETURN coalesce((identidad.puede_acceder('inventario',(f->>'producto_id')::bigint,'leer')),false);
 WHEN 'inventario.producto' THEN RETURN coalesce((((f->>'activo')::boolean AND (f->>'publicado')::boolean) OR identidad.puede_acceder('producto',(f->>'id')::bigint,'leer')),false);
 WHEN 'inventario.producto_imagen' THEN RETURN coalesce((EXISTS(SELECT 1 FROM inventario.producto p WHERE p.id=(f->>'producto_id')::bigint AND p.activo AND p.publicado) OR identidad.puede_acceder('producto',(f->>'producto_id')::bigint,'leer')),false);
 WHEN 'inventario.reserva_inventario' THEN RETURN coalesce((identidad.puede_acceder('detalle_pedido',(f->>'detalle_pedido_id')::bigint,'leer')),false);
 WHEN 'comercial.carrito' THEN RETURN coalesce((identidad.puede_acceder('carrito',(f->>'id')::bigint,'leer')),false);
 WHEN 'comercial.comprobante_factura' THEN RETURN coalesce((identidad.puede_acceder('factura',(f->>'factura_id')::bigint,'leer')),false);
 WHEN 'comercial.cotizacion' THEN RETURN coalesce((identidad.puede_acceder('cotizacion',(f->>'id')::bigint,'leer')),false);
 WHEN 'comercial.detalle_carrito' THEN RETURN coalesce((identidad.puede_acceder('carrito',(f->>'carrito_id')::bigint,'leer')),false);
 WHEN 'comercial.detalle_cotizacion' THEN RETURN coalesce((identidad.puede_acceder('version_cotizacion',(f->>'version_cotizacion_id')::bigint,'leer')),false);
 WHEN 'comercial.detalle_factura' THEN RETURN coalesce((identidad.puede_acceder('factura',(f->>'factura_id')::bigint,'leer')),false);
 WHEN 'comercial.detalle_pedido' THEN RETURN coalesce((identidad.puede_acceder('pedido',(f->>'pedido_id')::bigint,'leer')),false);
 WHEN 'comercial.factura' THEN RETURN coalesce((identidad.puede_acceder('factura',(f->>'id')::bigint,'leer')),false);
 WHEN 'comercial.historial_cotizacion' THEN RETURN coalesce((identidad.puede_acceder('cotizacion',(f->>'cotizacion_id')::bigint,'leer')),false);
 WHEN 'comercial.historial_factura' THEN RETURN coalesce((identidad.puede_acceder('factura',(f->>'factura_id')::bigint,'leer')),false);
 WHEN 'comercial.historial_pedido' THEN RETURN coalesce((identidad.puede_acceder('pedido',(f->>'pedido_id')::bigint,'leer')),false);
 WHEN 'comercial.historial_solicitud_cotizacion' THEN RETURN coalesce((identidad.puede_acceder('solicitud_cotizacion',(f->>'solicitud_cotizacion_id')::bigint,'leer')),false);
 WHEN 'comercial.pedido' THEN RETURN coalesce((identidad.puede_acceder('pedido',(f->>'id')::bigint,'leer')),false);
 WHEN 'comercial.solicitud_cotizacion' THEN RETURN coalesce((identidad.puede_acceder('solicitud_cotizacion',(f->>'id')::bigint,'leer')),false);
 WHEN 'comercial.version_cotizacion' THEN RETURN coalesce((identidad.puede_acceder('version_cotizacion',(f->>'id')::bigint,'leer')),false);
 WHEN 'servicios.asignacion_servicio' THEN RETURN coalesce((identidad.puede_acceder('orden_servicio',(f->>'orden_servicio_id')::bigint,'leer')),false);
 WHEN 'servicios.calificacion_servicio' THEN RETURN coalesce((identidad.puede_acceder('orden_servicio',(f->>'orden_servicio_id')::bigint,'leer')),false);
 WHEN 'servicios.cita_servicio' THEN RETURN coalesce((identidad.puede_acceder('solicitud_servicio',(f->>'solicitud_servicio_id')::bigint,'leer')),false);
 WHEN 'servicios.disponibilidad_tecnico' THEN RETURN coalesce((identidad.puede_acceder('empleado',(f->>'empleado_id')::bigint,'leer') OR identidad.puede_acceder('orden_servicio',NULL,'gestionar')),false);
 WHEN 'servicios.equipo_cliente' THEN RETURN coalesce((identidad.puede_acceder('cliente',(f->>'cliente_id')::bigint,'leer')),false);
 WHEN 'servicios.historial_servicio' THEN RETURN coalesce((identidad.puede_acceder('orden_servicio',(f->>'orden_servicio_id')::bigint,'leer')),false);
 WHEN 'servicios.historial_solicitud_servicio' THEN RETURN coalesce((identidad.puede_acceder('solicitud_servicio',(f->>'solicitud_servicio_id')::bigint,'leer')),false);
 WHEN 'servicios.mantenimiento' THEN RETURN coalesce((identidad.puede_acceder('orden_servicio',(f->>'orden_servicio_id')::bigint,'leer')),false);
 WHEN 'servicios.orden_servicio' THEN RETURN coalesce((identidad.puede_acceder('orden_servicio',(f->>'id')::bigint,'leer')),false);
 WHEN 'servicios.reparacion' THEN RETURN coalesce((identidad.puede_acceder('orden_servicio',(f->>'orden_servicio_id')::bigint,'leer')),false);
 WHEN 'servicios.servicio_ofrecido' THEN RETURN coalesce(((f->>'publicado')::boolean OR identidad.puede_acceder('servicio_ofrecido',(f->>'id')::bigint,'leer') OR EXISTS(SELECT 1 FROM servicios.solicitud_servicio s WHERE s.servicio_ofrecido_id=(f->>'id')::bigint AND identidad.puede_acceder('solicitud_servicio',s.id,'leer'))),false);
 WHEN 'servicios.solicitud_servicio' THEN RETURN coalesce((identidad.puede_acceder('solicitud_servicio',(f->>'id')::bigint,'leer')),false);
 WHEN 'proyectos.avance_proyecto' THEN RETURN coalesce((identidad.puede_acceder('etapa_proyecto',(f->>'etapa_proyecto_id')::bigint,'leer')),false);
 WHEN 'proyectos.etapa_proyecto' THEN RETURN coalesce((identidad.puede_acceder('proyecto',(f->>'proyecto_id')::bigint,'leer')),false);
 WHEN 'proyectos.historial_proyecto' THEN RETURN coalesce((identidad.puede_acceder('proyecto',(f->>'proyecto_id')::bigint,'leer')),false);
 WHEN 'proyectos.historial_solicitud_desarrollo' THEN RETURN coalesce((identidad.puede_acceder('solicitud_desarrollo',(f->>'solicitud_desarrollo_id')::bigint,'leer')),false);
 WHEN 'proyectos.miembro_proyecto' THEN RETURN coalesce((identidad.puede_acceder('proyecto',(f->>'proyecto_id')::bigint,'leer')),false);
 WHEN 'proyectos.proyecto' THEN RETURN coalesce((identidad.puede_acceder('proyecto',(f->>'id')::bigint,'leer')),false);
 WHEN 'proyectos.solicitud_desarrollo' THEN RETURN coalesce((identidad.puede_acceder('solicitud_desarrollo',(f->>'id')::bigint,'leer')),false);
 WHEN 'comunicacion.adjunto' THEN RETURN EXISTS(SELECT 1 FROM comunicacion.contexto_de_fila(f) c WHERE CASE WHEN c.recurso='mensaje' THEN EXISTS(SELECT 1 FROM comunicacion.mensaje m JOIN comunicacion.participante_conversacion p ON p.id=m.autor_participante_id WHERE m.id=c.registro_id AND NOT m.retirado AND identidad.puede_acceder('conversacion',p.conversacion_id,CASE WHEN f->>'visibilidad'='interno' THEN 'gestionar' ELSE 'leer' END)) ELSE identidad.puede_acceder(c.recurso,c.registro_id,CASE WHEN f->>'visibilidad'='interno' THEN 'gestionar' ELSE 'leer' END) END);
 WHEN 'comunicacion.archivo' THEN RETURN coalesce((comunicacion.puede_leer_archivo((f->>'id')::bigint) OR identidad.puede_acceder('archivo',(f->>'id')::bigint,'gestionar')),false);
 WHEN 'comunicacion.conversacion' THEN RETURN coalesce((identidad.puede_acceder('conversacion',(f->>'id')::bigint,'leer')),false);
 WHEN 'comunicacion.entrega_notificacion' THEN RETURN coalesce((identidad.puede_acceder('notificacion',NULL,'gestionar')),false);
 WHEN 'comunicacion.lectura_mensaje' THEN RETURN coalesce((EXISTS(SELECT 1 FROM comunicacion.participante_conversacion p WHERE p.id=(f->>'participante_id')::bigint AND identidad.puede_acceder('conversacion',p.conversacion_id,'leer'))),false);
 WHEN 'comunicacion.mensaje' THEN RETURN NOT (f->>'retirado')::boolean AND EXISTS(SELECT 1 FROM comunicacion.participante_conversacion p WHERE p.id=(f->>'autor_participante_id')::bigint AND identidad.puede_acceder('conversacion',p.conversacion_id,'leer'));
 WHEN 'comunicacion.notificacion' THEN RETURN coalesce((EXISTS(SELECT 1 FROM identidad.usuario u WHERE u.id=(f->>'destinatario_usuario_id')::bigint AND u.persona_id=identidad.actor_persona_actual()) OR identidad.puede_acceder('notificacion',(f->>'id')::bigint,'gestionar')),false);
 WHEN 'comunicacion.participante_conversacion' THEN RETURN coalesce((identidad.puede_acceder('conversacion',(f->>'conversacion_id')::bigint,'leer')),false);
 WHEN 'auditoria.evento_auditoria' THEN RETURN coalesce((identidad.puede_acceder('auditoria',NULL,'gestionar')),false);
 ELSE RETURN false;
 END CASE;
END $$;
REVOKE ALL ON SCHEMA identidad FROM PUBLIC;
GRANT USAGE ON SCHEMA identidad TO st_app,st_lectura,st_worker;
REVOKE ALL ON ALL TABLES IN SCHEMA identidad FROM PUBLIC,st_app,st_lectura,st_worker;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA identidad FROM PUBLIC,st_app,st_lectura,st_worker;
REVOKE ALL ON ALL ROUTINES IN SCHEMA identidad FROM PUBLIC,st_app,st_lectura,st_worker;
ALTER DEFAULT PRIVILEGES FOR ROLE st_owner IN SCHEMA identidad REVOKE EXECUTE ON ROUTINES FROM PUBLIC;
REVOKE ALL ON SCHEMA inventario FROM PUBLIC;
GRANT USAGE ON SCHEMA inventario TO st_app,st_lectura,st_worker;
REVOKE ALL ON ALL TABLES IN SCHEMA inventario FROM PUBLIC,st_app,st_lectura,st_worker;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA inventario FROM PUBLIC,st_app,st_lectura,st_worker;
REVOKE ALL ON ALL ROUTINES IN SCHEMA inventario FROM PUBLIC,st_app,st_lectura,st_worker;
ALTER DEFAULT PRIVILEGES FOR ROLE st_owner IN SCHEMA inventario REVOKE EXECUTE ON ROUTINES FROM PUBLIC;
REVOKE ALL ON SCHEMA comercial FROM PUBLIC;
GRANT USAGE ON SCHEMA comercial TO st_app,st_lectura,st_worker;
REVOKE ALL ON ALL TABLES IN SCHEMA comercial FROM PUBLIC,st_app,st_lectura,st_worker;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA comercial FROM PUBLIC,st_app,st_lectura,st_worker;
REVOKE ALL ON ALL ROUTINES IN SCHEMA comercial FROM PUBLIC,st_app,st_lectura,st_worker;
ALTER DEFAULT PRIVILEGES FOR ROLE st_owner IN SCHEMA comercial REVOKE EXECUTE ON ROUTINES FROM PUBLIC;
REVOKE ALL ON SCHEMA servicios FROM PUBLIC;
GRANT USAGE ON SCHEMA servicios TO st_app,st_lectura,st_worker;
REVOKE ALL ON ALL TABLES IN SCHEMA servicios FROM PUBLIC,st_app,st_lectura,st_worker;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA servicios FROM PUBLIC,st_app,st_lectura,st_worker;
REVOKE ALL ON ALL ROUTINES IN SCHEMA servicios FROM PUBLIC,st_app,st_lectura,st_worker;
ALTER DEFAULT PRIVILEGES FOR ROLE st_owner IN SCHEMA servicios REVOKE EXECUTE ON ROUTINES FROM PUBLIC;
REVOKE ALL ON SCHEMA proyectos FROM PUBLIC;
GRANT USAGE ON SCHEMA proyectos TO st_app,st_lectura,st_worker;
REVOKE ALL ON ALL TABLES IN SCHEMA proyectos FROM PUBLIC,st_app,st_lectura,st_worker;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA proyectos FROM PUBLIC,st_app,st_lectura,st_worker;
REVOKE ALL ON ALL ROUTINES IN SCHEMA proyectos FROM PUBLIC,st_app,st_lectura,st_worker;
ALTER DEFAULT PRIVILEGES FOR ROLE st_owner IN SCHEMA proyectos REVOKE EXECUTE ON ROUTINES FROM PUBLIC;
REVOKE ALL ON SCHEMA comunicacion FROM PUBLIC;
GRANT USAGE ON SCHEMA comunicacion TO st_app,st_lectura,st_worker;
REVOKE ALL ON ALL TABLES IN SCHEMA comunicacion FROM PUBLIC,st_app,st_lectura,st_worker;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA comunicacion FROM PUBLIC,st_app,st_lectura,st_worker;
REVOKE ALL ON ALL ROUTINES IN SCHEMA comunicacion FROM PUBLIC,st_app,st_lectura,st_worker;
ALTER DEFAULT PRIVILEGES FOR ROLE st_owner IN SCHEMA comunicacion REVOKE EXECUTE ON ROUTINES FROM PUBLIC;
REVOKE ALL ON SCHEMA auditoria FROM PUBLIC;
GRANT USAGE ON SCHEMA auditoria TO st_app,st_lectura,st_worker;
REVOKE ALL ON ALL TABLES IN SCHEMA auditoria FROM PUBLIC,st_app,st_lectura,st_worker;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA auditoria FROM PUBLIC,st_app,st_lectura,st_worker;
REVOKE ALL ON ALL ROUTINES IN SCHEMA auditoria FROM PUBLIC,st_app,st_lectura,st_worker;
ALTER DEFAULT PRIVILEGES FOR ROLE st_owner IN SCHEMA auditoria REVOKE EXECUTE ON ROUTINES FROM PUBLIC;
ALTER TABLE identidad.acceso_invitado ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON identidad.acceso_invitado FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('identidad.acceso_invitado',to_jsonb(acceso_invitado)));
ALTER TABLE identidad.acceso_invitado_permiso ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON identidad.acceso_invitado_permiso FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('identidad.acceso_invitado_permiso',to_jsonb(acceso_invitado_permiso)));
ALTER TABLE identidad.cliente ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON identidad.cliente FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('identidad.cliente',to_jsonb(cliente)));
GRANT SELECT ON identidad.cliente TO st_app,st_lectura;
ALTER TABLE identidad.credencial ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON identidad.credencial FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('identidad.credencial',to_jsonb(credencial)));
ALTER TABLE identidad.empleado ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON identidad.empleado FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('identidad.empleado',to_jsonb(empleado)));
GRANT SELECT ON identidad.empleado TO st_app,st_lectura;
ALTER TABLE identidad.permiso ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON identidad.permiso FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('identidad.permiso',to_jsonb(permiso)));
GRANT SELECT ON identidad.permiso TO st_app,st_lectura;
ALTER TABLE identidad.persona ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON identidad.persona FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('identidad.persona',to_jsonb(persona)));
GRANT SELECT ON identidad.persona TO st_app,st_lectura;
ALTER TABLE identidad.recuperacion_acceso ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON identidad.recuperacion_acceso FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('identidad.recuperacion_acceso',to_jsonb(recuperacion_acceso)));
ALTER TABLE identidad.rol ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON identidad.rol FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('identidad.rol',to_jsonb(rol)));
GRANT SELECT ON identidad.rol TO st_app,st_lectura;
ALTER TABLE identidad.rol_permiso ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON identidad.rol_permiso FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('identidad.rol_permiso',to_jsonb(rol_permiso)));
GRANT SELECT ON identidad.rol_permiso TO st_app,st_lectura;
ALTER TABLE identidad.sesion ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON identidad.sesion FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('identidad.sesion',to_jsonb(sesion)));
ALTER TABLE identidad.usuario ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON identidad.usuario FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('identidad.usuario',to_jsonb(usuario)));
GRANT SELECT ON identidad.usuario TO st_app,st_lectura;
ALTER TABLE identidad.usuario_rol ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON identidad.usuario_rol FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('identidad.usuario_rol',to_jsonb(usuario_rol)));
GRANT SELECT ON identidad.usuario_rol TO st_app,st_lectura;
ALTER TABLE inventario.categoria ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON inventario.categoria FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('inventario.categoria',to_jsonb(categoria)));
GRANT SELECT ON inventario.categoria TO st_app,st_lectura;
ALTER TABLE inventario.inventario ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON inventario.inventario FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('inventario.inventario',to_jsonb(inventario)));
GRANT SELECT ON inventario.inventario TO st_app,st_lectura;
ALTER TABLE inventario.movimiento_inventario ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON inventario.movimiento_inventario FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('inventario.movimiento_inventario',to_jsonb(movimiento_inventario)));
GRANT SELECT ON inventario.movimiento_inventario TO st_app,st_lectura;
ALTER TABLE inventario.producto ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON inventario.producto FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('inventario.producto',to_jsonb(producto)));
GRANT SELECT ON inventario.producto TO st_app,st_lectura;
ALTER TABLE inventario.producto_imagen ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON inventario.producto_imagen FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('inventario.producto_imagen',to_jsonb(producto_imagen)));
GRANT SELECT ON inventario.producto_imagen TO st_app,st_lectura;
ALTER TABLE inventario.reserva_inventario ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON inventario.reserva_inventario FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('inventario.reserva_inventario',to_jsonb(reserva_inventario)));
GRANT SELECT ON inventario.reserva_inventario TO st_app,st_lectura;
ALTER TABLE comercial.carrito ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comercial.carrito FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comercial.carrito',to_jsonb(carrito)));
GRANT SELECT(id,cliente_id,estado,created_at,updated_at) ON comercial.carrito TO st_app,st_lectura;
ALTER TABLE comercial.comprobante_factura ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comercial.comprobante_factura FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comercial.comprobante_factura',to_jsonb(comprobante_factura)));
GRANT SELECT ON comercial.comprobante_factura TO st_app,st_lectura;
ALTER TABLE comercial.cotizacion ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comercial.cotizacion FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comercial.cotizacion',to_jsonb(cotizacion)));
GRANT SELECT ON comercial.cotizacion TO st_app,st_lectura;
ALTER TABLE comercial.detalle_carrito ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comercial.detalle_carrito FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comercial.detalle_carrito',to_jsonb(detalle_carrito)));
GRANT SELECT ON comercial.detalle_carrito TO st_app,st_lectura;
ALTER TABLE comercial.detalle_cotizacion ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comercial.detalle_cotizacion FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comercial.detalle_cotizacion',to_jsonb(detalle_cotizacion)));
GRANT SELECT ON comercial.detalle_cotizacion TO st_app,st_lectura;
ALTER TABLE comercial.detalle_factura ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comercial.detalle_factura FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comercial.detalle_factura',to_jsonb(detalle_factura)));
GRANT SELECT ON comercial.detalle_factura TO st_app,st_lectura;
ALTER TABLE comercial.detalle_pedido ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comercial.detalle_pedido FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comercial.detalle_pedido',to_jsonb(detalle_pedido)));
GRANT SELECT ON comercial.detalle_pedido TO st_app,st_lectura;
ALTER TABLE comercial.factura ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comercial.factura FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comercial.factura',to_jsonb(factura)));
GRANT SELECT ON comercial.factura TO st_app,st_lectura;
ALTER TABLE comercial.historial_cotizacion ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comercial.historial_cotizacion FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comercial.historial_cotizacion',to_jsonb(historial_cotizacion)));
GRANT SELECT ON comercial.historial_cotizacion TO st_app,st_lectura;
ALTER TABLE comercial.historial_factura ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comercial.historial_factura FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comercial.historial_factura',to_jsonb(historial_factura)));
GRANT SELECT ON comercial.historial_factura TO st_app,st_lectura;
ALTER TABLE comercial.historial_pedido ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comercial.historial_pedido FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comercial.historial_pedido',to_jsonb(historial_pedido)));
GRANT SELECT ON comercial.historial_pedido TO st_app,st_lectura;
ALTER TABLE comercial.historial_solicitud_cotizacion ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comercial.historial_solicitud_cotizacion FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comercial.historial_solicitud_cotizacion',to_jsonb(historial_solicitud_cotizacion)));
GRANT SELECT ON comercial.historial_solicitud_cotizacion TO st_app,st_lectura;
ALTER TABLE comercial.pedido ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comercial.pedido FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comercial.pedido',to_jsonb(pedido)));
GRANT SELECT ON comercial.pedido TO st_app,st_lectura;
ALTER TABLE comercial.solicitud_cotizacion ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comercial.solicitud_cotizacion FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comercial.solicitud_cotizacion',to_jsonb(solicitud_cotizacion)));
GRANT SELECT ON comercial.solicitud_cotizacion TO st_app,st_lectura;
ALTER TABLE comercial.version_cotizacion ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comercial.version_cotizacion FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comercial.version_cotizacion',to_jsonb(version_cotizacion)));
GRANT SELECT ON comercial.version_cotizacion TO st_app,st_lectura;
ALTER TABLE servicios.asignacion_servicio ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON servicios.asignacion_servicio FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('servicios.asignacion_servicio',to_jsonb(asignacion_servicio)));
GRANT SELECT ON servicios.asignacion_servicio TO st_app,st_lectura;
ALTER TABLE servicios.calificacion_servicio ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON servicios.calificacion_servicio FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('servicios.calificacion_servicio',to_jsonb(calificacion_servicio)));
GRANT SELECT ON servicios.calificacion_servicio TO st_app,st_lectura;
ALTER TABLE servicios.cita_servicio ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON servicios.cita_servicio FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('servicios.cita_servicio',to_jsonb(cita_servicio)));
GRANT SELECT ON servicios.cita_servicio TO st_app,st_lectura;
ALTER TABLE servicios.disponibilidad_tecnico ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON servicios.disponibilidad_tecnico FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('servicios.disponibilidad_tecnico',to_jsonb(disponibilidad_tecnico)));
GRANT SELECT ON servicios.disponibilidad_tecnico TO st_app,st_lectura;
ALTER TABLE servicios.equipo_cliente ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON servicios.equipo_cliente FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('servicios.equipo_cliente',to_jsonb(equipo_cliente)));
GRANT SELECT ON servicios.equipo_cliente TO st_app,st_lectura;
ALTER TABLE servicios.historial_servicio ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON servicios.historial_servicio FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('servicios.historial_servicio',to_jsonb(historial_servicio)));
GRANT SELECT ON servicios.historial_servicio TO st_app,st_lectura;
ALTER TABLE servicios.historial_solicitud_servicio ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON servicios.historial_solicitud_servicio FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('servicios.historial_solicitud_servicio',to_jsonb(historial_solicitud_servicio)));
GRANT SELECT ON servicios.historial_solicitud_servicio TO st_app,st_lectura;
ALTER TABLE servicios.mantenimiento ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON servicios.mantenimiento FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('servicios.mantenimiento',to_jsonb(mantenimiento)));
GRANT SELECT ON servicios.mantenimiento TO st_app,st_lectura;
ALTER TABLE servicios.orden_servicio ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON servicios.orden_servicio FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('servicios.orden_servicio',to_jsonb(orden_servicio)));
GRANT SELECT ON servicios.orden_servicio TO st_app,st_lectura;
ALTER TABLE servicios.reparacion ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON servicios.reparacion FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('servicios.reparacion',to_jsonb(reparacion)));
GRANT SELECT ON servicios.reparacion TO st_app,st_lectura;
ALTER TABLE servicios.servicio_ofrecido ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON servicios.servicio_ofrecido FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('servicios.servicio_ofrecido',to_jsonb(servicio_ofrecido)));
GRANT SELECT ON servicios.servicio_ofrecido TO st_app,st_lectura;
ALTER TABLE servicios.solicitud_servicio ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON servicios.solicitud_servicio FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('servicios.solicitud_servicio',to_jsonb(solicitud_servicio)));
GRANT SELECT ON servicios.solicitud_servicio TO st_app,st_lectura;
ALTER TABLE proyectos.avance_proyecto ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON proyectos.avance_proyecto FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('proyectos.avance_proyecto',to_jsonb(avance_proyecto)));
GRANT SELECT ON proyectos.avance_proyecto TO st_app,st_lectura;
ALTER TABLE proyectos.etapa_proyecto ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON proyectos.etapa_proyecto FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('proyectos.etapa_proyecto',to_jsonb(etapa_proyecto)));
GRANT SELECT ON proyectos.etapa_proyecto TO st_app,st_lectura;
ALTER TABLE proyectos.historial_proyecto ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON proyectos.historial_proyecto FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('proyectos.historial_proyecto',to_jsonb(historial_proyecto)));
GRANT SELECT ON proyectos.historial_proyecto TO st_app,st_lectura;
ALTER TABLE proyectos.historial_solicitud_desarrollo ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON proyectos.historial_solicitud_desarrollo FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('proyectos.historial_solicitud_desarrollo',to_jsonb(historial_solicitud_desarrollo)));
GRANT SELECT ON proyectos.historial_solicitud_desarrollo TO st_app,st_lectura;
ALTER TABLE proyectos.miembro_proyecto ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON proyectos.miembro_proyecto FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('proyectos.miembro_proyecto',to_jsonb(miembro_proyecto)));
GRANT SELECT ON proyectos.miembro_proyecto TO st_app,st_lectura;
ALTER TABLE proyectos.proyecto ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON proyectos.proyecto FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('proyectos.proyecto',to_jsonb(proyecto)));
GRANT SELECT ON proyectos.proyecto TO st_app,st_lectura;
ALTER TABLE proyectos.solicitud_desarrollo ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON proyectos.solicitud_desarrollo FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('proyectos.solicitud_desarrollo',to_jsonb(solicitud_desarrollo)));
GRANT SELECT ON proyectos.solicitud_desarrollo TO st_app,st_lectura;
ALTER TABLE comunicacion.adjunto ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comunicacion.adjunto FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comunicacion.adjunto',to_jsonb(adjunto)));
GRANT SELECT ON comunicacion.adjunto TO st_app,st_lectura;
ALTER TABLE comunicacion.archivo ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comunicacion.archivo FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comunicacion.archivo',to_jsonb(archivo)));
GRANT SELECT ON comunicacion.archivo TO st_app,st_lectura;
GRANT SELECT ON comunicacion.archivo TO st_worker;
ALTER TABLE comunicacion.conversacion ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comunicacion.conversacion FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comunicacion.conversacion',to_jsonb(conversacion)));
GRANT SELECT ON comunicacion.conversacion TO st_app,st_lectura;
ALTER TABLE comunicacion.entrega_notificacion ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comunicacion.entrega_notificacion FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comunicacion.entrega_notificacion',to_jsonb(entrega_notificacion)));
GRANT SELECT ON comunicacion.entrega_notificacion TO st_app,st_lectura;
GRANT SELECT ON comunicacion.entrega_notificacion TO st_worker;
ALTER TABLE comunicacion.lectura_mensaje ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comunicacion.lectura_mensaje FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comunicacion.lectura_mensaje',to_jsonb(lectura_mensaje)));
GRANT SELECT ON comunicacion.lectura_mensaje TO st_app,st_lectura;
ALTER TABLE comunicacion.mensaje ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comunicacion.mensaje FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comunicacion.mensaje',to_jsonb(mensaje)));
GRANT SELECT ON comunicacion.mensaje TO st_app,st_lectura;
ALTER TABLE comunicacion.notificacion ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comunicacion.notificacion FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comunicacion.notificacion',to_jsonb(notificacion)));
GRANT SELECT ON comunicacion.notificacion TO st_app,st_lectura;
GRANT SELECT ON comunicacion.notificacion TO st_worker;
ALTER TABLE comunicacion.participante_conversacion ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON comunicacion.participante_conversacion FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('comunicacion.participante_conversacion',to_jsonb(participante_conversacion)));
GRANT SELECT ON comunicacion.participante_conversacion TO st_app,st_lectura;
ALTER TABLE auditoria.evento_auditoria ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura_autorizada ON auditoria.evento_auditoria FOR SELECT TO st_app,st_lectura,st_worker USING (identidad.fila_visible('auditoria.evento_auditoria',to_jsonb(evento_auditoria)));
GRANT SELECT ON auditoria.evento_auditoria TO st_app,st_lectura;
DO $$ DECLARE r record; BEGIN FOR r IN SELECT p.oid::regprocedure AS firma FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.prokind='p' AND n.nspname||'.'||p.proname=ANY(ARRAY['comercial.abandonar_carrito','comercial.anular_cotizacion','comercial.anular_factura','comercial.cambiar_estado_pedido','comercial.cambiar_estado_solicitud_cotizacion','comercial.confirmar_pedido','comercial.convertir_carrito','comercial.crear_carrito','comercial.crear_cotizacion','comercial.crear_factura','comercial.crear_pedido','comercial.editar_carrito','comercial.editar_version_cotizacion','comercial.emitir_factura','comercial.enviar_cotizacion','comercial.guardar_detalle_cotizacion','comercial.guardar_detalle_factura','comercial.guardar_detalle_pedido','comercial.quitar_detalle_cotizacion','comercial.quitar_detalle_factura','comercial.quitar_detalle_pedido','comercial.responder_cotizacion','comercial.revisar_cotizacion','comercial.solicitar_cotizacion','comunicacion.adjuntar_archivo','comunicacion.cerrar_conversacion','comunicacion.crear_conversacion','comunicacion.editar_mensaje','comunicacion.enviar_mensaje','comunicacion.gestionar_participante','comunicacion.marcar_mensaje_leido','comunicacion.marcar_notificacion_leida','comunicacion.registrar_archivo','comunicacion.retirar_mensaje','identidad.actualizar_perfil','identidad.administrar_registro','identidad.asignar_rol','identidad.cerrar_sesion','identidad.configurar_permiso_rol','identidad.procesar_vencimientos','identidad.registrar_cliente_invitado','identidad.registrar_sesion','identidad.registrar_usuario','identidad.revocar_rol','inventario.guardar_producto','inventario.registrar_movimiento','proyectos.aprobar_solicitud','proyectos.asignar_miembro','proyectos.cambiar_estado_proyecto','proyectos.cambiar_estado_solicitud','proyectos.definir_etapa','proyectos.registrar_avance','proyectos.retirar_miembro','proyectos.revisar_alcance','proyectos.solicitar_desarrollo','servicios.aceptar_solicitud','servicios.asignar_tecnico','servicios.calificar_servicio','servicios.cambiar_estado_cita','servicios.cambiar_estado_orden','servicios.cambiar_estado_solicitud','servicios.cerrar_servicio','servicios.editar_disponibilidad','servicios.programar_cita','servicios.registrar_disponibilidad','servicios.registrar_equipo','servicios.registrar_informe_mantenimiento','servicios.registrar_informe_reparacion','servicios.reprogramar_cita','servicios.retirar_tecnico','servicios.solicitar_servicio']) LOOP EXECUTE format('GRANT EXECUTE ON PROCEDURE %s TO st_app',r.firma); END LOOP; END $$;
DO $$ DECLARE r record; BEGIN FOR r IN SELECT p.oid::regprocedure AS firma FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.prokind='p' AND n.nspname||'.'||p.proname=ANY(ARRAY['comunicacion.encolar_entrega','comunicacion.reclamar_entrega','comunicacion.registrar_notificacion','comunicacion.registrar_resultado_entrega','comunicacion.validar_archivo','identidad.confirmar_correo','identidad.consumir_recuperacion','identidad.emitir_acceso_invitado','identidad.preparar_recuperacion','identidad.revocar_acceso_invitado']) LOOP EXECUTE format('GRANT EXECUTE ON PROCEDURE %s TO st_worker',r.firma); END LOOP; END $$;
GRANT EXECUTE ON FUNCTION identidad.fila_visible(text,jsonb) TO st_app,st_lectura,st_worker;
GRANT EXECUTE ON FUNCTION identidad.puede_acceder(text,bigint,text) TO st_app,st_lectura,st_worker;
GRANT EXECUTE ON FUNCTION identidad.actor_persona_actual() TO st_app,st_lectura,st_worker;
GRANT EXECUTE ON FUNCTION identidad.es_dba() TO st_app,st_lectura,st_worker;
GRANT EXECUTE ON FUNCTION comunicacion.puede_leer_archivo(bigint) TO st_app,st_lectura,st_worker;
GRANT EXECUTE ON FUNCTION comunicacion.contar_mensajes_no_leidos(bigint) TO st_app,st_lectura,st_worker;
GRANT EXECUTE ON FUNCTION proyectos.obtener_avance(bigint) TO st_app,st_lectura,st_worker;
GRANT EXECUTE ON FUNCTION identidad.datos_autenticacion(text),identidad.estado_sesion(bigint,bytea) TO st_worker;

-- MÓDULO 65_vistas
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

RESET search_path;
RESET ROLE;
