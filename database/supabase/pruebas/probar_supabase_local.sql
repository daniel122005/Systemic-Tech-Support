\set ON_ERROR_STOP on
-- Suite completa en la pila LOCAL de Supabase (supabase start + supabase db reset).
-- Conectar como supabase_admin: las pruebas usan SET SESSION AUTHORIZATION (requiere superusuario).
-- En el proyecto en la nube no hay superusuario: allí se usa verificacion_supabase.sql.
\ir 80_verificacion.sql
\ir 83_pruebas_comercial.sql
\ir 82_pruebas_servicios.sql
\ir 82_pruebas_comunicacion.sql
\ir 84_pruebas_acceso.sql
\ir 85_pruebas_cotizacion_contacto.sql
\ir 87_pruebas_rf.sql
\ir 86_pruebas_supabase_auth.sql
\echo TODAS LAS PRUEBAS EN SUPABASE LOCAL TERMINARON SIN ERROR
