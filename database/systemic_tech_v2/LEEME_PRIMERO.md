# Systemic Tech & Support — paquete de continuación (2026-10-09)

## Qué hacer ahora

1. Copia el **contenido** de `local_postgresql/` dentro de tu carpeta actual `…/outputs/systemic_tech_completo/` y acepta reemplazar. Solo cambian pruebas, documentación y datos ficticios: la estructura y los parches son los mismos.
2. En SQL Shell (usuario postgres), en este orden:
   ```psql
   \i 'C:/Users/danie/Documents/Codex/2026-09-12/quiero-que-act-es-como-un-2/outputs/systemic_tech_completo/retomar_datos_psql.sql'
   \i 'C:/Users/danie/Documents/Codex/2026-09-12/quiero-que-act-es-como-un-2/outputs/systemic_tech_completo/completar_datos_psql.sql'
   \i 'C:/Users/danie/Documents/Codex/2026-09-12/quiero-que-act-es-como-un-2/outputs/systemic_tech_completo/probar_psql.sql'
   ```
   La última línea de cada uno debe ser, respectivamente: `DATOS DE DEMOSTRACION Y VERIFICACION BASICA TERMINADOS`, `COMPLEMENTO DE DATOS Y VERIFICACION BASICA TERMINADOS` y `TODAS LAS PRUEBAS DEL PAQUETE TERMINARON SIN ERROR`. Si aparece un `ERROR`, ejecuta `ROLLBACK;` y envíame la primera línea `ERROR` con su `CONTEXT`. No borres nada.
3. Para Supabase, sigue `supabase/PROCEDIMIENTO_MIGRACION.md` desde el paso S0.

## Contenido

| Carpeta / archivo | Para qué |
|---|---|
| `INFORME_ESTADO.md` | Qué está preparado, qué se ejecutó (en réplica) y qué falta verificar en tus entornos. |
| `local_postgresql/` | Tu paquete local con las correcciones de pruebas, los datos demo completos (`71`), las pruebas por requerimiento (`87`), la matriz RF v2 y `correccion_06.md`. |
| `supabase/migrations/` | 6 migraciones versionadas para Supabase CLI (o el SQL Editor, en orden). |
| `supabase/seed.sql` | Datos ficticios: solo para local o pruebas (`supabase db reset`). Nunca en producción. |
| `supabase/pruebas/` | Suite completa para la pila local de Supabase (127 casos). |
| `supabase/verificacion/` | Verificación para el SQL Editor, prueba de humo del backend y alta del primer administrador. |
| `supabase/ADAPTACIONES_SUPABASE.md` | Qué cambia respecto a local y por qué. |
| `supabase/PROCEDIMIENTO_MIGRACION.md` | Comandos exactos y resultados esperados, paso a paso. |
| `supabase/ejemplo_backend/` | Cómo debe conectarse el backend: identidad por transacción, sin `service_role`. |
| `herramientas/` | Generador de migraciones (`generar_supabase.py`) y la simulación de permisos de Supabase usada para las pruebas. |
| `evidencia/` | Salidas reales de las ejecuciones en las réplicas de Claude. |
