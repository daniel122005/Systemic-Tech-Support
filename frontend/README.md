# Systemic Tech & Support — Frontend (React + Vite)

Sitio web público. Habla **solo con el backend** (carpeta `backend/`), nunca directo con la base de datos.
Stack: React 19 · Vite · TypeScript · Tailwind CSS v4 · Framer Motion · React Router.

## Ejecutar (desarrollo)

Se necesitan **dos terminales** en VS Code (Terminal → New Terminal; el botón `+` abre otra).

**Terminal 1 — backend**
```
cd backend
npm run dev
```
Debe quedar escuchando en http://localhost:3000 (prueba: http://localhost:3000/api/salud).

**Terminal 2 — frontend**
```
cd frontend
npm install        (solo la primera vez)
npm run dev
```
Abre http://localhost:5173

El archivo `.env` del frontend ya existe (copiado de `.env.example`). Solo lleva valores **públicos**:
- `VITE_API_URL` — dirección del backend (por defecto `http://localhost:3000/api`).
- `VITE_WHATSAPP_NUMERO` — número de WhatsApp con indicativo, solo dígitos (ej. `57` + número). Mientras esté vacío, los botones de WhatsApp llevan a /contacto.
- `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY` — para iniciar sesión. La clave es la **anon / publishable** (la misma `SUPABASE_ANON_KEY` del backend). Nunca la `service_role` / `secret`: el frontend se niega a usarla.

## Inicio de sesión (Supabase Auth)
Páginas: `/ingresar`, `/registro`, `/recuperar`, `/nueva-contrasena`, `/cuenta` (privada).
El navegador usa Supabase **solo para Auth**; los datos de la cuenta se piden al backend con
`Authorization: Bearer <access_token>`.

Configuración una sola vez en Supabase (Authentication → URL Configuration):
- **Site URL:** `http://localhost:5173` (en producción, el dominio real).
- **Redirect URLs:** agregar `http://localhost:5173/**`.

Sin esto, los enlaces de confirmación y de recuperación del correo no regresan al sitio.
El correo de prueba de Supabase tiene un límite bajo de envíos por hora; para producción configurar un SMTP propio.

El registro guarda en los metadatos del usuario la aceptación de la política de datos
(`acepta_tratamiento_datos`, fecha y versión) porque la base aún no tiene un campo para eso.
Esos metadatos los puede modificar el propio usuario: sirven como constancia, no como prueba firme.

En Supabase (Authentication → Sign In / Providers → Email) poner la **longitud mínima de contraseña en 8**:
el formulario ya lo exige, pero sin ese ajuste alguien podría saltárselo llamando a Supabase directamente.

Si cambias el `.env`, detén el servidor (Ctrl + C) y vuelve a ejecutar `npm run dev`.

> El puerto 5173 es fijo porque el backend solo acepta peticiones de `FRONTEND_ORIGIN=http://localhost:5173`.

## Otros comandos
- `npm run build` — revisa tipos (TypeScript) y genera la versión de producción en `dist/`.
- `npm run preview` — sirve `dist/` para probarla.

## Estructura
```
src/
  main.tsx, App.tsx      Entrada, rutas y transiciones entre páginas
  index.css              Paleta del logo, fuentes y animaciones CSS (respeta prefers-reduced-motion)
  datos/contenido.ts     Datos del negocio (cifras, contacto, testimonios, portafolio) → [DATO REAL PENDIENTE]
  auth/                  Sesión (ProveedorSesion, RutaPrivada) y traducción de errores de Supabase
  lib/api.ts             Cliente del backend (envía el token de sesión)
  lib/supabase.ts        Cliente de Supabase (solo Auth)
  components/            Encabezado, pie, WhatsApp flotante, formularios, tarjetas con tilt, contador, hero/ (cubo 3D)
  secciones/             Secciones de la página de Inicio
  paginas/               Inicio, Cursos, acceso (auth/), Mi cuenta, privacidad y marcador "en construcción"
public/favicon.svg       Ícono de la pestaña (cubo de la marca)
```

## Datos pendientes
Todo lo que se ve como **[DATO REAL PENDIENTE]** se llena en `src/datos/contenido.ts`
(cifras del hero, teléfono, correo, ciudad, dirección, horario, testimonios y casos de portafolio).
El texto de la política de datos va en `src/paginas/Privacidad.tsx`.
Al poner un número real en `cifras`, el contador animado empieza a funcionar solo.
