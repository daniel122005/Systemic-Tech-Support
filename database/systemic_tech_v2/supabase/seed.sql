-- Systemic Tech & Support — DATOS FICTICIOS para entorno local o de pruebas.
-- `supabase db reset` lo aplica solo en local. NUNCA usar `db push --include-seed` en producción.
-- Generado desde 70_datos_demo.sql sin el catálogo de roles/permisos (ya incluido en migraciones).
-- Datos exclusivamente ficticios. Ejecutar una sola vez, como DBA, después de instalar.
-- Las tasas cero son ejemplos de cálculo, NO una clasificación tributaria.
DO $demo$
DECLARE pc bigint; pt bigint; pg bigint; uc bigint; ut bigint; cli bigint; invitado bigint;
 emp bigint; rol bigint; cat bigint; prod bigint; prod2 bigint; pedido bigint; dp bigint;
 cot bigint; ver bigint; dc bigint; solcot bigint; pedcot bigint; factura bigint; df bigint;
 oferta bigint; ofertam bigint; equipo bigint; solicitud bigint; solicitudm bigint; orden bigint; ordenm bigint;
 asignacion bigint; disponibilidad bigint; cita bigint; sd bigint; proyecto bigint; miembro bigint;
 etapa bigint; etapa2 bigint; avance bigint; conv bigint; mensaje bigint; archivo bigint; adj bigint;
 carrito bigint; pedido_guest bigint; token text:=encode(extensions.gen_random_bytes(32),'hex');
 v_recurso_permiso record;
