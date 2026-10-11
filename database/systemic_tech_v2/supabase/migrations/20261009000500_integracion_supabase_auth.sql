-- Systemic Tech & Support — migración para Supabase (escrita a mano; no la genera el script).
-- 5/6. Integración con Supabase Auth y cierre de la API pública.
--
-- Decisiones (ver ADAPTACIONES_SUPABASE.md):
--  * Supabase Auth administra contraseñas, confirmación de correo, recuperación y sesiones (RF-02..RF-04).
--    El modelo ya admitía cuentas externas: usuario.origen_auth='externo' + (emisor_externo, sujeto_externo).
--    Aquí emisor_externo='supabase-auth' y sujeto_externo = auth.users.id.
--  * No se crea clave foránea hacia auth.users: borrar una cuenta de Auth no debe borrar historia comercial.
--  * La API REST/GraphQL de Supabase NO expone los 7 esquemas. anon/authenticated/service_role no reciben
--    ningún privilegio. La plataforma accede mediante su backend con el rol st_backend (miembro de st_app),
--    igual que en el diseño local, y fija la identidad con identidad.iniciar_contexto_supabase().
--  * Las rutinas de contraseña local quedan sin EXECUTE para la aplicación: no se usan con Supabase Auth.
DO $precondiciones$
BEGIN
  IF current_database() <> 'postgres' THEN RAISE EXCEPTION 'En Supabase la base debe ser postgres'; END IF;
  IF to_regclass('auth.users') IS NULL THEN RAISE EXCEPTION 'No existe auth.users: este archivo es solo para Supabase'; END IF;
  IF to_regprocedure('identidad.bloquear_operacion()') IS NULL THEN RAISE EXCEPTION 'Aplique antes las migraciones 1 a 4'; END IF;
END
$precondiciones$;

SET ROLE st_owner;
SET search_path = pg_catalog, pg_temp;

-- Sincroniza auth.users -> identidad.persona/usuario/cliente. Se ejecuta con los privilegios de st_owner.
CREATE FUNCTION identidad.sincronizar_usuario_supabase() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_usuario identidad.usuario%ROWTYPE;
  v_persona bigint;
  v_correo text;
  v_meta jsonb;
  v_nombres text;
  v_apellidos text;
  v_telefono text;
  v_bloqueado boolean;
