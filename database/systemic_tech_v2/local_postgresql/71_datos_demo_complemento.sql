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
