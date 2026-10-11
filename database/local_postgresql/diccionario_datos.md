# Diccionario de datos de Systemic Tech & Support

FASE 3 · Especificación para revisión · Sin creación de objetos en PostgreSQL

Contiene 62 tablas especificadas: 59 de negocio y soporte, más 3 opcionales para autenticación propia. No es una tabla por RF. La tabla adicional respecto de fase 2, `acceso_invitado_permiso`, normaliza el conjunto de acciones del acceso invitado.

Convenciones: NULL «Sí» permite ausencia; «No» implica NOT NULL. PK compuesta señala participación en la clave, no unicidad individual. UNIQUE «Sí (PK)» no requiere otro índice. Las unicidades de varias columnas, parciales y exclusiones se detallan debajo. DEFAULT «—» significa que no se define un valor por defecto. Las expresiones generadas no son valores que la aplicación pueda escribir.

Todas las FK son ON DELETE RESTRICT y ON UPDATE RESTRICT. Las claves internas son inmutables. La baja operativa utiliza estado/inactividad; eliminar datos relacionados requiere un procedimiento de conservación y purga explícito. No se propone cascada que borre historia comercial.

Los CHECK descritos en lenguaje natural son contratos precisos que se traducirán a expresiones en fase 4. Las validaciones cruzadas de las secciones T01–T14 se implementarán en fase 5; no se presentan como CHECK ejecutables ni como controles ya activos.

Reglas globales de dominio: texto obligatorio no vacío tras trim; correo de acceso normalizado, sin confundir verificación de correo con un CHECK de formato; moneda de tres letras mayúsculas y selección válida controlada por aplicación; fechas/instantes finitos; cantidades/precios/tasas sin NaN. NULL permitido solo en los campos marcados y sujeto a reglas condicionales.

Los importes a dos decimales, precio a cuatro decimales, cantidades a tres y escala de valoración 1–5 son decisiones técnicas propuestas para revisión, no reglas fiscales extraídas del documento.

## identidad.acceso_invitado

Concesión verificada limitada a un recurso sin cuenta.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `persona_id` | `bigint` | No | identidad.persona.id | No | No | — | Referencia a identidad.persona.id. |
| `token_hash` | `bytea` | No | — | No | Sí | — | SHA-256 del token opaco aleatorio de alta entropía; no del correo. |
| `medio_verificacion` | `text` | No | — | No | No | — | medio verificacion |
| `destino_verificado` | `text` | No | — | No | No | — | Canal que se verificó al emitir este acceso. |
| `verificado_en` | `timestamptz` | No | — | No | No | — | verificado en |
| `emitido_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | emitido en |
| `vence_en` | `timestamptz` | No | — | No | No | — | vence en |
| `revocado_en` | `timestamptz` | No | — | Sí | No | — | revocado en |
| `version_cotizacion_id` | `bigint` | No | comercial.version_cotizacion.id | Sí | No | — | Referencia a comercial.version_cotizacion.id. |
| `pedido_id` | `bigint` | No | comercial.pedido.id | Sí | No | — | Referencia a comercial.pedido.id. |
| `solicitud_servicio_id` | `bigint` | No | servicios.solicitud_servicio.id | Sí | No | — | Referencia a servicios.solicitud_servicio.id. |
| `orden_servicio_id` | `bigint` | No | servicios.orden_servicio.id | Sí | No | — | Referencia a servicios.orden_servicio.id. |
| `solicitud_cotizacion_id` | `bigint` | No | comercial.solicitud_cotizacion.id | Sí | No | — | Referencia a comercial.solicitud_cotizacion.id. |
| `cotizacion_id` | `bigint` | No | comercial.cotizacion.id | Sí | No | — | Referencia a comercial.cotizacion.id. |
| `solicitud_desarrollo_id` | `bigint` | No | proyectos.solicitud_desarrollo.id | Sí | No | — | Referencia a proyectos.solicitud_desarrollo.id. |
| `proyecto_id` | `bigint` | No | proyectos.proyecto.id | Sí | No | — | Referencia a proyectos.proyecto.id. |
| `factura_id` | `bigint` | No | comercial.factura.id | Sí | No | — | Referencia a comercial.factura.id. |
| `conversacion_id` | `bigint` | No | comunicacion.conversacion.id | Sí | No | — | Referencia a comunicacion.conversacion.id. |

**Restricciones de fila**

- CHECK octet_length(token_hash)=32; verificado_en <= emitido_en; vence_en > emitido_en; revocado_en IS NULL OR revocado_en >= emitido_en
- CHECK num_nonnulls(pedido_id, solicitud_servicio_id, orden_servicio_id, solicitud_cotizacion_id, cotizacion_id, solicitud_desarrollo_id, proyecto_id, factura_id, conversacion_id) = 1
- CHECK version_cotizacion_id exige cotizacion_id

**Reglas cruzadas y de operación**

- T13: persona titular del proceso o participante autorizado de conversación; versión pertenece a cotización. Acciones mediante acceso_invitado_permiso y lista de acciones invitadas permitidas por tipo; nunca asignación de roles, auditoría ni administración.
- Verificar token, tiempo, revocación, titularidad y permiso en cada operación; no basta validar al abrir pantalla. Para aceptar/rechazar cotización se exige versión precisa y vigente; respuesta atómica impide segundo uso. La concesión puede seguir sirviendo para consulta hasta expirar.
- Cambiar persona/contexto/permisos o versión requiere revocar y emitir otro acceso verificado. No existe un acceso invitado para toda la persona o todo su historial. Expiración no es CHECK con reloj.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## identidad.acceso_invitado_permiso

Acciones acotadas de una concesión; evita listas de permisos dentro de un campo.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `acceso_invitado_id` | `bigint` | Sí (compuesta) | identidad.acceso_invitado.id | No | No | — | Referencia a identidad.acceso_invitado.id. |
| `permiso_id` | `bigint` | Sí (compuesta) | identidad.permiso.id | No | No | — | Referencia a identidad.permiso.id. |

**Reglas cruzadas y de operación**

- T13: debe haber al menos una acción al emitir. Permiso debe pertenecer a lista segura compatible con recurso. El rol de negocio no se copia al invitado. Cambios requieren nueva concesión.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## identidad.cliente

Perfil comercial de una persona; puede existir sin usuario.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `persona_id` | `bigint` | No | identidad.persona.id | No | Sí | — | Referencia a identidad.persona.id. |
| `codigo` | `text` | No | — | No | Sí | — | Código de negocio estable; unicidad independiente de la PK. |
| `observaciones` | `text` | No | — | Sí | No | — | observaciones |
| `activo` | `boolean` | No | — | No | No | true | activo |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Reglas cruzadas y de operación**

- El perfil no confiere credenciales. Los documentos conservan sus datos históricos; nombres actuales se consultan en persona.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## identidad.credencial

Credencial local opcional; una por cuenta. **Opcional: perfil de autenticación propia.**

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `usuario_id` | `bigint` | Sí | identidad.usuario.id | No | Sí (PK) | — | Referencia a identidad.usuario.id. |
| `password_hash` | `text` | No | — | No | No | — | Hash resistente de contraseña con parámetros/sal; nunca texto plano. |
| `cambiada_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | cambiada en |

**Reglas cruzadas y de operación**

- Solo cuentas origen_auth local. Campo excluido de auditoría JSON, vistas y respuestas API. La aplicación/proveedor realiza el hash.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## identidad.empleado

Perfil de empleado individual; sin datos de nómina.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `persona_id` | `bigint` | No | identidad.persona.id | No | Sí | — | Referencia a identidad.persona.id. |
| `codigo` | `text` | No | — | No | Sí | — | Código de negocio estable; unicidad independiente de la PK. |
| `cargo` | `text` | No | — | No | No | — | cargo |
| `fecha_vinculacion` | `date` | No | — | No | No | — | fecha vinculacion |
| `activo` | `boolean` | No | — | No | No | true | activo |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Reglas cruzadas y de operación**

- Para actuar como técnico/desarrollador debe existir usuario activo de esta persona con permiso aplicable. Cargo no equivale a rol.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## identidad.permiso

Acción autorizable sobre un recurso.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `codigo` | `text` | No | — | No | Sí | — | Código de negocio estable; unicidad independiente de la PK. |
| `recurso` | `text` | No | — | No | No | — | recurso |
| `accion` | `text` | No | — | No | No | — | accion |
| `descripcion` | `text` | No | — | No | No | — | descripcion |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Unicidad y exclusión adicionales**

- UNIQUE (recurso, accion).

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## identidad.persona

Contacto e identidad compartida, sin cuenta obligatoria.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `nombres` | `text` | No | — | No | No | — | nombres |
| `apellidos` | `text` | No | — | Sí | No | — | apellidos |
| `correo_contacto` | `text` | No | — | Sí | No | — | correo contacto |
| `telefono` | `text` | No | — | Sí | No | — | telefono |
| `activo` | `boolean` | No | — | No | No | true | activo |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK nombres no vacío; al menos correo_contacto o telefono informado.

**Reglas cruzadas y de operación**

- El contacto no es prueba de titularidad; no fusionar por correo/nombre. La vinculación a una cuenta requiere verificación. Correo de contacto no es UNIQUE.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## identidad.recuperacion_acceso

Recuperación local de uso único. **Opcional: perfil de autenticación propia.**

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `usuario_id` | `bigint` | No | identidad.usuario.id | No | No | — | Referencia a identidad.usuario.id. |
| `token_hash` | `bytea` | No | — | No | Sí | — | Huella SHA-256 del secreto. |
| `solicitada_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | solicitada en |
| `vence_en` | `timestamptz` | No | — | No | No | — | vence en |
| `consumida_en` | `timestamptz` | No | — | Sí | No | — | consumida en |

**Restricciones de fila**

- CHECK octet_length(token_hash)=32; vence_en > solicitada_en; consumida_en IS NULL OR consumida_en >= solicitada_en

**Reglas cruzadas y de operación**

- Verificar vencimiento y consumir bajo bloqueo en la misma operación que cambia la credencial; gestionar revocación de sesiones. El proveedor de correo realiza la entrega.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## identidad.rol

Rol administrable de negocio.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `codigo` | `text` | No | — | No | Sí | — | Código de negocio estable; unicidad independiente de la PK. |
| `nombre` | `text` | No | — | No | No | — | nombre |
| `descripcion` | `text` | No | — | No | No | — | descripcion |
| `activo` | `boolean` | No | — | No | No | true | activo |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## identidad.rol_permiso

Concesión vigente entre un rol y un permiso.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `rol_id` | `bigint` | Sí (compuesta) | identidad.rol.id | No | No | — | Referencia a identidad.rol.id. |
| `permiso_id` | `bigint` | Sí (compuesta) | identidad.permiso.id | No | No | — | Referencia a identidad.permiso.id. |
| `concedido_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | concedido en |
| `actor_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `actor_sistema` | `text` | No | — | Sí | No | — | Proceso automático responsable cuando no hay iniciador humano. |

**Restricciones de fila**

- CHECK num_nonnulls(actor_persona_id, actor_sistema) = 1; actor_sistema no vacío si existe.

**Reglas cruzadas y de operación**

- Retirar una concesión elimina la relación mediante operación autorizada; la auditoría conserva quién y qué se retiró. La PK compuesta ya evita duplicados.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## identidad.sesion

Sesión local con revocación y renovación. **Opcional: perfil de autenticación propia.**

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `usuario_id` | `bigint` | No | identidad.usuario.id | No | No | — | Referencia a identidad.usuario.id. |
| `refresh_hash` | `bytea` | No | — | No | Sí | — | Huella SHA-256 del secreto de renovación. |
| `inicia_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | inicia en |
| `vence_en` | `timestamptz` | No | — | No | No | — | vence en |
| `revocada_en` | `timestamptz` | No | — | Sí | No | — | revocada en |

**Restricciones de fila**

- CHECK octet_length(refresh_hash)=32; vence_en > inicia_en; revocada_en IS NULL OR revocada_en >= inicia_en

**Reglas cruzadas y de operación**

- Validar cuenta/expiración/revocación en cada renovación; rotar huella bajo bloqueo de sesión. No usar CHECK comparado con el reloj.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## identidad.usuario

