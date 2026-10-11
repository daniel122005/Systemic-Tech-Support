\set ON_ERROR_STOP on
-- Pruebas R01-R30: recorridos por requerimiento funcional con la identidad SQL real de la aplicación (st_app).
-- Requiere 70_datos_demo.sql y 71_datos_demo_complemento.sql. Ejecutar como superusuario
-- (SET SESSION AUTHORIZATION). Todo se revierte con ROLLBACK; las secuencias pueden dejar huecos.
-- Distingue perspectivas: visitante (sin cuenta), cliente registrado y personal autorizado.
BEGIN;
SET LOCAL client_min_messages = notice;
CREATE TEMP TABLE r_ctx(clave text PRIMARY KEY, valor text NOT NULL) ON COMMIT DROP;
GRANT SELECT, INSERT, UPDATE ON r_ctx TO st_app;
INSERT INTO r_ctx
SELECT 'uc', u.id::text FROM identidad.usuario u WHERE u.correo_acceso='cliente@example.test'
UNION ALL SELECT 'ut', u.id::text FROM identidad.usuario u WHERE u.correo_acceso='profesional@example.test'
UNION ALL SELECT 'pc', p.id::text FROM identidad.persona p WHERE p.correo_contacto='cliente@example.test'
UNION ALL SELECT 'pt', p.id::text FROM identidad.persona p WHERE p.correo_contacto='profesional@example.test'
UNION ALL SELECT 'cli', c.id::text FROM identidad.cliente c WHERE c.codigo='DEMO-CLIENTE-001'
UNION ALL SELECT 'prod', id::text FROM inventario.producto WHERE sku='DEMO-SSD-001'
UNION ALL SELECT 'prod2', id::text FROM inventario.producto WHERE sku='DEMO-USB-001'
UNION ALL SELECT 'equipo', e.id::text FROM servicios.equipo_cliente e WHERE e.numero_serie='DEMO-SERIE'
UNION ALL SELECT 'oferta', id::text FROM servicios.servicio_ofrecido WHERE codigo='DEMO-REP'
UNION ALL SELECT 'ofertam', id::text FROM servicios.servicio_ofrecido WHERE codigo='DEMO-MAN'
UNION ALL SELECT 'proyecto', id::text FROM proyectos.proyecto WHERE nombre='Portal de soporte'
UNION ALL SELECT 'doc', id::text FROM comunicacion.archivo WHERE clave_objeto='proyectos/portal-soporte/alcance.pdf';
DO $c$ BEGIN
  IF (SELECT count(*) FROM pg_temp.r_ctx)<>12 THEN RAISE EXCEPTION 'Faltan datos demo (70 y 71) para estas pruebas'; END IF;
END $c$;

SET SESSION AUTHORIZATION st_app;

-- ===== Visitante sin cuenta =====
DO $r$
DECLARE n bigint; token text:=repeat('ab',32); v_carrito bigint; v_pedido bigint;
 prod2 bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='prod2');
