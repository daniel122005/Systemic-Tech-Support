// Área del usuario registrado (RF-05, RF-11, RF-12, RF-20, RF-21, RF-23, RF-28, RF-29, RF-31).
// Todas exigen sesión de Supabase. La seguridad real la aplica la base (RLS): un cliente solo ve lo suyo.
import { Router } from 'express';
import { entero, texto, booleano, correo, telefono } from '../validar.js';
import { ErrorHttp } from '../errores.js';

export function rutasCuenta({ conIdentidad }) {
  const r = Router();

  async function yo(tx) {
    const [fila] = await tx`
      select u.id as usuario_id, p.id as persona_id, c.id as cliente_id, p.nombres, p.apellidos,
             p.correo_contacto, p.telefono, u.correo_acceso, u.estado,
             coalesce((select array_agg(ro.codigo order by ro.codigo)
                         from identidad.usuario_rol ur join identidad.rol ro on ro.id = ur.rol_id
                        where ur.usuario_id = u.id and ur.inicia_en <= now()
                          and (ur.termina_en is null or ur.termina_en > now())), '{}') as roles
        from identidad.usuario u join identidad.persona p on p.id = u.persona_id
        left join identidad.cliente c on c.persona_id = p.id
       where u.id = ${tx.usuarioId}`;
    return fila;
  }

  // GET /api/cuenta/yo
  r.get('/yo', async (req, res) => res.json(await conIdentidad({ auth: req.auth }, yo)));

  // PUT /api/cuenta/yo  { nombres, apellidos, telefono, correo_contacto }  (el correo de acceso se cambia en Supabase Auth)
  r.put('/yo', async (req, res) => {
    const datos = await conIdentidad({ auth: req.auth }, async (tx) => {
      const actual = await yo(tx);
      const b = req.body || {};
      const nuevo = {
        nombres: b.nombres === undefined ? actual.nombres : texto(b.nombres, 'nombres', { max: 100 }),
        apellidos: b.apellidos === undefined ? actual.apellidos : texto(b.apellidos, 'apellidos', { opcional: true, max: 100 }),
        correo: b.correo_contacto === undefined ? actual.correo_contacto : correo(b.correo_contacto, 'correo de contacto'),
        telefono: b.telefono === undefined ? actual.telefono : telefono(b.telefono),
      };
      // Regla de la base (ck_persona_contacto): al menos un medio de contacto.
      if (!nuevo.correo && !nuevo.telefono) throw new ErrorHttp(400, 'Deja al menos un correo o un teléfono de contacto');
      await tx`call identidad.actualizar_perfil(${actual.persona_id}, ${nuevo.nombres}, ${nuevo.apellidos}, ${nuevo.correo}, ${nuevo.telefono})`;
      return yo(tx);
    });
    res.json(datos);
  });

  // GET /api/cuenta/pedidos
  r.get('/pedidos', async (req, res) => {
    res.json(await conIdentidad({ auth: req.auth }, async (tx) => {
      const { cliente_id } = await yo(tx);
      return tx`select * from comercial.v_resumen_pedidos where cliente_id = ${cliente_id} order by created_at desc, id desc`;
    }));
  });

  // GET /api/cuenta/pedidos/:id  (detalle + historial de estados)
  r.get('/pedidos/:id', async (req, res) => {
    const id = entero(req.params.id, 'id');
    const datos = await conIdentidad({ auth: req.auth }, async (tx) => {
      const { cliente_id } = await yo(tx);
      const [pedido] = await tx`select * from comercial.v_resumen_pedidos where id = ${id} and cliente_id = ${cliente_id}`;
      if (!pedido) return null;
      const lineas = await tx`select numero_linea, producto_id, descripcion, cantidad, unidad, precio_unitario, subtotal, impuesto_importe, total
                                from comercial.detalle_pedido where pedido_id = ${id} order by numero_linea`;
      const historial = await tx`select estado_anterior, estado_nuevo, motivo, ocurrido_en
                                   from comercial.historial_pedido where pedido_id = ${id} order by numero_evento`;
      return { ...pedido, lineas, historial };
    });
    if (!datos) throw new ErrorHttp(404, 'Pedido no encontrado');
    res.json(datos);
  });

  // GET /api/cuenta/cotizaciones  (versiones vigentes visibles para la cuenta)
  r.get('/cotizaciones', async (req, res) => {
    res.json(await conIdentidad({ auth: req.auth }, async (tx) => {
      const { persona_id } = await yo(tx);
      return tx`select v.* from comercial.v_cotizaciones_vigentes v
                  join comercial.cotizacion c on c.id = v.cotizacion_id
                  left join comercial.solicitud_cotizacion s on s.id = c.solicitud_cotizacion_id
                 where coalesce(c.persona_directa_id, s.persona_id) = ${persona_id}
                 order by v.vigente_hasta`;
    }));
  });

  // POST /api/cuenta/cotizaciones/versiones/:id/respuesta  { "aceptar": true, "comentario": "..." }
  r.post('/cotizaciones/versiones/:id/respuesta', async (req, res) => {
    const version = entero(req.params.id, 'id');
    const aceptar = booleano(req.body?.aceptar, 'aceptar');
    const comentario = texto(req.body?.comentario, 'comentario', { opcional: true, max: 1000 });
    const evidencia = `Respuesta en la plataforma por ${req.auth.email ?? req.auth.sub} el ${new Date().toISOString()}${comentario ? `: ${comentario}` : ''}`;
    await conIdentidad({ auth: req.auth }, (tx) => tx`call comercial.responder_cotizacion(${version}, ${aceptar}, ${evidencia})`);
    res.json({ version_id: version, estado: aceptar ? 'aceptada' : 'rechazada' });
  });

  // GET /api/cuenta/proyectos  (avance de proyectos de software)
  r.get('/proyectos', async (req, res) => {
    res.json(await conIdentidad({ auth: req.auth }, async (tx) => {
      const { cliente_id } = await yo(tx);
      return tx`select * from proyectos.v_avance_proyecto where cliente_id = ${cliente_id} order by id desc`;
    }));
  });

  // GET /api/cuenta/facturas
  r.get('/facturas', async (req, res) => {
    res.json(await conIdentidad({ auth: req.auth }, (tx) => tx`select * from comercial.v_facturas_cliente order by emitida_en desc nulls last`));
  });

  // GET /api/cuenta/historial  (compras, servicios, cotizaciones, proyectos y facturas)
  r.get('/historial', async (req, res) => {
    res.json(await conIdentidad({ auth: req.auth }, (tx) => tx`select * from comercial.v_historial_cliente order by fecha desc limit 200`));
  });

  // GET /api/cuenta/notificaciones  y  POST /api/cuenta/notificaciones/:id/leida
  r.get('/notificaciones', async (req, res) => {
    res.json(await conIdentidad({ auth: req.auth }, (tx) => tx`
      select id, tipo, titulo, contenido, created_at, leida_en from comunicacion.notificacion
       where destinatario_usuario_id = ${tx.usuarioId} order by created_at desc limit 50`));
  });
  r.post('/notificaciones/:id/leida', async (req, res) => {
    const id = entero(req.params.id, 'id');
    await conIdentidad({ auth: req.auth }, (tx) => tx`call comunicacion.marcar_notificacion_leida(${id})`);
    res.status(204).end();
  });

  return r;
}