Cuenta opcional; un único perfil de acceso por persona.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `persona_id` | `bigint` | No | identidad.persona.id | No | Sí | — | Referencia a identidad.persona.id. |
| `correo_acceso` | `text` | No | — | No | Sí | — | Correo de acceso normalizado con lower y trim. |
| `estado` | `text` | No | — | No | No | 'pendiente' | Estado: pendiente, activo, bloqueado, inactivo. |
| `origen_auth` | `text` | No | — | No | No | — | local o externo. |
| `emisor_externo` | `text` | No | — | Sí | No | — | emisor externo |
| `sujeto_externo` | `text` | No | — | Sí | No | — | sujeto externo |
| `verificado_en` | `timestamptz` | No | — | Sí | No | — | verificado en |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK estado IN ('pendiente', 'activo', 'bloqueado', 'inactivo')
- CHECK correo_acceso = lower(btrim(correo_acceso)); correo no vacío
- CHECK origen_auth IN ('local','externo'); local exige emisor/sujeto NULL y externo exige ambos no vacíos

**Unicidad y exclusión adicionales**

- UNIQUE (emisor_externo, sujeto_externo) cuando externos.

**Reglas cruzadas y de operación**

- Una cuenta local activa requiere credencial; externa delega autenticación. Cambiar identidad/persona requiere procedimiento de vinculación y auditoría; no UPDATE libre.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## identidad.usuario_rol

Asignación temporal de rol; conserva retiros y reasignaciones.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `usuario_id` | `bigint` | No | identidad.usuario.id | No | No | — | Referencia a identidad.usuario.id. |
| `rol_id` | `bigint` | No | identidad.rol.id | No | No | — | Referencia a identidad.rol.id. |
| `inicia_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | inicia en |
| `termina_en` | `timestamptz` | No | — | Sí | No | — | termina en |
| `actor_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `actor_sistema` | `text` | No | — | Sí | No | — | Proceso automático responsable cuando no hay iniciador humano. |

**Restricciones de fila**

- CHECK termina_en IS NULL OR termina_en > inicia_en
- CHECK num_nonnulls(actor_persona_id, actor_sistema) = 1; actor_sistema no vacío si existe.

**Unicidad y exclusión adicionales**

- EXCLUDE previsto: mismo usuario_id y rol_id con intervalos [inicia_en, termina_en) solapados; fin NULL es infinito.

**Reglas cruzadas y de operación**

- Asignaciones efectivas desde inicia_en hasta termina_en, límite superior exclusivo. No debe haber períodos superpuestos del mismo usuario/rol. Cambios requieren permiso de administración de roles.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## inventario.categoria

Clasificación principal del catálogo.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `nombre` | `text` | No | — | No | Sí | — | nombre |
| `descripcion` | `text` | No | — | No | No | — | descripcion |
| `activa` | `boolean` | No | — | No | No | true | activa |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## inventario.inventario

Proyección transaccional del saldo físico de una ubicación.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `producto_id` | `bigint` | Sí | inventario.producto.id | No | Sí (PK) | — | Referencia a inventario.producto.id. |
| `saldo` | `numeric(14,3)` | No | — | No | No | 0 | Suma materializada de movimientos. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | updated at |

**Restricciones de fila**

- CHECK saldo >= 0
- CHECK saldo <> 'NaN'::numeric

**Reglas cruzadas y de operación**

- T06: solo el mecanismo de movimientos modifica saldo. Crear producto crea su saldo cero de forma atómica. El saldo debe coincidir con el libro de movimientos en todo estado confirmado.

**Normalización:** Excepción controlada a datos derivados: saldo es una proyección para bloqueo y consulta. No constituye una fuente independiente; se reconstruye y concilia contra movimientos.

## inventario.movimiento_inventario

Libro inmutable de entradas, salidas y ajustes.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `producto_id` | `bigint` | No | inventario.inventario.producto_id | No | No | — | Referencia a inventario.inventario.producto_id. |
| `tipo` | `text` | No | — | No | No | — | tipo |
| `delta` | `numeric(14,3)` | No | — | No | No | — | Variación firmada de existencia física. |
| `motivo` | `text` | No | — | No | No | — | motivo |
| `detalle_pedido_id` | `bigint` | No | comercial.detalle_pedido.id | Sí | No | — | Referencia a comercial.detalle_pedido.id. |
| `compensa_movimiento_id` | `bigint` | No | inventario.movimiento_inventario.id | Sí | No | — | Referencia a inventario.movimiento_inventario.id. |
| `operacion_id` | `uuid` | No | — | No | Sí | — | Clave de reintento aportada por backend, no renovada en cada retry. |
| `registrado_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | registrado en |
| `actor_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `actor_sistema` | `text` | No | — | Sí | No | — | Proceso automático responsable cuando no hay iniciador humano. |

**Restricciones de fila**

- CHECK tipo IN ('entrada','salida','ajuste'); delta <> 0; entrada exige delta > 0; salida exige delta < 0
- CHECK detalle_pedido_id solo informado para salida; motivo no vacío; compensación no se referencia a sí misma
- CHECK delta <> 'NaN'::numeric
- CHECK num_nonnulls(actor_persona_id, actor_sistema) = 1; actor_sistema no vacío si existe.

**Unicidad y exclusión adicionales**

- Unicidad parcial detalle_pedido_id WHERE detalle_pedido_id IS NOT NULL: una salida de entrega por línea; no hay entregas parciales.

**Reglas cruzadas y de operación**

- T06: append-only. Bloquear producto; aplicar delta y mantener saldo >= reservas activas. Salida de entrega debe consumir su reserva conjuntamente; validación del saldo disponible se realiza sobre el estado final de la operación.
- Salida por pedido coincide con producto y cantidad de su detalle confirmado. Compensación debe referir mismo producto; no da permiso implícito de devolver o alterar una venta. Correcciones justificadas con un nuevo movimiento.
- operacion_id se reutiliza al reintentar; si payload cambia con mismo identificador se rechaza.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## inventario.producto

Producto publicable con condiciones vigentes.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `sku` | `text` | No | — | No | Sí | — | sku |
| `categoria_id` | `bigint` | No | inventario.categoria.id | No | No | — | Referencia a inventario.categoria.id. |
| `nombre` | `text` | No | — | No | No | — | nombre |
| `descripcion` | `text` | No | — | No | No | — | descripcion |
| `unidad` | `text` | No | — | No | No | — | unidad |
| `precio_vigente` | `numeric(18,4)` | No | — | No | No | — | precio vigente |
| `moneda` | `text` | No | — | No | No | — | Código monetario de tres letras mayúsculas; sin moneda predeterminada. |
| `publicado` | `boolean` | No | — | No | No | false | publicado |
| `activo` | `boolean` | No | — | No | No | true | activo |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK precio_vigente >= 0; moneda ~ tres mayúsculas; sku/nombre/unidad no vacíos
- CHECK precio_vigente <> 'NaN'::numeric

**Reglas cruzadas y de operación**

- Precio y publicación se auditan. Cambiar unidad con movimientos/pedidos se impide: requiere nuevo producto. El catálogo no reescribe condiciones históricas. No incluye stock ni disponibilidad persistidos.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## inventario.producto_imagen

Presentación de imágenes sin duplicar el producto.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `producto_id` | `bigint` | No | inventario.producto.id | No | No | — | Referencia a inventario.producto.id. |
| `archivo_id` | `bigint` | No | comunicacion.archivo.id | No | No | — | Referencia a comunicacion.archivo.id. |
| `orden` | `integer` | No | — | No | No | — | orden |
| `texto_alternativo` | `text` | No | — | No | No | — | texto alternativo |
| `principal` | `boolean` | No | — | No | No | false | principal |

**Restricciones de fila**

- CHECK orden > 0

**Unicidad y exclusión adicionales**

- UNIQUE (producto_id, archivo_id).
- UNIQUE (producto_id, orden).
- Unicidad parcial producto_id WHERE principal: máximo una imagen principal.

**Reglas cruzadas y de operación**

- Archivo validado y expresamente público. Cambiar visibilidad o invalidar archivo vuelve a comprobar usos públicos.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## inventario.reserva_inventario

Compromiso de unidades de una línea confirmada.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `detalle_pedido_id` | `bigint` | Sí | comercial.detalle_pedido.id | No | Sí (PK) | — | Referencia a comercial.detalle_pedido.id. |
| `estado` | `text` | No | — | No | No | 'activa' | Estado: activa, consumida, liberada. |
| `creada_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | creada en |
| `cerrada_en` | `timestamptz` | No | — | Sí | No | — | cerrada en |
| `motivo_liberacion` | `text` | No | — | Sí | No | — | motivo liberacion |

**Restricciones de fila**

- CHECK estado IN ('activa', 'consumida', 'liberada')
- CHECK (estado='activa' AND cerrada_en IS NULL) OR (estado<>'activa' AND cerrada_en IS NOT NULL); cerrada_en >= creada_en cuando exista; liberada exige motivo

**Reglas cruzadas y de operación**

- T06: cantidad y producto se derivan de detalle_pedido, que queda inmutable al confirmar. Así no hay una cantidad de reserva editable distinta. Confirmar reserva todas las líneas; entregar consume y descuenta; cancelar libera antes de salida.
- Bloquear inventario de todos los productos en orden de producto_id para confirmar/entregar/cancelar. Cambios o borrados directos de reservas se prohíben.

**Normalización:** Cantidad y producto se derivan de la línea vendida; no se duplican. El estado expresa un hecho independiente: si el compromiso sigue vigente.

## comercial.carrito

Selección de compra identificada o de visitante.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `cliente_id` | `bigint` | No | identidad.cliente.id | Sí | No | — | Referencia a identidad.cliente.id. |
| `sesion_anonima_hash` | `bytea` | No | — | Sí | Sí | — | Huella de identificador secreto del carrito invitado. |
| `estado` | `text` | No | — | No | No | 'abierto' | Estado: abierto, convertido, abandonado. |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK estado IN ('abierto', 'convertido', 'abandonado')
- CHECK num_nonnulls(cliente_id, sesion_anonima_hash)=1; huella de 32 bytes cuando exista

**Unicidad y exclusión adicionales**

- Unicidad parcial cliente_id WHERE estado=abierto AND cliente_id IS NOT NULL: un carrito abierto por cliente.

**Reglas cruzadas y de operación**

- Transferir carrito a cliente requiere demostrar control de la sesión, retirando la huella anónima; no asignarlo a un correo sin verificar. Un carrito convertido no se modifica.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comercial.comprobante_factura

Archivo documental asociado a factura, sin presumir un pago.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `factura_id` | `bigint` | No | comercial.factura.id | No | No | — | Referencia a comercial.factura.id. |
| `archivo_id` | `bigint` | No | comunicacion.archivo.id | No | No | — | Referencia a comunicacion.archivo.id. |
| `clase_documento` | `text` | No | — | No | No | — | clase documento |
| `descripcion` | `text` | No | — | No | No | — | descripcion |
| `incorporado_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | incorporado en |

**Unicidad y exclusión adicionales**

- UNIQUE (factura_id, archivo_id).

**Reglas cruzadas y de operación**

- Archivo validado, privado y acceso por titularidad de factura. PDF/documento emitido puede incorporarse por esta asociación; no se duplica binario en factura.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comercial.cotizacion

