# Systemic Tech & Support — entrega PostgreSQL

> **Actualización 2026-10-09 (corrección 06).** La corrección 05 se reprodujo y validó en una réplica PostgreSQL 18.3, y la suite completa pasa allí (111 casos de prueba). Orden para tu servidor: **1)** `retomar_datos_psql.sql` → **2)** `completar_datos_psql.sql` → **3)** `probar_psql.sql`. Los pasos, la salida esperada y la migración a Supabase están en `PROCEDIMIENTO_MIGRACION.md` (carpeta `supabase/` del paquete). Cambios y evidencia: `correccion_06.md`. Matriz actualizada: `matriz_rf_01_42.md` (v2). La frase «no está listo para Supabase» de más abajo se refiere a exponer la base directamente por la API REST; el despliegue con backend propio y Supabase Auth ya está preparado en `supabase/migrations/`.

Este paquete completa los scripts de estructura, programación, seguridad, demostración y pruebas sobre el modelo revisado. Nombre: `systemic_tech_db`, descriptivo, ASCII y snake_case. Requiere PostgreSQL 18; la consola mostrada por el usuario identifica 18.3.

**Estado real actualizado para continuar el trabajo:** la estructura quedó confirmada. La última captura muestra que la carga falló al crear un proyecto: `proyectos.proteger_datos()` intentó leer `NEW.cliente_id`, campo de solicitud_desarrollo que no existe en proyecto. El archivo `parche_05_trigger_proyectos.sql` ya corrige esa separación; su ejecución en el servidor todavía no está confirmada. `retomar_datos_psql.sql` conserva las tablas, aplica los parches 03–05 y repite la carga si las tablas están vacías. Falta completar los datos demo, la verificación básica y `probar_psql.sql`, corregir cualquier error restante y registrar los resultados reales. Consulta `correccion_05.md` y `estado_ejecucion.json`. No vuelvas a usar el instalador inicial sobre la base existente. Las herramientas no tienen una conexión autenticada para ejecutar esas pruebas directamente.

## Ejecutar desde tu consola PSQL

En el indicador `postgres=#`, pega esta línea completa y pulsa Enter:

```psql
\i 'C:/Users/danie/Documents/Codex/2026-09-12/quiero-que-act-es-como-un-2/outputs/systemic_tech_completo/instalar_psql.sql'
```

El archivo crea roles técnicos, crea la base, instala objetos en una transacción, carga datos ficticios en otra y ejecuta la verificación básica. Si termina correctamente muestra **INSTALACION Y VERIFICACION BASICA TERMINADAS**. Se detiene si la base o alguno de los roles ya existen; no borra ni sustituye información. No vuelvas a ejecutarlo sobre una instalación existente.

También existe `TODO_EN_UNO_PSQL.sql`, completamente autónomo: puedes abrirlo, copiar todo su contenido y pegarlo en SQL Shell. Es extenso; `\i` evita errores de copiado. Ambos instaladores son para PSQL y contienen órdenes que el editor SQL de pgAdmin no interpreta. Ejecuta solo uno.

Para comprobar los casos positivos, rechazos y aislamiento de comunicación después de instalar:

```psql
\i 'C:/Users/danie/Documents/Codex/2026-09-12/quiero-que-act-es-como-un-2/outputs/systemic_tech_completo/probar_psql.sql'
```

Las pruebas requieren el usuario postgres/superusuario, por el cambio temporal de identidad SQL empleado para verificar permisos reales. Las pruebas comerciales requieren los datos demo. Los cambios de las pruebas se revierten; las secuencias pueden dejar huecos. Si aparece un error, conserva la primera línea ERROR y su CONTEXT. Ejecuta `ROLLBACK;` y `RESET SESSION AUTHORIZATION;` antes de continuar. La instalación estructural es atómica, pero crear una base y los roles exige pasos separados: ante un fallo pueden quedar roles y una base vacía o una estructura instalada sin datos. No uses DROP ni vuelvas a instalar a ciegas.

## Verla en pgAdmin

Actualiza **Databases** en tu servidor y abre **systemic_tech_db → Schemas**. Dentro de cada esquema encontrarás **Tables**, **Views**, **Functions**, **Procedures** y **Sequences**. Para ver datos: botón derecho en una tabla → **View/Edit Data → All Rows**. Para consultar: abre **Query Tool** conectado a systemic_tech_db.

```sql
SELECT * FROM inventario.v_productos_disponibles;
SELECT * FROM comercial.v_resumen_pedidos;
SELECT * FROM comercial.v_facturas_cliente;
SELECT * FROM servicios.v_servicios_activos;
SELECT * FROM proyectos.v_avance_proyecto;
SELECT * FROM comercial.v_historial_cliente ORDER BY fecha DESC;
```

En PSQL también puedes usar `\dn`, `\dt *.*` y `\dv *.*`. No cambies manualmente existencias o importes históricos: utiliza los procedimientos.

