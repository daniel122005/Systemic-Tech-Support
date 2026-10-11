// Verificación de sesiones de Supabase Auth.
import { createClient } from '@supabase/supabase-js';
import { ErrorHttp } from './errores.js';

export function crearVerificadorSupabase(config) {
  const supabase = createClient(config.supabaseUrl, config.supabaseAnonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  // Devuelve { sub, email } si el token es válido; null si no.
  return async function verificarToken(token) {
    const { data, error } = await supabase.auth.getUser(token);
    if (error || !data?.user) return null;
    return { sub: data.user.id, email: data.user.email };
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
