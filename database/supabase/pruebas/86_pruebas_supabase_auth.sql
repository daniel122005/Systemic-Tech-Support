\set ON_ERROR_STOP on
-- Pruebas SB01-SB16 de la integración con Supabase Auth y del cierre de la API pública.
-- Ejecutar en la pila LOCAL de Supabase (supabase start) como supabase_admin, después de
-- `supabase db reset`. Requiere superusuario para SET SESSION AUTHORIZATION (no existe en la nube).
-- Simula lo que hace Supabase Auth (GoTrue) escribiendo en auth.users como supabase_auth_admin.
-- Todo se revierte con ROLLBACK.
BEGIN;
SET LOCAL client_min_messages = notice;
CREATE TEMP TABLE s_ctx(clave text PRIMARY KEY, valor text NOT NULL) ON COMMIT DROP;
GRANT SELECT ON s_ctx TO st_app, supabase_auth_admin, anon, authenticated, service_role;
INSERT INTO s_ctx VALUES
 ('a', gen_random_uuid()::text), ('b', gen_random_uuid()::text), ('c', gen_random_uuid()::text),
 ('anonimo', gen_random_uuid()::text), ('sin_correo', gen_random_uuid()::text),
 ('sufijo', replace(gen_random_uuid()::text,'-',''));

-- Supabase Auth registra tres cuentas: A y B confirmadas, C pendiente de confirmar.
SET SESSION AUTHORIZATION supabase_auth_admin;
INSERT INTO auth.users(id, aud, role, email, email_confirmed_at, raw_user_meta_data)
SELECT (SELECT valor FROM s_ctx WHERE clave='a')::uuid, 'authenticated', 'authenticated',
       'ana.'||(SELECT valor FROM s_ctx WHERE clave='sufijo')||'@example.test', now(),
       '{"nombres":"Ana","apellidos":"Prueba","telefono":"3000000001"}';
INSERT INTO auth.users(id, aud, role, email, email_confirmed_at, raw_user_meta_data)
SELECT (SELECT valor FROM s_ctx WHERE clave='b')::uuid, 'authenticated', 'authenticated',
       'BETO.'||(SELECT valor FROM s_ctx WHERE clave='sufijo')||'@Example.test ', now(), '{"full_name":"Beto Ficticio"}';
INSERT INTO auth.users(id, aud, role, email, raw_user_meta_data)
SELECT (SELECT valor FROM s_ctx WHERE clave='c')::uuid, 'authenticated', 'authenticated',
       'carla.'||(SELECT valor FROM s_ctx WHERE clave='sufijo')||'@example.test', '{}';
-- Usuario anónimo de Supabase: es un visitante, no crea cuenta.
INSERT INTO auth.users(id, aud, role, is_anonymous)
SELECT (SELECT valor FROM s_ctx WHERE clave='anonimo')::uuid, 'authenticated', 'authenticated', true;
RESET SESSION AUTHORIZATION;

DO $s$
DECLARE a uuid:=(SELECT valor FROM s_ctx WHERE clave='a'); b uuid:=(SELECT valor FROM s_ctx WHERE clave='b');
 c uuid:=(SELECT valor FROM s_ctx WHERE clave='c'); anonimo uuid:=(SELECT valor FROM s_ctx WHERE clave='anonimo');
 ua identidad.usuario%ROWTYPE; ub identidad.usuario%ROWTYPE; uc identidad.usuario%ROWTYPE; cli bigint; ped bigint;
