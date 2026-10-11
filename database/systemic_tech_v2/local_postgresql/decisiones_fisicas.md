# Fase 4 — Inventario físico y decisiones

Base: `systemic_tech_db`. El modelo conserva las 62 tablas y 603 columnas aprobadas; 59 tablas forman el núcleo y 3 son opcionales para autenticación local. Los nombres no dependen de una versión del sistema ni de un curso.

## Tipos PostgreSQL

`bigint` para claves y consecutivos; `text` con CHECK para estados y textos; `numeric` con precisión/escala explícita para importes y cantidades; `date` para días; `timestamptz` para instantes; `boolean`, `uuid`, `bytea` y `jsonb` según el diccionario aprobado. No se crea un tipo ENUM ni un DOMAIN sin necesidad. Las transiciones entre estados siguen siendo una regla de fase 5.

La instalación usa PostgreSQL 18 y la extensión oficial `btree_gist` en `public`; las tablas de negocio están en los siete esquemas aprobados. No se crean tablespaces ni particiones sin volumen de datos y mediciones que los justifiquen. La zona horaria de presentación se define por conexión; `timestamptz` representa un instante, no conserva el nombre original de zona.

## Cantidad de objetos

| Objeto | Núcleo | Opcional | Total |
|---|---:|---:|---:|
| Tablas | 59 | 3 | 62 |
| Columnas | 588 | 15 | 603 |
| PRIMARY KEY | 59 | 3 | 62 |
| FOREIGN KEY | 134 | 3 | 137 |
| UNIQUE de tabla | 52 | 2 | 54 |
| CHECK de tabla | 342 | 8 | 350 |
| EXCLUDE | 7 | 0 | 7 |
| Índices CREATE INDEX / CREATE UNIQUE INDEX | 119 | 2 | 121 |

Los índices de PK, UNIQUE y EXCLUDE son creados por PostgreSQL y no se duplican con CREATE INDEX. Las FK que no eran prefijo de un índice B-tree reciben un índice de soporte. El parcial de movimiento_inventario.detalle_pedido_id WHERE detalle_pedido_id IS NOT NULL ya cubre todas sus referencias y no se duplica. Un índice filtrado por catálogo publicado o estados pendientes sí deja referencias fuera y no reemplaza el soporte general.

## Secuencias e identidades

Se utilizan 52 columnas `GENERATED ALWAYS AS IDENTITY`: 50 del núcleo y 2 opcionales. Las PK compartidas y compuestas no generan identidades artificiales. Además hay tres secuencias explícitas:

| Secuencia | Uso | Momento |
|---|---|---|
| `comercial.seq_pedido` | `pedido.numero` | DEFAULT al insertar pedido. |
| `comercial.seq_cotizacion` | `cotizacion.numero` | DEFAULT al insertar cotización. |
| `comercial.seq_factura` | `factura.numero` | La rutina de emisión, en fase 5, asignará el número. El borrador conserva NULL. |

Todas son bigint, positivas, sin ciclo y están vinculadas a su columna con OWNED BY. No se usa MAX(numero)+1. La secuencia puede tener saltos después de un rollback; no demuestra cumplimiento fiscal ni numeración legal sin huecos. Los UUID de idempotencia los aporta el backend y se conservan en un reintento.

## Datos calculados y preservación histórica

Las nueve columnas generadas STORED corresponden a subtotal, impuesto_importe y total de detalle_cotizacion, detalle_pedido y detalle_factura. Cada expresión usa únicamente columnas base de su propia fila; no referencia otra columna generada. Los valores históricos de precio, descripción, unidad y tasa permanecen en el detalle. Los ajustes de reparto quedan como datos base restringidos por las futuras rutinas de fase 5. No se suman cabeceras ni se copia un porcentaje global de proyecto.

Los importes de cabecera, stock disponible, avance ponderado y promedio de calificación se consultarán mediante las funciones/vistas de fase 5. El saldo de inventario aún no se sincroniza automáticamente con el libro de movimientos; no debe editarse desde una aplicación antes de completar esa fase.

## Exclusiones temporales

| Tabla | Restricción | Finalidad |
|---|---|---|
| `identidad.usuario_rol` | `ex_usuario_rol_periodos` | Impide solapar concesiones del mismo rol al mismo usuario. |
| `servicios.asignacion_servicio` | `ex_asignacion_servicio_periodos` | Evita períodos duplicados del mismo técnico en la misma orden. |
| `servicios.asignacion_servicio` | `ex_asignacion_servicio_principal` | Un responsable principal de la orden en cada instante. |
| `servicios.disponibilidad_tecnico` | `ex_disponibilidad_tecnico_periodos` | Evita duplicar ventanas habilitadas del técnico. |
| `servicios.cita_servicio` | `ex_cita_servicio_periodos` | Impide doble reserva del mismo técnico; permite citas adyacentes. |
| `proyectos.miembro_proyecto` | `ex_miembro_proyecto_periodos` | Evita períodos duplicados del miembro en el proyecto. |
| `proyectos.miembro_proyecto` | `ex_miembro_proyecto_principal` | Un responsable principal del proyecto en cada instante. |

Los rangos usan `[inicio,fin)`: se permite terminar a las 10:00 y comenzar otra cita a las 10:00. Un fin NULL representa continuidad; las fechas infinito explícitas se rechazan. No se usa now() en predicados de índices o CHECK. Las exclusiones se comprueban inmediatamente; al sustituir períodos se cierra primero el anterior dentro de la misma transacción. El técnico aún debe estar habilitado y su cita dentro de disponibilidad: controles entre tablas de fase 5.

## Índices explícitos

La siguiente lista incluye todos los índices adicionales. Son un punto de partida por patrones de consulta; el uso real se revisará con EXPLAIN (ANALYZE, BUFFERS) y pg_stat_user_indexes cuando existan datos representativos. No se afirma una mejora medida todavía. No se crean índices aislados por cada estado, fecha o booleano. Para búsqueda por subcadenas/acentos de productos se evaluará un índice de búsqueda específico cuando se concrete la consulta; el índice de catálogo resuelve categoría/precio, no LIKE con comodín inicial.