Negociación que conserva versiones.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `numero` | `bigint` | No | — | No | Sí | Secuencia explícita comercial.seq_cotizacion | Consecutivo comercial. |
| `solicitud_cotizacion_id` | `bigint` | No | comercial.solicitud_cotizacion.id | Sí | Sí | — | Referencia a comercial.solicitud_cotizacion.id. |
| `persona_directa_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `estado` | `text` | No | — | No | No | 'abierta' | Estado: abierta, aceptada, cerrada, anulada. |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK estado IN ('abierta', 'aceptada', 'cerrada', 'anulada')
- CHECK num_nonnulls(solicitud_cotizacion_id, persona_directa_id)=1

**Reglas cruzadas y de operación**

- T08: destinatario se deriva de solicitud cuando existe; persona_directa_id se usa solo en cotización iniciada por la empresa. Así no se duplica una titularidad independiente. Al crear negociación crear al menos una versión; control diferible.
- Cabecera de negociación aceptada exige una versión aceptada; no guardar además version_aceptada_id redundante, se consulta mediante unicidad del estado.

**Normalización:** La titularidad se representa por una ruta exclusiva: solicitud o persona directa. Se elimina la dependencia transitiva solicitud -> persona dentro de cotizacion.

## comercial.detalle_carrito

Producto y cantidad solicitados en un carrito.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `carrito_id` | `bigint` | Sí (compuesta) | comercial.carrito.id | No | No | — | Referencia a comercial.carrito.id. |
| `producto_id` | `bigint` | Sí (compuesta) | inventario.producto.id | No | No | — | Referencia a inventario.producto.id. |
| `cantidad` | `numeric(14,3)` | No | — | No | No | — | cantidad |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK cantidad > 0
- CHECK cantidad <> 'NaN'::numeric

**Reglas cruzadas y de operación**

- Precios y existencias se consultan/revalidan. Solo se edita mientras carrito abierto; sincronizar modificación del carrito con conversión.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comercial.detalle_cotizacion

Concepto de producto, servicio técnico o descripción libre.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `version_cotizacion_id` | `bigint` | No | comercial.version_cotizacion.id | No | No | — | Referencia a comercial.version_cotizacion.id. |
| `numero_linea` | `integer` | No | — | No | No | — | numero linea |
| `clase` | `text` | No | — | No | No | — | producto, servicio o libre. |
| `producto_id` | `bigint` | No | inventario.producto.id | Sí | No | — | Referencia a inventario.producto.id. |
| `servicio_ofrecido_id` | `bigint` | No | servicios.servicio_ofrecido.id | Sí | No | — | Referencia a servicios.servicio_ofrecido.id. |
| `descripcion` | `text` | No | — | No | No | — | descripcion |
| `cantidad` | `numeric(14,3)` | No | — | No | No | — | Cantidad positiva del concepto. |
| `unidad` | `text` | No | — | No | No | — | Unidad histórica del concepto. |
| `precio_unitario` | `numeric(18,4)` | No | — | No | No | — | Precio neto unitario histórico. |
| `descuento_importe` | `numeric(18,2)` | No | — | No | No | 0 | Descuento absoluto neto de esta línea. |
| `tasa_impuesto` | `numeric(9,6)` | No | — | No | No | — | Tasa explícita en fracción: intervalo [0,1], sin default fiscal. |
| `subtotal` | `numeric(18,2)` | No | — | No | No | GENERADA STORED: (round(cantidad * precio_unitario, 2) - descuento_importe) | Base neta de línea. |
| `impuesto_importe` | `numeric(18,2)` | No | — | No | No | GENERADA STORED: (round((round(cantidad * precio_unitario, 2) - descuento_importe) * tasa_impuesto, 2)) | Impuesto de línea. |
| `total` | `numeric(18,2)` | No | — | No | No | GENERADA STORED: (round(cantidad * precio_unitario, 2) - descuento_importe) + (round((round(cantidad * precio_unitario, 2) - descuento_importe) * tasa_impuesto, 2)) | Importe total de línea. |

**Restricciones de fila**

- CHECK cantidad > 0; precio_unitario >= 0; descuento_importe >= 0; descuento_importe <= round(cantidad * precio_unitario,2)
- CHECK tasa_impuesto >= 0 AND tasa_impuesto <= 1; unidad y descripción no vacías
- CHECK clase IN ('producto','servicio','libre'); producto exige solo producto_id; servicio exige solo servicio_ofrecido_id; libre exige ambos NULL
- CHECK numero_linea > 0
- CHECK cantidad <> 'NaN'::numeric
- CHECK precio_unitario <> 'NaN'::numeric
- CHECK descuento_importe <> 'NaN'::numeric
- CHECK tasa_impuesto <> 'NaN'::numeric

**Unicidad y exclusión adicionales**

- UNIQUE (version_cotizacion_id, numero_linea).

**Reglas cruzadas y de operación**

- T08: solo editable mientras versión borrador. Conceptos libres cubren software a medida sin crear productos ficticios. Toda modificación/baja comprueba estado de versión bajo bloqueo, incluida la emisión concurrente.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comercial.detalle_factura

Concepto facturado con aplicación de cantidad o importe al origen.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `factura_id` | `bigint` | No | comercial.factura.id | No | No | — | Referencia a comercial.factura.id. |
| `numero_linea` | `integer` | No | — | No | No | — | numero linea |
| `detalle_pedido_id` | `bigint` | No | comercial.detalle_pedido.id | Sí | No | — | Referencia a comercial.detalle_pedido.id. |
| `detalle_cotizacion_id` | `bigint` | No | comercial.detalle_cotizacion.id | Sí | No | — | Referencia a comercial.detalle_cotizacion.id. |
| `descripcion` | `text` | No | — | No | No | — | descripcion |
| `cantidad` | `numeric(14,3)` | No | — | No | No | — | Cantidad positiva del concepto. |
| `unidad` | `text` | No | — | No | No | — | Unidad histórica del concepto. |
| `precio_unitario` | `numeric(18,4)` | No | — | No | No | — | Precio neto unitario histórico. |
| `descuento_importe` | `numeric(18,2)` | No | — | No | No | 0 | Descuento absoluto neto de esta línea. |
| `tasa_impuesto` | `numeric(9,6)` | No | — | No | No | — | Tasa explícita en fracción: intervalo [0,1], sin default fiscal. |
| `ajuste_base` | `numeric(18,2)` | No | — | No | No | 0 | Ajuste exclusivamente calculado para repartir importes históricos al aplicar o facturar parcialmente una fuente. |
| `ajuste_impuesto` | `numeric(18,2)` | No | — | No | No | 0 | Ajuste exclusivamente calculado para repartir impuesto histórico de la fuente. |
| `subtotal` | `numeric(18,2)` | No | — | No | No | GENERADA STORED: (round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base) | Base neta de línea. |
| `impuesto_importe` | `numeric(18,2)` | No | — | No | No | GENERADA STORED: (round((round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base) * tasa_impuesto, 2) + ajuste_impuesto) | Impuesto de línea. |
| `total` | `numeric(18,2)` | No | — | No | No | GENERADA STORED: (round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base) + (round((round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base) * tasa_impuesto, 2) + ajuste_impuesto) | Importe total de línea. |

**Restricciones de fila**

- CHECK cantidad > 0; precio_unitario >= 0; descuento_importe >= 0
- CHECK tasa_impuesto >= 0 AND tasa_impuesto <= 1; unidad y descripción no vacías
- CHECK numero_linea > 0; num_nonnulls(detalle_pedido_id,detalle_cotizacion_id) <= 1; subtotal >= 0; impuesto_importe >= 0
- CHECK cantidad <> 'NaN'::numeric
- CHECK precio_unitario <> 'NaN'::numeric
- CHECK descuento_importe <> 'NaN'::numeric
- CHECK tasa_impuesto <> 'NaN'::numeric
- CHECK ajuste_base <> 'NaN'::numeric
- CHECK ajuste_impuesto <> 'NaN'::numeric

**Unicidad y exclusión adicionales**

- UNIQUE (factura_id, numero_linea).

**Reglas cruzadas y de operación**

- T09: ruta pedido exige detalle_pedido de ese pedido y detalle_cotizacion NULL. Ruta orden/proyecto con cotización exige línea de su versión aceptada y detalle_pedido NULL. Ruta directa sin cotización exige ambas referencias NULL y consume importe base autorizado del origen.
- Las facturas de órdenes pueden usar conceptos servicio o libre coherentes con el trabajo; proyectos usan conceptos libres. Conceptos producto se facturan mediante pedidos. Para ruta cotizada se valida además su correspondencia con el servicio ofrecido cuando sea concepto servicio.
- Unidades e importes acumulados emitidos vigentes no exceden su fuente. Pedido consume cantidad cotizada al confirmarse; su facturación consume el pedido y no vuelve a contarse como aplicación adicional de la cotización. Órdenes/proyectos cotizados consumen directamente cantidades y economía de la línea cotizada al facturar.
- ajuste_base y ajuste_impuesto son calculados por el reparto acumulativo documentado, nunca importes libres editables por cliente. Precio/unidad/tasa y descripción se fijan desde fuente; descuento proporcional y ajustes aseguran que el último parcial cierre exactamente.
- La edición de detalles y la emisión deben bloquear la misma cabecera para impedir cambios concurrentes en documento emitido.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comercial.detalle_pedido

Línea comercial histórica vendida.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `pedido_id` | `bigint` | No | comercial.pedido.id | No | No | — | Referencia a comercial.pedido.id. |
| `numero_linea` | `integer` | No | — | No | No | — | numero linea |
| `producto_id` | `bigint` | No | inventario.producto.id | No | No | — | Referencia a inventario.producto.id. |
| `detalle_cotizacion_id` | `bigint` | No | comercial.detalle_cotizacion.id | Sí | No | — | Referencia a comercial.detalle_cotizacion.id. |
| `descripcion` | `text` | No | — | No | No | — | descripcion |
| `cantidad` | `numeric(14,3)` | No | — | No | No | — | Cantidad positiva del concepto. |
| `unidad` | `text` | No | — | No | No | — | Unidad histórica del concepto. |
| `precio_unitario` | `numeric(18,4)` | No | — | No | No | — | Precio neto unitario histórico. |
| `descuento_importe` | `numeric(18,2)` | No | — | No | No | 0 | Descuento absoluto neto de esta línea. |
| `tasa_impuesto` | `numeric(9,6)` | No | — | No | No | — | Tasa explícita en fracción: intervalo [0,1], sin default fiscal. |
| `ajuste_base` | `numeric(18,2)` | No | — | No | No | 0 | Ajuste exclusivamente calculado para repartir importes históricos al aplicar o facturar parcialmente una fuente. |
| `ajuste_impuesto` | `numeric(18,2)` | No | — | No | No | 0 | Ajuste exclusivamente calculado para repartir impuesto histórico de la fuente. |
| `subtotal` | `numeric(18,2)` | No | — | No | No | GENERADA STORED: (round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base) | Base neta de línea. |
| `impuesto_importe` | `numeric(18,2)` | No | — | No | No | GENERADA STORED: (round((round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base) * tasa_impuesto, 2) + ajuste_impuesto) | Impuesto de línea. |
| `total` | `numeric(18,2)` | No | — | No | No | GENERADA STORED: (round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base) + (round((round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base) * tasa_impuesto, 2) + ajuste_impuesto) | Importe total de línea. |

**Restricciones de fila**

- CHECK cantidad > 0; precio_unitario >= 0; descuento_importe >= 0
- CHECK tasa_impuesto >= 0 AND tasa_impuesto <= 1; unidad y descripción no vacías
- CHECK numero_linea > 0; subtotal >= 0; impuesto_importe >= 0
- CHECK cantidad <> 'NaN'::numeric
- CHECK precio_unitario <> 'NaN'::numeric
- CHECK descuento_importe <> 'NaN'::numeric
- CHECK tasa_impuesto <> 'NaN'::numeric
- CHECK ajuste_base <> 'NaN'::numeric
- CHECK ajuste_impuesto <> 'NaN'::numeric

**Unicidad y exclusión adicionales**

- UNIQUE (pedido_id, numero_linea).

**Reglas cruzadas y de operación**

- T07: precio/unidad/tasa/descripción históricos no dependen del catálogo actual. Al confirmar validar cantidades/condiciones de cotización si corresponde y capacidad global de su línea. Ajustes son cero en pedidos directos; en pedidos cotizados solo resultan del reparto acumulativo de la fuente, para conservar centavos y descuentos al dividir cantidades. Después no se actualizan ni borran; se conserva evidencia.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comercial.factura

Documento comercial con un origen principal y receptor histórico.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `numero` | `bigint` | No | — | Sí | Sí | —; al emitir: secuencia explícita comercial.seq_factura | Número asignado al emitir; no es garantía de secuencia fiscal sin saltos. |
| `pedido_id` | `bigint` | No | comercial.pedido.id | Sí | No | — | Referencia a comercial.pedido.id. |
| `orden_servicio_id` | `bigint` | No | servicios.orden_servicio.id | Sí | No | — | Referencia a servicios.orden_servicio.id. |
| `proyecto_id` | `bigint` | No | proyectos.proyecto.id | Sí | No | — | Referencia a proyectos.proyecto.id. |
| `estado` | `text` | No | — | No | No | 'borrador' | Estado: borrador, emitida, anulada. |
| `moneda` | `text` | No | — | No | No | — | Código monetario de tres letras mayúsculas; sin moneda predeterminada. |
| `receptor_nombre` | `text` | No | — | No | No | — | receptor nombre |
| `receptor_identificacion` | `text` | No | — | Sí | No | — | receptor identificacion |
| `receptor_correo` | `text` | No | — | Sí | No | — | receptor correo |
| `receptor_telefono` | `text` | No | — | Sí | No | — | receptor telefono |
| `receptor_direccion` | `text` | No | — | Sí | No | — | receptor direccion |
| `emitida_en` | `timestamptz` | No | — | Sí | No | — | emitida en |
| `anulada_en` | `timestamptz` | No | — | Sí | No | — | anulada en |
| `motivo_anulacion` | `text` | No | — | Sí | No | — | motivo anulacion |
| `operacion_emision_id` | `uuid` | No | — | Sí | Sí | — | operacion emision id |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK estado IN ('borrador', 'emitida', 'anulada')
- CHECK num_nonnulls(pedido_id, orden_servicio_id, proyecto_id)=1; moneda tres mayúsculas
- CHECK emitida/anulada exige numero, emitida_en y operacion_emision_id; borrador no los tiene; anulada exige anulada_en >= emitida_en y motivo

**Reglas cruzadas y de operación**

- T09: cliente se deriva del origen y no se duplica en factura. Receptor_nombre/identificacion/contacto describen el documento emitido, no otra identidad de acceso. Origen/titularidad no se reasignan tras emisión.
- Emitir exige líneas, moneda y autorización económica compatibles, bloqueo del origen y fuentes cotizadas, límites acumulados y número único. Documento emitido no se modifica ni elimina. Anulación conserva evidencia; sus importes dejan de consumir capacidad de facturación solamente mediante transición autorizada y auditada. No se afirma que sea una regla fiscal legal.

**Normalización:** Se elimina cliente_id transitivo porque deriva del origen exclusivo. El receptor histórico es snapshot documental con significado temporal distinto.

## comercial.historial_cotizacion

Historial explícito e inmutable de comercial.cotizacion.id.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `cotizacion_id` | `bigint` | No | comercial.cotizacion.id | No | No | — | Referencia a comercial.cotizacion.id. |
| `numero_evento` | `integer` | No | — | No | No | — | Ordinal por proceso para un orden inequívoco. |
| `estado_anterior` | `text` | No | — | Sí | No | — | estado anterior |
| `estado_nuevo` | `text` | No | — | No | No | — | estado nuevo |
| `motivo` | `text` | No | — | No | No | — | motivo |
| `correlacion_id` | `uuid` | No | — | No | No | — | Identificador de la operación autenticada. |
| `ocurrido_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | ocurrido en |
| `actor_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `actor_sistema` | `text` | No | — | Sí | No | — | Proceso automático responsable cuando no hay iniciador humano. |
| `version_cotizacion_id` | `bigint` | No | comercial.version_cotizacion.id | Sí | No | — | Referencia a comercial.version_cotizacion.id. |
| `estado_version_anterior` | `text` | No | — | Sí | No | — | estado version anterior |
| `estado_version_nuevo` | `text` | No | — | Sí | No | — | estado version nuevo |

**Restricciones de fila**

- CHECK numero_evento > 0; evento 1 exige estado_anterior NULL; posteriores exigen estado_anterior NOT NULL
- CHECK estado_anterior si existe y estado_nuevo pertenecen a: abierta, aceptada, cerrada, anulada
- CHECK num_nonnulls(actor_persona_id, actor_sistema) = 1; actor_sistema no vacío si existe.

**Unicidad y exclusión adicionales**

- UNIQUE (cotizacion_id, numero_evento).

**Reglas cruzadas y de operación**

- T14: crear proceso y evento inicial en la misma transacción; cada transición añade ordinal consecutivo bajo bloqueo del proceso, estado anterior coincide con último evento y nuevo con estado final. No se permiten UPDATE/DELETE del historial ni cambios libres del estado principal.
- En historial_cotizacion, evento de versión precisa estado anterior/nuevo de versión entre borrador, enviada, reemplazada, aceptada, rechazada, anulada, y versión de la misma cotización; puede mantener estado general igual si solo cambia versión.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comercial.historial_factura

Historial explícito e inmutable de comercial.factura.id.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `factura_id` | `bigint` | No | comercial.factura.id | No | No | — | Referencia a comercial.factura.id. |
| `numero_evento` | `integer` | No | — | No | No | — | Ordinal por proceso para un orden inequívoco. |
| `estado_anterior` | `text` | No | — | Sí | No | — | estado anterior |
| `estado_nuevo` | `text` | No | — | No | No | — | estado nuevo |
| `motivo` | `text` | No | — | No | No | — | motivo |
| `correlacion_id` | `uuid` | No | — | No | No | — | Identificador de la operación autenticada. |
| `ocurrido_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | ocurrido en |
| `actor_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `actor_sistema` | `text` | No | — | Sí | No | — | Proceso automático responsable cuando no hay iniciador humano. |

**Restricciones de fila**

- CHECK numero_evento > 0; evento 1 exige estado_anterior NULL; posteriores exigen estado_anterior NOT NULL
- CHECK estado_anterior si existe y estado_nuevo pertenecen a: borrador, emitida, anulada
- CHECK num_nonnulls(actor_persona_id, actor_sistema) = 1; actor_sistema no vacío si existe.

**Unicidad y exclusión adicionales**

- UNIQUE (factura_id, numero_evento).

**Reglas cruzadas y de operación**

- T14: crear proceso y evento inicial en la misma transacción; cada transición añade ordinal consecutivo bajo bloqueo del proceso, estado anterior coincide con último evento y nuevo con estado final. No se permiten UPDATE/DELETE del historial ni cambios libres del estado principal.
- Se registra solo transición efectiva de estado, aparte del evento inicial.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comercial.historial_pedido

Historial explícito e inmutable de comercial.pedido.id.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `pedido_id` | `bigint` | No | comercial.pedido.id | No | No | — | Referencia a comercial.pedido.id. |
| `numero_evento` | `integer` | No | — | No | No | — | Ordinal por proceso para un orden inequívoco. |
| `estado_anterior` | `text` | No | — | Sí | No | — | estado anterior |
| `estado_nuevo` | `text` | No | — | No | No | — | estado nuevo |
| `motivo` | `text` | No | — | No | No | — | motivo |
| `correlacion_id` | `uuid` | No | — | No | No | — | Identificador de la operación autenticada. |
| `ocurrido_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | ocurrido en |
| `actor_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `actor_sistema` | `text` | No | — | Sí | No | — | Proceso automático responsable cuando no hay iniciador humano. |

**Restricciones de fila**

- CHECK numero_evento > 0; evento 1 exige estado_anterior NULL; posteriores exigen estado_anterior NOT NULL
- CHECK estado_anterior si existe y estado_nuevo pertenecen a: borrador, confirmado, en_preparacion, completado, cancelado
- CHECK num_nonnulls(actor_persona_id, actor_sistema) = 1; actor_sistema no vacío si existe.

**Unicidad y exclusión adicionales**

- UNIQUE (pedido_id, numero_evento).

**Reglas cruzadas y de operación**

- T14: crear proceso y evento inicial en la misma transacción; cada transición añade ordinal consecutivo bajo bloqueo del proceso, estado anterior coincide con último evento y nuevo con estado final. No se permiten UPDATE/DELETE del historial ni cambios libres del estado principal.
- Se registra solo transición efectiva de estado, aparte del evento inicial.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comercial.historial_solicitud_cotizacion

Historial explícito e inmutable de comercial.solicitud_cotizacion.id.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `solicitud_cotizacion_id` | `bigint` | No | comercial.solicitud_cotizacion.id | No | No | — | Referencia a comercial.solicitud_cotizacion.id. |
| `numero_evento` | `integer` | No | — | No | No | — | Ordinal por proceso para un orden inequívoco. |
| `estado_anterior` | `text` | No | — | Sí | No | — | estado anterior |
| `estado_nuevo` | `text` | No | — | No | No | — | estado nuevo |
| `motivo` | `text` | No | — | No | No | — | motivo |
| `correlacion_id` | `uuid` | No | — | No | No | — | Identificador de la operación autenticada. |
| `ocurrido_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | ocurrido en |
| `actor_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `actor_sistema` | `text` | No | — | Sí | No | — | Proceso automático responsable cuando no hay iniciador humano. |

**Restricciones de fila**

- CHECK numero_evento > 0; evento 1 exige estado_anterior NULL; posteriores exigen estado_anterior NOT NULL
- CHECK estado_anterior si existe y estado_nuevo pertenecen a: recibida, en_evaluacion, atendida, rechazada, cancelada
- CHECK num_nonnulls(actor_persona_id, actor_sistema) = 1; actor_sistema no vacío si existe.

**Unicidad y exclusión adicionales**

- UNIQUE (solicitud_cotizacion_id, numero_evento).

**Reglas cruzadas y de operación**

- T14: crear proceso y evento inicial en la misma transacción; cada transición añade ordinal consecutivo bajo bloqueo del proceso, estado anterior coincide con último evento y nuevo con estado final. No se permiten UPDATE/DELETE del historial ni cambios libres del estado principal.
- Se registra solo transición efectiva de estado, aparte del evento inicial.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comercial.pedido

Venta con condiciones históricas y cliente sin cuenta obligatoria.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `numero` | `bigint` | No | — | No | Sí | Secuencia explícita comercial.seq_pedido | Consecutivo comercial. |
| `cliente_id` | `bigint` | No | identidad.cliente.id | No | No | — | Referencia a identidad.cliente.id. |
| `carrito_id` | `bigint` | No | comercial.carrito.id | Sí | Sí | — | Referencia a comercial.carrito.id. |
| `version_cotizacion_id` | `bigint` | No | comercial.version_cotizacion.id | Sí | No | — | Referencia a comercial.version_cotizacion.id. |
| `estado` | `text` | No | — | No | No | 'borrador' | Estado: borrador, confirmado, en_preparacion, completado, cancelado. |
| `moneda` | `text` | No | — | No | No | — | Código monetario de tres letras mayúsculas; sin moneda predeterminada. |
| `receptor_nombre` | `text` | No | — | No | No | — | receptor nombre |
| `receptor_correo` | `text` | No | — | Sí | No | — | receptor correo |
| `receptor_telefono` | `text` | No | — | Sí | No | — | receptor telefono |
| `confirmado_en` | `timestamptz` | No | — | Sí | No | — | confirmado en |
| `completado_en` | `timestamptz` | No | — | Sí | No | — | completado en |
| `cancelado_en` | `timestamptz` | No | — | Sí | No | — | cancelado en |
| `motivo_cancelacion` | `text` | No | — | Sí | No | — | motivo cancelacion |
| `operacion_confirmacion_id` | `uuid` | No | — | Sí | Sí | — | operacion confirmacion id |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK estado IN ('borrador', 'confirmado', 'en_preparacion', 'completado', 'cancelado')
- CHECK moneda tiene tres mayúsculas; receptor_nombre no vacío; al menos un canal de contacto
- CHECK confirmado/en_preparacion/completado exige confirmado_en y operacion_confirmacion_id; completado exige completado_en >= confirmado_en; cancelado exige cancelado_en y motivo

**Reglas cruzadas y de operación**

- T06/T07: confirmar exige líneas, disponibilidad y economía validada; congela titular, moneda y líneas. Carrito de mismo cliente si existe. Cancelación confirmada requiere no tener facturas emitidas vigentes y liberar reservas; no cancelar pedidos completados en el flujo actual.
- Si procede de cotización, la versión está aceptada y corresponde a la persona del cliente; todas las líneas se vinculan a conceptos de producto de esa versión. Pedidos directos no tienen referencias a líneas cotizadas.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comercial.solicitud_cotizacion

Necesidad de cotización de persona sin cliente o usuario obligatorio.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `codigo` | `text` | No | — | No | Sí | — | Código de negocio estable; unicidad independiente de la PK. |
| `persona_id` | `bigint` | No | identidad.persona.id | No | No | — | Referencia a identidad.persona.id. |
| `necesidad` | `text` | No | — | No | No | — | necesidad |
| `contacto_nombre` | `text` | No | — | No | No | — | contacto nombre |
| `contacto_correo` | `text` | No | — | Sí | No | — | contacto correo |
| `contacto_telefono` | `text` | No | — | Sí | No | — | contacto telefono |
| `estado` | `text` | No | — | No | No | 'recibida' | Estado: recibida, en_evaluacion, atendida, rechazada, cancelada. |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK estado IN ('recibida', 'en_evaluacion', 'atendida', 'rechazada', 'cancelada')
- CHECK contacto_nombre/necesidad no vacíos; al menos un canal de contacto

**Reglas cruzadas y de operación**

- Contacto recibido es snapshot de la solicitud; no una copia editable del maestro. Titular se verifica para vincular a cuentas.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comercial.version_cotizacion

Oferta económica inmutable una vez enviada.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `cotizacion_id` | `bigint` | No | comercial.cotizacion.id | No | No | — | Referencia a comercial.cotizacion.id. |
| `numero_version` | `integer` | No | — | No | No | — | numero version |
| `estado` | `text` | No | — | No | No | 'borrador' | Estado: borrador, enviada, reemplazada, aceptada, rechazada, anulada. |
| `moneda` | `text` | No | — | No | No | — | Código monetario de tres letras mayúsculas; sin moneda predeterminada. |
| `condiciones` | `text` | No | — | No | No | — | condiciones |
| `destinatario_nombre` | `text` | No | — | No | No | — | destinatario nombre |
| `destinatario_correo` | `text` | No | — | Sí | No | — | destinatario correo |
| `destinatario_telefono` | `text` | No | — | Sí | No | — | destinatario telefono |
| `enviada_en` | `timestamptz` | No | — | Sí | No | — | enviada en |
| `vigente_hasta` | `timestamptz` | No | — | No | No | — | vigente hasta |
| `respondida_en` | `timestamptz` | No | — | Sí | No | — | respondida en |
| `respondida_por_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `evidencia_respuesta` | `text` | No | — | Sí | No | — | evidencia respuesta |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK estado IN ('borrador', 'enviada', 'reemplazada', 'aceptada', 'rechazada', 'anulada')
- CHECK numero_version > 0; moneda tres mayúsculas; vigente_hasta > created_at; enviada_en IS NULL OR vigente_hasta > enviada_en
- CHECK aceptada/rechazada exige respondida_en, respondida_por_persona_id, enviada_en y evidencia; otros estados no guardan respuesta; respondida_en >= enviada_en y <= vigente_hasta

