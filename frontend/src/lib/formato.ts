export function formatoPrecio(valor: string | number, moneda = 'COP'): string {
  const n = Number(valor);
  if (!Number.isFinite(n)) return '';
  try {
    return new Intl.NumberFormat('es-CO', { style: 'currency', currency: moneda, maximumFractionDigits: 0 }).format(n);
  } catch {
    return `${moneda} ${n.toLocaleString('es-CO')}`;
  }
}

export const formatoNumero = (n: number) => n.toLocaleString('es-CO');