| Tabla | Índice / columnas | Condición | Consulta o regla beneficiada |
|---|---|---|---|
| `inventario.movimiento_inventario` | `ux_movimiento_inventario_parcial_1` — `detalle_pedido_id` | `detalle_pedido_id IS NOT NULL` | Una salida por línea entregada; no hay entregas parciales. |
| `inventario.producto_imagen` | `ux_producto_imagen_parcial_2` — `producto_id` | `principal` | Una imagen principal por producto. |
| `comercial.carrito` | `ux_carrito_parcial_3` — `cliente_id` | `estado = 'abierto' AND cliente_id IS NOT NULL` | Un carrito abierto por cliente. |
| `comercial.version_cotizacion` | `ux_version_cotizacion_parcial_4` — `cotizacion_id` | `estado = 'aceptada'` | Una versión aceptada por cotización. |
| `comercial.version_cotizacion` | `ux_version_cotizacion_parcial_5` — `cotizacion_id` | `estado = 'enviada'` | Una versión enviada por cotización. |
| `comercial.version_cotizacion` | `ux_version_cotizacion_parcial_6` — `cotizacion_id` | `estado = 'borrador'` | Una versión borrador por cotización. |
| `comunicacion.adjunto` | `ux_adjunto_archivo_mensaje_id` — `archivo_id, mensaje_id` | `mensaje_id IS NOT NULL` | No adjuntar dos veces el mismo archivo al mismo destino. |
| `comunicacion.adjunto` | `ux_adjunto_archivo_pedido_id` — `archivo_id, pedido_id` | `pedido_id IS NOT NULL` | No adjuntar dos veces el mismo archivo al mismo destino. |
| `comunicacion.adjunto` | `ux_adjunto_archivo_solicitud_servicio_id` — `archivo_id, solicitud_servicio_id` | `solicitud_servicio_id IS NOT NULL` | No adjuntar dos veces el mismo archivo al mismo destino. |
| `comunicacion.adjunto` | `ux_adjunto_archivo_orden_servicio_id` — `archivo_id, orden_servicio_id` | `orden_servicio_id IS NOT NULL` | No adjuntar dos veces el mismo archivo al mismo destino. |
| `comunicacion.adjunto` | `ux_adjunto_archivo_solicitud_cotizacion_id` — `archivo_id, solicitud_cotizacion_id` | `solicitud_cotizacion_id IS NOT NULL` | No adjuntar dos veces el mismo archivo al mismo destino. |
| `comunicacion.adjunto` | `ux_adjunto_archivo_cotizacion_id` — `archivo_id, cotizacion_id` | `cotizacion_id IS NOT NULL` | No adjuntar dos veces el mismo archivo al mismo destino. |
| `comunicacion.adjunto` | `ux_adjunto_archivo_solicitud_desarrollo_id` — `archivo_id, solicitud_desarrollo_id` | `solicitud_desarrollo_id IS NOT NULL` | No adjuntar dos veces el mismo archivo al mismo destino. |
| `comunicacion.adjunto` | `ux_adjunto_archivo_proyecto_id` — `archivo_id, proyecto_id` | `proyecto_id IS NOT NULL` | No adjuntar dos veces el mismo archivo al mismo destino. |
| `comunicacion.adjunto` | `ux_adjunto_archivo_factura_id` — `archivo_id, factura_id` | `factura_id IS NOT NULL` | No adjuntar dos veces el mismo archivo al mismo destino. |
| `comercial.pedido` | `ix_pedido_cliente_fecha` — `cliente_id, created_at DESC, id DESC` | Todas las filas | Historial paginado de compras por cliente (RF-11/RF-12). |
| `comercial.solicitud_cotizacion` | `ix_solicitud_cotizacion_persona_fecha` — `persona_id, created_at DESC, id DESC` | Todas las filas | Solicitudes e historial de cotizaciones de una persona, tenga cuenta o no. |
| `servicios.solicitud_servicio` | `ix_solicitud_servicio_cliente_fecha` — `cliente_id, created_at DESC, id DESC` | Todas las filas | Solicitudes e historial técnico de un cliente. |
| `proyectos.solicitud_desarrollo` | `ix_solicitud_desarrollo_cliente_fecha` — `cliente_id, created_at DESC, id DESC` | Todas las filas | Consulta de solicitudes de desarrollo del cliente. |
| `inventario.movimiento_inventario` | `ix_movimiento_inventario_producto_fecha` — `producto_id, registrado_en DESC, id DESC` | Todas las filas | Libro de movimientos del producto y conciliación de stock. |
| `proyectos.avance_proyecto` | `ix_avance_proyecto_etapa_fecha` — `etapa_proyecto_id, registrado_en DESC, id DESC` | Todas las filas | Último avance por etapa y consulta cronológica con desempate estable. |
| `comunicacion.mensaje` | `ix_mensaje_autor_fecha` — `autor_participante_id, enviado_en DESC, id DESC` | Todas las filas | Mensajes por participantes al consultar una conversación; conversación se deriva del autor. |
| `comunicacion.notificacion` | `ix_notificacion_destinatario_fecha` — `destinatario_usuario_id, created_at DESC, id DESC` | Todas las filas | Bandeja completa del destinatario con paginación. |
| `auditoria.evento_auditoria` | `ix_evento_auditoria_objeto_fecha` — `esquema_objeto, tabla_objeto, ocurrido_en DESC, id DESC` | Todas las filas | Revisión temporal de cambios en una tabla auditada. |
| `auditoria.evento_auditoria` | `ix_evento_auditoria_correlacion` — `correlacion_id` | Todas las filas | Reconstruir una operación que cambió varias tablas. |
| `comunicacion.notificacion` | `ix_notificacion_no_leida` — `destinatario_usuario_id, created_at DESC, id DESC` | `leida_en IS NULL` | Bandeja de pendientes sin recorrer las notificaciones ya leídas. |
| `comunicacion.entrega_notificacion` | `ix_entrega_notificacion_pendiente` — `created_at, id` | `estado = 'pendiente'` | Worker de entregas pendientes; selección y bloqueos se programan en fase 5. |
| `inventario.producto` | `ix_producto_catalogo` — `categoria_id, precio_vigente, id` | `activo AND publicado` | Catálogo publicado por categoría y rango de precio (RF-07/RF-08). |
| `identidad.acceso_invitado` | `ix_acceso_invitado_persona_id` — `persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.acceso_invitado` | `ix_acceso_invitado_version_cotizacion_id` — `version_cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.version_cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.acceso_invitado` | `ix_acceso_invitado_pedido_id` — `pedido_id` | Todas las filas | JOIN/FK hacia comercial.pedido.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.acceso_invitado` | `ix_acceso_invitado_solicitud_servicio_id` — `solicitud_servicio_id` | Todas las filas | JOIN/FK hacia servicios.solicitud_servicio.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.acceso_invitado` | `ix_acceso_invitado_orden_servicio_id` — `orden_servicio_id` | Todas las filas | JOIN/FK hacia servicios.orden_servicio.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.acceso_invitado` | `ix_acceso_invitado_solicitud_cotizacion_id` — `solicitud_cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.solicitud_cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.acceso_invitado` | `ix_acceso_invitado_cotizacion_id` — `cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.acceso_invitado` | `ix_acceso_invitado_solicitud_desarrollo_id` — `solicitud_desarrollo_id` | Todas las filas | JOIN/FK hacia proyectos.solicitud_desarrollo.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.acceso_invitado` | `ix_acceso_invitado_proyecto_id` — `proyecto_id` | Todas las filas | JOIN/FK hacia proyectos.proyecto.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.acceso_invitado` | `ix_acceso_invitado_factura_id` — `factura_id` | Todas las filas | JOIN/FK hacia comercial.factura.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.acceso_invitado` | `ix_acceso_invitado_conversacion_id` — `conversacion_id` | Todas las filas | JOIN/FK hacia comunicacion.conversacion.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.acceso_invitado_permiso` | `ix_acceso_invitado_permiso_permiso_id` — `permiso_id` | Todas las filas | JOIN/FK hacia identidad.permiso.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.rol_permiso` | `ix_rol_permiso_permiso_id` — `permiso_id` | Todas las filas | JOIN/FK hacia identidad.permiso.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.rol_permiso` | `ix_rol_permiso_actor_persona_id` — `actor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.usuario_rol` | `ix_usuario_rol_usuario_id` — `usuario_id` | Todas las filas | JOIN/FK hacia identidad.usuario.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.usuario_rol` | `ix_usuario_rol_rol_id` — `rol_id` | Todas las filas | JOIN/FK hacia identidad.rol.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.usuario_rol` | `ix_usuario_rol_actor_persona_id` — `actor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `inventario.movimiento_inventario` | `ix_movimiento_inventario_compensa_movimiento_id` — `compensa_movimiento_id` | Todas las filas | JOIN/FK hacia inventario.movimiento_inventario.id y comprobación eficiente de referencias al modificar el padre. |
| `inventario.movimiento_inventario` | `ix_movimiento_inventario_actor_persona_id` — `actor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `inventario.producto` | `ix_producto_categoria_id` — `categoria_id` | Todas las filas | JOIN/FK hacia inventario.categoria.id y comprobación eficiente de referencias al modificar el padre. |
| `inventario.producto_imagen` | `ix_producto_imagen_archivo_id` — `archivo_id` | Todas las filas | JOIN/FK hacia comunicacion.archivo.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.carrito` | `ix_carrito_cliente_id` — `cliente_id` | Todas las filas | JOIN/FK hacia identidad.cliente.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.comprobante_factura` | `ix_comprobante_factura_archivo_id` — `archivo_id` | Todas las filas | JOIN/FK hacia comunicacion.archivo.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.cotizacion` | `ix_cotizacion_persona_directa_id` — `persona_directa_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.detalle_carrito` | `ix_detalle_carrito_producto_id` — `producto_id` | Todas las filas | JOIN/FK hacia inventario.producto.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.detalle_cotizacion` | `ix_detalle_cotizacion_producto_id` — `producto_id` | Todas las filas | JOIN/FK hacia inventario.producto.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.detalle_cotizacion` | `ix_detalle_cotizacion_servicio_ofrecido_id` — `servicio_ofrecido_id` | Todas las filas | JOIN/FK hacia servicios.servicio_ofrecido.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.detalle_factura` | `ix_detalle_factura_detalle_pedido_id` — `detalle_pedido_id` | Todas las filas | JOIN/FK hacia comercial.detalle_pedido.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.detalle_factura` | `ix_detalle_factura_detalle_cotizacion_id` — `detalle_cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.detalle_cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.detalle_pedido` | `ix_detalle_pedido_producto_id` — `producto_id` | Todas las filas | JOIN/FK hacia inventario.producto.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.detalle_pedido` | `ix_detalle_pedido_detalle_cotizacion_id` — `detalle_cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.detalle_cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.factura` | `ix_factura_pedido_id` — `pedido_id` | Todas las filas | JOIN/FK hacia comercial.pedido.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.factura` | `ix_factura_orden_servicio_id` — `orden_servicio_id` | Todas las filas | JOIN/FK hacia servicios.orden_servicio.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.factura` | `ix_factura_proyecto_id` — `proyecto_id` | Todas las filas | JOIN/FK hacia proyectos.proyecto.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.historial_cotizacion` | `ix_historial_cotizacion_actor_persona_id` — `actor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.historial_cotizacion` | `ix_historial_cotizacion_version_cotizacion_id` — `version_cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.version_cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.historial_factura` | `ix_historial_factura_actor_persona_id` — `actor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.historial_pedido` | `ix_historial_pedido_actor_persona_id` — `actor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.historial_solicitud_cotizacion` | `ix_historial_solicitud_cotizacion_actor_persona_id` — `actor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.pedido` | `ix_pedido_version_cotizacion_id` — `version_cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.version_cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `comercial.version_cotizacion` | `ix_version_cotizacion_respondida_por_persona_id` — `respondida_por_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `servicios.asignacion_servicio` | `ix_asignacion_servicio_orden_servicio_id` — `orden_servicio_id` | Todas las filas | JOIN/FK hacia servicios.orden_servicio.id y comprobación eficiente de referencias al modificar el padre. |
| `servicios.asignacion_servicio` | `ix_asignacion_servicio_empleado_id` — `empleado_id` | Todas las filas | JOIN/FK hacia identidad.empleado.id y comprobación eficiente de referencias al modificar el padre. |
| `servicios.asignacion_servicio` | `ix_asignacion_servicio_actor_persona_id` — `actor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `servicios.calificacion_servicio` | `ix_calificacion_servicio_autor_persona_id` — `autor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `servicios.cita_servicio` | `ix_cita_servicio_solicitud_servicio_id` — `solicitud_servicio_id` | Todas las filas | JOIN/FK hacia servicios.solicitud_servicio.id y comprobación eficiente de referencias al modificar el padre. |
| `servicios.cita_servicio` | `ix_cita_servicio_tecnico_id` — `tecnico_id` | Todas las filas | JOIN/FK hacia identidad.empleado.id y comprobación eficiente de referencias al modificar el padre. |
| `servicios.disponibilidad_tecnico` | `ix_disponibilidad_tecnico_empleado_id` — `empleado_id` | Todas las filas | JOIN/FK hacia identidad.empleado.id y comprobación eficiente de referencias al modificar el padre. |
| `servicios.equipo_cliente` | `ix_equipo_cliente_cliente_id` — `cliente_id` | Todas las filas | JOIN/FK hacia identidad.cliente.id y comprobación eficiente de referencias al modificar el padre. |
| `servicios.historial_servicio` | `ix_historial_servicio_actor_persona_id` — `actor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `servicios.historial_solicitud_servicio` | `ix_historial_solicitud_servicio_actor_persona_id` — `actor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `servicios.orden_servicio` | `ix_orden_servicio_version_cotizacion_id` — `version_cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.version_cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `servicios.solicitud_servicio` | `ix_solicitud_servicio_servicio_ofrecido_id` — `servicio_ofrecido_id` | Todas las filas | JOIN/FK hacia servicios.servicio_ofrecido.id y comprobación eficiente de referencias al modificar el padre. |
| `servicios.solicitud_servicio` | `ix_solicitud_servicio_equipo_cliente_id` — `equipo_cliente_id` | Todas las filas | JOIN/FK hacia servicios.equipo_cliente.id y comprobación eficiente de referencias al modificar el padre. |
| `proyectos.avance_proyecto` | `ix_avance_proyecto_miembro_proyecto_id` — `miembro_proyecto_id` | Todas las filas | JOIN/FK hacia proyectos.miembro_proyecto.id y comprobación eficiente de referencias al modificar el padre. |
| `proyectos.historial_proyecto` | `ix_historial_proyecto_actor_persona_id` — `actor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `proyectos.historial_solicitud_desarrollo` | `ix_historial_solicitud_desarrollo_actor_persona_id` — `actor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `proyectos.miembro_proyecto` | `ix_miembro_proyecto_proyecto_id` — `proyecto_id` | Todas las filas | JOIN/FK hacia proyectos.proyecto.id y comprobación eficiente de referencias al modificar el padre. |
| `proyectos.miembro_proyecto` | `ix_miembro_proyecto_empleado_id` — `empleado_id` | Todas las filas | JOIN/FK hacia identidad.empleado.id y comprobación eficiente de referencias al modificar el padre. |
| `proyectos.miembro_proyecto` | `ix_miembro_proyecto_actor_persona_id` — `actor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `proyectos.proyecto` | `ix_proyecto_version_cotizacion_id` — `version_cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.version_cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.adjunto` | `ix_adjunto_archivo_id` — `archivo_id` | Todas las filas | JOIN/FK hacia comunicacion.archivo.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.adjunto` | `ix_adjunto_mensaje_id` — `mensaje_id` | Todas las filas | JOIN/FK hacia comunicacion.mensaje.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.adjunto` | `ix_adjunto_pedido_id` — `pedido_id` | Todas las filas | JOIN/FK hacia comercial.pedido.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.adjunto` | `ix_adjunto_solicitud_servicio_id` — `solicitud_servicio_id` | Todas las filas | JOIN/FK hacia servicios.solicitud_servicio.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.adjunto` | `ix_adjunto_orden_servicio_id` — `orden_servicio_id` | Todas las filas | JOIN/FK hacia servicios.orden_servicio.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.adjunto` | `ix_adjunto_solicitud_cotizacion_id` — `solicitud_cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.solicitud_cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.adjunto` | `ix_adjunto_cotizacion_id` — `cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.adjunto` | `ix_adjunto_solicitud_desarrollo_id` — `solicitud_desarrollo_id` | Todas las filas | JOIN/FK hacia proyectos.solicitud_desarrollo.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.adjunto` | `ix_adjunto_proyecto_id` — `proyecto_id` | Todas las filas | JOIN/FK hacia proyectos.proyecto.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.adjunto` | `ix_adjunto_factura_id` — `factura_id` | Todas las filas | JOIN/FK hacia comercial.factura.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.archivo` | `ix_archivo_actor_persona_id` — `actor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.conversacion` | `ix_conversacion_pedido_id` — `pedido_id` | Todas las filas | JOIN/FK hacia comercial.pedido.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.conversacion` | `ix_conversacion_solicitud_servicio_id` — `solicitud_servicio_id` | Todas las filas | JOIN/FK hacia servicios.solicitud_servicio.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.conversacion` | `ix_conversacion_orden_servicio_id` — `orden_servicio_id` | Todas las filas | JOIN/FK hacia servicios.orden_servicio.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.conversacion` | `ix_conversacion_solicitud_cotizacion_id` — `solicitud_cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.solicitud_cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.conversacion` | `ix_conversacion_cotizacion_id` — `cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.conversacion` | `ix_conversacion_solicitud_desarrollo_id` — `solicitud_desarrollo_id` | Todas las filas | JOIN/FK hacia proyectos.solicitud_desarrollo.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.conversacion` | `ix_conversacion_proyecto_id` — `proyecto_id` | Todas las filas | JOIN/FK hacia proyectos.proyecto.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.lectura_mensaje` | `ix_lectura_mensaje_participante_id` — `participante_id` | Todas las filas | JOIN/FK hacia comunicacion.participante_conversacion.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.notificacion` | `ix_notificacion_version_cotizacion_id` — `version_cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.version_cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.notificacion` | `ix_notificacion_pedido_id` — `pedido_id` | Todas las filas | JOIN/FK hacia comercial.pedido.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.notificacion` | `ix_notificacion_solicitud_servicio_id` — `solicitud_servicio_id` | Todas las filas | JOIN/FK hacia servicios.solicitud_servicio.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.notificacion` | `ix_notificacion_orden_servicio_id` — `orden_servicio_id` | Todas las filas | JOIN/FK hacia servicios.orden_servicio.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.notificacion` | `ix_notificacion_solicitud_cotizacion_id` — `solicitud_cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.solicitud_cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.notificacion` | `ix_notificacion_cotizacion_id` — `cotizacion_id` | Todas las filas | JOIN/FK hacia comercial.cotizacion.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.notificacion` | `ix_notificacion_solicitud_desarrollo_id` — `solicitud_desarrollo_id` | Todas las filas | JOIN/FK hacia proyectos.solicitud_desarrollo.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.notificacion` | `ix_notificacion_proyecto_id` — `proyecto_id` | Todas las filas | JOIN/FK hacia proyectos.proyecto.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.notificacion` | `ix_notificacion_factura_id` — `factura_id` | Todas las filas | JOIN/FK hacia comercial.factura.id y comprobación eficiente de referencias al modificar el padre. |
| `comunicacion.participante_conversacion` | `ix_participante_conversacion_persona_id` — `persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `auditoria.evento_auditoria` | `ix_evento_auditoria_actor_persona_id` — `actor_persona_id` | Todas las filas | JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.recuperacion_acceso` | `ix_recuperacion_acceso_usuario_id` — `usuario_id` | Todas las filas | JOIN/FK hacia identidad.usuario.id y comprobación eficiente de referencias al modificar el padre. |
| `identidad.sesion` | `ix_sesion_usuario_id` — `usuario_id` | Todas las filas | JOIN/FK hacia identidad.usuario.id y comprobación eficiente de referencias al modificar el padre. |

