// Errores HTTP propios y traducción de los errores de PostgreSQL a respuestas claras.
export class ErrorHttp extends Error {
  constructor(estado, mensaje) {
    super(mensaje);
    this.estado = estado;
  }
}

// Códigos de PostgreSQL que usan las reglas de negocio de la base.
const MAPA_PG = {
  '42501': [403, null, 'No tienes permiso para esta operación'],
  '28000': [401, null, 'Identidad inválida'],
  '23514': [409, 'negocio'],          // regla de negocio (estado, stock, transición no permitida…)
  '22023': [400, 'negocio'],          // parámetro inválido
  '22004': [400, 'negocio'],
  'P0001': [400, 'negocio'],          // RAISE EXCEPTION sin código
  'P0002': [404, null, 'No encontrado'],
  '23502': [400, null, 'Falta un dato obligatorio'],
  '23505': [409, null, 'El registro ya existe'],
  '23503': [409, null, 'El registro está relacionado con otros datos'],
  '23001': [409, null, 'El registro está relacionado con otros datos'],
  '22P02': [400, null, 'Formato de dato inválido'],
};

// Restricciones CHECK de las tablas. Cuando una regla de la base se viola por una restricción (y no por
// un RAISE de un procedimiento), PostgreSQL da un mensaje técnico en inglés: aquí se traduce.
const RESTRICCIONES = {
  ck_persona_contacto: 'Deja al menos un correo o un teléfono de contacto.',
  ck_solicitud_cotizacion_contacto: 'Deja al menos un correo o un teléfono de contacto.',
};

export function manejadorErrores(err, req, res, _next) {
  if (err instanceof ErrorHttp) {
    return res.status(err.estado).json({ error: err.message });
  }
  if (err?.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'JSON inválido' });
  }
  if (err?.code === '23514' && err.constraint_name) {
    console.warn(`[${new Date().toISOString()}] Restricción ${err.constraint_name} en ${req.method} ${req.originalUrl}`);
    return res.status(400).json({
      error: RESTRICCIONES[err.constraint_name] ?? 'Los datos enviados no cumplen las reglas del sistema. Revísalos e inténtalo de nuevo.',
      codigo: err.code,
    });
  }
  const mapeo = err?.code ? MAPA_PG[err.code] : null;
  if (mapeo) {
    const [estado, tipo, generico] = mapeo;
    // Los mensajes de reglas de negocio de la base están escritos para el usuario final.
    return res.status(estado).json({ error: tipo === 'negocio' ? err.message : generico, codigo: err.code });
  }
  console.error(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl}`, err);
  return res.status(500).json({ error: 'Error interno del servidor' });
}
