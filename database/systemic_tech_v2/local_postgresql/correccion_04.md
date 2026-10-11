# Corrección del contacto de solicitudes de cotización

La captura muestra que los procedimientos de pedidos se actualizaron y la carga avanzó hasta una solicitud de cotización de una persona existente. El ejemplo dejó los parámetros de contacto en NULL, pero el procedimiento anterior guardaba esos NULL directamente; por eso la restricción `ck_solicitud_cotizacion_contacto` rechazó la fila correctamente.

El procedimiento ahora obtiene del perfil autorizado los nombres, correo y teléfono que se omitan. Si se proporciona un contacto alternativo, lo conserva solo en la solicitud: no modifica el perfil. Una vez creada, la solicitud mantiene esa información histórica aunque el perfil cambie. Una persona nueva continúa pudiendo solicitar cotización sin cuenta, pero debe proporcionar nombre y al menos un medio de contacto. La restricción CHECK permanece intacta.

`parche_04_contacto_cotizacion.sql` actualiza la rutina instalada con CREATE OR REPLACE, conservando firma y permisos. El archivo `retomar_datos_psql.sql` aplica ahora los parches 03 y 04 antes de repetir la carga demo sobre tablas vacías. No recrea tablas ni borra datos confirmados.

```psql
\i 'C:/Users/danie/Documents/Codex/2026-09-12/quiero-que-act-es-como-un-2/outputs/systemic_tech_completo/retomar_datos_psql.sql'
```

Se prepararon cinco casos en `85_pruebas_cotizacion_contacto.sql`: usar el perfil, preservar el contacto histórico, respetar un contacto alternativo, aceptar invitados sin cuenta y rechazar ausencia de medios de contacto. El parche y estos casos todavía deben ejecutarse en PostgreSQL; la revisión de archivos no acredita su aprobación en el servidor.