**Unicidad y exclusión adicionales**

- UNIQUE (cotizacion_id, numero_version).
- Unicidad parcial cotizacion_id WHERE estado=aceptada.
- Unicidad parcial cotizacion_id WHERE estado=enviada.
- Unicidad parcial cotizacion_id WHERE estado=borrador.

**Reglas cruzadas y de operación**

- T08: responder requiere verificar vigencia contra reloj dentro de transacción, identidad titular y versión enviada vigente, bloqueando cotización/versión. No CHECK con now().
- Solo una versión enviada a la vez; enviar otra reemplaza la anterior sin alterar su contenido. No se revisa tras aceptación en este alcance; cambios requieren nueva negociación que no sustituya evidencia aceptada. Enviar exige al menos un detalle y contacto.
- Estado identifica la decisión; no añadir columna decision que pudiera contradecirlo. Contenido económico, destinatario, vigencia y líneas quedan inmutables al enviar; solo transiciones y evidencia de respuesta se autorizan.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## servicios.asignacion_servicio

Participación temporal de un empleado en una orden.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `orden_servicio_id` | `bigint` | No | servicios.orden_servicio.id | No | No | — | Referencia a servicios.orden_servicio.id. |
| `empleado_id` | `bigint` | No | identidad.empleado.id | No | No | — | Referencia a identidad.empleado.id. |
| `funcion` | `text` | No | — | No | No | — | funcion |
| `es_principal` | `boolean` | No | — | No | No | false | es principal |
| `inicia_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | inicia en |
| `termina_en` | `timestamptz` | No | — | Sí | No | — | termina en |
| `actor_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `actor_sistema` | `text` | No | — | Sí | No | — | Proceso automático responsable cuando no hay iniciador humano. |

