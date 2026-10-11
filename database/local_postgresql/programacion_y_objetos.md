# Programación PostgreSQL y finalidad de los objetos

Los nombres y firmas siguientes proceden de los archivos entregados. Las APIs modifican datos con CALL; las funciones devuelven valores, aplican autorización o atienden triggers. Ningún procedimiento confirma la transacción del llamador: una compra, aceptación o emisión de factura se confirma completa o se revierte.

## 10_identidad

```sql
CREATE FUNCTION identidad.es_dba() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.bloquear_operacion() RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.acceso_invitado_actual() RETURNS bigint
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.actor_persona_actual() RETURNS bigint
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.actor_sistema_actual() RETURNS text
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.persona_titular(p_recurso text,p_id bigint) RETURNS bigint
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.persona_tiene_permiso(p_persona bigint,p_recurso text,p_accion text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.empleado_habilitado(p_empleado bigint,p_recurso text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.persona_puede_acceder(p_persona bigint,p_recurso text,p_registro_id bigint,p_accion text DEFAULT 'leer') RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.puede_acceder(p_recurso text,p_registro_id bigint,p_accion text DEFAULT 'leer') RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.exigir_permiso(p_recurso text,p_accion text,p_registro_id bigint DEFAULT NULL) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE identidad.registrar_cliente_invitado(p_nombres text,p_apellidos text,p_correo text,p_telefono text,INOUT p_cliente_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE identidad.registrar_usuario(p_nombres text,p_apellidos text,p_correo text,p_telefono text,p_origen text,p_emisor text,p_sujeto text,p_password_hash text,INOUT p_usuario_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE identidad.actualizar_perfil(p_persona_id bigint,p_nombres text,p_apellidos text,p_correo text,p_telefono text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE identidad.administrar_registro(p_entidad text,p_datos jsonb,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE identidad.asignar_rol(p_usuario bigint,p_rol bigint,p_hasta timestamptz DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE identidad.revocar_rol(p_asignacion bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE identidad.configurar_permiso_rol(p_rol bigint,p_permiso bigint,p_conceder boolean,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE identidad.emitir_acceso_invitado(p_persona bigint,p_recurso text,p_registro bigint,p_version bigint,p_medio text,p_destino text,p_verificado timestamptz,p_vence timestamptz,p_token text,p_acciones text[],INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE identidad.revocar_acceso_invitado(p_id bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE identidad.registrar_sesion(p_usuario bigint,p_refresh_hash bytea,p_vence timestamptz,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE identidad.cerrar_sesion(p_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE identidad.preparar_recuperacion(p_usuario bigint,p_hash bytea,p_vence timestamptz,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE identidad.consumir_recuperacion(p_token text,p_hash_argon2 text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

El cuerpo completo y sus comprobaciones se encuentran en `10_identidad.sql`.

## 20_comercial

```sql
CREATE OR REPLACE FUNCTION comercial.persona_cotizacion(p_id bigint)
RETURNS bigint LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE FUNCTION inventario.existencia_disponible(p_producto bigint)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE FUNCTION comercial.total_pedido(p_id bigint)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE FUNCTION comercial.total_cotizacion(p_version bigint)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE FUNCTION comercial.total_factura(p_id bigint)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE FUNCTION comercial.repartir_importes(
 p_q numeric,p_b numeric,p_d numeric,p_i numeric,p_precio numeric,p_tasa numeric,
 p_usado_q numeric,p_usado_b numeric,p_usado_d numeric,p_usado_i numeric,p_nueva_q numeric)
