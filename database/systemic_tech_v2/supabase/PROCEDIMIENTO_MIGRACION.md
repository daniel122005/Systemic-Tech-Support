# Procedimiento: terminar PostgreSQL local y desplegar en Supabase

Cada paso dice qué ejecutar, dónde y qué debe aparecer. **No avances al siguiente paso si el anterior no muestra el resultado esperado**: conserva la primera línea `ERROR` y su `CONTEXT` y envíamelas.

Sustituye `<CARPETA>` por la ruta donde están tus scripts locales, que hoy es `C:/Users/danie/Documents/Codex/2026-09-12/quiero-que-act-es-como-un-2/outputs/systemic_tech_completo`. Antes, copia ahí el contenido de `local_postgresql/` de este paquete (ver `LEEME_PRIMERO.md`).

---

## Parte 1 — PostgreSQL local (SQL Shell / psql, usuario postgres)

### L1. Reanudar la carga de datos (aplica los parches 03–05)

```psql
\i '<CARPETA>/retomar_datos_psql.sql'
```

**Esperado:** primero `WARNING: there is no transaction in progress` (es normal), luego `NOTICE: Estructura, políticas, privilegios e invariantes comprobados`, 6 tablas de resultados y al final **`DATOS DE DEMOSTRACION Y VERIFICACION BASICA TERMINADOS`**.

**Cómo interpretar un fallo:**

- `Ya hay filas confirmadas en …`: ya existen datos. **No borres nada**. Envíame el mensaje.
- `Se esperaban 62 tablas`: la estructura no es la esperada. Envíame el mensaje.
- Cualquier otro `ERROR`: ejecuta `ROLLBACK;` y envíame el error con su `CONTEXT`.

### L2. Completar los datos ficticios (imágenes, archivos, comprobante, entregas, invitado)

```psql
\i '<CARPETA>/completar_datos_psql.sql'
```

**Esperado:** `Complemento de datos ficticios cargado: …` y **`COMPLEMENTO DE DATOS Y VERIFICACION BASICA TERMINADOS`**. Si dice `ya fue cargado`, el paso ya estaba hecho: continúa.

### L3. Suite completa de pruebas

```psql
\i '<CARPETA>/probar_psql.sql'
```

**Esperado:** avisos `… OK` (C01–C08, T40-01 a T40-29, A01–A08, Q01–Q05, R01–R30), la tabla de pruebas S/P de servicios y, al final, **`TODAS LAS PRUEBAS DEL PAQUETE TERMINARON SIN ERROR`**. Todo se revierte: puedes repetirlo.

Si falla: `ROLLBACK;` y luego `RESET SESSION AUTHORIZATION;`, y envíame el error.

### L4. Huella del catálogo local (para comparar con Supabase)

```psql
\connect systemic_tech_db
\o '<CARPETA>/catalogo_local.txt'
\pset format unaligned
\pset tuples_only on
\i '<CARPETA>/catalogo_detallado.sql'
\o
```

---

## Parte 2 — Supabase

### S0. Comprobar la versión del proyecto (SQL Editor)

```sql
select version();
```

**Esperado:** `PostgreSQL 17.x` (o superior). Con 15.x **no continúes**: las migraciones se detienen con un mensaje claro. Se puede actualizar el proyecto desde *Project Settings → Infrastructure*.

### S1. Preparar el repositorio con Supabase CLI (terminal)

```bash
npm install -D supabase           # o la instalación que prefieran
npx supabase init                 # crea supabase/config.toml
# Copiar desde este paquete:
#   supabase/migrations/*.sql  → supabase/migrations/
#   supabase/seed.sql          → supabase/seed.sql   (solo datos ficticios)
npx supabase login                # abre el navegador; no pegues tokens en ningún archivo
npx supabase link --project-ref <REF_DEL_PROYECTO>
```

En `supabase/config.toml` revisa:

- `[db] major_version = 17`
- `[api] schemas = ["public", "graphql_public"]` → **no** añadas `identidad`, `comercial`, etc.
- `[auth.email] enable_confirmations = true` → así una cuenta queda `pendiente` hasta confirmar el correo.

### S2. Ensayo completo en local con la imagen oficial de Supabase (requiere Docker)

```bash
npx supabase start
npx supabase db reset             # aplica las 6 migraciones + seed.sql en la base LOCAL
psql "postgresql://supabase_admin:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 \
     -f supabase/pruebas/probar_supabase_local.sql
```

**Esperado:** `PRUEBAS POR REQUERIMIENTO R01-R30 TERMINADAS SIN ERROR`, `PRUEBAS DE INTEGRACION SUPABASE SB01-SB16 TERMINADAS SIN ERROR` y **`TODAS LAS PRUEBAS EN SUPABASE LOCAL TERMINARON SIN ERROR`**.

Las pruebas necesitan superusuario (`supabase_admin`), que solo existe en la pila local. Si la contraseña local de `supabase_admin` no es `postgres` en tu versión del CLI, consulta `npx supabase status`.

### S3. Aplicar al proyecto en la nube (sin datos ficticios)

```bash
npx supabase db push --dry-run    # lista las 6 migraciones pendientes; no aplica nada
npx supabase db push              # aplica las migraciones; NO aplica seed.sql
```

