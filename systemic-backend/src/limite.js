// Límite simple de peticiones por IP (en memoria) para las altas públicas sin cuenta.
// La base confía en el backend para validar estas altas (ver identidad.exigir_permiso),
// así que aquí se frena el abuso: bots o formularios enviados en bucle.
// Nota: en memoria vale para un solo proceso; con varias instancias habría que usar un almacén compartido.
import { ErrorHttp } from './errores.js';

export function limitePorIp({ ventanaMs, maximo, mensaje }) {
  const registros = new Map(); // ip -> { inicio, cuenta }

  // Limpieza periódica para que el mapa no crezca sin fin.
  setInterval(() => {
    const ahora = Date.now();
    for (const [ip, r] of registros) if (ahora - r.inicio > ventanaMs) registros.delete(ip);
  }, ventanaMs).unref();

  // Se llama justo antes de guardar (después de validar): los errores de escritura no cuentan.
  return function consumir(req) {
    const ip = req.ip || 'desconocida';
    const ahora = Date.now();
    const r = registros.get(ip);
    if (!r || ahora - r.inicio > ventanaMs) return void registros.set(ip, { inicio: ahora, cuenta: 1 });
    if (r.cuenta >= maximo) throw new ErrorHttp(429, mensaje);
    r.cuenta++;
  };
}