BEGIN
 IF EXISTS(SELECT 1 FROM identidad.cliente WHERE codigo='DEMO-CLIENTE-001') THEN RAISE EXCEPTION 'Los datos de demostración ya existen'; END IF;
 PERFORM set_config('app.motivo','Carga inicial de datos ficticios Systemic Tech',true);
 IF NOT EXISTS (SELECT 1 FROM identidad.rol WHERE codigo='administrador') THEN
   RAISE EXCEPTION 'Falta el catálogo base de roles y permisos (migración datos_base)';
 END IF;
 INSERT INTO identidad.persona(nombres,apellidos,correo_contacto,telefono) VALUES('Cliente','Ejemplo','cliente@example.test','0000000001') RETURNING id INTO pc;
 INSERT INTO identidad.persona(nombres,apellidos,correo_contacto,telefono) VALUES('Profesional','Ejemplo','profesional@example.test','0000000002') RETURNING id INTO pt;
 INSERT INTO identidad.cliente(persona_id,codigo) VALUES(pc,'DEMO-CLIENTE-001') RETURNING id INTO cli;
 INSERT INTO identidad.empleado(persona_id,codigo,cargo,fecha_vinculacion) VALUES(pt,'DEMO-EMP-001','Técnico y desarrollador',current_date) RETURNING id INTO emp;
 -- Identidades externas simuladas: no permiten iniciar sesión en ningún proveedor real.
 INSERT INTO identidad.usuario(persona_id,correo_acceso,estado,origen_auth,emisor_externo,sujeto_externo,verificado_en)
 VALUES(pc,'cliente@example.test','activo','externo','https://identidad.example.test','cliente-demo',transaction_timestamp()) RETURNING id INTO uc;
 INSERT INTO identidad.usuario(persona_id,correo_acceso,estado,origen_auth,emisor_externo,sujeto_externo,verificado_en)
 VALUES(pt,'profesional@example.test','activo','externo','https://identidad.example.test','profesional-demo',transaction_timestamp()) RETURNING id INTO ut;
 SELECT id INTO rol FROM identidad.rol WHERE codigo='cliente'; CALL identidad.asignar_rol(uc,rol);
 SELECT id INTO rol FROM identidad.rol WHERE codigo='administrador'; CALL identidad.asignar_rol(ut,rol);
 SELECT id INTO rol FROM identidad.rol WHERE codigo='tecnico'; CALL identidad.asignar_rol(ut,rol);
 SELECT id INTO rol FROM identidad.rol WHERE codigo='desarrollador'; CALL identidad.asignar_rol(ut,rol);
 PERFORM set_config('app.usuario_id',ut::text,true);
 INSERT INTO inventario.categoria(nombre,descripcion) VALUES('Almacenamiento','Componentes y accesorios de almacenamiento') RETURNING id INTO cat;
 CALL inventario.guardar_producto(prod,'DEMO-SSD-001',cat,'SSD de demostración','Unidad de laboratorio','unidad',100000,'COP',true,true);
 CALL inventario.guardar_producto(prod2,'DEMO-USB-001',cat,'Memoria USB de demostración','Accesorio de laboratorio','unidad',30000,'COP',true,true);
 CALL inventario.registrar_movimiento(prod,'entrada',10,'Existencias iniciales de demostración',gen_random_uuid());
 CALL inventario.registrar_movimiento(prod2,'entrada',20,'Existencias iniciales de demostración',gen_random_uuid());
 CALL comercial.crear_pedido(pedido,cli,'COP','Cliente Ejemplo','cliente@example.test','0000000001');
 CALL comercial.guardar_detalle_pedido(dp,pedido,1,prod,1,0);
 CALL comercial.confirmar_pedido(pedido,gen_random_uuid());
 CALL comercial.cambiar_estado_pedido(pedido,'completado','Entrega de producto de demostración');
 CALL comercial.crear_factura(pedido,NULL,NULL,'Cliente Ejemplo','DEMO-001','cliente@example.test','0000000001','Dirección de demostración',factura);
 CALL comercial.guardar_detalle_factura(factura,1,dp,NULL,1,NULL,NULL,NULL,0,df);
 CALL comercial.emitir_factura(factura,gen_random_uuid());
 -- Una modificación posterior del catálogo no altera el precio histórico del pedido.
 CALL inventario.guardar_producto(prod,'DEMO-SSD-001',cat,'SSD de demostración','Unidad de laboratorio','unidad',110000,'COP',true,true);
 CALL comercial.solicitar_cotizacion(pc,NULL,NULL,NULL,NULL,'Dos unidades SSD para un puesto técnico',solcot);
 CALL comercial.cambiar_estado_solicitud_cotizacion(solcot,'en_evaluacion','Revisar necesidades');
 CALL comercial.crear_cotizacion(solcot,NULL,'COP','Entrega en taller; propuesta de demostración','Cliente Ejemplo','cliente@example.test','0000000001',clock_timestamp()+interval '15 days',cot,ver);
 CALL comercial.guardar_detalle_cotizacion(ver,1,'producto',prod,NULL,'SSD según propuesta',2,'unidad',95000,0,0,dc);
 CALL comercial.enviar_cotizacion(ver,'Propuesta preparada');
 PERFORM set_config('app.usuario_id',uc::text,true);
 CALL comercial.responder_cotizacion(ver,true,'Aceptación ficticia del cliente para demostración');
 PERFORM set_config('app.usuario_id',ut::text,true);
 CALL comercial.cambiar_estado_solicitud_cotizacion(solcot,'atendida','Cotización aceptada');
 CALL comercial.crear_pedido(pedcot,cli,'COP','Cliente Ejemplo','cliente@example.test','0000000001',ver);
 dp:=NULL; CALL comercial.guardar_detalle_pedido(dp,pedcot,1,prod,2,0,0,dc);
 CALL comercial.confirmar_pedido(pedcot,gen_random_uuid());
 -- Compra de invitado: carrito con token opaco, nuevo cliente sin cuenta y pedido borrador.
 CALL comercial.crear_carrito(NULL,token,carrito);
 CALL comercial.editar_carrito(carrito,token,prod2,1);
 CALL comercial.convertir_carrito(carrito,token,'Visitante','Ejemplo','visitante@example.test','0000000003','COP',0,pedido_guest);
 INSERT INTO servicios.servicio_ofrecido(codigo,nombre,descripcion,modalidad,publicado)
 VALUES('DEMO-REP','Reparación de equipos','Diagnóstico y reparación','reparacion',true) RETURNING id INTO oferta;
 INSERT INTO servicios.servicio_ofrecido(codigo,nombre,descripcion,modalidad,publicado)
 VALUES('DEMO-MAN','Mantenimiento preventivo','Limpieza y revisión','mantenimiento',true) RETURNING id INTO ofertam;
 CALL servicios.registrar_equipo(cli,'portatil','Equipo de demostración','Marca Ejemplo','Modelo Ejemplo','DEMO-SERIE',equipo);
 CALL servicios.solicitar_servicio(cli,oferta,equipo,'No inicia el equipo',NULL,NULL,solicitud);
 CALL servicios.cambiar_estado_solicitud(solicitud,'en_evaluacion','Diagnóstico inicial');
 CALL servicios.aceptar_solicitud(solicitud,180000,0,'COP',NULL,NULL,orden);
 CALL servicios.asignar_tecnico(orden,emp,'Responsable de reparación',true,'Asignación inicial',asignacion);
 CALL servicios.cambiar_estado_orden(orden,'en_ejecucion','Inicio de diagnóstico');
 CALL servicios.registrar_informe_reparacion(orden,'Conexión interna defectuosa','Conector flojo','Se ajustó el conector','Inicio y prueba funcional correctos');
 CALL servicios.cerrar_servicio(orden,'Equipo recuperado','Entrega acordada');
 PERFORM set_config('app.usuario_id',uc::text,true);
 CALL servicios.calificar_servicio(orden,5::smallint,'Atención satisfactoria en caso de demostración');
 PERFORM set_config('app.usuario_id',ut::text,true);
 CALL servicios.solicitar_servicio(cli,ofertam,equipo,'Limpieza preventiva','Limpieza y revisión general',NULL,solicitudm);
 CALL servicios.cambiar_estado_solicitud(solicitudm,'en_evaluacion','Revisión del alcance');
 CALL servicios.aceptar_solicitud(solicitudm,90000,0,'COP',NULL,'preventivo',ordenm);
 asignacion:=NULL; CALL servicios.asignar_tecnico(ordenm,emp,'Responsable de mantenimiento',true,'Asignación inicial',asignacion);
 CALL servicios.registrar_disponibilidad(emp,clock_timestamp()+interval '10 days',clock_timestamp()+interval '10 days 8 hours','Jornada de demostración',disponibilidad);
 CALL servicios.programar_cita(solicitudm,emp,clock_timestamp()+interval '10 days 1 hour',clock_timestamp()+interval '10 days 2 hours','presencial','Taller de demostración',true,cita);
 CALL proyectos.solicitar_desarrollo(cli,'Seguimiento de solicitudes','Centralizar información','Portal para clientes',1200000,'COP',NULL,sd);
 CALL proyectos.cambiar_estado_solicitud(sd,'en_evaluacion','Viabilidad revisada');
 CALL proyectos.aprobar_solicitud(sd,'Portal de soporte','Proyecto ficticio','Solicitudes y seguimiento',1200000,0,'COP',NULL,proyecto);
 CALL proyectos.asignar_miembro(proyecto,emp,'Desarrollador responsable',true,'Asignación inicial',miembro);
 CALL proyectos.definir_etapa(proyecto,'Análisis','Definir alcance',1,1,NULL,NULL,'Plan inicial',etapa);
 CALL proyectos.definir_etapa(proyecto,'Construcción','Implementar y revisar',2,3,NULL,NULL,'Plan inicial',etapa2);
 CALL proyectos.cambiar_estado_proyecto(proyecto,'en_ejecucion','Inicio aprobado');
 CALL proyectos.registrar_avance(etapa,miembro,100,'Análisis finalizado',NULL,avance);
 avance:=NULL; CALL proyectos.registrar_avance(etapa2,miembro,20,'Primer incremento',NULL,avance);
 CALL comunicacion.crear_conversacion('Seguimiento del portal','proyecto',proyecto,ARRAY[pc,pt],conv);
 CALL comunicacion.enviar_mensaje(conv,'El análisis está aprobado y comenzó la construcción.',ARRAY[]::bigint[],mensaje);
 PERFORM set_config('app.usuario_id',uc::text,true);
 CALL comunicacion.marcar_mensaje_leido(mensaje);
 PERFORM set_config('app.usuario_id','',true);
 SET CONSTRAINTS ALL IMMEDIATE;
 IF (SELECT precio_unitario FROM comercial.detalle_pedido WHERE pedido_id=pedido)<>100000 THEN RAISE EXCEPTION 'Precio histórico incorrecto'; END IF;
 IF inventario.existencia_disponible(prod)<>7 THEN RAISE EXCEPTION 'Existencia disponible esperada: 7'; END IF;
 IF proyectos.obtener_avance(proyecto)<>40 THEN RAISE EXCEPTION 'Avance esperado: 40%%'; END IF;
 IF comercial.total_factura(factura)<>100000 THEN RAISE EXCEPTION 'Factura esperada: 100000'; END IF;