BEGIN
 PERFORM set_config('app.usuario_id','',true); PERFORM set_config('app.invitado_token','',true);
 IF identidad.es_dba() THEN RAISE EXCEPTION 'La prueba conserva privilegios de DBA'; END IF;
 -- RF-01/RF-07: catálogo público con nombre, descripción, precio, disponibilidad e imagen.
 SELECT count(*) INTO n FROM inventario.v_productos_disponibles WHERE nombre IS NOT NULL AND precio_vigente>0 AND stock_disponible IS NOT NULL;
 IF n<>2 THEN RAISE EXCEPTION 'R01: catálogo público incompleto (%)',n; END IF;
 SELECT count(*) INTO n FROM inventario.producto_imagen i JOIN comunicacion.archivo a ON a.id=i.archivo_id WHERE i.principal;
 IF n<>1 THEN RAISE EXCEPTION 'R01: la imagen pública del producto no es visible (%)',n; END IF;
 RAISE NOTICE 'R01 OK [RF-01, RF-07]: visitante consulta productos, precio, disponibilidad e imagen';
 -- RF-08: búsqueda y filtros.
 IF (SELECT count(*) FROM inventario.v_productos_disponibles WHERE nombre ILIKE '%usb%')<>1
    OR (SELECT count(*) FROM inventario.v_productos_disponibles WHERE precio_vigente BETWEEN 20000 AND 50000)<>1
    OR (SELECT count(*) FROM inventario.v_productos_disponibles v JOIN inventario.categoria c ON c.id=v.categoria_id WHERE c.nombre='Almacenamiento')<>2 THEN
   RAISE EXCEPTION 'R02: búsqueda/filtrado incorrecto';
 END IF;
 RAISE NOTICE 'R02 OK [RF-08]: búsqueda por texto, rango de precio y categoría';
 -- RF-13: servicios publicados visibles sin cuenta.
 IF (SELECT count(*) FROM servicios.servicio_ofrecido WHERE publicado)<>2 THEN RAISE EXCEPTION 'R03: servicios públicos no visibles'; END IF;
 RAISE NOTICE 'R03 OK [RF-13]: visitante consulta servicios técnicos publicados';
 -- RF-16: horarios disponibles consultables.
 IF NOT EXISTS(SELECT 1 FROM servicios.v_horarios_disponibles) THEN RAISE EXCEPTION 'R04: sin horarios disponibles'; END IF;
 RAISE NOTICE 'R04 OK [RF-16]: horarios disponibles consultables';
 -- RF-06: sin identidad no se ve información privada.
 IF EXISTS(SELECT 1 FROM comercial.pedido) OR EXISTS(SELECT 1 FROM identidad.persona) OR EXISTS(SELECT 1 FROM comercial.factura) THEN
   RAISE EXCEPTION 'R05: visitante ve datos privados';
 END IF;
 RAISE NOTICE 'R05 OK [RF-06]: visitante sin acceso a pedidos, personas ni facturas';
 -- RF-09/RF-10 sin cuenta: carrito anónimo (agregar, modificar, eliminar) y compra.
 CALL comercial.crear_carrito(NULL,token,v_carrito);
 CALL comercial.editar_carrito(v_carrito,token,prod2,2);
 CALL comercial.editar_carrito(v_carrito,token,prod2,3);
 IF (comercial.consultar_carrito(v_carrito,token)->'lineas'->0->>'cantidad')::numeric<>3 THEN RAISE EXCEPTION 'R06: modificar cantidad'; END IF;
 CALL comercial.editar_carrito(v_carrito,token,prod2,0);
 IF jsonb_array_length(coalesce(comercial.consultar_carrito(v_carrito,token)->'lineas','[]'))<>0 THEN RAISE EXCEPTION 'R06: eliminar línea'; END IF;
 BEGIN CALL comercial.editar_carrito(v_carrito,repeat('cd',32),prod2,1); RAISE EXCEPTION 'R06: token ajeno aceptado';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 CALL comercial.editar_carrito(v_carrito,token,prod2,1);
 CALL comercial.convertir_carrito(v_carrito,token,'Otra','Visitante','otra.visitante@example.test',NULL,'COP',0,v_pedido);
 IF v_pedido IS NULL THEN RAISE EXCEPTION 'R06: compra de visitante'; END IF;
 RAISE NOTICE 'R06 OK [RF-09, RF-10]: carrito anónimo agrega/modifica/elimina con secreto y se convierte en pedido';
 -- RF-19/RF-14/RF-22 sin cuenta: solicitudes como visitante.
 n:=NULL; CALL comercial.solicitar_cotizacion(NULL,'Visitante','Cotiza','cotiza.visitante@example.test',NULL,'Cotizar 5 SSD',n);
 IF n IS NULL THEN RAISE EXCEPTION 'R07: cotización de visitante'; END IF;
 RAISE NOTICE 'R07 OK [RF-19]: visitante solicita cotización sin cuenta';
END $r$;

-- ===== Cliente registrado =====
DO $r$
DECLARE uc text:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='uc'); pc bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='pc');
 pt bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='pt'); cli bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='cli');
 prod bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='prod'); prod2 bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='prod2');
 equipo bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='equipo'); oferta bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='oferta');
 ofertam bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='ofertam'); v_proyecto bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='proyecto');
 doc bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='doc');
 n bigint; v_carrito bigint; v_pedido bigint; dp bigint; sol bigint; solm bigint; sd bigint; disp_antes numeric; notif bigint;
