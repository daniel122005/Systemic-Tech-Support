# Systemic Tech & Support — plataforma web

Plataforma de negocio de **Systemic Tech & Support** (Colombia): venta de productos tecnológicos, servicios
técnicos con agenda, cotizaciones, proyectos de software, cursos, mensajería con clientes, facturas y panel
administrativo. Los visitantes pueden comprar y pedir servicios **sin crear cuenta**.

## Estructura

| Carpeta | Contenido |
|---|---|
| `frontend/` | Sitio web: React + Vite + TypeScript + Tailwind + Framer Motion. Supabase solo para iniciar sesión. |
| `backend/` | API Node.js + Express. Única puerta a la base de datos (usuario limitado `st_backend`). |
| `database/` | Migraciones de Supabase (PostgreSQL 17), scripts SQL, pruebas y documentación del modelo. |
| `docs/` | Contexto del proyecto, requerimientos RF-01 a RF-42 y guía de diseño. |
| `assets/` | Logo original de la marca. |

Flujo: **navegador → backend → PostgreSQL (Supabase)**. El navegador nunca consulta las tablas directamente.

## Arrancar en local

Requisitos: Node.js 20 o superior.

```bash
# Terminal 1 — backend (http://localhost:3000/api/salud)
cd backend
npm install
cp .env.example .env      # completar DATABASE_URL y SUPABASE_ANON_KEY
npm run verificar         # debe decir CONEXION VERIFICADA
npm run dev

# Terminal 2 — frontend (http://localhost:5173)
cd frontend
npm install
cp .env.example .env      # VITE_SUPABASE_ANON_KEY = la misma clave anon del backend
npm run dev
```

Los archivos `.env` nunca se suben al repositorio. Detalles en `backend/README.md`, `frontend/README.md` y `database/README.md`.
