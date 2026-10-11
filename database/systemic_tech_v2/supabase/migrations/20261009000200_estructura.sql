-- Systemic Tech & Support — migración para Supabase generada por herramientas/generar_supabase.py
-- Origen: módulos locales verificados en PostgreSQL 18.3 y 17.6. No editar a mano: regenerar.
-- Compatible con Supabase CLI (supabase db push / db reset) y con el SQL Editor (pegar completo).
-- 2/6. Estructura: 62 tablas, restricciones, índices y secuencias (01 + 02).
DO $precondiciones$
BEGIN
  IF current_setting('server_version_num')::integer < 170000 THEN
    RAISE EXCEPTION 'Systemic Tech requiere PostgreSQL 17 o posterior (verificado en 17.6 y 18.3)';
  END IF;
  IF current_database() <> 'postgres' THEN
    RAISE EXCEPTION 'En Supabase la base de datos debe ser postgres; conectado a %', current_database();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'st_owner') THEN
    RAISE EXCEPTION 'Aplique antes la migración de roles (..._roles_systemic.sql)';
  END IF;
END
$precondiciones$;

-- A4/A5: objetos que en Supabase debe crear `postgres` (st_owner no tiene CREATE sobre la base).
CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA extensions;
CREATE SCHEMA identidad;
CREATE SCHEMA inventario;
CREATE SCHEMA comercial;
CREATE SCHEMA servicios;
CREATE SCHEMA proyectos;
CREATE SCHEMA comunicacion;
CREATE SCHEMA auditoria;
COMMENT ON SCHEMA identidad IS 'Personas, clientes, empleados, cuentas y concesiones.';
COMMENT ON SCHEMA inventario IS 'Productos, catálogo, stock y movimientos.';
COMMENT ON SCHEMA comercial IS 'Carrito, pedidos, cotizaciones y facturación.';
COMMENT ON SCHEMA servicios IS 'Solicitudes, órdenes técnicas, equipos y agenda.';
COMMENT ON SCHEMA proyectos IS 'Solicitudes de software, proyectos, miembros y avances.';
COMMENT ON SCHEMA comunicacion IS 'Conversaciones, archivos, notificaciones y entregas.';
COMMENT ON SCHEMA auditoria IS 'Evidencia de cambios por fila; captura en fase 5.';
GRANT USAGE, CREATE ON SCHEMA identidad TO st_owner WITH GRANT OPTION;
GRANT USAGE, CREATE ON SCHEMA inventario TO st_owner WITH GRANT OPTION;
GRANT USAGE, CREATE ON SCHEMA comercial TO st_owner WITH GRANT OPTION;
GRANT USAGE, CREATE ON SCHEMA servicios TO st_owner WITH GRANT OPTION;
GRANT USAGE, CREATE ON SCHEMA proyectos TO st_owner WITH GRANT OPTION;
GRANT USAGE, CREATE ON SCHEMA comunicacion TO st_owner WITH GRANT OPTION;
GRANT USAGE, CREATE ON SCHEMA auditoria TO st_owner WITH GRANT OPTION;

SET ROLE st_owner;
SET search_path = pg_catalog, public;
SET lock_timeout = '10s';
SET statement_timeout = '5min';

-- MÓDULO 01_estructura (desde CREATE SEQUENCE)
CREATE SEQUENCE comercial.seq_pedido AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 NO MAXVALUE CACHE 1 NO CYCLE;

CREATE SEQUENCE comercial.seq_cotizacion AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 NO MAXVALUE CACHE 1 NO CYCLE;

CREATE SEQUENCE comercial.seq_factura AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 NO MAXVALUE CACHE 1 NO CYCLE;

-- Concesión verificada limitada a un recurso sin cuenta.
CREATE TABLE identidad.acceso_invitado (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    persona_id bigint NOT NULL,
    token_hash bytea NOT NULL,
    medio_verificacion text NOT NULL,
    destino_verificado text NOT NULL,
    verificado_en timestamptz NOT NULL,
    emitido_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    vence_en timestamptz NOT NULL,
    revocado_en timestamptz,
    version_cotizacion_id bigint,
    pedido_id bigint,
    solicitud_servicio_id bigint,
    orden_servicio_id bigint,
    solicitud_cotizacion_id bigint,
    cotizacion_id bigint,
    solicitud_desarrollo_id bigint,
    proyecto_id bigint,
    factura_id bigint,
    conversacion_id bigint,
    CONSTRAINT pk_acceso_invitado PRIMARY KEY (id),
    CONSTRAINT uq_acceso_invitado_token_hash UNIQUE (token_hash),
    CONSTRAINT ck_acceso_invitado_textos CHECK ((btrim(medio_verificacion) <> '') AND (btrim(destino_verificado) <> '')),
    CONSTRAINT ck_acceso_invitado_fechas_finitas CHECK (isfinite(verificado_en) AND isfinite(emitido_en) AND isfinite(vence_en) AND isfinite(revocado_en)),
    CONSTRAINT ck_acceso_invitado_token_hash CHECK (octet_length(token_hash) = 32),
    CONSTRAINT ck_acceso_invitado_fechas CHECK (verificado_en <= emitido_en AND vence_en > emitido_en AND (revocado_en IS NULL OR revocado_en >= emitido_en)),
    CONSTRAINT ck_acceso_invitado_contexto CHECK (num_nonnulls(pedido_id, solicitud_servicio_id, orden_servicio_id, solicitud_cotizacion_id, cotizacion_id, solicitud_desarrollo_id, proyecto_id, factura_id, conversacion_id) = 1),
    CONSTRAINT ck_acceso_invitado_version_contexto CHECK (version_cotizacion_id IS NULL OR cotizacion_id IS NOT NULL)
);
COMMENT ON TABLE identidad.acceso_invitado IS 'Concesión verificada limitada a un recurso sin cuenta.';
COMMENT ON COLUMN identidad.acceso_invitado.id IS 'Identificador interno estable.';
COMMENT ON COLUMN identidad.acceso_invitado.persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN identidad.acceso_invitado.token_hash IS 'SHA-256 del token opaco aleatorio de alta entropía; no del correo.';
COMMENT ON COLUMN identidad.acceso_invitado.medio_verificacion IS 'medio verificacion';
COMMENT ON COLUMN identidad.acceso_invitado.destino_verificado IS 'Canal que se verificó al emitir este acceso.';
COMMENT ON COLUMN identidad.acceso_invitado.verificado_en IS 'verificado en';
COMMENT ON COLUMN identidad.acceso_invitado.emitido_en IS 'emitido en';
COMMENT ON COLUMN identidad.acceso_invitado.vence_en IS 'vence en';
COMMENT ON COLUMN identidad.acceso_invitado.revocado_en IS 'revocado en';
COMMENT ON COLUMN identidad.acceso_invitado.version_cotizacion_id IS 'Referencia a comercial.version_cotizacion.id.';
COMMENT ON COLUMN identidad.acceso_invitado.pedido_id IS 'Referencia a comercial.pedido.id.';
COMMENT ON COLUMN identidad.acceso_invitado.solicitud_servicio_id IS 'Referencia a servicios.solicitud_servicio.id.';
COMMENT ON COLUMN identidad.acceso_invitado.orden_servicio_id IS 'Referencia a servicios.orden_servicio.id.';
COMMENT ON COLUMN identidad.acceso_invitado.solicitud_cotizacion_id IS 'Referencia a comercial.solicitud_cotizacion.id.';
COMMENT ON COLUMN identidad.acceso_invitado.cotizacion_id IS 'Referencia a comercial.cotizacion.id.';
COMMENT ON COLUMN identidad.acceso_invitado.solicitud_desarrollo_id IS 'Referencia a proyectos.solicitud_desarrollo.id.';
COMMENT ON COLUMN identidad.acceso_invitado.proyecto_id IS 'Referencia a proyectos.proyecto.id.';
COMMENT ON COLUMN identidad.acceso_invitado.factura_id IS 'Referencia a comercial.factura.id.';
COMMENT ON COLUMN identidad.acceso_invitado.conversacion_id IS 'Referencia a comunicacion.conversacion.id.';

-- Acciones acotadas de una concesión; evita listas de permisos dentro de un campo.
CREATE TABLE identidad.acceso_invitado_permiso (
    acceso_invitado_id bigint NOT NULL,
    permiso_id bigint NOT NULL,
    CONSTRAINT pk_acceso_invitado_permiso PRIMARY KEY (acceso_invitado_id, permiso_id)
);
COMMENT ON TABLE identidad.acceso_invitado_permiso IS 'Acciones acotadas de una concesión; evita listas de permisos dentro de un campo.';
COMMENT ON COLUMN identidad.acceso_invitado_permiso.acceso_invitado_id IS 'Referencia a identidad.acceso_invitado.id.';
COMMENT ON COLUMN identidad.acceso_invitado_permiso.permiso_id IS 'Referencia a identidad.permiso.id.';

