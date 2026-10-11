# Informe de estado — Base de datos Systemic Tech & Support (2026-10-09)

**Alcance de la evidencia.** No tuve acceso a tu PostgreSQL ni a tu proyecto Supabase. Instalé **PostgreSQL 18.3** (la versión de tu consola) y **PostgreSQL 17.6** en mi espacio de trabajo y ejecuté ahí tus scripts. Sobre 17.6 reproduje las condiciones de permisos de Supabase, tomadas de su código fuente: `postgres` sin superusuario, base de otro dueño, esquemas `extensions` y `auth`, roles `anon`, `authenticated`, `service_role` y `supabase_auth_admin`. Las salidas están en `evidencia/`.

## Tabla de estado

| Elemento | Preparado | Ejecutado en réplica | Verificado en réplica | Tu servidor / tu Supabase |
|---|---|---|---|---|
| Diagnóstico del error de `proyectos.proteger_datos()` | Sí | Sí (error reproducido idéntico) | Sí | — |
| Parche 05 | Sí (sin cambios) | Sí, vía `retomar_datos_psql.sql` | Sí: catálogo idéntico a una instalación nueva | **Pendiente (L1)** |
| Carga demo 70 | Sí (sin cambios) | Sí | Sí (comprobaciones internas) | **Pendiente (L1)** |
| Complemento demo 71 | Nuevo | Sí (PG 18.3 y 17.6) | Sí | **Pendiente (L2)** |
| `80_verificacion.sql` | Sin cambios | Sí | Sí | **Pendiente (L1/L2)** |
| `probar_psql.sql` (111 casos) | 3 tests corregidos + R01–R30 nuevos | Sí | Sí, sin error | **Pendiente (L3)** |
| Migraciones Supabase (6) | Nuevas | Sí, como `postgres` sin superusuario, con y sin transacción | Sí | **Pendiente (S2/S3)** |
| `seed.sql` (datos ficticios) | Nuevo | Sí | Sí | Solo local o pruebas (S2) |
| Integración Supabase Auth | Nueva | Sí, con `auth.users` simulado | SB01–SB16 sin error | **Pendiente (S2)**: confirmar con la imagen oficial |
| Pruebas en Supabase (127 casos) | Nuevas/adaptadas | Sí | Sí, sin error | **Pendiente (S2)** |
| `verificacion_supabase.sql` | Nuevo | Sí (como una sola consulta múltiple, igual que el SQL Editor) | Sí | **Pendiente (S4)** |
| Prueba de humo `st_backend` | Nueva | Sí | Sí | **Pendiente (S6)**; la conexión de roles propios por el pooler no está comprobada |
| Ejemplo de backend (`postgres.js`) | Nuevo | Sí: catálogo, carrito de visitante y falla cerrada contra la simulación | Parcial: la verificación de JWT no se ejecutó | — |
| Matriz RF-01–RF-42 | v2 | — | 39 verificados en réplica, 2 parciales, 1 no verificable | Plataforma: 0/42 (no hay frontend/backend) |

---

## Etapa 1 — Auditoría

**A. Diagnóstico.**
- Están todos los archivos pedidos: `README.md`, `modelo_logico.md`, `estado_ejecucion.json`, `correccion_05.md`, `parche_05_trigger_proyectos.sql`, `retomar_datos_psql.sql`, `80_verificacion.sql` y `probar_psql.sql`.
- Las 47 huellas SHA-256 coinciden. `estructura_y_logica.sql` y `TODO_EN_UNO_PSQL.sql` son exactamente los módulos 01–65 sin sus `BEGIN`/`COMMIT`.
- Orden real: `00_roles` → base → `estructura_y_logica` (01–65 en una transacción) → `70` → `80`. Para tu estado: `retomar_datos_psql` (parches 03–05 → 70 → 80).
- El diagnóstico del error es correcto. El cliente del proyecto se obtiene por `proyecto.solicitud_desarrollo_id → solicitud_desarrollo.cliente_id`, y el defecto era una condición `ELSIF` que PostgreSQL evalúa entera, incluido `NEW.cliente_id`.
- **Riesgos de reejecución:** `instalar_psql.sql` y `TODO_EN_UNO` se detienen si la base o los roles existen. `retomar_datos_psql.sql` se detiene si alguna tabla tiene filas. `completar_datos_psql.sql` se detiene si el complemento ya existe. Los parches usan `CREATE OR REPLACE`, así que repetirlos no duplica nada.

**B–F.** Sin cambios en esta etapa.

## Etapa 2 — PostgreSQL local

**A. Diagnóstico.**
- `retomar_datos_psql.sql` funciona sobre tu estado reproducido.
- `probar_psql.sql` fallaba en 3 puntos, **todos defectos de las pruebas**: un código de error que cambió en PostgreSQL 18, dos nombres ambiguos entre variable y tabla, y un caso que contradecía `ck_adjunto_mensaje_compartido`.
- 9 tablas quedaban sin datos demo.

