# Systemic Tech & Support — contexto para Claude Code

Lee este archivo completo antes de proponer o escribir código. Responde siempre en **español claro**.

## Qué es el proyecto
**Systemic Tech & Support** es una empresa colombiana real de desarrollo de software y soporte técnico. Esta es su **plataforma web de negocio** (no es un proyecto académico): venta de productos tecnológicos, servicios técnicos (reparaciones y mantenimientos con agenda), cotizaciones, solicitudes y seguimiento de proyectos de software, mensajería con clientes, facturas y panel administrativo. Los requerimientos son RF-01 a RF-42 (ver `docs/CONTEXTO_PROYECTO.md`).

Regla de negocio clave: **los visitantes pueden ver el catálogo, comprar y pedir servicios o cotizaciones SIN crear cuenta**. La cuenta es opcional y da seguimiento e historial.

## Estructura de este workspace
```
systemic-tech/
  CLAUDE.md                 ← este archivo
  docs/                     ← contexto del proyecto y brief de diseño
  assets/                   ← logo y referencia visual
  systemic-backend/         ← API Node.js + Express (YA EXISTE, funcionando)
  database/systemic_tech_v2/ ← scripts SQL, modelo, diccionario de datos, migraciones Supabase
  frontend/                 ← (POR CREAR) sitio web React
```

## Estado actual (2026-10-09)
- **Base de datos: TERMINADA y desplegada.** PostgreSQL 17 en Supabase, proyecto `systemic-tech` (ref `fwscfaxsashkottfwwcl`, región us-east-2). 62 tablas en 7 esquemas (`identidad`, `inventario`, `comercial`, `servicios`, `proyectos`, `comunicacion`, `auditoria`), RLS en todas, auditoría, historiales inmutables, ~70 procedimientos de negocio. Verificada en local (111 pruebas) y en Supabase. Tiene datos ficticios de prueba (proyecto de desarrollo).
- **Autenticación:** Supabase Auth (registro, login, recuperación). Un trigger en `auth.users` crea automáticamente `persona`, `usuario` y `cliente`. La cuenta queda activa cuando el usuario confirma su correo.
- **Backend: base creada** en `systemic-backend/` (Express 5, postgres.js, supabase-js). Rutas de catálogo, carrito/compra (visitante y registrado) y área del cliente. Probado contra una réplica de Supabase.
- **Frontend: en curso** en `frontend/` (ver `frontend/README.md`). Hecho: Inicio con hero (cubo 3D en CSS), header/footer, login/registro/recuperación con Supabase Auth, "Mi cuenta" (perfil vía `/api/cuenta/yo`) y Cursos (fase 1). Pendiente: Productos, Servicios/Reparaciones, Desarrollo, Contacto y el resto de "Mi cuenta".
- **Cursos — fase 1 (acordada):** página `/cursos` donde los clientes dejan su interés (con o sin cuenta). Sin cambios en la base: `POST /api/cursos/interes` llama a `comercial.solicitar_cotizacion` con la necesidad prefijada `[CURSO] ` (así se filtrarán en el panel administrativo). **Fase 2** (cuando se oferten de verdad): esquema `formacion` (curso, solicitud_curso, historial) con migración nueva y revisada.

## Arquitectura y reglas que NO se pueden romper
1. **El navegador nunca habla directo con las tablas.** Flujo: Frontend → Backend (Express) → PostgreSQL. La API REST de Supabase NO expone los esquemas del negocio (a propósito). El frontend usa Supabase **solo para Auth** (y más adelante Storage).
2. **El backend se conecta con el usuario limitado `st_backend`**, nunca con `postgres`. `st_backend` solo puede leer (con RLS) y ejecutar procedimientos.
3. **Toda consulta del backend pasa por `conIdentidad({ auth: req.auth }, tx => ...)`** (en `systemic-backend/src/db.js`). Esa función llama a `identidad.iniciar_contexto_supabase(sub)` y la base aplica la seguridad por fila. Sin identidad = visitante (solo datos públicos).
4. **Nada de INSERT/UPDATE/DELETE directos.** Toda escritura usa los procedimientos de la base (`CALL comercial.confirmar_pedido(...)`, `CALL servicios.solicitar_servicio(...)`, etc.). Lista y firmas: `database/systemic_tech_v2/local_postgresql/programacion_y_objetos.md` y `api_procedimientos.json`.
5. **Parámetros siempre enlazados** con postgres.js (`tx\`... ${valor} ...\``). Nunca concatenar SQL.
6. **La identidad sale del JWT verificado** (`Authorization: Bearer <access_token>` de Supabase), nunca de un id enviado por el navegador.
7. **Secretos:** solo en `.env` (está en `.gitignore`). Nunca escribir contraseñas, la `service_role` key ni el `.env` en código, commits o chats. El frontend solo usa la clave pública `anon/publishable`.
8. **No modificar la estructura de la base** sin un script de migración nuevo y revisado. No editar datos desde el Table Editor de Supabase.
9. Los mensajes de error de la base (códigos 23514, 22023, P0001) ya están escritos para el usuario final; `errores.js` los traduce a HTTP.

## Cómo se ejecuta
- Backend: `cd systemic-backend` → `npm install` → crear `.env` desde `.env.example` (DATABASE_URL con la contraseña de st_backend y SUPABASE_ANON_KEY) → `npm run verificar` (debe decir CONEXION VERIFICADA) → `npm run dev` → http://localhost:3000/api/salud
- Conexión a Supabase: Session pooler `aws-0-us-east-2.pooler.supabase.com:5432`, usuario `st_backend.fwscfaxsashkottfwwcl`. (La conexión directa no funciona en la red del equipo: no hay IPv6.)

## Qué sigue (orden acordado)
1. Terminar de configurar `.env` del backend y verificar la conexión real.
2. **Frontend** en `frontend/` (React + Vite + Tailwind + Framer Motion + supabase-js), siguiendo `docs/DISENO_FRONTEND.md`. Primero: sitio público (Inicio, Productos, Servicios, Reparaciones, Desarrollo, Contacto) consumiendo el backend; luego login/registro y "Mi cuenta".
3. Backend por módulos: solicitudes de servicio y agenda → cotizaciones → solicitudes de desarrollo y proyectos → mensajería y archivos (Supabase Storage) → panel administrativo → notificaciones por correo.
4. Antes de lanzar con clientes reales: proyecto Supabase de producción (plan Pro) limpio con `database/systemic_tech_v2/supabase/subir_a_supabase.sql`, dominio, HTTPS y despliegue.

## Forma de trabajar
- Cambios pequeños y verificables; explicar qué se hizo y cómo probarlo.
- Antes de crear una ruta nueva, revisar qué procedimiento de la base corresponde y sus reglas.
- No inventar datos del negocio (cifras, testimonios, clientes): dejar marcadores claros `[DATO REAL PENDIENTE]`.
