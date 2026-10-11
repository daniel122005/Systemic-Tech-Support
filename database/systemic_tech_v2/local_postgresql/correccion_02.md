# Corrección de la carga de datos ficticios

La segunda captura del servidor muestra COMMIT de `estructura_y_logica.sql`, seguido por un fallo en la transacción de `70_datos_demo.sql`: el registro `r` no tiene un campo `id`. Por tanto, la estructura está confirmada y la carga demo quedó abortada; no debe ejecutarse otra vez el instalador de estructura.

La variable PL/pgSQL `r` contenía únicamente el campo `recurso` del bucle de permisos. Su nombre coincidía con el alias `r` de `identidad.rol` en dos INSERT posteriores. Se renombró la variable a `v_recurso_permiso` y se conservaron los alias SQL. El cambio está incorporado en la carga independiente y en el instalador autónomo actualizado.

Ejecutar en PSQL:

```psql
\i 'C:/Users/danie/Documents/Codex/2026-09-12/quiero-que-act-es-como-un-2/outputs/systemic_tech_completo/retomar_datos_psql.sql'
```

El archivo revierte exclusivamente la transacción pendiente, comprueba que existan las 62 tablas y que no haya filas de negocio confirmadas antes de repetir la primera carga. No recrea ni elimina tablas o roles. Si encuentra datos existentes, se detiene para evitar duplicados.

La captura acredita la compilación y confirmación de la estructura. La carga corregida y las pruebas de comportamiento siguen pendientes de ejecución en el servidor del usuario.
