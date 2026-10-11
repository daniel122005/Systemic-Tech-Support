-- Datos exclusivamente ficticios. Ejecutar una sola vez, como DBA, después de instalar.
-- Las tasas cero son ejemplos de cálculo, NO una clasificación tributaria.
BEGIN;
SET LOCAL TRANSACTION ISOLATION LEVEL READ COMMITTED;
DO $demo$
DECLARE pc bigint; pt bigint; pg bigint; uc bigint; ut bigint; cli bigint; invitado bigint;
 emp bigint; rol bigint; cat bigint; prod bigint; prod2 bigint; pedido bigint; dp bigint;
 cot bigint; ver bigint; dc bigint; solcot bigint; pedcot bigint; factura bigint; df bigint;
 oferta bigint; ofertam bigint; equipo bigint; solicitud bigint; solicitudm bigint; orden bigint; ordenm bigint;
 asignacion bigint; disponibilidad bigint; cita bigint; sd bigint; proyecto bigint; miembro bigint;
 etapa bigint; etapa2 bigint; avance bigint; conv bigint; mensaje bigint; archivo bigint; adj bigint;
 carrito bigint; pedido_guest bigint; token text:=encode(public.gen_random_bytes(32),'hex');
 v_recurso_permiso record;
BEGIN
 IF EXISTS(SELECT 1 FROM identidad.cliente WHERE codigo='DEMO-CLIENTE-001') THEN RAISE EXCEPTION 'Los datos de demostración ya existen'; END IF;
 PERFORM set_config('app.motivo','Carga inicial de datos ficticios Systemic Tech',true);
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
COMMIT;
SELECT 'Datos ficticios insertados y comprobaciones de demostración superadas' AS resultado;
