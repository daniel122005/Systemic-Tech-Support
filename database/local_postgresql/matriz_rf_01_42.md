# Matriz de trazabilidad RF-01 a RF-42 — Systemic Tech & Support (versión 2, 2026-10-09)

Fuente: «Requerimientos - Systemic Tech.docx».

## Cómo leer esta matriz

- **Soporte BD** clasifica lo que la base de datos hace por sí misma, con la evidencia disponible:
  - **Verificado (réplica):** hay una prueba que se ejecutó y pasó en las réplicas de Claude: PostgreSQL 18.3 (la versión de tu servidor) y PostgreSQL 17.6 con las restricciones de permisos de Supabase. **Todavía no se ha ejecutado en tu servidor ni en tu proyecto Supabase**; esa confirmación la dan los pasos L3 y S2 del procedimiento.
  - **Parcial:** la base cubre una parte y el resto depende de un servicio externo.
  - **No verificable:** la evidencia disponible no permite comprobarlo.
- **Plataforma** indica si existe la funcionalidad completa para el usuario final. **No hay frontend ni backend**, así que ningún requerimiento está terminado de punta a punta. Que exista una tabla de notificaciones no significa que la plataforma envíe notificaciones.
- **Códigos de prueba:** `C` = 83_pruebas_comercial · `S`/`P` = 82_pruebas_servicios · `T40-` = 82_pruebas_comunicacion · `A` = 84_pruebas_acceso · `Q` = 85_pruebas_cotizacion_contacto · `R` = 87_pruebas_rf (nuevo; usa la identidad real del rol `st_app`) · `SB` = 86_pruebas_supabase_auth (nuevo) · `demo` = comprobaciones internas de 70/71.

## Resumen

| Clasificación | Soporte BD | Plataforma completa |
|---|---|---|
| Implementado y verificado (réplica) | 39 | 0 |
| Parcialmente implementado | 2 (RF-03, RF-25) | — |
| Pendiente | 0 | 42 (falta frontend/backend) |
| No verificable con la evidencia disponible | 1 (RF-04, delegado a Supabase Auth) | — |

## Matriz