BEGIN
 SELECT * INTO STRICT ua FROM identidad.usuario WHERE emisor_externo='supabase-auth' AND sujeto_externo=a::text;
 SELECT * INTO STRICT ub FROM identidad.usuario WHERE emisor_externo='supabase-auth' AND sujeto_externo=b::text;
 SELECT * INTO STRICT uc FROM identidad.usuario WHERE emisor_externo='supabase-auth' AND sujeto_externo=c::text;
 IF ua.estado<>'activo' OR ua.verificado_en IS NULL OR ua.origen_auth<>'externo'
    OR NOT EXISTS(SELECT 1 FROM identidad.persona p JOIN identidad.cliente k ON k.persona_id=p.id
                  WHERE p.id=ua.persona_id AND p.nombres='Ana' AND p.apellidos='Prueba' AND p.telefono='3000000001') THEN
   RAISE EXCEPTION 'SB01: el alta confirmada no creó persona, cliente y cuenta activa';
 END IF;
 RAISE NOTICE 'SB01 OK: alta en Supabase Auth crea persona, cliente y cuenta externa activa';
 IF ub.correo_acceso <> lower(btrim(ub.correo_acceso)) OR ub.correo_acceso NOT LIKE 'beto.%@example.test'
    OR (SELECT nombres FROM identidad.persona WHERE id=ub.persona_id)<>'Beto Ficticio' THEN
   RAISE EXCEPTION 'SB02: correo no normalizado o nombre no tomado de full_name';
 END IF;
 RAISE NOTICE 'SB02 OK: correo normalizado y nombre desde metadatos alternativos';
 IF uc.estado<>'pendiente' OR uc.verificado_en IS NOT NULL THEN RAISE EXCEPTION 'SB03: cuenta sin confirmar no quedó pendiente'; END IF;
 IF (SELECT nombres FROM identidad.persona WHERE id=uc.persona_id) NOT LIKE 'carla.%' THEN RAISE EXCEPTION 'SB03: nombre por defecto'; END IF;
 RAISE NOTICE 'SB03 OK: cuenta sin confirmar queda pendiente, nombre tomado del correo';
 IF EXISTS(SELECT 1 FROM identidad.usuario WHERE sujeto_externo=anonimo::text) THEN RAISE EXCEPTION 'SB04: anónimo creó cuenta'; END IF;
 RAISE NOTICE 'SB04 OK: usuario anónimo de Supabase se trata como visitante';
 IF EXISTS(SELECT 1 FROM identidad.credencial) THEN RAISE EXCEPTION 'SB05: hay contraseñas en el modelo'; END IF;
 RAISE NOTICE 'SB05 OK: ninguna contraseña almacenada fuera de Supabase Auth';
 -- Un pedido borrador para A y otro para B, creados por el DBA.
 PERFORM set_config('app.usuario_id','',true);
 SELECT k.id INTO cli FROM identidad.cliente k WHERE k.persona_id=ua.persona_id;
 CALL comercial.crear_pedido(ped,cli,'COP','Ana Prueba',ua.correo_acceso,NULL);
 INSERT INTO s_ctx VALUES('pedido_a',ped::text);
 ped:=NULL; SELECT k.id INTO cli FROM identidad.cliente k WHERE k.persona_id=ub.persona_id;
 CALL comercial.crear_pedido(ped,cli,'COP','Beto Ficticio',ub.correo_acceso,NULL);
 INSERT INTO s_ctx VALUES('pedido_b',ped::text);
END $s$;

-- El correo con mayúsculas y espacios no es válido para Supabase, pero el alta debe rechazar cuentas sin correo.
SET SESSION AUTHORIZATION supabase_auth_admin;
DO $s$
BEGIN
  INSERT INTO auth.users(id, aud, role, phone) VALUES ((SELECT valor FROM s_ctx WHERE clave='sin_correo')::uuid,'authenticated','authenticated','+570000000009');
  RAISE EXCEPTION 'SB06: se creó una cuenta sin correo';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'SB06 OK: alta sin correo rechazada (Supabase Auth recibe el error)';
END $s$;
RESET SESSION AUTHORIZATION;