END $demo$;
SELECT 'Datos ficticios insertados y comprobaciones de demostración superadas' AS resultado;

-- ===== 71_datos_demo_complemento.sql =====
-- Complemento de datos EXCLUSIVAMENTE ficticios. Ejecutar una sola vez, como DBA, DESPUÉS de 70_datos_demo.sql.
-- Cubre las tablas que 70 dejaba vacías y que relacionan módulos entre sí:
--   inventario.producto_imagen, comunicacion.archivo, comunicacion.adjunto, comercial.comprobante_factura,
--   comunicacion.entrega_notificacion, identidad.acceso_invitado y identidad.acceso_invitado_permiso.
-- Solo usa procedimientos del sistema (no inserta directamente en tablas protegidas).
-- No crea contraseñas, sesiones ni recuperaciones locales: con Supabase Auth esas tablas quedan vacías.
-- Los objetos de almacenamiento son referencias ficticias: no existen bytes en ningún almacén.
DO $complemento$
DECLARE
 ut bigint; prod bigint; proyecto bigint; factura bigint; pedido_guest bigint; visitante bigint;
 img bigint; doc bigint; comp bigint; adj bigint; imagen_id bigint; comprobante bigint;
 notif bigint; entrega bigint; acceso bigint;
 token text := encode(sha256(convert_to(gen_random_uuid()::text || clock_timestamp()::text || random()::text, 'UTF8')), 'hex');