-- Perfil comercial de una persona; puede existir sin usuario.
CREATE TABLE identidad.cliente (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    persona_id bigint NOT NULL,
    codigo text NOT NULL,
    observaciones text,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_cliente PRIMARY KEY (id),
    CONSTRAINT uq_cliente_persona_id UNIQUE (persona_id),
    CONSTRAINT uq_cliente_codigo UNIQUE (codigo),
    CONSTRAINT ck_cliente_textos CHECK ((btrim(codigo) <> '') AND (btrim(observaciones) <> '')),
    CONSTRAINT ck_cliente_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_cliente_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE identidad.cliente IS 'Perfil comercial de una persona; puede existir sin usuario.';
COMMENT ON COLUMN identidad.cliente.id IS 'Identificador interno estable.';
COMMENT ON COLUMN identidad.cliente.persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN identidad.cliente.codigo IS 'Código de negocio estable; unicidad independiente de la PK.';
COMMENT ON COLUMN identidad.cliente.observaciones IS 'observaciones';
COMMENT ON COLUMN identidad.cliente.activo IS 'activo';
COMMENT ON COLUMN identidad.cliente.created_at IS 'Creación del registro.';
COMMENT ON COLUMN identidad.cliente.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Perfil de empleado individual; sin datos de nómina.
CREATE TABLE identidad.empleado (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    persona_id bigint NOT NULL,
    codigo text NOT NULL,
    cargo text NOT NULL,
    fecha_vinculacion date NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_empleado PRIMARY KEY (id),
    CONSTRAINT uq_empleado_persona_id UNIQUE (persona_id),
    CONSTRAINT uq_empleado_codigo UNIQUE (codigo),
    CONSTRAINT ck_empleado_textos CHECK ((btrim(codigo) <> '') AND (btrim(cargo) <> '')),
    CONSTRAINT ck_empleado_fechas_finitas CHECK (isfinite(fecha_vinculacion) AND isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_empleado_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE identidad.empleado IS 'Perfil de empleado individual; sin datos de nómina.';
COMMENT ON COLUMN identidad.empleado.id IS 'Identificador interno estable.';
COMMENT ON COLUMN identidad.empleado.persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN identidad.empleado.codigo IS 'Código de negocio estable; unicidad independiente de la PK.';
COMMENT ON COLUMN identidad.empleado.cargo IS 'cargo';
COMMENT ON COLUMN identidad.empleado.fecha_vinculacion IS 'fecha vinculacion';
COMMENT ON COLUMN identidad.empleado.activo IS 'activo';
COMMENT ON COLUMN identidad.empleado.created_at IS 'Creación del registro.';
COMMENT ON COLUMN identidad.empleado.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Acción autorizable sobre un recurso.
CREATE TABLE identidad.permiso (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    codigo text NOT NULL,
    recurso text NOT NULL,
    accion text NOT NULL,
    descripcion text NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_permiso PRIMARY KEY (id),
    CONSTRAINT uq_permiso_codigo UNIQUE (codigo),
    CONSTRAINT uq_permiso_recurso_accion UNIQUE (recurso, accion),
    CONSTRAINT ck_permiso_textos CHECK ((btrim(codigo) <> '') AND (btrim(recurso) <> '') AND (btrim(accion) <> '') AND (btrim(descripcion) <> '')),
    CONSTRAINT ck_permiso_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_permiso_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE identidad.permiso IS 'Acción autorizable sobre un recurso.';
COMMENT ON COLUMN identidad.permiso.id IS 'Identificador interno estable.';
COMMENT ON COLUMN identidad.permiso.codigo IS 'Código de negocio estable; unicidad independiente de la PK.';
COMMENT ON COLUMN identidad.permiso.recurso IS 'recurso';
COMMENT ON COLUMN identidad.permiso.accion IS 'accion';
COMMENT ON COLUMN identidad.permiso.descripcion IS 'descripcion';
COMMENT ON COLUMN identidad.permiso.created_at IS 'Creación del registro.';
COMMENT ON COLUMN identidad.permiso.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Contacto e identidad compartida, sin cuenta obligatoria.
CREATE TABLE identidad.persona (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    nombres text NOT NULL,
    apellidos text,
    correo_contacto text,
    telefono text,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_persona PRIMARY KEY (id),
    CONSTRAINT ck_persona_textos CHECK ((btrim(nombres) <> '') AND (btrim(apellidos) <> '') AND (btrim(correo_contacto) <> '') AND (btrim(telefono) <> '')),
    CONSTRAINT ck_persona_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_persona_fechas_registro CHECK (updated_at >= created_at),
    CONSTRAINT ck_persona_contacto CHECK (num_nonnulls(correo_contacto, telefono) >= 1)
);
COMMENT ON TABLE identidad.persona IS 'Contacto e identidad compartida, sin cuenta obligatoria.';
COMMENT ON COLUMN identidad.persona.id IS 'Identificador interno estable.';
COMMENT ON COLUMN identidad.persona.nombres IS 'nombres';
COMMENT ON COLUMN identidad.persona.apellidos IS 'apellidos';
COMMENT ON COLUMN identidad.persona.correo_contacto IS 'correo contacto';
COMMENT ON COLUMN identidad.persona.telefono IS 'telefono';
COMMENT ON COLUMN identidad.persona.activo IS 'activo';
COMMENT ON COLUMN identidad.persona.created_at IS 'Creación del registro.';
COMMENT ON COLUMN identidad.persona.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Rol administrable de negocio.
CREATE TABLE identidad.rol (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    codigo text NOT NULL,
    nombre text NOT NULL,
    descripcion text NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_rol PRIMARY KEY (id),
    CONSTRAINT uq_rol_codigo UNIQUE (codigo),
    CONSTRAINT ck_rol_textos CHECK ((btrim(codigo) <> '') AND (btrim(nombre) <> '') AND (btrim(descripcion) <> '')),
    CONSTRAINT ck_rol_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_rol_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE identidad.rol IS 'Rol administrable de negocio.';
COMMENT ON COLUMN identidad.rol.id IS 'Identificador interno estable.';
COMMENT ON COLUMN identidad.rol.codigo IS 'Código de negocio estable; unicidad independiente de la PK.';
COMMENT ON COLUMN identidad.rol.nombre IS 'nombre';
COMMENT ON COLUMN identidad.rol.descripcion IS 'descripcion';
COMMENT ON COLUMN identidad.rol.activo IS 'activo';
COMMENT ON COLUMN identidad.rol.created_at IS 'Creación del registro.';
COMMENT ON COLUMN identidad.rol.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Concesión vigente entre un rol y un permiso.
CREATE TABLE identidad.rol_permiso (
    rol_id bigint NOT NULL,
    permiso_id bigint NOT NULL,
    concedido_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actor_persona_id bigint,
    actor_sistema text,
    CONSTRAINT pk_rol_permiso PRIMARY KEY (rol_id, permiso_id),
    CONSTRAINT ck_rol_permiso_textos CHECK ((btrim(actor_sistema) <> '')),
    CONSTRAINT ck_rol_permiso_fechas_finitas CHECK (isfinite(concedido_en)),
    CONSTRAINT ck_rol_permiso_actor CHECK (num_nonnulls(actor_persona_id, actor_sistema) = 1)
);
COMMENT ON TABLE identidad.rol_permiso IS 'Concesión vigente entre un rol y un permiso.';
COMMENT ON COLUMN identidad.rol_permiso.rol_id IS 'Referencia a identidad.rol.id.';
COMMENT ON COLUMN identidad.rol_permiso.permiso_id IS 'Referencia a identidad.permiso.id.';
COMMENT ON COLUMN identidad.rol_permiso.concedido_en IS 'concedido en';
COMMENT ON COLUMN identidad.rol_permiso.actor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN identidad.rol_permiso.actor_sistema IS 'Proceso automático responsable cuando no hay iniciador humano.';

-- Cuenta opcional; un único perfil de acceso por persona.
CREATE TABLE identidad.usuario (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    persona_id bigint NOT NULL,
    correo_acceso text NOT NULL,
    estado text DEFAULT 'pendiente' NOT NULL,
    origen_auth text NOT NULL,
    emisor_externo text,
    sujeto_externo text,
    verificado_en timestamptz,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_usuario PRIMARY KEY (id),
    CONSTRAINT uq_usuario_persona_id UNIQUE (persona_id),
    CONSTRAINT uq_usuario_correo_acceso UNIQUE (correo_acceso),
    CONSTRAINT uq_usuario_emisor_externo_sujeto_externo UNIQUE (emisor_externo, sujeto_externo),
    CONSTRAINT ck_usuario_textos CHECK ((btrim(correo_acceso) <> '') AND (btrim(estado) <> '') AND (btrim(origen_auth) <> '') AND (btrim(emisor_externo) <> '') AND (btrim(sujeto_externo) <> '')),
    CONSTRAINT ck_usuario_fechas_finitas CHECK (isfinite(verificado_en) AND isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_usuario_estado CHECK (estado IN ('pendiente', 'activo', 'bloqueado', 'inactivo')),
    CONSTRAINT ck_usuario_fechas_registro CHECK (updated_at >= created_at),
    CONSTRAINT ck_usuario_correo_normalizado CHECK (correo_acceso = lower(btrim(correo_acceso))),
    CONSTRAINT ck_usuario_origen_auth CHECK (origen_auth IN ('local', 'externo')),
    CONSTRAINT ck_usuario_identidad_externa CHECK ((origen_auth = 'local' AND emisor_externo IS NULL AND sujeto_externo IS NULL) OR (origen_auth = 'externo' AND emisor_externo IS NOT NULL AND sujeto_externo IS NOT NULL))
);
COMMENT ON TABLE identidad.usuario IS 'Cuenta opcional; un único perfil de acceso por persona.';
COMMENT ON COLUMN identidad.usuario.id IS 'Identificador interno estable.';
COMMENT ON COLUMN identidad.usuario.persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN identidad.usuario.correo_acceso IS 'Correo de acceso normalizado con lower y trim.';
COMMENT ON COLUMN identidad.usuario.estado IS 'Estado: pendiente, activo, bloqueado, inactivo.';
COMMENT ON COLUMN identidad.usuario.origen_auth IS 'local o externo.';
COMMENT ON COLUMN identidad.usuario.emisor_externo IS 'emisor externo';
COMMENT ON COLUMN identidad.usuario.sujeto_externo IS 'sujeto externo';
COMMENT ON COLUMN identidad.usuario.verificado_en IS 'verificado en';
COMMENT ON COLUMN identidad.usuario.created_at IS 'Creación del registro.';
COMMENT ON COLUMN identidad.usuario.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Asignación temporal de rol; conserva retiros y reasignaciones.
CREATE TABLE identidad.usuario_rol (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    usuario_id bigint NOT NULL,
    rol_id bigint NOT NULL,
    inicia_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    termina_en timestamptz,
    actor_persona_id bigint,
    actor_sistema text,
    CONSTRAINT pk_usuario_rol PRIMARY KEY (id),
    CONSTRAINT ck_usuario_rol_textos CHECK ((btrim(actor_sistema) <> '')),
    CONSTRAINT ck_usuario_rol_fechas_finitas CHECK (isfinite(inicia_en) AND isfinite(termina_en)),
    CONSTRAINT ck_usuario_rol_actor CHECK (num_nonnulls(actor_persona_id, actor_sistema) = 1),
    CONSTRAINT ck_usuario_rol_intervalo CHECK (termina_en IS NULL OR termina_en > inicia_en)
);
COMMENT ON TABLE identidad.usuario_rol IS 'Asignación temporal de rol; conserva retiros y reasignaciones.';
COMMENT ON COLUMN identidad.usuario_rol.id IS 'Identificador interno estable.';
COMMENT ON COLUMN identidad.usuario_rol.usuario_id IS 'Referencia a identidad.usuario.id.';
COMMENT ON COLUMN identidad.usuario_rol.rol_id IS 'Referencia a identidad.rol.id.';
COMMENT ON COLUMN identidad.usuario_rol.inicia_en IS 'inicia en';
COMMENT ON COLUMN identidad.usuario_rol.termina_en IS 'termina en';
COMMENT ON COLUMN identidad.usuario_rol.actor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN identidad.usuario_rol.actor_sistema IS 'Proceso automático responsable cuando no hay iniciador humano.';

-- Clasificación principal del catálogo.
CREATE TABLE inventario.categoria (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    nombre text NOT NULL,
    descripcion text NOT NULL,
    activa boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_categoria PRIMARY KEY (id),
    CONSTRAINT uq_categoria_nombre UNIQUE (nombre),
    CONSTRAINT ck_categoria_textos CHECK ((btrim(nombre) <> '') AND (btrim(descripcion) <> '')),
    CONSTRAINT ck_categoria_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_categoria_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE inventario.categoria IS 'Clasificación principal del catálogo.';
COMMENT ON COLUMN inventario.categoria.id IS 'Identificador interno estable.';
COMMENT ON COLUMN inventario.categoria.nombre IS 'nombre';
COMMENT ON COLUMN inventario.categoria.descripcion IS 'descripcion';
COMMENT ON COLUMN inventario.categoria.activa IS 'activa';
COMMENT ON COLUMN inventario.categoria.created_at IS 'Creación del registro.';
COMMENT ON COLUMN inventario.categoria.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Proyección transaccional del saldo físico de una ubicación.
CREATE TABLE inventario.inventario (
    producto_id bigint NOT NULL,
    saldo numeric(14,3) DEFAULT 0 NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_inventario PRIMARY KEY (producto_id),
    CONSTRAINT ck_inventario_numericos CHECK ((saldo <> 'NaN'::numeric)),
    CONSTRAINT ck_inventario_fechas_finitas CHECK (isfinite(updated_at)),
    CONSTRAINT ck_inventario_saldo_no_negativo CHECK (saldo >= 0)
);
COMMENT ON TABLE inventario.inventario IS 'Proyección transaccional del saldo físico de una ubicación.';
COMMENT ON COLUMN inventario.inventario.producto_id IS 'Referencia a inventario.producto.id.';
COMMENT ON COLUMN inventario.inventario.saldo IS 'Suma materializada de movimientos.';
COMMENT ON COLUMN inventario.inventario.updated_at IS 'updated at';

-- Libro inmutable de entradas, salidas y ajustes.
CREATE TABLE inventario.movimiento_inventario (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    producto_id bigint NOT NULL,
    tipo text NOT NULL,
    delta numeric(14,3) NOT NULL,
    motivo text NOT NULL,
    detalle_pedido_id bigint,
    compensa_movimiento_id bigint,
    operacion_id uuid NOT NULL,
    registrado_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actor_persona_id bigint,
    actor_sistema text,
    CONSTRAINT pk_movimiento_inventario PRIMARY KEY (id),
    CONSTRAINT uq_movimiento_inventario_operacion_id UNIQUE (operacion_id),
    CONSTRAINT ck_movimiento_inventario_textos CHECK ((btrim(tipo) <> '') AND (btrim(motivo) <> '') AND (btrim(actor_sistema) <> '')),
    CONSTRAINT ck_movimiento_inventario_numericos CHECK ((delta <> 'NaN'::numeric)),
    CONSTRAINT ck_movimiento_inventario_fechas_finitas CHECK (isfinite(registrado_en)),
    CONSTRAINT ck_movimiento_inventario_actor CHECK (num_nonnulls(actor_persona_id, actor_sistema) = 1),
    CONSTRAINT ck_movimiento_tipo_delta CHECK ((tipo = 'entrada' AND delta > 0) OR (tipo = 'salida' AND delta < 0) OR (tipo = 'ajuste' AND delta <> 0)),
    CONSTRAINT ck_movimiento_origen_salida CHECK (detalle_pedido_id IS NULL OR tipo = 'salida'),
    CONSTRAINT ck_movimiento_no_autocompensa CHECK (compensa_movimiento_id IS NULL OR compensa_movimiento_id <> id)
);
COMMENT ON TABLE inventario.movimiento_inventario IS 'Libro inmutable de entradas, salidas y ajustes.';
COMMENT ON COLUMN inventario.movimiento_inventario.id IS 'Identificador interno estable.';
COMMENT ON COLUMN inventario.movimiento_inventario.producto_id IS 'Referencia a inventario.inventario.producto_id.';
COMMENT ON COLUMN inventario.movimiento_inventario.tipo IS 'tipo';
COMMENT ON COLUMN inventario.movimiento_inventario.delta IS 'Variación firmada de existencia física.';
COMMENT ON COLUMN inventario.movimiento_inventario.motivo IS 'motivo';
COMMENT ON COLUMN inventario.movimiento_inventario.detalle_pedido_id IS 'Referencia a comercial.detalle_pedido.id.';
COMMENT ON COLUMN inventario.movimiento_inventario.compensa_movimiento_id IS 'Referencia a inventario.movimiento_inventario.id.';
COMMENT ON COLUMN inventario.movimiento_inventario.operacion_id IS 'Clave de reintento aportada por backend, no renovada en cada retry.';
COMMENT ON COLUMN inventario.movimiento_inventario.registrado_en IS 'registrado en';
COMMENT ON COLUMN inventario.movimiento_inventario.actor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN inventario.movimiento_inventario.actor_sistema IS 'Proceso automático responsable cuando no hay iniciador humano.';

-- Producto publicable con condiciones vigentes.
CREATE TABLE inventario.producto (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    sku text NOT NULL,
    categoria_id bigint NOT NULL,
    nombre text NOT NULL,
    descripcion text NOT NULL,
    unidad text NOT NULL,
    precio_vigente numeric(18,4) NOT NULL,
    moneda text NOT NULL,
    publicado boolean DEFAULT false NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_producto PRIMARY KEY (id),
    CONSTRAINT uq_producto_sku UNIQUE (sku),
    CONSTRAINT ck_producto_textos CHECK ((btrim(sku) <> '') AND (btrim(nombre) <> '') AND (btrim(descripcion) <> '') AND (btrim(unidad) <> '') AND (btrim(moneda) <> '')),
    CONSTRAINT ck_producto_numericos CHECK ((precio_vigente <> 'NaN'::numeric)),
    CONSTRAINT ck_producto_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_producto_moneda CHECK ((moneda ~ '^[A-Z]{3}$')),
    CONSTRAINT ck_producto_precio_no_negativo CHECK (precio_vigente >= 0),
    CONSTRAINT ck_producto_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE inventario.producto IS 'Producto publicable con condiciones vigentes.';
COMMENT ON COLUMN inventario.producto.id IS 'Identificador interno estable.';
COMMENT ON COLUMN inventario.producto.sku IS 'sku';
COMMENT ON COLUMN inventario.producto.categoria_id IS 'Referencia a inventario.categoria.id.';
COMMENT ON COLUMN inventario.producto.nombre IS 'nombre';
COMMENT ON COLUMN inventario.producto.descripcion IS 'descripcion';
COMMENT ON COLUMN inventario.producto.unidad IS 'unidad';
COMMENT ON COLUMN inventario.producto.precio_vigente IS 'precio vigente';
COMMENT ON COLUMN inventario.producto.moneda IS 'Código monetario de tres letras mayúsculas; sin moneda predeterminada.';
COMMENT ON COLUMN inventario.producto.publicado IS 'publicado';
COMMENT ON COLUMN inventario.producto.activo IS 'activo';
COMMENT ON COLUMN inventario.producto.created_at IS 'Creación del registro.';
COMMENT ON COLUMN inventario.producto.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Presentación de imágenes sin duplicar el producto.
CREATE TABLE inventario.producto_imagen (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    producto_id bigint NOT NULL,
    archivo_id bigint NOT NULL,
    orden integer NOT NULL,
    texto_alternativo text NOT NULL,
    principal boolean DEFAULT false NOT NULL,
    CONSTRAINT pk_producto_imagen PRIMARY KEY (id),
    CONSTRAINT uq_producto_imagen_producto_id_archivo_id UNIQUE (producto_id, archivo_id),
    CONSTRAINT uq_producto_imagen_producto_id_orden UNIQUE (producto_id, orden),
    CONSTRAINT ck_producto_imagen_textos CHECK ((btrim(texto_alternativo) <> '')),
    CONSTRAINT ck_producto_imagen_orden_positivo CHECK (orden > 0)
);
COMMENT ON TABLE inventario.producto_imagen IS 'Presentación de imágenes sin duplicar el producto.';
COMMENT ON COLUMN inventario.producto_imagen.id IS 'Identificador interno estable.';
COMMENT ON COLUMN inventario.producto_imagen.producto_id IS 'Referencia a inventario.producto.id.';
COMMENT ON COLUMN inventario.producto_imagen.archivo_id IS 'Referencia a comunicacion.archivo.id.';
COMMENT ON COLUMN inventario.producto_imagen.orden IS 'orden';
COMMENT ON COLUMN inventario.producto_imagen.texto_alternativo IS 'texto alternativo';
COMMENT ON COLUMN inventario.producto_imagen.principal IS 'principal';

-- Compromiso de unidades de una línea confirmada.
CREATE TABLE inventario.reserva_inventario (
    detalle_pedido_id bigint NOT NULL,
    estado text DEFAULT 'activa' NOT NULL,
    creada_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    cerrada_en timestamptz,
    motivo_liberacion text,
    CONSTRAINT pk_reserva_inventario PRIMARY KEY (detalle_pedido_id),
    CONSTRAINT ck_reserva_inventario_textos CHECK ((btrim(estado) <> '') AND (btrim(motivo_liberacion) <> '')),
    CONSTRAINT ck_reserva_inventario_fechas_finitas CHECK (isfinite(creada_en) AND isfinite(cerrada_en)),
    CONSTRAINT ck_reserva_inventario_estado CHECK (estado IN ('activa', 'consumida', 'liberada')),
    CONSTRAINT ck_reserva_cierre_estado CHECK ((estado = 'activa' AND cerrada_en IS NULL) OR (estado IN ('consumida', 'liberada') AND cerrada_en IS NOT NULL)),
    CONSTRAINT ck_reserva_fechas CHECK (cerrada_en IS NULL OR cerrada_en >= creada_en),
    CONSTRAINT ck_reserva_motivo_liberacion CHECK ((estado = 'liberada' AND motivo_liberacion IS NOT NULL) OR (estado <> 'liberada' AND motivo_liberacion IS NULL))
);
COMMENT ON TABLE inventario.reserva_inventario IS 'Compromiso de unidades de una línea confirmada.';
COMMENT ON COLUMN inventario.reserva_inventario.detalle_pedido_id IS 'Referencia a comercial.detalle_pedido.id.';
COMMENT ON COLUMN inventario.reserva_inventario.estado IS 'Estado: activa, consumida, liberada.';
COMMENT ON COLUMN inventario.reserva_inventario.creada_en IS 'creada en';
COMMENT ON COLUMN inventario.reserva_inventario.cerrada_en IS 'cerrada en';
COMMENT ON COLUMN inventario.reserva_inventario.motivo_liberacion IS 'motivo liberacion';

-- Selección de compra identificada o de visitante.
CREATE TABLE comercial.carrito (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    cliente_id bigint,
    sesion_anonima_hash bytea,
    estado text DEFAULT 'abierto' NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_carrito PRIMARY KEY (id),
    CONSTRAINT uq_carrito_sesion_anonima_hash UNIQUE (sesion_anonima_hash),
    CONSTRAINT ck_carrito_textos CHECK ((btrim(estado) <> '')),
    CONSTRAINT ck_carrito_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_carrito_estado CHECK (estado IN ('abierto', 'convertido', 'abandonado')),
    CONSTRAINT ck_carrito_titular_xor CHECK (num_nonnulls(cliente_id, sesion_anonima_hash) = 1),
    CONSTRAINT ck_carrito_huella_32_bytes CHECK (sesion_anonima_hash IS NULL OR octet_length(sesion_anonima_hash) = 32),
    CONSTRAINT ck_carrito_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE comercial.carrito IS 'Selección de compra identificada o de visitante.';
COMMENT ON COLUMN comercial.carrito.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comercial.carrito.cliente_id IS 'Referencia a identidad.cliente.id.';
COMMENT ON COLUMN comercial.carrito.sesion_anonima_hash IS 'Huella de identificador secreto del carrito invitado.';
COMMENT ON COLUMN comercial.carrito.estado IS 'Estado: abierto, convertido, abandonado.';
COMMENT ON COLUMN comercial.carrito.created_at IS 'Creación del registro.';
COMMENT ON COLUMN comercial.carrito.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Archivo documental asociado a factura, sin presumir un pago.
CREATE TABLE comercial.comprobante_factura (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    factura_id bigint NOT NULL,
    archivo_id bigint NOT NULL,
    clase_documento text NOT NULL,
    descripcion text NOT NULL,
    incorporado_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_comprobante_factura PRIMARY KEY (id),
    CONSTRAINT uq_comprobante_factura_factura_id_archivo_id UNIQUE (factura_id, archivo_id),
    CONSTRAINT ck_comprobante_factura_textos CHECK ((btrim(clase_documento) <> '') AND (btrim(descripcion) <> '')),
    CONSTRAINT ck_comprobante_factura_fechas_finitas CHECK (isfinite(incorporado_en))
);
COMMENT ON TABLE comercial.comprobante_factura IS 'Archivo documental asociado a factura, sin presumir un pago.';
COMMENT ON COLUMN comercial.comprobante_factura.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comercial.comprobante_factura.factura_id IS 'Referencia a comercial.factura.id.';
COMMENT ON COLUMN comercial.comprobante_factura.archivo_id IS 'Referencia a comunicacion.archivo.id.';
COMMENT ON COLUMN comercial.comprobante_factura.clase_documento IS 'clase documento';
COMMENT ON COLUMN comercial.comprobante_factura.descripcion IS 'descripcion';
COMMENT ON COLUMN comercial.comprobante_factura.incorporado_en IS 'incorporado en';

-- Negociación que conserva versiones.
CREATE TABLE comercial.cotizacion (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    numero bigint DEFAULT nextval('comercial.seq_cotizacion'::regclass) NOT NULL,
    solicitud_cotizacion_id bigint,
    persona_directa_id bigint,
    estado text DEFAULT 'abierta' NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_cotizacion PRIMARY KEY (id),
    CONSTRAINT uq_cotizacion_numero UNIQUE (numero),
    CONSTRAINT uq_cotizacion_solicitud_cotizacion_id UNIQUE (solicitud_cotizacion_id),
    CONSTRAINT ck_cotizacion_textos CHECK ((btrim(estado) <> '')),
    CONSTRAINT ck_cotizacion_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_cotizacion_estado CHECK (estado IN ('abierta', 'aceptada', 'cerrada', 'anulada')),
    CONSTRAINT ck_cotizacion_destinatario_xor CHECK (num_nonnulls(solicitud_cotizacion_id, persona_directa_id) = 1),
    CONSTRAINT ck_cotizacion_numero_positivo CHECK (numero > 0),
    CONSTRAINT ck_cotizacion_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE comercial.cotizacion IS 'Negociación que conserva versiones.';
COMMENT ON COLUMN comercial.cotizacion.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comercial.cotizacion.numero IS 'Consecutivo comercial.';
COMMENT ON COLUMN comercial.cotizacion.solicitud_cotizacion_id IS 'Referencia a comercial.solicitud_cotizacion.id.';
COMMENT ON COLUMN comercial.cotizacion.persona_directa_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN comercial.cotizacion.estado IS 'Estado: abierta, aceptada, cerrada, anulada.';
COMMENT ON COLUMN comercial.cotizacion.created_at IS 'Creación del registro.';
COMMENT ON COLUMN comercial.cotizacion.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Producto y cantidad solicitados en un carrito.
CREATE TABLE comercial.detalle_carrito (
    carrito_id bigint NOT NULL,
    producto_id bigint NOT NULL,
    cantidad numeric(14,3) NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_detalle_carrito PRIMARY KEY (carrito_id, producto_id),
    CONSTRAINT ck_detalle_carrito_numericos CHECK ((cantidad <> 'NaN'::numeric)),
    CONSTRAINT ck_detalle_carrito_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_detalle_carrito_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_detalle_carrito_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE comercial.detalle_carrito IS 'Producto y cantidad solicitados en un carrito.';
COMMENT ON COLUMN comercial.detalle_carrito.carrito_id IS 'Referencia a comercial.carrito.id.';
COMMENT ON COLUMN comercial.detalle_carrito.producto_id IS 'Referencia a inventario.producto.id.';
COMMENT ON COLUMN comercial.detalle_carrito.cantidad IS 'cantidad';
COMMENT ON COLUMN comercial.detalle_carrito.created_at IS 'Creación del registro.';
COMMENT ON COLUMN comercial.detalle_carrito.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Concepto de producto, servicio técnico o descripción libre.
CREATE TABLE comercial.detalle_cotizacion (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    version_cotizacion_id bigint NOT NULL,
    numero_linea integer NOT NULL,
    clase text NOT NULL,
    producto_id bigint,
    servicio_ofrecido_id bigint,
    descripcion text NOT NULL,
    cantidad numeric(14,3) NOT NULL,
    unidad text NOT NULL,
    precio_unitario numeric(18,4) NOT NULL,
    descuento_importe numeric(18,2) DEFAULT 0 NOT NULL,
    tasa_impuesto numeric(9,6) NOT NULL,
    subtotal numeric(18,2) GENERATED ALWAYS AS ((round(cantidad * precio_unitario, 2) - descuento_importe)) STORED NOT NULL,
    impuesto_importe numeric(18,2) GENERATED ALWAYS AS ((round((round(cantidad * precio_unitario, 2) - descuento_importe) * tasa_impuesto, 2))) STORED NOT NULL,
    total numeric(18,2) GENERATED ALWAYS AS ((round(cantidad * precio_unitario, 2) - descuento_importe) + (round((round(cantidad * precio_unitario, 2) - descuento_importe) * tasa_impuesto, 2))) STORED NOT NULL,
    CONSTRAINT pk_detalle_cotizacion PRIMARY KEY (id),
    CONSTRAINT uq_detalle_cotizacion_version_cotizacion_id_numero_linea UNIQUE (version_cotizacion_id, numero_linea),
    CONSTRAINT ck_detalle_cotizacion_textos CHECK ((btrim(clase) <> '') AND (btrim(descripcion) <> '') AND (btrim(unidad) <> '')),
    CONSTRAINT ck_detalle_cotizacion_numericos CHECK ((cantidad <> 'NaN'::numeric) AND (precio_unitario <> 'NaN'::numeric) AND (descuento_importe <> 'NaN'::numeric) AND (tasa_impuesto <> 'NaN'::numeric) AND (subtotal <> 'NaN'::numeric) AND (impuesto_importe <> 'NaN'::numeric) AND (total <> 'NaN'::numeric)),
    CONSTRAINT ck_detalle_cotizacion_cantidad_precio_descuento CHECK (cantidad > 0 AND precio_unitario >= 0 AND descuento_importe >= 0),
    CONSTRAINT ck_detalle_cotizacion_tasa CHECK (tasa_impuesto >= 0 AND tasa_impuesto <= 1),
    CONSTRAINT ck_detalle_cotizacion_numero_linea CHECK (numero_linea > 0),
    CONSTRAINT ck_detalle_cotizacion_importes_no_negativos CHECK (subtotal >= 0 AND impuesto_importe >= 0),
    CONSTRAINT ck_detalle_cotizacion_descuento_limite CHECK (descuento_importe <= round(cantidad * precio_unitario, 2)),
    CONSTRAINT ck_detalle_cotizacion_clase_origen CHECK ((clase = 'producto' AND producto_id IS NOT NULL AND servicio_ofrecido_id IS NULL) OR (clase = 'servicio' AND producto_id IS NULL AND servicio_ofrecido_id IS NOT NULL) OR (clase = 'libre' AND producto_id IS NULL AND servicio_ofrecido_id IS NULL))
);
COMMENT ON TABLE comercial.detalle_cotizacion IS 'Concepto de producto, servicio técnico o descripción libre.';
COMMENT ON COLUMN comercial.detalle_cotizacion.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comercial.detalle_cotizacion.version_cotizacion_id IS 'Referencia a comercial.version_cotizacion.id.';
COMMENT ON COLUMN comercial.detalle_cotizacion.numero_linea IS 'numero linea';
COMMENT ON COLUMN comercial.detalle_cotizacion.clase IS 'producto, servicio o libre.';
COMMENT ON COLUMN comercial.detalle_cotizacion.producto_id IS 'Referencia a inventario.producto.id.';
COMMENT ON COLUMN comercial.detalle_cotizacion.servicio_ofrecido_id IS 'Referencia a servicios.servicio_ofrecido.id.';
COMMENT ON COLUMN comercial.detalle_cotizacion.descripcion IS 'descripcion';
COMMENT ON COLUMN comercial.detalle_cotizacion.cantidad IS 'Cantidad positiva del concepto.';
COMMENT ON COLUMN comercial.detalle_cotizacion.unidad IS 'Unidad histórica del concepto.';
COMMENT ON COLUMN comercial.detalle_cotizacion.precio_unitario IS 'Precio neto unitario histórico.';
COMMENT ON COLUMN comercial.detalle_cotizacion.descuento_importe IS 'Descuento absoluto neto de esta línea.';
COMMENT ON COLUMN comercial.detalle_cotizacion.tasa_impuesto IS 'Tasa explícita en fracción: intervalo [0,1], sin default fiscal.';
COMMENT ON COLUMN comercial.detalle_cotizacion.subtotal IS 'Base neta de línea.';
COMMENT ON COLUMN comercial.detalle_cotizacion.impuesto_importe IS 'Impuesto de línea.';
COMMENT ON COLUMN comercial.detalle_cotizacion.total IS 'Importe total de línea.';

-- Concepto facturado con aplicación de cantidad o importe al origen.
CREATE TABLE comercial.detalle_factura (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    factura_id bigint NOT NULL,
    numero_linea integer NOT NULL,
    detalle_pedido_id bigint,
    detalle_cotizacion_id bigint,
    descripcion text NOT NULL,
    cantidad numeric(14,3) NOT NULL,
    unidad text NOT NULL,
    precio_unitario numeric(18,4) NOT NULL,
    descuento_importe numeric(18,2) DEFAULT 0 NOT NULL,
    tasa_impuesto numeric(9,6) NOT NULL,
    ajuste_base numeric(18,2) DEFAULT 0 NOT NULL,
    ajuste_impuesto numeric(18,2) DEFAULT 0 NOT NULL,
    subtotal numeric(18,2) GENERATED ALWAYS AS ((round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base)) STORED NOT NULL,
    impuesto_importe numeric(18,2) GENERATED ALWAYS AS ((round((round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base) * tasa_impuesto, 2) + ajuste_impuesto)) STORED NOT NULL,
    total numeric(18,2) GENERATED ALWAYS AS ((round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base) + (round((round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base) * tasa_impuesto, 2) + ajuste_impuesto)) STORED NOT NULL,
    CONSTRAINT pk_detalle_factura PRIMARY KEY (id),
    CONSTRAINT uq_detalle_factura_factura_id_numero_linea UNIQUE (factura_id, numero_linea),
    CONSTRAINT ck_detalle_factura_textos CHECK ((btrim(descripcion) <> '') AND (btrim(unidad) <> '')),
    CONSTRAINT ck_detalle_factura_numericos CHECK ((cantidad <> 'NaN'::numeric) AND (precio_unitario <> 'NaN'::numeric) AND (descuento_importe <> 'NaN'::numeric) AND (tasa_impuesto <> 'NaN'::numeric) AND (ajuste_base <> 'NaN'::numeric) AND (ajuste_impuesto <> 'NaN'::numeric) AND (subtotal <> 'NaN'::numeric) AND (impuesto_importe <> 'NaN'::numeric) AND (total <> 'NaN'::numeric)),
    CONSTRAINT ck_detalle_factura_cantidad_precio_descuento CHECK (cantidad > 0 AND precio_unitario >= 0 AND descuento_importe >= 0),
    CONSTRAINT ck_detalle_factura_tasa CHECK (tasa_impuesto >= 0 AND tasa_impuesto <= 1),
    CONSTRAINT ck_detalle_factura_numero_linea CHECK (numero_linea > 0),
    CONSTRAINT ck_detalle_factura_importes_no_negativos CHECK (subtotal >= 0 AND impuesto_importe >= 0),
    CONSTRAINT ck_detalle_factura_max_un_origen CHECK (num_nonnulls(detalle_pedido_id, detalle_cotizacion_id) <= 1)
);
COMMENT ON TABLE comercial.detalle_factura IS 'Concepto facturado con aplicación de cantidad o importe al origen.';
COMMENT ON COLUMN comercial.detalle_factura.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comercial.detalle_factura.factura_id IS 'Referencia a comercial.factura.id.';
COMMENT ON COLUMN comercial.detalle_factura.numero_linea IS 'numero linea';
COMMENT ON COLUMN comercial.detalle_factura.detalle_pedido_id IS 'Referencia a comercial.detalle_pedido.id.';
COMMENT ON COLUMN comercial.detalle_factura.detalle_cotizacion_id IS 'Referencia a comercial.detalle_cotizacion.id.';
COMMENT ON COLUMN comercial.detalle_factura.descripcion IS 'descripcion';
COMMENT ON COLUMN comercial.detalle_factura.cantidad IS 'Cantidad positiva del concepto.';
COMMENT ON COLUMN comercial.detalle_factura.unidad IS 'Unidad histórica del concepto.';
COMMENT ON COLUMN comercial.detalle_factura.precio_unitario IS 'Precio neto unitario histórico.';
COMMENT ON COLUMN comercial.detalle_factura.descuento_importe IS 'Descuento absoluto neto de esta línea.';
COMMENT ON COLUMN comercial.detalle_factura.tasa_impuesto IS 'Tasa explícita en fracción: intervalo [0,1], sin default fiscal.';
COMMENT ON COLUMN comercial.detalle_factura.ajuste_base IS 'Ajuste exclusivamente calculado para repartir importes históricos al aplicar o facturar parcialmente una fuente.';
COMMENT ON COLUMN comercial.detalle_factura.ajuste_impuesto IS 'Ajuste exclusivamente calculado para repartir impuesto histórico de la fuente.';
COMMENT ON COLUMN comercial.detalle_factura.subtotal IS 'Base neta de línea.';
COMMENT ON COLUMN comercial.detalle_factura.impuesto_importe IS 'Impuesto de línea.';
COMMENT ON COLUMN comercial.detalle_factura.total IS 'Importe total de línea.';

-- Línea comercial histórica vendida.
CREATE TABLE comercial.detalle_pedido (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    pedido_id bigint NOT NULL,
    numero_linea integer NOT NULL,
    producto_id bigint NOT NULL,
    detalle_cotizacion_id bigint,
    descripcion text NOT NULL,
    cantidad numeric(14,3) NOT NULL,
    unidad text NOT NULL,
    precio_unitario numeric(18,4) NOT NULL,
    descuento_importe numeric(18,2) DEFAULT 0 NOT NULL,
    tasa_impuesto numeric(9,6) NOT NULL,
    ajuste_base numeric(18,2) DEFAULT 0 NOT NULL,
    ajuste_impuesto numeric(18,2) DEFAULT 0 NOT NULL,
    subtotal numeric(18,2) GENERATED ALWAYS AS ((round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base)) STORED NOT NULL,
    impuesto_importe numeric(18,2) GENERATED ALWAYS AS ((round((round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base) * tasa_impuesto, 2) + ajuste_impuesto)) STORED NOT NULL,
    total numeric(18,2) GENERATED ALWAYS AS ((round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base) + (round((round(cantidad * precio_unitario, 2) - descuento_importe + ajuste_base) * tasa_impuesto, 2) + ajuste_impuesto)) STORED NOT NULL,
    CONSTRAINT pk_detalle_pedido PRIMARY KEY (id),
    CONSTRAINT uq_detalle_pedido_pedido_id_numero_linea UNIQUE (pedido_id, numero_linea),
    CONSTRAINT ck_detalle_pedido_textos CHECK ((btrim(descripcion) <> '') AND (btrim(unidad) <> '')),
    CONSTRAINT ck_detalle_pedido_numericos CHECK ((cantidad <> 'NaN'::numeric) AND (precio_unitario <> 'NaN'::numeric) AND (descuento_importe <> 'NaN'::numeric) AND (tasa_impuesto <> 'NaN'::numeric) AND (ajuste_base <> 'NaN'::numeric) AND (ajuste_impuesto <> 'NaN'::numeric) AND (subtotal <> 'NaN'::numeric) AND (impuesto_importe <> 'NaN'::numeric) AND (total <> 'NaN'::numeric)),
    CONSTRAINT ck_detalle_pedido_cantidad_precio_descuento CHECK (cantidad > 0 AND precio_unitario >= 0 AND descuento_importe >= 0),
    CONSTRAINT ck_detalle_pedido_tasa CHECK (tasa_impuesto >= 0 AND tasa_impuesto <= 1),
    CONSTRAINT ck_detalle_pedido_numero_linea CHECK (numero_linea > 0),
    CONSTRAINT ck_detalle_pedido_importes_no_negativos CHECK (subtotal >= 0 AND impuesto_importe >= 0),
    CONSTRAINT ck_detalle_pedido_ajustes_directos CHECK (detalle_cotizacion_id IS NOT NULL OR (ajuste_base = 0 AND ajuste_impuesto = 0))
);
COMMENT ON TABLE comercial.detalle_pedido IS 'Línea comercial histórica vendida.';
COMMENT ON COLUMN comercial.detalle_pedido.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comercial.detalle_pedido.pedido_id IS 'Referencia a comercial.pedido.id.';
COMMENT ON COLUMN comercial.detalle_pedido.numero_linea IS 'numero linea';
COMMENT ON COLUMN comercial.detalle_pedido.producto_id IS 'Referencia a inventario.producto.id.';
COMMENT ON COLUMN comercial.detalle_pedido.detalle_cotizacion_id IS 'Referencia a comercial.detalle_cotizacion.id.';
COMMENT ON COLUMN comercial.detalle_pedido.descripcion IS 'descripcion';
COMMENT ON COLUMN comercial.detalle_pedido.cantidad IS 'Cantidad positiva del concepto.';
COMMENT ON COLUMN comercial.detalle_pedido.unidad IS 'Unidad histórica del concepto.';
COMMENT ON COLUMN comercial.detalle_pedido.precio_unitario IS 'Precio neto unitario histórico.';
COMMENT ON COLUMN comercial.detalle_pedido.descuento_importe IS 'Descuento absoluto neto de esta línea.';
COMMENT ON COLUMN comercial.detalle_pedido.tasa_impuesto IS 'Tasa explícita en fracción: intervalo [0,1], sin default fiscal.';
COMMENT ON COLUMN comercial.detalle_pedido.ajuste_base IS 'Ajuste exclusivamente calculado para repartir importes históricos al aplicar o facturar parcialmente una fuente.';
COMMENT ON COLUMN comercial.detalle_pedido.ajuste_impuesto IS 'Ajuste exclusivamente calculado para repartir impuesto histórico de la fuente.';
COMMENT ON COLUMN comercial.detalle_pedido.subtotal IS 'Base neta de línea.';
COMMENT ON COLUMN comercial.detalle_pedido.impuesto_importe IS 'Impuesto de línea.';
COMMENT ON COLUMN comercial.detalle_pedido.total IS 'Importe total de línea.';

-- Documento comercial con un origen principal y receptor histórico.
CREATE TABLE comercial.factura (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    numero bigint,
    pedido_id bigint,
    orden_servicio_id bigint,
    proyecto_id bigint,
    estado text DEFAULT 'borrador' NOT NULL,
    moneda text NOT NULL,
    receptor_nombre text NOT NULL,
    receptor_identificacion text,
    receptor_correo text,
    receptor_telefono text,
    receptor_direccion text,
    emitida_en timestamptz,
    anulada_en timestamptz,
    motivo_anulacion text,
    operacion_emision_id uuid,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_factura PRIMARY KEY (id),
    CONSTRAINT uq_factura_numero UNIQUE (numero),
    CONSTRAINT uq_factura_operacion_emision_id UNIQUE (operacion_emision_id),
    CONSTRAINT ck_factura_textos CHECK ((btrim(estado) <> '') AND (btrim(moneda) <> '') AND (btrim(receptor_nombre) <> '') AND (btrim(receptor_identificacion) <> '') AND (btrim(receptor_correo) <> '') AND (btrim(receptor_telefono) <> '') AND (btrim(receptor_direccion) <> '') AND (btrim(motivo_anulacion) <> '')),
    CONSTRAINT ck_factura_fechas_finitas CHECK (isfinite(emitida_en) AND isfinite(anulada_en) AND isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_factura_moneda CHECK ((moneda ~ '^[A-Z]{3}$')),
    CONSTRAINT ck_factura_estado CHECK (estado IN ('borrador', 'emitida', 'anulada')),
    CONSTRAINT ck_factura_origen_xor CHECK (num_nonnulls(pedido_id, orden_servicio_id, proyecto_id) = 1),
    CONSTRAINT ck_factura_numero_positivo CHECK (numero IS NULL OR numero > 0),
    CONSTRAINT ck_factura_emision_estado CHECK ((estado = 'borrador' AND numero IS NULL AND emitida_en IS NULL AND operacion_emision_id IS NULL) OR (estado IN ('emitida', 'anulada') AND numero IS NOT NULL AND emitida_en IS NOT NULL AND operacion_emision_id IS NOT NULL)),
    CONSTRAINT ck_factura_anulacion_estado CHECK ((estado = 'anulada' AND anulada_en IS NOT NULL AND motivo_anulacion IS NOT NULL) OR (estado <> 'anulada' AND anulada_en IS NULL AND motivo_anulacion IS NULL)),
    CONSTRAINT ck_factura_emision_fecha CHECK (emitida_en IS NULL OR emitida_en >= created_at),
    CONSTRAINT ck_factura_anulacion_fecha CHECK (anulada_en IS NULL OR (emitida_en IS NOT NULL AND anulada_en >= emitida_en)),
    CONSTRAINT ck_factura_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE comercial.factura IS 'Documento comercial con un origen principal y receptor histórico.';
COMMENT ON COLUMN comercial.factura.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comercial.factura.numero IS 'Número asignado al emitir; no es garantía de secuencia fiscal sin saltos.';
COMMENT ON COLUMN comercial.factura.pedido_id IS 'Referencia a comercial.pedido.id.';
COMMENT ON COLUMN comercial.factura.orden_servicio_id IS 'Referencia a servicios.orden_servicio.id.';
COMMENT ON COLUMN comercial.factura.proyecto_id IS 'Referencia a proyectos.proyecto.id.';
COMMENT ON COLUMN comercial.factura.estado IS 'Estado: borrador, emitida, anulada.';
COMMENT ON COLUMN comercial.factura.moneda IS 'Código monetario de tres letras mayúsculas; sin moneda predeterminada.';
COMMENT ON COLUMN comercial.factura.receptor_nombre IS 'receptor nombre';
COMMENT ON COLUMN comercial.factura.receptor_identificacion IS 'receptor identificacion';
COMMENT ON COLUMN comercial.factura.receptor_correo IS 'receptor correo';
COMMENT ON COLUMN comercial.factura.receptor_telefono IS 'receptor telefono';
COMMENT ON COLUMN comercial.factura.receptor_direccion IS 'receptor direccion';
COMMENT ON COLUMN comercial.factura.emitida_en IS 'emitida en';
COMMENT ON COLUMN comercial.factura.anulada_en IS 'anulada en';
COMMENT ON COLUMN comercial.factura.motivo_anulacion IS 'motivo anulacion';
COMMENT ON COLUMN comercial.factura.operacion_emision_id IS 'operacion emision id';
COMMENT ON COLUMN comercial.factura.created_at IS 'Creación del registro.';
COMMENT ON COLUMN comercial.factura.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Historial explícito e inmutable de comercial.cotizacion.id.
CREATE TABLE comercial.historial_cotizacion (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    cotizacion_id bigint NOT NULL,
    numero_evento integer NOT NULL,
    estado_anterior text,
    estado_nuevo text NOT NULL,
    motivo text NOT NULL,
    correlacion_id uuid NOT NULL,
    ocurrido_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actor_persona_id bigint,
    actor_sistema text,
    version_cotizacion_id bigint,
    estado_version_anterior text,
    estado_version_nuevo text,
    CONSTRAINT pk_historial_cotizacion PRIMARY KEY (id),
    CONSTRAINT uq_historial_cotizacion_cotizacion_id_numero_evento UNIQUE (cotizacion_id, numero_evento),
    CONSTRAINT ck_historial_cotizacion_textos CHECK ((btrim(estado_anterior) <> '') AND (btrim(estado_nuevo) <> '') AND (btrim(motivo) <> '') AND (btrim(actor_sistema) <> '') AND (btrim(estado_version_anterior) <> '') AND (btrim(estado_version_nuevo) <> '')),
    CONSTRAINT ck_historial_cotizacion_fechas_finitas CHECK (isfinite(ocurrido_en)),
    CONSTRAINT ck_historial_cotizacion_actor CHECK (num_nonnulls(actor_persona_id, actor_sistema) = 1),
    CONSTRAINT ck_historial_cotizacion_ordinal CHECK (numero_evento > 0 AND ((numero_evento = 1 AND estado_anterior IS NULL) OR (numero_evento > 1 AND estado_anterior IS NOT NULL))),
    CONSTRAINT ck_historial_cotizacion_estados CHECK (estado_nuevo IN ('abierta', 'aceptada', 'cerrada', 'anulada') AND (estado_anterior IS NULL OR estado_anterior IN ('abierta', 'aceptada', 'cerrada', 'anulada'))),
    CONSTRAINT ck_historial_cotizacion_version_contexto CHECK ((version_cotizacion_id IS NULL AND estado_version_anterior IS NULL AND estado_version_nuevo IS NULL) OR (version_cotizacion_id IS NOT NULL AND estado_version_nuevo IS NOT NULL)),
    CONSTRAINT ck_historial_cotizacion_version_estados CHECK ((estado_version_anterior IS NULL OR estado_version_anterior IN ('borrador', 'enviada', 'reemplazada', 'aceptada', 'rechazada', 'anulada')) AND (estado_version_nuevo IS NULL OR estado_version_nuevo IN ('borrador', 'enviada', 'reemplazada', 'aceptada', 'rechazada', 'anulada'))),
    CONSTRAINT ck_historial_cotizacion_cambio_efectivo CHECK (numero_evento = 1 OR estado_anterior IS DISTINCT FROM estado_nuevo OR (version_cotizacion_id IS NOT NULL AND estado_version_anterior IS DISTINCT FROM estado_version_nuevo))
);
COMMENT ON TABLE comercial.historial_cotizacion IS 'Historial explícito e inmutable de comercial.cotizacion.id.';
COMMENT ON COLUMN comercial.historial_cotizacion.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comercial.historial_cotizacion.cotizacion_id IS 'Referencia a comercial.cotizacion.id.';
COMMENT ON COLUMN comercial.historial_cotizacion.numero_evento IS 'Ordinal por proceso para un orden inequívoco.';
COMMENT ON COLUMN comercial.historial_cotizacion.estado_anterior IS 'estado anterior';
COMMENT ON COLUMN comercial.historial_cotizacion.estado_nuevo IS 'estado nuevo';
COMMENT ON COLUMN comercial.historial_cotizacion.motivo IS 'motivo';
COMMENT ON COLUMN comercial.historial_cotizacion.correlacion_id IS 'Identificador de la operación autenticada.';
COMMENT ON COLUMN comercial.historial_cotizacion.ocurrido_en IS 'ocurrido en';
COMMENT ON COLUMN comercial.historial_cotizacion.actor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN comercial.historial_cotizacion.actor_sistema IS 'Proceso automático responsable cuando no hay iniciador humano.';
COMMENT ON COLUMN comercial.historial_cotizacion.version_cotizacion_id IS 'Referencia a comercial.version_cotizacion.id.';
COMMENT ON COLUMN comercial.historial_cotizacion.estado_version_anterior IS 'estado version anterior';
COMMENT ON COLUMN comercial.historial_cotizacion.estado_version_nuevo IS 'estado version nuevo';

-- Historial explícito e inmutable de comercial.factura.id.
CREATE TABLE comercial.historial_factura (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    factura_id bigint NOT NULL,
    numero_evento integer NOT NULL,
    estado_anterior text,
    estado_nuevo text NOT NULL,
    motivo text NOT NULL,
    correlacion_id uuid NOT NULL,
    ocurrido_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actor_persona_id bigint,
    actor_sistema text,
    CONSTRAINT pk_historial_factura PRIMARY KEY (id),
    CONSTRAINT uq_historial_factura_factura_id_numero_evento UNIQUE (factura_id, numero_evento),
    CONSTRAINT ck_historial_factura_textos CHECK ((btrim(estado_anterior) <> '') AND (btrim(estado_nuevo) <> '') AND (btrim(motivo) <> '') AND (btrim(actor_sistema) <> '')),
    CONSTRAINT ck_historial_factura_fechas_finitas CHECK (isfinite(ocurrido_en)),
    CONSTRAINT ck_historial_factura_actor CHECK (num_nonnulls(actor_persona_id, actor_sistema) = 1),
    CONSTRAINT ck_historial_factura_ordinal CHECK (numero_evento > 0 AND ((numero_evento = 1 AND estado_anterior IS NULL) OR (numero_evento > 1 AND estado_anterior IS NOT NULL))),
    CONSTRAINT ck_historial_factura_estados CHECK (estado_nuevo IN ('borrador', 'emitida', 'anulada') AND (estado_anterior IS NULL OR estado_anterior IN ('borrador', 'emitida', 'anulada'))),
    CONSTRAINT ck_historial_factura_cambio_efectivo CHECK (numero_evento = 1 OR estado_anterior IS DISTINCT FROM estado_nuevo)
);
COMMENT ON TABLE comercial.historial_factura IS 'Historial explícito e inmutable de comercial.factura.id.';
COMMENT ON COLUMN comercial.historial_factura.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comercial.historial_factura.factura_id IS 'Referencia a comercial.factura.id.';
COMMENT ON COLUMN comercial.historial_factura.numero_evento IS 'Ordinal por proceso para un orden inequívoco.';
COMMENT ON COLUMN comercial.historial_factura.estado_anterior IS 'estado anterior';
COMMENT ON COLUMN comercial.historial_factura.estado_nuevo IS 'estado nuevo';
COMMENT ON COLUMN comercial.historial_factura.motivo IS 'motivo';
COMMENT ON COLUMN comercial.historial_factura.correlacion_id IS 'Identificador de la operación autenticada.';
COMMENT ON COLUMN comercial.historial_factura.ocurrido_en IS 'ocurrido en';
COMMENT ON COLUMN comercial.historial_factura.actor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN comercial.historial_factura.actor_sistema IS 'Proceso automático responsable cuando no hay iniciador humano.';

-- Historial explícito e inmutable de comercial.pedido.id.
CREATE TABLE comercial.historial_pedido (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    pedido_id bigint NOT NULL,
    numero_evento integer NOT NULL,
    estado_anterior text,
    estado_nuevo text NOT NULL,
    motivo text NOT NULL,
    correlacion_id uuid NOT NULL,
    ocurrido_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actor_persona_id bigint,
    actor_sistema text,
    CONSTRAINT pk_historial_pedido PRIMARY KEY (id),
    CONSTRAINT uq_historial_pedido_pedido_id_numero_evento UNIQUE (pedido_id, numero_evento),
    CONSTRAINT ck_historial_pedido_textos CHECK ((btrim(estado_anterior) <> '') AND (btrim(estado_nuevo) <> '') AND (btrim(motivo) <> '') AND (btrim(actor_sistema) <> '')),
    CONSTRAINT ck_historial_pedido_fechas_finitas CHECK (isfinite(ocurrido_en)),
    CONSTRAINT ck_historial_pedido_actor CHECK (num_nonnulls(actor_persona_id, actor_sistema) = 1),
    CONSTRAINT ck_historial_pedido_ordinal CHECK (numero_evento > 0 AND ((numero_evento = 1 AND estado_anterior IS NULL) OR (numero_evento > 1 AND estado_anterior IS NOT NULL))),
    CONSTRAINT ck_historial_pedido_estados CHECK (estado_nuevo IN ('borrador', 'confirmado', 'en_preparacion', 'completado', 'cancelado') AND (estado_anterior IS NULL OR estado_anterior IN ('borrador', 'confirmado', 'en_preparacion', 'completado', 'cancelado'))),
    CONSTRAINT ck_historial_pedido_cambio_efectivo CHECK (numero_evento = 1 OR estado_anterior IS DISTINCT FROM estado_nuevo)
);
COMMENT ON TABLE comercial.historial_pedido IS 'Historial explícito e inmutable de comercial.pedido.id.';
COMMENT ON COLUMN comercial.historial_pedido.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comercial.historial_pedido.pedido_id IS 'Referencia a comercial.pedido.id.';
COMMENT ON COLUMN comercial.historial_pedido.numero_evento IS 'Ordinal por proceso para un orden inequívoco.';
COMMENT ON COLUMN comercial.historial_pedido.estado_anterior IS 'estado anterior';
COMMENT ON COLUMN comercial.historial_pedido.estado_nuevo IS 'estado nuevo';
COMMENT ON COLUMN comercial.historial_pedido.motivo IS 'motivo';
COMMENT ON COLUMN comercial.historial_pedido.correlacion_id IS 'Identificador de la operación autenticada.';
COMMENT ON COLUMN comercial.historial_pedido.ocurrido_en IS 'ocurrido en';
COMMENT ON COLUMN comercial.historial_pedido.actor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN comercial.historial_pedido.actor_sistema IS 'Proceso automático responsable cuando no hay iniciador humano.';

-- Historial explícito e inmutable de comercial.solicitud_cotizacion.id.
CREATE TABLE comercial.historial_solicitud_cotizacion (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    solicitud_cotizacion_id bigint NOT NULL,
    numero_evento integer NOT NULL,
    estado_anterior text,
    estado_nuevo text NOT NULL,
    motivo text NOT NULL,
    correlacion_id uuid NOT NULL,
    ocurrido_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actor_persona_id bigint,
    actor_sistema text,
    CONSTRAINT pk_historial_solicitud_cotizacion PRIMARY KEY (id),
    CONSTRAINT uq_historial_solicitud_cotizacion_solicitud_cotizaci_a8947d6bec UNIQUE (solicitud_cotizacion_id, numero_evento),
    CONSTRAINT ck_historial_solicitud_cotizacion_textos CHECK ((btrim(estado_anterior) <> '') AND (btrim(estado_nuevo) <> '') AND (btrim(motivo) <> '') AND (btrim(actor_sistema) <> '')),
    CONSTRAINT ck_historial_solicitud_cotizacion_fechas_finitas CHECK (isfinite(ocurrido_en)),
    CONSTRAINT ck_historial_solicitud_cotizacion_actor CHECK (num_nonnulls(actor_persona_id, actor_sistema) = 1),
    CONSTRAINT ck_historial_solicitud_cotizacion_ordinal CHECK (numero_evento > 0 AND ((numero_evento = 1 AND estado_anterior IS NULL) OR (numero_evento > 1 AND estado_anterior IS NOT NULL))),
    CONSTRAINT ck_historial_solicitud_cotizacion_estados CHECK (estado_nuevo IN ('recibida', 'en_evaluacion', 'atendida', 'rechazada', 'cancelada') AND (estado_anterior IS NULL OR estado_anterior IN ('recibida', 'en_evaluacion', 'atendida', 'rechazada', 'cancelada'))),
    CONSTRAINT ck_historial_solicitud_cotizacion_cambio_efectivo CHECK (numero_evento = 1 OR estado_anterior IS DISTINCT FROM estado_nuevo)
);
COMMENT ON TABLE comercial.historial_solicitud_cotizacion IS 'Historial explícito e inmutable de comercial.solicitud_cotizacion.id.';
COMMENT ON COLUMN comercial.historial_solicitud_cotizacion.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comercial.historial_solicitud_cotizacion.solicitud_cotizacion_id IS 'Referencia a comercial.solicitud_cotizacion.id.';
COMMENT ON COLUMN comercial.historial_solicitud_cotizacion.numero_evento IS 'Ordinal por proceso para un orden inequívoco.';
COMMENT ON COLUMN comercial.historial_solicitud_cotizacion.estado_anterior IS 'estado anterior';
COMMENT ON COLUMN comercial.historial_solicitud_cotizacion.estado_nuevo IS 'estado nuevo';
COMMENT ON COLUMN comercial.historial_solicitud_cotizacion.motivo IS 'motivo';
COMMENT ON COLUMN comercial.historial_solicitud_cotizacion.correlacion_id IS 'Identificador de la operación autenticada.';
COMMENT ON COLUMN comercial.historial_solicitud_cotizacion.ocurrido_en IS 'ocurrido en';
COMMENT ON COLUMN comercial.historial_solicitud_cotizacion.actor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN comercial.historial_solicitud_cotizacion.actor_sistema IS 'Proceso automático responsable cuando no hay iniciador humano.';

-- Venta con condiciones históricas y cliente sin cuenta obligatoria.
CREATE TABLE comercial.pedido (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    numero bigint DEFAULT nextval('comercial.seq_pedido'::regclass) NOT NULL,
    cliente_id bigint NOT NULL,
    carrito_id bigint,
    version_cotizacion_id bigint,
    estado text DEFAULT 'borrador' NOT NULL,
    moneda text NOT NULL,
    receptor_nombre text NOT NULL,
    receptor_correo text,
    receptor_telefono text,
    confirmado_en timestamptz,
    completado_en timestamptz,
    cancelado_en timestamptz,
    motivo_cancelacion text,
    operacion_confirmacion_id uuid,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_pedido PRIMARY KEY (id),
    CONSTRAINT uq_pedido_numero UNIQUE (numero),
    CONSTRAINT uq_pedido_carrito_id UNIQUE (carrito_id),
    CONSTRAINT uq_pedido_operacion_confirmacion_id UNIQUE (operacion_confirmacion_id),
    CONSTRAINT ck_pedido_textos CHECK ((btrim(estado) <> '') AND (btrim(moneda) <> '') AND (btrim(receptor_nombre) <> '') AND (btrim(receptor_correo) <> '') AND (btrim(receptor_telefono) <> '') AND (btrim(motivo_cancelacion) <> '')),
    CONSTRAINT ck_pedido_fechas_finitas CHECK (isfinite(confirmado_en) AND isfinite(completado_en) AND isfinite(cancelado_en) AND isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_pedido_moneda CHECK ((moneda ~ '^[A-Z]{3}$')),
    CONSTRAINT ck_pedido_estado CHECK (estado IN ('borrador', 'confirmado', 'en_preparacion', 'completado', 'cancelado')),
    CONSTRAINT ck_pedido_numero_positivo CHECK (numero > 0),
    CONSTRAINT ck_pedido_contacto CHECK (num_nonnulls(receptor_correo, receptor_telefono) >= 1),
    CONSTRAINT ck_pedido_confirmacion_pareja CHECK (num_nonnulls(confirmado_en, operacion_confirmacion_id) IN (0, 2)),
    CONSTRAINT ck_pedido_confirmacion_estado CHECK ((estado = 'borrador' AND confirmado_en IS NULL) OR (estado IN ('confirmado', 'en_preparacion', 'completado') AND confirmado_en IS NOT NULL) OR estado = 'cancelado'),
    CONSTRAINT ck_pedido_completado_estado CHECK ((estado = 'completado' AND completado_en IS NOT NULL) OR (estado <> 'completado' AND completado_en IS NULL)),
    CONSTRAINT ck_pedido_cancelacion_estado CHECK ((estado = 'cancelado' AND cancelado_en IS NOT NULL AND motivo_cancelacion IS NOT NULL) OR (estado <> 'cancelado' AND cancelado_en IS NULL AND motivo_cancelacion IS NULL)),
    CONSTRAINT ck_pedido_confirmacion_fecha CHECK (confirmado_en IS NULL OR confirmado_en >= created_at),
    CONSTRAINT ck_pedido_completado_fecha CHECK (completado_en IS NULL OR (confirmado_en IS NOT NULL AND completado_en >= confirmado_en)),
    CONSTRAINT ck_pedido_cancelacion_fecha CHECK (cancelado_en IS NULL OR (cancelado_en >= created_at AND (confirmado_en IS NULL OR cancelado_en >= confirmado_en))),
    CONSTRAINT ck_pedido_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE comercial.pedido IS 'Venta con condiciones históricas y cliente sin cuenta obligatoria.';
COMMENT ON COLUMN comercial.pedido.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comercial.pedido.numero IS 'Consecutivo comercial.';
COMMENT ON COLUMN comercial.pedido.cliente_id IS 'Referencia a identidad.cliente.id.';
COMMENT ON COLUMN comercial.pedido.carrito_id IS 'Referencia a comercial.carrito.id.';
COMMENT ON COLUMN comercial.pedido.version_cotizacion_id IS 'Referencia a comercial.version_cotizacion.id.';
COMMENT ON COLUMN comercial.pedido.estado IS 'Estado: borrador, confirmado, en_preparacion, completado, cancelado.';
COMMENT ON COLUMN comercial.pedido.moneda IS 'Código monetario de tres letras mayúsculas; sin moneda predeterminada.';
COMMENT ON COLUMN comercial.pedido.receptor_nombre IS 'receptor nombre';
COMMENT ON COLUMN comercial.pedido.receptor_correo IS 'receptor correo';
COMMENT ON COLUMN comercial.pedido.receptor_telefono IS 'receptor telefono';
COMMENT ON COLUMN comercial.pedido.confirmado_en IS 'confirmado en';
COMMENT ON COLUMN comercial.pedido.completado_en IS 'completado en';
COMMENT ON COLUMN comercial.pedido.cancelado_en IS 'cancelado en';
COMMENT ON COLUMN comercial.pedido.motivo_cancelacion IS 'motivo cancelacion';
COMMENT ON COLUMN comercial.pedido.operacion_confirmacion_id IS 'operacion confirmacion id';
COMMENT ON COLUMN comercial.pedido.created_at IS 'Creación del registro.';
COMMENT ON COLUMN comercial.pedido.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Necesidad de cotización de persona sin cliente o usuario obligatorio.
CREATE TABLE comercial.solicitud_cotizacion (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    codigo text NOT NULL,
    persona_id bigint NOT NULL,
    necesidad text NOT NULL,
    contacto_nombre text NOT NULL,
    contacto_correo text,
    contacto_telefono text,
    estado text DEFAULT 'recibida' NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_solicitud_cotizacion PRIMARY KEY (id),
    CONSTRAINT uq_solicitud_cotizacion_codigo UNIQUE (codigo),
    CONSTRAINT ck_solicitud_cotizacion_textos CHECK ((btrim(codigo) <> '') AND (btrim(necesidad) <> '') AND (btrim(contacto_nombre) <> '') AND (btrim(contacto_correo) <> '') AND (btrim(contacto_telefono) <> '') AND (btrim(estado) <> '')),
    CONSTRAINT ck_solicitud_cotizacion_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_solicitud_cotizacion_estado CHECK (estado IN ('recibida', 'en_evaluacion', 'atendida', 'rechazada', 'cancelada')),
    CONSTRAINT ck_solicitud_cotizacion_contacto CHECK (num_nonnulls(contacto_correo, contacto_telefono) >= 1),
    CONSTRAINT ck_solicitud_cotizacion_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE comercial.solicitud_cotizacion IS 'Necesidad de cotización de persona sin cliente o usuario obligatorio.';
COMMENT ON COLUMN comercial.solicitud_cotizacion.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comercial.solicitud_cotizacion.codigo IS 'Código de negocio estable; unicidad independiente de la PK.';
COMMENT ON COLUMN comercial.solicitud_cotizacion.persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN comercial.solicitud_cotizacion.necesidad IS 'necesidad';
COMMENT ON COLUMN comercial.solicitud_cotizacion.contacto_nombre IS 'contacto nombre';
COMMENT ON COLUMN comercial.solicitud_cotizacion.contacto_correo IS 'contacto correo';
COMMENT ON COLUMN comercial.solicitud_cotizacion.contacto_telefono IS 'contacto telefono';
COMMENT ON COLUMN comercial.solicitud_cotizacion.estado IS 'Estado: recibida, en_evaluacion, atendida, rechazada, cancelada.';
COMMENT ON COLUMN comercial.solicitud_cotizacion.created_at IS 'Creación del registro.';
COMMENT ON COLUMN comercial.solicitud_cotizacion.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Oferta económica inmutable una vez enviada.
CREATE TABLE comercial.version_cotizacion (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    cotizacion_id bigint NOT NULL,
    numero_version integer NOT NULL,
    estado text DEFAULT 'borrador' NOT NULL,
    moneda text NOT NULL,
    condiciones text NOT NULL,
    destinatario_nombre text NOT NULL,
    destinatario_correo text,
    destinatario_telefono text,
    enviada_en timestamptz,
    vigente_hasta timestamptz NOT NULL,
    respondida_en timestamptz,
    respondida_por_persona_id bigint,
    evidencia_respuesta text,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_version_cotizacion PRIMARY KEY (id),
    CONSTRAINT uq_version_cotizacion_cotizacion_id_numero_version UNIQUE (cotizacion_id, numero_version),
    CONSTRAINT ck_version_cotizacion_textos CHECK ((btrim(estado) <> '') AND (btrim(moneda) <> '') AND (btrim(condiciones) <> '') AND (btrim(destinatario_nombre) <> '') AND (btrim(destinatario_correo) <> '') AND (btrim(destinatario_telefono) <> '') AND (btrim(evidencia_respuesta) <> '')),
    CONSTRAINT ck_version_cotizacion_fechas_finitas CHECK (isfinite(enviada_en) AND isfinite(vigente_hasta) AND isfinite(respondida_en) AND isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_version_cotizacion_moneda CHECK ((moneda ~ '^[A-Z]{3}$')),
    CONSTRAINT ck_version_cotizacion_estado CHECK (estado IN ('borrador', 'enviada', 'reemplazada', 'aceptada', 'rechazada', 'anulada')),
    CONSTRAINT ck_version_cotizacion_numero CHECK (numero_version > 0),
    CONSTRAINT ck_version_cotizacion_vigencia CHECK (vigente_hasta > created_at AND (enviada_en IS NULL OR vigente_hasta > enviada_en)),
    CONSTRAINT ck_version_cotizacion_envio_fecha CHECK (enviada_en IS NULL OR enviada_en >= created_at),
    CONSTRAINT ck_version_cotizacion_envio_estado CHECK ((estado = 'borrador' AND enviada_en IS NULL) OR (estado IN ('enviada', 'reemplazada', 'aceptada', 'rechazada') AND enviada_en IS NOT NULL) OR estado = 'anulada'),
    CONSTRAINT ck_version_cotizacion_contacto_enviada CHECK (enviada_en IS NULL OR num_nonnulls(destinatario_correo, destinatario_telefono) >= 1),
    CONSTRAINT ck_version_cotizacion_respuesta_estado CHECK ((estado IN ('aceptada', 'rechazada') AND respondida_en IS NOT NULL AND respondida_por_persona_id IS NOT NULL AND enviada_en IS NOT NULL AND evidencia_respuesta IS NOT NULL) OR (estado NOT IN ('aceptada', 'rechazada') AND respondida_en IS NULL AND respondida_por_persona_id IS NULL AND evidencia_respuesta IS NULL)),
    CONSTRAINT ck_version_cotizacion_respuesta_fecha CHECK (respondida_en IS NULL OR (enviada_en IS NOT NULL AND respondida_en >= enviada_en AND respondida_en <= vigente_hasta)),
    CONSTRAINT ck_version_cotizacion_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE comercial.version_cotizacion IS 'Oferta económica inmutable una vez enviada.';
COMMENT ON COLUMN comercial.version_cotizacion.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comercial.version_cotizacion.cotizacion_id IS 'Referencia a comercial.cotizacion.id.';
COMMENT ON COLUMN comercial.version_cotizacion.numero_version IS 'numero version';
COMMENT ON COLUMN comercial.version_cotizacion.estado IS 'Estado: borrador, enviada, reemplazada, aceptada, rechazada, anulada.';
COMMENT ON COLUMN comercial.version_cotizacion.moneda IS 'Código monetario de tres letras mayúsculas; sin moneda predeterminada.';
COMMENT ON COLUMN comercial.version_cotizacion.condiciones IS 'condiciones';
COMMENT ON COLUMN comercial.version_cotizacion.destinatario_nombre IS 'destinatario nombre';
COMMENT ON COLUMN comercial.version_cotizacion.destinatario_correo IS 'destinatario correo';
COMMENT ON COLUMN comercial.version_cotizacion.destinatario_telefono IS 'destinatario telefono';
COMMENT ON COLUMN comercial.version_cotizacion.enviada_en IS 'enviada en';
COMMENT ON COLUMN comercial.version_cotizacion.vigente_hasta IS 'vigente hasta';
COMMENT ON COLUMN comercial.version_cotizacion.respondida_en IS 'respondida en';
COMMENT ON COLUMN comercial.version_cotizacion.respondida_por_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN comercial.version_cotizacion.evidencia_respuesta IS 'evidencia respuesta';
COMMENT ON COLUMN comercial.version_cotizacion.created_at IS 'Creación del registro.';
COMMENT ON COLUMN comercial.version_cotizacion.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Participación temporal de un empleado en una orden.
CREATE TABLE servicios.asignacion_servicio (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    orden_servicio_id bigint NOT NULL,
    empleado_id bigint NOT NULL,
    funcion text NOT NULL,
    es_principal boolean DEFAULT false NOT NULL,
    inicia_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    termina_en timestamptz,
    actor_persona_id bigint,
    actor_sistema text,
    CONSTRAINT pk_asignacion_servicio PRIMARY KEY (id),
    CONSTRAINT ck_asignacion_servicio_textos CHECK ((btrim(funcion) <> '') AND (btrim(actor_sistema) <> '')),
    CONSTRAINT ck_asignacion_servicio_fechas_finitas CHECK (isfinite(inicia_en) AND isfinite(termina_en)),
    CONSTRAINT ck_asignacion_servicio_actor CHECK (num_nonnulls(actor_persona_id, actor_sistema) = 1),
    CONSTRAINT ck_asignacion_servicio_periodo CHECK (termina_en IS NULL OR termina_en > inicia_en)
);
COMMENT ON TABLE servicios.asignacion_servicio IS 'Participación temporal de un empleado en una orden.';
COMMENT ON COLUMN servicios.asignacion_servicio.id IS 'Identificador interno estable.';
COMMENT ON COLUMN servicios.asignacion_servicio.orden_servicio_id IS 'Referencia a servicios.orden_servicio.id.';
COMMENT ON COLUMN servicios.asignacion_servicio.empleado_id IS 'Referencia a identidad.empleado.id.';
COMMENT ON COLUMN servicios.asignacion_servicio.funcion IS 'funcion';
COMMENT ON COLUMN servicios.asignacion_servicio.es_principal IS 'es principal';
COMMENT ON COLUMN servicios.asignacion_servicio.inicia_en IS 'inicia en';
COMMENT ON COLUMN servicios.asignacion_servicio.termina_en IS 'termina en';
COMMENT ON COLUMN servicios.asignacion_servicio.actor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN servicios.asignacion_servicio.actor_sistema IS 'Proceso automático responsable cuando no hay iniciador humano.';

-- Valoración de un servicio propio finalizado.
CREATE TABLE servicios.calificacion_servicio (
    orden_servicio_id bigint NOT NULL,
    autor_persona_id bigint NOT NULL,
    puntuacion smallint NOT NULL,
    comentario text,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_calificacion_servicio PRIMARY KEY (orden_servicio_id),
    CONSTRAINT ck_calificacion_servicio_textos CHECK ((btrim(comentario) <> '')),
    CONSTRAINT ck_calificacion_servicio_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_calificacion_servicio_fechas_registro CHECK (updated_at >= created_at),
    CONSTRAINT ck_calificacion_servicio_puntuacion CHECK (puntuacion BETWEEN 1 AND 5)
);
COMMENT ON TABLE servicios.calificacion_servicio IS 'Valoración de un servicio propio finalizado.';
COMMENT ON COLUMN servicios.calificacion_servicio.orden_servicio_id IS 'Referencia a servicios.orden_servicio.id.';
COMMENT ON COLUMN servicios.calificacion_servicio.autor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN servicios.calificacion_servicio.puntuacion IS 'puntuacion';
COMMENT ON COLUMN servicios.calificacion_servicio.comentario IS 'comentario';
COMMENT ON COLUMN servicios.calificacion_servicio.created_at IS 'Creación del registro.';
COMMENT ON COLUMN servicios.calificacion_servicio.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Visita de una solicitud, incluso anterior a su orden.
CREATE TABLE servicios.cita_servicio (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    solicitud_servicio_id bigint NOT NULL,
    tecnico_id bigint,
    inicio timestamptz NOT NULL,
    fin timestamptz NOT NULL,
    estado text DEFAULT 'propuesta' NOT NULL,
    modalidad_atencion text NOT NULL,
    lugar text,
    motivo_cancelacion text,
    sustituye_cita_id bigint,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_cita_servicio PRIMARY KEY (id),
    CONSTRAINT uq_cita_servicio_sustituye_cita_id UNIQUE (sustituye_cita_id),
    CONSTRAINT ck_cita_servicio_textos CHECK ((btrim(estado) <> '') AND (btrim(modalidad_atencion) <> '') AND (btrim(lugar) <> '') AND (btrim(motivo_cancelacion) <> '')),
    CONSTRAINT ck_cita_servicio_fechas_finitas CHECK (isfinite(inicio) AND isfinite(fin) AND isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_cita_servicio_estado CHECK (estado IN ('propuesta', 'confirmada', 'realizada', 'cancelada')),
    CONSTRAINT ck_cita_servicio_fechas_registro CHECK (updated_at >= created_at),
    CONSTRAINT ck_cita_servicio_intervalo CHECK (fin > inicio),
    CONSTRAINT ck_cita_servicio_modalidad CHECK (modalidad_atencion IN ('presencial', 'remota')),
    CONSTRAINT ck_cita_servicio_tecnico CHECK (estado NOT IN ('confirmada', 'realizada') OR tecnico_id IS NOT NULL),
    CONSTRAINT ck_cita_servicio_lugar CHECK (modalidad_atencion <> 'presencial' OR (lugar IS NOT NULL AND btrim(lugar) <> '')),
    CONSTRAINT ck_cita_servicio_cancelacion CHECK (estado <> 'cancelada' OR (motivo_cancelacion IS NOT NULL AND btrim(motivo_cancelacion) <> '')),
    CONSTRAINT ck_cita_servicio_no_autosustitucion CHECK (sustituye_cita_id IS NULL OR sustituye_cita_id <> id)
);
COMMENT ON TABLE servicios.cita_servicio IS 'Visita de una solicitud, incluso anterior a su orden.';
COMMENT ON COLUMN servicios.cita_servicio.id IS 'Identificador interno estable.';
COMMENT ON COLUMN servicios.cita_servicio.solicitud_servicio_id IS 'Referencia a servicios.solicitud_servicio.id.';
COMMENT ON COLUMN servicios.cita_servicio.tecnico_id IS 'Referencia a identidad.empleado.id.';
COMMENT ON COLUMN servicios.cita_servicio.inicio IS 'inicio';
COMMENT ON COLUMN servicios.cita_servicio.fin IS 'fin';
COMMENT ON COLUMN servicios.cita_servicio.estado IS 'Estado: propuesta, confirmada, realizada, cancelada.';
COMMENT ON COLUMN servicios.cita_servicio.modalidad_atencion IS 'presencial o remota.';
COMMENT ON COLUMN servicios.cita_servicio.lugar IS 'lugar';
COMMENT ON COLUMN servicios.cita_servicio.motivo_cancelacion IS 'motivo cancelacion';
COMMENT ON COLUMN servicios.cita_servicio.sustituye_cita_id IS 'Referencia a servicios.cita_servicio.id.';
COMMENT ON COLUMN servicios.cita_servicio.created_at IS 'Creación del registro.';
COMMENT ON COLUMN servicios.cita_servicio.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Ventana concreta de disponibilidad de un empleado.
CREATE TABLE servicios.disponibilidad_tecnico (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    empleado_id bigint NOT NULL,
    inicio timestamptz NOT NULL,
    fin timestamptz NOT NULL,
    habilitada boolean DEFAULT true NOT NULL,
    observaciones text,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_disponibilidad_tecnico PRIMARY KEY (id),
    CONSTRAINT ck_disponibilidad_tecnico_textos CHECK ((btrim(observaciones) <> '')),
    CONSTRAINT ck_disponibilidad_tecnico_fechas_finitas CHECK (isfinite(inicio) AND isfinite(fin) AND isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_disponibilidad_tecnico_fechas_registro CHECK (updated_at >= created_at),
    CONSTRAINT ck_disponibilidad_tecnico_intervalo CHECK (fin > inicio)
);
COMMENT ON TABLE servicios.disponibilidad_tecnico IS 'Ventana concreta de disponibilidad de un empleado.';
COMMENT ON COLUMN servicios.disponibilidad_tecnico.id IS 'Identificador interno estable.';
COMMENT ON COLUMN servicios.disponibilidad_tecnico.empleado_id IS 'Referencia a identidad.empleado.id.';
COMMENT ON COLUMN servicios.disponibilidad_tecnico.inicio IS 'inicio';
COMMENT ON COLUMN servicios.disponibilidad_tecnico.fin IS 'fin';
COMMENT ON COLUMN servicios.disponibilidad_tecnico.habilitada IS 'habilitada';
COMMENT ON COLUMN servicios.disponibilidad_tecnico.observaciones IS 'observaciones';
COMMENT ON COLUMN servicios.disponibilidad_tecnico.created_at IS 'Creación del registro.';
COMMENT ON COLUMN servicios.disponibilidad_tecnico.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Equipo del cliente atendido; independiente del inventario de venta.
CREATE TABLE servicios.equipo_cliente (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    cliente_id bigint NOT NULL,
    tipo text NOT NULL,
    marca text,
    modelo text,
    numero_serie text,
    descripcion text NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_equipo_cliente PRIMARY KEY (id),
    CONSTRAINT ck_equipo_cliente_textos CHECK ((btrim(tipo) <> '') AND (btrim(marca) <> '') AND (btrim(modelo) <> '') AND (btrim(numero_serie) <> '') AND (btrim(descripcion) <> '')),
    CONSTRAINT ck_equipo_cliente_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_equipo_cliente_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE servicios.equipo_cliente IS 'Equipo del cliente atendido; independiente del inventario de venta.';
COMMENT ON COLUMN servicios.equipo_cliente.id IS 'Identificador interno estable.';
COMMENT ON COLUMN servicios.equipo_cliente.cliente_id IS 'Referencia a identidad.cliente.id.';
COMMENT ON COLUMN servicios.equipo_cliente.tipo IS 'tipo';
COMMENT ON COLUMN servicios.equipo_cliente.marca IS 'marca';
COMMENT ON COLUMN servicios.equipo_cliente.modelo IS 'modelo';
COMMENT ON COLUMN servicios.equipo_cliente.numero_serie IS 'numero serie';
COMMENT ON COLUMN servicios.equipo_cliente.descripcion IS 'descripcion';
COMMENT ON COLUMN servicios.equipo_cliente.activo IS 'activo';
COMMENT ON COLUMN servicios.equipo_cliente.created_at IS 'Creación del registro.';
COMMENT ON COLUMN servicios.equipo_cliente.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Historial explícito e inmutable de servicios.orden_servicio.id.
CREATE TABLE servicios.historial_servicio (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    orden_servicio_id bigint NOT NULL,
    numero_evento integer NOT NULL,
    estado_anterior text,
    estado_nuevo text NOT NULL,
    motivo text NOT NULL,
    correlacion_id uuid NOT NULL,
    ocurrido_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actor_persona_id bigint,
    actor_sistema text,
    CONSTRAINT pk_historial_servicio PRIMARY KEY (id),
    CONSTRAINT uq_historial_servicio_orden_servicio_id_numero_evento UNIQUE (orden_servicio_id, numero_evento),
    CONSTRAINT ck_historial_servicio_textos CHECK ((btrim(estado_anterior) <> '') AND (btrim(estado_nuevo) <> '') AND (btrim(motivo) <> '') AND (btrim(actor_sistema) <> '')),
    CONSTRAINT ck_historial_servicio_fechas_finitas CHECK (isfinite(ocurrido_en)),
    CONSTRAINT ck_historial_servicio_actor CHECK (num_nonnulls(actor_persona_id, actor_sistema) = 1),
    CONSTRAINT ck_historial_servicio_numero_evento CHECK (numero_evento > 0),
    CONSTRAINT ck_historial_servicio_evento_inicial CHECK ((numero_evento = 1 AND estado_anterior IS NULL) OR (numero_evento > 1 AND estado_anterior IS NOT NULL)),
    CONSTRAINT ck_historial_servicio_estado_nuevo CHECK (estado_nuevo IN ('pendiente_asignacion', 'asignada', 'en_ejecucion', 'pausada', 'finalizada', 'cancelada')),
    CONSTRAINT ck_historial_servicio_estado_anterior CHECK (estado_anterior IS NULL OR estado_anterior IN ('pendiente_asignacion', 'asignada', 'en_ejecucion', 'pausada', 'finalizada', 'cancelada')),
    CONSTRAINT ck_historial_servicio_transicion_efectiva CHECK (estado_anterior IS DISTINCT FROM estado_nuevo)
);
COMMENT ON TABLE servicios.historial_servicio IS 'Historial explícito e inmutable de servicios.orden_servicio.id.';
COMMENT ON COLUMN servicios.historial_servicio.id IS 'Identificador interno estable.';
COMMENT ON COLUMN servicios.historial_servicio.orden_servicio_id IS 'Referencia a servicios.orden_servicio.id.';
COMMENT ON COLUMN servicios.historial_servicio.numero_evento IS 'Ordinal por proceso para un orden inequívoco.';
COMMENT ON COLUMN servicios.historial_servicio.estado_anterior IS 'estado anterior';
COMMENT ON COLUMN servicios.historial_servicio.estado_nuevo IS 'estado nuevo';
COMMENT ON COLUMN servicios.historial_servicio.motivo IS 'motivo';
COMMENT ON COLUMN servicios.historial_servicio.correlacion_id IS 'Identificador de la operación autenticada.';
COMMENT ON COLUMN servicios.historial_servicio.ocurrido_en IS 'ocurrido en';
COMMENT ON COLUMN servicios.historial_servicio.actor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN servicios.historial_servicio.actor_sistema IS 'Proceso automático responsable cuando no hay iniciador humano.';

-- Historial explícito e inmutable de servicios.solicitud_servicio.id.
CREATE TABLE servicios.historial_solicitud_servicio (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    solicitud_servicio_id bigint NOT NULL,
    numero_evento integer NOT NULL,
    estado_anterior text,
    estado_nuevo text NOT NULL,
    motivo text NOT NULL,
    correlacion_id uuid NOT NULL,
    ocurrido_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actor_persona_id bigint,
    actor_sistema text,
    CONSTRAINT pk_historial_solicitud_servicio PRIMARY KEY (id),
    CONSTRAINT uq_historial_solicitud_servicio_solicitud_servicio_i_597f0c8b11 UNIQUE (solicitud_servicio_id, numero_evento),
    CONSTRAINT ck_historial_solicitud_servicio_textos CHECK ((btrim(estado_anterior) <> '') AND (btrim(estado_nuevo) <> '') AND (btrim(motivo) <> '') AND (btrim(actor_sistema) <> '')),
    CONSTRAINT ck_historial_solicitud_servicio_fechas_finitas CHECK (isfinite(ocurrido_en)),
    CONSTRAINT ck_historial_solicitud_servicio_actor CHECK (num_nonnulls(actor_persona_id, actor_sistema) = 1),
    CONSTRAINT ck_hist_sol_servicio_numero_evento CHECK (numero_evento > 0),
    CONSTRAINT ck_hist_sol_servicio_evento_inicial CHECK ((numero_evento = 1 AND estado_anterior IS NULL) OR (numero_evento > 1 AND estado_anterior IS NOT NULL)),
    CONSTRAINT ck_hist_sol_servicio_estado_nuevo CHECK (estado_nuevo IN ('recibida', 'en_evaluacion', 'aceptada', 'rechazada', 'cancelada')),
    CONSTRAINT ck_hist_sol_servicio_estado_anterior CHECK (estado_anterior IS NULL OR estado_anterior IN ('recibida', 'en_evaluacion', 'aceptada', 'rechazada', 'cancelada')),
    CONSTRAINT ck_hist_sol_servicio_transicion_efectiva CHECK (estado_anterior IS DISTINCT FROM estado_nuevo)
);
COMMENT ON TABLE servicios.historial_solicitud_servicio IS 'Historial explícito e inmutable de servicios.solicitud_servicio.id.';
COMMENT ON COLUMN servicios.historial_solicitud_servicio.id IS 'Identificador interno estable.';
COMMENT ON COLUMN servicios.historial_solicitud_servicio.solicitud_servicio_id IS 'Referencia a servicios.solicitud_servicio.id.';
COMMENT ON COLUMN servicios.historial_solicitud_servicio.numero_evento IS 'Ordinal por proceso para un orden inequívoco.';
COMMENT ON COLUMN servicios.historial_solicitud_servicio.estado_anterior IS 'estado anterior';
COMMENT ON COLUMN servicios.historial_solicitud_servicio.estado_nuevo IS 'estado nuevo';
COMMENT ON COLUMN servicios.historial_solicitud_servicio.motivo IS 'motivo';
COMMENT ON COLUMN servicios.historial_solicitud_servicio.correlacion_id IS 'Identificador de la operación autenticada.';
COMMENT ON COLUMN servicios.historial_solicitud_servicio.ocurrido_en IS 'ocurrido en';
COMMENT ON COLUMN servicios.historial_solicitud_servicio.actor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN servicios.historial_solicitud_servicio.actor_sistema IS 'Proceso automático responsable cuando no hay iniciador humano.';

-- Datos exclusivos del mantenimiento.
CREATE TABLE servicios.mantenimiento (
    orden_servicio_id bigint NOT NULL,
    tipo_mantenimiento text NOT NULL,
    actividades_realizadas text,
    hallazgos text,
    recomendaciones text,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_mantenimiento PRIMARY KEY (orden_servicio_id),
    CONSTRAINT ck_mantenimiento_textos CHECK ((btrim(tipo_mantenimiento) <> '') AND (btrim(actividades_realizadas) <> '') AND (btrim(hallazgos) <> '') AND (btrim(recomendaciones) <> '')),
    CONSTRAINT ck_mantenimiento_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_mantenimiento_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE servicios.mantenimiento IS 'Datos exclusivos del mantenimiento.';
COMMENT ON COLUMN servicios.mantenimiento.orden_servicio_id IS 'Referencia a servicios.orden_servicio.id.';
COMMENT ON COLUMN servicios.mantenimiento.tipo_mantenimiento IS 'tipo mantenimiento';
COMMENT ON COLUMN servicios.mantenimiento.actividades_realizadas IS 'actividades realizadas';
COMMENT ON COLUMN servicios.mantenimiento.hallazgos IS 'hallazgos';
COMMENT ON COLUMN servicios.mantenimiento.recomendaciones IS 'recomendaciones';
COMMENT ON COLUMN servicios.mantenimiento.created_at IS 'Creación del registro.';
COMMENT ON COLUMN servicios.mantenimiento.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Trabajo autorizado procedente de una solicitud.
CREATE TABLE servicios.orden_servicio (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    codigo text NOT NULL,
    solicitud_servicio_id bigint NOT NULL,
    estado text DEFAULT 'pendiente_asignacion' NOT NULL,
    iniciada_en timestamptz,
    finalizada_en timestamptz,
    resumen_trabajo text,
    observaciones_cierre text,
    version_cotizacion_id bigint,
    importe_base_autorizado numeric(18,2),
    tasa_impuesto_autorizada numeric(9,6),
    moneda text,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_orden_servicio PRIMARY KEY (id),
    CONSTRAINT uq_orden_servicio_codigo UNIQUE (codigo),
    CONSTRAINT uq_orden_servicio_solicitud_servicio_id UNIQUE (solicitud_servicio_id),
    CONSTRAINT ck_orden_servicio_textos CHECK ((btrim(codigo) <> '') AND (btrim(estado) <> '') AND (btrim(resumen_trabajo) <> '') AND (btrim(observaciones_cierre) <> '') AND (btrim(moneda) <> '')),
    CONSTRAINT ck_orden_servicio_numericos CHECK ((importe_base_autorizado <> 'NaN'::numeric) AND (tasa_impuesto_autorizada <> 'NaN'::numeric)),
    CONSTRAINT ck_orden_servicio_fechas_finitas CHECK (isfinite(iniciada_en) AND isfinite(finalizada_en) AND isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_orden_servicio_moneda CHECK ((moneda ~ '^[A-Z]{3}$')),
    CONSTRAINT ck_orden_servicio_estado CHECK (estado IN ('pendiente_asignacion', 'asignada', 'en_ejecucion', 'pausada', 'finalizada', 'cancelada')),
    CONSTRAINT ck_orden_servicio_fechas_registro CHECK (updated_at >= created_at),
    CONSTRAINT ck_orden_servicio_inicio_por_estado CHECK (estado NOT IN ('en_ejecucion', 'pausada', 'finalizada') OR iniciada_en IS NOT NULL),
    CONSTRAINT ck_orden_servicio_cierre_por_estado CHECK (estado <> 'finalizada' OR (finalizada_en IS NOT NULL AND resumen_trabajo IS NOT NULL AND btrim(resumen_trabajo) <> '')),
    CONSTRAINT ck_orden_servicio_cronologia_real CHECK (finalizada_en IS NULL OR (iniciada_en IS NOT NULL AND finalizada_en >= iniciada_en)),
    CONSTRAINT ck_orden_servicio_autorizacion_economica CHECK ((version_cotizacion_id IS NOT NULL AND num_nonnulls(importe_base_autorizado, tasa_impuesto_autorizada, moneda) = 0) OR (version_cotizacion_id IS NULL AND num_nonnulls(importe_base_autorizado, tasa_impuesto_autorizada, moneda) = 3)),
    CONSTRAINT ck_orden_servicio_importe_autorizado CHECK (importe_base_autorizado IS NULL OR importe_base_autorizado >= 0),
    CONSTRAINT ck_orden_servicio_tasa_autorizada CHECK (tasa_impuesto_autorizada IS NULL OR tasa_impuesto_autorizada BETWEEN 0 AND 1)
);
COMMENT ON TABLE servicios.orden_servicio IS 'Trabajo autorizado procedente de una solicitud.';
COMMENT ON COLUMN servicios.orden_servicio.id IS 'Identificador interno estable.';
COMMENT ON COLUMN servicios.orden_servicio.codigo IS 'Código de negocio estable; unicidad independiente de la PK.';
COMMENT ON COLUMN servicios.orden_servicio.solicitud_servicio_id IS 'Referencia a servicios.solicitud_servicio.id.';
COMMENT ON COLUMN servicios.orden_servicio.estado IS 'Estado: pendiente_asignacion, asignada, en_ejecucion, pausada, finalizada, cancelada.';
COMMENT ON COLUMN servicios.orden_servicio.iniciada_en IS 'iniciada en';
COMMENT ON COLUMN servicios.orden_servicio.finalizada_en IS 'finalizada en';
COMMENT ON COLUMN servicios.orden_servicio.resumen_trabajo IS 'resumen trabajo';
COMMENT ON COLUMN servicios.orden_servicio.observaciones_cierre IS 'observaciones cierre';
COMMENT ON COLUMN servicios.orden_servicio.version_cotizacion_id IS 'Referencia a comercial.version_cotizacion.id.';
COMMENT ON COLUMN servicios.orden_servicio.importe_base_autorizado IS 'Techo neto para facturación directa, cuando no hay cotización.';
COMMENT ON COLUMN servicios.orden_servicio.tasa_impuesto_autorizada IS 'Tasa fraccional única de la autorización directa.';
COMMENT ON COLUMN servicios.orden_servicio.moneda IS 'Código monetario de tres letras mayúsculas; sin moneda predeterminada.';
COMMENT ON COLUMN servicios.orden_servicio.created_at IS 'Creación del registro.';
COMMENT ON COLUMN servicios.orden_servicio.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Datos exclusivos de la reparación.
CREATE TABLE servicios.reparacion (
    orden_servicio_id bigint NOT NULL,
    diagnostico text,
    falla_determinada text,
    solucion text,
    resultado_pruebas text,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_reparacion PRIMARY KEY (orden_servicio_id),
    CONSTRAINT ck_reparacion_textos CHECK ((btrim(diagnostico) <> '') AND (btrim(falla_determinada) <> '') AND (btrim(solucion) <> '') AND (btrim(resultado_pruebas) <> '')),
    CONSTRAINT ck_reparacion_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_reparacion_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE servicios.reparacion IS 'Datos exclusivos de la reparación.';
COMMENT ON COLUMN servicios.reparacion.orden_servicio_id IS 'Referencia a servicios.orden_servicio.id.';
COMMENT ON COLUMN servicios.reparacion.diagnostico IS 'diagnostico';
COMMENT ON COLUMN servicios.reparacion.falla_determinada IS 'falla determinada';
COMMENT ON COLUMN servicios.reparacion.solucion IS 'solucion';
COMMENT ON COLUMN servicios.reparacion.resultado_pruebas IS 'resultado pruebas';
COMMENT ON COLUMN servicios.reparacion.created_at IS 'Creación del registro.';
COMMENT ON COLUMN servicios.reparacion.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Oferta pública de reparación o mantenimiento.
CREATE TABLE servicios.servicio_ofrecido (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    codigo text NOT NULL,
    nombre text NOT NULL,
    descripcion text NOT NULL,
    modalidad text NOT NULL,
    duracion_estimada_min integer,
    precio_referencia numeric(18,2),
    moneda text,
    publicado boolean DEFAULT false NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_servicio_ofrecido PRIMARY KEY (id),
    CONSTRAINT uq_servicio_ofrecido_codigo UNIQUE (codigo),
    CONSTRAINT ck_servicio_ofrecido_textos CHECK ((btrim(codigo) <> '') AND (btrim(nombre) <> '') AND (btrim(descripcion) <> '') AND (btrim(modalidad) <> '') AND (btrim(moneda) <> '')),
    CONSTRAINT ck_servicio_ofrecido_numericos CHECK ((precio_referencia <> 'NaN'::numeric)),
    CONSTRAINT ck_servicio_ofrecido_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_servicio_ofrecido_moneda CHECK ((moneda ~ '^[A-Z]{3}$')),
    CONSTRAINT ck_servicio_ofrecido_fechas_registro CHECK (updated_at >= created_at),
    CONSTRAINT ck_servicio_ofrecido_modalidad CHECK (modalidad IN ('reparacion', 'mantenimiento')),
    CONSTRAINT ck_servicio_ofrecido_duracion CHECK (duracion_estimada_min IS NULL OR duracion_estimada_min > 0),
    CONSTRAINT ck_servicio_ofrecido_precio CHECK (precio_referencia IS NULL OR precio_referencia >= 0),
    CONSTRAINT ck_servicio_ofrecido_precio_moneda CHECK (num_nonnulls(precio_referencia, moneda) IN (0, 2))
);
COMMENT ON TABLE servicios.servicio_ofrecido IS 'Oferta pública de reparación o mantenimiento.';
COMMENT ON COLUMN servicios.servicio_ofrecido.id IS 'Identificador interno estable.';
COMMENT ON COLUMN servicios.servicio_ofrecido.codigo IS 'Código de negocio estable; unicidad independiente de la PK.';
COMMENT ON COLUMN servicios.servicio_ofrecido.nombre IS 'nombre';
COMMENT ON COLUMN servicios.servicio_ofrecido.descripcion IS 'descripcion';
COMMENT ON COLUMN servicios.servicio_ofrecido.modalidad IS 'modalidad';
COMMENT ON COLUMN servicios.servicio_ofrecido.duracion_estimada_min IS 'duracion estimada min';
COMMENT ON COLUMN servicios.servicio_ofrecido.precio_referencia IS 'precio referencia';
COMMENT ON COLUMN servicios.servicio_ofrecido.moneda IS 'Código monetario de tres letras mayúsculas; sin moneda predeterminada.';
COMMENT ON COLUMN servicios.servicio_ofrecido.publicado IS 'publicado';
COMMENT ON COLUMN servicios.servicio_ofrecido.created_at IS 'Creación del registro.';
COMMENT ON COLUMN servicios.servicio_ofrecido.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Recepción de una necesidad técnica, con o sin cuenta.
CREATE TABLE servicios.solicitud_servicio (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    codigo text NOT NULL,
    cliente_id bigint NOT NULL,
    servicio_ofrecido_id bigint NOT NULL,
    equipo_cliente_id bigint,
    necesidad text NOT NULL,
    alcance text,
    fecha_preferida timestamptz,
    estado text DEFAULT 'recibida' NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_solicitud_servicio PRIMARY KEY (id),
    CONSTRAINT uq_solicitud_servicio_codigo UNIQUE (codigo),
    CONSTRAINT ck_solicitud_servicio_textos CHECK ((btrim(codigo) <> '') AND (btrim(necesidad) <> '') AND (btrim(alcance) <> '') AND (btrim(estado) <> '')),
    CONSTRAINT ck_solicitud_servicio_fechas_finitas CHECK (isfinite(fecha_preferida) AND isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_solicitud_servicio_estado CHECK (estado IN ('recibida', 'en_evaluacion', 'aceptada', 'rechazada', 'cancelada')),
    CONSTRAINT ck_solicitud_servicio_fechas_registro CHECK (updated_at >= created_at)
);
COMMENT ON TABLE servicios.solicitud_servicio IS 'Recepción de una necesidad técnica, con o sin cuenta.';
COMMENT ON COLUMN servicios.solicitud_servicio.id IS 'Identificador interno estable.';
COMMENT ON COLUMN servicios.solicitud_servicio.codigo IS 'Código de negocio estable; unicidad independiente de la PK.';
COMMENT ON COLUMN servicios.solicitud_servicio.cliente_id IS 'Referencia a identidad.cliente.id.';
COMMENT ON COLUMN servicios.solicitud_servicio.servicio_ofrecido_id IS 'Referencia a servicios.servicio_ofrecido.id.';
COMMENT ON COLUMN servicios.solicitud_servicio.equipo_cliente_id IS 'Referencia a servicios.equipo_cliente.id.';
COMMENT ON COLUMN servicios.solicitud_servicio.necesidad IS 'necesidad';
COMMENT ON COLUMN servicios.solicitud_servicio.alcance IS 'alcance';
COMMENT ON COLUMN servicios.solicitud_servicio.fecha_preferida IS 'fecha preferida';
COMMENT ON COLUMN servicios.solicitud_servicio.estado IS 'Estado: recibida, en_evaluacion, aceptada, rechazada, cancelada.';
COMMENT ON COLUMN servicios.solicitud_servicio.created_at IS 'Creación del registro.';
COMMENT ON COLUMN servicios.solicitud_servicio.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Reporte histórico de progreso de una etapa.
CREATE TABLE proyectos.avance_proyecto (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    etapa_proyecto_id bigint NOT NULL,
    miembro_proyecto_id bigint NOT NULL,
    porcentaje numeric(5,2) NOT NULL,
    descripcion text NOT NULL,
    observaciones text,
    registrado_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_avance_proyecto PRIMARY KEY (id),
    CONSTRAINT ck_avance_proyecto_textos CHECK ((btrim(descripcion) <> '') AND (btrim(observaciones) <> '')),
    CONSTRAINT ck_avance_proyecto_numericos CHECK ((porcentaje <> 'NaN'::numeric)),
    CONSTRAINT ck_avance_proyecto_fechas_finitas CHECK (isfinite(registrado_en)),
    CONSTRAINT ck_avance_proyecto_porcentaje CHECK (porcentaje BETWEEN 0 AND 100)
);
COMMENT ON TABLE proyectos.avance_proyecto IS 'Reporte histórico de progreso de una etapa.';
COMMENT ON COLUMN proyectos.avance_proyecto.id IS 'Identificador interno estable.';
COMMENT ON COLUMN proyectos.avance_proyecto.etapa_proyecto_id IS 'Referencia a proyectos.etapa_proyecto.id.';
COMMENT ON COLUMN proyectos.avance_proyecto.miembro_proyecto_id IS 'Referencia a proyectos.miembro_proyecto.id.';
COMMENT ON COLUMN proyectos.avance_proyecto.porcentaje IS 'porcentaje';
COMMENT ON COLUMN proyectos.avance_proyecto.descripcion IS 'descripcion';
COMMENT ON COLUMN proyectos.avance_proyecto.observaciones IS 'observaciones';
COMMENT ON COLUMN proyectos.avance_proyecto.registrado_en IS 'registrado en';

-- Etapa ponderada del alcance aprobado.
CREATE TABLE proyectos.etapa_proyecto (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    proyecto_id bigint NOT NULL,
    nombre text NOT NULL,
    descripcion text NOT NULL,
    orden integer NOT NULL,
    peso numeric(9,4) NOT NULL,
    inicio_planificado date,
    fin_planificado date,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_etapa_proyecto PRIMARY KEY (id),
    CONSTRAINT uq_etapa_proyecto_proyecto_id_orden UNIQUE (proyecto_id, orden),
    CONSTRAINT ck_etapa_proyecto_textos CHECK ((btrim(nombre) <> '') AND (btrim(descripcion) <> '')),
    CONSTRAINT ck_etapa_proyecto_numericos CHECK ((peso <> 'NaN'::numeric)),
    CONSTRAINT ck_etapa_proyecto_fechas_finitas CHECK (isfinite(inicio_planificado) AND isfinite(fin_planificado) AND isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_etapa_proyecto_fechas_registro CHECK (updated_at >= created_at),
    CONSTRAINT ck_etapa_proyecto_orden CHECK (orden > 0),
    CONSTRAINT ck_etapa_proyecto_peso CHECK (peso > 0),
    CONSTRAINT ck_etapa_proyecto_fechas_planificadas CHECK (inicio_planificado IS NULL OR fin_planificado IS NULL OR fin_planificado >= inicio_planificado)
);
COMMENT ON TABLE proyectos.etapa_proyecto IS 'Etapa ponderada del alcance aprobado.';
COMMENT ON COLUMN proyectos.etapa_proyecto.id IS 'Identificador interno estable.';
COMMENT ON COLUMN proyectos.etapa_proyecto.proyecto_id IS 'Referencia a proyectos.proyecto.id.';
COMMENT ON COLUMN proyectos.etapa_proyecto.nombre IS 'nombre';
COMMENT ON COLUMN proyectos.etapa_proyecto.descripcion IS 'descripcion';
COMMENT ON COLUMN proyectos.etapa_proyecto.orden IS 'orden';
COMMENT ON COLUMN proyectos.etapa_proyecto.peso IS 'peso';
COMMENT ON COLUMN proyectos.etapa_proyecto.inicio_planificado IS 'inicio planificado';
COMMENT ON COLUMN proyectos.etapa_proyecto.fin_planificado IS 'fin planificado';
COMMENT ON COLUMN proyectos.etapa_proyecto.created_at IS 'Creación del registro.';
COMMENT ON COLUMN proyectos.etapa_proyecto.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Historial explícito e inmutable de proyectos.proyecto.id.
CREATE TABLE proyectos.historial_proyecto (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    proyecto_id bigint NOT NULL,
    numero_evento integer NOT NULL,
    estado_anterior text,
    estado_nuevo text NOT NULL,
    motivo text NOT NULL,
    correlacion_id uuid NOT NULL,
    ocurrido_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actor_persona_id bigint,
    actor_sistema text,
    CONSTRAINT pk_historial_proyecto PRIMARY KEY (id),
    CONSTRAINT uq_historial_proyecto_proyecto_id_numero_evento UNIQUE (proyecto_id, numero_evento),
    CONSTRAINT ck_historial_proyecto_textos CHECK ((btrim(estado_anterior) <> '') AND (btrim(estado_nuevo) <> '') AND (btrim(motivo) <> '') AND (btrim(actor_sistema) <> '')),
    CONSTRAINT ck_historial_proyecto_fechas_finitas CHECK (isfinite(ocurrido_en)),
    CONSTRAINT ck_historial_proyecto_actor CHECK (num_nonnulls(actor_persona_id, actor_sistema) = 1),
    CONSTRAINT ck_historial_proyecto_numero_evento CHECK (numero_evento > 0),
    CONSTRAINT ck_historial_proyecto_evento_inicial CHECK ((numero_evento = 1 AND estado_anterior IS NULL) OR (numero_evento > 1 AND estado_anterior IS NOT NULL)),
    CONSTRAINT ck_historial_proyecto_estado_nuevo CHECK (estado_nuevo IN ('planificado', 'en_ejecucion', 'suspendido', 'finalizado', 'cancelado')),
    CONSTRAINT ck_historial_proyecto_estado_anterior CHECK (estado_anterior IS NULL OR estado_anterior IN ('planificado', 'en_ejecucion', 'suspendido', 'finalizado', 'cancelado')),
    CONSTRAINT ck_historial_proyecto_transicion_efectiva CHECK (estado_anterior IS DISTINCT FROM estado_nuevo)
);
COMMENT ON TABLE proyectos.historial_proyecto IS 'Historial explícito e inmutable de proyectos.proyecto.id.';
COMMENT ON COLUMN proyectos.historial_proyecto.id IS 'Identificador interno estable.';
COMMENT ON COLUMN proyectos.historial_proyecto.proyecto_id IS 'Referencia a proyectos.proyecto.id.';
COMMENT ON COLUMN proyectos.historial_proyecto.numero_evento IS 'Ordinal por proceso para un orden inequívoco.';
COMMENT ON COLUMN proyectos.historial_proyecto.estado_anterior IS 'estado anterior';
COMMENT ON COLUMN proyectos.historial_proyecto.estado_nuevo IS 'estado nuevo';
COMMENT ON COLUMN proyectos.historial_proyecto.motivo IS 'motivo';
COMMENT ON COLUMN proyectos.historial_proyecto.correlacion_id IS 'Identificador de la operación autenticada.';
COMMENT ON COLUMN proyectos.historial_proyecto.ocurrido_en IS 'ocurrido en';
COMMENT ON COLUMN proyectos.historial_proyecto.actor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN proyectos.historial_proyecto.actor_sistema IS 'Proceso automático responsable cuando no hay iniciador humano.';

-- Historial explícito e inmutable de proyectos.solicitud_desarrollo.id.
CREATE TABLE proyectos.historial_solicitud_desarrollo (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    solicitud_desarrollo_id bigint NOT NULL,
    numero_evento integer NOT NULL,
    estado_anterior text,
    estado_nuevo text NOT NULL,
    motivo text NOT NULL,
    correlacion_id uuid NOT NULL,
    ocurrido_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actor_persona_id bigint,
    actor_sistema text,
    CONSTRAINT pk_historial_solicitud_desarrollo PRIMARY KEY (id),
    CONSTRAINT uq_historial_solicitud_desarrollo_solicitud_desarrol_74250cedef UNIQUE (solicitud_desarrollo_id, numero_evento),
    CONSTRAINT ck_historial_solicitud_desarrollo_textos CHECK ((btrim(estado_anterior) <> '') AND (btrim(estado_nuevo) <> '') AND (btrim(motivo) <> '') AND (btrim(actor_sistema) <> '')),
    CONSTRAINT ck_historial_solicitud_desarrollo_fechas_finitas CHECK (isfinite(ocurrido_en)),
    CONSTRAINT ck_historial_solicitud_desarrollo_actor CHECK (num_nonnulls(actor_persona_id, actor_sistema) = 1),
    CONSTRAINT ck_hist_sol_desarrollo_numero_evento CHECK (numero_evento > 0),
    CONSTRAINT ck_hist_sol_desarrollo_evento_inicial CHECK ((numero_evento = 1 AND estado_anterior IS NULL) OR (numero_evento > 1 AND estado_anterior IS NOT NULL)),
    CONSTRAINT ck_hist_sol_desarrollo_estado_nuevo CHECK (estado_nuevo IN ('recibida', 'en_evaluacion', 'aprobada', 'rechazada', 'cancelada')),
    CONSTRAINT ck_hist_sol_desarrollo_estado_anterior CHECK (estado_anterior IS NULL OR estado_anterior IN ('recibida', 'en_evaluacion', 'aprobada', 'rechazada', 'cancelada')),
    CONSTRAINT ck_hist_sol_desarrollo_transicion_efectiva CHECK (estado_anterior IS DISTINCT FROM estado_nuevo)
);
COMMENT ON TABLE proyectos.historial_solicitud_desarrollo IS 'Historial explícito e inmutable de proyectos.solicitud_desarrollo.id.';
COMMENT ON COLUMN proyectos.historial_solicitud_desarrollo.id IS 'Identificador interno estable.';
COMMENT ON COLUMN proyectos.historial_solicitud_desarrollo.solicitud_desarrollo_id IS 'Referencia a proyectos.solicitud_desarrollo.id.';
COMMENT ON COLUMN proyectos.historial_solicitud_desarrollo.numero_evento IS 'Ordinal por proceso para un orden inequívoco.';
COMMENT ON COLUMN proyectos.historial_solicitud_desarrollo.estado_anterior IS 'estado anterior';
COMMENT ON COLUMN proyectos.historial_solicitud_desarrollo.estado_nuevo IS 'estado nuevo';
COMMENT ON COLUMN proyectos.historial_solicitud_desarrollo.motivo IS 'motivo';
COMMENT ON COLUMN proyectos.historial_solicitud_desarrollo.correlacion_id IS 'Identificador de la operación autenticada.';
COMMENT ON COLUMN proyectos.historial_solicitud_desarrollo.ocurrido_en IS 'ocurrido en';
COMMENT ON COLUMN proyectos.historial_solicitud_desarrollo.actor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN proyectos.historial_solicitud_desarrollo.actor_sistema IS 'Proceso automático responsable cuando no hay iniciador humano.';

-- Membresía temporal de empleado en proyecto.
CREATE TABLE proyectos.miembro_proyecto (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    proyecto_id bigint NOT NULL,
    empleado_id bigint NOT NULL,
    funcion text NOT NULL,
    es_principal boolean DEFAULT false NOT NULL,
    inicia_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    termina_en timestamptz,
    actor_persona_id bigint,
    actor_sistema text,
    CONSTRAINT pk_miembro_proyecto PRIMARY KEY (id),
    CONSTRAINT ck_miembro_proyecto_textos CHECK ((btrim(funcion) <> '') AND (btrim(actor_sistema) <> '')),
    CONSTRAINT ck_miembro_proyecto_fechas_finitas CHECK (isfinite(inicia_en) AND isfinite(termina_en)),
    CONSTRAINT ck_miembro_proyecto_actor CHECK (num_nonnulls(actor_persona_id, actor_sistema) = 1),
    CONSTRAINT ck_miembro_proyecto_periodo CHECK (termina_en IS NULL OR termina_en > inicia_en)
);
COMMENT ON TABLE proyectos.miembro_proyecto IS 'Membresía temporal de empleado en proyecto.';
COMMENT ON COLUMN proyectos.miembro_proyecto.id IS 'Identificador interno estable.';
COMMENT ON COLUMN proyectos.miembro_proyecto.proyecto_id IS 'Referencia a proyectos.proyecto.id.';
COMMENT ON COLUMN proyectos.miembro_proyecto.empleado_id IS 'Referencia a identidad.empleado.id.';
COMMENT ON COLUMN proyectos.miembro_proyecto.funcion IS 'funcion';
COMMENT ON COLUMN proyectos.miembro_proyecto.es_principal IS 'es principal';
COMMENT ON COLUMN proyectos.miembro_proyecto.inicia_en IS 'inicia en';
COMMENT ON COLUMN proyectos.miembro_proyecto.termina_en IS 'termina en';
COMMENT ON COLUMN proyectos.miembro_proyecto.actor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN proyectos.miembro_proyecto.actor_sistema IS 'Proceso automático responsable cuando no hay iniciador humano.';

-- Ejecución de una solicitud aprobada.
CREATE TABLE proyectos.proyecto (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    codigo text NOT NULL,
    solicitud_desarrollo_id bigint NOT NULL,
    nombre text NOT NULL,
    descripcion text NOT NULL,
    alcance_acordado text NOT NULL,
    estado text DEFAULT 'planificado' NOT NULL,
    inicio_planificado date,
    fin_planificado date,
    iniciado_en timestamptz,
    finalizado_en timestamptz,
    version_cotizacion_id bigint,
    importe_base_autorizado numeric(18,2),
    tasa_impuesto_autorizada numeric(9,6),
    moneda text,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_proyecto PRIMARY KEY (id),
    CONSTRAINT uq_proyecto_codigo UNIQUE (codigo),
    CONSTRAINT uq_proyecto_solicitud_desarrollo_id UNIQUE (solicitud_desarrollo_id),
    CONSTRAINT ck_proyecto_textos CHECK ((btrim(codigo) <> '') AND (btrim(nombre) <> '') AND (btrim(descripcion) <> '') AND (btrim(alcance_acordado) <> '') AND (btrim(estado) <> '') AND (btrim(moneda) <> '')),
    CONSTRAINT ck_proyecto_numericos CHECK ((importe_base_autorizado <> 'NaN'::numeric) AND (tasa_impuesto_autorizada <> 'NaN'::numeric)),
    CONSTRAINT ck_proyecto_fechas_finitas CHECK (isfinite(inicio_planificado) AND isfinite(fin_planificado) AND isfinite(iniciado_en) AND isfinite(finalizado_en) AND isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_proyecto_moneda CHECK ((moneda ~ '^[A-Z]{3}$')),
    CONSTRAINT ck_proyecto_estado CHECK (estado IN ('planificado', 'en_ejecucion', 'suspendido', 'finalizado', 'cancelado')),
    CONSTRAINT ck_proyecto_fechas_registro CHECK (updated_at >= created_at),
    CONSTRAINT ck_proyecto_inicio_por_estado CHECK (estado NOT IN ('en_ejecucion', 'suspendido', 'finalizado') OR iniciado_en IS NOT NULL),
    CONSTRAINT ck_proyecto_cierre_por_estado CHECK (estado <> 'finalizado' OR finalizado_en IS NOT NULL),
    CONSTRAINT ck_proyecto_fechas_planificadas CHECK (inicio_planificado IS NULL OR fin_planificado IS NULL OR fin_planificado >= inicio_planificado),
    CONSTRAINT ck_proyecto_cronologia_real CHECK (finalizado_en IS NULL OR (iniciado_en IS NOT NULL AND finalizado_en >= iniciado_en)),
    CONSTRAINT ck_proyecto_autorizacion_economica CHECK ((version_cotizacion_id IS NOT NULL AND num_nonnulls(importe_base_autorizado, tasa_impuesto_autorizada, moneda) = 0) OR (version_cotizacion_id IS NULL AND num_nonnulls(importe_base_autorizado, tasa_impuesto_autorizada, moneda) = 3)),
    CONSTRAINT ck_proyecto_importe_autorizado CHECK (importe_base_autorizado IS NULL OR importe_base_autorizado >= 0),
    CONSTRAINT ck_proyecto_tasa_autorizada CHECK (tasa_impuesto_autorizada IS NULL OR tasa_impuesto_autorizada BETWEEN 0 AND 1)
);
COMMENT ON TABLE proyectos.proyecto IS 'Ejecución de una solicitud aprobada.';
COMMENT ON COLUMN proyectos.proyecto.id IS 'Identificador interno estable.';
COMMENT ON COLUMN proyectos.proyecto.codigo IS 'Código de negocio estable; unicidad independiente de la PK.';
COMMENT ON COLUMN proyectos.proyecto.solicitud_desarrollo_id IS 'Referencia a proyectos.solicitud_desarrollo.id.';
COMMENT ON COLUMN proyectos.proyecto.nombre IS 'nombre';
COMMENT ON COLUMN proyectos.proyecto.descripcion IS 'descripcion';
COMMENT ON COLUMN proyectos.proyecto.alcance_acordado IS 'alcance acordado';
COMMENT ON COLUMN proyectos.proyecto.estado IS 'Estado: planificado, en_ejecucion, suspendido, finalizado, cancelado.';
COMMENT ON COLUMN proyectos.proyecto.inicio_planificado IS 'inicio planificado';
COMMENT ON COLUMN proyectos.proyecto.fin_planificado IS 'fin planificado';
COMMENT ON COLUMN proyectos.proyecto.iniciado_en IS 'iniciado en';
COMMENT ON COLUMN proyectos.proyecto.finalizado_en IS 'finalizado en';
COMMENT ON COLUMN proyectos.proyecto.version_cotizacion_id IS 'Referencia a comercial.version_cotizacion.id.';
COMMENT ON COLUMN proyectos.proyecto.importe_base_autorizado IS 'Techo neto para facturación directa, cuando no hay cotización.';
COMMENT ON COLUMN proyectos.proyecto.tasa_impuesto_autorizada IS 'Tasa fraccional única de la autorización directa.';
COMMENT ON COLUMN proyectos.proyecto.moneda IS 'Código monetario de tres letras mayúsculas; sin moneda predeterminada.';
COMMENT ON COLUMN proyectos.proyecto.created_at IS 'Creación del registro.';
COMMENT ON COLUMN proyectos.proyecto.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Necesidades de software de cliente con o sin cuenta.
CREATE TABLE proyectos.solicitud_desarrollo (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    codigo text NOT NULL,
    cliente_id bigint NOT NULL,
    necesidades text NOT NULL,
    objetivos text NOT NULL,
    alcance_deseado text NOT NULL,
    presupuesto_orientativo numeric(18,2),
    moneda_orientativa text,
    fecha_deseada date,
    estado text DEFAULT 'recibida' NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_solicitud_desarrollo PRIMARY KEY (id),
    CONSTRAINT uq_solicitud_desarrollo_codigo UNIQUE (codigo),
    CONSTRAINT ck_solicitud_desarrollo_textos CHECK ((btrim(codigo) <> '') AND (btrim(necesidades) <> '') AND (btrim(objetivos) <> '') AND (btrim(alcance_deseado) <> '') AND (btrim(moneda_orientativa) <> '') AND (btrim(estado) <> '')),
    CONSTRAINT ck_solicitud_desarrollo_numericos CHECK ((presupuesto_orientativo <> 'NaN'::numeric)),
    CONSTRAINT ck_solicitud_desarrollo_fechas_finitas CHECK (isfinite(fecha_deseada) AND isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_solicitud_desarrollo_moneda CHECK ((moneda_orientativa ~ '^[A-Z]{3}$')),
    CONSTRAINT ck_solicitud_desarrollo_estado CHECK (estado IN ('recibida', 'en_evaluacion', 'aprobada', 'rechazada', 'cancelada')),
    CONSTRAINT ck_solicitud_desarrollo_fechas_registro CHECK (updated_at >= created_at),
    CONSTRAINT ck_solicitud_desarrollo_presupuesto CHECK (presupuesto_orientativo IS NULL OR presupuesto_orientativo >= 0),
    CONSTRAINT ck_solicitud_desarrollo_presupuesto_moneda CHECK (num_nonnulls(presupuesto_orientativo, moneda_orientativa) IN (0, 2))
);
COMMENT ON TABLE proyectos.solicitud_desarrollo IS 'Necesidades de software de cliente con o sin cuenta.';
COMMENT ON COLUMN proyectos.solicitud_desarrollo.id IS 'Identificador interno estable.';
COMMENT ON COLUMN proyectos.solicitud_desarrollo.codigo IS 'Código de negocio estable; unicidad independiente de la PK.';
COMMENT ON COLUMN proyectos.solicitud_desarrollo.cliente_id IS 'Referencia a identidad.cliente.id.';
COMMENT ON COLUMN proyectos.solicitud_desarrollo.necesidades IS 'necesidades';
COMMENT ON COLUMN proyectos.solicitud_desarrollo.objetivos IS 'objetivos';
COMMENT ON COLUMN proyectos.solicitud_desarrollo.alcance_deseado IS 'alcance deseado';
COMMENT ON COLUMN proyectos.solicitud_desarrollo.presupuesto_orientativo IS 'presupuesto orientativo';
COMMENT ON COLUMN proyectos.solicitud_desarrollo.moneda_orientativa IS 'moneda orientativa';
COMMENT ON COLUMN proyectos.solicitud_desarrollo.fecha_deseada IS 'fecha deseada';
COMMENT ON COLUMN proyectos.solicitud_desarrollo.estado IS 'Estado: recibida, en_evaluacion, aprobada, rechazada, cancelada.';
COMMENT ON COLUMN proyectos.solicitud_desarrollo.created_at IS 'Creación del registro.';
COMMENT ON COLUMN proyectos.solicitud_desarrollo.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Un archivo asociado explícitamente a un mensaje o proceso.
CREATE TABLE comunicacion.adjunto (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    archivo_id bigint NOT NULL,
    mensaje_id bigint,
    pedido_id bigint,
    solicitud_servicio_id bigint,
    orden_servicio_id bigint,
    solicitud_cotizacion_id bigint,
    cotizacion_id bigint,
    solicitud_desarrollo_id bigint,
    proyecto_id bigint,
    factura_id bigint,
    descripcion text,
    visibilidad text DEFAULT 'compartido' NOT NULL,
    adjuntado_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_adjunto PRIMARY KEY (id),
    CONSTRAINT ck_adjunto_textos CHECK ((btrim(descripcion) <> '') AND (btrim(visibilidad) <> '')),
    CONSTRAINT ck_adjunto_fechas_finitas CHECK (isfinite(adjuntado_en)),
    CONSTRAINT ck_adjunto_contexto CHECK (num_nonnulls(pedido_id, solicitud_servicio_id, orden_servicio_id, solicitud_cotizacion_id, cotizacion_id, solicitud_desarrollo_id, proyecto_id, factura_id, mensaje_id) = 1),
    CONSTRAINT ck_adjunto_visibilidad CHECK (visibilidad IN ('compartido', 'interno')),
    CONSTRAINT ck_adjunto_mensaje_compartido CHECK (mensaje_id IS NULL OR visibilidad = 'compartido')
);
COMMENT ON TABLE comunicacion.adjunto IS 'Un archivo asociado explícitamente a un mensaje o proceso.';
COMMENT ON COLUMN comunicacion.adjunto.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comunicacion.adjunto.archivo_id IS 'Referencia a comunicacion.archivo.id.';
COMMENT ON COLUMN comunicacion.adjunto.mensaje_id IS 'Referencia a comunicacion.mensaje.id.';
COMMENT ON COLUMN comunicacion.adjunto.pedido_id IS 'Referencia a comercial.pedido.id.';
COMMENT ON COLUMN comunicacion.adjunto.solicitud_servicio_id IS 'Referencia a servicios.solicitud_servicio.id.';
COMMENT ON COLUMN comunicacion.adjunto.orden_servicio_id IS 'Referencia a servicios.orden_servicio.id.';
COMMENT ON COLUMN comunicacion.adjunto.solicitud_cotizacion_id IS 'Referencia a comercial.solicitud_cotizacion.id.';
COMMENT ON COLUMN comunicacion.adjunto.cotizacion_id IS 'Referencia a comercial.cotizacion.id.';
COMMENT ON COLUMN comunicacion.adjunto.solicitud_desarrollo_id IS 'Referencia a proyectos.solicitud_desarrollo.id.';
COMMENT ON COLUMN comunicacion.adjunto.proyecto_id IS 'Referencia a proyectos.proyecto.id.';
COMMENT ON COLUMN comunicacion.adjunto.factura_id IS 'Referencia a comercial.factura.id.';
COMMENT ON COLUMN comunicacion.adjunto.descripcion IS 'descripcion';
COMMENT ON COLUMN comunicacion.adjunto.visibilidad IS 'compartido o interno.';
COMMENT ON COLUMN comunicacion.adjunto.adjuntado_en IS 'adjuntado en';

-- Metadatos de objeto almacenado externamente.
CREATE TABLE comunicacion.archivo (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    nombre_original text NOT NULL,
    almacen text NOT NULL,
    clave_objeto text NOT NULL,
    tipo_contenido text NOT NULL,
    tamano_bytes bigint NOT NULL,
    sha256 bytea,
    estado text DEFAULT 'pendiente' NOT NULL,
    visibilidad text DEFAULT 'privado' NOT NULL,
    actor_persona_id bigint,
    actor_sistema text,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_archivo PRIMARY KEY (id),
    CONSTRAINT uq_archivo_almacen_clave_objeto UNIQUE (almacen, clave_objeto),
    CONSTRAINT ck_archivo_textos CHECK ((btrim(nombre_original) <> '') AND (btrim(almacen) <> '') AND (btrim(clave_objeto) <> '') AND (btrim(tipo_contenido) <> '') AND (btrim(estado) <> '') AND (btrim(visibilidad) <> '') AND (btrim(actor_sistema) <> '')),
    CONSTRAINT ck_archivo_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_archivo_estado CHECK (estado IN ('pendiente', 'validado', 'rechazado')),
    CONSTRAINT ck_archivo_actor CHECK (num_nonnulls(actor_persona_id, actor_sistema) = 1),
    CONSTRAINT ck_archivo_fechas_registro CHECK (updated_at >= created_at),
    CONSTRAINT ck_archivo_tamano CHECK (tamano_bytes >= 0),
    CONSTRAINT ck_archivo_huella CHECK (sha256 IS NULL OR octet_length(sha256) = 32),
    CONSTRAINT ck_archivo_visibilidad CHECK (visibilidad IN ('privado', 'publico'))
);
COMMENT ON TABLE comunicacion.archivo IS 'Metadatos de objeto almacenado externamente.';
COMMENT ON COLUMN comunicacion.archivo.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comunicacion.archivo.nombre_original IS 'nombre original';
COMMENT ON COLUMN comunicacion.archivo.almacen IS 'Identificador lógico del almacenamiento; sin credenciales.';
COMMENT ON COLUMN comunicacion.archivo.clave_objeto IS 'Clave estable; no una URL temporal firmada.';
COMMENT ON COLUMN comunicacion.archivo.tipo_contenido IS 'tipo contenido';
COMMENT ON COLUMN comunicacion.archivo.tamano_bytes IS 'tamano bytes';
COMMENT ON COLUMN comunicacion.archivo.sha256 IS 'Huella de integridad, no credencial.';
COMMENT ON COLUMN comunicacion.archivo.estado IS 'Estado: pendiente, validado, rechazado.';
COMMENT ON COLUMN comunicacion.archivo.visibilidad IS 'visibilidad';
COMMENT ON COLUMN comunicacion.archivo.actor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN comunicacion.archivo.actor_sistema IS 'Proceso automático responsable cuando no hay iniciador humano.';
COMMENT ON COLUMN comunicacion.archivo.created_at IS 'Creación del registro.';
COMMENT ON COLUMN comunicacion.archivo.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Conversación reutilizable de proceso o contacto general.
CREATE TABLE comunicacion.conversacion (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    asunto text NOT NULL,
    estado text DEFAULT 'abierta' NOT NULL,
    pedido_id bigint,
    solicitud_servicio_id bigint,
    orden_servicio_id bigint,
    solicitud_cotizacion_id bigint,
    cotizacion_id bigint,
    solicitud_desarrollo_id bigint,
    proyecto_id bigint,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_conversacion PRIMARY KEY (id),
    CONSTRAINT ck_conversacion_textos CHECK ((btrim(asunto) <> '') AND (btrim(estado) <> '')),
    CONSTRAINT ck_conversacion_fechas_finitas CHECK (isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_conversacion_estado CHECK (estado IN ('abierta', 'cerrada')),
    CONSTRAINT ck_conversacion_fechas_registro CHECK (updated_at >= created_at),
    CONSTRAINT ck_conversacion_contexto CHECK (num_nonnulls(pedido_id, solicitud_servicio_id, orden_servicio_id, solicitud_cotizacion_id, cotizacion_id, solicitud_desarrollo_id, proyecto_id) <= 1)
);
COMMENT ON TABLE comunicacion.conversacion IS 'Conversación reutilizable de proceso o contacto general.';
COMMENT ON COLUMN comunicacion.conversacion.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comunicacion.conversacion.asunto IS 'asunto';
COMMENT ON COLUMN comunicacion.conversacion.estado IS 'Estado: abierta, cerrada.';
COMMENT ON COLUMN comunicacion.conversacion.pedido_id IS 'Referencia a comercial.pedido.id.';
COMMENT ON COLUMN comunicacion.conversacion.solicitud_servicio_id IS 'Referencia a servicios.solicitud_servicio.id.';
COMMENT ON COLUMN comunicacion.conversacion.orden_servicio_id IS 'Referencia a servicios.orden_servicio.id.';
COMMENT ON COLUMN comunicacion.conversacion.solicitud_cotizacion_id IS 'Referencia a comercial.solicitud_cotizacion.id.';
COMMENT ON COLUMN comunicacion.conversacion.cotizacion_id IS 'Referencia a comercial.cotizacion.id.';
COMMENT ON COLUMN comunicacion.conversacion.solicitud_desarrollo_id IS 'Referencia a proyectos.solicitud_desarrollo.id.';
COMMENT ON COLUMN comunicacion.conversacion.proyecto_id IS 'Referencia a proyectos.proyecto.id.';
COMMENT ON COLUMN comunicacion.conversacion.created_at IS 'Creación del registro.';
COMMENT ON COLUMN comunicacion.conversacion.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Intento de entrega por un canal externo cuando se configure.
CREATE TABLE comunicacion.entrega_notificacion (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    notificacion_id bigint NOT NULL,
    canal text NOT NULL,
    destino text NOT NULL,
    numero_intento integer NOT NULL,
    idempotencia_id uuid NOT NULL,
    estado text DEFAULT 'pendiente' NOT NULL,
    proveedor text,
    referencia_proveedor text,
    iniciada_en timestamptz,
    finalizada_en timestamptz,
    entregada_en timestamptz,
    error text,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_entrega_notificacion PRIMARY KEY (id),
    CONSTRAINT uq_entrega_notificacion_idempotencia_id UNIQUE (idempotencia_id),
    CONSTRAINT uq_entrega_notificacion_notificacion_id_canal_numero_intento UNIQUE (notificacion_id, canal, numero_intento),
    CONSTRAINT ck_entrega_notificacion_textos CHECK ((btrim(canal) <> '') AND (btrim(destino) <> '') AND (btrim(estado) <> '') AND (btrim(proveedor) <> '') AND (btrim(referencia_proveedor) <> '') AND (btrim(error) <> '')),
    CONSTRAINT ck_entrega_notificacion_fechas_finitas CHECK (isfinite(iniciada_en) AND isfinite(finalizada_en) AND isfinite(entregada_en) AND isfinite(created_at) AND isfinite(updated_at)),
    CONSTRAINT ck_entrega_notificacion_estado CHECK (estado IN ('pendiente', 'enviando', 'enviada', 'entregada', 'fallida')),
    CONSTRAINT ck_entrega_notificacion_fechas_registro CHECK (updated_at >= created_at),
    CONSTRAINT ck_entrega_notificacion_intento CHECK (numero_intento > 0),
    CONSTRAINT ck_entrega_notificacion_fechas CHECK ((iniciada_en IS NULL OR iniciada_en >= created_at) AND (finalizada_en IS NULL OR (iniciada_en IS NOT NULL AND finalizada_en >= iniciada_en)) AND (entregada_en IS NULL OR (finalizada_en IS NOT NULL AND entregada_en >= finalizada_en))),
    CONSTRAINT ck_entrega_notificacion_estado_fechas CHECK ((estado = 'pendiente' AND iniciada_en IS NULL AND finalizada_en IS NULL AND entregada_en IS NULL AND error IS NULL) OR (estado = 'enviando' AND iniciada_en IS NOT NULL AND finalizada_en IS NULL AND entregada_en IS NULL AND error IS NULL) OR (estado = 'enviada' AND iniciada_en IS NOT NULL AND finalizada_en IS NOT NULL AND entregada_en IS NULL AND error IS NULL) OR (estado = 'entregada' AND iniciada_en IS NOT NULL AND finalizada_en IS NOT NULL AND entregada_en IS NOT NULL AND error IS NULL) OR (estado = 'fallida' AND iniciada_en IS NOT NULL AND finalizada_en IS NOT NULL AND entregada_en IS NULL AND error IS NOT NULL))
);
COMMENT ON TABLE comunicacion.entrega_notificacion IS 'Intento de entrega por un canal externo cuando se configure.';
COMMENT ON COLUMN comunicacion.entrega_notificacion.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comunicacion.entrega_notificacion.notificacion_id IS 'Referencia a comunicacion.notificacion.id.';
COMMENT ON COLUMN comunicacion.entrega_notificacion.canal IS 'canal';
COMMENT ON COLUMN comunicacion.entrega_notificacion.destino IS 'Destino histórico utilizado, no copia editable del perfil actual.';
COMMENT ON COLUMN comunicacion.entrega_notificacion.numero_intento IS 'numero intento';
COMMENT ON COLUMN comunicacion.entrega_notificacion.idempotencia_id IS 'Clave estable del intento.';
COMMENT ON COLUMN comunicacion.entrega_notificacion.estado IS 'Estado: pendiente, enviando, enviada, entregada, fallida.';
COMMENT ON COLUMN comunicacion.entrega_notificacion.proveedor IS 'proveedor';
COMMENT ON COLUMN comunicacion.entrega_notificacion.referencia_proveedor IS 'referencia proveedor';
COMMENT ON COLUMN comunicacion.entrega_notificacion.iniciada_en IS 'iniciada en';
COMMENT ON COLUMN comunicacion.entrega_notificacion.finalizada_en IS 'finalizada en';
COMMENT ON COLUMN comunicacion.entrega_notificacion.entregada_en IS 'Instante local de registro de confirmación de entrega, posterior al fin del intento; no timestamp remoto ni prueba de lectura.';
COMMENT ON COLUMN comunicacion.entrega_notificacion.error IS 'error';
COMMENT ON COLUMN comunicacion.entrega_notificacion.created_at IS 'Creación del registro.';
COMMENT ON COLUMN comunicacion.entrega_notificacion.updated_at IS 'Última modificación; se mantendrá con trigger.';

-- Primera lectura de un mensaje por participante.
CREATE TABLE comunicacion.lectura_mensaje (
    mensaje_id bigint NOT NULL,
    participante_id bigint NOT NULL,
    leido_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_lectura_mensaje PRIMARY KEY (mensaje_id, participante_id),
    CONSTRAINT ck_lectura_mensaje_fechas_finitas CHECK (isfinite(leido_en))
);
COMMENT ON TABLE comunicacion.lectura_mensaje IS 'Primera lectura de un mensaje por participante.';
COMMENT ON COLUMN comunicacion.lectura_mensaje.mensaje_id IS 'Referencia a comunicacion.mensaje.id.';
COMMENT ON COLUMN comunicacion.lectura_mensaje.participante_id IS 'Referencia a comunicacion.participante_conversacion.id.';
COMMENT ON COLUMN comunicacion.lectura_mensaje.leido_en IS 'leido en';

-- Mensaje cuya conversación deriva de su autor participante.
CREATE TABLE comunicacion.mensaje (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    autor_participante_id bigint NOT NULL,
    contenido text,
    enviado_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    editado_en timestamptz,
    retirado boolean DEFAULT false NOT NULL,
    motivo_retiro text,
    CONSTRAINT pk_mensaje PRIMARY KEY (id),
    CONSTRAINT ck_mensaje_textos CHECK ((btrim(contenido) <> '') AND (btrim(motivo_retiro) <> '')),
    CONSTRAINT ck_mensaje_fechas_finitas CHECK (isfinite(enviado_en) AND isfinite(editado_en)),
    CONSTRAINT ck_mensaje_edicion_fecha CHECK (editado_en IS NULL OR editado_en >= enviado_en),
    CONSTRAINT ck_mensaje_retiro_motivo CHECK (NOT retirado OR motivo_retiro IS NOT NULL)
);
COMMENT ON TABLE comunicacion.mensaje IS 'Mensaje cuya conversación deriva de su autor participante.';
COMMENT ON COLUMN comunicacion.mensaje.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comunicacion.mensaje.autor_participante_id IS 'Referencia a comunicacion.participante_conversacion.id.';
COMMENT ON COLUMN comunicacion.mensaje.contenido IS 'contenido';
COMMENT ON COLUMN comunicacion.mensaje.enviado_en IS 'enviado en';
COMMENT ON COLUMN comunicacion.mensaje.editado_en IS 'editado en';
COMMENT ON COLUMN comunicacion.mensaje.retirado IS 'retirado';
COMMENT ON COLUMN comunicacion.mensaje.motivo_retiro IS 'motivo retiro';

-- Bandeja propuesta para usuario registrado.
CREATE TABLE comunicacion.notificacion (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    destinatario_usuario_id bigint NOT NULL,
    tipo text NOT NULL,
    titulo text NOT NULL,
    contenido text NOT NULL,
    evento_id uuid NOT NULL,
    version_cotizacion_id bigint,
    pedido_id bigint,
    solicitud_servicio_id bigint,
    orden_servicio_id bigint,
    solicitud_cotizacion_id bigint,
    cotizacion_id bigint,
    solicitud_desarrollo_id bigint,
    proyecto_id bigint,
    factura_id bigint,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    leida_en timestamptz,
    CONSTRAINT pk_notificacion PRIMARY KEY (id),
    CONSTRAINT uq_notificacion_destinatario_usuario_id_evento_id_tipo UNIQUE (destinatario_usuario_id, evento_id, tipo),
    CONSTRAINT ck_notificacion_textos CHECK ((btrim(tipo) <> '') AND (btrim(titulo) <> '') AND (btrim(contenido) <> '')),
    CONSTRAINT ck_notificacion_fechas_finitas CHECK (isfinite(created_at) AND isfinite(leida_en)),
    CONSTRAINT ck_notificacion_tipo CHECK (tipo IN ('general', 'cambio_pedido', 'cambio_solicitud', 'cambio_servicio', 'cambio_cotizacion', 'cambio_proyecto', 'factura_emitida')),
    CONSTRAINT ck_notificacion_contexto CHECK (num_nonnulls(pedido_id, solicitud_servicio_id, orden_servicio_id, solicitud_cotizacion_id, cotizacion_id, solicitud_desarrollo_id, proyecto_id, factura_id) <= 1),
    CONSTRAINT ck_notificacion_tipo_contexto CHECK ((tipo = 'general' AND num_nonnulls(pedido_id, solicitud_servicio_id, orden_servicio_id, solicitud_cotizacion_id, cotizacion_id, solicitud_desarrollo_id, proyecto_id, factura_id) = 0) OR (tipo = 'cambio_pedido' AND pedido_id IS NOT NULL) OR (tipo = 'cambio_solicitud' AND num_nonnulls(solicitud_servicio_id, solicitud_cotizacion_id, solicitud_desarrollo_id) = 1) OR (tipo = 'cambio_servicio' AND orden_servicio_id IS NOT NULL) OR (tipo = 'cambio_cotizacion' AND cotizacion_id IS NOT NULL) OR (tipo = 'cambio_proyecto' AND proyecto_id IS NOT NULL) OR (tipo = 'factura_emitida' AND factura_id IS NOT NULL)),
    CONSTRAINT ck_notificacion_version_contexto CHECK (version_cotizacion_id IS NULL OR cotizacion_id IS NOT NULL),
    CONSTRAINT ck_notificacion_lectura_fecha CHECK (leida_en IS NULL OR leida_en >= created_at)
);
COMMENT ON TABLE comunicacion.notificacion IS 'Bandeja propuesta para usuario registrado.';
COMMENT ON COLUMN comunicacion.notificacion.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comunicacion.notificacion.destinatario_usuario_id IS 'Referencia a identidad.usuario.id.';
COMMENT ON COLUMN comunicacion.notificacion.tipo IS 'tipo';
COMMENT ON COLUMN comunicacion.notificacion.titulo IS 'titulo';
COMMENT ON COLUMN comunicacion.notificacion.contenido IS 'contenido';
COMMENT ON COLUMN comunicacion.notificacion.evento_id IS 'Identificador estable del evento de negocio para deduplicar.';
COMMENT ON COLUMN comunicacion.notificacion.version_cotizacion_id IS 'Referencia a comercial.version_cotizacion.id.';
COMMENT ON COLUMN comunicacion.notificacion.pedido_id IS 'Referencia a comercial.pedido.id.';
COMMENT ON COLUMN comunicacion.notificacion.solicitud_servicio_id IS 'Referencia a servicios.solicitud_servicio.id.';
COMMENT ON COLUMN comunicacion.notificacion.orden_servicio_id IS 'Referencia a servicios.orden_servicio.id.';
COMMENT ON COLUMN comunicacion.notificacion.solicitud_cotizacion_id IS 'Referencia a comercial.solicitud_cotizacion.id.';
COMMENT ON COLUMN comunicacion.notificacion.cotizacion_id IS 'Referencia a comercial.cotizacion.id.';
COMMENT ON COLUMN comunicacion.notificacion.solicitud_desarrollo_id IS 'Referencia a proyectos.solicitud_desarrollo.id.';
COMMENT ON COLUMN comunicacion.notificacion.proyecto_id IS 'Referencia a proyectos.proyecto.id.';
COMMENT ON COLUMN comunicacion.notificacion.factura_id IS 'Referencia a comercial.factura.id.';
COMMENT ON COLUMN comunicacion.notificacion.created_at IS 'created at';
COMMENT ON COLUMN comunicacion.notificacion.leida_en IS 'leida en';

-- Persona participante, registrada o invitada.
CREATE TABLE comunicacion.participante_conversacion (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    conversacion_id bigint NOT NULL,
    persona_id bigint NOT NULL,
    funcion text NOT NULL,
    incorporado_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    salio_en timestamptz,
    CONSTRAINT pk_participante_conversacion PRIMARY KEY (id),
    CONSTRAINT uq_participante_conversacion_conversacion_id_persona_id UNIQUE (conversacion_id, persona_id),
    CONSTRAINT ck_participante_conversacion_textos CHECK ((btrim(funcion) <> '')),
    CONSTRAINT ck_participante_conversacion_fechas_finitas CHECK (isfinite(incorporado_en) AND isfinite(salio_en)),
    CONSTRAINT ck_participante_conversacion_fechas CHECK (salio_en IS NULL OR salio_en >= incorporado_en)
);
COMMENT ON TABLE comunicacion.participante_conversacion IS 'Persona participante, registrada o invitada.';
COMMENT ON COLUMN comunicacion.participante_conversacion.id IS 'Identificador interno estable.';
COMMENT ON COLUMN comunicacion.participante_conversacion.conversacion_id IS 'Referencia a comunicacion.conversacion.id.';
COMMENT ON COLUMN comunicacion.participante_conversacion.persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN comunicacion.participante_conversacion.funcion IS 'funcion';
COMMENT ON COLUMN comunicacion.participante_conversacion.incorporado_en IS 'incorporado en';
COMMENT ON COLUMN comunicacion.participante_conversacion.salio_en IS 'salio en';

-- Evidencia de modificaciones críticas; no sustituye historiales operativos.
CREATE TABLE auditoria.evento_auditoria (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    operacion text NOT NULL,
    esquema_objeto text NOT NULL,
    tabla_objeto text NOT NULL,
    clave_registro jsonb NOT NULL,
    valores_anteriores jsonb,
    valores_nuevos jsonb,
    usuario_conexion text NOT NULL,
    rol_efectivo text NOT NULL,
    correlacion_id uuid NOT NULL,
    ocurrido_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actor_persona_id bigint,
    actor_sistema text,
    CONSTRAINT pk_evento_auditoria PRIMARY KEY (id),
    CONSTRAINT ck_evento_auditoria_textos CHECK ((btrim(operacion) <> '') AND (btrim(esquema_objeto) <> '') AND (btrim(tabla_objeto) <> '') AND (btrim(usuario_conexion) <> '') AND (btrim(rol_efectivo) <> '') AND (btrim(actor_sistema) <> '')),
    CONSTRAINT ck_evento_auditoria_fechas_finitas CHECK (isfinite(ocurrido_en)),
    CONSTRAINT ck_evento_auditoria_actor CHECK (num_nonnulls(actor_persona_id, actor_sistema) = 1),
    CONSTRAINT ck_evento_auditoria_operacion CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE')),
    CONSTRAINT ck_evento_auditoria_clave_objeto CHECK (jsonb_typeof(clave_registro) = 'object' AND clave_registro <> '{}'::jsonb),
    CONSTRAINT ck_evento_auditoria_imagenes_objeto CHECK ((valores_anteriores IS NULL OR jsonb_typeof(valores_anteriores) = 'object') AND (valores_nuevos IS NULL OR jsonb_typeof(valores_nuevos) = 'object')),
    CONSTRAINT ck_evento_auditoria_operacion_imagenes CHECK ((operacion = 'INSERT' AND valores_anteriores IS NULL AND valores_nuevos IS NOT NULL) OR (operacion = 'UPDATE' AND valores_anteriores IS NOT NULL AND valores_nuevos IS NOT NULL) OR (operacion = 'DELETE' AND valores_anteriores IS NOT NULL AND valores_nuevos IS NULL))
);
COMMENT ON TABLE auditoria.evento_auditoria IS 'Evidencia de modificaciones críticas; no sustituye historiales operativos.';
COMMENT ON COLUMN auditoria.evento_auditoria.id IS 'Identificador interno estable.';
COMMENT ON COLUMN auditoria.evento_auditoria.operacion IS 'INSERT, UPDATE o DELETE.';
COMMENT ON COLUMN auditoria.evento_auditoria.esquema_objeto IS 'esquema objeto';
COMMENT ON COLUMN auditoria.evento_auditoria.tabla_objeto IS 'tabla objeto';
COMMENT ON COLUMN auditoria.evento_auditoria.clave_registro IS 'Identificación histórica incluso de una PK compuesta o registro eliminado.';
COMMENT ON COLUMN auditoria.evento_auditoria.valores_anteriores IS 'valores anteriores';
COMMENT ON COLUMN auditoria.evento_auditoria.valores_nuevos IS 'valores nuevos';
COMMENT ON COLUMN auditoria.evento_auditoria.usuario_conexion IS 'Identidad técnica de conexión; no se interpreta como cliente final.';
COMMENT ON COLUMN auditoria.evento_auditoria.rol_efectivo IS 'rol efectivo';
COMMENT ON COLUMN auditoria.evento_auditoria.correlacion_id IS 'correlacion id';
COMMENT ON COLUMN auditoria.evento_auditoria.ocurrido_en IS 'ocurrido en';
COMMENT ON COLUMN auditoria.evento_auditoria.actor_persona_id IS 'Referencia a identidad.persona.id.';
COMMENT ON COLUMN auditoria.evento_auditoria.actor_sistema IS 'Proceso automático responsable cuando no hay iniciador humano.';


-- FKs al final: todos los destinos y sus claves únicas ya existen.
ALTER TABLE identidad.acceso_invitado ADD CONSTRAINT fk_acceso_invitado_persona_id FOREIGN KEY (persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.acceso_invitado ADD CONSTRAINT fk_acceso_invitado_version_cotizacion_id FOREIGN KEY (version_cotizacion_id) REFERENCES comercial.version_cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.acceso_invitado ADD CONSTRAINT fk_acceso_invitado_pedido_id FOREIGN KEY (pedido_id) REFERENCES comercial.pedido (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.acceso_invitado ADD CONSTRAINT fk_acceso_invitado_solicitud_servicio_id FOREIGN KEY (solicitud_servicio_id) REFERENCES servicios.solicitud_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.acceso_invitado ADD CONSTRAINT fk_acceso_invitado_orden_servicio_id FOREIGN KEY (orden_servicio_id) REFERENCES servicios.orden_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.acceso_invitado ADD CONSTRAINT fk_acceso_invitado_solicitud_cotizacion_id FOREIGN KEY (solicitud_cotizacion_id) REFERENCES comercial.solicitud_cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.acceso_invitado ADD CONSTRAINT fk_acceso_invitado_cotizacion_id FOREIGN KEY (cotizacion_id) REFERENCES comercial.cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.acceso_invitado ADD CONSTRAINT fk_acceso_invitado_solicitud_desarrollo_id FOREIGN KEY (solicitud_desarrollo_id) REFERENCES proyectos.solicitud_desarrollo (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.acceso_invitado ADD CONSTRAINT fk_acceso_invitado_proyecto_id FOREIGN KEY (proyecto_id) REFERENCES proyectos.proyecto (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.acceso_invitado ADD CONSTRAINT fk_acceso_invitado_factura_id FOREIGN KEY (factura_id) REFERENCES comercial.factura (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.acceso_invitado ADD CONSTRAINT fk_acceso_invitado_conversacion_id FOREIGN KEY (conversacion_id) REFERENCES comunicacion.conversacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.acceso_invitado_permiso ADD CONSTRAINT fk_acceso_invitado_permiso_acceso_invitado_id FOREIGN KEY (acceso_invitado_id) REFERENCES identidad.acceso_invitado (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.acceso_invitado_permiso ADD CONSTRAINT fk_acceso_invitado_permiso_permiso_id FOREIGN KEY (permiso_id) REFERENCES identidad.permiso (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.cliente ADD CONSTRAINT fk_cliente_persona_id FOREIGN KEY (persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.empleado ADD CONSTRAINT fk_empleado_persona_id FOREIGN KEY (persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.rol_permiso ADD CONSTRAINT fk_rol_permiso_rol_id FOREIGN KEY (rol_id) REFERENCES identidad.rol (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.rol_permiso ADD CONSTRAINT fk_rol_permiso_permiso_id FOREIGN KEY (permiso_id) REFERENCES identidad.permiso (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.rol_permiso ADD CONSTRAINT fk_rol_permiso_actor_persona_id FOREIGN KEY (actor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.usuario ADD CONSTRAINT fk_usuario_persona_id FOREIGN KEY (persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.usuario_rol ADD CONSTRAINT fk_usuario_rol_usuario_id FOREIGN KEY (usuario_id) REFERENCES identidad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.usuario_rol ADD CONSTRAINT fk_usuario_rol_rol_id FOREIGN KEY (rol_id) REFERENCES identidad.rol (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.usuario_rol ADD CONSTRAINT fk_usuario_rol_actor_persona_id FOREIGN KEY (actor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE inventario.inventario ADD CONSTRAINT fk_inventario_producto_id FOREIGN KEY (producto_id) REFERENCES inventario.producto (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE inventario.movimiento_inventario ADD CONSTRAINT fk_movimiento_inventario_producto_id FOREIGN KEY (producto_id) REFERENCES inventario.inventario (producto_id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE inventario.movimiento_inventario ADD CONSTRAINT fk_movimiento_inventario_detalle_pedido_id FOREIGN KEY (detalle_pedido_id) REFERENCES comercial.detalle_pedido (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE inventario.movimiento_inventario ADD CONSTRAINT fk_movimiento_inventario_compensa_movimiento_id FOREIGN KEY (compensa_movimiento_id) REFERENCES inventario.movimiento_inventario (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE inventario.movimiento_inventario ADD CONSTRAINT fk_movimiento_inventario_actor_persona_id FOREIGN KEY (actor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE inventario.producto ADD CONSTRAINT fk_producto_categoria_id FOREIGN KEY (categoria_id) REFERENCES inventario.categoria (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE inventario.producto_imagen ADD CONSTRAINT fk_producto_imagen_producto_id FOREIGN KEY (producto_id) REFERENCES inventario.producto (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE inventario.producto_imagen ADD CONSTRAINT fk_producto_imagen_archivo_id FOREIGN KEY (archivo_id) REFERENCES comunicacion.archivo (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE inventario.reserva_inventario ADD CONSTRAINT fk_reserva_inventario_detalle_pedido_id FOREIGN KEY (detalle_pedido_id) REFERENCES comercial.detalle_pedido (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.carrito ADD CONSTRAINT fk_carrito_cliente_id FOREIGN KEY (cliente_id) REFERENCES identidad.cliente (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.comprobante_factura ADD CONSTRAINT fk_comprobante_factura_factura_id FOREIGN KEY (factura_id) REFERENCES comercial.factura (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.comprobante_factura ADD CONSTRAINT fk_comprobante_factura_archivo_id FOREIGN KEY (archivo_id) REFERENCES comunicacion.archivo (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.cotizacion ADD CONSTRAINT fk_cotizacion_solicitud_cotizacion_id FOREIGN KEY (solicitud_cotizacion_id) REFERENCES comercial.solicitud_cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.cotizacion ADD CONSTRAINT fk_cotizacion_persona_directa_id FOREIGN KEY (persona_directa_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.detalle_carrito ADD CONSTRAINT fk_detalle_carrito_carrito_id FOREIGN KEY (carrito_id) REFERENCES comercial.carrito (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.detalle_carrito ADD CONSTRAINT fk_detalle_carrito_producto_id FOREIGN KEY (producto_id) REFERENCES inventario.producto (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.detalle_cotizacion ADD CONSTRAINT fk_detalle_cotizacion_version_cotizacion_id FOREIGN KEY (version_cotizacion_id) REFERENCES comercial.version_cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.detalle_cotizacion ADD CONSTRAINT fk_detalle_cotizacion_producto_id FOREIGN KEY (producto_id) REFERENCES inventario.producto (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.detalle_cotizacion ADD CONSTRAINT fk_detalle_cotizacion_servicio_ofrecido_id FOREIGN KEY (servicio_ofrecido_id) REFERENCES servicios.servicio_ofrecido (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.detalle_factura ADD CONSTRAINT fk_detalle_factura_factura_id FOREIGN KEY (factura_id) REFERENCES comercial.factura (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.detalle_factura ADD CONSTRAINT fk_detalle_factura_detalle_pedido_id FOREIGN KEY (detalle_pedido_id) REFERENCES comercial.detalle_pedido (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.detalle_factura ADD CONSTRAINT fk_detalle_factura_detalle_cotizacion_id FOREIGN KEY (detalle_cotizacion_id) REFERENCES comercial.detalle_cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.detalle_pedido ADD CONSTRAINT fk_detalle_pedido_pedido_id FOREIGN KEY (pedido_id) REFERENCES comercial.pedido (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.detalle_pedido ADD CONSTRAINT fk_detalle_pedido_producto_id FOREIGN KEY (producto_id) REFERENCES inventario.producto (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.detalle_pedido ADD CONSTRAINT fk_detalle_pedido_detalle_cotizacion_id FOREIGN KEY (detalle_cotizacion_id) REFERENCES comercial.detalle_cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.factura ADD CONSTRAINT fk_factura_pedido_id FOREIGN KEY (pedido_id) REFERENCES comercial.pedido (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.factura ADD CONSTRAINT fk_factura_orden_servicio_id FOREIGN KEY (orden_servicio_id) REFERENCES servicios.orden_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.factura ADD CONSTRAINT fk_factura_proyecto_id FOREIGN KEY (proyecto_id) REFERENCES proyectos.proyecto (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.historial_cotizacion ADD CONSTRAINT fk_historial_cotizacion_cotizacion_id FOREIGN KEY (cotizacion_id) REFERENCES comercial.cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.historial_cotizacion ADD CONSTRAINT fk_historial_cotizacion_actor_persona_id FOREIGN KEY (actor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.historial_cotizacion ADD CONSTRAINT fk_historial_cotizacion_version_cotizacion_id FOREIGN KEY (version_cotizacion_id) REFERENCES comercial.version_cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.historial_factura ADD CONSTRAINT fk_historial_factura_factura_id FOREIGN KEY (factura_id) REFERENCES comercial.factura (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.historial_factura ADD CONSTRAINT fk_historial_factura_actor_persona_id FOREIGN KEY (actor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.historial_pedido ADD CONSTRAINT fk_historial_pedido_pedido_id FOREIGN KEY (pedido_id) REFERENCES comercial.pedido (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.historial_pedido ADD CONSTRAINT fk_historial_pedido_actor_persona_id FOREIGN KEY (actor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.historial_solicitud_cotizacion ADD CONSTRAINT fk_historial_solicitud_cotizacion_solicitud_cotizacion_id FOREIGN KEY (solicitud_cotizacion_id) REFERENCES comercial.solicitud_cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.historial_solicitud_cotizacion ADD CONSTRAINT fk_historial_solicitud_cotizacion_actor_persona_id FOREIGN KEY (actor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.pedido ADD CONSTRAINT fk_pedido_cliente_id FOREIGN KEY (cliente_id) REFERENCES identidad.cliente (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.pedido ADD CONSTRAINT fk_pedido_carrito_id FOREIGN KEY (carrito_id) REFERENCES comercial.carrito (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.pedido ADD CONSTRAINT fk_pedido_version_cotizacion_id FOREIGN KEY (version_cotizacion_id) REFERENCES comercial.version_cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.solicitud_cotizacion ADD CONSTRAINT fk_solicitud_cotizacion_persona_id FOREIGN KEY (persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.version_cotizacion ADD CONSTRAINT fk_version_cotizacion_cotizacion_id FOREIGN KEY (cotizacion_id) REFERENCES comercial.cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comercial.version_cotizacion ADD CONSTRAINT fk_version_cotizacion_respondida_por_persona_id FOREIGN KEY (respondida_por_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.asignacion_servicio ADD CONSTRAINT fk_asignacion_servicio_orden_servicio_id FOREIGN KEY (orden_servicio_id) REFERENCES servicios.orden_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.asignacion_servicio ADD CONSTRAINT fk_asignacion_servicio_empleado_id FOREIGN KEY (empleado_id) REFERENCES identidad.empleado (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.asignacion_servicio ADD CONSTRAINT fk_asignacion_servicio_actor_persona_id FOREIGN KEY (actor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.calificacion_servicio ADD CONSTRAINT fk_calificacion_servicio_orden_servicio_id FOREIGN KEY (orden_servicio_id) REFERENCES servicios.orden_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.calificacion_servicio ADD CONSTRAINT fk_calificacion_servicio_autor_persona_id FOREIGN KEY (autor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.cita_servicio ADD CONSTRAINT fk_cita_servicio_solicitud_servicio_id FOREIGN KEY (solicitud_servicio_id) REFERENCES servicios.solicitud_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.cita_servicio ADD CONSTRAINT fk_cita_servicio_tecnico_id FOREIGN KEY (tecnico_id) REFERENCES identidad.empleado (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.cita_servicio ADD CONSTRAINT fk_cita_servicio_sustituye_cita_id FOREIGN KEY (sustituye_cita_id) REFERENCES servicios.cita_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.disponibilidad_tecnico ADD CONSTRAINT fk_disponibilidad_tecnico_empleado_id FOREIGN KEY (empleado_id) REFERENCES identidad.empleado (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.equipo_cliente ADD CONSTRAINT fk_equipo_cliente_cliente_id FOREIGN KEY (cliente_id) REFERENCES identidad.cliente (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.historial_servicio ADD CONSTRAINT fk_historial_servicio_orden_servicio_id FOREIGN KEY (orden_servicio_id) REFERENCES servicios.orden_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.historial_servicio ADD CONSTRAINT fk_historial_servicio_actor_persona_id FOREIGN KEY (actor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.historial_solicitud_servicio ADD CONSTRAINT fk_historial_solicitud_servicio_solicitud_servicio_id FOREIGN KEY (solicitud_servicio_id) REFERENCES servicios.solicitud_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.historial_solicitud_servicio ADD CONSTRAINT fk_historial_solicitud_servicio_actor_persona_id FOREIGN KEY (actor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.mantenimiento ADD CONSTRAINT fk_mantenimiento_orden_servicio_id FOREIGN KEY (orden_servicio_id) REFERENCES servicios.orden_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.orden_servicio ADD CONSTRAINT fk_orden_servicio_solicitud_servicio_id FOREIGN KEY (solicitud_servicio_id) REFERENCES servicios.solicitud_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.orden_servicio ADD CONSTRAINT fk_orden_servicio_version_cotizacion_id FOREIGN KEY (version_cotizacion_id) REFERENCES comercial.version_cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.reparacion ADD CONSTRAINT fk_reparacion_orden_servicio_id FOREIGN KEY (orden_servicio_id) REFERENCES servicios.orden_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.solicitud_servicio ADD CONSTRAINT fk_solicitud_servicio_cliente_id FOREIGN KEY (cliente_id) REFERENCES identidad.cliente (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.solicitud_servicio ADD CONSTRAINT fk_solicitud_servicio_servicio_ofrecido_id FOREIGN KEY (servicio_ofrecido_id) REFERENCES servicios.servicio_ofrecido (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE servicios.solicitud_servicio ADD CONSTRAINT fk_solicitud_servicio_equipo_cliente_id FOREIGN KEY (equipo_cliente_id) REFERENCES servicios.equipo_cliente (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE proyectos.avance_proyecto ADD CONSTRAINT fk_avance_proyecto_etapa_proyecto_id FOREIGN KEY (etapa_proyecto_id) REFERENCES proyectos.etapa_proyecto (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE proyectos.avance_proyecto ADD CONSTRAINT fk_avance_proyecto_miembro_proyecto_id FOREIGN KEY (miembro_proyecto_id) REFERENCES proyectos.miembro_proyecto (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE proyectos.etapa_proyecto ADD CONSTRAINT fk_etapa_proyecto_proyecto_id FOREIGN KEY (proyecto_id) REFERENCES proyectos.proyecto (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE proyectos.historial_proyecto ADD CONSTRAINT fk_historial_proyecto_proyecto_id FOREIGN KEY (proyecto_id) REFERENCES proyectos.proyecto (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE proyectos.historial_proyecto ADD CONSTRAINT fk_historial_proyecto_actor_persona_id FOREIGN KEY (actor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE proyectos.historial_solicitud_desarrollo ADD CONSTRAINT fk_historial_solicitud_desarrollo_solicitud_desarrollo_id FOREIGN KEY (solicitud_desarrollo_id) REFERENCES proyectos.solicitud_desarrollo (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE proyectos.historial_solicitud_desarrollo ADD CONSTRAINT fk_historial_solicitud_desarrollo_actor_persona_id FOREIGN KEY (actor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE proyectos.miembro_proyecto ADD CONSTRAINT fk_miembro_proyecto_proyecto_id FOREIGN KEY (proyecto_id) REFERENCES proyectos.proyecto (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE proyectos.miembro_proyecto ADD CONSTRAINT fk_miembro_proyecto_empleado_id FOREIGN KEY (empleado_id) REFERENCES identidad.empleado (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE proyectos.miembro_proyecto ADD CONSTRAINT fk_miembro_proyecto_actor_persona_id FOREIGN KEY (actor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE proyectos.proyecto ADD CONSTRAINT fk_proyecto_solicitud_desarrollo_id FOREIGN KEY (solicitud_desarrollo_id) REFERENCES proyectos.solicitud_desarrollo (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE proyectos.proyecto ADD CONSTRAINT fk_proyecto_version_cotizacion_id FOREIGN KEY (version_cotizacion_id) REFERENCES comercial.version_cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE proyectos.solicitud_desarrollo ADD CONSTRAINT fk_solicitud_desarrollo_cliente_id FOREIGN KEY (cliente_id) REFERENCES identidad.cliente (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.adjunto ADD CONSTRAINT fk_adjunto_archivo_id FOREIGN KEY (archivo_id) REFERENCES comunicacion.archivo (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.adjunto ADD CONSTRAINT fk_adjunto_mensaje_id FOREIGN KEY (mensaje_id) REFERENCES comunicacion.mensaje (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.adjunto ADD CONSTRAINT fk_adjunto_pedido_id FOREIGN KEY (pedido_id) REFERENCES comercial.pedido (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.adjunto ADD CONSTRAINT fk_adjunto_solicitud_servicio_id FOREIGN KEY (solicitud_servicio_id) REFERENCES servicios.solicitud_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.adjunto ADD CONSTRAINT fk_adjunto_orden_servicio_id FOREIGN KEY (orden_servicio_id) REFERENCES servicios.orden_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.adjunto ADD CONSTRAINT fk_adjunto_solicitud_cotizacion_id FOREIGN KEY (solicitud_cotizacion_id) REFERENCES comercial.solicitud_cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.adjunto ADD CONSTRAINT fk_adjunto_cotizacion_id FOREIGN KEY (cotizacion_id) REFERENCES comercial.cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.adjunto ADD CONSTRAINT fk_adjunto_solicitud_desarrollo_id FOREIGN KEY (solicitud_desarrollo_id) REFERENCES proyectos.solicitud_desarrollo (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.adjunto ADD CONSTRAINT fk_adjunto_proyecto_id FOREIGN KEY (proyecto_id) REFERENCES proyectos.proyecto (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.adjunto ADD CONSTRAINT fk_adjunto_factura_id FOREIGN KEY (factura_id) REFERENCES comercial.factura (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.archivo ADD CONSTRAINT fk_archivo_actor_persona_id FOREIGN KEY (actor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.conversacion ADD CONSTRAINT fk_conversacion_pedido_id FOREIGN KEY (pedido_id) REFERENCES comercial.pedido (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.conversacion ADD CONSTRAINT fk_conversacion_solicitud_servicio_id FOREIGN KEY (solicitud_servicio_id) REFERENCES servicios.solicitud_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.conversacion ADD CONSTRAINT fk_conversacion_orden_servicio_id FOREIGN KEY (orden_servicio_id) REFERENCES servicios.orden_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.conversacion ADD CONSTRAINT fk_conversacion_solicitud_cotizacion_id FOREIGN KEY (solicitud_cotizacion_id) REFERENCES comercial.solicitud_cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.conversacion ADD CONSTRAINT fk_conversacion_cotizacion_id FOREIGN KEY (cotizacion_id) REFERENCES comercial.cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.conversacion ADD CONSTRAINT fk_conversacion_solicitud_desarrollo_id FOREIGN KEY (solicitud_desarrollo_id) REFERENCES proyectos.solicitud_desarrollo (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.conversacion ADD CONSTRAINT fk_conversacion_proyecto_id FOREIGN KEY (proyecto_id) REFERENCES proyectos.proyecto (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.entrega_notificacion ADD CONSTRAINT fk_entrega_notificacion_notificacion_id FOREIGN KEY (notificacion_id) REFERENCES comunicacion.notificacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.lectura_mensaje ADD CONSTRAINT fk_lectura_mensaje_mensaje_id FOREIGN KEY (mensaje_id) REFERENCES comunicacion.mensaje (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.lectura_mensaje ADD CONSTRAINT fk_lectura_mensaje_participante_id FOREIGN KEY (participante_id) REFERENCES comunicacion.participante_conversacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.mensaje ADD CONSTRAINT fk_mensaje_autor_participante_id FOREIGN KEY (autor_participante_id) REFERENCES comunicacion.participante_conversacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.notificacion ADD CONSTRAINT fk_notificacion_destinatario_usuario_id FOREIGN KEY (destinatario_usuario_id) REFERENCES identidad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.notificacion ADD CONSTRAINT fk_notificacion_version_cotizacion_id FOREIGN KEY (version_cotizacion_id) REFERENCES comercial.version_cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.notificacion ADD CONSTRAINT fk_notificacion_pedido_id FOREIGN KEY (pedido_id) REFERENCES comercial.pedido (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.notificacion ADD CONSTRAINT fk_notificacion_solicitud_servicio_id FOREIGN KEY (solicitud_servicio_id) REFERENCES servicios.solicitud_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.notificacion ADD CONSTRAINT fk_notificacion_orden_servicio_id FOREIGN KEY (orden_servicio_id) REFERENCES servicios.orden_servicio (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.notificacion ADD CONSTRAINT fk_notificacion_solicitud_cotizacion_id FOREIGN KEY (solicitud_cotizacion_id) REFERENCES comercial.solicitud_cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.notificacion ADD CONSTRAINT fk_notificacion_cotizacion_id FOREIGN KEY (cotizacion_id) REFERENCES comercial.cotizacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.notificacion ADD CONSTRAINT fk_notificacion_solicitud_desarrollo_id FOREIGN KEY (solicitud_desarrollo_id) REFERENCES proyectos.solicitud_desarrollo (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.notificacion ADD CONSTRAINT fk_notificacion_proyecto_id FOREIGN KEY (proyecto_id) REFERENCES proyectos.proyecto (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.notificacion ADD CONSTRAINT fk_notificacion_factura_id FOREIGN KEY (factura_id) REFERENCES comercial.factura (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.participante_conversacion ADD CONSTRAINT fk_participante_conversacion_conversacion_id FOREIGN KEY (conversacion_id) REFERENCES comunicacion.conversacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE comunicacion.participante_conversacion ADD CONSTRAINT fk_participante_conversacion_persona_id FOREIGN KEY (persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE auditoria.evento_auditoria ADD CONSTRAINT fk_evento_auditoria_actor_persona_id FOREIGN KEY (actor_persona_id) REFERENCES identidad.persona (id) ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER SEQUENCE comercial.seq_pedido OWNED BY comercial.pedido.numero;

ALTER SEQUENCE comercial.seq_cotizacion OWNED BY comercial.cotizacion.numero;

ALTER SEQUENCE comercial.seq_factura OWNED BY comercial.factura.numero;

-- Unicidad condicional: predicados estables, sin depender del reloj.
-- Una salida por línea entregada; no hay entregas parciales.
CREATE UNIQUE INDEX ux_movimiento_inventario_parcial_1 ON inventario.movimiento_inventario USING btree (detalle_pedido_id) WHERE detalle_pedido_id IS NOT NULL;
-- Una imagen principal por producto.
CREATE UNIQUE INDEX ux_producto_imagen_parcial_2 ON inventario.producto_imagen USING btree (producto_id) WHERE principal;
-- Un carrito abierto por cliente.
CREATE UNIQUE INDEX ux_carrito_parcial_3 ON comercial.carrito USING btree (cliente_id) WHERE estado = 'abierto' AND cliente_id IS NOT NULL;
-- Una versión aceptada por cotización.
CREATE UNIQUE INDEX ux_version_cotizacion_parcial_4 ON comercial.version_cotizacion USING btree (cotizacion_id) WHERE estado = 'aceptada';
-- Una versión enviada por cotización.
CREATE UNIQUE INDEX ux_version_cotizacion_parcial_5 ON comercial.version_cotizacion USING btree (cotizacion_id) WHERE estado = 'enviada';
-- Una versión borrador por cotización.
CREATE UNIQUE INDEX ux_version_cotizacion_parcial_6 ON comercial.version_cotizacion USING btree (cotizacion_id) WHERE estado = 'borrador';
-- No adjuntar dos veces el mismo archivo al mismo destino.
CREATE UNIQUE INDEX ux_adjunto_archivo_mensaje_id ON comunicacion.adjunto USING btree (archivo_id, mensaje_id) WHERE mensaje_id IS NOT NULL;
-- No adjuntar dos veces el mismo archivo al mismo destino.
CREATE UNIQUE INDEX ux_adjunto_archivo_pedido_id ON comunicacion.adjunto USING btree (archivo_id, pedido_id) WHERE pedido_id IS NOT NULL;
-- No adjuntar dos veces el mismo archivo al mismo destino.
CREATE UNIQUE INDEX ux_adjunto_archivo_solicitud_servicio_id ON comunicacion.adjunto USING btree (archivo_id, solicitud_servicio_id) WHERE solicitud_servicio_id IS NOT NULL;
-- No adjuntar dos veces el mismo archivo al mismo destino.
CREATE UNIQUE INDEX ux_adjunto_archivo_orden_servicio_id ON comunicacion.adjunto USING btree (archivo_id, orden_servicio_id) WHERE orden_servicio_id IS NOT NULL;
-- No adjuntar dos veces el mismo archivo al mismo destino.
CREATE UNIQUE INDEX ux_adjunto_archivo_solicitud_cotizacion_id ON comunicacion.adjunto USING btree (archivo_id, solicitud_cotizacion_id) WHERE solicitud_cotizacion_id IS NOT NULL;
-- No adjuntar dos veces el mismo archivo al mismo destino.
CREATE UNIQUE INDEX ux_adjunto_archivo_cotizacion_id ON comunicacion.adjunto USING btree (archivo_id, cotizacion_id) WHERE cotizacion_id IS NOT NULL;
-- No adjuntar dos veces el mismo archivo al mismo destino.
CREATE UNIQUE INDEX ux_adjunto_archivo_solicitud_desarrollo_id ON comunicacion.adjunto USING btree (archivo_id, solicitud_desarrollo_id) WHERE solicitud_desarrollo_id IS NOT NULL;
-- No adjuntar dos veces el mismo archivo al mismo destino.
CREATE UNIQUE INDEX ux_adjunto_archivo_proyecto_id ON comunicacion.adjunto USING btree (archivo_id, proyecto_id) WHERE proyecto_id IS NOT NULL;
-- No adjuntar dos veces el mismo archivo al mismo destino.
CREATE UNIQUE INDEX ux_adjunto_archivo_factura_id ON comunicacion.adjunto USING btree (archivo_id, factura_id) WHERE factura_id IS NOT NULL;
-- Exclusiones temporales: intervalos [inicio,fin), con NULL como fin abierto.
-- Impide solapar concesiones del mismo rol al mismo usuario.
ALTER TABLE identidad.usuario_rol ADD CONSTRAINT ex_usuario_rol_periodos EXCLUDE USING gist (usuario_id WITH =, rol_id WITH =, tstzrange(inicia_en, termina_en, '[)') WITH &&);
-- Evita períodos duplicados del mismo técnico en la misma orden.
ALTER TABLE servicios.asignacion_servicio ADD CONSTRAINT ex_asignacion_servicio_periodos EXCLUDE USING gist (orden_servicio_id WITH =, empleado_id WITH =, tstzrange(inicia_en, termina_en, '[)') WITH &&);
-- Un responsable principal de la orden en cada instante.
ALTER TABLE servicios.asignacion_servicio ADD CONSTRAINT ex_asignacion_servicio_principal EXCLUDE USING gist (orden_servicio_id WITH =, tstzrange(inicia_en, termina_en, '[)') WITH &&) WHERE (es_principal);
-- Evita duplicar ventanas habilitadas del técnico.
ALTER TABLE servicios.disponibilidad_tecnico ADD CONSTRAINT ex_disponibilidad_tecnico_periodos EXCLUDE USING gist (empleado_id WITH =, tstzrange(inicio, fin, '[)') WITH &&) WHERE (habilitada);
-- Impide doble reserva del mismo técnico; permite citas adyacentes.
ALTER TABLE servicios.cita_servicio ADD CONSTRAINT ex_cita_servicio_periodos EXCLUDE USING gist (tecnico_id WITH =, tstzrange(inicio, fin, '[)') WITH &&) WHERE (estado IN ('confirmada', 'realizada'));
-- Evita períodos duplicados del miembro en el proyecto.
ALTER TABLE proyectos.miembro_proyecto ADD CONSTRAINT ex_miembro_proyecto_periodos EXCLUDE USING gist (proyecto_id WITH =, empleado_id WITH =, tstzrange(inicia_en, termina_en, '[)') WITH &&);
-- Un responsable principal del proyecto en cada instante.
ALTER TABLE proyectos.miembro_proyecto ADD CONSTRAINT ex_miembro_proyecto_principal EXCLUDE USING gist (proyecto_id WITH =, tstzrange(inicia_en, termina_en, '[)') WITH &&) WHERE (es_principal);

-- Historial paginado de compras por cliente (RF-11/RF-12).
CREATE INDEX ix_pedido_cliente_fecha ON comercial.pedido USING btree (cliente_id, created_at DESC, id DESC);

-- Solicitudes e historial de cotizaciones de una persona, tenga cuenta o no.
CREATE INDEX ix_solicitud_cotizacion_persona_fecha ON comercial.solicitud_cotizacion USING btree (persona_id, created_at DESC, id DESC);

-- Solicitudes e historial técnico de un cliente.
CREATE INDEX ix_solicitud_servicio_cliente_fecha ON servicios.solicitud_servicio USING btree (cliente_id, created_at DESC, id DESC);

-- Consulta de solicitudes de desarrollo del cliente.
CREATE INDEX ix_solicitud_desarrollo_cliente_fecha ON proyectos.solicitud_desarrollo USING btree (cliente_id, created_at DESC, id DESC);

-- Libro de movimientos del producto y conciliación de stock.
CREATE INDEX ix_movimiento_inventario_producto_fecha ON inventario.movimiento_inventario USING btree (producto_id, registrado_en DESC, id DESC);

-- Último avance por etapa y consulta cronológica con desempate estable.
CREATE INDEX ix_avance_proyecto_etapa_fecha ON proyectos.avance_proyecto USING btree (etapa_proyecto_id, registrado_en DESC, id DESC);

-- Mensajes por participantes al consultar una conversación; conversación se deriva del autor.
CREATE INDEX ix_mensaje_autor_fecha ON comunicacion.mensaje USING btree (autor_participante_id, enviado_en DESC, id DESC);

-- Bandeja completa del destinatario con paginación.
CREATE INDEX ix_notificacion_destinatario_fecha ON comunicacion.notificacion USING btree (destinatario_usuario_id, created_at DESC, id DESC);

-- Revisión temporal de cambios en una tabla auditada.
CREATE INDEX ix_evento_auditoria_objeto_fecha ON auditoria.evento_auditoria USING btree (esquema_objeto, tabla_objeto, ocurrido_en DESC, id DESC);

-- Reconstruir una operación que cambió varias tablas.
CREATE INDEX ix_evento_auditoria_correlacion ON auditoria.evento_auditoria USING btree (correlacion_id);

-- Bandeja de pendientes sin recorrer las notificaciones ya leídas.
CREATE INDEX ix_notificacion_no_leida ON comunicacion.notificacion USING btree (destinatario_usuario_id, created_at DESC, id DESC) WHERE leida_en IS NULL;

-- Worker de entregas pendientes; selección y bloqueos se programan en fase 5.
CREATE INDEX ix_entrega_notificacion_pendiente ON comunicacion.entrega_notificacion USING btree (created_at, id) WHERE estado = 'pendiente';

-- Catálogo publicado por categoría y rango de precio (RF-07/RF-08).
CREATE INDEX ix_producto_catalogo ON inventario.producto USING btree (categoria_id, precio_vigente, id) WHERE activo AND publicado;

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_acceso_invitado_persona_id ON identidad.acceso_invitado USING btree (persona_id);

-- JOIN/FK hacia comercial.version_cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_acceso_invitado_version_cotizacion_id ON identidad.acceso_invitado USING btree (version_cotizacion_id);

-- JOIN/FK hacia comercial.pedido.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_acceso_invitado_pedido_id ON identidad.acceso_invitado USING btree (pedido_id);

-- JOIN/FK hacia servicios.solicitud_servicio.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_acceso_invitado_solicitud_servicio_id ON identidad.acceso_invitado USING btree (solicitud_servicio_id);

-- JOIN/FK hacia servicios.orden_servicio.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_acceso_invitado_orden_servicio_id ON identidad.acceso_invitado USING btree (orden_servicio_id);

-- JOIN/FK hacia comercial.solicitud_cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_acceso_invitado_solicitud_cotizacion_id ON identidad.acceso_invitado USING btree (solicitud_cotizacion_id);

-- JOIN/FK hacia comercial.cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_acceso_invitado_cotizacion_id ON identidad.acceso_invitado USING btree (cotizacion_id);

-- JOIN/FK hacia proyectos.solicitud_desarrollo.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_acceso_invitado_solicitud_desarrollo_id ON identidad.acceso_invitado USING btree (solicitud_desarrollo_id);

-- JOIN/FK hacia proyectos.proyecto.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_acceso_invitado_proyecto_id ON identidad.acceso_invitado USING btree (proyecto_id);

-- JOIN/FK hacia comercial.factura.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_acceso_invitado_factura_id ON identidad.acceso_invitado USING btree (factura_id);

-- JOIN/FK hacia comunicacion.conversacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_acceso_invitado_conversacion_id ON identidad.acceso_invitado USING btree (conversacion_id);

-- JOIN/FK hacia identidad.permiso.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_acceso_invitado_permiso_permiso_id ON identidad.acceso_invitado_permiso USING btree (permiso_id);

-- JOIN/FK hacia identidad.permiso.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_rol_permiso_permiso_id ON identidad.rol_permiso USING btree (permiso_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_rol_permiso_actor_persona_id ON identidad.rol_permiso USING btree (actor_persona_id);

-- JOIN/FK hacia identidad.usuario.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_usuario_rol_usuario_id ON identidad.usuario_rol USING btree (usuario_id);

-- JOIN/FK hacia identidad.rol.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_usuario_rol_rol_id ON identidad.usuario_rol USING btree (rol_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_usuario_rol_actor_persona_id ON identidad.usuario_rol USING btree (actor_persona_id);

-- JOIN/FK hacia inventario.movimiento_inventario.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_movimiento_inventario_compensa_movimiento_id ON inventario.movimiento_inventario USING btree (compensa_movimiento_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_movimiento_inventario_actor_persona_id ON inventario.movimiento_inventario USING btree (actor_persona_id);

-- JOIN/FK hacia inventario.categoria.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_producto_categoria_id ON inventario.producto USING btree (categoria_id);

-- JOIN/FK hacia comunicacion.archivo.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_producto_imagen_archivo_id ON inventario.producto_imagen USING btree (archivo_id);

-- JOIN/FK hacia identidad.cliente.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_carrito_cliente_id ON comercial.carrito USING btree (cliente_id);

-- JOIN/FK hacia comunicacion.archivo.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_comprobante_factura_archivo_id ON comercial.comprobante_factura USING btree (archivo_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_cotizacion_persona_directa_id ON comercial.cotizacion USING btree (persona_directa_id);

-- JOIN/FK hacia inventario.producto.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_detalle_carrito_producto_id ON comercial.detalle_carrito USING btree (producto_id);

-- JOIN/FK hacia inventario.producto.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_detalle_cotizacion_producto_id ON comercial.detalle_cotizacion USING btree (producto_id);

-- JOIN/FK hacia servicios.servicio_ofrecido.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_detalle_cotizacion_servicio_ofrecido_id ON comercial.detalle_cotizacion USING btree (servicio_ofrecido_id);

-- JOIN/FK hacia comercial.detalle_pedido.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_detalle_factura_detalle_pedido_id ON comercial.detalle_factura USING btree (detalle_pedido_id);

-- JOIN/FK hacia comercial.detalle_cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_detalle_factura_detalle_cotizacion_id ON comercial.detalle_factura USING btree (detalle_cotizacion_id);

-- JOIN/FK hacia inventario.producto.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_detalle_pedido_producto_id ON comercial.detalle_pedido USING btree (producto_id);

-- JOIN/FK hacia comercial.detalle_cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_detalle_pedido_detalle_cotizacion_id ON comercial.detalle_pedido USING btree (detalle_cotizacion_id);

-- JOIN/FK hacia comercial.pedido.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_factura_pedido_id ON comercial.factura USING btree (pedido_id);

-- JOIN/FK hacia servicios.orden_servicio.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_factura_orden_servicio_id ON comercial.factura USING btree (orden_servicio_id);

-- JOIN/FK hacia proyectos.proyecto.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_factura_proyecto_id ON comercial.factura USING btree (proyecto_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_historial_cotizacion_actor_persona_id ON comercial.historial_cotizacion USING btree (actor_persona_id);

-- JOIN/FK hacia comercial.version_cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_historial_cotizacion_version_cotizacion_id ON comercial.historial_cotizacion USING btree (version_cotizacion_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_historial_factura_actor_persona_id ON comercial.historial_factura USING btree (actor_persona_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_historial_pedido_actor_persona_id ON comercial.historial_pedido USING btree (actor_persona_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_historial_solicitud_cotizacion_actor_persona_id ON comercial.historial_solicitud_cotizacion USING btree (actor_persona_id);

-- JOIN/FK hacia comercial.version_cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_pedido_version_cotizacion_id ON comercial.pedido USING btree (version_cotizacion_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_version_cotizacion_respondida_por_persona_id ON comercial.version_cotizacion USING btree (respondida_por_persona_id);

-- JOIN/FK hacia servicios.orden_servicio.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_asignacion_servicio_orden_servicio_id ON servicios.asignacion_servicio USING btree (orden_servicio_id);

-- JOIN/FK hacia identidad.empleado.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_asignacion_servicio_empleado_id ON servicios.asignacion_servicio USING btree (empleado_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_asignacion_servicio_actor_persona_id ON servicios.asignacion_servicio USING btree (actor_persona_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_calificacion_servicio_autor_persona_id ON servicios.calificacion_servicio USING btree (autor_persona_id);

-- JOIN/FK hacia servicios.solicitud_servicio.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_cita_servicio_solicitud_servicio_id ON servicios.cita_servicio USING btree (solicitud_servicio_id);

-- JOIN/FK hacia identidad.empleado.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_cita_servicio_tecnico_id ON servicios.cita_servicio USING btree (tecnico_id);

-- JOIN/FK hacia identidad.empleado.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_disponibilidad_tecnico_empleado_id ON servicios.disponibilidad_tecnico USING btree (empleado_id);

-- JOIN/FK hacia identidad.cliente.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_equipo_cliente_cliente_id ON servicios.equipo_cliente USING btree (cliente_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_historial_servicio_actor_persona_id ON servicios.historial_servicio USING btree (actor_persona_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_historial_solicitud_servicio_actor_persona_id ON servicios.historial_solicitud_servicio USING btree (actor_persona_id);

-- JOIN/FK hacia comercial.version_cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_orden_servicio_version_cotizacion_id ON servicios.orden_servicio USING btree (version_cotizacion_id);

-- JOIN/FK hacia servicios.servicio_ofrecido.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_solicitud_servicio_servicio_ofrecido_id ON servicios.solicitud_servicio USING btree (servicio_ofrecido_id);

-- JOIN/FK hacia servicios.equipo_cliente.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_solicitud_servicio_equipo_cliente_id ON servicios.solicitud_servicio USING btree (equipo_cliente_id);

-- JOIN/FK hacia proyectos.miembro_proyecto.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_avance_proyecto_miembro_proyecto_id ON proyectos.avance_proyecto USING btree (miembro_proyecto_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_historial_proyecto_actor_persona_id ON proyectos.historial_proyecto USING btree (actor_persona_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_historial_solicitud_desarrollo_actor_persona_id ON proyectos.historial_solicitud_desarrollo USING btree (actor_persona_id);

-- JOIN/FK hacia proyectos.proyecto.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_miembro_proyecto_proyecto_id ON proyectos.miembro_proyecto USING btree (proyecto_id);

-- JOIN/FK hacia identidad.empleado.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_miembro_proyecto_empleado_id ON proyectos.miembro_proyecto USING btree (empleado_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_miembro_proyecto_actor_persona_id ON proyectos.miembro_proyecto USING btree (actor_persona_id);

-- JOIN/FK hacia comercial.version_cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_proyecto_version_cotizacion_id ON proyectos.proyecto USING btree (version_cotizacion_id);

-- JOIN/FK hacia comunicacion.archivo.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_adjunto_archivo_id ON comunicacion.adjunto USING btree (archivo_id);

-- JOIN/FK hacia comunicacion.mensaje.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_adjunto_mensaje_id ON comunicacion.adjunto USING btree (mensaje_id);

-- JOIN/FK hacia comercial.pedido.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_adjunto_pedido_id ON comunicacion.adjunto USING btree (pedido_id);

-- JOIN/FK hacia servicios.solicitud_servicio.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_adjunto_solicitud_servicio_id ON comunicacion.adjunto USING btree (solicitud_servicio_id);

-- JOIN/FK hacia servicios.orden_servicio.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_adjunto_orden_servicio_id ON comunicacion.adjunto USING btree (orden_servicio_id);

-- JOIN/FK hacia comercial.solicitud_cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_adjunto_solicitud_cotizacion_id ON comunicacion.adjunto USING btree (solicitud_cotizacion_id);

-- JOIN/FK hacia comercial.cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_adjunto_cotizacion_id ON comunicacion.adjunto USING btree (cotizacion_id);

-- JOIN/FK hacia proyectos.solicitud_desarrollo.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_adjunto_solicitud_desarrollo_id ON comunicacion.adjunto USING btree (solicitud_desarrollo_id);

-- JOIN/FK hacia proyectos.proyecto.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_adjunto_proyecto_id ON comunicacion.adjunto USING btree (proyecto_id);

-- JOIN/FK hacia comercial.factura.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_adjunto_factura_id ON comunicacion.adjunto USING btree (factura_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_archivo_actor_persona_id ON comunicacion.archivo USING btree (actor_persona_id);

-- JOIN/FK hacia comercial.pedido.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_conversacion_pedido_id ON comunicacion.conversacion USING btree (pedido_id);

-- JOIN/FK hacia servicios.solicitud_servicio.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_conversacion_solicitud_servicio_id ON comunicacion.conversacion USING btree (solicitud_servicio_id);

-- JOIN/FK hacia servicios.orden_servicio.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_conversacion_orden_servicio_id ON comunicacion.conversacion USING btree (orden_servicio_id);

-- JOIN/FK hacia comercial.solicitud_cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_conversacion_solicitud_cotizacion_id ON comunicacion.conversacion USING btree (solicitud_cotizacion_id);

-- JOIN/FK hacia comercial.cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_conversacion_cotizacion_id ON comunicacion.conversacion USING btree (cotizacion_id);

-- JOIN/FK hacia proyectos.solicitud_desarrollo.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_conversacion_solicitud_desarrollo_id ON comunicacion.conversacion USING btree (solicitud_desarrollo_id);

-- JOIN/FK hacia proyectos.proyecto.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_conversacion_proyecto_id ON comunicacion.conversacion USING btree (proyecto_id);

-- JOIN/FK hacia comunicacion.participante_conversacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_lectura_mensaje_participante_id ON comunicacion.lectura_mensaje USING btree (participante_id);

-- JOIN/FK hacia comercial.version_cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_notificacion_version_cotizacion_id ON comunicacion.notificacion USING btree (version_cotizacion_id);

-- JOIN/FK hacia comercial.pedido.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_notificacion_pedido_id ON comunicacion.notificacion USING btree (pedido_id);

-- JOIN/FK hacia servicios.solicitud_servicio.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_notificacion_solicitud_servicio_id ON comunicacion.notificacion USING btree (solicitud_servicio_id);

-- JOIN/FK hacia servicios.orden_servicio.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_notificacion_orden_servicio_id ON comunicacion.notificacion USING btree (orden_servicio_id);

-- JOIN/FK hacia comercial.solicitud_cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_notificacion_solicitud_cotizacion_id ON comunicacion.notificacion USING btree (solicitud_cotizacion_id);

-- JOIN/FK hacia comercial.cotizacion.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_notificacion_cotizacion_id ON comunicacion.notificacion USING btree (cotizacion_id);

-- JOIN/FK hacia proyectos.solicitud_desarrollo.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_notificacion_solicitud_desarrollo_id ON comunicacion.notificacion USING btree (solicitud_desarrollo_id);

-- JOIN/FK hacia proyectos.proyecto.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_notificacion_proyecto_id ON comunicacion.notificacion USING btree (proyecto_id);

-- JOIN/FK hacia comercial.factura.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_notificacion_factura_id ON comunicacion.notificacion USING btree (factura_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_participante_conversacion_persona_id ON comunicacion.participante_conversacion USING btree (persona_id);

-- JOIN/FK hacia identidad.persona.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_evento_auditoria_actor_persona_id ON auditoria.evento_auditoria USING btree (actor_persona_id);


-- MÓDULO 02_autenticacion_local (tablas conservadas; con Supabase Auth no se usan para contraseñas)



-- Opcional: solo si se adopta autenticación local en el backend.

-- Credencial local opcional; una por cuenta.
CREATE TABLE identidad.credencial (
    usuario_id bigint NOT NULL,
    password_hash text NOT NULL,
    cambiada_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_credencial PRIMARY KEY (usuario_id),
    CONSTRAINT ck_credencial_textos CHECK ((btrim(password_hash) <> '')),
    CONSTRAINT ck_credencial_fechas_finitas CHECK (isfinite(cambiada_en))
);
COMMENT ON TABLE identidad.credencial IS 'Credencial local opcional; una por cuenta.';
COMMENT ON COLUMN identidad.credencial.usuario_id IS 'Referencia a identidad.usuario.id.';
COMMENT ON COLUMN identidad.credencial.password_hash IS 'Hash resistente de contraseña con parámetros/sal; nunca texto plano.';
COMMENT ON COLUMN identidad.credencial.cambiada_en IS 'cambiada en';

-- Recuperación local de uso único.
CREATE TABLE identidad.recuperacion_acceso (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    usuario_id bigint NOT NULL,
    token_hash bytea NOT NULL,
    solicitada_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    vence_en timestamptz NOT NULL,
    consumida_en timestamptz,
    CONSTRAINT pk_recuperacion_acceso PRIMARY KEY (id),
    CONSTRAINT uq_recuperacion_acceso_token_hash UNIQUE (token_hash),
    CONSTRAINT ck_recuperacion_acceso_fechas_finitas CHECK (isfinite(solicitada_en) AND isfinite(vence_en) AND isfinite(consumida_en)),
    CONSTRAINT ck_recuperacion_acceso_token_hash CHECK (octet_length(token_hash) = 32),
    CONSTRAINT ck_recuperacion_acceso_fechas CHECK (vence_en > solicitada_en AND (consumida_en IS NULL OR consumida_en >= solicitada_en))
);
COMMENT ON TABLE identidad.recuperacion_acceso IS 'Recuperación local de uso único.';
COMMENT ON COLUMN identidad.recuperacion_acceso.id IS 'Identificador interno estable.';
COMMENT ON COLUMN identidad.recuperacion_acceso.usuario_id IS 'Referencia a identidad.usuario.id.';
COMMENT ON COLUMN identidad.recuperacion_acceso.token_hash IS 'Huella SHA-256 del secreto.';
COMMENT ON COLUMN identidad.recuperacion_acceso.solicitada_en IS 'solicitada en';
COMMENT ON COLUMN identidad.recuperacion_acceso.vence_en IS 'vence en';
COMMENT ON COLUMN identidad.recuperacion_acceso.consumida_en IS 'consumida en';

-- Sesión local con revocación y renovación.
CREATE TABLE identidad.sesion (
    id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    usuario_id bigint NOT NULL,
    refresh_hash bytea NOT NULL,
    inicia_en timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    vence_en timestamptz NOT NULL,
    revocada_en timestamptz,
    CONSTRAINT pk_sesion PRIMARY KEY (id),
    CONSTRAINT uq_sesion_refresh_hash UNIQUE (refresh_hash),
    CONSTRAINT ck_sesion_fechas_finitas CHECK (isfinite(inicia_en) AND isfinite(vence_en) AND isfinite(revocada_en)),
    CONSTRAINT ck_sesion_refresh_hash CHECK (octet_length(refresh_hash) = 32),
    CONSTRAINT ck_sesion_fechas CHECK (vence_en > inicia_en AND (revocada_en IS NULL OR revocada_en >= inicia_en))
);
COMMENT ON TABLE identidad.sesion IS 'Sesión local con revocación y renovación.';
COMMENT ON COLUMN identidad.sesion.id IS 'Identificador interno estable.';
COMMENT ON COLUMN identidad.sesion.usuario_id IS 'Referencia a identidad.usuario.id.';
COMMENT ON COLUMN identidad.sesion.refresh_hash IS 'Huella SHA-256 del secreto de renovación.';
COMMENT ON COLUMN identidad.sesion.inicia_en IS 'inicia en';
COMMENT ON COLUMN identidad.sesion.vence_en IS 'vence en';
COMMENT ON COLUMN identidad.sesion.revocada_en IS 'revocada en';


-- FKs al final: todos los destinos y sus claves únicas ya existen.
ALTER TABLE identidad.credencial ADD CONSTRAINT fk_credencial_usuario_id FOREIGN KEY (usuario_id) REFERENCES identidad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.recuperacion_acceso ADD CONSTRAINT fk_recuperacion_acceso_usuario_id FOREIGN KEY (usuario_id) REFERENCES identidad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE identidad.sesion ADD CONSTRAINT fk_sesion_usuario_id FOREIGN KEY (usuario_id) REFERENCES identidad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT;

-- JOIN/FK hacia identidad.usuario.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_recuperacion_acceso_usuario_id ON identidad.recuperacion_acceso USING btree (usuario_id);

-- JOIN/FK hacia identidad.usuario.id y comprobación eficiente de referencias al modificar el padre.
CREATE INDEX ix_sesion_usuario_id ON identidad.sesion USING btree (usuario_id);


RESET statement_timeout;
RESET lock_timeout;
RESET search_path;
RESET ROLE;