**Restricciones de fila**

- CHECK termina_en IS NULL OR termina_en > inicia_en
- CHECK num_nonnulls(actor_persona_id, actor_sistema) = 1; actor_sistema no vacío si existe.

**Unicidad y exclusión adicionales**

- EXCLUDE: no solapar períodos para la misma orden/empleado.
- EXCLUDE parcial: no solapar períodos principales de la misma orden, entre cualesquiera empleados.

**Reglas cruzadas y de operación**

- T02: cambios de responsables atómicos, sin dejar temporalmente una orden ejecutándose sin responsable al cerrar la transacción. Son períodos efectivos, no asignaciones futuras: no se programa fin que haga desaparecer el responsable por paso del tiempo.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## servicios.calificacion_servicio

Valoración de un servicio propio finalizado.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `orden_servicio_id` | `bigint` | Sí | servicios.orden_servicio.id | No | Sí (PK) | — | Referencia a servicios.orden_servicio.id. |
| `autor_persona_id` | `bigint` | No | identidad.persona.id | No | No | — | Referencia a identidad.persona.id. |
| `puntuacion` | `smallint` | No | — | No | No | — | puntuacion |
| `comentario` | `text` | No | — | Sí | No | — | comentario |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK puntuacion BETWEEN 1 AND 5

**Reglas cruzadas y de operación**

- T04: escala 1–5 propuesta para esta fase; una valoración por orden. Autor debe ser persona del cliente titular y orden finalizada. No guardar además cliente_id, que se deriva de orden/solicitud. Invitado debe acreditar acceso de valoración. Edición por titular conserva auditoría.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## servicios.cita_servicio

Visita de una solicitud, incluso anterior a su orden.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `solicitud_servicio_id` | `bigint` | No | servicios.solicitud_servicio.id | No | No | — | Referencia a servicios.solicitud_servicio.id. |
| `tecnico_id` | `bigint` | No | identidad.empleado.id | Sí | No | — | Referencia a identidad.empleado.id. |
| `inicio` | `timestamptz` | No | — | No | No | — | inicio |
| `fin` | `timestamptz` | No | — | No | No | — | fin |
| `estado` | `text` | No | — | No | No | 'propuesta' | Estado: propuesta, confirmada, realizada, cancelada. |
| `modalidad_atencion` | `text` | No | — | No | No | — | presencial o remota. |
| `lugar` | `text` | No | — | Sí | No | — | lugar |
| `motivo_cancelacion` | `text` | No | — | Sí | No | — | motivo cancelacion |
| `sustituye_cita_id` | `bigint` | No | servicios.cita_servicio.id | Sí | Sí | — | Referencia a servicios.cita_servicio.id. |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK estado IN ('propuesta', 'confirmada', 'realizada', 'cancelada')
- CHECK modalidad_atencion IN ('presencial','remota'); fin > inicio
- CHECK estado NOT IN ('confirmada','realizada') OR tecnico_id IS NOT NULL; presencial exige lugar no vacío; cancelada exige motivo

**Unicidad y exclusión adicionales**

- EXCLUDE parcial: mismo tecnico_id e intervalos [inicio,fin) solapados con estado confirmada o realizada.

**Reglas cruzadas y de operación**

- T03: confirmar exige ventana habilitada que contenga [inicio,fin), técnico habilitado y solicitud no cancelada/rechazada. La cita sustituta pertenece a la misma solicitud y no puede sustituirse a sí misma; se cancela la anterior y crea nueva sin perderla.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## servicios.disponibilidad_tecnico

Ventana concreta de disponibilidad de un empleado.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `empleado_id` | `bigint` | No | identidad.empleado.id | No | No | — | Referencia a identidad.empleado.id. |
| `inicio` | `timestamptz` | No | — | No | No | — | inicio |
| `fin` | `timestamptz` | No | — | No | No | — | fin |
| `habilitada` | `boolean` | No | — | No | No | true | habilitada |
| `observaciones` | `text` | No | — | Sí | No | — | observaciones |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK fin > inicio

**Unicidad y exclusión adicionales**

- EXCLUDE parcial: intervalos [inicio,fin) habilitados del mismo empleado no se solapan.

**Reglas cruzadas y de operación**

- T03: modificar/eliminar/deshabilitar ventanas debe preservar las citas confirmadas futuras; coordinar cambios y confirmaciones bloqueando el mismo empleado.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## servicios.equipo_cliente

Equipo del cliente atendido; independiente del inventario de venta.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `cliente_id` | `bigint` | No | identidad.cliente.id | No | No | — | Referencia a identidad.cliente.id. |
| `tipo` | `text` | No | — | No | No | — | tipo |
| `marca` | `text` | No | — | Sí | No | — | marca |
| `modelo` | `text` | No | — | Sí | No | — | modelo |
| `numero_serie` | `text` | No | — | Sí | No | — | numero serie |
| `descripcion` | `text` | No | — | No | No | — | descripcion |
| `activo` | `boolean` | No | — | No | No | true | activo |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Reglas cruzadas y de operación**

- La serie no se presume mundialmente única ni obligatoria. Cambiar titular con solicitudes históricas requiere una política explícita; inicialmente se impide.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## servicios.historial_servicio

Historial explícito e inmutable de servicios.orden_servicio.id.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `orden_servicio_id` | `bigint` | No | servicios.orden_servicio.id | No | No | — | Referencia a servicios.orden_servicio.id. |
| `numero_evento` | `integer` | No | — | No | No | — | Ordinal por proceso para un orden inequívoco. |
| `estado_anterior` | `text` | No | — | Sí | No | — | estado anterior |
| `estado_nuevo` | `text` | No | — | No | No | — | estado nuevo |
| `motivo` | `text` | No | — | No | No | — | motivo |
| `correlacion_id` | `uuid` | No | — | No | No | — | Identificador de la operación autenticada. |
| `ocurrido_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | ocurrido en |
| `actor_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `actor_sistema` | `text` | No | — | Sí | No | — | Proceso automático responsable cuando no hay iniciador humano. |

**Restricciones de fila**

- CHECK numero_evento > 0; evento 1 exige estado_anterior NULL; posteriores exigen estado_anterior NOT NULL
- CHECK estado_anterior si existe y estado_nuevo pertenecen a: pendiente_asignacion, asignada, en_ejecucion, pausada, finalizada, cancelada
- CHECK num_nonnulls(actor_persona_id, actor_sistema) = 1; actor_sistema no vacío si existe.

**Unicidad y exclusión adicionales**

- UNIQUE (orden_servicio_id, numero_evento).

**Reglas cruzadas y de operación**

- T14: crear proceso y evento inicial en la misma transacción; cada transición añade ordinal consecutivo bajo bloqueo del proceso, estado anterior coincide con último evento y nuevo con estado final. No se permiten UPDATE/DELETE del historial ni cambios libres del estado principal.
- Se registra solo transición efectiva de estado, aparte del evento inicial.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## servicios.historial_solicitud_servicio

Historial explícito e inmutable de servicios.solicitud_servicio.id.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `solicitud_servicio_id` | `bigint` | No | servicios.solicitud_servicio.id | No | No | — | Referencia a servicios.solicitud_servicio.id. |
| `numero_evento` | `integer` | No | — | No | No | — | Ordinal por proceso para un orden inequívoco. |
| `estado_anterior` | `text` | No | — | Sí | No | — | estado anterior |
| `estado_nuevo` | `text` | No | — | No | No | — | estado nuevo |
| `motivo` | `text` | No | — | No | No | — | motivo |
| `correlacion_id` | `uuid` | No | — | No | No | — | Identificador de la operación autenticada. |
| `ocurrido_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | ocurrido en |
| `actor_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `actor_sistema` | `text` | No | — | Sí | No | — | Proceso automático responsable cuando no hay iniciador humano. |

**Restricciones de fila**

- CHECK numero_evento > 0; evento 1 exige estado_anterior NULL; posteriores exigen estado_anterior NOT NULL
- CHECK estado_anterior si existe y estado_nuevo pertenecen a: recibida, en_evaluacion, aceptada, rechazada, cancelada
- CHECK num_nonnulls(actor_persona_id, actor_sistema) = 1; actor_sistema no vacío si existe.

**Unicidad y exclusión adicionales**

- UNIQUE (solicitud_servicio_id, numero_evento).

**Reglas cruzadas y de operación**

