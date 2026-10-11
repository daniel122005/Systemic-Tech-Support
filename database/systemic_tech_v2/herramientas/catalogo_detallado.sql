-- Listado por objeto (sin md5 agregados) para comparar dos entornos con diff.
-- Ejecutar con: psql -X -At -F'|' -f catalogo_detallado.sql > salida.txt
WITH s AS (SELECT oid,nspname FROM pg_namespace WHERE nspname IN ('identidad','inventario','comercial','servicios','proyectos','comunicacion','auditoria'))
SELECT 'tabla', s.nspname||'.'||c.relname, c.relkind::text||' rls='||c.relrowsecurity::text||' cols='||(SELECT count(*) FROM pg_attribute a WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped)||' owner='||pg_get_userbyid(c.relowner)
FROM pg_class c JOIN s ON s.oid=c.relnamespace WHERE c.relkind IN ('r','v','m','S')
UNION ALL SELECT 'columna', s.nspname||'.'||c.relname||'.'||a.attname, format_type(a.atttypid,a.atttypmod)||' notnull='||a.attnotnull::text||' def='||coalesce(pg_get_expr(d.adbin,d.adrelid),'')
FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN s ON s.oid=c.relnamespace LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attnum>0 AND NOT a.attisdropped AND c.relkind='r'
UNION ALL SELECT 'restriccion', s.nspname||'.'||o.conname, pg_get_constraintdef(o.oid) FROM pg_constraint o JOIN s ON s.oid=o.connamespace
UNION ALL SELECT 'indice', s.nspname||'.'||c.relname, pg_get_indexdef(c.oid) FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid JOIN s ON s.oid=c.relnamespace
UNION ALL SELECT 'rutina', p.oid::regprocedure::text, 'owner='||pg_get_userbyid(p.proowner)||' secdef='||p.prosecdef::text||' acl='||coalesce(p.proacl::text,'')||' md5='||md5(replace(pg_get_functiondef(p.oid),chr(13),'')) FROM pg_proc p JOIN s ON s.oid=p.pronamespace
UNION ALL SELECT 'trigger', s.nspname||'.'||c.relname||'.'||t.tgname, pg_get_triggerdef(t.oid) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN s ON s.oid=c.relnamespace WHERE NOT t.tgisinternal
UNION ALL SELECT 'politica', schemaname||'.'||tablename||'.'||policyname, cmd||' '||array_to_string(roles,',')||' '||coalesce(qual,'')||' '||coalesce(with_check,'') FROM pg_policies WHERE schemaname IN (SELECT nspname FROM s)
UNION ALL SELECT 'acl_tabla', s.nspname||'.'||c.relname, coalesce(c.relacl::text,'') FROM pg_class c JOIN s ON s.oid=c.relnamespace WHERE c.relkind IN ('r','v','S')
UNION ALL SELECT 'esquema', nspname, 'owner='||pg_get_userbyid(nspowner)||' acl='||coalesce(nspacl::text,'') FROM pg_namespace WHERE nspname IN (SELECT nspname FROM s)
UNION ALL SELECT 'extension', extname, extnamespace::regnamespace::text FROM pg_extension WHERE extname IN ('btree_gist','pgcrypto')
ORDER BY 1,2;
