// Validaciones simples de entrada. La base vuelve a validar todo: esto solo da mensajes claros.
import { ErrorHttp } from './errores.js';

export function entero(valor, nombre, { opcional = false, min = 1 } = {}) {
  if (valor === undefined || valor === null || valor === '') {
    if (opcional) return null;
    throw new ErrorHttp(400, `Falta ${nombre}`);
  }
  const n = Number(valor);
  if (!Number.isSafeInteger(n) || n < min) throw new ErrorHttp(400, `${nombre} debe ser un entero >= ${min}`);
  return n;
}

export function numero(valor, nombre, { opcional = false, min = 0 } = {}) {
  if (valor === undefined || valor === null || valor === '') {
    if (opcional) return null;
    throw new ErrorHttp(400, `Falta ${nombre}`);
  }
  const n = Number(valor);
  if (!Number.isFinite(n) || n < min) throw new ErrorHttp(400, `${nombre} debe ser un número >= ${min}`);
  return n;
}

export function texto(valor, nombre, { opcional = false, max = 500 } = {}) {
  if (valor === undefined || valor === null || String(valor).trim() === '') {
    if (opcional) return null;
    throw new ErrorHttp(400, `Falta ${nombre}`);
  }
  const t = String(valor).trim();
  if (t.length > max) throw new ErrorHttp(400, `${nombre} supera ${max} caracteres`);
  return t;
}

export function booleano(valor, nombre) {
  if (typeof valor !== 'boolean') throw new ErrorHttp(400, `${nombre} debe ser true o false`);
  return valor;
}

// Escapa % y _ para búsquedas con ILIKE.
export function patronBusqueda(t) {
  return t === null ? null : `%${t.replace(/[\\%_]/g, '\\$&')}%`;
}