- T14: crear proceso y evento inicial en la misma transacción; cada transición añade ordinal consecutivo bajo bloqueo del proceso, estado anterior coincide con último evento y nuevo con estado final. No se permiten UPDATE/DELETE del historial ni cambios libres del estado principal.
- Se registra solo transición efectiva de estado, aparte del evento inicial.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## servicios.mantenimiento

Datos exclusivos del mantenimiento.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `orden_servicio_id` | `bigint` | Sí | servicios.orden_servicio.id | No | Sí (PK) | — | Referencia a servicios.orden_servicio.id. |
| `tipo_mantenimiento` | `text` | No | — | No | No | — | tipo mantenimiento |
| `actividades_realizadas` | `text` | No | — | Sí | No | — | actividades realizadas |
| `hallazgos` | `text` | No | — | Sí | No | — | hallazgos |
| `recomendaciones` | `text` | No | — | Sí | No | — | recomendaciones |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Reglas cruzadas y de operación**

- T02: modalidad coherente y excluyente con reparación. Finalizar requiere actividades realizadas; sin hallazgos se registra explícitamente que no se detectaron.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## servicios.orden_servicio

Trabajo autorizado procedente de una solicitud.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `codigo` | `text` | No | — | No | Sí | — | Código de negocio estable; unicidad independiente de la PK. |
| `solicitud_servicio_id` | `bigint` | No | servicios.solicitud_servicio.id | No | Sí | — | Referencia a servicios.solicitud_servicio.id. |
| `estado` | `text` | No | — | No | No | 'pendiente_asignacion' | Estado: pendiente_asignacion, asignada, en_ejecucion, pausada, finalizada, cancelada. |
| `iniciada_en` | `timestamptz` | No | — | Sí | No | — | iniciada en |
| `finalizada_en` | `timestamptz` | No | — | Sí | No | — | finalizada en |
| `resumen_trabajo` | `text` | No | — | Sí | No | — | resumen trabajo |
| `observaciones_cierre` | `text` | No | — | Sí | No | — | observaciones cierre |
| `version_cotizacion_id` | `bigint` | No | comercial.version_cotizacion.id | Sí | No | — | Referencia a comercial.version_cotizacion.id. |
| `importe_base_autorizado` | `numeric(18,2)` | No | — | Sí | No | — | Techo neto para facturación directa, cuando no hay cotización. |
| `tasa_impuesto_autorizada` | `numeric(9,6)` | No | — | Sí | No | — | Tasa fraccional única de la autorización directa. |
| `moneda` | `text` | No | — | Sí | No | — | Código monetario de tres letras mayúsculas; sin moneda predeterminada. |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK estado IN ('pendiente_asignacion', 'asignada', 'en_ejecucion', 'pausada', 'finalizada', 'cancelada')
- CHECK estado IN ('en_ejecucion','pausada','finalizada') exige iniciada_en; finalizada exige finalizada_en y resumen_trabajo no vacío
- CHECK finalizada_en IS NULL OR (iniciada_en IS NOT NULL AND finalizada_en >= iniciada_en)
- CHECK ruta económica exclusiva: con version_cotizacion_id, importe_base_autorizado/tasa_impuesto_autorizada/moneda son NULL; sin versión, los tres son NOT NULL
- CHECK importe_base_autorizado >= 0 y tasa_impuesto_autorizada entre 0 y 1 cuando existan; moneda cumple tres mayúsculas
- CHECK importe_base_autorizado <> 'NaN'::numeric cuando no sea NULL
- CHECK tasa_impuesto_autorizada <> 'NaN'::numeric cuando no sea NULL

**Reglas cruzadas y de operación**

- T02: solicitud aceptada, exactamente un subtipo coherente reparación/mantenimiento y responsable principal al ejecutar. Validaciones diferibles sobre orden, solicitud, subtipo y asignación; las bajas de empleado/usuario tampoco pueden dejar una orden ejecutándose sin responsable habilitado.
- Titular se deriva de solicitud; no se duplica cliente_id. La autorización económica se congela al iniciar facturación; ruta cotizada utiliza líneas elegibles de la versión aceptada, sin copiar su total global.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## servicios.reparacion

Datos exclusivos de la reparación.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `orden_servicio_id` | `bigint` | Sí | servicios.orden_servicio.id | No | Sí (PK) | — | Referencia a servicios.orden_servicio.id. |
| `diagnostico` | `text` | No | — | Sí | No | — | diagnostico |
| `falla_determinada` | `text` | No | — | Sí | No | — | falla determinada |
| `solucion` | `text` | No | — | Sí | No | — | solucion |
| `resultado_pruebas` | `text` | No | — | Sí | No | — | resultado pruebas |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Reglas cruzadas y de operación**

- T02: especialización total y excluyente con mantenimiento. Al finalizar se exigen diagnóstico, solución y resultado no vacíos; un CHECK de esta fila no puede comprobar el estado de orden.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## servicios.servicio_ofrecido

Oferta pública de reparación o mantenimiento.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `codigo` | `text` | No | — | No | Sí | — | Código de negocio estable; unicidad independiente de la PK. |
| `nombre` | `text` | No | — | No | No | — | nombre |
| `descripcion` | `text` | No | — | No | No | — | descripcion |
| `modalidad` | `text` | No | — | No | No | — | modalidad |
| `duracion_estimada_min` | `integer` | No | — | Sí | No | — | duracion estimada min |
| `precio_referencia` | `numeric(18,2)` | No | — | Sí | No | — | precio referencia |
| `moneda` | `text` | No | — | Sí | No | — | Código monetario de tres letras mayúsculas; sin moneda predeterminada. |
| `publicado` | `boolean` | No | — | No | No | false | publicado |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK modalidad IN ('reparacion','mantenimiento')
- CHECK duracion_estimada_min > 0 cuando exista; precio_referencia >= 0 cuando exista; precio_referencia/moneda ambos NULL o ambos informados
- CHECK precio_referencia <> 'NaN'::numeric cuando no sea NULL

**Reglas cruzadas y de operación**

- La modalidad no se cambia mientras existan solicitudes vinculadas; se crea otra oferta para una modalidad distinta. Así solicitud no duplica modalidad.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## servicios.solicitud_servicio

Recepción de una necesidad técnica, con o sin cuenta.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `codigo` | `text` | No | — | No | Sí | — | Código de negocio estable; unicidad independiente de la PK. |
| `cliente_id` | `bigint` | No | identidad.cliente.id | No | No | — | Referencia a identidad.cliente.id. |
| `servicio_ofrecido_id` | `bigint` | No | servicios.servicio_ofrecido.id | No | No | — | Referencia a servicios.servicio_ofrecido.id. |
| `equipo_cliente_id` | `bigint` | No | servicios.equipo_cliente.id | Sí | No | — | Referencia a servicios.equipo_cliente.id. |
| `necesidad` | `text` | No | — | No | No | — | necesidad |
| `alcance` | `text` | No | — | Sí | No | — | alcance |
| `fecha_preferida` | `timestamptz` | No | — | Sí | No | — | fecha preferida |
| `estado` | `text` | No | — | No | No | 'recibida' | Estado: recibida, en_evaluacion, aceptada, rechazada, cancelada. |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK estado IN ('recibida', 'en_evaluacion', 'aceptada', 'rechazada', 'cancelada')

**Reglas cruzadas y de operación**

- T01: según modalidad del servicio ofrecido, reparación exige equipo del mismo cliente; mantenimiento sin equipo exige alcance no vacío. La regla se protege también al alterar servicio/equipo/titular. Una preferencia de fecha no confirma cita.
- Cambios de estado generan historial; solicitud aceptada no significa trabajo finalizado.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## proyectos.avance_proyecto