BEGIN
  PERFORM identidad.bloquear_operacion();
  PERFORM set_config('app.motivo', 'Sincronización con Supabase Auth', true);
  IF TG_OP = 'DELETE' THEN
    -- Se conserva la persona y su historia; la cuenta queda inactiva.
    UPDATE identidad.usuario u SET estado = 'inactivo'
     WHERE u.origen_auth = 'externo' AND u.emisor_externo = 'supabase-auth'
       AND u.sujeto_externo = OLD.id::text AND u.estado <> 'inactivo';
    RETURN OLD;
  END IF;
  -- Los usuarios anónimos de Supabase son visitantes: no tienen cuenta en el modelo (RF-01, RF-06).
  IF coalesce(NEW.is_anonymous, false) THEN RETURN NEW; END IF;

  v_correo := lower(btrim(NEW.email));
  v_bloqueado := NEW.deleted_at IS NOT NULL OR (NEW.banned_until IS NOT NULL AND NEW.banned_until > clock_timestamp());
  SELECT * INTO v_usuario FROM identidad.usuario u
   WHERE u.origen_auth = 'externo' AND u.emisor_externo = 'supabase-auth' AND u.sujeto_externo = NEW.id::text;

  IF NOT FOUND THEN
    IF nullif(v_correo, '') IS NULL THEN
      RAISE EXCEPTION 'Systemic Tech requiere correo electrónico para crear una cuenta' USING ERRCODE = '23514';
    END IF;
    v_meta := coalesce(NEW.raw_user_meta_data, '{}'::jsonb);
    v_nombres := nullif(btrim(coalesce(v_meta->>'nombres', v_meta->>'given_name', v_meta->>'first_name',
                                       v_meta->>'full_name', v_meta->>'name')), '');
    v_apellidos := nullif(btrim(coalesce(v_meta->>'apellidos', v_meta->>'family_name', v_meta->>'last_name')), '');
    IF v_nombres IS NULL THEN v_nombres := split_part(v_correo, '@', 1); END IF;
    v_telefono := nullif(btrim(coalesce(NEW.phone, v_meta->>'telefono')), '');
    -- Igual que identidad.registrar_usuario: persona nueva, cuenta y perfil comercial de cliente.
    -- Una compra previa como invitado con el mismo correo NO se vincula automáticamente.
    INSERT INTO identidad.persona(nombres, apellidos, correo_contacto, telefono)
    VALUES (v_nombres, v_apellidos, v_correo, v_telefono) RETURNING id INTO v_persona;
    INSERT INTO identidad.usuario(persona_id, correo_acceso, estado, origen_auth, emisor_externo, sujeto_externo, verificado_en)
    VALUES (v_persona, v_correo,
            CASE WHEN v_bloqueado THEN 'bloqueado' WHEN NEW.email_confirmed_at IS NOT NULL THEN 'activo' ELSE 'pendiente' END,
            'externo', 'supabase-auth', NEW.id::text,
            CASE WHEN NEW.email_confirmed_at IS NOT NULL THEN least(NEW.email_confirmed_at, clock_timestamp()) END);
    INSERT INTO identidad.cliente(persona_id, codigo) VALUES (v_persona, 'CLI-' || gen_random_uuid());
    RETURN NEW;
  END IF;

  -- Cambio de correo ya verificado por Supabase Auth.
  IF nullif(v_correo, '') IS NOT NULL AND v_correo IS DISTINCT FROM v_usuario.correo_acceso THEN
    UPDATE identidad.usuario u SET correo_acceso = v_correo WHERE u.id = v_usuario.id;
  END IF;
  IF v_bloqueado AND v_usuario.estado IN ('activo', 'pendiente') THEN
    UPDATE identidad.usuario u SET estado = 'bloqueado' WHERE u.id = v_usuario.id;
  ELSIF NOT v_bloqueado AND v_usuario.estado = 'pendiente' AND NEW.email_confirmed_at IS NOT NULL THEN
    UPDATE identidad.usuario u SET estado = 'activo', verificado_en = least(NEW.email_confirmed_at, clock_timestamp())
     WHERE u.id = v_usuario.id;
  END IF;
  -- El desbloqueo NO es automático: lo decide el personal autorizado (RF-32) con
  -- identidad.administrar_registro('usuario', '{"estado":"activo"}', id).
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION identidad.sincronizar_usuario_supabase() FROM PUBLIC;

