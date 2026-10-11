-- Systemic Tech & Support — migración para Supabase generada por herramientas/generar_supabase.py
-- Origen: módulos locales verificados en PostgreSQL 18.3 y 17.6. No editar a mano: regenerar.
-- Compatible con Supabase CLI (supabase db push / db reset) y con el SQL Editor (pegar completo).
-- 6/6. Datos base de producción: roles de negocio, permisos y concesiones rol-permiso.
-- Extraídos literalmente de 70_datos_demo.sql (primer bloque). No contiene personas ni datos ficticios.
-- Idempotente: si los roles ya existen no hace nada.
DO $datos_base$
DECLARE v_recurso_permiso record;
BEGIN
 IF EXISTS (SELECT 1 FROM identidad.rol WHERE codigo IN ('cliente','administrador','tecnico','desarrollador','administrativo')) THEN
   RAISE NOTICE 'Catálogo de roles y permisos ya presente; no se modifica';
   RETURN;
 END IF;
 PERFORM set_config('app.motivo','Catálogo base de roles y permisos Systemic Tech',true);
 INSERT INTO identidad.rol(codigo,nombre,descripcion) VALUES
 ('cliente','Cliente','Consulta y opera sus propios procesos; autorización por titularidad'),
 ('administrador','Administrador','Administración funcional de la aplicación'),
 ('tecnico','Técnico','Gestiona órdenes y agenda de servicios'),
 ('desarrollador','Desarrollador','Gestiona proyectos, etapas y avances'),
 ('administrativo','Personal administrativo','Atiende cotizaciones, pedidos y facturación');
 FOR v_recurso_permiso IN SELECT unnest(ARRAY['persona','usuario','cliente','empleado','rol','permiso','producto','categoria','inventario','carrito','pedido','solicitud_cotizacion','cotizacion','version_cotizacion','factura','equipo_cliente','servicio_ofrecido','solicitud_servicio','orden_servicio','solicitud_desarrollo','proyecto','conversacion','archivo','notificacion','acceso_invitado','auditoria']) AS recurso LOOP
   INSERT INTO identidad.permiso(codigo,recurso,accion,descripcion) VALUES
   (v_recurso_permiso.recurso||'.leer',v_recurso_permiso.recurso,'leer','Consultar '||v_recurso_permiso.recurso),
   (v_recurso_permiso.recurso||'.gestionar',v_recurso_permiso.recurso,'gestionar','Administrar '||v_recurso_permiso.recurso);
 END LOOP;
 INSERT INTO identidad.permiso(codigo,recurso,accion,descripcion) VALUES
 ('pedido.editar','pedido','editar','Confirmar pedido propio'),
 ('solicitud_servicio.editar','solicitud_servicio','editar','Gestionar solicitud propia según estado'),
 ('solicitud_desarrollo.editar','solicitud_desarrollo','editar','Gestionar solicitud propia según estado'),
 ('solicitud_cotizacion.editar','solicitud_cotizacion','editar','Gestionar solicitud propia según estado'),
 ('cotizacion.responder','cotizacion','responder','Aceptar o rechazar versión concedida'),
 ('orden_servicio.calificar','orden_servicio','calificar','Calificar servicio propio finalizado');
 INSERT INTO identidad.rol_permiso(rol_id,permiso_id,actor_sistema)
 SELECT r.id,p.id,'demo' FROM identidad.rol r CROSS JOIN identidad.permiso p WHERE r.codigo='administrador';
 INSERT INTO identidad.rol_permiso(rol_id,permiso_id,actor_sistema)
 SELECT r.id,p.id,'demo' FROM identidad.rol r CROSS JOIN identidad.permiso p WHERE
 (r.codigo='tecnico' AND p.accion='gestionar' AND p.recurso IN ('orden_servicio','solicitud_servicio','equipo_cliente','conversacion')) OR
 (r.codigo='desarrollador' AND p.accion='gestionar' AND p.recurso IN ('proyecto','solicitud_desarrollo','conversacion')) OR
 (r.codigo='administrativo' AND p.accion='gestionar' AND p.recurso IN ('cliente','cotizacion','solicitud_cotizacion','pedido','factura'));
END
$datos_base$;
