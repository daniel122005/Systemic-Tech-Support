# Brief de diseño del frontend — Systemic Tech & Support

## Referencias
- Logo: `assets/logo-systemic.jpg` (cubo isométrico con pistas de circuito + "SYSTEMIC · TECH & SUPPORT").
- Maqueta actual de la página de inicio: `assets/referencia-inicio.png`. **Es solo el punto de partida**: queremos algo **más llamativo, moderno y con muy buenas animaciones**, manteniendo la estructura (menú, hero con logo, botones, cifras, WhatsApp flotante).

## Identidad visual
- Paleta tomada del logo:
  - Azul noche (fondo): `#011631` y variante `#04203F`
  - Azul profundo: `#0E4E7A` · Azul medio: `#0F6B92`
  - Turquesa/cian de acento: `#08C6C4` (y brillo `#22E3E0` para glow)
  - Blanco hueso para texto: `#EEF0EF` · gris secundario `#9FB3C8`
- Estética: tecnológica, "circuitos que se encienden", oscura con brillos cian; limpia y profesional (es una empresa real, debe inspirar confianza).
- Tipografía sugerida: títulos con una geométrica fuerte (p. ej. "Sora" o "Space Grotesk" en 700–800, mayúsculas en el hero); texto "Inter"; etiquetas técnicas "JetBrains Mono" con espaciado amplio.

## Stack
React + Vite + TypeScript, Tailwind CSS, **Framer Motion** (animaciones), React Router, `@supabase/supabase-js` (solo Auth), consumo del backend en `http://localhost:3000/api` (variable `VITE_API_URL`). El frontend solo usa `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY` (clave pública).

## Animaciones deseadas (llamativas pero elegantes)
- **Hero:** el cubo del logo flotando suavemente con halo cian pulsante; líneas de circuito SVG que se "dibujan" (stroke-dashoffset) desde el cubo hacia los bordes y nodos que se encienden en secuencia; fondo con rejilla/partículas sutiles con parallax al mover el mouse.
- Título "SOPORTE / TÉCNICO / INTEGRAL" apareciendo palabra por palabra (stagger) con un barrido de brillo sobre "TÉCNICO".
- Cifras que cuentan hacia arriba al entrar en pantalla.
- Secciones que aparecen al hacer scroll (fade + slide, stagger en tarjetas).
- Tarjetas de servicios/productos con efecto tilt 3D leve y borde con gradiente animado al pasar el mouse.
- Menú con indicador deslizante bajo el ítem activo; header que se compacta y difumina (backdrop-blur) al hacer scroll.
- Botón de WhatsApp flotante con pulso suave.
- Transiciones entre páginas.
- **Accesibilidad obligatoria:** respetar `prefers-reduced-motion` (desactivar animaciones grandes), buen contraste, foco visible, navegación por teclado, responsive desde 360 px.
- Rendimiento: animar solo `transform` y `opacity`; nada de librerías pesadas de 3D para el hero salvo que se justifique.

## Páginas
1. **Inicio:** hero, servicios destacados, productos destacados (desde `/api/productos`), proceso de reparación en pasos, desarrollo de software (casos/portafolio), testimonios, llamado a la acción, footer.
2. **Productos:** catálogo con búsqueda y filtros (texto, categoría, precio), detalle, carrito (funciona sin cuenta).
3. **Servicios / Reparaciones:** servicios técnicos (`/api/servicios`), formulario para solicitar reparación o mantenimiento y elegir fecha (`/api/horarios`).
4. **Desarrollo:** qué hacemos, formulario para solicitar un proyecto de software.
5. **Contacto:** formulario, WhatsApp, ubicación, horarios.
6. **Ingresar / Registrarse / Recuperar contraseña** (Supabase Auth).
7. **Mi cuenta:** perfil, pedidos, cotizaciones (aceptar/rechazar), proyectos con avance, facturas, historial, notificaciones.

## Contenido
- No inventar datos del negocio. Las cifras de la maqueta ("+1.200 clientes", "+8 años", "100% garantía") y cualquier testimonio deben confirmarse; mientras tanto usar `[DATO REAL PENDIENTE]`.
- Textos en español de Colombia, tono cercano y profesional.

## Primera tarea sugerida para Claude Code
Crear `frontend/` con Vite + React + TS + Tailwind + Framer Motion, configurar la paleta y fuentes, y construir **la página de Inicio completa** con las animaciones del hero, consumiendo `/api/productos` para "productos destacados". Mostrar cómo ejecutarlo (`npm run dev`).