**B. Solución.** Se corrigieron las pruebas sin tocar ninguna restricción. Se añadió el complemento 71, que solo usa procedimientos. Al escribirlo, dos reglas rechazaron datos incorrectos (T12 y la validación diferida de concesiones) y se corrigieron los datos, no las reglas. Se añadió `87_pruebas_rf.sql` con evidencia por requerimiento.

**C. Archivos.** Ver `local_postgresql/correccion_06.md` §5.

**D. Ejecución.** Pasos L1–L3 de `supabase/PROCEDIMIENTO_MIGRACION.md`.

**E. Verificación.** Lo que debe aparecer al final:
- L1: `DATOS DE DEMOSTRACION Y VERIFICACION BASICA TERMINADOS`
- L2: `COMPLEMENTO DE DATOS Y VERIFICACION BASICA TERMINADOS`
- L3: `TODAS LAS PRUEBAS DEL PAQUETE TERMINARON SIN ERROR`

**F. Estado.** Corregido en archivos y verificado en réplica. **Ejecución en tu servidor: pendiente.**

## Etapa 3 — Migración a Supabase

**A. Diagnóstico.**
- Supabase documenta PostgreSQL 15/17. La base funciona en 17.6 sin cambios de lógica.
- Obligan a adaptar: el rol `postgres` sin superusuario, la base que no le pertenece, `pgcrypto` en `extensions`, PostgREST sin `CALL` y el riesgo de revocar privilegios de la base.

**B. Solución.**
- Seis migraciones versionadas: cuatro generadas desde tus módulos con 7 adaptaciones comprobadas, más la integración con Auth y el catálogo base.
- La semilla de datos ficticios va aparte.
- La comparación de catálogos documenta las únicas diferencias esperadas.

**C. Archivos.** `supabase/migrations/*`, `supabase/seed.sql`, `supabase/ADAPTACIONES_SUPABASE.md`, `supabase/PROCEDIMIENTO_MIGRACION.md`, `herramientas/generar_supabase.py`, `local_postgresql/catalogo_detallado.sql`.

**D. Ejecución.** Pasos S0–S3. Por CLI: `db reset` en local y `db push` a la nube. Alternativa: SQL Editor o psql, archivo por archivo.

**E. Verificación.** S2 debe mostrar `TODAS LAS PRUEBAS EN SUPABASE LOCAL TERMINARON SIN ERROR`; S4, `VERIFICACION SUPERADA`; S8, solo las diferencias de la tabla del procedimiento.

**F. Estado.** Preparado y verificado en simulación. **No desplegado en tu proyecto.**

## Etapa 4 — Seguridad

**A. Diagnóstico.** El diseño ya es de mínimo privilegio: RLS en las 62 tablas, `st_app` sin escritura directa, funciones `SECURITY DEFINER` con `search_path` fijo y contraseñas solo como hash. El riesgo en Supabase está en exponer esquemas a la API, usar `service_role` o mantener contraseñas propias.

**B. Solución.**
- Supabase Auth gestiona las cuentas, sincronizadas por trigger. La identidad se fija con `iniciar_contexto_supabase` y falla cerrada.
- Los 7 esquemas no se exponen. `anon`, `authenticated` y `service_role` quedan sin privilegios, con verificación incluida.
- Se retiran las 8 rutinas de contraseña local.
- La contraseña de `st_backend` se fija con `\password`, nunca en archivos ni en el SQL Editor.
- No se pidió ni se usó ningún secreto.

**E. Verificación.** SB07–SB13 y SB15 en réplica, y V08–V17 en `verificacion_supabase.sql`.

**F. Estado.** Verificado en simulación. **Pendiente en tu proyecto (S4, S6).**

## Etapa 5 — RF-01 a RF-42

Ver `local_postgresql/matriz_rf_01_42.md`. Base de datos: 39 verificados en réplica, 2 parciales (RF-03 inicio de sesión, RF-25 canales externos) y 1 no verificable (RF-04, recuperación de contraseña en Supabase Auth). **Plataforma completa: ninguno**, porque faltan frontend, backend, Storage, envíos de correo y pagos.

## Decisiones que necesitan tu confirmación

1. **Arquitectura de acceso:** backend propio con `st_backend` (recomendada y preparada) en lugar de exponer la API REST de Supabase. Exponer la API exigiría reescribir unas 70 operaciones como funciones y adaptar la identidad. Es posible, pero es otro proyecto.
2. **Versión de PostgreSQL en Supabase:** 17 (o superior si tu proyecto la ofrece).
3. **Cuentas solo con correo:** el registro únicamente por teléfono queda rechazado, porque el modelo exige `correo_acceso`.
