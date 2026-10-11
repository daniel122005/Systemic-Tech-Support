BEGIN;
CREATE FUNCTION identidad.datos_autenticacion(p_correo text)
RETURNS TABLE(usuario_id bigint,password_hash text,estado text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF NOT identidad.es_dba() AND NOT pg_has_role(session_user,'st_worker','MEMBER') THEN RAISE EXCEPTION 'Solo servicio de autenticación' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT u.id,c.password_hash,u.estado FROM identidad.usuario u
 JOIN identidad.persona p ON p.id=u.persona_id JOIN identidad.credencial c ON c.usuario_id=u.id
 WHERE u.correo_acceso=lower(btrim(p_correo)) AND u.origen_auth='local' AND p.activo AND u.estado IN ('pendiente','activo');
END $$;
CREATE PROCEDURE identidad.confirmar_correo(p_usuario bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();
 IF NOT identidad.es_dba() AND NOT pg_has_role(session_user,'st_worker','MEMBER') THEN RAISE EXCEPTION 'Solo servicio de autenticación' USING ERRCODE='42501'; END IF;
 UPDATE identidad.usuario SET estado='activo',verificado_en=clock_timestamp() WHERE id=p_usuario AND estado='pendiente';
 IF NOT FOUND THEN RAISE EXCEPTION 'La cuenta no está pendiente'; END IF;
END $$;
CREATE FUNCTION identidad.estado_sesion(p_sesion bigint,p_hash bytea)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE u bigint;
BEGIN
 IF NOT identidad.es_dba() AND NOT pg_has_role(session_user,'st_worker','MEMBER') THEN RAISE EXCEPTION 'Solo servicio de autenticación' USING ERRCODE='42501'; END IF;
 SELECT s.usuario_id INTO u FROM identidad.sesion s JOIN identidad.usuario x ON x.id=s.usuario_id
 JOIN identidad.persona p ON p.id=x.persona_id WHERE s.id=p_sesion AND s.refresh_hash=p_hash
 AND s.revocada_en IS NULL AND s.inicia_en<=clock_timestamp() AND s.vence_en>clock_timestamp() AND x.estado='activo' AND p.activo;
 RETURN u;
END $$;
CREATE PROCEDURE comercial.vincular_comprobante(p_factura bigint,p_archivo bigint,p_clase text,p_descripcion text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 PERFORM identidad.bloquear_operacion();PERFORM identidad.exigir_permiso('factura','gestionar',p_factura);
 IF p_id IS NOT NULL THEN RAISE EXCEPTION 'El identificador de alta debe ser NULL'; END IF;
 IF NOT EXISTS(SELECT 1 FROM comercial.factura WHERE id=p_factura AND estado IN ('emitida','anulada')) THEN RAISE EXCEPTION 'Comprobante requiere factura emitida'; END IF;
 IF NOT comunicacion.puede_leer_archivo(p_archivo) THEN PERFORM identidad.exigir_permiso('archivo','gestionar',p_archivo); END IF;
 IF NOT EXISTS(SELECT 1 FROM comunicacion.archivo WHERE id=p_archivo AND estado='validado' AND visibilidad='privado') THEN RAISE EXCEPTION 'Comprobante requiere archivo privado validado'; END IF;
 INSERT INTO comercial.comprobante_factura(factura_id,archivo_id,clase_documento,descripcion)
 VALUES(p_factura,p_archivo,p_clase,p_descripcion) RETURNING id INTO p_id;
END $$;
COMMIT;