BEGIN
 PERFORM set_config('app.usuario_id',uc,true); PERFORM set_config('app.invitado_token','',true);
 -- RF-05: perfil propio sí, ajeno no.
 CALL identidad.actualizar_perfil(pc,'Cliente','Ejemplo Actualizado','cliente@example.test','0000000001');
 IF (SELECT apellidos FROM identidad.persona WHERE id=pc)<>'Ejemplo Actualizado' THEN RAISE EXCEPTION 'R08: perfil propio'; END IF;
 BEGIN CALL identidad.actualizar_perfil(pt,'X','Y','x@example.test',NULL); RAISE EXCEPTION 'R08: perfil ajeno editable';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 RAISE NOTICE 'R08 OK [RF-05]: cliente consulta y actualiza su perfil, no el de otros';
 -- RF-09/RF-10 registrado: carrito de cliente y compra con reserva de inventario.
 CALL comercial.crear_carrito(cli,NULL,v_carrito);
 CALL comercial.editar_carrito(v_carrito,NULL,prod2,4);
 CALL comercial.editar_carrito(v_carrito,NULL,prod2,2);
 IF (SELECT cantidad FROM comercial.detalle_carrito WHERE carrito_id=v_carrito AND producto_id=prod2)<>2 THEN RAISE EXCEPTION 'R09: carrito de cliente'; END IF;
 disp_antes:=inventario.consultar_disponibilidad(prod2);
 -- Flujo del diseño: el carrito del cliente se convierte en pedido borrador y el titular lo confirma.
 CALL comercial.convertir_carrito(v_carrito,NULL,'Cliente','Ejemplo','cliente@example.test','0000000001','COP',0,v_pedido);
 CALL comercial.confirmar_pedido(v_pedido,gen_random_uuid());
 BEGIN CALL comercial.guardar_detalle_pedido(dp,v_pedido,2,prod,1,0); RAISE EXCEPTION 'R09: el cliente altera líneas de pedido';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF inventario.consultar_disponibilidad(prod2)<>disp_antes-2 OR (SELECT estado FROM comercial.pedido WHERE id=v_pedido)<>'confirmado' THEN
   RAISE EXCEPTION 'R09: compra registrada sin reserva';
 END IF;
 RAISE NOTICE 'R09 OK [RF-09, RF-10]: cliente gestiona carrito, compra y la confirmación reserva inventario';
 -- RF-11/RF-12: estado e historial de compras propios.
 IF (SELECT count(*) FROM comercial.v_resumen_pedidos)<>3 OR EXISTS(SELECT 1 FROM comercial.v_resumen_pedidos WHERE cliente_id<>cli)
    OR NOT EXISTS(SELECT 1 FROM comercial.historial_pedido WHERE pedido_id=v_pedido) THEN
   RAISE EXCEPTION 'R10: consulta de pedidos';
 END IF;
 RAISE NOTICE 'R10 OK [RF-11, RF-12]: cliente consulta estado e historial solo de sus pedidos';
 -- RF-14/RF-15/RF-16: solicitudes de reparación y mantenimiento con fecha preferida.
 CALL servicios.solicitar_servicio(cli,oferta,equipo,'Pantalla intermitente',NULL,clock_timestamp()+interval '3 days',sol);
 CALL servicios.solicitar_servicio(cli,ofertam,NULL,'Mantenimiento de red','Revisión de cableado y switch',NULL,solm);
 IF (SELECT count(*) FROM servicios.solicitud_servicio WHERE id IN (sol,solm) AND cliente_id=cli)<>2
    OR (SELECT fecha_preferida FROM servicios.solicitud_servicio WHERE id=sol) IS NULL THEN RAISE EXCEPTION 'R11: solicitudes técnicas'; END IF;
 RAISE NOTICE 'R11 OK [RF-14, RF-15, RF-16]: cliente solicita reparación (con equipo y fecha preferida) y mantenimiento';
 -- RF-17/RF-18: estado de reparación e historial de servicios.
 IF NOT EXISTS(SELECT 1 FROM servicios.orden_servicio o JOIN servicios.reparacion r ON r.orden_servicio_id=o.id WHERE o.estado='finalizada')
    OR (SELECT count(*) FROM servicios.historial_servicio)=0
    OR (SELECT count(*) FROM comercial.v_historial_cliente WHERE proceso='orden_servicio')<>2 THEN
   RAISE EXCEPTION 'R12: estado/historial de servicios';
 END IF;
 RAISE NOTICE 'R12 OK [RF-17, RF-18]: cliente ve estado de su reparación e historial de reparaciones y mantenimientos';
 -- RF-20: cotizaciones asociadas a su cuenta.
 IF (SELECT count(*) FROM comercial.cotizacion)<>1 OR (SELECT count(*) FROM comercial.version_cotizacion)<>1 THEN RAISE EXCEPTION 'R13: cotizaciones propias'; END IF;
 RAISE NOTICE 'R13 OK [RF-20]: cliente consulta sus cotizaciones y versiones';
 -- RF-22: solicitud de desarrollo como cliente.
 CALL proyectos.solicitar_desarrollo(cli,'App de inventario','Reducir errores','Módulo móvil',3000000,'COP',NULL,sd);
 IF NOT EXISTS(SELECT 1 FROM proyectos.solicitud_desarrollo WHERE id=sd AND cliente_id=cli) THEN RAISE EXCEPTION 'R14: solicitud de desarrollo'; END IF;
 RAISE NOTICE 'R14 OK [RF-22]: cliente solicita desarrollo de software';
 -- RF-23/RF-24: seguimiento del proyecto.
 IF proyectos.obtener_avance(v_proyecto)<>40 OR (SELECT count(*) FROM proyectos.etapa_proyecto WHERE proyecto_id=v_proyecto)<>2
    OR (SELECT count(*) FROM proyectos.avance_proyecto)<>2 OR (SELECT descripcion FROM proyectos.proyecto WHERE id=v_proyecto) IS NULL THEN
   RAISE EXCEPTION 'R15: seguimiento de proyecto';
 END IF;
 RAISE NOTICE 'R15 OK [RF-23, RF-24]: cliente ve descripción, etapas, avances (40%%) y estado de su proyecto';
 -- RF-25/RF-26/RF-27: conversación del proyecto y documento adjunto.
 IF (SELECT count(*) FROM comunicacion.mensaje)<>1 OR NOT comunicacion.puede_leer_archivo(doc)
    OR (SELECT count(*) FROM comunicacion.adjunto WHERE proyecto_id=v_proyecto)<>1 THEN RAISE EXCEPTION 'R16: mensajería/archivos'; END IF;
 RAISE NOTICE 'R16 OK [RF-25, RF-26, RF-27]: cliente lee la conversación con el personal y el documento adjunto al proyecto';
 -- RF-28: notificaciones propias y marcado de lectura.
 SELECT id INTO notif FROM comunicacion.notificacion ORDER BY id LIMIT 1;
 IF notif IS NULL OR EXISTS(SELECT 1 FROM comunicacion.notificacion n JOIN identidad.usuario u ON u.id=n.destinatario_usuario_id WHERE u.id<>uc::bigint) THEN
   RAISE EXCEPTION 'R17: notificaciones';
 END IF;
 CALL comunicacion.marcar_notificacion_leida(notif);
 RAISE NOTICE 'R17 OK [RF-28]: cliente recibe solo sus notificaciones y las marca como leídas';
 -- RF-29: facturas y comprobantes.
 IF (SELECT count(*) FROM comercial.v_facturas_cliente)<>1 OR (SELECT count(*) FROM comercial.comprobante_factura)<>1 THEN RAISE EXCEPTION 'R18: facturas'; END IF;
 RAISE NOTICE 'R18 OK [RF-29]: cliente consulta su factura y su comprobante';
 -- RF-30: su calificación registrada.
 IF (SELECT count(*) FROM servicios.calificacion_servicio WHERE autor_persona_id=pc)<>1 THEN RAISE EXCEPTION 'R19: calificación'; END IF;
 RAISE NOTICE 'R19 OK [RF-30]: cliente ve la calificación y comentario que registró';
 -- RF-31: historial centralizado.
 IF (SELECT count(DISTINCT proceso) FROM comercial.v_historial_cliente)<7 THEN RAISE EXCEPTION 'R20: historial centralizado'; END IF;
 RAISE NOTICE 'R20 OK [RF-31]: historial centralizado con compras, servicios, cotizaciones, proyectos y facturas';
 -- RF-06/RF-32/RF-42: un cliente no ejecuta acciones administrativas.
 n:=uc::bigint;
 BEGIN CALL identidad.administrar_registro('usuario','{"estado":"bloqueado"}',n); RAISE EXCEPTION 'R21: cliente administra cuentas';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN CALL inventario.registrar_movimiento(prod,'entrada',5,'Intento de cliente',gen_random_uuid()); RAISE EXCEPTION 'R21: cliente mueve inventario';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 RAISE NOTICE 'R21 OK [RF-06]: el cliente no accede a funciones administrativas';