-- El backend (st_backend) fija la identidad con el sub verificado y RLS aísla a cada cliente.
SET SESSION AUTHORIZATION st_backend;
DO $s$
DECLARE a uuid:=(SELECT valor FROM s_ctx WHERE clave='a'); b uuid:=(SELECT valor FROM s_ctx WHERE clave='b');
 c uuid:=(SELECT valor FROM s_ctx WHERE clave='c'); pa bigint:=(SELECT valor FROM s_ctx WHERE clave='pedido_a');
 pb bigint:=(SELECT valor FROM s_ctx WHERE clave='pedido_b'); u bigint;
BEGIN
 u:=identidad.iniciar_contexto_supabase(a);
 IF u IS NULL OR (SELECT array_agg(id) FROM comercial.pedido)<>ARRAY[pa] THEN RAISE EXCEPTION 'SB07: A no ve solo su pedido'; END IF;
 IF (SELECT count(*) FROM identidad.persona)<>1 THEN RAISE EXCEPTION 'SB07: A ve otras personas'; END IF;
 u:=identidad.iniciar_contexto_supabase(b);
 IF (SELECT array_agg(id) FROM comercial.pedido)<>ARRAY[pb] THEN RAISE EXCEPTION 'SB07: B no ve solo su pedido'; END IF;
 RAISE NOTICE 'SB07 OK: RLS aísla pedidos y personas entre clientes con identidad de Supabase';
 u:=identidad.iniciar_contexto_supabase(c);
 IF u IS NOT NULL OR EXISTS(SELECT 1 FROM comercial.pedido) OR current_setting('app.usuario_id',true)<>'' THEN
   RAISE EXCEPTION 'SB08: cuenta pendiente obtuvo identidad';
 END IF;
 u:=identidad.iniciar_contexto_supabase(gen_random_uuid());
 IF u IS NOT NULL OR EXISTS(SELECT 1 FROM identidad.persona) THEN RAISE EXCEPTION 'SB08: sujeto desconocido obtuvo identidad'; END IF;
 RAISE NOTICE 'SB08 OK: cuenta pendiente o sujeto desconocido quedan sin identidad (falla cerrado)';
 BEGIN
   CALL identidad.registrar_usuario('X','Y','x@example.test',NULL,'local',NULL,NULL,'$argon2id$v=19$x',u);
   RAISE EXCEPTION 'SB09: la aplicación puede crear contraseñas locales';
 EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'SB09 OK: rutinas de contraseña local retiradas para la aplicación';
 END;
 u:=identidad.iniciar_contexto_supabase(a);
 BEGIN
   UPDATE comercial.pedido SET estado='cancelado' WHERE id=pa;
   RAISE EXCEPTION 'SB10: escritura directa permitida';
 EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'SB10 OK: sin escritura directa; solo procedimientos autorizados';
 END;
END $s$;
RESET SESSION AUTHORIZATION;

-- Roles de la API pública de Supabase: sin acceso a los esquemas internos.
SET ROLE anon;
DO $s$ BEGIN PERFORM 1 FROM identidad.persona; RAISE EXCEPTION 'SB11: anon lee identidad';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'SB11 OK: anon sin acceso a los esquemas internos'; END $s$;
RESET ROLE;
SET ROLE authenticated;
DO $s$ BEGIN PERFORM 1 FROM comercial.pedido; RAISE EXCEPTION 'SB12: authenticated lee pedidos';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'SB12 OK: authenticated sin acceso directo (usa el backend)'; END $s$;
RESET ROLE;
SET ROLE service_role;
DO $s$ BEGIN PERFORM 1 FROM comercial.factura; RAISE EXCEPTION 'SB13: service_role lee facturas';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'SB13 OK: service_role (BYPASSRLS) sin privilegios sobre las tablas'; END $s$;
RESET ROLE;

-- Cambios en Supabase Auth: confirmación, cambio de correo, bloqueo y baja.
SET SESSION AUTHORIZATION supabase_auth_admin;
UPDATE auth.users SET email_confirmed_at=now() WHERE id=(SELECT valor FROM s_ctx WHERE clave='c')::uuid;
UPDATE auth.users SET email='ana.nueva.'||(SELECT valor FROM s_ctx WHERE clave='sufijo')||'@example.test'
 WHERE id=(SELECT valor FROM s_ctx WHERE clave='a')::uuid;
