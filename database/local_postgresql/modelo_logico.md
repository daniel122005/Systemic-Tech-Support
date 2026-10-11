# Modelo lógico de Systemic Tech & Support

FASE 3 · Propuesta completa para revisión · Base prevista `systemic_tech_db`

El usuario aprobó avanzar desde el modelo conceptual y confirmó expresamente que visitantes pueden comprar y solicitar reparaciones, mantenimientos, cotizaciones y desarrollo sin crear cuenta. Este documento convierte ese modelo en relaciones, claves y restricciones. La fuente funcional sigue siendo «Requerimientos - Systemic Tech.docx», RF-01 a RF-42.

Se especifican **62 tablas y 603 campos**, con 137 referencias simples verificadas: 59 tablas de negocio y soporte y 3 opcionales para autenticación propia. La cantidad responde a detalles, asociaciones, historiales y controles; no se creó una tabla por requerimiento. **No se han creado tablas ni ejecutado scripts contra PostgreSQL.** Los mecanismos de fases 4–6 están descritos como compromisos de implementación, no como controles ya instalados.

El diccionario complementario incluye, tabla por tabla, exactamente las columnas de documentación solicitadas: Campo, Tipo PostgreSQL, PK, FK, NULL, UNIQUE, DEFAULT y Descripción; añade las restricciones de cada tabla y las reglas entre tablas.

## 1 Alcance y decisiones

Se mantienen siete esquemas: `identidad`, `inventario`, `comercial`, `servicios`, `proyectos`, `comunicacion` y `auditoria`.

- Persona, cuenta, cliente y empleado permanecen separados. Una persona puede tener perfiles de cliente y empleado y no tener cuenta. Los accesos invitados no se modelan como usuarios ficticios.
- Se conserva una ubicación de inventario, una categoría principal por producto, una orden por solicitud técnica y un proyecto por solicitud de desarrollo.
- Se reserva al confirmar el pedido y se registra salida al entregar. El flujo inicial entrega completo, sin entregas parciales. Facturación parcial es una capacidad independiente de entrega parcial.
- Cotizaciones conservan versiones y la respuesta de la versión exacta. Una oferta mixta puede respaldar procesos distintos sin multiplicar sus cantidades o presupuesto.
- La factura tiene un único origen principal entre pedido, orden o proyecto. El cliente se obtiene de ese origen; sus datos impresos son históricos.
- El avance del proyecto se calcula con etapas ponderadas y el último reporte por etapa. No hay porcentaje global editable.
- Clientes empresariales con varios contactos, múltiples almacenes, devoluciones y reglas fiscales específicas no forman parte de esta versión. Requerirían modificar el alcance aprobado antes de implementarlos.

Decisiones técnicas para revisión: dinero expresado a dos decimales, precios a cuatro, cantidades a tres, tasas en fracción entre 0 y 1, valoración de 1 a 5 y fin de intervalos exclusivo. No se asigna moneda ni tasa fiscal predeterminada. El usuario no ha elegido proveedor de autenticación: el núcleo permite identidad local o externa y las tres tablas locales son un perfil opcional, no una segunda implementación obligatoria del proveedor.

## 2 Traducciones del modelo conceptual

| Concepto de fase 2 | Decisión lógica y razón |
|---|---|
| Persona con perfiles opcionales | `usuario.persona_id`, `cliente.persona_id` y `empleado.persona_id` son FK y UNIQUE: como máximo un perfil de cada clase por persona. |
| Inventario por producto | `inventario.producto_id` es PK y FK. Un mecanismo diferible creará siempre el saldo al crear producto. |
| Reserva de toda una línea | `reserva_inventario.detalle_pedido_id` es PK/FK. Cantidad y producto derivan del detalle congelado; no se duplican. |
| Reparación o mantenimiento | PK/FK compartida `orden_servicio_id` en ambos subtipos. La exclusividad total exige validación diferible, pues dos FK por sí solas no la garantizan. |
| Cliente del proyecto y orden | Se deriva de la solicitud. No existe otro `cliente_id` modificable en proyecto u orden. |
| Destinatario de cotización | Ruta exclusiva: solicitud con su persona, o `persona_directa_id` para oferta directa. Se evita guardar dos titulares independientes. |
| Cliente de factura | Deriva del origen exclusivo; no se guarda `cliente_id` redundante. Los datos del receptor emitidos sí se conservan. |
| Mensaje en conversación | La conversación deriva de `autor_participante_id`; no se duplica `conversacion_id` en mensaje. |
| Valoración de cliente | Autor persona + orden. El cliente titular se deriva de orden/solicitud; se valida que el autor corresponda. |
| Acciones del acceso invitado | Se añade `identidad.acceso_invitado_permiso`, PK compuesta acceso/permiso. Así no se guardan listas de permisos en texto, arrays ni JSON. Es una asociación técnica, no un nuevo módulo. |
| Lectura de mensajes | PK compuesta mensaje/participante. Una lectura no implica que todos los participantes hayan leído. |
| Versión respondida | Estado aceptada/rechazada y evidencia en la versión. La cabecera no duplica un identificador de versión aceptada que pueda contradecirla. |
| Totales | Generados en líneas y agregados mediante consulta en cabeceras; no son campos libres que la aplicación pueda desajustar. |

## 3 Convenciones de claves y datos

PK técnicas `bigint` con identity donde hace falta identidad propia. Las asociaciones simples utilizan PK compuesta; las especializaciones reutilizan la PK de la entidad principal. Identity no reemplaza la declaración de PK. Números de pedido/cotización/factura tienen finalidad comercial distinta de la clave interna y utilizarán secuencias explícitas en la fase física.

Una FK con UNIQUE implementa el máximo 1:1; una FK ordinaria implementa el lado N. NOT NULL hace obligatoria la referencia de la fila hija. El requisito inverso «todo producto tiene inventario», «toda cotización tiene versión» o «todo proceso tiene historial inicial» necesita además creación atómica y validación diferible. Los borradores permiten cero detalles; la transición de confirmación/envío/emisión exige al menos uno.