| RF | Requerimiento | Objetos de BD | Prueba que lo verifica | Soporte BD | Plataforma / ajuste pendiente |
|---|---|---|---|---|---|
| RF-01 | Acceso público | `inventario.v_productos_disponibles`, `producto_imagen`, `servicios.servicio_ofrecido` (RLS: publicado), `v_horarios_disponibles` | R01, R03, R04, A08 | Verificado (réplica) | Páginas públicas y backend que consulte sin identidad. |
| RF-02 | Registro opcional | `identidad.persona`, `usuario` (origen externo), `cliente`; trigger `sincronizar_usuario_supabase` sobre `auth.users` | SB01, SB02, SB03, SB06 | Verificado (réplica; `auth.users` simulado) | Formulario de registro con Supabase Auth. Confirmar en `supabase start` (paso S2). |
| RF-03 | Inicio y cierre de sesión | Supabase Auth; `identidad.iniciar_contexto_supabase` (falla cerrado) | SB08, SB15, H02–H04 (humo) | **Parcial** | Las credenciales y las sesiones las gestiona Supabase Auth, fuera de la base. La base solo comprueba que una cuenta pendiente, bloqueada o desconocida no obtiene identidad. |
| RF-04 | Recuperación de contraseña | Supabase Auth. Las rutinas locales `preparar/consumir_recuperacion` quedan retiradas | — | **No verificable** | Flujo de recuperación de Supabase Auth y su plantilla de correo. No interviene la base. |
| RF-05 | Gestión del perfil | `identidad.actualizar_perfil`; RLS en `persona` | R08 | Verificado (réplica) | Pantalla de perfil. El cambio de correo de acceso se hace en Supabase Auth (sincronizado, SB14). |
| RF-06 | Control según tipo de usuario | `puede_acceder`, `exigir_permiso`, 62 políticas RLS, `acceso_invitado` | R05, R21, A01–A08, SB07, SB11–SB13 | Verificado (réplica) | La interfaz oculta acciones, pero la seguridad real está en la base. |
| RF-07 | Consulta de productos | `inventario.producto`, `producto_imagen`, `comunicacion.archivo` (público), `v_productos_disponibles` | R01, A04 | Verificado (réplica) | Guardar los bytes de las imágenes en Storage (bucket público `catalogo`) y mostrarlas. |
| RF-08 | Búsqueda y filtrado | `v_productos_disponibles`, índices de producto | R02 (texto, rango de precio, categoría) | Verificado (réplica) | Interfaz de filtros. Con catálogo grande, revisar índices con `EXPLAIN`. |
| RF-09 | Carrito | `comercial.carrito`, `detalle_carrito`; `crear/editar/abandonar_carrito`, `consultar_carrito` | R06 (anónimo con secreto; token ajeno rechazado), R09 (cliente) | Verificado (réplica) | Cookie httpOnly con el secreto del carrito anónimo. |
| RF-10 | Realizar compras | `convertir_carrito`, `confirmar_pedido`, `reserva_inventario` | R06, R09 (reserva), C01–C03 | Verificado (réplica) | Checkout. **Pagos: no definidos en los requerimientos.** |
| RF-11 | Consulta de pedidos | `comercial.pedido`, `historial_pedido`, `v_resumen_pedidos` | R10, A03 | Verificado (réplica) | Pantalla de seguimiento. |
| RF-12 | Historial de compras | `v_resumen_pedidos`, `detalle_pedido` | R10 | Verificado (réplica) | Listado paginado. |
| RF-13 | Consulta de servicios | `servicios.servicio_ofrecido` (RLS: publicado) | R03 | Verificado (réplica) | La matriz v1 citaba una vista `v_servicios_publicados` **que no existe**; el soporte real es la tabla con RLS. |
| RF-14 | Solicitud de reparación | `equipo_cliente`, `solicitud_servicio`; `solicitar_servicio` | R11, S01–S03 | Verificado (réplica) | Formulario. |
| RF-15 | Solicitud de mantenimiento | `solicitud_servicio`, `mantenimiento` | R11, S21 | Verificado (réplica) | Formulario. |
| RF-16 | Agendamiento | `disponibilidad_tecnico`, `cita_servicio` (EXCLUDE), `v_horarios_disponibles`, `programar_cita`, `fecha_preferida` | R04, R11, S12–S16 | Verificado (réplica) | Calendario en la interfaz. |
| RF-17 | Estado de reparación | `orden_servicio`, `reparacion`, `historial_servicio` | R12, S17 | Verificado (réplica) | Pantalla de seguimiento. Un invitado necesita concesión (S20). |
| RF-18 | Historial de servicios | `v_historial_cliente`, `orden_servicio` | R12 | Verificado (réplica) | Listado. |
| RF-19 | Cotización sin cuenta | `solicitud_cotizacion`; `solicitar_cotizacion` | R07, Q04, Q05 | Verificado (réplica) | Formulario público. |
| RF-20 | Consulta de cotizaciones | `cotizacion`, `version_cotizacion`, `v_cotizaciones_vigentes` | R13 | Verificado (réplica) | Pantalla. |
| RF-21 | Aceptar o rechazar cotización | `responder_cotizacion`, `historial_cotizacion` | R29 (rechazo; respuesta inmutable), demo (aceptación), C08 | Verificado (réplica) | Botones con las condiciones visibles. |
| RF-22 | Solicitud de desarrollo | `proyectos.solicitud_desarrollo`; `solicitar_desarrollo` | R14 | Verificado (réplica) | Formulario. |
| RF-23 | Seguimiento de proyectos | `proyecto`, `etapa_proyecto`, `avance_proyecto`, `obtener_avance` | R15, P02 | Verificado (réplica) | Barra de progreso. |
| RF-24 | Información del proyecto | Ídem, más `miembro_proyecto` | R15, P01–P09 | Verificado (réplica) | Vista de detalle. |
| RF-25 | Contacto con la empresa | `comunicacion.conversacion` (sin proceso asociado) | T40-01, R16 | **Parcial** | La base cubre el canal interno. Teléfono, correo y redes son contenido o integraciones de la plataforma. |
| RF-26 | Mensajería | `conversacion`, `participante_conversacion`, `mensaje`, `lectura_mensaje` | T40-01 a T40-07, T40-13 a T40-15, R16 | Verificado (réplica) | Interfaz de chat; tiempo real opcional (Supabase Realtime no está configurado). |
| RF-27 | Carga de archivos | `archivo`, `adjunto`, `registrar/validar/adjuntar_archivo`, `puede_leer_archivo` | T40-08 a T40-12, T40-25 a T40-29, R16 | Verificado (réplica) en metadatos y permisos | Guardar los bytes en Storage (bucket privado), control de tamaño y tipo, antivirus y URL firmada. |
| RF-28 | Notificaciones | `notificacion`, `entrega_notificacion`, `notificar_estado` | T40-16 a T40-24, R17, demo 71 (entrega) | Verificado (réplica): registro, lectura y ciclo de entrega | Proceso que envíe correos o push (rol `st_trabajador`). **Hoy nada envía mensajes.** |
| RF-29 | Facturas y comprobantes | `factura`, `detalle_factura`, `comprobante_factura`, `v_facturas_cliente` | A05, R18, C06 | Verificado (réplica) | Generar el PDF. **La facturación electrónica fiscal no está especificada.** |
| RF-30 | Calificación de servicios | `calificacion_servicio`; `calificar_servicio` | S19, S20, R19, demo | Verificado (réplica) | Formulario. |
| RF-31 | Historial general | `comercial.v_historial_cliente` | R20 | Verificado (réplica) | Cronología en la interfaz. |
| RF-32 | Gestión de usuarios | `administrar_registro`, `usuario_rol`, auditoría; sincronización con Auth | R21 (negativo), R27, R30, SB14, SB16 | Verificado (réplica) | Panel administrativo. Desbloquear exige además quitar el bloqueo en Supabase Auth. |
| RF-33 | Gestión de productos | `guardar_producto`, `administrar_registro` (categoría, imagen) | R23, R01 | Verificado (réplica) | Panel con subida de imágenes. |
| RF-34 | Gestión de inventario | `registrar_movimiento`, `movimiento_inventario`, `inventario` | R24, C03, C05 | Verificado (réplica) | Panel. |
| RF-35 | Gestión de pedidos | `cambiar_estado_pedido`, `historial_pedido` | R25, C01, C04 | Verificado (réplica) | Panel. |
| RF-36 | Gestión de reparaciones | `aceptar_solicitud`, `asignar_tecnico`, `registrar_informe_reparacion`, `cerrar_servicio` | S06–S11, S17, S18 | Verificado (réplica, ejecutado como DBA) | Panel del técnico. Falta un recorrido con `st_app` y el rol técnico. |
| RF-37 | Gestión de mantenimientos | `solicitud_servicio`, `orden_servicio`, `mantenimiento`, `cita_servicio` | S21, demo | Verificado (réplica) | Panel. |
| RF-38 | Gestión de cotizaciones | `crear/revisar/enviar/anular_cotizacion` | R26, C08 | Verificado (réplica) | Panel. El correo de envío depende del proceso de notificaciones. |
| RF-39 | Gestión de proyectos | `aprobar_solicitud`, `asignar_miembro`, `definir_etapa`, `registrar_avance`, `cambiar_estado_proyecto` | P01–P09, demo | Verificado (réplica) | Panel. |
| RF-40 | Gestión de clientes | `identidad.cliente`, `persona`, `administrar_registro` | R22, R27, A02 | Verificado (réplica) | Panel con filtro registrados/invitados. |
| RF-41 | Gestión de solicitudes | `solicitud_cotizacion`, `solicitud_servicio`, `solicitud_desarrollo` | R22 | Verificado (réplica) | Bandeja unificada en el panel. |
| RF-42 | Roles y permisos | `rol`, `permiso`, `rol_permiso`, `usuario_rol`; `configurar_permiso_rol`, `asignar_rol`, `revocar_rol` | R28, SB16, R30 | Verificado (réplica) | Panel de roles. |

## Ajustes pendientes identificados (sin cambiar el modelo)

1. **RF-36:** añadir una prueba con `st_app` y un usuario de rol técnico (hoy el flujo se prueba como DBA).
2. **RF-27 / RF-07:** decidir los buckets de Storage y el proceso que valida los archivos (`validar_archivo` lo ejecuta `st_worker`).
3. **RF-28 / RF-38:** construir el proceso de envíos (correo/push) con `st_trabajador`.
4. **RF-10 / RF-29:** definir pagos y facturación electrónica, que no están en los requerimientos.
