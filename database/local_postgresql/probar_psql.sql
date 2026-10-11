\set ON_ERROR_STOP on
\connect systemic_tech_db
\ir 80_verificacion.sql
\ir 83_pruebas_comercial.sql
\ir 82_pruebas_servicios.sql
\ir 82_pruebas_comunicacion.sql
\ir 84_pruebas_acceso.sql
\ir 85_pruebas_cotizacion_contacto.sql
\ir 87_pruebas_rf.sql
\echo TODAS LAS PRUEBAS DEL PAQUETE TERMINARON SIN ERROR