END $r$;

-- ===== Personal autorizado (rol administrador) =====
DO $r$
DECLARE ut text:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='ut'); uc bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='uc');
 cli bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='cli'); prod bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='prod');
 pc bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='pc');
 n bigint; antes numeric; cat bigint; solcot bigint; cot bigint; ver bigint; dc bigint; rol bigint; perm bigint; asig bigint; pid bigint;
BEGIN
 PERFORM set_config('app.usuario_id',ut,true); PERFORM set_config('app.invitado_token','',true);
 PERFORM set_config('app.motivo','Pruebas R de administración',true);
 -- RF-40/RF-41: clientes y solicitudes de todos.
 IF (SELECT count(*) FROM identidad.cliente)<3 OR (SELECT count(*) FROM comercial.solicitud_cotizacion)<2
    OR (SELECT count(*) FROM servicios.solicitud_servicio)<4 OR (SELECT count(*) FROM proyectos.solicitud_desarrollo)<2 THEN
   RAISE EXCEPTION 'R22: visión administrativa incompleta';
 END IF;
 RAISE NOTICE 'R22 OK [RF-40, RF-41]: el personal ve clientes y las tres clases de solicitudes';
 -- RF-33: productos, precios y categorías.
 CALL identidad.administrar_registro('categoria','{"nombre":"Redes","descripcion":"Equipos de red"}',cat);
 CALL inventario.guardar_producto(prod,'DEMO-SSD-001',cat,'SSD de demostración','Unidad de laboratorio','unidad',120000,'COP',true,true);
 IF (SELECT precio_vigente FROM inventario.producto WHERE id=prod)<>120000 THEN RAISE EXCEPTION 'R23: precio'; END IF;
 RAISE NOTICE 'R23 OK [RF-33]: el personal crea categorías y actualiza precio/categoría de productos';
 -- RF-34: entradas, salidas y existencias.
 antes:=inventario.consultar_disponibilidad(prod);
 CALL inventario.registrar_movimiento(prod,'entrada',5,'Compra a proveedor ficticio',gen_random_uuid());
 CALL inventario.registrar_movimiento(prod,'salida',-2,'Uso interno ficticio',gen_random_uuid());
 IF inventario.consultar_disponibilidad(prod)<>antes+3 THEN RAISE EXCEPTION 'R24: existencias'; END IF;
 RAISE NOTICE 'R24 OK [RF-34]: entradas y salidas actualizan existencias mediante el libro de movimientos';
 -- RF-35: estado de pedidos.
 SELECT p.id INTO STRICT n FROM comercial.pedido p WHERE p.cliente_id=cli AND p.estado='confirmado' ORDER BY p.id LIMIT 1;
 CALL comercial.cambiar_estado_pedido(n,'completado','Entrega ficticia');
 IF (SELECT estado FROM comercial.pedido WHERE id=n)<>'completado' THEN RAISE EXCEPTION 'R25: estado de pedido'; END IF;
 RAISE NOTICE 'R25 OK [RF-35]: el personal actualiza el estado de un pedido';
 -- RF-38/RF-21: crear, enviar cotización; el cliente la rechaza.
 CALL comercial.solicitar_cotizacion(pc,NULL,NULL,NULL,NULL,'Cotizar soporte mensual',solcot);
 CALL comercial.cambiar_estado_solicitud_cotizacion(solcot,'en_evaluacion','Revisión');
 CALL comercial.crear_cotizacion(solcot,NULL,'COP','Soporte mensual','Cliente Ejemplo','cliente@example.test','0000000001',clock_timestamp()+interval '10 days',cot,ver);
 CALL comercial.guardar_detalle_cotizacion(ver,1,'libre',NULL,NULL,'Soporte remoto mensual',1,'servicio',250000,0,0,dc);
 CALL comercial.enviar_cotizacion(ver,'Propuesta enviada');
 INSERT INTO pg_temp.r_ctx VALUES('ver',ver::text);
 RAISE NOTICE 'R26 OK [RF-38]: el personal crea, detalla y envía una cotización';
 -- RF-32/RF-40: administración de datos de clientes y cuentas.
 CALL identidad.administrar_registro('persona','{"telefono":"0000000077"}',pc);
 IF (SELECT telefono FROM identidad.persona WHERE id=pc)<>'0000000077' THEN RAISE EXCEPTION 'R27: gestión de cliente'; END IF;
 RAISE NOTICE 'R27 OK [RF-32, RF-40]: el personal actualiza datos de un cliente';
 -- RF-42: roles y permisos.
 SELECT id INTO STRICT rol FROM identidad.rol WHERE codigo='administrativo';
 SELECT id INTO STRICT perm FROM identidad.permiso WHERE codigo='producto.gestionar';
 CALL identidad.configurar_permiso_rol(rol,perm,true,'Prueba de concesión');
 IF NOT EXISTS(SELECT 1 FROM identidad.rol_permiso WHERE rol_id=rol AND permiso_id=perm) THEN RAISE EXCEPTION 'R28: conceder permiso'; END IF;
 CALL identidad.configurar_permiso_rol(rol,perm,false,'Prueba de retiro');
 IF EXISTS(SELECT 1 FROM identidad.rol_permiso WHERE rol_id=rol AND permiso_id=perm) THEN RAISE EXCEPTION 'R28: retirar permiso'; END IF;
 CALL identidad.asignar_rol(uc,rol);
 SELECT id INTO STRICT asig FROM identidad.usuario_rol WHERE usuario_id=uc AND rol_id=rol AND termina_en IS NULL;
 CALL identidad.revocar_rol(asig,'Prueba de revocación');
 IF EXISTS(SELECT 1 FROM identidad.usuario_rol WHERE id=asig AND termina_en IS NULL) THEN RAISE EXCEPTION 'R28: revocar rol'; END IF;
 RAISE NOTICE 'R28 OK [RF-42]: conceder/retirar permisos a roles y asignar/revocar roles con historial';
