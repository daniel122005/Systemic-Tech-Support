// Cliente del backend (systemic-backend). El navegador NUNCA habla directo con la base:
// todo pasa por la API Express, que aplica la seguridad.

export const API_URL: string = (import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api').replace(/\/$/, '');

export class ErrorApi extends Error {
  constructor(public estado: number, mensaje: string) {
    super(mensaje);
  }
}

type Opciones = Omit<RequestInit, 'body'> & { token?: string | null; cuerpo?: unknown };

async function pedir<T>(ruta: string, { token, cuerpo, ...init }: Opciones = {}): Promise<T> {
  let respuesta: Response;
  try {
    respuesta = await fetch(`${API_URL}${ruta}`, {
      ...init,
      body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
      credentials: 'include', // cookie segura del carrito de visitante
      headers: {
        Accept: 'application/json',
        ...(cuerpo === undefined ? {} : { 'Content-Type': 'application/json' }),
        // La identidad viaja SOLO en el token de Supabase; el backend lo verifica.
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...init.headers,
      },
    });
  } catch (e) {
    if ((e as Error).name === 'AbortError') throw e;
    throw new ErrorApi(0, 'No pudimos conectarnos con el servidor. Intenta de nuevo en unos minutos.');
  }
  const datos = await respuesta.json().catch(() => null);
  if (!respuesta.ok) throw new ErrorApi(respuesta.status, datos?.error ?? 'Ocurrió un error inesperado.');
  return datos as T;
}

/** Producto tal como lo devuelve GET /api/productos (los numeric de PostgreSQL llegan como texto). */
export interface Producto {
  id: string; // bigint: llega como texto
  sku: string;
  nombre: string;
  descripcion: string | null;
  categoria_id: string;
  categoria: string;
  unidad: string;
  precio_vigente: string | number;
  moneda: string;
  stock_disponible: string | number;
  imagen: string | null;
}

/** Perfil de GET /api/cuenta/yo. */
export interface Perfil {
  usuario_id: string;
  persona_id: string;
  cliente_id: string | null;
  nombres: string;
  apellidos: string | null;
  correo_contacto: string | null;
  telefono: string | null;
  correo_acceso: string;
  estado: string;
  roles: string[];
}

export type CambiosPerfil = Partial<Pick<Perfil, 'nombres' | 'apellidos' | 'telefono' | 'correo_contacto'>>;

/** Interés en un curso (fase 1: se guarda como solicitud de cotización con prefijo [CURSO]). */
export interface InteresCurso {
  tema: string;
  modalidad?: 'presencial' | 'virtual' | 'cualquiera' | '';
  mensaje?: string;
  nombres?: string;
  apellidos?: string;
  correo?: string;
  telefono?: string;
  /** Campo trampa anti-bots: siempre vacío para personas. */
  sitio_web?: string;
}

export const api = {
  productos: (params: { limite?: number; q?: string; categoria?: number } = {}, signal?: AbortSignal) => {
    const qs = new URLSearchParams();
    Object.entries(params).forEach(([k, v]) => v !== undefined && qs.set(k, String(v)));
    return pedir<Producto[]>(`/productos?${qs}`, { signal });
  },
  perfil: (token: string, signal?: AbortSignal) => pedir<Perfil>('/cuenta/yo', { token, signal }),
  actualizarPerfil: (token: string, cambios: CambiosPerfil) => pedir<Perfil>('/cuenta/yo', { token, method: 'PUT', cuerpo: cambios }),
  interesCurso: (datos: InteresCurso, token?: string | null) => pedir<{ mensaje: string }>('/cursos/interes', { token, method: 'POST', cuerpo: datos }),
};
