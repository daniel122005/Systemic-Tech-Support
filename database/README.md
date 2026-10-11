# Base de datos — Systemic Tech & Support

PostgreSQL 17 en Supabase (proyecto `systemic-tech`). 62 tablas en 7 esquemas (`identidad`, `inventario`,
`comercial`, `servicios`, `proyectos`, `comunicacion`, `auditoria`), RLS en todas, auditoría, historiales
inmutables y procedimientos de negocio. **La fuente de verdad desplegada son las migraciones de `supabase/migrations/`.**

## Estructura

| Carpeta / archivo | Para qué |
|---|---|
| `supabase/migrations/` | Las 6 migraciones aplicadas en Supabase, en orden. |
| `supabase/subir_a_supabase.sql` | Aplica las 6 migraciones + verificación en un proyecto nuevo (producción limpia). |
| `supabase/seed.sql`, `supabase/cargar_datos_demo_supabase.sql` | Datos **ficticios**. Solo desarrollo/pruebas, nunca producción. |
| `supabase/verificacion/` | Verificación en el SQL Editor, prueba de humo de `st_backend` y alta del primer administrador. |
| `supabase/pruebas/` | Suite de pruebas para la pila local de Supabase (generada por `herramientas/generar_supabase.py`). |
| `supabase/PROCEDIMIENTO_MIGRACION.md` | Pasos exactos (local opcional y Supabase) con el resultado esperado de cada uno. |
| `supabase/ADAPTACIONES_SUPABASE.md` | Qué cambia frente a PostgreSQL local y por qué (Auth, roles, API REST cerrada). |
| `local_postgresql/` | Scripts fuente por módulo (`00`–`65`), datos ficticios (`70`, `71`), pruebas (`80`–`87`) e instalador local. |
| `local_postgresql/programacion_y_objetos.md`, `api_procedimientos.json` | Inventario de procedimientos y firmas que usa el backend. |
| `local_postgresql/modelo_*.md`, `diccionario_datos.md`, `der_final.mmd` | Modelo conceptual, lógico, diccionario y diagrama entidad-relación. |
| `local_postgresql/matriz_rf_01_42.md` | Cobertura de cada requerimiento RF-01 a RF-42. |
| `local_postgresql/decisiones_*.md` | Razonamiento de diseño y decisiones físicas. |
| `herramientas/` | Generador de migraciones, simulación de permisos de Supabase y huella del catálogo. |
| `evidencia/` | Salidas reales de las ejecuciones de prueba (local 18.3 y Supabase). |

## Reglas
- **No cambiar la estructura a mano** ni editar datos desde el Table Editor. Todo cambio va en una migración
  nueva (`supabase/migrations/AAAAMMDDHHMMSS_descripcion.sql`), revisada y probada antes de aplicarla.
- Las aplicaciones escriben solo con procedimientos (`CALL ...`) usando el usuario limitado `st_backend`.
- Nunca guardar contraseñas en estos archivos: los usuarios `st_*` se crean sin contraseña y se configura con `\password`.

## PostgreSQL local (opcional)
En SQL Shell (usuario `postgres`, PostgreSQL 18):
```psql
\i 'C:/ruta/a/systemic-tech/database/local_postgresql/instalar_psql.sql'
\i 'C:/ruta/a/systemic-tech/database/local_postgresql/probar_psql.sql'
```
Deben terminar en `INSTALACION Y VERIFICACION BASICA TERMINADAS` y `TODAS LAS PRUEBAS DEL PAQUETE TERMINARON SIN ERROR`.
El instalador se detiene sin tocar nada si la base o los roles ya existen.