BEGIN
 IF NOT EXISTS(SELECT 1 FROM identidad.cliente WHERE codigo='DEMO-CLIENTE-001') THEN
   RAISE EXCEPTION 'Ejecute primero 70_datos_demo.sql';
 END IF;
 IF EXISTS(SELECT 1 FROM comunicacion.archivo WHERE almacen='demo_sin_almacenamiento') THEN
   RAISE EXCEPTION 'El complemento de datos de demostración ya fue cargado';
 END IF;
 IF NOT identidad.es_dba() THEN RAISE EXCEPTION 'Ejecute como DBA (postgres local o postgres de Supabase)'; END IF;
 -- Si se ejecuta en la misma transacción que 70 (p. ej. seed.sql de Supabase), 70 dejó las restricciones en
 -- modo inmediato. Se restablece el modo diferido para que las validaciones de fin de transacción
 -- (p. ej. concesión de invitado con sus acciones) se evalúen al final, como en producción.
 SET CONSTRAINTS ALL DEFERRED;
 PERFORM set_config('app.motivo','Complemento de datos ficticios Systemic Tech',true);
 SELECT u.id INTO STRICT ut FROM identidad.usuario u WHERE u.correo_acceso='profesional@example.test';
 SELECT id INTO STRICT prod FROM inventario.producto WHERE sku='DEMO-SSD-001';
 SELECT id INTO STRICT proyecto FROM proyectos.proyecto WHERE nombre='Portal de soporte';
 SELECT f.id INTO STRICT factura FROM comercial.factura f JOIN comercial.pedido p ON p.id=f.pedido_id
   JOIN identidad.cliente c ON c.id=p.cliente_id WHERE c.codigo='DEMO-CLIENTE-001' AND f.estado='emitida';
 SELECT id INTO STRICT visitante FROM identidad.persona WHERE correo_contacto='visitante@example.test';
 SELECT p.id INTO STRICT pedido_guest FROM comercial.pedido p JOIN identidad.cliente c ON c.id=p.cliente_id
   WHERE c.persona_id=visitante;

 -- RF-07/RF-33: imagen pública de catálogo (archivo validado y público).
 PERFORM set_config('app.usuario_id',ut::text,true);
 CALL comunicacion.registrar_archivo('ssd_demo.webp','demo_sin_almacenamiento','catalogo/DEMO-SSD-001/principal.webp','image/webp',48213,img);
 CALL comunicacion.validar_archivo(img,'validado',sha256(convert_to('imagen ficticia SSD','UTF8')),true);
 CALL identidad.administrar_registro('producto_imagen',
   jsonb_build_object('producto_id',prod,'archivo_id',img,'orden',1,'texto_alternativo','SSD de demostración, vista frontal','principal',true),imagen_id);

 -- RF-27: documento privado adjunto a un proyecto (visible para su titular y el equipo).
 CALL comunicacion.registrar_archivo('alcance_portal.pdf','demo_sin_almacenamiento','proyectos/portal-soporte/alcance.pdf','application/pdf',182044,doc);
 CALL comunicacion.validar_archivo(doc,'validado',sha256(convert_to('documento ficticio de alcance','UTF8')),false);
 CALL comunicacion.adjuntar_archivo(doc,'proyecto',proyecto,'Documento de alcance acordado','compartido',adj);

 -- RF-29: comprobante (PDF) asociado a la factura emitida.
 CALL comunicacion.registrar_archivo('factura_demo_001.pdf','demo_sin_almacenamiento','facturas/DEMO-001.pdf','application/pdf',35120,comp);
 CALL comunicacion.validar_archivo(comp,'validado',sha256(convert_to('comprobante ficticio','UTF8')),false);
 CALL comercial.vincular_comprobante(factura,comp,'representacion_grafica','Representación gráfica de la factura de demostración',comprobante);
 PERFORM set_config('app.usuario_id','',true);

 -- RF-28: entrega por correo de una notificación ya generada (simula el trabajador de envíos).
 SELECT n.id INTO notif FROM comunicacion.notificacion n JOIN identidad.usuario u ON u.id=n.destinatario_usuario_id
  WHERE u.correo_acceso='cliente@example.test' ORDER BY n.id LIMIT 1;
 IF notif IS NULL THEN RAISE EXCEPTION 'No hay notificaciones del cliente de demostración'; END IF;
 CALL comunicacion.encolar_entrega(notif,'correo','cliente@example.test',gen_random_uuid(),entrega);
 CALL comunicacion.reclamar_entrega(entrega);
 -- Regla T12: enviando -> enviada (aceptada por el proveedor) -> entregada (confirmación posterior).
 CALL comunicacion.registrar_resultado_entrega(entrega,'enviada','proveedor_ficticio','DEMO-MSG-0001',NULL);
 CALL comunicacion.registrar_resultado_entrega(entrega,'entregada','proveedor_ficticio','DEMO-MSG-0001',NULL);

 -- RF-10/RF-11 sin cuenta: concesión verificada para que el visitante consulte su pedido (7 días, solo lectura).
 CALL identidad.emitir_acceso_invitado(visitante,'pedido',pedido_guest,NULL,'correo','visitante@example.test',
   clock_timestamp()-interval '1 minute',clock_timestamp()+interval '7 days',token,ARRAY['leer'],acceso);

 SET CONSTRAINTS ALL IMMEDIATE;
 -- Comprobaciones de la propia carga.
 IF NOT EXISTS(SELECT 1 FROM inventario.producto_imagen WHERE producto_id=prod AND principal) THEN RAISE EXCEPTION 'Falta imagen principal'; END IF;
 IF (SELECT count(*) FROM comunicacion.adjunto WHERE proyecto_id=proyecto)<>1 THEN RAISE EXCEPTION 'Falta adjunto del proyecto'; END IF;
 IF (SELECT estado FROM comunicacion.entrega_notificacion WHERE id=entrega)<>'entregada' THEN RAISE EXCEPTION 'Entrega no registrada'; END IF;
 -- El token vale para leer el pedido del visitante y nada más.
 PERFORM set_config('app.invitado_token',token,true);
 IF identidad.actor_persona_actual() IS DISTINCT FROM visitante
    OR NOT identidad.persona_puede_acceder(visitante,'pedido',pedido_guest,'leer') THEN
   RAISE EXCEPTION 'La concesión de invitado no identifica al visitante';
 END IF;
 PERFORM set_config('app.invitado_token','',true);
END $complemento$;
SELECT 'Complemento de datos ficticios cargado: imagen, adjunto, comprobante, entrega e invitado' AS resultado;
