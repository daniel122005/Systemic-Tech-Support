-- SYSTEMIC TECH & SUPPORT — Fase 4. Estructura, sin lógica de negocio todavía.
-- Ejecutar como propietario autorizado. No contiene DROP ni borra datos existentes.
BEGIN;
SET LOCAL search_path = pg_catalog, public;
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '5min';
DO $precondiciones$
BEGIN
    IF current_setting('server_version_num')::integer < 180000 THEN
        RAISE EXCEPTION 'Este paquete requiere PostgreSQL 18 o posterior; fue preparado para 18.3.';
    END IF;
    IF current_database() <> 'systemic_tech_db' THEN
        RAISE EXCEPTION 'Conecte a systemic_tech_db antes de ejecutar este archivo.';
    END IF;
END;
$precondiciones$;


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

COMMIT;