## Restricciones CHECK y justificación

NOT NULL se emite columna por columna conforme al diccionario. Un CHECK que recibe NULL puede resultar desconocido y ser aceptado por PostgreSQL; por eso las alternativas que requieren datos usan IS NOT NULL / num_nonnulls explícitos. Los CHECK globales permiten NULL solamente en campos opcionales. Las FK usan RESTRICT al actualizar o borrar; el borrado lógico evita perder historia.

| Tabla | CHECK | Finalidad |
|---|---|---|
| `identidad.acceso_invitado` | `ck_acceso_invitado_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `identidad.acceso_invitado` | `ck_acceso_invitado_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `identidad.acceso_invitado` | `ck_acceso_invitado_token_hash` | La huella SHA-256 del token debe ocupar exactamente 32 bytes. |
| `identidad.acceso_invitado` | `ck_acceso_invitado_fechas` | La concesión se emite después de verificar y tiene un intervalo de vigencia positivo; la revocación no precede a la emisión. |
| `identidad.acceso_invitado` | `ck_acceso_invitado_contexto` | Cada concesión habilita exactamente un recurso concreto; la versión de cotización es una precisión de ese recurso. |
| `identidad.acceso_invitado` | `ck_acceso_invitado_version_contexto` | Una versión solo se puede precisar cuando la concesión refiere una cotización. Verificar pertenencia corresponde a fase 5. |
| `identidad.cliente` | `ck_cliente_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `identidad.cliente` | `ck_cliente_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `identidad.cliente` | `ck_cliente_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `identidad.empleado` | `ck_empleado_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `identidad.empleado` | `ck_empleado_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `identidad.empleado` | `ck_empleado_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `identidad.permiso` | `ck_permiso_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `identidad.permiso` | `ck_permiso_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `identidad.permiso` | `ck_permiso_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `identidad.persona` | `ck_persona_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `identidad.persona` | `ck_persona_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `identidad.persona` | `ck_persona_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `identidad.persona` | `ck_persona_contacto` | La persona proporciona al menos un canal de contacto; el CHECK general de textos impide rellenarlo con una cadena vacía. |
| `identidad.rol` | `ck_rol_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `identidad.rol` | `ck_rol_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `identidad.rol` | `ck_rol_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `identidad.rol_permiso` | `ck_rol_permiso_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `identidad.rol_permiso` | `ck_rol_permiso_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `identidad.rol_permiso` | `ck_rol_permiso_actor` | Exactamente un responsable: persona o sistema identificado. |
| `identidad.usuario` | `ck_usuario_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `identidad.usuario` | `ck_usuario_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `identidad.usuario` | `ck_usuario_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `identidad.usuario` | `ck_usuario_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `identidad.usuario` | `ck_usuario_correo_normalizado` | Unicidad del correo sobre una representación normalizada. No pretende verificar propiedad ni implementar toda la sintaxis de correo. |
| `identidad.usuario` | `ck_usuario_origen_auth` | Las rutas de autenticación previstas son propia o delegada a un emisor externo. |
| `identidad.usuario` | `ck_usuario_identidad_externa` | La autenticación local no identifica emisor/sujeto; la externa exige ambos valores. Las comprobaciones generales de texto rechazan valores vacíos. |
| `identidad.usuario_rol` | `ck_usuario_rol_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `identidad.usuario_rol` | `ck_usuario_rol_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `identidad.usuario_rol` | `ck_usuario_rol_actor` | Exactamente un responsable: persona o sistema identificado. |
| `identidad.usuario_rol` | `ck_usuario_rol_intervalo` | Una asignación tiene duración positiva o permanece abierta. Los solapamientos requieren EXCLUDE, no CHECK. |
| `inventario.categoria` | `ck_categoria_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `inventario.categoria` | `ck_categoria_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `inventario.categoria` | `ck_categoria_fechas_registro` | La última modificación no precede a la creación del registro; su mantenimiento automático corresponde a fase 5. |
| `inventario.inventario` | `ck_inventario_numericos` | No admite NaN; los numeric con precisión limitada también rechazan infinitos. |
| `inventario.inventario` | `ck_inventario_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `inventario.inventario` | `ck_inventario_saldo_no_negativo` | No se admiten existencias físicas negativas. La conciliación con movimientos y reservas es transaccional en fase 5. |
| `inventario.movimiento_inventario` | `ck_movimiento_inventario_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `inventario.movimiento_inventario` | `ck_movimiento_inventario_numericos` | No admite NaN; los numeric con precisión limitada también rechazan infinitos. |
| `inventario.movimiento_inventario` | `ck_movimiento_inventario_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `inventario.movimiento_inventario` | `ck_movimiento_inventario_actor` | Exactamente un responsable: persona o sistema identificado. |
| `inventario.movimiento_inventario` | `ck_movimiento_tipo_delta` | Los tres tipos permitidos tienen una variación no nula y entrada/salida el signo correspondiente. |
| `inventario.movimiento_inventario` | `ck_movimiento_origen_salida` | Una referencia a detalle de pedido identifica una salida. La correspondencia de producto y cantidad se verifica en fase 5. |
| `inventario.movimiento_inventario` | `ck_movimiento_no_autocompensa` | Un movimiento compensatorio no puede referenciarse a sí mismo. |
| `inventario.producto` | `ck_producto_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `inventario.producto` | `ck_producto_numericos` | No admite NaN; los numeric con precisión limitada también rechazan infinitos. |
| `inventario.producto` | `ck_producto_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `inventario.producto` | `ck_producto_moneda` | Forma del código monetario; no selecciona moneda ni reglas fiscales por defecto. |
| `inventario.producto` | `ck_producto_precio_no_negativo` | El precio vigente admite cero, pero no valores negativos. |
| `inventario.producto` | `ck_producto_fechas_registro` | La última modificación no precede a la creación del registro; su mantenimiento automático corresponde a fase 5. |
| `inventario.producto_imagen` | `ck_producto_imagen_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `inventario.producto_imagen` | `ck_producto_imagen_orden_positivo` | Posición positiva de presentación de la imagen. |
| `inventario.reserva_inventario` | `ck_reserva_inventario_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `inventario.reserva_inventario` | `ck_reserva_inventario_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `inventario.reserva_inventario` | `ck_reserva_inventario_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `inventario.reserva_inventario` | `ck_reserva_cierre_estado` | La reserva activa no está cerrada; consumir o liberar requiere registrar su cierre. |
| `inventario.reserva_inventario` | `ck_reserva_fechas` | El cierre de la reserva no precede a su creación. |
| `inventario.reserva_inventario` | `ck_reserva_motivo_liberacion` | El motivo de liberación es obligatorio y exclusivo del estado liberada; la validación global impide texto vacío. |
| `comercial.carrito` | `ck_carrito_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comercial.carrito` | `ck_carrito_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comercial.carrito` | `ck_carrito_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `comercial.carrito` | `ck_carrito_titular_xor` | El carrito corresponde a un cliente o a una sesión anónima, sin identidad ausente ni duplicada. |
| `comercial.carrito` | `ck_carrito_huella_32_bytes` | La huella del identificador anónimo tiene 32 bytes. |
| `comercial.carrito` | `ck_carrito_fechas_registro` | La última modificación no precede a la creación del registro; su mantenimiento automático corresponde a fase 5. |
| `comercial.comprobante_factura` | `ck_comprobante_factura_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comercial.comprobante_factura` | `ck_comprobante_factura_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comercial.cotizacion` | `ck_cotizacion_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comercial.cotizacion` | `ck_cotizacion_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comercial.cotizacion` | `ck_cotizacion_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `comercial.cotizacion` | `ck_cotizacion_destinatario_xor` | La titularidad deriva de una solicitud o de la persona destinataria de una oferta directa. |
| `comercial.cotizacion` | `ck_cotizacion_numero_positivo` | El consecutivo comercial es positivo, incluso cuando se inserta de forma explícita. |
| `comercial.cotizacion` | `ck_cotizacion_fechas_registro` | La última modificación no precede a la creación del registro; su mantenimiento automático corresponde a fase 5. |
| `comercial.detalle_carrito` | `ck_detalle_carrito_numericos` | No admite NaN; los numeric con precisión limitada también rechazan infinitos. |
| `comercial.detalle_carrito` | `ck_detalle_carrito_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comercial.detalle_carrito` | `ck_detalle_carrito_cantidad` | Una línea del carrito representa una cantidad positiva. |
| `comercial.detalle_carrito` | `ck_detalle_carrito_fechas_registro` | La última modificación no precede a la creación del registro; su mantenimiento automático corresponde a fase 5. |
| `comercial.detalle_cotizacion` | `ck_detalle_cotizacion_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comercial.detalle_cotizacion` | `ck_detalle_cotizacion_numericos` | No admite NaN; los numeric con precisión limitada también rechazan infinitos. |
| `comercial.detalle_cotizacion` | `ck_detalle_cotizacion_cantidad_precio_descuento` | Cantidades positivas y precios/descuentos no negativos; las columnas numéricas rechazan NaN mediante validación global. |
| `comercial.detalle_cotizacion` | `ck_detalle_cotizacion_tasa` | La tasa se expresa explícitamente como fracción dentro de [0,1], sin establecer un porcentaje fiscal. |
| `comercial.detalle_cotizacion` | `ck_detalle_cotizacion_numero_linea` | El orden de la línea es positivo. |
| `comercial.detalle_cotizacion` | `ck_detalle_cotizacion_importes_no_negativos` | Los valores de base e impuesto generados deben ser no negativos, incluidos los ajustes de reparto cuando existan. |
| `comercial.detalle_cotizacion` | `ck_detalle_cotizacion_descuento_limite` | El descuento original no supera el importe bruto redondeado de la línea cotizada. |
| `comercial.detalle_cotizacion` | `ck_detalle_cotizacion_clase_origen` | Cada clase usa exclusivamente su referencia correspondiente; un concepto libre no apunta a producto ni a catálogo de servicios. |
| `comercial.detalle_factura` | `ck_detalle_factura_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comercial.detalle_factura` | `ck_detalle_factura_numericos` | No admite NaN; los numeric con precisión limitada también rechazan infinitos. |
| `comercial.detalle_factura` | `ck_detalle_factura_cantidad_precio_descuento` | Cantidades positivas y precios/descuentos no negativos; las columnas numéricas rechazan NaN mediante validación global. |
| `comercial.detalle_factura` | `ck_detalle_factura_tasa` | La tasa se expresa explícitamente como fracción dentro de [0,1], sin establecer un porcentaje fiscal. |
| `comercial.detalle_factura` | `ck_detalle_factura_numero_linea` | El orden de la línea es positivo. |
| `comercial.detalle_factura` | `ck_detalle_factura_importes_no_negativos` | Los valores de base e impuesto generados deben ser no negativos, incluidos los ajustes de reparto cuando existan. |
| `comercial.detalle_factura` | `ck_detalle_factura_max_un_origen` | La línea consume una línea de pedido, una de cotización o una autorización directa; la ruta precisa depende de la cabecera y se valida en fase 5. |
| `comercial.detalle_pedido` | `ck_detalle_pedido_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comercial.detalle_pedido` | `ck_detalle_pedido_numericos` | No admite NaN; los numeric con precisión limitada también rechazan infinitos. |
| `comercial.detalle_pedido` | `ck_detalle_pedido_cantidad_precio_descuento` | Cantidades positivas y precios/descuentos no negativos; las columnas numéricas rechazan NaN mediante validación global. |
| `comercial.detalle_pedido` | `ck_detalle_pedido_tasa` | La tasa se expresa explícitamente como fracción dentro de [0,1], sin establecer un porcentaje fiscal. |
| `comercial.detalle_pedido` | `ck_detalle_pedido_numero_linea` | El orden de la línea es positivo. |
| `comercial.detalle_pedido` | `ck_detalle_pedido_importes_no_negativos` | Los valores de base e impuesto generados deben ser no negativos, incluidos los ajustes de reparto cuando existan. |
| `comercial.detalle_pedido` | `ck_detalle_pedido_ajustes_directos` | Un pedido sin concepto cotizado no contiene ajustes de reparto. La coherencia entre detalle y cabecera se verifica en fase 5. |
| `comercial.factura` | `ck_factura_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comercial.factura` | `ck_factura_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comercial.factura` | `ck_factura_moneda` | Forma del código monetario; no selecciona moneda ni reglas fiscales por defecto. |
| `comercial.factura` | `ck_factura_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `comercial.factura` | `ck_factura_origen_xor` | La factura tiene exactamente uno de los tres orígenes autorizados. |
| `comercial.factura` | `ck_factura_numero_positivo` | El número comercial asignado al emitir es positivo. |
| `comercial.factura` | `ck_factura_emision_estado` | Un borrador no tiene número ni evidencia de emisión; emitir y anular conservan los tres datos de emisión. |
| `comercial.factura` | `ck_factura_anulacion_estado` | Anular exige fecha y motivo; no se aceptan campos de anulación en otros estados. |
| `comercial.factura` | `ck_factura_emision_fecha` | La fecha de emisión no precede a la creación del borrador. |
| `comercial.factura` | `ck_factura_anulacion_fecha` | La anulación exige una emisión previa y no la precede. |
| `comercial.factura` | `ck_factura_fechas_registro` | La última modificación no precede a la creación del registro; su mantenimiento automático corresponde a fase 5. |
| `comercial.historial_cotizacion` | `ck_historial_cotizacion_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comercial.historial_cotizacion` | `ck_historial_cotizacion_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comercial.historial_cotizacion` | `ck_historial_cotizacion_actor` | Exactamente un responsable: persona o sistema identificado. |
| `comercial.historial_cotizacion` | `ck_historial_cotizacion_ordinal` | El primer evento carece de estado anterior; los siguientes lo requieren. La consecutividad y correspondencia real con el proceso son transaccionales. |
| `comercial.historial_cotizacion` | `ck_historial_cotizacion_estados` | Los estados registrados pertenecen al mismo dominio que el proceso principal. |
| `comercial.historial_cotizacion` | `ck_historial_cotizacion_version_contexto` | Un evento relativo a una versión identifica esa versión y su estado nuevo. El estado anterior puede ser NULL al crear una nueva versión, aunque no sea el primer evento general. |
| `comercial.historial_cotizacion` | `ck_historial_cotizacion_version_estados` | Los estados específicos de versión usan su propio dominio, distinto del estado general de la negociación. |
| `comercial.historial_cotizacion` | `ck_historial_cotizacion_cambio_efectivo` | Permite mantener el estado general si cambia o se crea una versión; impide eventos posteriores sin ningún cambio. |
| `comercial.historial_factura` | `ck_historial_factura_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comercial.historial_factura` | `ck_historial_factura_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comercial.historial_factura` | `ck_historial_factura_actor` | Exactamente un responsable: persona o sistema identificado. |
| `comercial.historial_factura` | `ck_historial_factura_ordinal` | El primer evento carece de estado anterior; los siguientes lo requieren. La consecutividad y correspondencia real con el proceso son transaccionales. |
| `comercial.historial_factura` | `ck_historial_factura_estados` | Los estados registrados pertenecen al mismo dominio que el proceso principal. |
| `comercial.historial_factura` | `ck_historial_factura_cambio_efectivo` | Después del evento inicial se registran cambios efectivos de estado. |
| `comercial.historial_pedido` | `ck_historial_pedido_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comercial.historial_pedido` | `ck_historial_pedido_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comercial.historial_pedido` | `ck_historial_pedido_actor` | Exactamente un responsable: persona o sistema identificado. |
| `comercial.historial_pedido` | `ck_historial_pedido_ordinal` | El primer evento carece de estado anterior; los siguientes lo requieren. La consecutividad y correspondencia real con el proceso son transaccionales. |
| `comercial.historial_pedido` | `ck_historial_pedido_estados` | Los estados registrados pertenecen al mismo dominio que el proceso principal. |
| `comercial.historial_pedido` | `ck_historial_pedido_cambio_efectivo` | Después del evento inicial se registran cambios efectivos de estado. |
| `comercial.historial_solicitud_cotizacion` | `ck_historial_solicitud_cotizacion_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comercial.historial_solicitud_cotizacion` | `ck_historial_solicitud_cotizacion_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comercial.historial_solicitud_cotizacion` | `ck_historial_solicitud_cotizacion_actor` | Exactamente un responsable: persona o sistema identificado. |
| `comercial.historial_solicitud_cotizacion` | `ck_historial_solicitud_cotizacion_ordinal` | El primer evento carece de estado anterior; los siguientes lo requieren. La consecutividad y correspondencia real con el proceso son transaccionales. |
| `comercial.historial_solicitud_cotizacion` | `ck_historial_solicitud_cotizacion_estados` | Los estados registrados pertenecen al mismo dominio que el proceso principal. |
| `comercial.historial_solicitud_cotizacion` | `ck_historial_solicitud_cotizacion_cambio_efectivo` | Después del evento inicial se registran cambios efectivos de estado. |
| `comercial.pedido` | `ck_pedido_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comercial.pedido` | `ck_pedido_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comercial.pedido` | `ck_pedido_moneda` | Forma del código monetario; no selecciona moneda ni reglas fiscales por defecto. |
| `comercial.pedido` | `ck_pedido_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `comercial.pedido` | `ck_pedido_numero_positivo` | El consecutivo comercial es positivo. |
| `comercial.pedido` | `ck_pedido_contacto` | El snapshot del receptor conserva al menos un canal de contacto; textos vacíos se rechazan globalmente. |
| `comercial.pedido` | `ck_pedido_confirmacion_pareja` | La fecha de confirmación y su identificador de operación se guardan conjuntamente, incluida una cancelación posterior. |
| `comercial.pedido` | `ck_pedido_confirmacion_estado` | Borrador carece de confirmación; los estados confirmados la requieren. Cancelado puede proceder de borrador o de un pedido confirmado. |
| `comercial.pedido` | `ck_pedido_completado_estado` | Solo el pedido completado tiene fecha de finalización; el flujo aprobado no admite cancelación de pedidos completados. |
| `comercial.pedido` | `ck_pedido_cancelacion_estado` | Cancelar requiere fecha y motivo; los demás estados no guardan datos de cancelación. |
| `comercial.pedido` | `ck_pedido_confirmacion_fecha` | La confirmación no precede a la creación del pedido. |
| `comercial.pedido` | `ck_pedido_completado_fecha` | Completar requiere una confirmación previa y una fecha coherente. |
| `comercial.pedido` | `ck_pedido_cancelacion_fecha` | La cancelación no precede a la creación ni a una confirmación existente. |
| `comercial.pedido` | `ck_pedido_fechas_registro` | La última modificación no precede a la creación del registro; su mantenimiento automático corresponde a fase 5. |
| `comercial.solicitud_cotizacion` | `ck_solicitud_cotizacion_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comercial.solicitud_cotizacion` | `ck_solicitud_cotizacion_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comercial.solicitud_cotizacion` | `ck_solicitud_cotizacion_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `comercial.solicitud_cotizacion` | `ck_solicitud_cotizacion_contacto` | La solicitud, incluso de visitante, conserva al menos un canal de contacto. |
| `comercial.solicitud_cotizacion` | `ck_solicitud_cotizacion_fechas_registro` | La última modificación no precede a la creación del registro; su mantenimiento automático corresponde a fase 5. |
| `comercial.version_cotizacion` | `ck_version_cotizacion_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comercial.version_cotizacion` | `ck_version_cotizacion_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comercial.version_cotizacion` | `ck_version_cotizacion_moneda` | Forma del código monetario; no selecciona moneda ni reglas fiscales por defecto. |
| `comercial.version_cotizacion` | `ck_version_cotizacion_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `comercial.version_cotizacion` | `ck_version_cotizacion_numero` | Número de versión positivo dentro de la negociación. |
| `comercial.version_cotizacion` | `ck_version_cotizacion_vigencia` | La vigencia vence después de la creación y del envío, sin consultar el reloj en un CHECK. |
| `comercial.version_cotizacion` | `ck_version_cotizacion_envio_fecha` | El envío de la versión no precede a su creación. |
| `comercial.version_cotizacion` | `ck_version_cotizacion_envio_estado` | Los estados posteriores al envío exigen evidencia de envío; la versión anulada puede proceder de borrador o de enviada. |
| `comercial.version_cotizacion` | `ck_version_cotizacion_contacto_enviada` | Una oferta enviada conserva al menos un canal de contacto; el borrador puede completarlo antes de enviar. |
| `comercial.version_cotizacion` | `ck_version_cotizacion_respuesta_estado` | Aceptar o rechazar requiere fecha, persona, envío y evidencia. Los demás estados no conservan campos de respuesta contradictorios. |
| `comercial.version_cotizacion` | `ck_version_cotizacion_respuesta_fecha` | La respuesta corresponde a un instante dentro del periodo de vigencia a partir del envío. Verificar el tiempo real al responder se implementa en fase 5. |
| `comercial.version_cotizacion` | `ck_version_cotizacion_fechas_registro` | La última modificación no precede a la creación del registro; su mantenimiento automático corresponde a fase 5. |
| `servicios.asignacion_servicio` | `ck_asignacion_servicio_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `servicios.asignacion_servicio` | `ck_asignacion_servicio_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `servicios.asignacion_servicio` | `ck_asignacion_servicio_actor` | Exactamente un responsable: persona o sistema identificado. |
| `servicios.asignacion_servicio` | `ck_asignacion_servicio_periodo` | Cada asignación tiene un período no vacío; NULL conserva un extremo final abierto. |
| `servicios.calificacion_servicio` | `ck_calificacion_servicio_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `servicios.calificacion_servicio` | `ck_calificacion_servicio_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `servicios.calificacion_servicio` | `ck_calificacion_servicio_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `servicios.calificacion_servicio` | `ck_calificacion_servicio_puntuacion` | Escala de valoración aprobada en la fase 3. |
| `servicios.cita_servicio` | `ck_cita_servicio_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `servicios.cita_servicio` | `ck_cita_servicio_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `servicios.cita_servicio` | `ck_cita_servicio_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `servicios.cita_servicio` | `ck_cita_servicio_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `servicios.cita_servicio` | `ck_cita_servicio_intervalo` | Toda cita representa un intervalo temporal no vacío. |
| `servicios.cita_servicio` | `ck_cita_servicio_modalidad` | Modalidades de atención definidas en el modelo lógico. |
| `servicios.cita_servicio` | `ck_cita_servicio_tecnico` | La confirmación y la atención realizada requieren un técnico identificado. |
| `servicios.cita_servicio` | `ck_cita_servicio_lugar` | Una cita presencial exige lugar informado; IS NOT NULL evita aceptar UNKNOWN. |
| `servicios.cita_servicio` | `ck_cita_servicio_cancelacion` | Cancelar una cita requiere motivo explícito. |
| `servicios.cita_servicio` | `ck_cita_servicio_no_autosustitucion` | Una cita no puede sustituirse a sí misma; igualdad de solicitud y estado de la cita previa quedan en T03. |
| `servicios.disponibilidad_tecnico` | `ck_disponibilidad_tecnico_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `servicios.disponibilidad_tecnico` | `ck_disponibilidad_tecnico_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `servicios.disponibilidad_tecnico` | `ck_disponibilidad_tecnico_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `servicios.disponibilidad_tecnico` | `ck_disponibilidad_tecnico_intervalo` | Una ventana de disponibilidad debe tener duración positiva. |
| `servicios.equipo_cliente` | `ck_equipo_cliente_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `servicios.equipo_cliente` | `ck_equipo_cliente_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `servicios.equipo_cliente` | `ck_equipo_cliente_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `servicios.historial_servicio` | `ck_historial_servicio_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `servicios.historial_servicio` | `ck_historial_servicio_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `servicios.historial_servicio` | `ck_historial_servicio_actor` | Exactamente un responsable: persona o sistema identificado. |
| `servicios.historial_servicio` | `ck_historial_servicio_numero_evento` | Ordinal positivo por orden. |
| `servicios.historial_servicio` | `ck_historial_servicio_evento_inicial` | El evento inicial no tiene estado anterior; las transiciones posteriores sí. |
| `servicios.historial_servicio` | `ck_historial_servicio_estado_nuevo` | Mismo dominio de estados de orden_servicio. |
| `servicios.historial_servicio` | `ck_historial_servicio_estado_anterior` | Estado previo válido cuando exista. |
| `servicios.historial_servicio` | `ck_historial_servicio_transicion_efectiva` | El historial registra cambios efectivos; el primer evento conserva estado anterior NULL. |
| `servicios.historial_solicitud_servicio` | `ck_historial_solicitud_servicio_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `servicios.historial_solicitud_servicio` | `ck_historial_solicitud_servicio_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `servicios.historial_solicitud_servicio` | `ck_historial_solicitud_servicio_actor` | Exactamente un responsable: persona o sistema identificado. |
| `servicios.historial_solicitud_servicio` | `ck_hist_sol_servicio_numero_evento` | Ordinal positivo por solicitud. |
| `servicios.historial_solicitud_servicio` | `ck_hist_sol_servicio_evento_inicial` | Distingue creación y transiciones posteriores. |
| `servicios.historial_solicitud_servicio` | `ck_hist_sol_servicio_estado_nuevo` | Mismo dominio de estados de solicitud_servicio. |
| `servicios.historial_solicitud_servicio` | `ck_hist_sol_servicio_estado_anterior` | Estado previo válido cuando exista. |
| `servicios.historial_solicitud_servicio` | `ck_hist_sol_servicio_transicion_efectiva` | Se registra únicamente transición efectiva además del evento inicial. |
| `servicios.mantenimiento` | `ck_mantenimiento_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `servicios.mantenimiento` | `ck_mantenimiento_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `servicios.mantenimiento` | `ck_mantenimiento_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `servicios.orden_servicio` | `ck_orden_servicio_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `servicios.orden_servicio` | `ck_orden_servicio_numericos` | No admite NaN; los numeric con precisión limitada también rechazan infinitos. |
| `servicios.orden_servicio` | `ck_orden_servicio_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `servicios.orden_servicio` | `ck_orden_servicio_moneda` | Forma del código monetario; no selecciona moneda ni reglas fiscales por defecto. |
| `servicios.orden_servicio` | `ck_orden_servicio_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `servicios.orden_servicio` | `ck_orden_servicio_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `servicios.orden_servicio` | `ck_orden_servicio_inicio_por_estado` | La ejecución, pausa y finalización presuponen un inicio registrado. |
| `servicios.orden_servicio` | `ck_orden_servicio_cierre_por_estado` | Finalizar exige fecha y resumen; no permite que NULL evada el CHECK. |
| `servicios.orden_servicio` | `ck_orden_servicio_cronologia_real` | Una finalización informada requiere inicio y no puede precederlo. |
| `servicios.orden_servicio` | `ck_orden_servicio_autorizacion_economica` | Ruta exclusiva: versión de cotización o autorización directa completa; no admite rutas parciales. |
| `servicios.orden_servicio` | `ck_orden_servicio_importe_autorizado` | El techo de facturación directa no puede ser negativo. |
| `servicios.orden_servicio` | `ck_orden_servicio_tasa_autorizada` | Tasa expresada como fracción entre cero y uno; no fija ninguna tasa fiscal. |
| `servicios.reparacion` | `ck_reparacion_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `servicios.reparacion` | `ck_reparacion_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `servicios.reparacion` | `ck_reparacion_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `servicios.servicio_ofrecido` | `ck_servicio_ofrecido_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `servicios.servicio_ofrecido` | `ck_servicio_ofrecido_numericos` | No admite NaN; los numeric con precisión limitada también rechazan infinitos. |
| `servicios.servicio_ofrecido` | `ck_servicio_ofrecido_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `servicios.servicio_ofrecido` | `ck_servicio_ofrecido_moneda` | Forma del código monetario; no selecciona moneda ni reglas fiscales por defecto. |
| `servicios.servicio_ofrecido` | `ck_servicio_ofrecido_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `servicios.servicio_ofrecido` | `ck_servicio_ofrecido_modalidad` | Modalidades técnicas del catálogo aprobado. |
| `servicios.servicio_ofrecido` | `ck_servicio_ofrecido_duracion` | La duración estimada, si se informa, es positiva. |
| `servicios.servicio_ofrecido` | `ck_servicio_ofrecido_precio` | El precio orientativo no puede ser negativo. |
| `servicios.servicio_ofrecido` | `ck_servicio_ofrecido_precio_moneda` | Precio y moneda se informan juntos o se omiten juntos. |
| `servicios.solicitud_servicio` | `ck_solicitud_servicio_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `servicios.solicitud_servicio` | `ck_solicitud_servicio_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `servicios.solicitud_servicio` | `ck_solicitud_servicio_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `servicios.solicitud_servicio` | `ck_solicitud_servicio_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `proyectos.avance_proyecto` | `ck_avance_proyecto_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `proyectos.avance_proyecto` | `ck_avance_proyecto_numericos` | No admite NaN; los numeric con precisión limitada también rechazan infinitos. |
| `proyectos.avance_proyecto` | `ck_avance_proyecto_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `proyectos.avance_proyecto` | `ck_avance_proyecto_porcentaje` | Cada reporte mide un porcentaje entre cero y cien, sin exigir incremento monotónico. |
| `proyectos.etapa_proyecto` | `ck_etapa_proyecto_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `proyectos.etapa_proyecto` | `ck_etapa_proyecto_numericos` | No admite NaN; los numeric con precisión limitada también rechazan infinitos. |
| `proyectos.etapa_proyecto` | `ck_etapa_proyecto_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `proyectos.etapa_proyecto` | `ck_etapa_proyecto_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `proyectos.etapa_proyecto` | `ck_etapa_proyecto_orden` | Posición positiva de la etapa dentro del proyecto. |
| `proyectos.etapa_proyecto` | `ck_etapa_proyecto_peso` | Peso estrictamente positivo para calcular avance ponderado; no impone suma igual a cien. |
| `proyectos.etapa_proyecto` | `ck_etapa_proyecto_fechas_planificadas` | Si ambas fechas existen, el fin no precede al inicio; el modelo permite fechas parciales. |
| `proyectos.historial_proyecto` | `ck_historial_proyecto_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `proyectos.historial_proyecto` | `ck_historial_proyecto_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `proyectos.historial_proyecto` | `ck_historial_proyecto_actor` | Exactamente un responsable: persona o sistema identificado. |
| `proyectos.historial_proyecto` | `ck_historial_proyecto_numero_evento` | Ordinal positivo por proyecto. |
| `proyectos.historial_proyecto` | `ck_historial_proyecto_evento_inicial` | Distingue creación de proyecto y transiciones posteriores. |
| `proyectos.historial_proyecto` | `ck_historial_proyecto_estado_nuevo` | Mismo dominio de estados de proyecto. |
| `proyectos.historial_proyecto` | `ck_historial_proyecto_estado_anterior` | Estado previo válido cuando exista. |
| `proyectos.historial_proyecto` | `ck_historial_proyecto_transicion_efectiva` | Únicamente transiciones efectivas además del evento inicial. |
| `proyectos.historial_solicitud_desarrollo` | `ck_historial_solicitud_desarrollo_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `proyectos.historial_solicitud_desarrollo` | `ck_historial_solicitud_desarrollo_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `proyectos.historial_solicitud_desarrollo` | `ck_historial_solicitud_desarrollo_actor` | Exactamente un responsable: persona o sistema identificado. |
| `proyectos.historial_solicitud_desarrollo` | `ck_hist_sol_desarrollo_numero_evento` | Ordinal positivo por solicitud de desarrollo. |
| `proyectos.historial_solicitud_desarrollo` | `ck_hist_sol_desarrollo_evento_inicial` | Distingue recepción y transiciones posteriores. |
| `proyectos.historial_solicitud_desarrollo` | `ck_hist_sol_desarrollo_estado_nuevo` | Mismo dominio de estados de solicitud_desarrollo. |
| `proyectos.historial_solicitud_desarrollo` | `ck_hist_sol_desarrollo_estado_anterior` | Estado previo válido cuando exista. |
| `proyectos.historial_solicitud_desarrollo` | `ck_hist_sol_desarrollo_transicion_efectiva` | Se registra únicamente transición efectiva además del evento inicial. |
| `proyectos.miembro_proyecto` | `ck_miembro_proyecto_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `proyectos.miembro_proyecto` | `ck_miembro_proyecto_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `proyectos.miembro_proyecto` | `ck_miembro_proyecto_actor` | Exactamente un responsable: persona o sistema identificado. |
| `proyectos.miembro_proyecto` | `ck_miembro_proyecto_periodo` | Participación con período no vacío; NULL permite continuidad sin fin declarado. |
| `proyectos.proyecto` | `ck_proyecto_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `proyectos.proyecto` | `ck_proyecto_numericos` | No admite NaN; los numeric con precisión limitada también rechazan infinitos. |
| `proyectos.proyecto` | `ck_proyecto_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `proyectos.proyecto` | `ck_proyecto_moneda` | Forma del código monetario; no selecciona moneda ni reglas fiscales por defecto. |
| `proyectos.proyecto` | `ck_proyecto_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `proyectos.proyecto` | `ck_proyecto_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `proyectos.proyecto` | `ck_proyecto_inicio_por_estado` | La ejecución, suspensión y finalización presuponen inicio registrado. |
| `proyectos.proyecto` | `ck_proyecto_cierre_por_estado` | Un proyecto finalizado exige fecha de finalización. |
| `proyectos.proyecto` | `ck_proyecto_fechas_planificadas` | Si ambas fechas existen, el fin no precede al inicio; permite planificación parcial. |
| `proyectos.proyecto` | `ck_proyecto_cronologia_real` | Una finalización informada requiere inicio y no puede precederlo. |
| `proyectos.proyecto` | `ck_proyecto_autorizacion_economica` | Cotización o autorización directa completa, sin duplicar ni mezclar rutas económicas. |
| `proyectos.proyecto` | `ck_proyecto_importe_autorizado` | El techo de autorización directa no puede ser negativo. |
| `proyectos.proyecto` | `ck_proyecto_tasa_autorizada` | Tasa fraccional entre cero y uno, sin definir reglas fiscales externas. |
| `proyectos.solicitud_desarrollo` | `ck_solicitud_desarrollo_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `proyectos.solicitud_desarrollo` | `ck_solicitud_desarrollo_numericos` | No admite NaN; los numeric con precisión limitada también rechazan infinitos. |
| `proyectos.solicitud_desarrollo` | `ck_solicitud_desarrollo_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `proyectos.solicitud_desarrollo` | `ck_solicitud_desarrollo_moneda` | Forma del código monetario; no selecciona moneda ni reglas fiscales por defecto. |
| `proyectos.solicitud_desarrollo` | `ck_solicitud_desarrollo_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `proyectos.solicitud_desarrollo` | `ck_solicitud_desarrollo_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `proyectos.solicitud_desarrollo` | `ck_solicitud_desarrollo_presupuesto` | El presupuesto orientativo no puede ser negativo ni se interpreta como autorización económica. |
| `proyectos.solicitud_desarrollo` | `ck_solicitud_desarrollo_presupuesto_moneda` | Presupuesto y moneda se informan juntos o se omiten juntos. |
| `comunicacion.adjunto` | `ck_adjunto_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comunicacion.adjunto` | `ck_adjunto_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comunicacion.adjunto` | `ck_adjunto_contexto` | Cada asociación de archivo tiene exactamente un destino verificable mediante FK. |
| `comunicacion.adjunto` | `ck_adjunto_visibilidad` | La audiencia se expresa mediante el ámbito compartido o el ámbito interno de su proceso. |
| `comunicacion.adjunto` | `ck_adjunto_mensaje_compartido` | En un mensaje, la conversación define la audiencia y el adjunto se comparte entre sus participantes; se evita un adjunto interno ambiguo. |
| `comunicacion.archivo` | `ck_archivo_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comunicacion.archivo` | `ck_archivo_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comunicacion.archivo` | `ck_archivo_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `comunicacion.archivo` | `ck_archivo_actor` | Exactamente un responsable: persona o sistema identificado. |
| `comunicacion.archivo` | `ck_archivo_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `comunicacion.archivo` | `ck_archivo_tamano` | El tamaño de un objeto puede ser cero, pero no negativo. |
| `comunicacion.archivo` | `ck_archivo_huella` | La huella de integridad, cuando exista, debe tener la longitud SHA-256. |
| `comunicacion.archivo` | `ck_archivo_visibilidad` | Clasificación explícita del objeto; autorizar su publicación y revisar todas sus asociaciones corresponde a fase 5 y fase 6. |
| `comunicacion.conversacion` | `ck_conversacion_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comunicacion.conversacion` | `ck_conversacion_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comunicacion.conversacion` | `ck_conversacion_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `comunicacion.conversacion` | `ck_conversacion_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `comunicacion.conversacion` | `ck_conversacion_contexto` | Una conversación puede ser un contacto general o estar asociada a un solo proceso. |
| `comunicacion.entrega_notificacion` | `ck_entrega_notificacion_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comunicacion.entrega_notificacion` | `ck_entrega_notificacion_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comunicacion.entrega_notificacion` | `ck_entrega_notificacion_estado` | Dominio de estados aprobado; las transiciones se implementarán en fase 5. |
| `comunicacion.entrega_notificacion` | `ck_entrega_notificacion_fechas_registro` | La última modificación no puede preceder a la creación. Su actualización automática corresponde a fase 5. |
| `comunicacion.entrega_notificacion` | `ck_entrega_notificacion_intento` | Cada intento tiene una numeración positiva. |
| `comunicacion.entrega_notificacion` | `ck_entrega_notificacion_fechas` | Los instantes locales del intento siguen creación, inicio, finalización del envío y registro de confirmación de entrega. Una fecha posterior exige la anterior. |
| `comunicacion.entrega_notificacion` | `ck_entrega_notificacion_estado_fechas` | Coherencia completa por intento: pendiente no afirma ejecución; enviada no afirma entrega; entregada requiere confirmación; fallida requiere error. El worker inicia incluso un intento que falla en validación o transporte. |
| `comunicacion.lectura_mensaje` | `ck_lectura_mensaje_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comunicacion.mensaje` | `ck_mensaje_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comunicacion.mensaje` | `ck_mensaje_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comunicacion.mensaje` | `ck_mensaje_edicion_fecha` | La edición no puede preceder al envío. |
| `comunicacion.mensaje` | `ck_mensaje_retiro_motivo` | Retirar un mensaje exige motivo, además de la protección y autorización de fase 5 y fase 6. |
| `comunicacion.notificacion` | `ck_notificacion_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comunicacion.notificacion` | `ck_notificacion_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comunicacion.notificacion` | `ck_notificacion_tipo` | Catálogo de clases de notificación definido en el modelo lógico. |
| `comunicacion.notificacion` | `ck_notificacion_contexto` | La notificación refiere como máximo un proceso; la versión es un calificador de cotización. |
| `comunicacion.notificacion` | `ck_notificacion_tipo_contexto` | El tipo exige el contexto correcto, junto al límite de un contexto; general no refiere procesos. |
| `comunicacion.notificacion` | `ck_notificacion_version_contexto` | No admite una versión sin contexto de cotización. Pertenencia y permiso del destinatario se verifican en fase 5. |
| `comunicacion.notificacion` | `ck_notificacion_lectura_fecha` | La lectura no puede preceder a la creación de la notificación. |
| `comunicacion.participante_conversacion` | `ck_participante_conversacion_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `comunicacion.participante_conversacion` | `ck_participante_conversacion_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `comunicacion.participante_conversacion` | `ck_participante_conversacion_fechas` | La salida no precede a la incorporación; la vigencia frente a mensajes/lecturas es una regla entre filas para fase 5. |
| `auditoria.evento_auditoria` | `ck_evento_auditoria_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `auditoria.evento_auditoria` | `ck_evento_auditoria_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `auditoria.evento_auditoria` | `ck_evento_auditoria_actor` | Exactamente un responsable: persona o sistema identificado. |
| `auditoria.evento_auditoria` | `ck_evento_auditoria_operacion` | La evidencia por fila representa las tres operaciones DML previstas. |
| `auditoria.evento_auditoria` | `ck_evento_auditoria_clave_objeto` | La identificación histórica de la fila debe ser un objeto JSON no vacío, también para claves compuestas. |
| `auditoria.evento_auditoria` | `ck_evento_auditoria_imagenes_objeto` | Las imágenes de la fila son objetos JSON cuando existen; no se aceptan arrays, escalares ni JSON null. |
| `auditoria.evento_auditoria` | `ck_evento_auditoria_operacion_imagenes` | INSERT conserva imagen nueva, UPDATE ambas y DELETE la imagen anterior. |
| `identidad.credencial` | `ck_credencial_textos` | Los textos presentes contienen caracteres distintos de espacios; NULL se permite solo donde el modelo lo admite. |
| `identidad.credencial` | `ck_credencial_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `identidad.recuperacion_acceso` | `ck_recuperacion_acceso_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `identidad.recuperacion_acceso` | `ck_recuperacion_acceso_token_hash` | Se almacena una huella SHA-256 del secreto, de longitud fija. |
| `identidad.recuperacion_acceso` | `ck_recuperacion_acceso_fechas` | Intervalo de recuperación positivo y consumo posterior a la solicitud. La vigencia al consumir se comprueba atómicamente en fase 5, sin CHECK dependiente del reloj. |
| `identidad.sesion` | `ck_sesion_fechas_finitas` | Las fechas informadas deben ser finitas. NULL conserva el extremo abierto de los períodos. |
| `identidad.sesion` | `ck_sesion_refresh_hash` | Huella SHA-256 del secreto de renovación, nunca el secreto en claro. |
| `identidad.sesion` | `ck_sesion_fechas` | La sesión tiene duración positiva y no puede revocarse antes de iniciar. La validez actual se comprobará en cada acceso o renovación. |

## Alcance de esta entrega

No se incorporan módulos ni tablas adicionales. La precisión física de entrega_notificacion.entregada_en es la fecha local al registrar el acuse del proveedor, no un instante remoto; enviada no significa entregada y entregada no significa leída. El resto del contrato lógico permanece en fase_3_modelo_logico.md y fase_3_diccionario_datos.md.

No se implementan aún los controles transaccionales T00–T14, triggers de auditoría/updated_at, vistas, funciones, procedimientos, usuarios PostgreSQL, GRANT/REVOKE de aplicación ni RLS. Los clientes invitados siguen teniendo persona/cliente sin usuario obligatorio. Una FK de titularidad no sustituye la autorización del backend.

## Referencias técnicas

- [CREATE TABLE: restricciones, identidad y columnas generadas](https://www.postgresql.org/docs/18/sql-createtable.html).
- [btree_gist: exclusiones con tipos escalares y rangos](https://www.postgresql.org/docs/18/btree-gist.html).
- [CREATE INDEX: índices parciales y expresiones](https://www.postgresql.org/docs/18/sql-createindex.html).
- [CREATE DATABASE: fuera de una transacción](https://www.postgresql.org/docs/18/sql-createdatabase.html).
- [Secuencias: nextval no se revierte con rollback](https://www.postgresql.org/docs/18/functions-sequence.html).