**Nunca** uses `--include-seed` contra producción. El catálogo de roles y permisos ya viene en la migración 6.

**Alternativa sin CLI (SQL Editor):** abre cada archivo de `supabase/migrations/` **en orden** (0100 → 0600), pega su contenido completo, ejecútalo y comprueba que termina sin error antes de pasar al siguiente. Si el editor rechaza un archivo por su tamaño (0200 y 0300 pesan unos 220 KB), usa psql con la conexión directa:

```bash
psql "postgresql://postgres@db.<REF>.supabase.co:5432/postgres?sslmode=require" -v ON_ERROR_STOP=1 -1 -f supabase/migrations/20261009000200_estructura.sql
```

psql pedirá la contraseña. No la pongas en la línea de comandos.

### S4. Verificar el despliegue (SQL Editor)

Pega `supabase/verificacion/verificacion_supabase.sql` completo y ejecútalo.

**Esperado:** una tabla con `tablas 62`, `politicas_rls 62`, `rutinas 138`, `roles_negocio 5`, `permisos 58` y `resultado VERIFICACION SUPERADA`. Si falla, el mensaje empieza por un código `V01`–`V17` que indica exactamente qué falta.

### S5. Contraseña del rol del backend (psql como postgres, conexión directa)

```psql
\password st_backend
```

`\password` envía la contraseña ya cifrada. **No uses `ALTER ROLE … PASSWORD` en el SQL Editor**, porque queda en el historial de consultas. Guarda la contraseña solo en las variables de entorno del servidor del backend. Haz lo mismo con `st_trabajador` cuando exista el proceso de envíos.

### S6. Prueba de humo del backend (como st_backend)

```bash
psql "postgresql://st_backend.<REF>@<HOST_POOLER>:6543/postgres?sslmode=require" -f supabase/verificacion/humo_backend_supabase.sql
```

**Esperado:** `Prueba de humo superada: …`. El host del pooler aparece en *Connect* del panel.

Que un rol propio pueda conectarse por el pooler (Supavisor) con el formato `rol.ref` **no lo pude comprobar**. Si falla la autenticación, prueba con la conexión directa (`db.<REF>.supabase.co:5432`, usuario `st_backend`). Con el modo transacción (puerto 6543) desactiva las sentencias preparadas del driver (`prepare: false`).

### S7. Primer administrador

1. Regístrate en la plataforma (o en *Authentication → Users → Add user*) con el correo del administrador y confirma el correo.
2. En el SQL Editor, abre `supabase/verificacion/bootstrap_administrador.sql`, cambia el correo de la línea marcada y ejecútalo. **Esperado:** `Rol administrador asignado a …`.

### S8. Comparar local y Supabase

Ejecuta `catalogo_detallado.sql` en Supabase (psql, mismas opciones que en L4) y compara con el archivo local, por ejemplo con `diff catalogo_local.txt catalogo_supabase.txt` o con WinMerge.

**Diferencias esperadas (y solo estas):**

| Diferencia | Motivo |
|---|---|
| `esquema … owner=postgres` y ACL con `st_owner=U*C*/postgres` | A4 |
| `extension btree_gist/pgcrypto → extensions` | A5 |
| `md5` distinto en 5 rutinas: `acceso_invitado_actual`, `emitir_acceso_invitado`, `consumir_recuperacion`, `exigir_carrito`, `crear_carrito` | A6 (`sha256`) |
| `acl` distinta en 8 rutinas de contraseña local | migración 5 |
| 2 rutinas nuevas: `iniciar_contexto_supabase`, `sincronizar_usuario_supabase` | migración 5 |
| Unas 413 líneas `restriccion … _not_null` que solo están en local | PostgreSQL 18 registra los `NOT NULL` en el catálogo de restricciones; 17 no (las columnas son idénticas) |

En la réplica la comparación dio exactamente esta lista: 62 tablas, 603 columnas, índices, triggers, políticas y ACL de tablas idénticos.

---

## Datos: qué se migra y qué no

- **Los datos locales son ficticios: no se migran.** En Supabase la estructura llega por migraciones. Los datos ficticios llegan por `seed.sql` y solo a entornos locales o de pruebas.
- **Producción** recibe únicamente el catálogo base (5 roles, 58 permisos, 70 concesiones) en la migración 6. Los productos, servicios, empleados y demás datos reales los carga el personal mediante los procedimientos (RF-32 a RF-42).
- Si algún día hubiera **datos reales** en local que mover, `pg_dump --data-only` **no sirve tal cual**. Los triggers fijan fechas del servidor, protegen historiales de solo-anexar y registran auditoría, y en Supabase no se pueden desactivar sin superusuario. Habría que diseñar un procedimiento específico; pídelo antes de intentarlo.

## Cambios futuros

- Un cambio = una migración nueva (`npx supabase migration new nombre`). **Nunca** edites una migración ya aplicada.
- Las migraciones 1–4 y 6 se regeneran con `python3 herramientas/generar_supabase.py <carpeta_local> <salida>`. Si cambias un módulo local, regenera y revisa el `diff` antes de crear la migración nueva.
- Antes de `db push`, ejecuta siempre `db reset` + `probar_supabase_local.sql` en local.
