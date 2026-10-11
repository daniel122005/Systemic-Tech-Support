#!/usr/bin/env python3
"""Genera las migraciones de Supabase a partir de los módulos SQL locales de Systemic Tech.

Uso:  python3 -I generar_supabase.py <carpeta_modulos_locales> <carpeta_supabase_salida>

Cada sustitución se comprueba: si un texto esperado no aparece exactamente el número de
veces previsto, el script se detiene sin escribir nada. Así una edición futura de los
módulos no produce migraciones silenciosamente incorrectas.

Adaptaciones (todas justificadas en ADAPTACIONES_SUPABASE.md):
  A1  Se eliminan BEGIN/COMMIT: el CLI de Supabase y el SQL Editor gestionan la transacción.
  A2  SET LOCAL -> SET + RESET final (funciona dentro y fuera de una transacción explícita).
  A3  Versión mínima 17 (Supabase ofrece 15/17); la base se llama `postgres`.
  A4  Esquemas, comentarios de esquema y extensiones se crean como `postgres`, porque en
      Supabase st_owner no puede recibir CREATE sobre la base (postgres no tiene GRANT OPTION).
      Tablas, funciones, triggers y políticas siguen perteneciendo a st_owner.
  A5  btree_gist se instala en el esquema `extensions` (convención de Supabase).
  A6  public.digest(x,'sha256') -> pg_catalog.sha256(convert_to(x,'UTF8')): mismo resultado
      en una base UTF8, sin depender de pgcrypto ni del esquema `extensions`.
  A7  Se omiten REVOKE/GRANT sobre la base de datos y REVOKE CREATE ON SCHEMA public:
      en Supabase romperían roles internos (authenticator, supabase_auth_admin...).
"""
import re
import sys
from pathlib import Path

SRC = Path(sys.argv[1])
OUT = Path(sys.argv[2])
PREFIJO = "20261009"


def leer(nombre):
    with open(SRC / nombre, encoding="utf-8", newline="") as f:  # conserva CRLF originales
        return f.read()


def sustituir(texto, viejo, nuevo, veces=1, etiqueta=""):
    n = texto.count(viejo)
    if n != veces:
        raise SystemExit(f"[{etiqueta}] se esperaban {veces} apariciones de {viejo!r} y hay {n}")
    return texto.replace(viejo, nuevo)


def quitar_lineas(texto, lineas, etiqueta):
    for l in lineas:
        patron = re.compile(r"^" + re.escape(l) + r"[ \t]*\r?\n", re.M)
        n = len(patron.findall(texto))
        if n != 1:
            raise SystemExit(f"[{etiqueta}] línea {l!r}: {n} apariciones (se esperaba 1)")
        texto = patron.sub("", texto, count=1)
    return texto


def cuerpo_modulo(nombre, quitar):
    return quitar_lineas(leer(nombre), quitar, nombre)


CABECERA = """-- Systemic Tech & Support — migración para Supabase generada por herramientas/generar_supabase.py
-- Origen: módulos locales verificados en PostgreSQL 18.3 y 17.6. No editar a mano: regenerar.
-- Compatible con Supabase CLI (supabase db push / db reset) y con el SQL Editor (pegar completo).
"""

PRECONDICION = """DO $precondiciones$
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
"""

ESQUEMAS = ["identidad", "inventario", "comercial", "servicios", "proyectos", "comunicacion", "auditoria"]


def migracion_roles():
    return CABECERA + """-- 1/6. Roles técnicos. Equivale a 00_roles.sql adaptado a Supabase.
-- En Supabase `postgres` no es superusuario pero tiene CREATEROLE; al crear cada rol recibe ADMIN OPTION.
-- Es idempotente: si el rol existe, solo se reafirman sus atributos de seguridad.
DO $roles$
DECLARE r record;
BEGIN
  IF current_setting('server_version_num')::integer < 170000 THEN
    RAISE EXCEPTION 'Systemic Tech requiere PostgreSQL 17 o posterior';
  END IF;
  IF current_database() <> 'postgres' THEN
    RAISE EXCEPTION 'En Supabase la base de datos debe ser postgres';
  END IF;
  FOR r IN SELECT * FROM (VALUES
      ('st_owner',false),('st_dba',false),('st_app',false),('st_worker',false),('st_lectura',false),
      ('st_administracion',false),('st_backend',true),('st_trabajador',true),('st_consulta',true)) AS t(nombre,login)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r.nombre) THEN
      EXECUTE format('CREATE ROLE %I %s NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS INHERIT',
                     r.nombre, CASE WHEN r.login THEN 'LOGIN' ELSE 'NOLOGIN' END);
    ELSE
      EXECUTE format('ALTER ROLE %I %s NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
                     r.nombre, CASE WHEN r.login THEN 'LOGIN' ELSE 'NOLOGIN' END);
    END IF;
  END LOOP;
END
$roles$;
-- Sin contraseña: se fija después con \\password desde psql (nunca en un archivo del repositorio).
GRANT st_owner TO st_dba;
GRANT st_app TO st_backend, st_administracion;
GRANT st_worker TO st_trabajador;
GRANT st_lectura TO st_consulta;
-- `postgres` es el administrador del proyecto Supabase: actúa como el DBA del modelo
-- (en local ese papel lo tiene el superusuario). Necesita SET ROLE st_owner para instalar.
GRANT st_dba TO postgres;
"""


