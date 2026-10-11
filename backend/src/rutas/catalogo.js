// Catálogo público: productos, categorías, servicios y horarios (RF-01, RF-07, RF-08, RF-13, RF-16).
import { Router } from 'express';
import { entero, numero, texto, patronBusqueda } from '../validar.js';
import { ErrorHttp } from '../errores.js';

export function rutasCatalogo({ conIdentidad, config }) {
  const r = Router();
  // Las imágenes del catálogo se guardan en el bucket público "catalogo" de Supabase Storage.
  const urlImagen = (clave) => (clave ? `${config.supabaseUrl}/storage/v1/object/public/catalogo/${encodeURI(clave)}` : null);

  // GET /api/productos?q=ssd&categoria=1&precio_min=10000&precio_max=200000&limite=24&desde=0
  r.get('/productos', async (req, res) => {
    const patron = patronBusqueda(texto(req.query.q, 'q', { opcional: true, max: 100 }));
    const categoria = entero(req.query.categoria, 'categoria', { opcional: true });
    const min = numero(req.query.precio_min, 'precio_min', { opcional: true });
    const max = numero(req.query.precio_max, 'precio_max', { opcional: true });
    const limite = Math.min(entero(req.query.limite, 'limite', { opcional: true }) ?? 24, 100);
    const desde = entero(req.query.desde, 'desde', { opcional: true, min: 0 }) ?? 0;
    const filas = await conIdentidad({ auth: req.auth }, (tx) => tx`
      select v.id, v.sku, v.nombre, v.descripcion, v.categoria_id, v.categoria, v.unidad,
             v.precio_vigente, v.moneda, v.stock_disponible,
             (select a.clave_objeto from inventario.producto_imagen i
                join comunicacion.archivo a on a.id = i.archivo_id
               where i.producto_id = v.id and i.principal limit 1) as imagen
        from inventario.v_productos_disponibles v
       where (${patron}::text is null or v.nombre ilike ${patron} or v.descripcion ilike ${patron})
         and (${categoria}::bigint is null or v.categoria_id = ${categoria})
         and (${min}::numeric is null or v.precio_vigente >= ${min})
         and (${max}::numeric is null or v.precio_vigente <= ${max})
       order by v.nombre
       limit ${limite} offset ${desde}`);
    res.json(filas.map((f) => ({ ...f, imagen: urlImagen(f.imagen) })));
  });

  // GET /api/productos/:id  (detalle con todas sus imágenes)
  r.get('/productos/:id', async (req, res) => {
    const id = entero(req.params.id, 'id');
    const resultado = await conIdentidad({ auth: req.auth }, async (tx) => {
      const [producto] = await tx`select * from inventario.v_productos_disponibles where id = ${id}`;
      if (!producto) return null;
      const imagenes = await tx`
        select a.clave_objeto, i.texto_alternativo, i.principal, i.orden
          from inventario.producto_imagen i join comunicacion.archivo a on a.id = i.archivo_id
         where i.producto_id = ${id} order by i.orden`;
      return { ...producto, imagenes: imagenes.map((i) => ({ url: urlImagen(i.clave_objeto), texto_alternativo: i.texto_alternativo, principal: i.principal })) };
    });
    if (!resultado) throw new ErrorHttp(404, 'Producto no encontrado o no disponible');
    res.json(resultado);
  });

  // GET /api/categorias
  r.get('/categorias', async (req, res) => {
    res.json(await conIdentidad({ auth: req.auth }, (tx) => tx`
      select id, nombre, descripcion from inventario.categoria where activa order by nombre`));
  });

  // GET /api/servicios  (servicios técnicos publicados)
  r.get('/servicios', async (req, res) => {
    res.json(await conIdentidad({ auth: req.auth }, (tx) => tx`
      select id, codigo, nombre, descripcion, modalidad, duracion_estimada_min, precio_referencia, moneda
        from servicios.servicio_ofrecido where publicado order by nombre`));
  });

  // GET /api/horarios  (franjas de técnicos disponibles para agendar)
  r.get('/horarios', async (req, res) => {
    res.json(await conIdentidad({ auth: req.auth }, (tx) => tx`
      select disponibilidad_id, tecnico_id, inicio, fin from servicios.v_horarios_disponibles
       where fin > now() order by inicio limit 100`));
  });

  return r;
}
