# Corrección de procedimientos de pedidos ya instalados

La tercera captura muestra que la carga superó el registro de roles y permisos y llegó a `comercial.confirmar_pedido`. El registro local `d` todavía no tenía asignado un detalle cuando una consulta utilizó también `d` como alias SQL. Se encontró el mismo patrón en `comercial.cambiar_estado_pedido`, tanto en su consulta de bloqueo como en la actualización de reservas.

Se renombraron los alias de las consultas a `linea_bloqueo` y `linea_reservada`; el registro del bucle sigue siendo `d`. La revisión textual de variables declaradas frente a alias FROM/JOIN/UPDATE de tablas calificadas en los módulos 10–65 no encontró otras coincidencias de este patrón. Esta revisión no equivale a ejecutar todas las consultas ni descarta otros tipos de ambigüedad SQL.

Cambiar el archivo comercial no actualiza por sí solo las rutinas que ya están en PostgreSQL. Por eso `parche_03_pedidos.sql` reemplaza ambos procedimientos mediante CREATE OR REPLACE, con las mismas firmas y bajo st_owner. No recrea tablas ni modifica directamente filas de negocio.

También se movió la configuración de codificación después de ROLLBACK y de conectar a la base. La orden de codificación anterior se había intentado mientras la transacción estaba abortada; ahora se utiliza SET client_encoding con ON_ERROR_STOP activo.

Ejecutar el archivo actualizado:

```psql
\i 'C:/Users/danie/Documents/Codex/2026-09-12/quiero-que-act-es-como-un-2/outputs/systemic_tech_completo/retomar_datos_psql.sql'
```

Hace ROLLBACK de la carga fallida, comprueba que las 62 tablas estén instaladas y vacías, aplica el parche de procedimientos, carga los datos corregidos y ejecuta la verificación básica. Las rutinas actualizadas quedan confirmadas antes de la carga. Si encuentra datos previamente confirmados, se detiene para conservarlos.

La carga y el parche aún deben ejecutarse en el servidor del usuario; la captura no acredita una carga terminada ni las pruebas funcionales completas.