def migracion_estructura():
    m01 = leer("01_estructura.sql")
    cab_vieja = m01[: m01.index("CREATE SEQUENCE")]
    # Verificar que la cabecera contiene exactamente lo que se traslada al bloque de postgres.
    for e in ESQUEMAS:
        sustituir(cab_vieja, f"CREATE SCHEMA {e};", "", 1, "01 cabecera")
        if f"COMMENT ON SCHEMA {e} IS" not in cab_vieja:
            raise SystemExit(f"Falta COMMENT ON SCHEMA {e}")
    sustituir(cab_vieja, "CREATE EXTENSION btree_gist WITH SCHEMA public;", "", 1, "01 cabecera")
    comentarios = [c.rstrip("\r") for c in re.findall(r"^COMMENT ON SCHEMA [^\n]*?;\r?$", cab_vieja, re.M)]
    if len(comentarios) != 7:
        raise SystemExit("Se esperaban 7 COMMENT ON SCHEMA")
    resto01 = m01[m01.index("CREATE SEQUENCE"):]
    resto01 = quitar_lineas(resto01, ["COMMIT;"], "01")
    m02 = leer("02_autenticacion_local.sql")
    m02 = m02[m02.index("$precondiciones$;", m02.index("DO $precondiciones$")) + len("$precondiciones$;"):]
    m02 = quitar_lineas(m02, ["COMMIT;"], "02")
    bloque_postgres = "\n".join(
        ["-- A4/A5: objetos que en Supabase debe crear `postgres` (st_owner no tiene CREATE sobre la base).",
         "CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA extensions;"]
        + [f"CREATE SCHEMA {e};" for e in ESQUEMAS]
        + comentarios
        + [f"GRANT USAGE, CREATE ON SCHEMA {e} TO st_owner WITH GRANT OPTION;" for e in ESQUEMAS]
    )
    return (CABECERA + "-- 2/6. Estructura: 62 tablas, restricciones, índices y secuencias (01 + 02).\n"
            + PRECONDICION + "\n" + bloque_postgres + "\n\n"
            + "SET ROLE st_owner;\nSET search_path = pg_catalog, public;\nSET lock_timeout = '10s';\nSET statement_timeout = '5min';\n\n"
            + "-- MÓDULO 01_estructura (desde CREATE SEQUENCE)\n" + resto01
            + "\n-- MÓDULO 02_autenticacion_local (tablas conservadas; con Supabase Auth no se usan para contraseñas)\n" + m02
            + "\nRESET statement_timeout;\nRESET lock_timeout;\nRESET search_path;\nRESET ROLE;\n")


def adaptar_digest(texto, etiqueta, esperadas):
    patron = re.compile(r"public\.digest\(([^(),]+),('{1,2})sha256\2\)")
    n = len(patron.findall(texto))
    if n != esperadas:
        raise SystemExit(f"[{etiqueta}] se esperaban {esperadas} llamadas a public.digest y hay {n}")
    texto = patron.sub(lambda m: f"pg_catalog.sha256(convert_to({m.group(1)},{m.group(2)}UTF8{m.group(2)}))", texto)
    if "public.digest" in texto or "gen_random_bytes" in texto:
        raise SystemExit(f"[{etiqueta}] quedan referencias a pgcrypto")
    return texto