Reporte histórico de progreso de una etapa.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `etapa_proyecto_id` | `bigint` | No | proyectos.etapa_proyecto.id | No | No | — | Referencia a proyectos.etapa_proyecto.id. |
| `miembro_proyecto_id` | `bigint` | No | proyectos.miembro_proyecto.id | No | No | — | Referencia a proyectos.miembro_proyecto.id. |
| `porcentaje` | `numeric(5,2)` | No | — | No | No | — | porcentaje |
| `descripcion` | `text` | No | — | No | No | — | descripcion |
| `observaciones` | `text` | No | — | Sí | No | — | observaciones |
| `registrado_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | registrado en |

**Restricciones de fila**

- CHECK porcentaje BETWEEN 0 AND 100
- CHECK porcentaje <> 'NaN'::numeric

**Reglas cruzadas y de operación**

- T05: miembro habilitado del mismo proyecto, con participación vigente al registrar. Reportes append-only; correcciones mediante otro reporte. Último reporte por (registrado_en DESC,id DESC), fecha asignada por servidor sin backdating arbitrario. No se fuerza aumento monotónico: una revisión puede reducir porcentaje con explicación.
- Avance global = sum(peso * último porcentaje)/sum(peso); ausencia de reporte=0 y ausencia de etapas=0. Derivado, no persistido en proyecto.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## proyectos.etapa_proyecto

Etapa ponderada del alcance aprobado.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `proyecto_id` | `bigint` | No | proyectos.proyecto.id | No | No | — | Referencia a proyectos.proyecto.id. |
| `nombre` | `text` | No | — | No | No | — | nombre |
| `descripcion` | `text` | No | — | No | No | — | descripcion |
| `orden` | `integer` | No | — | No | No | — | orden |
| `peso` | `numeric(9,4)` | No | — | No | No | — | peso |
| `inicio_planificado` | `date` | No | — | Sí | No | — | inicio planificado |
| `fin_planificado` | `date` | No | — | Sí | No | — | fin planificado |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK orden > 0; peso > 0; fin_planificado >= inicio_planificado cuando ambas existan
- CHECK peso <> 'NaN'::numeric

**Unicidad y exclusión adicionales**

- UNIQUE (proyecto_id, orden).

**Reglas cruzadas y de operación**

- T05: proyecto_id de etapa es inmutable. Peso/orden/alcance solo cambian mediante revisión registrada tras iniciar ejecución; se prohíbe borrar etapas con reportes. No almacena porcentaje actual.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## proyectos.historial_proyecto

Historial explícito e inmutable de proyectos.proyecto.id.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `proyecto_id` | `bigint` | No | proyectos.proyecto.id | No | No | — | Referencia a proyectos.proyecto.id. |
| `numero_evento` | `integer` | No | — | No | No | — | Ordinal por proceso para un orden inequívoco. |
| `estado_anterior` | `text` | No | — | Sí | No | — | estado anterior |
| `estado_nuevo` | `text` | No | — | No | No | — | estado nuevo |
| `motivo` | `text` | No | — | No | No | — | motivo |
| `correlacion_id` | `uuid` | No | — | No | No | — | Identificador de la operación autenticada. |
| `ocurrido_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | ocurrido en |
| `actor_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `actor_sistema` | `text` | No | — | Sí | No | — | Proceso automático responsable cuando no hay iniciador humano. |

**Restricciones de fila**

- CHECK numero_evento > 0; evento 1 exige estado_anterior NULL; posteriores exigen estado_anterior NOT NULL
- CHECK estado_anterior si existe y estado_nuevo pertenecen a: planificado, en_ejecucion, suspendido, finalizado, cancelado
- CHECK num_nonnulls(actor_persona_id, actor_sistema) = 1; actor_sistema no vacío si existe.

**Unicidad y exclusión adicionales**

- UNIQUE (proyecto_id, numero_evento).

**Reglas cruzadas y de operación**

- T14: crear proceso y evento inicial en la misma transacción; cada transición añade ordinal consecutivo bajo bloqueo del proceso, estado anterior coincide con último evento y nuevo con estado final. No se permiten UPDATE/DELETE del historial ni cambios libres del estado principal.
- Se registra solo transición efectiva de estado, aparte del evento inicial.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## proyectos.historial_solicitud_desarrollo

Historial explícito e inmutable de proyectos.solicitud_desarrollo.id.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `solicitud_desarrollo_id` | `bigint` | No | proyectos.solicitud_desarrollo.id | No | No | — | Referencia a proyectos.solicitud_desarrollo.id. |
| `numero_evento` | `integer` | No | — | No | No | — | Ordinal por proceso para un orden inequívoco. |
| `estado_anterior` | `text` | No | — | Sí | No | — | estado anterior |
| `estado_nuevo` | `text` | No | — | No | No | — | estado nuevo |
| `motivo` | `text` | No | — | No | No | — | motivo |
| `correlacion_id` | `uuid` | No | — | No | No | — | Identificador de la operación autenticada. |
| `ocurrido_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | ocurrido en |
| `actor_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `actor_sistema` | `text` | No | — | Sí | No | — | Proceso automático responsable cuando no hay iniciador humano. |

**Restricciones de fila**

- CHECK numero_evento > 0; evento 1 exige estado_anterior NULL; posteriores exigen estado_anterior NOT NULL
- CHECK estado_anterior si existe y estado_nuevo pertenecen a: recibida, en_evaluacion, aprobada, rechazada, cancelada
- CHECK num_nonnulls(actor_persona_id, actor_sistema) = 1; actor_sistema no vacío si existe.

**Unicidad y exclusión adicionales**

- UNIQUE (solicitud_desarrollo_id, numero_evento).

**Reglas cruzadas y de operación**

- T14: crear proceso y evento inicial en la misma transacción; cada transición añade ordinal consecutivo bajo bloqueo del proceso, estado anterior coincide con último evento y nuevo con estado final. No se permiten UPDATE/DELETE del historial ni cambios libres del estado principal.
- Se registra solo transición efectiva de estado, aparte del evento inicial.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## proyectos.miembro_proyecto

Membresía temporal de empleado en proyecto.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `proyecto_id` | `bigint` | No | proyectos.proyecto.id | No | No | — | Referencia a proyectos.proyecto.id. |
| `empleado_id` | `bigint` | No | identidad.empleado.id | No | No | — | Referencia a identidad.empleado.id. |
| `funcion` | `text` | No | — | No | No | — | funcion |
| `es_principal` | `boolean` | No | — | No | No | false | es principal |
| `inicia_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | inicia en |
| `termina_en` | `timestamptz` | No | — | Sí | No | — | termina en |
| `actor_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `actor_sistema` | `text` | No | — | Sí | No | — | Proceso automático responsable cuando no hay iniciador humano. |

**Restricciones de fila**

- CHECK termina_en IS NULL OR termina_en > inicia_en
- CHECK num_nonnulls(actor_persona_id, actor_sistema) = 1; actor_sistema no vacío si existe.

**Unicidad y exclusión adicionales**

- EXCLUDE: períodos del mismo proyecto/empleado no se solapan.
- EXCLUDE parcial: períodos de responsables principales del mismo proyecto no se solapan.

**Reglas cruzadas y de operación**

- T05: mismas garantías de responsable que asignacion_servicio. No programar períodos futuros que cambien la elegibilidad solo por el reloj; mantener transacciones de sustitución.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## proyectos.proyecto

Ejecución de una solicitud aprobada.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `codigo` | `text` | No | — | No | Sí | — | Código de negocio estable; unicidad independiente de la PK. |
| `solicitud_desarrollo_id` | `bigint` | No | proyectos.solicitud_desarrollo.id | No | Sí | — | Referencia a proyectos.solicitud_desarrollo.id. |
| `nombre` | `text` | No | — | No | No | — | nombre |
| `descripcion` | `text` | No | — | No | No | — | descripcion |
| `alcance_acordado` | `text` | No | — | No | No | — | alcance acordado |
| `estado` | `text` | No | — | No | No | 'planificado' | Estado: planificado, en_ejecucion, suspendido, finalizado, cancelado. |
| `inicio_planificado` | `date` | No | — | Sí | No | — | inicio planificado |
| `fin_planificado` | `date` | No | — | Sí | No | — | fin planificado |
| `iniciado_en` | `timestamptz` | No | — | Sí | No | — | iniciado en |
| `finalizado_en` | `timestamptz` | No | — | Sí | No | — | finalizado en |
| `version_cotizacion_id` | `bigint` | No | comercial.version_cotizacion.id | Sí | No | — | Referencia a comercial.version_cotizacion.id. |
| `importe_base_autorizado` | `numeric(18,2)` | No | — | Sí | No | — | Techo neto para facturación directa, cuando no hay cotización. |
| `tasa_impuesto_autorizada` | `numeric(9,6)` | No | — | Sí | No | — | Tasa fraccional única de la autorización directa. |
| `moneda` | `text` | No | — | Sí | No | — | Código monetario de tres letras mayúsculas; sin moneda predeterminada. |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK estado IN ('planificado', 'en_ejecucion', 'suspendido', 'finalizado', 'cancelado')
- CHECK en_ejecucion/suspendido/finalizado exige iniciado_en; finalizado exige finalizado_en
- CHECK fin_planificado >= inicio_planificado cuando ambos existan; finalizado_en exige iniciado_en y >= iniciado_en
- CHECK ruta económica exclusiva: con version_cotizacion_id, importe_base_autorizado/tasa_impuesto_autorizada/moneda son NULL; sin versión, los tres son NOT NULL
- CHECK importe_base_autorizado >= 0 y tasa_impuesto_autorizada entre 0 y 1 cuando existan; moneda cumple tres mayúsculas
- CHECK importe_base_autorizado <> 'NaN'::numeric cuando no sea NULL
- CHECK tasa_impuesto_autorizada <> 'NaN'::numeric cuando no sea NULL

**Reglas cruzadas y de operación**

- T05: solicitud aprobada y exactamente un responsable principal activo para ejecutar; al menos una etapa y miembros habilitados. Titular deriva de solicitud, no cliente duplicado. Ruta cotizada utiliza líneas de versión aceptada; no asigna el total completo como presupuesto de cada proyecto.
- Estructura de etapas/pesos se fija al iniciar ejecución. Cambios posteriores solo mediante revisión autorizada y registrada bajo bloqueo del proyecto: motivo y valores anteriores/nuevos en auditoría, preservando etapas con avances. El porcentaje actual se recalcula y la interfaz debe indicar el cambio de base; no presentar una variación por pesos como trabajo ejecutado.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## proyectos.solicitud_desarrollo

Necesidades de software de cliente con o sin cuenta.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `codigo` | `text` | No | — | No | Sí | — | Código de negocio estable; unicidad independiente de la PK. |
| `cliente_id` | `bigint` | No | identidad.cliente.id | No | No | — | Referencia a identidad.cliente.id. |
| `necesidades` | `text` | No | — | No | No | — | necesidades |
| `objetivos` | `text` | No | — | No | No | — | objetivos |
| `alcance_deseado` | `text` | No | — | No | No | — | alcance deseado |
| `presupuesto_orientativo` | `numeric(18,2)` | No | — | Sí | No | — | presupuesto orientativo |
| `moneda_orientativa` | `text` | No | — | Sí | No | — | moneda orientativa |
| `fecha_deseada` | `date` | No | — | Sí | No | — | fecha deseada |
| `estado` | `text` | No | — | No | No | 'recibida' | Estado: recibida, en_evaluacion, aprobada, rechazada, cancelada. |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK estado IN ('recibida', 'en_evaluacion', 'aprobada', 'rechazada', 'cancelada')
- CHECK presupuesto_orientativo/moneda_orientativa ambos NULL o ambos informados; presupuesto >= 0
- CHECK presupuesto_orientativo <> 'NaN'::numeric cuando no sea NULL

**Reglas cruzadas y de operación**

- El presupuesto orientativo no es autorización de facturación.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comunicacion.adjunto

Un archivo asociado explícitamente a un mensaje o proceso.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `archivo_id` | `bigint` | No | comunicacion.archivo.id | No | No | — | Referencia a comunicacion.archivo.id. |
| `mensaje_id` | `bigint` | No | comunicacion.mensaje.id | Sí | No | — | Referencia a comunicacion.mensaje.id. |
| `pedido_id` | `bigint` | No | comercial.pedido.id | Sí | No | — | Referencia a comercial.pedido.id. |
| `solicitud_servicio_id` | `bigint` | No | servicios.solicitud_servicio.id | Sí | No | — | Referencia a servicios.solicitud_servicio.id. |
| `orden_servicio_id` | `bigint` | No | servicios.orden_servicio.id | Sí | No | — | Referencia a servicios.orden_servicio.id. |
| `solicitud_cotizacion_id` | `bigint` | No | comercial.solicitud_cotizacion.id | Sí | No | — | Referencia a comercial.solicitud_cotizacion.id. |
| `cotizacion_id` | `bigint` | No | comercial.cotizacion.id | Sí | No | — | Referencia a comercial.cotizacion.id. |
| `solicitud_desarrollo_id` | `bigint` | No | proyectos.solicitud_desarrollo.id | Sí | No | — | Referencia a proyectos.solicitud_desarrollo.id. |
| `proyecto_id` | `bigint` | No | proyectos.proyecto.id | Sí | No | — | Referencia a proyectos.proyecto.id. |
| `factura_id` | `bigint` | No | comercial.factura.id | Sí | No | — | Referencia a comercial.factura.id. |
| `descripcion` | `text` | No | — | Sí | No | — | descripcion |
| `visibilidad` | `text` | No | — | No | No | 'compartido' | compartido o interno. |
| `adjuntado_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | adjuntado en |

**Restricciones de fila**

- CHECK num_nonnulls(pedido_id, solicitud_servicio_id, orden_servicio_id, solicitud_cotizacion_id, cotizacion_id, solicitud_desarrollo_id, proyecto_id, factura_id, mensaje_id) = 1
- CHECK visibilidad IN ('compartido','interno')

**Unicidad y exclusión adicionales**

- Para cada destino: UNIQUE parcial (archivo_id, columna_destino) WHERE columna_destino IS NOT NULL.

**Reglas cruzadas y de operación**

- T11: archivo validado y autorización del proceso. Asociación interna solo para personal habilitado; adjunto en mensaje debe ser compartido dentro de su conversación, que ya define la audiencia.
- No se cambia destino de asociación existente; se crea otra tras autorizar nuevo ámbito. Un archivo puede aparecer en varios destinos sin propagar privilegios entre ellos.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comunicacion.archivo

