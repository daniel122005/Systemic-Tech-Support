import { Router } from 'express';

export function rutasSalud({ conIdentidad }) {
  const r = Router();
  // GET /api/salud: comprueba que el backend llega a la base con el usuario correcto.
  r.get('/salud', async (_req, res) => {
    const [fila] = await conIdentidad({}, (tx) => tx`
      select current_user as usuario_db, now() as hora_servidor,
             (select count(*) from inventario.v_productos_disponibles)::int as productos_publicados`);
    res.json({ estado: 'ok', ...fila });
  });
  return r;
}