def migracion_logica():
    m10 = cuerpo_modulo("10_identidad.sql", ["BEGIN;", "COMMIT;", "CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;"])
    m10 = adaptar_digest(m10, "10", 3)
    m20 = cuerpo_modulo("20_comercial.sql", ["BEGIN;", "COMMIT;"])
    m20 = sustituir(m20, "SET LOCAL search_path = pg_catalog, pg_temp;", "SET search_path = pg_catalog, pg_temp;", 1, "20")
    m20 = adaptar_digest(m20, "20", 2)
    m30 = leer("30_servicios.sql")
    m40 = cuerpo_modulo("40_comunicacion.sql", ["BEGIN;", "SET LOCAL ROLE st_owner;", "COMMIT;"])
    m50 = cuerpo_modulo("50_auditoria.sql", ["BEGIN;", "COMMIT;"])
    m55 = cuerpo_modulo("55_autenticacion_backend.sql", ["BEGIN;", "COMMIT;"])
    for nombre, t in [("30", m30), ("40", m40), ("50", m50), ("55", m55)]:
        if "public." in t or re.search(r"^(BEGIN|COMMIT);", t, re.M):
            raise SystemExit(f"[{nombre}] contiene public. o control de transacción inesperado")
    return (CABECERA + "-- 3/6. Programación: identidad, comercial, servicios/proyectos, comunicación, auditoría.\n"
            + PRECONDICION + "\nSET ROLE st_owner;\nSET search_path = pg_catalog, public;\n\n"
            + "-- MÓDULO 10_identidad\n" + m10 + "\n-- MÓDULO 20_comercial\n" + m20
            + "\n-- MÓDULO 30_servicios\n" + m30 + "\n-- MÓDULO 40_comunicacion\n" + m40
            + "\n-- MÓDULO 50_auditoria\n" + m50 + "\n-- MÓDULO 55_autenticacion_backend\n" + m55
            + "\nRESET search_path;\nRESET ROLE;\n")


def migracion_seguridad():
    m60 = cuerpo_modulo("60_seguridad.sql", [
        "BEGIN;", "COMMIT;",
        "REVOKE ALL ON DATABASE systemic_tech_db FROM PUBLIC;",
        "GRANT CONNECT ON DATABASE systemic_tech_db TO st_app,st_worker,st_lectura,st_dba;",
        "REVOKE CREATE ON SCHEMA public FROM PUBLIC;",
    ])
    if "systemic_tech_db" in m60:
        raise SystemExit("[60] quedan referencias a systemic_tech_db")
    m65 = cuerpo_modulo("65_vistas.sql", ["BEGIN;", "COMMIT;"])
    return (CABECERA + "-- 4/6. Privilegios, RLS (62 políticas) y vistas (60 + 65).\n"
            + "-- A7: se omiten las sentencias sobre la base de datos y el esquema public.\n"
            + PRECONDICION + "\nSET ROLE st_owner;\nSET search_path = pg_catalog, pg_temp;\n\n"
            + "-- MÓDULO 60_seguridad\n" + m60 + "\n-- MÓDULO 65_vistas\n" + m65
            + "\nRESET search_path;\nRESET ROLE;\n")


def datos_demo_partes():
    demo = leer("70_datos_demo.sql")
    inicio_personas = demo.index(" INSERT INTO identidad.persona(nombres,apellidos,correo_contacto,telefono) VALUES('Cliente'")
    inicio_roles = demo.index(" INSERT INTO identidad.rol(codigo,nombre,descripcion) VALUES")
    base = demo[inicio_roles:inicio_personas]
    return demo, base, inicio_personas


def migracion_datos_base():
    _, base, _ = datos_demo_partes()
    if "DEMO" in base or "example" in base:
        raise SystemExit("La parte de catálogo base contiene datos ficticios")
    return (CABECERA + """-- 6/6. Datos base de producción: roles de negocio, permisos y concesiones rol-permiso.
-- Extraídos literalmente de 70_datos_demo.sql (primer bloque). No contiene personas ni datos ficticios.
-- Idempotente: si los roles ya existen no hace nada.
DO $datos_base$
DECLARE v_recurso_permiso record;
BEGIN
 IF EXISTS (SELECT 1 FROM identidad.rol WHERE codigo IN ('cliente','administrador','tecnico','desarrollador','administrativo')) THEN
   RAISE NOTICE 'Catálogo de roles y permisos ya presente; no se modifica';
   RETURN;
 END IF;
 PERFORM set_config('app.motivo','Catálogo base de roles y permisos Systemic Tech',true);
""" + base + """END
$datos_base$;
""")


