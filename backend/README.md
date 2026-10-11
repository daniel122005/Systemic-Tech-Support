# Systemic Tech & Support — Backend (Node.js + Express)

API de la plataforma. Se conecta a la base de datos en Supabase con el usuario limitado **st_backend** y usa **Supabase Auth** para las sesiones.

## Arrancar en VS Code (primera vez)

1. Abre la carpeta `systemic-tech` en VS Code y una terminal (**Terminal → New Terminal**).
2. Entra al backend: `cd backend`.
3. Instala las dependencias:
   ```
   npm install
   ```
4. Crea tu archivo de configuración: copia `.env.example` y renombra la copia a **`.env`**. Luego llena:
   - `DATABASE_URL`: cambia `PON_AQUI_LA_CONTRASEÑA_DE_ST_BACKEND` por la contraseña que le pusiste a st_backend con `\password st_backend`.
   - `SUPABASE_ANON_KEY`: en Supabase → **Project Settings → API Keys** → copia la clave **anon / publishable**. **Nunca** la `service_role` / `secret`. El backend no arranca si la clave no tiene formato válido.
   - `TRUST_PROXY`: `0` en desarrollo. Solo `1` si el backend queda detrás de un proxy o hosting que añade `X-Forwarded-For` (si no, cualquiera podría falsear su IP y saltarse los límites).
5. Verifica la conexión (no modifica nada):
   ```
   npm run verificar
   ```
   Debe terminar en **`CONEXION VERIFICADA`**.
6. Enciende el servidor:
   ```
   npm run dev
   ```
   Abre en el navegador http://localhost:3000/api/salud y http://localhost:3000/api/productos

Para probar las rutas cómodamente instala la extensión **REST Client** (de Huachao Mao), abre `peticiones.http` y dale clic a **Send Request**.

## Estructura

```
src/
  server.js        Arranca el servidor
  app.js           Express: seguridad (helmet, CORS), rutas y errores
  config.js        Lee y valida .env (se niega a arrancar con el usuario postgres, la service_role o una clave inválida)
  db.js            Conexión y conIdentidad(): identidad del usuario en cada transacción
  auth.js          Verifica el token de Supabase Auth (Authorization: Bearer ...); recuerda tokens válidos 60 s
  errores.js       Traduce errores de la base a respuestas HTTP claras (incluye restricciones CHECK)
  validar.js       Validación de entradas (textos, números, correo, teléfono)
  rutas/
    salud.js       GET /api/salud
    catalogo.js    Productos, categorías, servicios, horarios (público)
    carrito.js     Carrito y compra (visitante y registrado)
    cuenta.js      Perfil, pedidos, cotizaciones, proyectos, facturas, historial, notificaciones
    cursos.js      Interés en cursos (fase 1, sin tablas propias)
  limite.js        Límite de envíos por IP para altas públicas
scripts/verificar-conexion.js
```

## Reglas de oro (léanlas todos los del equipo)

1. **Toda consulta pasa por `conIdentidad(...)`.** Ella fija quién es el usuario dentro de la transacción; sin eso la base no muestra datos privados (y así debe ser).
2. **No se escribe directo en las tablas** (`INSERT/UPDATE/DELETE`): st_backend no tiene permiso. Se usan los **procedimientos** de la base (`CALL comercial.confirmar_pedido(...)`, etc.). La lista completa está en `programacion_y_objetos.md` y `api_procedimientos.json` del paquete de la base.
3. **Parámetros siempre con `${variable}`** dentro de `tx\`...\``: postgres.js los envía separados del SQL (sin inyección SQL). Nunca construyas SQL concatenando texto.
4. **Nunca confíes en un id de usuario enviado por el navegador.** La identidad sale del token verificado.
5. **`.env` nunca se sube a GitHub** (lo excluye el `.gitignore` de la raíz).
6. **Altas públicas sin cuenta = límite por IP** (`limitePorIp` de `src/limite.js`): la base confía en el backend para frenar el abuso.

Ejemplo de una ruta nueva:

```js
r.get('/mis-solicitudes', async (req, res) => {
  res.json(await conIdentidad({ auth: req.auth }, (tx) => tx`
    select id, codigo, estado, created_at from servicios.solicitud_servicio order by created_at desc`));
});
```

## Rutas disponibles

| Método y ruta | Sesión | Qué hace |
|---|---|---|
| GET `/api/salud` | No | Estado del backend y de la base |
| GET `/api/productos?q=&categoria=&precio_min=&precio_max=&limite=&desde=` | No | Catálogo con búsqueda y filtros |
| GET `/api/productos/:id` | No | Detalle con imágenes |
| GET `/api/categorias` · `/api/servicios` · `/api/horarios` | No | Catálogos públicos |
| GET `/api/carrito` | Opcional | Ver carrito (visitante por cookie segura, o del cliente) |
| POST `/api/carrito/items` `{producto_id, cantidad}` | Opcional | Agregar o cambiar cantidad (0 elimina). Máx. 20 carritos nuevos de visitante por IP/hora |
| DELETE `/api/carrito/items/:producto_id` | Opcional | Quitar producto |
| POST `/api/carrito/comprar` | Opcional | Cliente: pedido confirmado. Visitante `{nombres, apellidos, correo, telefono}`: pedido borrador (correo/teléfono validados; máx. 5 por IP cada 15 min) |
| POST `/api/cursos/interes` `{tema, modalidad?, mensaje?, nombres?, apellidos?, correo?, telefono?}` | Opcional | Interés en un curso (fase 1). Se guarda con `comercial.solicitar_cotizacion` y la necesidad empieza por `[CURSO]`. Máx. 5 envíos válidos por IP cada 15 min |
| GET / PUT `/api/cuenta/yo` | Sí | Perfil y roles / actualizar perfil (exige al menos un correo o teléfono) |
| GET `/api/cuenta/pedidos` · `/api/cuenta/pedidos/:id` | Sí | Pedidos propios y su detalle |
| GET `/api/cuenta/cotizaciones` | Sí | Cotizaciones vigentes propias |
| POST `/api/cuenta/cotizaciones/versiones/:id/respuesta` `{aceptar, comentario}` | Sí | Aceptar o rechazar |
| GET `/api/cuenta/proyectos` · `/facturas` · `/historial` · `/notificaciones` | Sí | Consultas del cliente |
| POST `/api/cuenta/notificaciones/:id/leida` | Sí | Marcar notificación leída |

Las rutas `/api/cuenta/*` muestran lo que la cuenta puede ver según la base: para un cliente, solo lo suyo. Las rutas del **panel administrativo** (personal) se construyen aparte.

## Cómo inicia sesión el frontend

El frontend usa `@supabase/supabase-js` (`supabase.auth.signUp`, `signInWithPassword`, `resetPasswordForEmail`…). Al iniciar sesión obtiene `session.access_token` y lo envía en cada petición:

```
Authorization: Bearer <access_token>
```

Al registrarse, la base crea automáticamente la persona, el usuario y el cliente. La cuenta queda habilitada cuando el usuario confirma su correo.

## Estado

Probado contra una réplica con los permisos de Supabase: catálogo, filtros, carrito de visitante con cookie segura y compra, registro por Supabase Auth, perfil, compra de cliente con reserva de inventario, aislamiento entre clientes, sobreventa rechazada y errores 400/401/403/404. Falta probarlo contra tu proyecto real (`npm run verificar`).
