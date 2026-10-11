# Contexto detallado — Systemic Tech & Support

## Historia del trabajo hecho
1. **Modelo y scripts de base de datos** (fases previas): modelo conceptual, lógico, diccionario de datos y DER de 62 tablas; scripts para PostgreSQL 18.
2. **Corrección y pruebas (2026-10-09):** se corrigió el error del trigger `proyectos.proteger_datos()` (parche 05), se completaron los datos ficticios y se ejecutó la suite de pruebas: **111 casos sin error en el PostgreSQL local del equipo**.
3. **Migración a Supabase:** 6 migraciones adaptadas (Supabase no da superusuario; PostgREST no ejecuta procedimientos). Integración con Supabase Auth por trigger. Desplegado en el proyecto `systemic-tech` con verificación superada (62 tablas, 62 políticas RLS, 138 rutinas, 5 roles, 58 permisos). Datos ficticios cargados (proyecto de desarrollo). Contraseña de `st_backend` creada.
4. **Backend inicial** Node.js + Express: catálogo, carrito y compra, área del cliente; 37 comprobaciones de punta a punta contra una réplica de Supabase.

## Roles de negocio (tabla identidad.rol)
`cliente`, `administrador`, `tecnico`, `desarrollador`, `administrativo`. Permisos por recurso y acción (`leer`, `gestionar`, `editar`, `responder`, `calificar`). El primer administrador se asigna con `database/systemic_tech_v2/supabase/verificacion/bootstrap_administrador.sql`.

## Requerimientos funcionales
- Acceso: RF-01 acceso público · RF-02 registro opcional · RF-03 login/logout · RF-04 recuperar contraseña · RF-05 perfil · RF-06 control de acceso.
- Productos y ventas: RF-07 consulta · RF-08 búsqueda/filtros · RF-09 carrito · RF-10 compra · RF-11 estado de pedidos · RF-12 historial de compras.
- Servicios técnicos: RF-13 consulta · RF-14 solicitar reparación · RF-15 solicitar mantenimiento · RF-16 agendar fecha · RF-17 estado de reparación · RF-18 historial de servicios.
- Cotizaciones: RF-19 solicitar sin cuenta · RF-20 consultar · RF-21 aceptar/rechazar.
- Desarrollo de software: RF-22 solicitar proyecto · RF-23 seguimiento · RF-24 información del proyecto.
- Comunicación: RF-25 contacto · RF-26 mensajería · RF-27 archivos · RF-28 notificaciones.
- Facturación: RF-29 facturas · RF-30 calificar servicios · RF-31 historial general.
- Administración: RF-32 usuarios · RF-33 productos · RF-34 inventario · RF-35 pedidos · RF-36 reparaciones · RF-37 mantenimientos · RF-38 cotizaciones · RF-39 proyectos · RF-40 clientes · RF-41 solicitudes · RF-42 roles y permisos.

Cobertura de la base por requerimiento: `database/systemic_tech_v2/local_postgresql/matriz_rf_01_42.md`.

## Rutas del backend ya hechas
Ver `systemic-backend/README.md`. Resumen: `/api/salud`, `/api/productos`, `/api/productos/:id`, `/api/categorias`, `/api/servicios`, `/api/horarios`, `/api/carrito` (+ `/items`, `/comprar`), `/api/cuenta/yo|pedidos|cotizaciones|proyectos|facturas|historial|notificaciones`.

## Pendientes conocidos
- Rutas de: solicitar reparación/mantenimiento y agendar, solicitar cotización, solicitar desarrollo, mensajes, archivos, panel administrativo, notificaciones por correo.
- Supabase Storage: bucket público `catalogo` (imágenes de productos) y privado `adjuntos` (documentos, comprobantes).
- Regla fiscal (IVA) y pagos: no definidos todavía (la compra usa tasa 0 y moneda COP).
- Plan de producción: proyecto Supabase Pro separado, sin datos ficticios.