## Archivos y alcance

| Archivo | Finalidad |
|---|---|
| instalar_psql.sql | Entrada recomendada; usa archivos vecinos mediante rutas relativas. |
| TODO_EN_UNO_PSQL.sql | Mismo instalador, autónomo, apto para copiar y pegar en PSQL. |
| estructura_y_logica.sql | Estructura y programación unidas en una transacción; depende de roles/base creados. |
| 00_roles.sql; 01_estructura.sql; 02_autenticacion_local.sql | Roles técnicos y 62 tablas con restricciones, índices y secuencias. |
| 10 a 55 | Identidad, operaciones comerciales, servicios, proyectos, comunicación, auditoría y autenticación auxiliar. |
| 60_seguridad.sql; 65_vistas.sql | ACL, RLS, consultas operativas y alias de catálogo. |
| 70_datos_demo.sql | Personas ficticias, productos, stock, compra, cotización, reparación, mantenimiento, agenda, proyecto, factura y valoración. |
| 80 a 84; probar_psql.sql | Inspección y casos verificables; no se presentan como ejecutados. |
| modelo_conceptual.md; modelo_logico.md; diccionario_datos.md | Entidades, cardinalidades, normalización y campos del modelo aprobado. |
| der_final.mmd | DER físico final con las 62 tablas y sus claves foráneas. |
| programacion_y_objetos.md; decisiones_finales.md | Inventario y explicación de funciones, procedimientos, triggers y decisiones de explotación. |
| matriz_rf_01_42.md | Cobertura individual, distinguiendo BD y aplicación. |
| revision_estatica.json; sha256.json | Alcance comprobado por revisión textual y huellas de los archivos. |

Los documentos de fases 2 y 3 conservan el razonamiento aprobado y algunas referencias a programación futura; los scripts y `decisiones_finales.md` describen la entrega actual. Las tres tablas locales de autenticación se incluyen para demostrar el modelo, aunque los datos ficticios usan identidades externas simuladas sin credenciales utilizables.

## Conexión posterior del backend

Los usuarios SQL `st_backend`, `st_trabajador` y `st_consulta` se crean sin contraseña. No permiten autenticación por contraseña hasta configurarla de manera interactiva con `\password st_backend` (y los otros usuarios que realmente se vayan a utilizar). Configura SCRAM y las reglas apropiadas en pg_hba.conf; no guardes contraseñas en el repositorio.

`st_owner` es propietario sin LOGIN. `st_dba` permite al administrador asumirlo. `st_app` ejecuta APIs y lee filas autorizadas, `st_worker` atiende autenticación, archivos y entregas, `st_lectura` solo consulta. `st_administracion` es un grupo SQL para herramientas administrativas de la aplicación: no concede por sí solo el rol de negocio administrador. Nunca asignes st_owner/st_dba a conexiones de la aplicación.

Cada solicitud del backend usa una transacción READ COMMITTED y contexto LOCAL:

```sql
BEGIN;
SELECT set_config('app.usuario_id', $1, true);
SELECT set_config('app.invitado_token', '', true);
SELECT set_config('app.correlacion_id', $2, true);
-- CALL de la operación y consultas autorizadas.
COMMIT;
```

`$1` y `$2` son parámetros enlazados por el driver, no texto para pegar literalmente en PSQL. Para invitado, deja usuario_id vacío y establece el token verificado. El backend jamás acepta usuario_id del navegador como identidad: debe obtenerlo de la sesión/JWT verificado. Limpia ambos contextos en cada transacción, también en conexiones reutilizadas. Guarda las credenciales SQL únicamente en el servidor. Las políticas no convierten un GUC controlado por el cliente en una identidad confiable.

**Este paquete no está listo para exposición directa mediante PostgREST o Supabase.** Para ello hay que adaptar la resolución de identidad a claims verificados por PostgREST o a auth.uid(), mapear sujeto/emisor, fijar roles de API y revisar políticas y RPC. No basta con activar RLS. Con backend propio se aplica el contrato privado descrito aquí. JWT, correo, almacenamiento, generación de PDF y cobro son integraciones posteriores.

Para carrito anónimo el backend genera un secreto criptográfico y llama a crear_carrito/editar_carrito/convertir_carrito. La consulta del carrito anónimo se efectúa con la función consultar_carrito incluida en 65_vistas.sql, enviando ese mismo secreto. La base guarda su hash. Para futuras consultas de un pedido o solicitud, el worker verifica el contacto y emite una concesión de recurso/acciones con vencimiento; no exige crear cuenta.

No se implementan un frontend, un proveedor de autenticación real, correos, almacenamiento de bytes, facturación electrónica ni pagos. Los RF se sostienen con datos y operaciones; el sistema completo necesita esas partes de aplicación y las reglas fiscales que se decidan.
