\set ON_ERROR_STOP on
-- Ejecutar como DBA. Casos de contacto y conservación de la información histórica.
BEGIN;
DO $pruebas$
DECLARE v_persona bigint; v_solicitud bigint; v_otra_solicitud bigint; v_invitada bigint; v_solicitud_invalida bigint;
 v_rechazada boolean:=false; v_correo text:='contacto.'||gen_random_uuid()::text||'@example.test';
BEGIN
 IF NOT identidad.es_dba() THEN RAISE EXCEPTION 'Las pruebas requieren un DBA'; END IF;
 INSERT INTO identidad.persona(nombres,apellidos,correo_contacto,telefono)
 VALUES('Persona','Prueba de contacto',v_correo,'0000000099') RETURNING id INTO v_persona;
 CALL comercial.solicitar_cotizacion(v_persona,NULL,NULL,NULL,NULL,'Solicitud de prueba con datos del perfil',v_solicitud);
 IF NOT EXISTS(SELECT 1 FROM comercial.solicitud_cotizacion sc WHERE sc.id=v_solicitud
 AND sc.persona_id=v_persona AND sc.contacto_nombre='Persona Prueba de contacto'
 AND sc.contacto_correo=v_correo AND sc.contacto_telefono='0000000099') THEN
   RAISE EXCEPTION 'Q01: no se copiaron los datos del perfil';
 END IF;
 UPDATE identidad.persona SET correo_contacto='perfil.modificado@example.test' WHERE id=v_persona;
 IF (SELECT contacto_correo FROM comercial.solicitud_cotizacion WHERE id=v_solicitud) IS DISTINCT FROM v_correo THEN
   RAISE EXCEPTION 'Q02: cambiar el perfil alteró una solicitud histórica';
 END IF;
 CALL comercial.solicitar_cotizacion(v_persona,NULL,NULL,'alternativo@example.test',NULL,'Solicitud con contacto alternativo',v_otra_solicitud);
 IF (SELECT contacto_correo FROM comercial.solicitud_cotizacion WHERE id=v_otra_solicitud)<>'alternativo@example.test'
 OR (SELECT correo_contacto FROM identidad.persona WHERE id=v_persona)<>'perfil.modificado@example.test' THEN
   RAISE EXCEPTION 'Q03: no se respetó el contacto alternativo o se modificó el perfil';
 END IF;
 CALL comercial.solicitar_cotizacion(NULL,'Visitante','Prueba','invitado.contacto@example.test',NULL,'Cotización sin cuenta',v_invitada);
 IF NOT EXISTS(SELECT 1 FROM comercial.solicitud_cotizacion sc WHERE sc.id=v_invitada AND sc.contacto_correo='invitado.contacto@example.test'
 AND NOT EXISTS(SELECT 1 FROM identidad.usuario u WHERE u.persona_id=sc.persona_id)) THEN
   RAISE EXCEPTION 'Q04: la solicitud de invitado debe ser posible sin cuenta';
 END IF;
 BEGIN
   CALL comercial.solicitar_cotizacion(NULL,'Visitante','Sin contacto',NULL,'   ','Contacto insuficiente',v_solicitud_invalida);
 EXCEPTION WHEN invalid_parameter_value THEN v_rechazada:=true;
 END;
 IF NOT v_rechazada THEN RAISE EXCEPTION 'Q05: se aceptó una solicitud sin contacto'; END IF;
 SET CONSTRAINTS ALL IMMEDIATE;
 RAISE NOTICE 'Q01-Q05 OK: perfil, contacto alternativo, historia e invitado';
END $pruebas$;
ROLLBACK;