UPDATE auth.users SET banned_until=now()+interval '100 years' WHERE id=(SELECT valor FROM s_ctx WHERE clave='b')::uuid;
-- Un inicio de sesión (columnas ajenas) no dispara la sincronización: la condición WHEN lo filtra.
UPDATE auth.users SET last_sign_in_at=now() WHERE id=(SELECT valor FROM s_ctx WHERE clave='a')::uuid;
DELETE FROM auth.users WHERE id=(SELECT valor FROM s_ctx WHERE clave='c')::uuid;
RESET SESSION AUTHORIZATION;
DO $s$
DECLARE a text:=(SELECT valor FROM s_ctx WHERE clave='a'); b text:=(SELECT valor FROM s_ctx WHERE clave='b');
 c text:=(SELECT valor FROM s_ctx WHERE clave='c');
BEGIN
 IF (SELECT correo_acceso FROM identidad.usuario WHERE sujeto_externo=a) NOT LIKE 'ana.nueva.%' THEN RAISE EXCEPTION 'SB14: cambio de correo'; END IF;
 IF (SELECT estado FROM identidad.usuario WHERE sujeto_externo=b)<>'bloqueado' THEN RAISE EXCEPTION 'SB14: bloqueo'; END IF;
 IF (SELECT estado FROM identidad.usuario WHERE sujeto_externo=c)<>'inactivo'
    OR NOT EXISTS(SELECT 1 FROM identidad.persona p JOIN identidad.usuario u ON u.persona_id=p.id WHERE u.sujeto_externo=c) THEN
   RAISE EXCEPTION 'SB14: la baja debe inactivar la cuenta y conservar la persona';
 END IF;
 RAISE NOTICE 'SB14 OK: cambio de correo, bloqueo y baja sincronizados sin borrar historia';
END $s$;
SET SESSION AUTHORIZATION st_backend;
DO $s$ BEGIN
 IF identidad.iniciar_contexto_supabase((SELECT valor FROM s_ctx WHERE clave='b')::uuid) IS NOT NULL THEN
   RAISE EXCEPTION 'SB15: cuenta bloqueada en Auth conserva identidad';
 END IF;
 RAISE NOTICE 'SB15 OK: cuenta bloqueada en Supabase Auth pierde la identidad en la base';
END $s$;
RESET SESSION AUTHORIZATION;

-- Una cuenta real de Supabase con rol administrador ve lo que su rol permite (RF-32, RF-42).
DO $s$
DECLARE a uuid:=(SELECT valor FROM s_ctx WHERE clave='a'); u bigint; r bigint;
BEGIN
 SELECT id INTO STRICT u FROM identidad.usuario WHERE sujeto_externo=a::text;
 SELECT id INTO STRICT r FROM identidad.rol WHERE codigo='administrador';
 PERFORM set_config('app.usuario_id','',true);
 CALL identidad.asignar_rol(u,r);
END $s$;
SET SESSION AUTHORIZATION st_backend;
DO $s$ BEGIN
 PERFORM identidad.iniciar_contexto_supabase((SELECT valor FROM s_ctx WHERE clave='a')::uuid);
 IF (SELECT count(*) FROM comercial.pedido)<2 OR (SELECT count(*) FROM identidad.persona)<2 THEN
   RAISE EXCEPTION 'SB16: el administrador no ve pedidos ni personas de otros clientes';
 END IF;
 RAISE NOTICE 'SB16 OK: cuenta de Supabase con rol administrador accede según sus permisos';
END $s$;
RESET SESSION AUTHORIZATION;
ROLLBACK;
\echo PRUEBAS DE INTEGRACION SUPABASE SB01-SB16 TERMINADAS SIN ERROR
