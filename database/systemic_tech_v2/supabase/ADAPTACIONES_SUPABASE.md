# Adaptaciones para Supabase — Systemic Tech & Support

Este documento explica **qué cambia** entre la instalación local (PostgreSQL 18.3) y el despliegue en Supabase, y **por qué**. El modelo lógico, las 62 tablas, las restricciones, los triggers, las 62 políticas RLS y los procedimientos **no cambian**: Supabase es PostgreSQL, y la base se instala con los mismos módulos.

Fuentes verificadas: el código de inicialización de Supabase (`supabase/postgres`, `migrations/db/init-scripts` y `migrations/10000000000000_demote-postgres.sql`) y la documentación de PostgREST, que dice textualmente: *"Stored Procedures are not supported"*.

## 1. Hechos de Supabase que obligan a adaptar

| Hecho en Supabase | Consecuencia para este proyecto |
|---|---|
| El rol `postgres` es `NOSUPERUSER CREATEDB CREATEROLE BYPASSRLS` | Los scripts no pueden exigir superusuario. Las pruebas que usan `SET SESSION AUTHORIZATION` solo se ejecutan en la pila local de Supabase (`supabase start`), conectando como `supabase_admin`. |
| La base se llama `postgres`, pertenece a `supabase_admin` y `postgres` la tiene sin GRANT OPTION | `st_owner` no puede recibir `CREATE` sobre la base, así que no puede crear esquemas. Los 7 esquemas los crea `postgres` y se le concede `USAGE, CREATE … WITH GRANT OPTION` a `st_owner`. **Tablas, funciones, triggers, vistas y políticas siguen perteneciendo a `st_owner`.** |
| `pgcrypto` ya está instalado en el esquema `extensions` | Las 5 funciones que usaban `public.digest(x,'sha256')` pasan a usar `pg_catalog.sha256(convert_to(x,'UTF8'))`. En una base UTF8 el resultado es el mismo (32 bytes), y deja de depender de `pgcrypto`. |
| Las extensiones van en el esquema `extensions` | `btree_gist` se instala allí. Las restricciones `EXCLUDE` usan la clase de operadores por defecto, que PostgreSQL encuentra sin permisos sobre el esquema. |
| Supabase ofrece PostgreSQL 15 y 17 (la documentación no menciona 18) | La versión mínima baja a 17. Toda la base y los 127 casos de prueba pasaron en 17.6. El único cambio de comportamiento entre versiones es el código de error de una FK `RESTRICT` (`23503` en 17, `23001` en 18), y la prueba P04 acepta los dos. |
| PostgREST (la API REST de Supabase) **no invoca procedimientos** (`CALL`) | Casi toda la API del modelo son procedimientos. Además, la identidad del modelo se basa en `session_user` (el rol de la conexión) y en `app.usuario_id`. **La plataforma usa un backend propio que se conecta con `st_backend`**, exactamente como en el diseño local. Los 7 esquemas **no** se exponen en la API de Supabase. |
| `anon`, `authenticated` y `service_role` (este último con `BYPASSRLS`) existen en todo proyecto | No reciben ningún privilegio sobre los 7 esquemas. La migración 5 los revoca explícitamente y falla si alguno quedara expuesto. |
| Revocar privilegios de `PUBLIC` sobre la base `postgres` rompería roles internos (`authenticator`, `supabase_auth_admin`, …) | Se omiten `REVOKE ALL ON DATABASE …`, `GRANT CONNECT ON DATABASE …` y `REVOKE CREATE ON SCHEMA public …` (adaptación A7). |

## 2. Lista exacta de adaptaciones (las aplica `herramientas/generar_supabase.py`)

| Código | Adaptación | Archivos afectados |
|---|---|---|
| A1 | Se eliminan `BEGIN`/`COMMIT` de los módulos: el CLI y el SQL Editor gestionan la transacción. Se probó con una transacción por archivo y también sin ella (autocommit). | todas las migraciones |
| A2 | `SET LOCAL …` pasa a `SET …` con su `RESET` al final del archivo. | 0200, 0300, 0400 |
| A3 | Versión mínima 17. La base debe llamarse `postgres`. | precondiciones |
| A4 | Esquemas, comentarios de esquema y extensiones los crea `postgres`. El resto lo crea `st_owner` mediante `SET ROLE st_owner`. | 0200 |
| A5 | `btree_gist` se instala en `extensions`. | 0200 |
| A6 | `public.digest(x,'sha256')` pasa a `pg_catalog.sha256(convert_to(x,'UTF8'))` en 5 funciones: `acceso_invitado_actual`, `emitir_acceso_invitado`, `consumir_recuperacion`, `exigir_carrito` y `crear_carrito`. | 0300 |
| A7 | Se omiten 3 sentencias sobre la base de datos y el esquema `public`. | 0400 |
| — | Pruebas: `public.gen_random_bytes` pasa a `extensions.gen_random_bytes`. | `pruebas/` |

