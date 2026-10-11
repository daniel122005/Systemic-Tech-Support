# Corrección del trigger compartido de proyectos

La captura muestra el fallo al ejecutar `proyectos.aprobar_solicitud`, después de aplicar las correcciones anteriores. El cliente de un proyecto se obtiene a través de `solicitud_desarrollo_id`; por eso `proyectos.proyecto` no contiene una columna cliente_id.

La función `proyectos.proteger_datos()` atiende varias tablas. Una condición ELSIF comprobaba simultáneamente el nombre de tabla, el evento y NEW.cliente_id. Al preparar esa expresión para una fila de proyecto, PostgreSQL intentó resolver un campo que esa fila no contiene. La corrección usa condiciones anidadas: primero comprueba que la tabla sea solicitud_desarrollo, luego que sea UPDATE, y solo dentro de esa rama consulta cliente_id.

`parche_05_trigger_proyectos.sql` reemplaza únicamente la función mediante CREATE OR REPLACE y conserva los triggers que la invocan, la propiedad y los permisos. El modelo de tablas no cambia. Se actualizaron también `30_servicios.sql`, los instaladores combinados y el ZIP.

La búsqueda textual en los módulos 10–65 no encontró otras condiciones IF/ELSIF que mezclen TG_TABLE_NAME con accesos directos NEW.campo/OLD.campo. Esto no sustituye las pruebas de ejecución ni garantiza ausencia de otros defectos. La suite existente `82_pruebas_servicios.sql` incluye aprobación de proyectos, etapas, avances y protección del historial.

Para la carga abortada que muestra la captura:

```psql
\i 'C:/Users/danie/Documents/Codex/2026-09-12/quiero-que-act-es-como-un-2/outputs/systemic_tech_completo/retomar_datos_psql.sql'
```

El archivo revierte la transacción fallida, comprueba las tablas vacías, aplica las correcciones 03–05 a los objetos instalados y vuelve a cargar los datos. Ninguna fila de la carga fallida se considera confirmada, aunque las llamadas previas dentro de esa transacción hayan terminado sin error. La estructura y los parches ya confirmados se conservan.

La ejecución del parche y la carga final todavía deben comprobarse en el PostgreSQL del usuario.