Metadatos de objeto almacenado externamente.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `nombre_original` | `text` | No | — | No | No | — | nombre original |
| `almacen` | `text` | No | — | No | No | — | Identificador lógico del almacenamiento; sin credenciales. |
| `clave_objeto` | `text` | No | — | No | No | — | Clave estable; no una URL temporal firmada. |
| `tipo_contenido` | `text` | No | — | No | No | — | tipo contenido |
| `tamano_bytes` | `bigint` | No | — | No | No | — | tamano bytes |
| `sha256` | `bytea` | No | — | Sí | No | — | Huella de integridad, no credencial. |
| `estado` | `text` | No | — | No | No | 'pendiente' | Estado: pendiente, validado, rechazado. |
| `visibilidad` | `text` | No | — | No | No | 'privado' | visibilidad |
| `actor_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `actor_sistema` | `text` | No | — | Sí | No | — | Proceso automático responsable cuando no hay iniciador humano. |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK estado IN ('pendiente', 'validado', 'rechazado')
- CHECK tamano_bytes >= 0; sha256 IS NULL OR octet_length(sha256)=32; visibilidad IN ('privado','publico')
- CHECK num_nonnulls(actor_persona_id, actor_sistema) = 1; actor_sistema no vacío si existe.

**Unicidad y exclusión adicionales**

- UNIQUE (almacen, clave_objeto).

**Reglas cruzadas y de operación**

- T11: solo archivos validados se publican/descargan. Backend valida contenido real, tamaño y análisis; MIME declarado no prueba seguridad. Visibilidad pública se permite para imágenes de catálogo; no se reutilizan objetos privados como imagen pública.
- Cambiar almacenamiento/visibilidad/validación comprueba todas las asociaciones. Copiar objeto con permisos diferentes crea archivo separado; un vínculo público no debe exponer adjuntos privados. Cargador humano o sistema obligatorios.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comunicacion.conversacion

Conversación reutilizable de proceso o contacto general.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `asunto` | `text` | No | — | No | No | — | asunto |
| `estado` | `text` | No | — | No | No | 'abierta' | Estado: abierta, cerrada. |
| `pedido_id` | `bigint` | No | comercial.pedido.id | Sí | No | — | Referencia a comercial.pedido.id. |
| `solicitud_servicio_id` | `bigint` | No | servicios.solicitud_servicio.id | Sí | No | — | Referencia a servicios.solicitud_servicio.id. |
| `orden_servicio_id` | `bigint` | No | servicios.orden_servicio.id | Sí | No | — | Referencia a servicios.orden_servicio.id. |
| `solicitud_cotizacion_id` | `bigint` | No | comercial.solicitud_cotizacion.id | Sí | No | — | Referencia a comercial.solicitud_cotizacion.id. |
| `cotizacion_id` | `bigint` | No | comercial.cotizacion.id | Sí | No | — | Referencia a comercial.cotizacion.id. |
| `solicitud_desarrollo_id` | `bigint` | No | proyectos.solicitud_desarrollo.id | Sí | No | — | Referencia a proyectos.solicitud_desarrollo.id. |
| `proyecto_id` | `bigint` | No | proyectos.proyecto.id | Sí | No | — | Referencia a proyectos.proyecto.id. |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK estado IN ('abierta', 'cerrada')
- CHECK num_nonnulls(pedido_id, solicitud_servicio_id, orden_servicio_id, solicitud_cotizacion_id, cotizacion_id, solicitud_desarrollo_id, proyecto_id) <= 1

**Reglas cruzadas y de operación**

- T10: crear con al menos un participante; contexto vacío solo contacto general. Contexto no se cambia después de incorporar mensajes/participantes para evitar transferir acceso. Nuevos procesos tienen conversaciones nuevas y conservan vínculo de origen.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comunicacion.entrega_notificacion

Intento de entrega por un canal externo cuando se configure.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `notificacion_id` | `bigint` | No | comunicacion.notificacion.id | No | No | — | Referencia a comunicacion.notificacion.id. |
| `canal` | `text` | No | — | No | No | — | canal |
| `destino` | `text` | No | — | No | No | — | Destino histórico utilizado, no copia editable del perfil actual. |
| `numero_intento` | `integer` | No | — | No | No | — | numero intento |
| `idempotencia_id` | `uuid` | No | — | No | Sí | — | Clave estable del intento. |
| `estado` | `text` | No | — | No | No | 'pendiente' | Estado: pendiente, enviando, enviada, entregada, fallida. |
| `proveedor` | `text` | No | — | Sí | No | — | proveedor |
| `referencia_proveedor` | `text` | No | — | Sí | No | — | referencia proveedor |
| `iniciada_en` | `timestamptz` | No | — | Sí | No | — | iniciada en |
| `finalizada_en` | `timestamptz` | No | — | Sí | No | — | finalizada en |
| `entregada_en` | `timestamptz` | No | — | Sí | No | — | entregada en |
| `error` | `text` | No | — | Sí | No | — | error |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Creación del registro. |
| `updated_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | Última modificación; se mantendrá con trigger. |

**Restricciones de fila**

- CHECK estado IN ('pendiente', 'enviando', 'enviada', 'entregada', 'fallida')
- CHECK numero_intento > 0; finalizada_en exige iniciada_en y >= iniciada_en; entregada exige entregada_en; fallida exige error

**Unicidad y exclusión adicionales**

- UNIQUE (notificacion_id, canal, numero_intento).

**Reglas cruzadas y de operación**

- T12: pendiente no equivale a enviada; enviada no prueba entrega; entrega no prueba lectura. Worker posterior al commit reclama intento bajo bloqueo y usa idempotencia del proveedor cuando exista. Si el proveedor no la admite, documentar posibilidad de entrega al menos una vez y duplicados.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comunicacion.lectura_mensaje

Primera lectura de un mensaje por participante.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `mensaje_id` | `bigint` | Sí (compuesta) | comunicacion.mensaje.id | No | No | — | Referencia a comunicacion.mensaje.id. |
| `participante_id` | `bigint` | Sí (compuesta) | comunicacion.participante_conversacion.id | No | No | — | Referencia a comunicacion.participante_conversacion.id. |
| `leido_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | leido en |

**Reglas cruzadas y de operación**

- T10: mensaje y lector pertenecen a misma conversación; lector vigente y leido_en >= enviado_en. Primera lectura inmutable; reintentos no crean duplicados gracias a PK. No copiar conversacion_id ni persona_id.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comunicacion.mensaje

Mensaje cuya conversación deriva de su autor participante.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `autor_participante_id` | `bigint` | No | comunicacion.participante_conversacion.id | No | No | — | Referencia a comunicacion.participante_conversacion.id. |
| `contenido` | `text` | No | — | Sí | No | — | contenido |
| `enviado_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | enviado en |
| `editado_en` | `timestamptz` | No | — | Sí | No | — | editado en |
| `retirado` | `boolean` | No | — | No | No | false | retirado |
| `motivo_retiro` | `text` | No | — | Sí | No | — | motivo retiro |

**Restricciones de fila**

- CHECK editado_en IS NULL OR editado_en >= enviado_en; retirado exige motivo

**Reglas cruzadas y de operación**

- T10: autor participante vigente y conversación abierta al enviar. Mensaje tiene texto no vacío o al menos un adjunto validado, comprobado al final de transacción. No duplicar conversacion_id, que se deriva del autor.
- Autor/enviado_en son inmutables; contenido solo por autor autorizado según política y con auditoría. Retirar no elimina fila ni hace accesible su historial privado.

**Normalización:** Evita dependencia mensaje -> participante -> conversación almacenando únicamente autor_participante_id. La consulta une participante para obtener conversación.

## comunicacion.notificacion

Bandeja propuesta para usuario registrado.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `destinatario_usuario_id` | `bigint` | No | identidad.usuario.id | No | No | — | Referencia a identidad.usuario.id. |
| `tipo` | `text` | No | — | No | No | — | tipo |
| `titulo` | `text` | No | — | No | No | — | titulo |
| `contenido` | `text` | No | — | No | No | — | contenido |
| `evento_id` | `uuid` | No | — | No | No | — | Identificador estable del evento de negocio para deduplicar. |
| `version_cotizacion_id` | `bigint` | No | comercial.version_cotizacion.id | Sí | No | — | Referencia a comercial.version_cotizacion.id. |
| `pedido_id` | `bigint` | No | comercial.pedido.id | Sí | No | — | Referencia a comercial.pedido.id. |
| `solicitud_servicio_id` | `bigint` | No | servicios.solicitud_servicio.id | Sí | No | — | Referencia a servicios.solicitud_servicio.id. |
| `orden_servicio_id` | `bigint` | No | servicios.orden_servicio.id | Sí | No | — | Referencia a servicios.orden_servicio.id. |
| `solicitud_cotizacion_id` | `bigint` | No | comercial.solicitud_cotizacion.id | Sí | No | — | Referencia a comercial.solicitud_cotizacion.id. |
| `cotizacion_id` | `bigint` | No | comercial.cotizacion.id | Sí | No | — | Referencia a comercial.cotizacion.id. |
| `solicitud_desarrollo_id` | `bigint` | No | proyectos.solicitud_desarrollo.id | Sí | No | — | Referencia a proyectos.solicitud_desarrollo.id. |
| `proyecto_id` | `bigint` | No | proyectos.proyecto.id | Sí | No | — | Referencia a proyectos.proyecto.id. |
| `factura_id` | `bigint` | No | comercial.factura.id | Sí | No | — | Referencia a comercial.factura.id. |
| `created_at` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | created at |
| `leida_en` | `timestamptz` | No | — | Sí | No | — | leida en |

**Restricciones de fila**

- CHECK tipo IN ('general', 'cambio_pedido', 'cambio_solicitud', 'cambio_servicio', 'cambio_cotizacion', 'cambio_proyecto', 'factura_emitida')
- CHECK num_nonnulls(pedido_id, solicitud_servicio_id, orden_servicio_id, solicitud_cotizacion_id, cotizacion_id, solicitud_desarrollo_id, proyecto_id, factura_id) <= 1
- CHECK leida_en IS NULL OR leida_en >= created_at; version_cotizacion_id exige cotizacion_id
- CHECK por tipo: cambio_pedido exige pedido_id; cambio_servicio exige orden_servicio_id; cambio_cotizacion exige cotizacion_id; cambio_proyecto exige proyecto_id; factura_emitida exige factura_id; cambio_solicitud exige una de las tres solicitudes; general no tiene contexto

**Unicidad y exclusión adicionales**

- UNIQUE (destinatario_usuario_id, evento_id, tipo).

**Reglas cruzadas y de operación**

- T12: destinatario debe poder conocer el evento y versión debe pertenecer a cotización. No se guardan booleano leído ni estado de entrega duplicados. Evento y destinatario inmutables; marcar lectura solo titular.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## comunicacion.participante_conversacion

Persona participante, registrada o invitada.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `conversacion_id` | `bigint` | No | comunicacion.conversacion.id | No | No | — | Referencia a comunicacion.conversacion.id. |
| `persona_id` | `bigint` | No | identidad.persona.id | No | No | — | Referencia a identidad.persona.id. |
| `funcion` | `text` | No | — | No | No | — | funcion |
| `incorporado_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | incorporado en |
| `salio_en` | `timestamptz` | No | — | Sí | No | — | salio en |

**Restricciones de fila**

- CHECK salio_en IS NULL OR salio_en >= incorporado_en

**Unicidad y exclusión adicionales**

- UNIQUE (conversacion_id, persona_id).

**Reglas cruzadas y de operación**

- T10: persona/conversación/incorporación son inmutables tras participación; retirar conserva autoría y lecturas. Inicialmente no se reabre esta misma membresía después de salir; una nueva conversación permite nueva participación sin borrar intervalos pasados.
- Acceso deriva de cuenta verificada o concesión invitada válida y participación. Conocer persona_id no autentica. Impedir retirar último participante de una conversación abierta.

**Normalización:** Cada atributo describe la fila identificada por su clave; las relaciones independientes se representan mediante referencias.

## auditoria.evento_auditoria

Evidencia de modificaciones críticas; no sustituye historiales operativos.

| Campo | Tipo PostgreSQL | PK | FK | NULL | UNIQUE | DEFAULT | Descripción |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `id` | `bigint` | Sí | — | No | Sí (PK) | GENERATED ALWAYS AS IDENTITY | Identificador interno estable. |
| `operacion` | `text` | No | — | No | No | — | INSERT, UPDATE o DELETE. |
| `esquema_objeto` | `text` | No | — | No | No | — | esquema objeto |
| `tabla_objeto` | `text` | No | — | No | No | — | tabla objeto |
| `clave_registro` | `jsonb` | No | — | No | No | — | Identificación histórica incluso de una PK compuesta o registro eliminado. |
| `valores_anteriores` | `jsonb` | No | — | Sí | No | — | valores anteriores |
| `valores_nuevos` | `jsonb` | No | — | Sí | No | — | valores nuevos |
| `usuario_conexion` | `text` | No | — | No | No | — | Identidad técnica de conexión; no se interpreta como cliente final. |
| `rol_efectivo` | `text` | No | — | No | No | — | rol efectivo |
| `correlacion_id` | `uuid` | No | — | No | No | — | correlacion id |
| `ocurrido_en` | `timestamptz` | No | — | No | No | CURRENT_TIMESTAMP | ocurrido en |
| `actor_persona_id` | `bigint` | No | identidad.persona.id | Sí | No | — | Referencia a identidad.persona.id. |
| `actor_sistema` | `text` | No | — | Sí | No | — | Proceso automático responsable cuando no hay iniciador humano. |

**Restricciones de fila**

- CHECK operacion IN ('INSERT','UPDATE','DELETE'); clave_registro JSON objeto; anterior/nuevo JSON objetos cuando existan
- CHECK INSERT: anterior NULL y nuevo NOT NULL; UPDATE: ambos NOT NULL; DELETE: anterior NOT NULL y nuevo NULL
- CHECK num_nonnulls(actor_persona_id, actor_sistema) = 1; actor_sistema no vacío si existe.

**Reglas cruzadas y de operación**

- T14: append-only y escritura exclusiva del mecanismo de auditoría. Excluir hashes, tokens, credenciales y secretos; lista de campos auditables por tabla. No hay FK al registro eliminado: es evidencia documental, no referencia operativa.
- Conservar persona y rol técnico sin confiar en persona_id enviado por cliente; contexto establecido por backend verificado. Intentos fallidos/rollback, SELECT, DDL y acciones de superusuario requieren registros de aplicación/servidor independientes.

**Normalización:** JSONB contiene documentos de evidencia; roles, permisos, líneas, participantes y demás datos operativos permanecen relacionales.