El generador comprueba cada sustitución: si un texto esperado no aparece exactamente las veces previstas, se detiene. Si en el futuro modifican un módulo local, regeneren las migraciones; no las editen a mano.

## 3. Integración con Supabase Auth (migración 5, escrita a mano)

El modelo ya admitía cuentas externas: `usuario.origen_auth = 'externo'` con `(emisor_externo, sujeto_externo)` único. Se usan así:

- `emisor_externo = 'supabase-auth'` y `sujeto_externo = auth.users.id`.
- **Alta** (trigger `AFTER INSERT` sobre `auth.users`). Crea `persona`, `usuario` y `cliente`, igual que `identidad.registrar_usuario`. Toma el nombre de los metadatos (`nombres`/`apellidos`, o `given_name`/`family_name`, o `full_name`/`name`); si no vienen, usa la parte local del correo. Si el correo ya está confirmado, el estado es `activo`; si no, `pendiente`.
- **Usuarios anónimos de Supabase**: no crean cuenta en el modelo, se tratan como visitantes.
- **Sin correo**: el alta se rechaza (`23514`) y Supabase Auth devuelve el error. El modelo exige `correo_acceso`.
- **Cambios** (trigger `AFTER UPDATE` con condición `WHEN`): confirmación de correo (`pendiente` → `activo`), cambio de correo y bloqueo (`banned_until`) o borrado lógico (pasan a `bloqueado`). Un inicio de sesión **no** dispara el trigger.
- **Baja** (trigger `AFTER DELETE`): la cuenta pasa a `inactivo` y la persona y su historia se conservan. **No hay FK hacia `auth.users`** a propósito: borrar una cuenta de Auth no debe borrar pedidos, facturas ni auditoría.
- **El desbloqueo no es automático**: lo decide el personal autorizado (RF-32).
- **Una compra previa como invitado con el mismo correo no se vincula automáticamente**, igual que en el diseño original: vincular exige verificar la identidad.

`identidad.iniciar_contexto_supabase(sub uuid, correlacion uuid)` solo la puede ejecutar `st_app`. El backend la llama al inicio de cada transacción con el `sub` del JWT **ya verificado**. Devuelve el `usuario_id`, o `NULL` si la cuenta no existe, está pendiente o está bloqueada; en ese caso las consultas quedan sin identidad (falla cerrado).

**Contraseñas**: con Supabase Auth no se usan `identidad.credencial`, `sesion` ni `recuperacion_acceso`. Se conservan para no alterar el modelo aprobado de 62 tablas, pero se retira `EXECUTE` a las 8 rutinas de contraseña local, y `verificacion_supabase.sql` falla si esas tablas tienen filas.

## 4. Modelo de seguridad resultante

```
Navegador ──(JWT de Supabase Auth)──► Backend de la plataforma ──(st_backend, pooler)──► PostgreSQL
                                        │ verifica el JWT (getUser / JWKS)
                                        │ BEGIN; SELECT identidad.iniciar_contexto_supabase(sub);
                                        │ CALL procedimiento(...) / SELECT vistas con RLS; COMMIT;
Navegador ──► Supabase Auth (registro, login, recuperación)  ──trigger──► identidad.usuario
Navegador ──✗──► API REST/GraphQL sobre los 7 esquemas (sin privilegios: 42501)
```

- `st_backend` (LOGIN, miembro de `st_app`): solo `SELECT` sobre tablas y vistas con RLS, más `EXECUTE` de procedimientos. **Sin INSERT/UPDATE/DELETE directos** (pruebas SB10 y T40-28).
- `st_trabajador` (miembro de `st_worker`): validación de archivos, envío de notificaciones y concesiones de invitado. Se usará desde un proceso de servidor (por ejemplo una Edge Function o un job).
- `postgres` (administrador del proyecto Supabase) es el DBA del modelo: es miembro de `st_dba` y por eso `identidad.es_dba()` es verdadero. **No editen datos desde el Table Editor del panel**: eso salta los procedimientos (la misma regla que en local).
- La clave `service_role` **no sirve** para leer estas tablas (prueba SB13) y nunca debe estar en el frontend.

## 5. Qué NO se expone ni se configura aquí

- No se añaden los 7 esquemas a "Exposed schemas" de la API. Dejen solo `public` (y `graphql_public` si aparece).
- No se crean buckets de Storage. Recomendación: un bucket **privado** `adjuntos` (comprobantes y documentos, descargados con URL firmada que genera el backend tras comprobar `comunicacion.puede_leer_archivo`) y uno **público** `catalogo` (imágenes de productos). `comunicacion.archivo.almacen` / `clave_objeto` guardan el bucket y la ruta.
- No se implementan frontend, backend, envío de correos, generación de PDF, facturación electrónica ni pagos.