Todas las FK se plantean con ON DELETE RESTRICT y ON UPDATE RESTRICT. Las PK no se reasignan. No se usa cascada para borrar operaciones, mensajes, facturas o auditoría. Bajas de personas/cuentas/productos son cambios de estado, conservando referencias. Las políticas de retención y purga se definirán antes de habilitar eliminación permanente.

`timestamptz` representa instantes; la presentación se convierte a la zona elegida. `date` se reserva para fechas sin hora. Se prohíben instantes infinitos en estos datos de negocio. Las validaciones dependientes del reloj —vigencia, sesión o acceso— se ejecutan al usar el recurso, no mediante un CHECK que solo evaluaría inserciones/actualizaciones.

No se inventa un catálogo fiscal. Moneda tiene formato de tres letras mayúsculas y debe ser una moneda elegida por la aplicación; el formato no prueba por sí solo validez del código. Tasas son explícitas incluso si son cero. Las precisiones elegidas exigen controlar límites antes de aceptar importes; `numeric` evita cálculo monetario binario y se excluye NaN. [Tipos numéricos de PostgreSQL](https://www.postgresql.org/docs/current/datatype-numeric.html).

## 4 Inventario de tablas y claves

### identidad · 13 tablas

| Tabla | PK | Referencias principales y relaciones |
| --- | --- | --- |
| `identidad.acceso_invitado` | id | persona_id → identidad.persona.id; version_cotizacion_id → comercial.version_cotizacion.id; pedido_id → comercial.pedido.id; solicitud_servicio_id → servicios.solicitud_servicio.id; orden_servicio_id → servicios.orden_servicio.id; solicitud_cotizacion_id → comercial.solicitud_cotizacion.id; cotizacion_id → comercial.cotizacion.id; solicitud_desarrollo_id → proyectos.solicitud_desarrollo.id; proyecto_id → proyectos.proyecto.id; factura_id → comercial.factura.id; conversacion_id → comunicacion.conversacion.id |
| `identidad.acceso_invitado_permiso` | acceso_invitado_id, permiso_id | acceso_invitado_id → identidad.acceso_invitado.id; permiso_id → identidad.permiso.id |
| `identidad.cliente` | id | persona_id → identidad.persona.id [máx. 1 por destino] |
| `identidad.credencial` (opcional) | usuario_id | usuario_id → identidad.usuario.id [máx. 1 por destino] |
| `identidad.empleado` | id | persona_id → identidad.persona.id [máx. 1 por destino] |
| `identidad.permiso` | id | Sin FK. |
| `identidad.persona` | id | Sin FK. |
| `identidad.recuperacion_acceso` (opcional) | id | usuario_id → identidad.usuario.id |
| `identidad.rol` | id | Sin FK. |
| `identidad.rol_permiso` | rol_id, permiso_id | rol_id → identidad.rol.id; permiso_id → identidad.permiso.id; actor_persona_id → identidad.persona.id |
| `identidad.sesion` (opcional) | id | usuario_id → identidad.usuario.id |
| `identidad.usuario` | id | persona_id → identidad.persona.id [máx. 1 por destino] |
| `identidad.usuario_rol` | id | usuario_id → identidad.usuario.id; rol_id → identidad.rol.id; actor_persona_id → identidad.persona.id |

### inventario · 6 tablas

| Tabla | PK | Referencias principales y relaciones |
| --- | --- | --- |
| `inventario.categoria` | id | Sin FK. |
| `inventario.inventario` | producto_id | producto_id → inventario.producto.id [máx. 1 por destino] |
| `inventario.movimiento_inventario` | id | producto_id → inventario.inventario.producto_id; detalle_pedido_id → comercial.detalle_pedido.id; compensa_movimiento_id → inventario.movimiento_inventario.id; actor_persona_id → identidad.persona.id |
| `inventario.producto` | id | categoria_id → inventario.categoria.id |
| `inventario.producto_imagen` | id | producto_id → inventario.producto.id; archivo_id → comunicacion.archivo.id |
| `inventario.reserva_inventario` | detalle_pedido_id | detalle_pedido_id → comercial.detalle_pedido.id [máx. 1 por destino] |

### comercial · 15 tablas

| Tabla | PK | Referencias principales y relaciones |
| --- | --- | --- |
| `comercial.carrito` | id | cliente_id → identidad.cliente.id |
| `comercial.comprobante_factura` | id | factura_id → comercial.factura.id; archivo_id → comunicacion.archivo.id |
| `comercial.cotizacion` | id | solicitud_cotizacion_id → comercial.solicitud_cotizacion.id [máx. 1 por destino]; persona_directa_id → identidad.persona.id |
| `comercial.detalle_carrito` | carrito_id, producto_id | carrito_id → comercial.carrito.id; producto_id → inventario.producto.id |
| `comercial.detalle_cotizacion` | id | version_cotizacion_id → comercial.version_cotizacion.id; producto_id → inventario.producto.id; servicio_ofrecido_id → servicios.servicio_ofrecido.id |
| `comercial.detalle_factura` | id | factura_id → comercial.factura.id; detalle_pedido_id → comercial.detalle_pedido.id; detalle_cotizacion_id → comercial.detalle_cotizacion.id |
| `comercial.detalle_pedido` | id | pedido_id → comercial.pedido.id; producto_id → inventario.producto.id; detalle_cotizacion_id → comercial.detalle_cotizacion.id |
| `comercial.factura` | id | pedido_id → comercial.pedido.id; orden_servicio_id → servicios.orden_servicio.id; proyecto_id → proyectos.proyecto.id |
| `comercial.historial_cotizacion` | id | cotizacion_id → comercial.cotizacion.id; actor_persona_id → identidad.persona.id; version_cotizacion_id → comercial.version_cotizacion.id |
| `comercial.historial_factura` | id | factura_id → comercial.factura.id; actor_persona_id → identidad.persona.id |
| `comercial.historial_pedido` | id | pedido_id → comercial.pedido.id; actor_persona_id → identidad.persona.id |
| `comercial.historial_solicitud_cotizacion` | id | solicitud_cotizacion_id → comercial.solicitud_cotizacion.id; actor_persona_id → identidad.persona.id |
| `comercial.pedido` | id | cliente_id → identidad.cliente.id; carrito_id → comercial.carrito.id [máx. 1 por destino]; version_cotizacion_id → comercial.version_cotizacion.id |
| `comercial.solicitud_cotizacion` | id | persona_id → identidad.persona.id |
| `comercial.version_cotizacion` | id | cotizacion_id → comercial.cotizacion.id; respondida_por_persona_id → identidad.persona.id |

### servicios · 12 tablas

| Tabla | PK | Referencias principales y relaciones |
| --- | --- | --- |
| `servicios.asignacion_servicio` | id | orden_servicio_id → servicios.orden_servicio.id; empleado_id → identidad.empleado.id; actor_persona_id → identidad.persona.id |
| `servicios.calificacion_servicio` | orden_servicio_id | orden_servicio_id → servicios.orden_servicio.id [máx. 1 por destino]; autor_persona_id → identidad.persona.id |
| `servicios.cita_servicio` | id | solicitud_servicio_id → servicios.solicitud_servicio.id; tecnico_id → identidad.empleado.id; sustituye_cita_id → servicios.cita_servicio.id [máx. 1 por destino] |
| `servicios.disponibilidad_tecnico` | id | empleado_id → identidad.empleado.id |
| `servicios.equipo_cliente` | id | cliente_id → identidad.cliente.id |
| `servicios.historial_servicio` | id | orden_servicio_id → servicios.orden_servicio.id; actor_persona_id → identidad.persona.id |
| `servicios.historial_solicitud_servicio` | id | solicitud_servicio_id → servicios.solicitud_servicio.id; actor_persona_id → identidad.persona.id |
| `servicios.mantenimiento` | orden_servicio_id | orden_servicio_id → servicios.orden_servicio.id [máx. 1 por destino] |
| `servicios.orden_servicio` | id | solicitud_servicio_id → servicios.solicitud_servicio.id [máx. 1 por destino]; version_cotizacion_id → comercial.version_cotizacion.id |
| `servicios.reparacion` | orden_servicio_id | orden_servicio_id → servicios.orden_servicio.id [máx. 1 por destino] |
| `servicios.servicio_ofrecido` | id | Sin FK. |
| `servicios.solicitud_servicio` | id | cliente_id → identidad.cliente.id; servicio_ofrecido_id → servicios.servicio_ofrecido.id; equipo_cliente_id → servicios.equipo_cliente.id |

### proyectos · 7 tablas

| Tabla | PK | Referencias principales y relaciones |
| --- | --- | --- |
| `proyectos.avance_proyecto` | id | etapa_proyecto_id → proyectos.etapa_proyecto.id; miembro_proyecto_id → proyectos.miembro_proyecto.id |
| `proyectos.etapa_proyecto` | id | proyecto_id → proyectos.proyecto.id |
| `proyectos.historial_proyecto` | id | proyecto_id → proyectos.proyecto.id; actor_persona_id → identidad.persona.id |
| `proyectos.historial_solicitud_desarrollo` | id | solicitud_desarrollo_id → proyectos.solicitud_desarrollo.id; actor_persona_id → identidad.persona.id |
| `proyectos.miembro_proyecto` | id | proyecto_id → proyectos.proyecto.id; empleado_id → identidad.empleado.id; actor_persona_id → identidad.persona.id |
| `proyectos.proyecto` | id | solicitud_desarrollo_id → proyectos.solicitud_desarrollo.id [máx. 1 por destino]; version_cotizacion_id → comercial.version_cotizacion.id |
| `proyectos.solicitud_desarrollo` | id | cliente_id → identidad.cliente.id |

### comunicacion · 8 tablas

| Tabla | PK | Referencias principales y relaciones |
| --- | --- | --- |
| `comunicacion.adjunto` | id | archivo_id → comunicacion.archivo.id; mensaje_id → comunicacion.mensaje.id; pedido_id → comercial.pedido.id; solicitud_servicio_id → servicios.solicitud_servicio.id; orden_servicio_id → servicios.orden_servicio.id; solicitud_cotizacion_id → comercial.solicitud_cotizacion.id; cotizacion_id → comercial.cotizacion.id; solicitud_desarrollo_id → proyectos.solicitud_desarrollo.id; proyecto_id → proyectos.proyecto.id; factura_id → comercial.factura.id |
| `comunicacion.archivo` | id | actor_persona_id → identidad.persona.id |
| `comunicacion.conversacion` | id | pedido_id → comercial.pedido.id; solicitud_servicio_id → servicios.solicitud_servicio.id; orden_servicio_id → servicios.orden_servicio.id; solicitud_cotizacion_id → comercial.solicitud_cotizacion.id; cotizacion_id → comercial.cotizacion.id; solicitud_desarrollo_id → proyectos.solicitud_desarrollo.id; proyecto_id → proyectos.proyecto.id |
| `comunicacion.entrega_notificacion` | id | notificacion_id → comunicacion.notificacion.id |
| `comunicacion.lectura_mensaje` | mensaje_id, participante_id | mensaje_id → comunicacion.mensaje.id; participante_id → comunicacion.participante_conversacion.id |
| `comunicacion.mensaje` | id | autor_participante_id → comunicacion.participante_conversacion.id |
| `comunicacion.notificacion` | id | destinatario_usuario_id → identidad.usuario.id; version_cotizacion_id → comercial.version_cotizacion.id; pedido_id → comercial.pedido.id; solicitud_servicio_id → servicios.solicitud_servicio.id; orden_servicio_id → servicios.orden_servicio.id; solicitud_cotizacion_id → comercial.solicitud_cotizacion.id; cotizacion_id → comercial.cotizacion.id; solicitud_desarrollo_id → proyectos.solicitud_desarrollo.id; proyecto_id → proyectos.proyecto.id; factura_id → comercial.factura.id |
| `comunicacion.participante_conversacion` | id | conversacion_id → comunicacion.conversacion.id; persona_id → identidad.persona.id |

### auditoria · 1 tablas

| Tabla | PK | Referencias principales y relaciones |
| --- | --- | --- |
| `auditoria.evento_auditoria` | id | actor_persona_id → identidad.persona.id |


La relación completa de cada campo FK con su destino está en el diccionario. Las PK compuestas indicadas aquí no convierten cada columna individual en única. Los historiales son tablas del esquema de su proceso; `auditoria` se reserva para evidencia transversal.

## 5 Restricciones y dónde se garantizarán

| Clase de regla | Mecanismo previsto |
|---|---|
| Campo obligatorio, rango, formato, XOR entre referencias de una fila | NOT NULL y CHECK de la fila. |
| Identidad y códigos sin repetición | PK y UNIQUE. |
| Registro referenciado existente | FK a PK/UNIQUE. |
| Una versión aceptada o enviada por cotización, una imagen principal | Índice único parcial en fase 4; no una falsa restricción UNIQUE condicional. |
| Citas, ventanas y asignaciones sin solapamiento | Restricción EXCLUDE con intervalos, utilizando soporte GiST y `btree_gist` si corresponde. |
| Titularidad entre varios saltos, mínimos de hijos, subtipo exclusivo | Validación transaccional y triggers de restricción diferibles, sobre todos los caminos de modificación. |
| Cantidades agregadas, inventario reservado, facturación acumulada | Procedimientos con bloqueos, restricciones de escritura y validaciones al cierre de la operación. |
| Autenticación, envío externo y validación de archivos | Backend/proveedor, con soporte persistente y controles de privilegios en PostgreSQL. |

Un CHECK no garantiza condiciones que consultan otras tablas; tampoco reemplaza NOT NULL, porque una expresión desconocida por NULL no se rechaza como falsa. Se utilizan FK, UNIQUE o EXCLUDE donde son suficientes y reglas transaccionales donde hacen falta. [Restricciones PostgreSQL](https://www.postgresql.org/docs/current/ddl-constraints.html).

Los intervalos serán `[inicio, fin)`: dos citas adyacentes pueden coexistir. EXCLUDE impide solapamientos del mismo técnico, pero **no prueba que la cita esté dentro de su disponibilidad**; esa es una validación cruzada. [Rangos PostgreSQL](https://www.postgresql.org/docs/current/rangetypes.html).

### Contratos de integridad entre tablas

| Código | Invariante y caminos a proteger |
|---|---|
| T00 | Autorización: cuenta/persona/empleado activos y permisos vigentes. Revocar una cuenta o permiso no debe quedar impedido por una asignación: la operación reasigna responsables o pausa órdenes/proyectos afectados en la misma transacción. La revocación de acceso tiene prioridad. |
| T01 | Equipo y solicitud pertenecen al mismo cliente; reparación exige equipo y modalidad coincide con oferta. Proteger cambios de equipo, dueño, oferta y solicitud; no solo creación de solicitud. |
| T02 | Una orden nace de solicitud aceptada y tiene exactamente un subtipo coherente. Ejecutar exige responsable principal habilitado. Proteger altas/bajas de subtipos, asignaciones, cuentas, empleados y cambios de estado; la sustitución puede completarse antes del chequeo diferible. |
| T03 | Cita confirmada requiere técnico, ventana que la contenga y solicitud apta. Cambiar ventanas, técnico, horas, habilitación o cancelación vuelve a validar; confirmar y editar disponibilidad bloquean el mismo empleado. |
| T04 | Valora la persona del cliente de una orden finalizada. Mantener inmutables orden y autor de la valoración; identidad invitada verificada. |
| T05 | Proyecto procede de solicitud aprobada; responsable y miembros pertenecen al proyecto. Autor de avance pertenece a la etapa/proyecto. Último reporte por instante servidor e id. Cambios de pesos/alcance después de iniciar se realizan mediante revisión autorizada y auditada bajo bloqueo del proyecto; no se borran etapas con avances. |
| T06 | Libro de movimientos, saldo y reservas coherentes. Proteger creación de producto/saldo, confirmación, entrega, cancelación, ajuste y compensación. No DML directo sobre saldo ni movimientos editables. Bloquear productos en orden estable. |
| T07 | Pedido cotizado corresponde a destinatario y versión aceptada; líneas coherentes y capacidad no excedida. Congelar condiciones desde confirmación. Proteger edición de líneas concurrente con confirmación. |
| T08 | Oferta enviada tiene líneas y destinatario; una sola versión enviada/aceptada. Verificar tiempo, identidad y versión al responder bajo bloqueo. Enviar, reemplazar, responder y editar borrador deben bloquear cabecera y versión. |
| T09 | Factura de un origen, titular y moneda coherentes. Cantidades/bases/impuestos aplicados dentro de lo autorizado. Emisión/anulación y operaciones sobre fuentes comparten bloqueos. Congelar cabecera/líneas al emitir. |
| T10 | Autor/lector pertenecen a misma conversación y su participación era vigente. Mensaje tiene contenido o archivo válido; conversación abierta tiene participantes. Proteger reasignación de participante y cambios de contexto, no solo inserción de mensaje. |
| T11 | Archivo validado y acceso conforme a cada asociación; impedir convertir un objeto privado referenciado en uno público. Validar al adjuntar, publicar imagen y modificar visibilidad/validación/almacenamiento. |
| T12 | Notificación visible al destinatario y versión del mismo proceso. Dedupe por evento/destinatario/tipo. Entregas posteriores al commit con estados separados de lectura y claves estables de reintento. |
| T13 | Acceso invitado verifica titular/participante, contexto único, acciones permitidas, tiempo y revocación. Respuesta de cotización exige versión precisa. No se puede ampliar concesión cambiando campos; se revoca y emite otra verificada. |
| T14 | Cambio de estado e historial se confirman juntos; ordinal por proceso coherente con estados anteriores. Auditoría append-only de cambios críticos, filtrando secretos. JSONB de evidencia no es una FK operativa a registros eliminados. |

La implementación combinará privilegios que cierren escrituras directas, procedimientos que coordinen los bloqueos y validaciones de todos los cambios relevantes. Un trigger que lea una suma sin bloquear no basta frente a concurrencia. Los mecanismos se concretarán en fases 4–6 y las pruebas negativas/concurrentes se ejecutarán en fase 7.

## 6 Estado y transiciones

Las listas de estados están especificadas en cada tabla. Estas rutas de negocio serán la base de la programación; no son estados literales del documento fuente.

| Proceso | Transiciones principales |
|---|---|
| Pedido | borrador → confirmado/cancelado; confirmado → en_preparacion/completado/cancelado; en_preparacion → completado/cancelado. Completado y cancelado son terminales en este alcance. |
| Solicitud técnica | recibida → en_evaluacion/cancelada; en_evaluacion → aceptada/rechazada/cancelada. Cancelar una aceptada requiere coordinar cancelación de orden y citas; no si hay trabajo finalizado o facturación vigente incompatible. |
| Orden | pendiente_asignacion → asignada/cancelada; asignada → en_ejecucion/cancelada; en_ejecucion ↔ pausada; en_ejecucion → finalizada; cancelar ejecución/pausa requiere motivo y revisión económica. |
| Solicitud de cotización | recibida → en_evaluacion/cancelada; en_evaluacion → atendida/rechazada/cancelada. Emitir una oferta atiende la solicitud sin cerrar necesariamente la negociación. |
| Negociación | abierta → aceptada/cerrada/anulada; cerrada → abierta mediante reapertura autorizada sin sobrescribir versiones. Aceptada permanece como evidencia; cambios de acuerdo crean otra negociación. |
| Versión | borrador → enviada/anulada; enviada → aceptada/rechazada/reemplazada/anulada. Expirada se deriva de fecha: no se inserta un estado que exija un trigger por paso del tiempo. |
| Solicitud de software | recibida → en_evaluacion/cancelada; en_evaluacion → aprobada/rechazada/cancelada. Aprobada con proyecto activo no se revoca sin coordinarlo. |
| Proyecto | planificado → en_ejecucion/cancelado; en_ejecucion ↔ suspendido; en_ejecucion → finalizado; cancelar exige revisar ejecución y facturación. |
| Factura | borrador → emitida → anulada. Una factura anulada no se reactiva ni se borra. |

Los estados iniciales generan evento 1; eventos posteriores registran estado anterior real, nuevo, actor, motivo y correlación. Se conserva la diferencia entre cierre operativo y situación económica. No se deduce pago a partir de estado de factura.

## 7 Inventario y concurrencia

**Fuente de verdad:** movimientos confirmados. El saldo de `inventario` es una proyección controlada. Reservado se obtiene de cantidades de detalles cuyo registro de reserva está activo; disponible es saldo menos reservado.

Confirmar pedido bloquea su cabecera y los productos afectados, revalida disponibilidad y crea una reserva por línea. Los detalles quedan inmutables. Dos confirmaciones del mismo pedido no crean dos reservas: PK por línea, estado y `operacion_confirmacion_id` protegen el reintento.

Entregar consume las reservas, registra una salida por detalle y actualiza el saldo dentro de la misma transacción. No se valida el saldo disponible en un estado intermedio que todavía tenga la reserva consumida contada como activa. El estado final debe cumplir saldo no negativo y saldo suficiente para las reservas restantes.

Cancelar antes de entregar libera reservas y conserva el pedido; no crea entrada porque ningún producto había salido. Un ajuste negativo tampoco puede consumir unidades comprometidas por otras reservas. Los movimientos no se borran ni se editan: las correcciones son movimientos compensatorios con motivo y responsable.

Se usará el mismo orden de bloqueo por producto para operaciones de múltiples líneas. Las claves de idempotencia se reutilizan al reintentar; reutilizar una clave con otro contenido se rechaza. La correlación de auditoría no reemplaza la idempotencia de negocio.

## 8 Cotizaciones mixtas y facturación parcial

Una cotización puede contener productos, servicios y conceptos libres. Una versión aceptada no constituye un presupuesto completo nuevo para cada pedido, orden o proyecto que la cite.

Para conceptos de producto, los pedidos en estados **confirmado, en_preparacion o completado** consumen cantidades de la línea cotizada. Sus facturas aplican cantidades a la línea del pedido; **no se vuelve a contar la factura como otra aplicación de la cotización**. Cancelar un pedido no entregado libera su aplicación solo cuando no queda facturación emitida vigente que lo contradiga.

Para órdenes/proyectos cotizados, la factura referencia conceptos elegibles de la versión: la suma de cantidades facturadas emitidas vigentes entre todos esos orígenes no excede la línea. Un concepto de servicio debe corresponder al servicio ofrecido; los proyectos usan conceptos libres. No se permite vender productos mediante una línea libre para eludir inventario.

La versión debe ser de la persona titular del proceso. Las líneas de pedido referenciadas pertenecen a su pedido y las líneas de cotización referenciadas a su versión. También se comprueban moneda, precio, unidad, tasa, base y descuento. Los identificadores válidos por separado no bastan para demostrar estas correspondencias.

En la ruta sin cotización, orden/proyecto conserva una autorización directa: importe base máximo, tasa única explícita y moneda. En la ruta cotizada esos tres campos quedan NULL y las condiciones se obtienen de sus conceptos. Se evita copiar el total de la oferta mixta como techo de cada proceso. No se reserva presupuesto individual de cada proyecto al crearlo: se controla la aplicación y facturación global de las líneas aceptadas. Un reparto presupuestal individual previo necesitaría una relación adicional de asignación antes de habilitarlo.

Emisión bloquea cabecera, origen y fuentes de aplicación en orden estable. Confirmar pedidos respaldados, editar fuentes, emitir y anular facturas utilizarán esos mismos bloqueos. Las líneas de borrador no consumen capacidad, pero se revalidan al emitir. Facturas anuladas conservan el documento y dejan de consumir capacidad solo por la transición autorizada.

### Cálculos y redondeo interno propuestos

En líneas originales de cotización y pedidos directos:

- Base = redondear(cantidad × precio unitario, 2) − descuento de línea.
- Impuesto = redondear(base × tasa explícita, 2).
- Total = base + impuesto.

La factura y el pedido aplicado parcialmente desde cotización incorporan ajustes técnicos de base/impuesto calculados por el reparto acumulativo. En pedidos directos son cero. La expresión generada de cada campo repite los operandos originales; no referencia otra columna generada. PostgreSQL restringe esas referencias y las expresiones generadas deben ser inmutables. [Columnas generadas](https://www.postgresql.org/docs/current/ddl-generated-columns.html).

Para una fuente con cantidad Q, base B, descuento D e impuesto I, si se aplica una cantidad acumulada q:

- Base acumulada autorizada = redondear(B × q / Q, 2).
- Descuento acumulado = redondear(D × q / Q, 2).
- Impuesto acumulado = redondear(I × q / Q, 2).
- El importe de la nueva aplicación es el acumulado autorizado menos lo ya aplicado por operaciones vigentes.

El precio histórico se conserva. Se calcula `ajuste_base` como la diferencia necesaria entre esa base asignada y la fórmula de cantidad/precio/descuento de la nueva línea; `ajuste_impuesto` hace lo mismo con el impuesto. Las correcciones de centavos solo las determina el procedimiento, y se validan contra la fuente. Así la última aplicación cierra exactamente el importe original. No se permite al cliente enviar ajustes arbitrarios.

En autorizaciones directas por importe, la suma de bases no excede el techo; el impuesto acumulado se calcula sobre la base efectivamente facturada y su tasa autorizada, repartiendo el residual de redondeo en la nueva emisión. Si el techo es cero, bases e impuestos son cero y no se divide por ese techo. Para varias líneas en una emisión se aplica un orden determinista y se controla el total, no se redondea cada parte como si tuviera presupuesto independiente.

Las anulaciones y nuevas aplicaciones se comprueban también por importes, no solamente por cantidad, especialmente después de liberar una aplicación intermedia con centavos de ajuste. Si el reparto no puede conservar cantidades/importes no negativos y techo original, se rechaza y exige una corrección comercial explícita; no se altera una factura ya emitida. Esta es una regla aritmética de consistencia, no una afirmación de normativa fiscal colombiana.

Las sumas de cabecera, disponibilidad, avance y promedio de valoraciones se consultan; no se almacenan como valores libres duplicados.

## 9 Normalización

| Problema o dependencia | Solución | Resultado |
|---|---|---|
| Lista de productos en un pedido | `detalle_pedido`, una línea por hecho comercial. | 1FN: no columnas producto_1, producto_2 ni listas. |
| Varios roles/permisos o participantes en un campo | Asociaciones usuario_rol, rol_permiso, acceso_invitado_permiso y participante_conversacion. | 1FN y relaciones explícitas. |
| Nombre de producto en detalle_carrito junto a su referencia | Se consulta desde producto; el detalle solo guarda selección/cantidad. | Evita dependencia transitiva mientras no existe hecho de venta. |
| Datos de rol/permiso en su asociación | Nombre y descripción permanecen en sus entidades. | 2FN: atributos de la concesión dependen de la combinación completa. |
| Estado de lectura global | Lectura por combinación mensaje/participante, con su fecha. | 2FN: depende de ambos, no solo del mensaje. |
| Persona repetida en cliente y empleado | Referencias únicas a persona; cuenta separada. | 3FN del núcleo de identidad. |
| Solicitud determina titular del proyecto/orden | Titular se obtiene por la solicitud. | Elimina cliente_id transitivo. |
| Origen de factura determina cliente | Cliente derivado del origen exclusivo. | Evita dos titulares que puedan divergir. |
| Solicitud determina destinatario de cotización | Persona directa solo cuando no hay solicitud. | Elimina la copia transitiva. |
| Participante determina conversación de mensaje | Mensaje guarda autor_participante_id. | Elimina conversacion_id redundante. |
| Detalle determina cantidad/producto de reserva | Reserva referencia detalle inmutable. | Elimina saldo reservado editable por otra vía. |
| Último avance de etapa determina progreso actual | Se consulta último reporte; global ponderado derivado. | No hay tres porcentajes editables contradictorios. |
| Leída/no leída depende de fecha de lectura | Solo leida_en en notificación. | Evita booleano y fecha contradictorios. |

El **núcleo de hechos editables** se plantea en 3FN, según las dependencias funcionales indicadas. La representación preparada para PostgreSQL contiene excepciones y proyecciones explícitas; no se afirma que todos los campos físicos almacenados estén en 3FN estricta:

1. **Snapshots comerciales:** descripciones, precios, unidades, destinatarios e impuestos guardan el hecho acordado/emitido. No son otra copia editable de los datos vigentes. Si provienen de una fuente inmutable, su copia se conserva como snapshot documental verificado, una redundancia deliberada.
2. **Columnas generadas de línea:** son proyecciones deterministas de sus operandos; no son otro dato base. Al materializarlas se introduce redundancia física controlada, sin posibilidad de edición independiente.
3. **Saldo de inventario:** materializa una suma para consulta y bloqueo; se mantiene por un único mecanismo y se concilia con movimientos.
4. **Estado actual e historial:** estado es la proyección operativa del último evento. Se mantienen juntos; el historial aporta hechos temporales adicionales.
5. **Auditoría JSONB:** cada fila conserva un documento de evidencia. No se trasladan a JSONB relaciones operativas que deban tener claves y restricciones.

Los valores calculados puramente de consulta no forman parte de las tablas base. No se descompone una descripción libre en tablas artificiales ni se crean catálogos para cada texto sin función de negocio.

## 10 Acceso sin cuenta y separación de responsabilidades

El acceso invitado conserva huella del token y medio verificado, persona, vencimiento, revocación y un recurso concreto. Una asociación contiene las acciones permitidas. Responder una versión de cotización exige precisión de versión; consultar otros documentos no hereda ese permiso. Las referencias explícitas se respaldan por FK y una regla de exclusividad; no existe un identificador polimórfico libre sin validación.

La aplicación no confiará en un `persona_id` aportado por el navegador. Verifica cuenta o token, establece contexto confiable y autoriza la acción. PostgreSQL refuerza integridad y privilegios; RLS se diseñará en fase 6 según arquitectura. Un visitante recibe acceso a operaciones concretas, no a la totalidad del historial de todas las personas que compartan correo.

El backend o proveedor gestiona contraseñas, sesión, recuperación, entrega de correos y validación de archivos. PostgreSQL conserva estados, metadatos, autorizaciones y trazabilidad. Registrar una notificación no garantiza entrega externa; el estado del proveedor se conserva por intento.

El historial general del cliente y la bandeja administrativa se obtendrán mediante vistas/consultas; no se duplican en tablas universales de operaciones. Los roles de la aplicación siguen siendo distintos de los roles de conexión PostgreSQL que se implementarán en fase 6.

## 11 Trazabilidad de los 42 RF

La siguiente matriz verifica presencia de soporte en el **diseño**, no cumplimiento funcional ejecutado.

| RF | Requerimiento fuente | Tablas de soporte | Implementación y responsabilidad | Estado |
| --- | --- | --- | --- | --- |
| RF-01 | Acceso público | inventario.producto, inventario.categoria, servicios.servicio_ofrecido | Publicación limitada de catálogo y oferta; frontend permite navegación sin cuenta. | Previsto; sin ejecutar |
| RF-02 | Registro de usuarios | identidad.persona, identidad.usuario | Backend/proveedor registra y verifica la cuenta opcional. | Previsto; sin ejecutar |
| RF-03 | Inicio de sesión | identidad.usuario, identidad.credencial, identidad.sesion | Autenticación y cierre propios o delegados; las dos últimas tablas solo en perfil local. | Previsto; sin ejecutar |
| RF-04 | Recuperación de contraseña | identidad.recuperacion_acceso | Recuperación local o proveedor; enlace entregado externamente y uso único transaccional. | Previsto; sin ejecutar |
| RF-05 | Gestión del perfil | identidad.persona, identidad.usuario, identidad.cliente | Consulta/edición del propio perfil; backend valida campos y titularidad. | Previsto; sin ejecutar |
| RF-06 | Control de acceso según usuario | identidad.rol, identidad.permiso, identidad.usuario_rol, identidad.rol_permiso, identidad.acceso_invitado, identidad.acceso_invitado_permiso | Backend y futura seguridad DB distinguen cuenta, invitado, propiedad y acción. | Previsto; sin ejecutar |
| RF-07 | Consulta de productos | inventario.producto, inventario.producto_imagen, comunicacion.archivo, inventario.inventario, inventario.reserva_inventario | Catálogo, imágenes y disponibilidad derivada; frontend presenta. | Previsto; sin ejecutar |
| RF-08 | Búsqueda y filtrado de productos | inventario.producto, inventario.categoria | Consultas filtradas y futuros índices; backend parametriza y pagina. | Previsto; sin ejecutar |
| RF-09 | Carrito de compras | comercial.carrito, comercial.detalle_carrito | Sesión anónima o cliente; modificar selección antes de conversión. | Previsto; sin ejecutar |
| RF-10 | Realización de compras | comercial.pedido, comercial.detalle_pedido, inventario.reserva_inventario, inventario.movimiento_inventario | Confirmación/entrega consistentes; backend coordina, sin presuponer pasarela de pago. | Previsto; sin ejecutar |
| RF-11 | Consulta de pedidos | comercial.pedido, comercial.historial_pedido | Consultar estados propios por cuenta o acceso invitado autorizado. | Previsto; sin ejecutar |
| RF-12 | Historial de compras | comercial.pedido, comercial.detalle_pedido | Consulta de historial de compras propio. | Previsto; sin ejecutar |
| RF-13 | Consulta de servicios | servicios.servicio_ofrecido | Información pública de oferta técnica, presentada por frontend. | Previsto; sin ejecutar |
| RF-14 | Solicitud de reparación | servicios.solicitud_servicio, servicios.equipo_cliente | Recepción de reparación; equipo y problema, incluso sin cuenta. | Previsto; sin ejecutar |
| RF-15 | Solicitud de mantenimiento | servicios.solicitud_servicio, servicios.servicio_ofrecido | Recepción de necesidad de mantenimiento, incluso sin cuenta. | Previsto; sin ejecutar |
| RF-16 | Agendamiento de servicios | servicios.cita_servicio, servicios.disponibilidad_tecnico | Disponibilidad y no solapamiento; frontend calendario y backend confirmación. | Previsto; sin ejecutar |
| RF-17 | Consulta del estado de reparación | servicios.orden_servicio, servicios.reparacion, servicios.historial_servicio | Estado de reparación con autorización del titular. | Previsto; sin ejecutar |
| RF-18 | Historial de servicios | servicios.solicitud_servicio, servicios.orden_servicio, servicios.reparacion, servicios.mantenimiento | Historial de atenciones por cliente. | Previsto; sin ejecutar |
| RF-19 | Solicitud de cotización | comercial.solicitud_cotizacion, identidad.persona | Cotización sin cuenta ni cliente obligatorio; contacto y necesidad. | Previsto; sin ejecutar |
| RF-20 | Consulta de cotizaciones | comercial.cotizacion, comercial.version_cotizacion, identidad.usuario | Consulta por titularidad derivada y verificada. | Previsto; sin ejecutar |
| RF-21 | Gestión de cotizaciones | comercial.version_cotizacion, identidad.acceso_invitado | Respuesta a versión precisa; vigencia, actor y evidencia. | Previsto; sin ejecutar |
| RF-22 | Solicitud de desarrollo de software | proyectos.solicitud_desarrollo, identidad.cliente | Necesidades de software con perfil comercial sin cuenta obligatoria. | Previsto; sin ejecutar |
| RF-23 | Seguimiento de proyectos | proyectos.proyecto, proyectos.etapa_proyecto, proyectos.avance_proyecto | Consulta de estado y avance ponderado derivado. | Previsto; sin ejecutar |
| RF-24 | Consulta de información del proyecto | proyectos.proyecto, proyectos.etapa_proyecto, proyectos.avance_proyecto, proyectos.miembro_proyecto | Información relevante del proyecto autorizada al cliente. | Previsto; sin ejecutar |
| RF-25 | Contacto con la empresa | comunicacion.conversacion | Comunicación registrada cuando corresponda; canales públicos pueden ser enlaces de frontend/servicios externos. | Previsto; sin ejecutar |
| RF-26 | Mensajería | comunicacion.conversacion, comunicacion.participante_conversacion, comunicacion.mensaje, comunicacion.lectura_mensaje | Mensajería compartida y autorizada con personal y visitantes verificados. | Previsto; sin ejecutar |
| RF-27 | Carga de archivos | comunicacion.archivo, comunicacion.adjunto | Metadatos y FK de contexto; backend/almacenamiento carga, valida y entrega binarios. | Previsto; sin ejecutar |
| RF-28 | Notificaciones | comunicacion.notificacion, comunicacion.entrega_notificacion | Bandeja propuesta y entregas externas independientes de lectura. | Previsto; sin ejecutar |
| RF-29 | Consulta de facturas | comercial.factura, comercial.detalle_factura, comercial.comprobante_factura | Consulta autorizada de documentos; emisión/detalle ampliados por encargo del usuario. | Previsto; sin ejecutar |
| RF-30 | Calificación de servicios | servicios.calificacion_servicio | Una valoración del titular sobre servicio finalizado; frontend formulario. | Previsto; sin ejecutar |
| RF-31 | Historial general del cliente | comercial.pedido, servicios.solicitud_servicio, comercial.cotizacion, proyectos.solicitud_desarrollo | Consulta unificada por titularidad; no tabla duplicada de historial general. | Previsto; sin ejecutar |
| RF-32 | Gestión de usuarios | identidad.usuario, identidad.persona, auditoria.evento_auditoria | Administración de cuentas autorizada y auditada. | Previsto; sin ejecutar |
| RF-33 | Gestión de productos | inventario.producto, inventario.categoria, inventario.producto_imagen, auditoria.evento_auditoria | Gestión de catálogo, precio y publicación. | Previsto; sin ejecutar |
| RF-34 | Gestión de inventario | inventario.inventario, inventario.movimiento_inventario, inventario.reserva_inventario | Entradas, salidas, ajustes y existencias controladas. | Previsto; sin ejecutar |
| RF-35 | Gestión de pedidos | comercial.pedido, comercial.historial_pedido | Administrar transiciones sin romper inventario/facturación. | Previsto; sin ejecutar |
| RF-36 | Gestión de reparaciones | servicios.orden_servicio, servicios.reparacion, servicios.asignacion_servicio, servicios.historial_servicio | Asignación, diagnóstico, ejecución y cierre. | Previsto; sin ejecutar |
| RF-37 | Gestión de mantenimientos | servicios.solicitud_servicio, servicios.mantenimiento, servicios.orden_servicio | Administración de solicitud y atención de mantenimiento. | Previsto; sin ejecutar |
| RF-38 | Gestión de cotizaciones | comercial.cotizacion, comercial.version_cotizacion, comercial.detalle_cotizacion, comercial.historial_cotizacion | Preparar, enviar, revisar y gestionar ofertas conservando evidencia. | Previsto; sin ejecutar |
| RF-39 | Gestión de proyectos de software | proyectos.proyecto, proyectos.miembro_proyecto, proyectos.historial_proyecto | Administración, responsables, estado y revisiones registradas. | Previsto; sin ejecutar |
| RF-40 | Gestión de clientes | identidad.cliente, identidad.persona, identidad.usuario | Gestión de cliente; la cuenta es opcional. | Previsto; sin ejecutar |
| RF-41 | Gestión de solicitudes | servicios.solicitud_servicio, comercial.solicitud_cotizacion, proyectos.solicitud_desarrollo | Bandeja mediante consulta; backend coordina cada flujo. | Previsto; sin ejecutar |
| RF-42 | Gestión de roles y permisos | identidad.rol, identidad.permiso, identidad.usuario_rol, identidad.rol_permiso | Gestión de autorizaciones de aplicación, distinta de roles PostgreSQL de fase 6. | Previsto; sin ejecutar |

## 12 Revisión realizada y siguiente límite de fase

Se verificaron mecánicamente nombres de tablas/campos, PK no nulas, 137 destinos FK existentes y de tipo compatible, claves únicas válidas como destino, ausencia de referencias entre columnas generadas y cobertura de las 61 entidades conceptuales. Se incorporó únicamente la asociación de permisos de acceso invitado ya justificada. Estas comprobaciones no equivalen a ejecutar restricciones, pruebas de concurrencia o procedimientos en PostgreSQL.

El detalle de expresiones DDL, índices concretos, secuencias y extensiones corresponde a la fase 4. La programación de reglas T01–T14 corresponde a la fase 5 y la autorización efectiva a la fase 6. Las consultas, INSERT y pruebas positivas/negativas/concurrentes quedan para fase 7, con verificación final por RF en fase 8.

**Fin de la fase 3.** Se entrega el modelo lógico y el diccionario para revisión antes de crear la estructura física.
