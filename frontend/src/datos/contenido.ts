// Contenido del negocio en un solo lugar.
// Regla del proyecto: NO inventar datos. Todo lo que esté en null o con PENDIENTE
// se muestra como "[DATO REAL PENDIENTE]" hasta que la empresa lo confirme.

export const PENDIENTE = '[DATO REAL PENDIENTE]';

/** Número de WhatsApp: NO va aquí, va en frontend/.env → VITE_WHATSAPP_NUMERO=57XXXXXXXXXX (solo dígitos). */
export const whatsappNumero: string = (import.meta.env.VITE_WHATSAPP_NUMERO ?? '').replace(/\D/g, '');
export const whatsappUrl = whatsappNumero
  ? `https://wa.me/${whatsappNumero}?text=${encodeURIComponent('Hola, Systemic Tech & Support. Quiero más información.')}`
  : null;

export interface Cifra {
  /** Valor numérico real. Mientras sea null se muestra el marcador pendiente. */
  valor: number | null;
  prefijo?: string;
  sufijo?: string;
  etiqueta: string;
}

// La maqueta mostraba "+1.200 clientes", "+8 años" y "100% garantía": deben confirmarse antes de publicarlas.
export const cifras: Cifra[] = [
  { valor: null, prefijo: '+', etiqueta: 'Clientes atendidos' },
  { valor: null, prefijo: '+', sufijo: ' años', etiqueta: 'De experiencia' },
  { valor: null, sufijo: '%', etiqueta: 'Garantía' },
];

// ▼▼ DATOS DE CONTACTO: reemplaza cada null por el dato real entre comillas. ▼▼
// Ejemplo: telefono: '+57 300 000 0000',
// Lo que siga en null se muestra como [DATO REAL PENDIENTE] en el pie de página.
export const contacto = {
  telefono: '+57 312 4860459' as string | null,
  correo: 'SystemicTech@gmail.com' as string | null,
  ciudad: 'Florencia, Caquetá' as string | null,
  direccion: null as string | null, // 'Calle ... # ... - ...'
  horario: 'Lun a Vie 8:00 a. m. – 6:00 p. m. · Sáb 9:00 a. m. – 1:00 p. m.' as string | null,
};

export const testimonios: { nombre: string | null; cargo: string | null; texto: string | null }[] = [
  { nombre: null, cargo: null, texto: null },
  { nombre: null, cargo: null, texto: null },
  { nombre: null, cargo: null, texto: null },
];

export const casosDesarrollo: { titulo: string | null; descripcion: string | null; etiquetas: string[] }[] = [
  { titulo: null, descripcion: null, etiquetas: [] },
  { titulo: null, descripcion: null, etiquetas: [] },
  { titulo: null, descripcion: null, etiquetas: [] },
];
