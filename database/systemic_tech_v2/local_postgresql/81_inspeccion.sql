-- Solo lectura. Se puede ejecutar desde psql o Query Tool de pgAdmin.
SELECT current_database() AS base, current_user AS usuario, version() AS version;
SELECT table_schema AS esquema, count(*) AS tablas
FROM information_schema.tables
WHERE table_type = 'BASE TABLE' AND table_schema IN ('identidad', 'inventario', 'comercial', 'servicios', 'proyectos', 'comunicacion', 'auditoria')
GROUP BY table_schema ORDER BY table_schema;

-- Atributos, nulabilidad, valor predeterminado, identidad y expresión generada.
SELECT table_schema, table_name, ordinal_position, column_name, data_type,
       udt_name, numeric_precision, numeric_scale, is_nullable, column_default,
       is_identity, identity_generation, is_generated, generation_expression
FROM information_schema.columns WHERE table_schema IN ('identidad', 'inventario', 'comercial', 'servicios', 'proyectos', 'comunicacion', 'auditoria')
ORDER BY table_schema, table_name, ordinal_position;

-- Restricciones reales, incluidas FK, CHECK, UNIQUE y EXCLUDE.
SELECT n.nspname AS esquema, c.relname AS tabla, k.conname AS restriccion,
       k.contype AS tipo, pg_get_constraintdef(k.oid, true) AS definicion
FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('identidad', 'inventario', 'comercial', 'servicios', 'proyectos', 'comunicacion', 'auditoria')
ORDER BY n.nspname, c.relname, k.conname;

SELECT schemaname, tablename, indexname, indexdef FROM pg_indexes
WHERE schemaname IN ('identidad', 'inventario', 'comercial', 'servicios', 'proyectos', 'comunicacion', 'auditoria') ORDER BY schemaname, tablename, indexname;

-- Incluye secuencias de identidad y las tres explícitas; no llama a nextval.
SELECT schemaname, sequencename, data_type, start_value, increment_by, cycle, cache_size
FROM pg_sequences WHERE schemaname IN ('identidad', 'inventario', 'comercial', 'servicios', 'proyectos', 'comunicacion', 'auditoria') ORDER BY schemaname, sequencename;

SELECT extname, extversion FROM pg_extension WHERE extname = 'btree_gist';
