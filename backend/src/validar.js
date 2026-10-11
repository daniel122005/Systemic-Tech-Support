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

const RE_CORREO = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const RE_TELEFONO = /^\+?\d{7,15}$/;

// Correo en minúsculas y con formato válido (null si es opcional y viene vacío).
export function correo(valor, nombre = 'correo', { opcional = true } = {}) {
  const t = texto(valor, nombre, { opcional, max: 200 });
  if (t === null) return null;
  const c = t.toLowerCase();
  if (!RE_CORREO.test(c)) throw new ErrorHttp(400, 'Escribe un correo válido');
  return c;
}

// Teléfono solo con dígitos (se quitan espacios, guiones y paréntesis); admite + al inicio.
export function telefono(valor, nombre = 'teléfono', { opcional = true } = {}) {
  const t = texto(valor, nombre, { opcional, max: 30 });
  if (t === null) return null;
  const n = t.replace(/[\s()-]/g, '');
  if (!RE_TELEFONO.test(n)) throw new ErrorHttp(400, 'Escribe un teléfono válido (solo números, de 7 a 15 dígitos)');
  return n;
}

// Escapa % y _ para búsquedas con ILIKE.
export function patronBusqueda(t) {
  return t === null ? null : `%${t.replace(/[\\%_]/g, '\\$&')}%`;
}