RETURNS TABLE(descuento numeric,ajuste_base numeric,ajuste_impuesto numeric)
LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE FUNCTION comercial.proteger_fila()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE FUNCTION inventario.inicializar_saldo()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE FUNCTION inventario.aplicar_movimiento()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE FUNCTION comercial.validar_integridad()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE FUNCTION comercial.validar_integridad_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE PROCEDURE inventario.registrar_movimiento(p_producto bigint,p_tipo text,p_delta numeric,p_motivo text,p_operacion uuid,p_compensa bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE PROCEDURE inventario.guardar_producto(INOUT p_id bigint,p_sku text,p_categoria bigint,p_nombre text,p_descripcion text,p_unidad text,p_precio numeric,p_moneda text,p_publicado boolean,p_activo boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE PROCEDURE comercial.crear_pedido(INOUT p_id bigint,p_cliente bigint,p_moneda text,p_nombre text,p_correo text,p_telefono text,p_version bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE PROCEDURE comercial.guardar_detalle_pedido(INOUT p_id bigint,p_pedido bigint,p_numero integer,p_producto bigint,p_cantidad numeric,p_tasa numeric,p_descuento numeric DEFAULT 0,p_detalle_cotizacion bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE PROCEDURE comercial.confirmar_pedido(p_pedido bigint,p_operacion uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE OR REPLACE PROCEDURE comercial.cambiar_estado_pedido(p_pedido bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
```

```sql
CREATE FUNCTION comercial.exigir_carrito(p_id bigint,p_token text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.crear_carrito(p_cliente bigint,p_token text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.editar_carrito(p_id bigint,p_token text,p_producto bigint,p_cantidad numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.abandonar_carrito(p_id bigint,p_token text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.convertir_carrito(p_carrito bigint,p_token text,p_nombres text,p_apellidos text,p_correo text,p_telefono text,p_moneda text,p_tasa numeric,INOUT p_pedido bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.quitar_detalle_pedido(p_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE OR REPLACE PROCEDURE comercial.solicitar_cotizacion(p_persona bigint,p_nombres text,p_apellidos text,p_correo text,p_telefono text,p_necesidad text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.cambiar_estado_solicitud_cotizacion(p_id bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.crear_cotizacion(p_solicitud bigint,p_persona bigint,p_moneda text,p_condiciones text,p_nombre text,p_correo text,p_telefono text,p_vigente_hasta timestamptz,INOUT p_id bigint DEFAULT NULL,INOUT p_version bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.revisar_cotizacion(p_cotizacion bigint,p_moneda text,p_condiciones text,p_nombre text,p_correo text,p_telefono text,p_vigente_hasta timestamptz,p_copiar_version bigint,INOUT p_version bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.editar_version_cotizacion(p_version bigint,p_condiciones text,p_nombre text,p_correo text,p_telefono text,p_vigente_hasta timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.guardar_detalle_cotizacion(p_version bigint,p_numero integer,p_clase text,p_producto bigint,p_servicio bigint,p_descripcion text,p_cantidad numeric,p_unidad text,p_precio numeric,p_descuento numeric,p_tasa numeric,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.quitar_detalle_cotizacion(p_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.enviar_cotizacion(p_version bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.responder_cotizacion(p_version bigint,p_aceptar boolean,p_evidencia text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.anular_cotizacion(p_cotizacion bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.crear_factura(p_pedido bigint,p_orden bigint,p_proyecto bigint,p_nombre text,p_identificacion text,p_correo text,p_telefono text,p_direccion text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.guardar_detalle_factura(p_factura bigint,p_numero integer,p_detalle_pedido bigint,p_detalle_cotizacion bigint,p_cantidad numeric,p_descripcion text,p_unidad text,p_precio_directo numeric,p_descuento_directo numeric,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.quitar_detalle_factura(p_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.emitir_factura(p_factura bigint,p_operacion uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.anular_factura(p_factura bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

El cuerpo completo y sus comprobaciones se encuentran en `20_comercial.sql`.

## 30_servicios

```sql
CREATE FUNCTION servicios.validar_integridad() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION servicios.proteger_datos() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION proyectos.proteger_datos() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION servicios.exigir_cliente_alta(p_cliente bigint) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.registrar_equipo(p_cliente bigint,p_tipo text,p_descripcion text,p_marca text,p_modelo text,p_serie text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.solicitar_servicio(p_cliente bigint,p_oferta bigint,p_equipo bigint,p_necesidad text,p_alcance text,p_fecha timestamptz,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.cambiar_estado_solicitud(p_id bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.aceptar_solicitud(p_solicitud bigint,p_importe numeric,p_tasa numeric,p_moneda text,p_version bigint,p_tipo_mantenimiento text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.registrar_disponibilidad(p_empleado bigint,p_inicio timestamptz,p_fin timestamptz,p_observaciones text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.editar_disponibilidad(p_id bigint,p_inicio timestamptz,p_fin timestamptz,p_habilitada boolean,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.programar_cita(p_solicitud bigint,p_tecnico bigint,p_inicio timestamptz,p_fin timestamptz,p_modalidad text,p_lugar text,p_confirmar boolean,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.cambiar_estado_cita(p_id bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.reprogramar_cita(p_anterior bigint,p_tecnico bigint,p_inicio timestamptz,p_fin timestamptz,p_motivo text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.asignar_tecnico(p_orden bigint,p_empleado bigint,p_funcion text,p_principal boolean,p_motivo text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.retirar_tecnico(p_asignacion bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.registrar_informe_reparacion(p_orden bigint,p_diagnostico text,p_falla text,p_solucion text,p_pruebas text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.registrar_informe_mantenimiento(p_orden bigint,p_actividades text,p_hallazgos text,p_recomendaciones text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.cambiar_estado_orden(p_id bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.cerrar_servicio(p_id bigint,p_resumen text,p_observaciones text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE servicios.calificar_servicio(p_orden bigint,p_puntuacion smallint,p_comentario text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE proyectos.solicitar_desarrollo(p_cliente bigint,p_necesidades text,p_objetivos text,p_alcance text,p_presupuesto numeric,p_moneda text,p_fecha date,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE proyectos.cambiar_estado_solicitud(p_id bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE proyectos.aprobar_solicitud(p_solicitud bigint,p_nombre text,p_descripcion text,p_alcance text,p_importe numeric,p_tasa numeric,p_moneda text,p_version bigint,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE proyectos.asignar_miembro(p_proyecto bigint,p_empleado bigint,p_funcion text,p_principal boolean,p_motivo text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE proyectos.retirar_miembro(p_miembro bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE proyectos.definir_etapa(p_proyecto bigint,p_nombre text,p_descripcion text,p_orden integer,p_peso numeric,p_inicio date,p_fin date,p_motivo text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE proyectos.revisar_alcance(p_id bigint,p_alcance text,p_inicio date,p_fin date,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE proyectos.cambiar_estado_proyecto(p_id bigint,p_estado text,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE proyectos.registrar_avance(p_etapa bigint,p_miembro bigint,p_porcentaje numeric,p_descripcion text,p_observaciones text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION proyectos.obtener_avance(p_proyecto bigint) RETURNS numeric
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE VIEW servicios.v_servicios_publicados WITH(security_invoker=true)
```

```sql
CREATE VIEW servicios.v_servicios_activos WITH(security_invoker=true)
```

```sql
CREATE VIEW proyectos.v_avance_etapa WITH(security_invoker=true)
```

```sql
CREATE VIEW proyectos.v_avance_proyecto WITH(security_invoker=true)
```

El cuerpo completo y sus comprobaciones se encuentran en `30_servicios.sql`.

## 40_comunicacion

```sql
CREATE FUNCTION comunicacion.contexto_de_fila(p_fila jsonb, OUT recurso text, OUT registro_id bigint)
RETURNS record LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION comunicacion.puede_leer_archivo(p_archivo_id bigint)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION comunicacion.validar_integridad()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION comunicacion.validar_integridad_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION comunicacion.proteger_fila()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comunicacion.crear_conversacion(p_asunto text,p_recurso text,p_registro_id bigint,
 p_participantes bigint[],INOUT p_conversacion_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comunicacion.gestionar_participante(p_conversacion_id bigint,p_persona_id bigint,p_accion text,p_funcion text DEFAULT 'participante')
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comunicacion.cerrar_conversacion(p_conversacion_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comunicacion.registrar_archivo(p_nombre text,p_almacen text,p_clave text,p_tipo text,p_bytes bigint,
 INOUT p_archivo_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comunicacion.validar_archivo(p_archivo_id bigint,p_estado text,p_sha256 bytea,p_publico boolean DEFAULT false)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comunicacion.adjuntar_archivo(p_archivo_id bigint,p_recurso text,p_registro_id bigint,p_descripcion text DEFAULT NULL,
 p_visibilidad text DEFAULT 'compartido',INOUT p_adjunto_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comunicacion.enviar_mensaje(p_conversacion_id bigint,p_contenido text,p_archivos bigint[] DEFAULT ARRAY[]::bigint[],
 INOUT p_mensaje_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comunicacion.editar_mensaje(p_mensaje_id bigint,p_contenido text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comunicacion.retirar_mensaje(p_mensaje_id bigint,p_motivo text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comunicacion.marcar_mensaje_leido(p_mensaje_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comunicacion.registrar_notificacion(p_usuario_id bigint,p_tipo text,p_titulo text,p_contenido text,p_evento uuid,
 p_recurso text DEFAULT NULL,p_registro_id bigint DEFAULT NULL,p_version_id bigint DEFAULT NULL,INOUT p_notificacion_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comunicacion.marcar_notificacion_leida(p_notificacion_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comunicacion.encolar_entrega(p_notificacion_id bigint,p_canal text,p_destino text,p_idempotencia uuid,
 INOUT p_entrega_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comunicacion.reclamar_entrega(p_entrega_id bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comunicacion.registrar_resultado_entrega(p_entrega_id bigint,p_estado text,p_proveedor text DEFAULT NULL,
 p_referencia text DEFAULT NULL,p_error text DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE VIEW comunicacion.v_mensajes_visibles WITH (security_barrier=true)
```

```sql
CREATE VIEW comunicacion.v_notificaciones_propias WITH (security_barrier=true)
```

```sql
CREATE FUNCTION comunicacion.contar_mensajes_no_leidos(p_conversacion_id bigint)
RETURNS bigint LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

El cuerpo completo y sus comprobaciones se encuentran en `40_comunicacion.sql`.

## 50_auditoria

```sql
CREATE FUNCTION auditoria.persona_responsable() RETURNS bigint
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION auditoria.sistema_responsable() RETURNS text
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.proteger_basico() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION auditoria.solo_anexar() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION auditoria.registrar_cambio() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION auditoria.verificar_transicion() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION auditoria.registrar_estado() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION auditoria.registrar_estado_version() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.validar_identidad() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.proteger_acceso() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.sincronizar_habilitaciones() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.revisar_habilitaciones_trigger() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE identidad.procesar_vencimientos()
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION auditoria.validar_historial() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION comunicacion.notificar_estado() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

El cuerpo completo y sus comprobaciones se encuentran en `50_auditoria.sql`.

## 55_autenticacion_backend

```sql
CREATE FUNCTION identidad.datos_autenticacion(p_correo text)
RETURNS TABLE(usuario_id bigint,password_hash text,estado text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE identidad.confirmar_correo(p_usuario bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE FUNCTION identidad.estado_sesion(p_sesion bigint,p_hash bytea)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE PROCEDURE comercial.vincular_comprobante(p_factura bigint,p_archivo bigint,p_clase text,p_descripcion text,INOUT p_id bigint DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

El cuerpo completo y sus comprobaciones se encuentran en `55_autenticacion_backend.sql`.

## 60_seguridad

```sql
CREATE FUNCTION identidad.fila_visible(p_tabla text,f jsonb) RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

El cuerpo completo y sus comprobaciones se encuentran en `60_seguridad.sql`.

## 65_vistas

```sql
CREATE FUNCTION inventario.consultar_disponibilidad(p_producto bigint) RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE VIEW inventario.v_productos_disponibles WITH(security_barrier=true)
```

```sql
CREATE VIEW inventario.productos WITH(security_barrier=true)
```

```sql
CREATE VIEW inventario.v_inventario_actual WITH(security_barrier=true)
```

```sql
CREATE VIEW comercial.v_resumen_pedidos WITH(security_invoker=true)
```

```sql
CREATE VIEW comercial.v_cotizaciones_vigentes WITH(security_invoker=true)
```

```sql
CREATE VIEW comercial.v_facturas_cliente WITH(security_invoker=true)
```

```sql
CREATE VIEW comercial.v_historial_cliente WITH(security_invoker=true)
```

```sql
CREATE VIEW servicios.v_calificaciones WITH(security_invoker=true)
```

```sql
CREATE VIEW comercial.v_carritos_propios WITH(security_invoker=true)
```

```sql
CREATE FUNCTION servicios.horarios_disponibles()
RETURNS TABLE(disponibilidad_id bigint,tecnico_id bigint,inicio timestamptz,fin timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

```sql
CREATE VIEW servicios.v_horarios_disponibles WITH(security_barrier=true)
```

```sql
CREATE FUNCTION comercial.consultar_carrito(p_id bigint,p_token text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS
```

El cuerpo completo y sus comprobaciones se encuentran en `65_vistas.sql`.

## Triggers

Los triggers `b00_basico`/protección equivalente actualizan fechas, toman el bloqueo de escritura y preservan identificadores. Los guards de cada módulo controlan mutaciones; los constraint triggers diferibles validan el estado final. Los triggers de historial registran inserciones y transiciones; los de auditoría toman imágenes JSONB en INSERT/UPDATE/DELETE. Los de inventario crean la proyección al dar de alta productos y aplican cada movimiento. Los de notificaciones registran cambios importantes de estado en la misma transacción.


### 20_comercial

```sql
  EXECUTE format('CREATE TRIGGER b20_guard BEFORE INSERT OR UPDATE OR DELETE ON %s FOR EACH ROW EXECUTE FUNCTION comercial.proteger_fila()',v);
  EXECUTE format('CREATE CONSTRAINT TRIGGER z20_integridad AFTER INSERT OR UPDATE OR DELETE ON %s DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION comercial.validar_integridad_trigger()',v);
  EXECUTE format('CREATE CONSTRAINT TRIGGER z20_integridad AFTER INSERT OR UPDATE OR DELETE ON %s DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION comercial.validar_integridad_trigger()',v);
CREATE TRIGGER c20_inicializar AFTER INSERT ON inventario.producto FOR EACH ROW EXECUTE FUNCTION inventario.inicializar_saldo();
CREATE TRIGGER c20_aplicar AFTER INSERT ON inventario.movimiento_inventario FOR EACH ROW EXECUTE FUNCTION inventario.aplicar_movimiento();
```

### 30_servicios

```sql
    EXECUTE format('CREATE CONSTRAINT TRIGGER validar_servicios_proyectos AFTER INSERT OR UPDATE OR DELETE ON %s DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION servicios.validar_integridad()',t);
   EXECUTE format('CREATE TRIGGER proteger_datos_servicio BEFORE INSERT OR UPDATE OR DELETE ON servicios.%I FOR EACH ROW EXECUTE FUNCTION servicios.proteger_datos()',t);
   EXECUTE format('CREATE TRIGGER proteger_datos_proyecto BEFORE INSERT OR UPDATE OR DELETE ON proyectos.%I FOR EACH ROW EXECUTE FUNCTION proyectos.proteger_datos()',t);
```

### 40_comunicacion

```sql
    EXECUTE format('CREATE TRIGGER t10_guard_%I BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.%I FOR EACH ROW EXECUTE FUNCTION comunicacion.proteger_fila()',t,t);
    EXECUTE format('CREATE CONSTRAINT TRIGGER t10_integridad_%I AFTER INSERT OR UPDATE OR DELETE ON comunicacion.%I DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION comunicacion.validar_integridad_trigger()',t,t);
CREATE CONSTRAINT TRIGGER t11_integridad_producto_imagen AFTER INSERT OR UPDATE OR DELETE ON inventario.producto_imagen
CREATE CONSTRAINT TRIGGER t11_integridad_comprobante AFTER INSERT OR UPDATE OR DELETE ON comercial.comprobante_factura
CREATE CONSTRAINT TRIGGER t12_integridad_version AFTER UPDATE ON comercial.version_cotizacion
```

### 50_auditoria

```sql
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado_permiso FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('acceso_invitado_id','permiso_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado_permiso FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('acceso_invitado_id','permiso_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.cliente FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','persona_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.cliente FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.credencial FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('usuario_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.credencial FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('usuario_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.empleado FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','persona_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.empleado FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.permiso FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.permiso FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.persona FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.persona FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.recuperacion_acceso FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.recuperacion_acceso FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.rol FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.rol FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.rol_permiso FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('rol_id','permiso_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.rol_permiso FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('rol_id','permiso_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.sesion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.sesion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.usuario FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','persona_id','origen_auth','emisor_externo','sujeto_externo');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.usuario FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON identidad.usuario_rol FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','usuario_id','rol_id','inicia_en');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON identidad.usuario_rol FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON inventario.categoria FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON inventario.categoria FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON inventario.inventario FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('producto_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON inventario.inventario FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('producto_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON inventario.movimiento_inventario FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON inventario.movimiento_inventario FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON inventario.producto FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON inventario.producto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON inventario.producto_imagen FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON inventario.producto_imagen FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON inventario.reserva_inventario FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('detalle_pedido_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON inventario.reserva_inventario FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('detalle_pedido_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.carrito FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.carrito FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.comprobante_factura FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.comprobante_factura FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.cotizacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','solicitud_cotizacion_id','persona_directa_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON comercial.cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON comercial.cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('comercial.historial_cotizacion','cotizacion_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.detalle_carrito FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('carrito_id','producto_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.detalle_carrito FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('carrito_id','producto_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.detalle_cotizacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.detalle_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.detalle_factura FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.detalle_factura FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.detalle_pedido FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.detalle_pedido FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.factura FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.factura FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON comercial.factura FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON comercial.factura FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('comercial.historial_factura','factura_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.historial_cotizacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON comercial.historial_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.historial_factura FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON comercial.historial_factura FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_factura FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.historial_pedido FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON comercial.historial_pedido FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_pedido FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.historial_solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON comercial.historial_solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.pedido FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','cliente_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.pedido FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON comercial.pedido FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON comercial.pedido FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('comercial.historial_pedido','pedido_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','persona_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON comercial.solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON comercial.solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('comercial.historial_solicitud_cotizacion','solicitud_cotizacion_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comercial.version_cotizacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','cotizacion_id','numero_version');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comercial.version_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON comercial.version_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.asignacion_servicio FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.asignacion_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.calificacion_servicio FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('orden_servicio_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.calificacion_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('orden_servicio_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.cita_servicio FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.cita_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.disponibilidad_tecnico FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.disponibilidad_tecnico FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.equipo_cliente FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','cliente_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.equipo_cliente FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.historial_servicio FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON servicios.historial_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.historial_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.historial_solicitud_servicio FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON servicios.historial_solicitud_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.historial_solicitud_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.mantenimiento FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('orden_servicio_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.mantenimiento FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('orden_servicio_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.orden_servicio FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','solicitud_servicio_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.orden_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON servicios.orden_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON servicios.orden_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('servicios.historial_servicio','orden_servicio_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.reparacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('orden_servicio_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.reparacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('orden_servicio_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.servicio_ofrecido FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.servicio_ofrecido FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON servicios.solicitud_servicio FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','cliente_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON servicios.solicitud_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON servicios.solicitud_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON servicios.solicitud_servicio FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('servicios.historial_solicitud_servicio','solicitud_servicio_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON proyectos.avance_proyecto FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON proyectos.avance_proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON proyectos.etapa_proyecto FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON proyectos.etapa_proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON proyectos.historial_proyecto FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON proyectos.historial_proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON proyectos.historial_proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON proyectos.historial_solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON proyectos.historial_solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON proyectos.historial_solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON proyectos.miembro_proyecto FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON proyectos.miembro_proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON proyectos.proyecto FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','solicitud_desarrollo_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON proyectos.proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON proyectos.proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON proyectos.proyecto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('proyectos.historial_proyecto','proyecto_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON proyectos.solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id','cliente_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON proyectos.solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a10_transicion BEFORE UPDATE ON proyectos.solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION auditoria.verificar_transicion();
CREATE TRIGGER z50_historial AFTER INSERT OR UPDATE ON proyectos.solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado('proyectos.historial_solicitud_desarrollo','solicitud_desarrollo_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.adjunto FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.adjunto FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.archivo FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.archivo FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.conversacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.conversacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.entrega_notificacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.entrega_notificacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.lectura_mensaje FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('mensaje_id','participante_id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.lectura_mensaje FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('mensaje_id','participante_id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.mensaje FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.mensaje FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.notificacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.notificacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON comunicacion.participante_conversacion FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER z90_auditar AFTER INSERT OR UPDATE OR DELETE ON comunicacion.participante_conversacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio('id');
CREATE TRIGGER a00_basico BEFORE INSERT OR UPDATE OR DELETE ON auditoria.evento_auditoria FOR EACH ROW EXECUTE FUNCTION identidad.proteger_basico('id');
CREATE TRIGGER a05_inmutable BEFORE UPDATE OR DELETE ON auditoria.evento_auditoria FOR EACH ROW EXECUTE FUNCTION auditoria.solo_anexar();
CREATE TRIGGER z50_historial_version AFTER INSERT OR UPDATE ON comercial.version_cotizacion FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_estado_version();
CREATE TRIGGER a20_concesion BEFORE INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado FOR EACH ROW EXECUTE FUNCTION identidad.proteger_acceso();
CREATE TRIGGER a20_concesion BEFORE INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado_permiso FOR EACH ROW EXECUTE FUNCTION identidad.proteger_acceso();
CREATE CONSTRAINT TRIGGER z95_identidad AFTER INSERT OR UPDATE OR DELETE ON identidad.usuario DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identidad.validar_identidad();
CREATE CONSTRAINT TRIGGER z95_identidad AFTER INSERT OR UPDATE OR DELETE ON identidad.credencial DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identidad.validar_identidad();
CREATE CONSTRAINT TRIGGER z95_identidad AFTER INSERT OR UPDATE OR DELETE ON identidad.sesion DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identidad.validar_identidad();
CREATE CONSTRAINT TRIGGER z95_identidad AFTER INSERT OR UPDATE OR DELETE ON identidad.recuperacion_acceso DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identidad.validar_identidad();
CREATE CONSTRAINT TRIGGER z95_identidad AFTER INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identidad.validar_identidad();
CREATE CONSTRAINT TRIGGER z95_identidad AFTER INSERT OR UPDATE OR DELETE ON identidad.acceso_invitado_permiso DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identidad.validar_identidad();
CREATE CONSTRAINT TRIGGER z95_identidad AFTER INSERT OR UPDATE OR DELETE ON identidad.permiso DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identidad.validar_identidad();
CREATE TRIGGER z30_habilitaciones AFTER UPDATE OR DELETE ON identidad.persona FOR EACH STATEMENT EXECUTE FUNCTION identidad.revisar_habilitaciones_trigger();
CREATE TRIGGER z30_habilitaciones AFTER UPDATE OR DELETE ON identidad.usuario FOR EACH STATEMENT EXECUTE FUNCTION identidad.revisar_habilitaciones_trigger();
CREATE TRIGGER z30_habilitaciones AFTER UPDATE OR DELETE ON identidad.empleado FOR EACH STATEMENT EXECUTE FUNCTION identidad.revisar_habilitaciones_trigger();
CREATE TRIGGER z30_habilitaciones AFTER UPDATE OR DELETE ON identidad.usuario_rol FOR EACH STATEMENT EXECUTE FUNCTION identidad.revisar_habilitaciones_trigger();
CREATE TRIGGER z30_habilitaciones AFTER UPDATE OR DELETE ON identidad.rol_permiso FOR EACH STATEMENT EXECUTE FUNCTION identidad.revisar_habilitaciones_trigger();
CREATE TRIGGER z30_habilitaciones AFTER UPDATE OR DELETE ON identidad.rol FOR EACH STATEMENT EXECUTE FUNCTION identidad.revisar_habilitaciones_trigger();
CREATE TRIGGER z30_habilitaciones AFTER UPDATE OR DELETE ON identidad.permiso FOR EACH STATEMENT EXECUTE FUNCTION identidad.revisar_habilitaciones_trigger();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.pedido DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.cotizacion DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.solicitud_cotizacion DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.factura DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON servicios.solicitud_servicio DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON servicios.orden_servicio DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON proyectos.solicitud_desarrollo DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON proyectos.proyecto DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_pedido DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_cotizacion DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_solicitud_cotizacion DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON comercial.historial_factura DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON servicios.historial_solicitud_servicio DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON servicios.historial_servicio DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON proyectos.historial_solicitud_desarrollo DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE CONSTRAINT TRIGGER z99_historial_consistente AFTER INSERT OR UPDATE OR DELETE ON proyectos.historial_proyecto DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION auditoria.validar_historial();
CREATE TRIGGER z70_notificar AFTER UPDATE ON comercial.pedido FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON comercial.cotizacion FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON comercial.solicitud_cotizacion FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON comercial.factura FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON servicios.solicitud_servicio FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON servicios.orden_servicio FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON proyectos.solicitud_desarrollo FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON proyectos.proyecto FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
CREATE TRIGGER z70_notificar AFTER UPDATE ON comercial.version_cotizacion FOR EACH ROW EXECUTE FUNCTION comunicacion.notificar_estado();
```
