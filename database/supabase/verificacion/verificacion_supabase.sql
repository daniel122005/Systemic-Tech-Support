-- Systemic Tech & Support — verificación del despliegue en el proyecto Supabase (nube o local).
-- Compatible con el SQL Editor de Supabase (sin metacomandos de psql) y con psql.
-- Ejecutar como `postgres` después de aplicar las 6 migraciones. Solo lee el catálogo y llama a
-- validadores de integridad: no modifica datos. Si algo falla, el DO aborta con el motivo exacto.
DO $verificacion$
DECLARE n integer; e text;
BEGIN
  IF current_setting('server_version_num')::integer < 170000 THEN RAISE EXCEPTION 'V01: PostgreSQL < 17'; END IF;
  SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace
   WHERE c.relkind = 'r' AND s.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria');
  IF n <> 62 THEN RAISE EXCEPTION 'V02: se esperaban 62 tablas y hay %', n; END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace
             WHERE c.relkind = 'r' AND s.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria')
               AND NOT c.relrowsecurity) THEN RAISE EXCEPTION 'V03: hay tablas sin RLS'; END IF;
  SELECT count(*) INTO n FROM pg_policies WHERE schemaname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria');
  IF n <> 62 THEN RAISE EXCEPTION 'V04: se esperaban 62 políticas y hay %', n; END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace
             WHERE s.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria')
               AND c.relkind IN ('r','v','S') AND pg_get_userbyid(c.relowner) <> 'st_owner') THEN
    RAISE EXCEPTION 'V05: hay tablas, vistas o secuencias cuyo propietario no es st_owner';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace s ON s.oid = p.pronamespace
             WHERE s.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria')
               AND pg_get_userbyid(p.proowner) <> 'st_owner') THEN
    RAISE EXCEPTION 'V06: hay rutinas cuyo propietario no es st_owner (un SECURITY DEFINER de postgres saltaría RLS)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace s ON s.oid = p.pronamespace
             WHERE s.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria')
               AND p.prosecdef AND NOT coalesce(p.proconfig::text LIKE '%search_path=pg_catalog, pg_temp%'
                                              OR p.proconfig::text LIKE '%search_path=pg_catalog,pg_temp%', false)) THEN
    RAISE EXCEPTION 'V07: rutina SECURITY DEFINER sin search_path controlado';
  END IF;
  FOREACH e IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
    IF EXISTS (SELECT 1 FROM pg_namespace s WHERE s.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria')
               AND has_schema_privilege(e, s.oid, 'USAGE')) THEN
      RAISE EXCEPTION 'V08: el rol de API % tiene acceso a un esquema interno', e;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace
               WHERE s.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria')
                 AND c.relkind IN ('r','v') AND (has_table_privilege(e, c.oid, 'SELECT') OR has_table_privilege(e, c.oid, 'INSERT')
                      OR has_table_privilege(e, c.oid, 'UPDATE') OR has_table_privilege(e, c.oid, 'DELETE'))) THEN
      RAISE EXCEPTION 'V09: el rol de API % tiene privilegios sobre tablas internas', e;
    END IF;
  END LOOP;
  IF has_table_privilege('st_app','inventario.movimiento_inventario','INSERT')
     OR has_table_privilege('st_app','comercial.pedido','UPDATE')
     OR has_table_privilege('st_app','identidad.credencial','SELECT') THEN RAISE EXCEPTION 'V10: privilegios excesivos de st_app'; END IF;
  IF has_function_privilege('st_app','identidad.registrar_usuario(text,text,text,text,text,text,text,text,bigint)','EXECUTE')
     OR has_function_privilege('st_worker','identidad.datos_autenticacion(text)','EXECUTE') THEN
    RAISE EXCEPTION 'V11: las rutinas de contraseña local siguen habilitadas';
  END IF;
  IF NOT has_function_privilege('st_app','identidad.iniciar_contexto_supabase(uuid,uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'V12: st_app no puede fijar el contexto de identidad';
  END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'auth.users'::regclass AND tgname LIKE 'st_sincronizar_%') <> 3 THEN
    RAISE EXCEPTION 'V13: faltan triggers de sincronización en auth.users';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'btree_gist') THEN RAISE EXCEPTION 'V14: falta btree_gist'; END IF;
  IF EXISTS (SELECT 1 FROM identidad.credencial) OR EXISTS (SELECT 1 FROM identidad.sesion)
     OR EXISTS (SELECT 1 FROM identidad.recuperacion_acceso) THEN
    RAISE EXCEPTION 'V15: hay contraseñas/sesiones locales; con Supabase Auth deben estar vacías';
  END IF;
  IF (SELECT count(*) FROM identidad.rol WHERE codigo IN ('cliente','administrador','tecnico','desarrollador','administrativo')) <> 5
     OR (SELECT count(*) FROM identidad.permiso) < 58 THEN
    RAISE EXCEPTION 'V16: falta el catálogo base de roles y permisos';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname IN ('st_owner','st_dba','st_app','st_worker','st_lectura','st_administracion')
             AND (rolcanlogin OR rolsuper OR rolbypassrls)) THEN RAISE EXCEPTION 'V17: un rol de grupo puede iniciar sesión o saltar RLS'; END IF;
  PERFORM comercial.validar_integridad();
  PERFORM comunicacion.validar_integridad();
  RAISE NOTICE 'Verificación Supabase superada: V01-V17 e invariantes comercial/comunicación';
END
$verificacion$;

-- Resumen visible en el SQL Editor (última consulta del script).
SELECT 'tablas' AS elemento, count(*)::text AS valor FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace
 WHERE c.relkind = 'r' AND s.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria')
UNION ALL SELECT 'politicas_rls', count(*)::text FROM pg_policies
 WHERE schemaname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria')
UNION ALL SELECT 'rutinas', count(*)::text FROM pg_proc p JOIN pg_namespace s ON s.oid = p.pronamespace
 WHERE s.nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria')
UNION ALL SELECT 'roles_negocio', count(*)::text FROM identidad.rol
UNION ALL SELECT 'permisos', count(*)::text FROM identidad.permiso
UNION ALL SELECT 'cuentas_supabase', count(*)::text FROM identidad.usuario WHERE emisor_externo = 'supabase-auth'
UNION ALL SELECT 'personas', count(*)::text FROM identidad.persona
UNION ALL SELECT 'version', current_setting('server_version')
UNION ALL SELECT 'resultado', 'VERIFICACION SUPERADA';