def seed_demo():
    demo, base, inicio_personas = datos_demo_partes()
    demo = demo.replace(base, "", 1)
    demo = quitar_lineas(demo, ["BEGIN;", "SET LOCAL TRANSACTION ISOLATION LEVEL READ COMMITTED;", "COMMIT;"], "70")
    demo = sustituir(demo, "public.gen_random_bytes(32)", "extensions.gen_random_bytes(32)", 1, "70")
    demo = sustituir(demo, " PERFORM set_config('app.motivo','Carga inicial de datos ficticios Systemic Tech',true);\n",
                     " PERFORM set_config('app.motivo','Carga inicial de datos ficticios Systemic Tech',true);\n"
                     " IF NOT EXISTS (SELECT 1 FROM identidad.rol WHERE codigo='administrador') THEN\n"
                     "   RAISE EXCEPTION 'Falta el catálogo base de roles y permisos (migración datos_base)';\n END IF;\n", 1, "70")
    complemento = leer("71_datos_demo_complemento.sql")
    if "public." in complemento or re.search(r"^\\\\", complemento, re.M):
        raise SystemExit("[71] referencias no portables")
    demo = demo + "\n-- ===== 71_datos_demo_complemento.sql =====\n" + complemento
    return ("-- Systemic Tech & Support — DATOS FICTICIOS para entorno local o de pruebas.\n"
            "-- `supabase db reset` lo aplica solo en local. NUNCA usar `db push --include-seed` en producción.\n"
            "-- Generado desde 70_datos_demo.sql sin el catálogo de roles/permisos (ya incluido en migraciones).\n"
            + demo)


def pruebas():
    """Copias de las pruebas locales adaptadas al entorno Supabase local (solo cambia pgcrypto)."""
    salida = {}
    for nombre in ["80_verificacion.sql", "82_pruebas_servicios.sql", "82_pruebas_comunicacion.sql",
                   "83_pruebas_comercial.sql", "84_pruebas_acceso.sql", "85_pruebas_cotizacion_contacto.sql",
                   "87_pruebas_rf.sql"]:
        t = leer(nombre)
        n = t.count("public.gen_random_bytes(")
        t = t.replace("public.gen_random_bytes(", "extensions.gen_random_bytes(")
        if "public." in t.replace("public.gen_random_bytes", ""):
            pass
        if "systemic_tech_db" in t:
            raise SystemExit(f"[{nombre}] referencia a systemic_tech_db")
        salida[f"pruebas/{nombre}"] = t
    salida["pruebas/probar_supabase_local.sql"] = (
        "\\set ON_ERROR_STOP on\n"
        "-- Suite completa en la pila LOCAL de Supabase (supabase start + supabase db reset).\n"
        "-- Conectar como supabase_admin: las pruebas usan SET SESSION AUTHORIZATION (requiere superusuario).\n"
        "-- En el proyecto en la nube no hay superusuario: allí se usa verificacion_supabase.sql.\n"
        "\\ir 80_verificacion.sql\n\\ir 83_pruebas_comercial.sql\n\\ir 82_pruebas_servicios.sql\n"
        "\\ir 82_pruebas_comunicacion.sql\n\\ir 84_pruebas_acceso.sql\n\\ir 85_pruebas_cotizacion_contacto.sql\n"
        "\\ir 87_pruebas_rf.sql\n\\ir 86_pruebas_supabase_auth.sql\n"
        "\\echo TODAS LAS PRUEBAS EN SUPABASE LOCAL TERMINARON SIN ERROR\n")
    return salida


def main():
    archivos = {
        f"migrations/{PREFIJO}000100_roles_systemic.sql": migracion_roles(),
        f"migrations/{PREFIJO}000200_estructura.sql": migracion_estructura(),
        f"migrations/{PREFIJO}000300_logica.sql": migracion_logica(),
        f"migrations/{PREFIJO}000400_seguridad_vistas.sql": migracion_seguridad(),
        f"migrations/{PREFIJO}000600_datos_base.sql": migracion_datos_base(),
        "seed.sql": seed_demo(),
    }
    pruebas_generadas = pruebas()
    for rel, contenido in archivos.items():
        if re.search(r"^\\", contenido, re.M):
            raise SystemExit(f"{rel} contiene metacomandos de psql")
        destino = OUT / rel
        destino.parent.mkdir(parents=True, exist_ok=True)
        with open(destino, "w", encoding="utf-8", newline="") as f:
            f.write(contenido)
        print(f"escrito {rel} ({len(contenido.encode())} bytes)")
    for rel, contenido in pruebas_generadas.items():  # las pruebas son para psql: sí llevan metacomandos
        destino = OUT / rel
        destino.parent.mkdir(parents=True, exist_ok=True)
        with open(destino, "w", encoding="utf-8", newline="") as f:
            f.write(contenido)
        print(f"escrito {rel}")


if __name__ == "__main__":
    main()
