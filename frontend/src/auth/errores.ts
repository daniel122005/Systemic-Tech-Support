// Traduce los errores de Supabase Auth (en inglés) a mensajes claros para el cliente.
import { isAuthError } from '@supabase/supabase-js';

const mensajes: Record<string, string> = {
  invalid_credentials: 'Correo o contraseña incorrectos.',
  email_not_confirmed: 'Aún no has confirmado tu correo. Revisa tu bandeja de entrada (y la carpeta de spam).',
  user_already_exists: 'Ya existe una cuenta con ese correo. Ingresa o recupera tu contraseña.',
  email_exists: 'Ya existe una cuenta con ese correo. Ingresa o recupera tu contraseña.',
  weak_password: 'La contraseña es muy débil. Usa al menos 8 caracteres combinando letras y números.',
  same_password: 'La nueva contraseña debe ser distinta a la anterior.',
  over_email_send_rate_limit: 'Enviamos demasiados correos en poco tiempo. Espera unos minutos e inténtalo de nuevo.',
  over_request_rate_limit: 'Demasiados intentos seguidos. Espera unos minutos e inténtalo de nuevo.',
  email_address_invalid: 'Ese correo no es válido.',
  email_address_not_authorized: 'No podemos enviar correos a esa dirección por ahora.',
  signup_disabled: 'El registro está deshabilitado temporalmente.',
  validation_failed: 'Revisa los datos ingresados.',
  otp_expired: 'El enlace venció o ya fue usado. Solicita uno nuevo.',
  flow_state_expired: 'El enlace venció. Solicita uno nuevo.',
  flow_state_not_found: 'Abre el enlace en el mismo navegador donde lo solicitaste, o solicita uno nuevo.',
  bad_code_verifier: 'Abre el enlace en el mismo navegador donde lo solicitaste, o solicita uno nuevo.',
  session_not_found: 'Tu sesión venció. Ingresa de nuevo.',
  refresh_token_not_found: 'Tu sesión venció. Ingresa de nuevo.',
  user_banned: 'Tu cuenta está bloqueada. Comunícate con nosotros.',
};

export function mensajeAuth(e: unknown): string {
  if (isAuthError(e)) {
    if (e.code && mensajes[e.code]) return mensajes[e.code];
    if (e.name === 'AuthRetryableFetchError' || e.status === 0) return 'No pudimos conectarnos. Revisa tu conexión e inténtalo de nuevo.';
    if (e.status === 429) return mensajes.over_request_rate_limit;
  }
  console.error('[Systemic] Error de Supabase Auth sin traducir:', e);
  const general = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  // En desarrollo se muestra el detalle técnico para poder diagnosticar.
  if (import.meta.env.DEV && isAuthError(e)) return `${general} (Detalle: ${e.code ?? e.name} · ${e.status ?? ''} · ${e.message})`;
  return general;
}

/** Errores que Supabase devuelve en la URL al abrir un enlace del correo (ej. enlace vencido). */
export function errorEnUrl(): string | null {
  const params = new URLSearchParams(window.location.search);
  const hash = new URLSearchParams(window.location.hash.slice(1));
  const codigo = params.get('error_code') ?? hash.get('error_code');
  if (!codigo && !params.get('error') && !hash.get('error')) return null;
  return (codigo && mensajes[codigo]) || 'El enlace no es válido o ya venció. Solicita uno nuevo.';
}
