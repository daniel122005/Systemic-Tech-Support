// Carrito y compra para visitantes (sin cuenta) y clientes registrados (RF-09, RF-10).
import { Router } from 'express';
import { randomBytes, randomUUID } from 'node:crypto';
import { entero, numero, texto } from '../validar.js';
import { ErrorHttp } from '../errores.js';

const COOKIE = 'st_carrito';
const MONEDA = 'COP';
// Tasa de impuesto aplicada a la compra. 0 hasta que el negocio defina la regla fiscal (IVA, exenciones…).
const TASA_IMPUESTO = 0;

export function rutasCarrito({ conIdentidad, config }) {
  const r = Router();
  const opcionesCookie = { httpOnly: true, sameSite: 'lax', secure: config.produccion, maxAge: 30 * 24 * 3600 * 1000, path: '/api' };

  function leerCookie(req) {
    const [id, token] = String(req.cookies?.[COOKIE] || '').split(':');
    return Number.isSafeInteger(Number(id)) && token ? { id: Number(id), token } : null;
  }

  async function miCliente(tx) {
    const [fila] = await tx`
      select c.id as cliente_id, p.nombres, p.apellidos, p.correo_contacto, p.telefono
        from identidad.usuario u join identidad.persona p on p.id = u.persona_id
        join identidad.cliente c on c.persona_id = p.id
       where u.id = ${tx.usuarioId}`;
    if (!fila) throw new ErrorHttp(409, 'Tu cuenta no tiene perfil de cliente');
    return fila;
  }

  // Devuelve { id, token } del carrito abierto; si `crear`, lo crea cuando no existe.
  async function carritoActual(tx, req, res, crear) {
    if (req.auth) {
      const cliente = await miCliente(tx);
      const [abierto] = await tx`select id from comercial.carrito where cliente_id = ${cliente.cliente_id} and estado = 'abierto' order by id desc limit 1`;
      if (abierto) return { id: Number(abierto.id), token: null };
      if (!crear) return null;
      const [nuevo] = await tx`call comercial.crear_carrito(${cliente.cliente_id}, null, null)`;
      return { id: Number(nuevo.p_id), token: null };
    }
    const cookie = leerCookie(req);
    if (cookie) return cookie;
    if (!crear) return null;
    const token = randomBytes(32).toString('base64url'); // 256 bits; la base guarda solo su hash
    const [nuevo] = await tx`call comercial.crear_carrito(null, ${token}, null)`;
    const carrito = { id: Number(nuevo.p_id), token };
    res.cookie(COOKIE, `${carrito.id}:${token}`, opcionesCookie);
    return carrito;
  }

  async function contenido(tx, carrito) {
    const [fila] = await tx`select comercial.consultar_carrito(${carrito.id}, ${carrito.token}) as carrito`;
    return fila.carrito;
  }

  // GET /api/carrito
  r.get('/carrito', async (req, res) => {
    const datos = await conIdentidad({ auth: req.auth }, async (tx) => {
      const carrito = await carritoActual(tx, req, res, false);
      return carrito ? contenido(tx, carrito) : { id: null, estado: null, lineas: [] };
    });
    res.json(datos);
  });

  // POST /api/carrito/items  { "producto_id": 1, "cantidad": 2 }   (agrega o cambia la cantidad)
  r.post('/carrito/items', async (req, res) => {
    const producto = entero(req.body?.producto_id, 'producto_id');
    const cantidad = numero(req.body?.cantidad, 'cantidad', { min: 0 });
    const datos = await conIdentidad({ auth: req.auth }, async (tx) => {
      const carrito = await carritoActual(tx, req, res, true);
      await tx`call comercial.editar_carrito(${carrito.id}, ${carrito.token}, ${producto}, ${cantidad})`;
      return contenido(tx, carrito);
    });
    res.json(datos);
  });

  // DELETE /api/carrito/items/:producto_id
  r.delete('/carrito/items/:producto_id', async (req, res) => {
    const producto = entero(req.params.producto_id, 'producto_id');
    const datos = await conIdentidad({ auth: req.auth }, async (tx) => {
      const carrito = await carritoActual(tx, req, res, false);
      if (!carrito) throw new ErrorHttp(404, 'No tienes un carrito abierto');
      await tx`call comercial.editar_carrito(${carrito.id}, ${carrito.token}, ${producto}, 0)`;
      return contenido(tx, carrito);
    });
    res.json(datos);
  });

  // POST /api/carrito/comprar
  //  - Cliente registrado: crea el pedido y lo confirma (reserva inventario).
  //  - Visitante: envía { nombres, apellidos, correo, telefono }; queda como pedido borrador que el
  //    personal confirma tras verificar el contacto (regla del modelo: confirmar exige identidad verificada).
  r.post('/carrito/comprar', async (req, res) => {
    const visitante = req.auth ? null : {
      nombres: texto(req.body?.nombres, 'nombres', { max: 100 }),
      apellidos: texto(req.body?.apellidos, 'apellidos', { opcional: true, max: 100 }),
      correo: texto(req.body?.correo, 'correo', { opcional: true, max: 200 }),
      telefono: texto(req.body?.telefono, 'telefono', { opcional: true, max: 30 }),
    };
    if (visitante && !visitante.correo && !visitante.telefono) throw new ErrorHttp(400, 'Indica un correo o un teléfono de contacto');
    const resultado = await conIdentidad({ auth: req.auth }, async (tx) => {
      const carrito = await carritoActual(tx, req, res, false);
      if (!carrito) throw new ErrorHttp(404, 'No tienes un carrito abierto');
      if (req.auth) {
        const c = await miCliente(tx);
        const [p] = await tx`call comercial.convertir_carrito(${carrito.id}, null, ${c.nombres}, ${c.apellidos}, ${c.correo_contacto}, ${c.telefono}, ${MONEDA}, ${TASA_IMPUESTO}, null)`;
        await tx`call comercial.confirmar_pedido(${p.p_pedido}, ${randomUUID()}::uuid)`;
        const [pedido] = await tx`select id, numero, estado, total from comercial.v_resumen_pedidos where id = ${p.p_pedido}`;
        return pedido;
      }
      const [p] = await tx`call comercial.convertir_carrito(${carrito.id}, ${carrito.token}, ${visitante.nombres}, ${visitante.apellidos}, ${visitante.correo}, ${visitante.telefono}, ${MONEDA}, ${TASA_IMPUESTO}, null)`;
      return { id: Number(p.p_pedido), estado: 'borrador', mensaje: 'Recibimos tu pedido. Te contactaremos para confirmarlo.' };
    });
    if (!req.auth) res.clearCookie(COOKIE, { path: '/api' });
    res.status(201).json(resultado);
  });

  return r;
}
