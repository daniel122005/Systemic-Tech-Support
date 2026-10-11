# Corrección 06 — pruebas ejecutadas, datos demo completos y preparación para Supabase (2026-10-09)

## Evidencia y alcance

Claude no tiene acceso a tu servidor. Instaló **PostgreSQL 18.3** (la misma versión de tu consola) y **PostgreSQL 17.6** en su espacio de trabajo y ejecutó ahí los scripts. Por eso este documento distingue entre:

- **Preparado:** el archivo existe y está revisado.
- **Ejecutado en réplica:** corrió en las bases de Claude, con su salida registrada en `evidencia/`.
- **Ejecutado/verificado en tu servidor o en Supabase:** pendiente; lo confirman los pasos L1–L3 y S2–S6 de `PROCEDIMIENTO_MIGRACION.md`.

## 1. Error de `proyectos.proteger_datos()` (corrección 05): diagnóstico confirmado

- Se reprodujo en la réplica el estado descrito: estructura confirmada, tablas vacías y la función con la condición mezclada. El mensaje fue idéntico: `record "new" has no field "cliente_id"`, al insertar en `proyectos.proyecto`.
- **Relación correcta:** `proyecto.solicitud_desarrollo_id → solicitud_desarrollo.cliente_id`. El proyecto no tiene `cliente_id` y no debe tenerlo: el cliente se deriva de la solicitud, y el trigger impide cambiar el origen (`solicitud_desarrollo_id` inmutable) y la titularidad de una solicitud ya aprobada.
- El parche 05 solo anida las condiciones (primero la tabla, luego el evento, luego el campo). No cambia ninguna regla. Su cuerpo es idéntico al de `30_servicios.sql`.
- `retomar_datos_psql.sql` (sin cambios) **se ejecutó en la réplica sobre ese estado**: aplicó los parches 03–05, cargó los datos y pasó `80_verificacion.sql`. El catálogo resultante es **idéntico** al de una instalación nueva (tablas, columnas, 1.095 restricciones, índices, 136 rutinas, triggers, 62 políticas y ACL).

## 2. Defectos de las pruebas (no de la base)

| Archivo | Problema | Corrección | ¿Se debilitó alguna regla? |
|---|---|---|---|
| `82_pruebas_servicios.sql` (P04) | Esperaba `23503`. Una FK `ON DELETE RESTRICT` devuelve `23001` en PostgreSQL 18 y `23503` en 17. | El asistente `rechaza` acepta alternativas (`'23001\|23503'`). | No: la etapa con avances sigue sin poder borrarse. |
| `82_pruebas_servicios.sql` (P08) | `WHERE id=usuario`: la variable PL/pgSQL `usuario` choca con el nombre de la tabla (`42702`). | Alias de tabla: `UPDATE identidad.usuario u … WHERE u.id=usuario`. | No. |
| `82_pruebas_comunicacion.sql` (T40-09 a T40-11) | El mismo choque con `archivo`. | Alias `a`. | No. |
| `82_pruebas_comunicacion.sql` (preparación de T40-25) | Adjuntaba un archivo `interno` a un **mensaje**, algo que el diseño aprobado prohíbe (`ck_adjunto_mensaje_compartido`, documentado en `decisiones_fisicas.md`). | Ahora se comprueba el **rechazo** (nuevo T40-12b). T40-25 sigue verificando que otro participante no obtiene ese archivo. | No: se añadió una aserción. |

## 3. Datos demo completos

- **Nuevo `71_datos_demo_complemento.sql`**: imagen pública de producto, documento adjunto al proyecto, comprobante de factura, entrega de notificación (`pendiente → enviando → enviada → entregada`) y concesión de invitado para consultar su pedido. Solo usa procedimientos.
  - En la primera versión, la regla T12 rechazó saltar de `enviando` a `entregada`. Se corrigió el **dato**, no la regla.
  - Restablece `SET CONSTRAINTS ALL DEFERRED` al empezar: si se ejecuta en la misma transacción que 70 (como en `seed.sql` de Supabase), 70 deja las restricciones en modo inmediato.
- **Nuevo `completar_datos_psql.sql`**: ejecuta 71 en una transacción y repite la verificación básica. Se detiene sin cambios si ya se cargó.
- Tras 70 + 71, solo quedan vacías `identidad.credencial`, `sesion` y `recuperacion_acceso`, como corresponde con Supabase Auth.

## 4. Pruebas nuevas

- **`87_pruebas_rf.sql` (R01–R30):** recorridos por requerimiento con la identidad real `st_app`, desde tres perspectivas: visitante, cliente registrado y personal administrador. Se añadió a `probar_psql.sql` y necesita 70 + 71.
- **`supabase/pruebas/86_pruebas_supabase_auth.sql` (SB01–SB16):** integración con Supabase Auth, aislamiento por RLS y ausencia de acceso de `anon`, `authenticated` y `service_role`.

## 5. Archivos

| Estado | Archivos |
|---|---|
| Modificados | `82_pruebas_servicios.sql`, `82_pruebas_comunicacion.sql`, `probar_psql.sql`, `README.md` (sección inicial), `estado_ejecucion.json`, `matriz_rf_01_42.md` (v2), `sha256.json` |
| Nuevos | `71_datos_demo_complemento.sql`, `completar_datos_psql.sql`, `87_pruebas_rf.sql`, `catalogo_detallado.sql`, `correccion_06.md`, `matriz_rf_01_42_v1.md` (copia de la matriz anterior) |
| Sin cambios | La estructura y la lógica (`01`–`65`, `estructura_y_logica.sql`, `TODO_EN_UNO_PSQL.sql`), los parches 03–05, `retomar_datos_psql.sql`, `70_datos_demo.sql`, `80_verificacion.sql` y las pruebas 83–85 |

**No se modificó ningún objeto de la base local.** Los cambios son de pruebas y datos ficticios.