-- Contexto de identidad para el backend. Debe llamarse al inicio de cada transacción con el `sub`
-- del JWT YA VERIFICADO por el backend (supabase.auth.getUser() o verificación JWKS).
-- Devuelve el usuario_id del modelo, o NULL si la cuenta no existe, está pendiente o bloqueada:
-- en ese caso las consultas quedan sin identidad (falla cerrado) y el backend debe responder 401/403.
CREATE FUNCTION identidad.iniciar_contexto_supabase(p_sujeto uuid, p_correlacion uuid DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_usuario bigint;
BEGIN
  IF NOT identidad.es_dba() AND NOT pg_has_role(session_user, 'st_app', 'MEMBER') THEN
    RAISE EXCEPTION 'Solo el backend de la aplicación fija el contexto de identidad' USING ERRCODE = '42501';
  END IF;
  IF p_sujeto IS NULL THEN RAISE EXCEPTION 'Sujeto de autenticación obligatorio' USING ERRCODE = '22004'; END IF;
  SELECT u.id INTO v_usuario FROM identidad.usuario u JOIN identidad.persona p ON p.id = u.persona_id
   WHERE u.origen_auth = 'externo' AND u.emisor_externo = 'supabase-auth' AND u.sujeto_externo = p_sujeto::text
     AND u.estado = 'activo' AND p.activo;
  PERFORM set_config('app.usuario_id', coalesce(v_usuario::text, ''), true);
  PERFORM set_config('app.invitado_token', '', true);
  PERFORM set_config('app.correlacion_id', coalesce(p_correlacion, gen_random_uuid())::text, true);
  RETURN v_usuario;
END $$;
REVOKE ALL ON FUNCTION identidad.iniciar_contexto_supabase(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION identidad.iniciar_contexto_supabase(uuid, uuid) TO st_app;

-- Con Supabase Auth no hay contraseñas, sesiones ni recuperación propias: se retira su ejecución.
-- Las tablas se conservan (modelo aprobado de 62 tablas) y deben permanecer vacías.
REVOKE EXECUTE ON PROCEDURE identidad.registrar_usuario(text,text,text,text,text,text,text,text,bigint) FROM st_app;
REVOKE EXECUTE ON PROCEDURE identidad.registrar_sesion(bigint,bytea,timestamp with time zone,bigint) FROM st_app;
REVOKE EXECUTE ON PROCEDURE identidad.cerrar_sesion(bigint) FROM st_app;
REVOKE EXECUTE ON PROCEDURE identidad.preparar_recuperacion(bigint,bytea,timestamp with time zone,bigint) FROM st_worker;
REVOKE EXECUTE ON PROCEDURE identidad.consumir_recuperacion(text,text) FROM st_worker;
REVOKE EXECUTE ON PROCEDURE identidad.confirmar_correo(bigint) FROM st_worker;
REVOKE EXECUTE ON FUNCTION identidad.datos_autenticacion(text) FROM st_worker;
REVOKE EXECUTE ON FUNCTION identidad.estado_sesion(bigint,bytea) FROM st_worker;

RESET search_path;
RESET ROLE;

-- Triggers sobre auth.users (los crea postgres, que tiene TRIGGER sobre auth.users en Supabase).
CREATE TRIGGER st_sincronizar_alta AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION identidad.sincronizar_usuario_supabase();
CREATE TRIGGER st_sincronizar_cambio AFTER UPDATE ON auth.users
  FOR EACH ROW WHEN (OLD.email IS DISTINCT FROM NEW.email
                  OR OLD.email_confirmed_at IS DISTINCT FROM NEW.email_confirmed_at
                  OR OLD.banned_until IS DISTINCT FROM NEW.banned_until
                  OR OLD.deleted_at IS DISTINCT FROM NEW.deleted_at
                  OR OLD.is_anonymous IS DISTINCT FROM NEW.is_anonymous)
  EXECUTE FUNCTION identidad.sincronizar_usuario_supabase();
CREATE TRIGGER st_sincronizar_baja AFTER DELETE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION identidad.sincronizar_usuario_supabase();

-- Cierre explícito de la API pública de Supabase sobre los 7 esquemas (defensa en profundidad:
-- hoy no tienen privilegios; esto impide que un GRANT accidental futuro pase desapercibido).
DO $cierre$
DECLARE e text;
BEGIN
  FOREACH e IN ARRAY ARRAY['identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria'] LOOP
    EXECUTE format('REVOKE ALL ON SCHEMA %I FROM anon, authenticated, service_role', e);
    EXECUTE format('REVOKE ALL ON ALL TABLES IN SCHEMA %I FROM anon, authenticated, service_role', e);
    EXECUTE format('REVOKE ALL ON ALL SEQUENCES IN SCHEMA %I FROM anon, authenticated, service_role', e);
    EXECUTE format('REVOKE ALL ON ALL ROUTINES IN SCHEMA %I FROM anon, authenticated, service_role', e);
  END LOOP;
END
$cierre$;

-- Comprobación inmediata: la migración falla si algo quedó expuesto.
DO $verificar$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace n CROSS JOIN (VALUES ('anon'),('authenticated'),('service_role')) r(rol)
             WHERE n.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria')
               AND has_schema_privilege(r.rol, n.oid, 'USAGE')) THEN
    RAISE EXCEPTION 'Un rol de la API de Supabase tiene USAGE sobre un esquema interno';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             CROSS JOIN (VALUES ('anon'),('authenticated')) r(rol)
             WHERE n.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria')
               AND has_function_privilege(r.rol, p.oid, 'EXECUTE')) THEN
    -- Son las consultas públicas que el diseño concede a PUBLIC (catálogo, carrito por token, horarios).
    -- Sin USAGE sobre el esquema, anon/authenticated no pueden invocarlas; se informa para revisión.
    RAISE NOTICE 'Rutinas con EXECUTE para PUBLIC (no invocables desde la API sin USAGE): %',
      (SELECT string_agg(p.oid::regprocedure::text, ', ' ORDER BY 1) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria')
          AND has_function_privilege('anon', p.oid, 'EXECUTE'));
  END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'auth.users'::regclass AND tgname LIKE 'st_sincronizar_%') <> 3 THEN
    RAISE EXCEPTION 'No se crearon los 3 triggers de sincronización sobre auth.users';
  END IF;
END
$verificar$;