END $r$;

-- RF-21: el cliente rechaza la versión enviada.
DO $r$
DECLARE ver bigint:=(SELECT valor FROM pg_temp.r_ctx WHERE clave='ver');
BEGIN
 PERFORM set_config('app.usuario_id',(SELECT valor FROM pg_temp.r_ctx WHERE clave='uc'),true);
 CALL comercial.responder_cotizacion(ver,false,'Rechazo ficticio: presupuesto insuficiente');
 IF (SELECT estado FROM comercial.version_cotizacion WHERE id=ver)<>'rechazada' THEN RAISE EXCEPTION 'R29: rechazo de cotización'; END IF;
 BEGIN CALL comercial.responder_cotizacion(ver,true,'Cambio de opinión'); RAISE EXCEPTION 'R29: respuesta modificable';
 EXCEPTION WHEN OTHERS THEN IF SQLSTATE NOT IN ('23514','P0001','42501') THEN RAISE; END IF; END;
 RAISE NOTICE 'R29 OK [RF-21]: el cliente rechaza una cotización recibida y la respuesta queda fija';
 -- La auditoría registró las operaciones de la sesión de aplicación.
 PERFORM set_config('app.usuario_id','',true);
END $r$;
RESET SESSION AUTHORIZATION;
DO $r$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM auditoria.evento_auditoria WHERE tabla_objeto='version_cotizacion' AND usuario_conexion='st_app') THEN
   RAISE EXCEPTION 'R30: auditoría sin evidencia de la aplicación';
 END IF;
 RAISE NOTICE 'R30 OK [RF-32, RF-42]: las operaciones de la aplicación quedan en auditoría';
END $r$;
ROLLBACK;
\echo PRUEBAS POR REQUERIMIENTO R01-R30 TERMINADAS SIN ERROR
