// Verificación de sesiones de Supabase Auth.
import { createHash } from 'node:crypto';
import { createClient } from '@supabase/supabase-js';
import { ErrorHttp } from './errores.js';

// Un token ya verificado se recuerda hasta 60 s (nunca más allá de su vencimiento).
// Compromiso aceptado: una sesión cerrada en Supabase puede seguir valiendo hasta 60 s aquí.
const CACHE_MS = 60_000;
const CACHE_MAX = 1000;

function vencimientoJwt(token) {
  try {
    const carga = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8'));
    return typeof carga.exp === 'number' ? carga.exp * 1000 : null;
  } catch {
    return null;
  }
}

export function crearVerificadorSupabase(config) {
  const supabase = createClient(config.supabaseUrl, config.supabaseAnonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const cache = new Map(); // huella del token -> { usuario, vence }

  // Devuelve { sub, email } si el token es válido; null si no.
  return async function verificarToken(token) {
    const clave = createHash('sha256').update(token).digest('base64url'); // no se guarda el token en claro
    const ahora = Date.now();
    const guardado = cache.get(clave);
    if (guardado && guardado.vence > ahora) return guardado.usuario;
    cache.delete(clave);

    const { data, error } = await supabase.auth.getUser(token);
    if (error || !data?.user) return null;
    const usuario = { sub: data.user.id, email: data.user.email };

    const vence = Math.min(ahora + CACHE_MS, vencimientoJwt(token) ?? ahora + CACHE_MS);
    if (cache.size >= CACHE_MAX) cache.delete(cache.keys().next().value); // descarta el más antiguo
    cache.set(clave, { usuario, vence });
    return usuario;
  };
}

// Middleware: lee "Authorization: Bearer <token>" que envía el frontend tras iniciar sesión con Supabase.
export function autenticacion(verificarToken, { obligatoria }) {
  return async (req, _res, next) => {
    const cabecera = req.get('authorization') || '';
    const token = cabecera.startsWith('Bearer ') ? cabecera.slice(7).trim() : null;
    if (!token) {
      if (obligatoria) throw new ErrorHttp(401, 'Debes iniciar sesión');
      req.auth = null;
      return next();
    }
    const usuario = await verificarToken(token);
    if (!usuario) throw new ErrorHttp(401, 'Sesión inválida o vencida. Inicia sesión de nuevo');
    req.auth = usuario;
    next();
  };
}
