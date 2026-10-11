// Cliente de Supabase SOLO para autenticación (registro, ingreso, recuperación).
// Los datos del negocio NUNCA se leen desde aquí: van por el backend (Express).
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const url = (import.meta.env.VITE_SUPABASE_URL ?? '').trim();
const clave = (import.meta.env.VITE_SUPABASE_ANON_KEY ?? '').trim();

/** Evita publicar por error la clave secreta (service_role / sb_secret_) en el navegador. */
function esClaveSecreta(k: string): boolean {
  if (k.startsWith('sb_secret_')) return true;
  try {
    const carga = JSON.parse(atob(k.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
    return carga?.role === 'service_role';
  } catch {
    return false;
  }
}

export let motivoSinAuth: string | null = null;
let cliente: SupabaseClient | null = null;

if (!url || !clave) {
  motivoSinAuth = 'Falta configurar VITE_SUPABASE_URL o VITE_SUPABASE_ANON_KEY en frontend/.env';
} else if (esClaveSecreta(clave)) {
  motivoSinAuth = 'VITE_SUPABASE_ANON_KEY tiene la clave SECRETA. Usa la clave anon / publishable.';
  console.error(`[Systemic] ${motivoSinAuth}`);
} else if (!/^sb_publishable_\S+$/.test(clave) && !/^eyJ[\w-]+\.[\w-]+\.[\w-]+$/.test(clave)) {
  // La clave pública es un JWT (eyJ...) o empieza por sb_publishable_; cualquier otra cosa es un error de copia.
  motivoSinAuth = 'VITE_SUPABASE_ANON_KEY no parece una clave de Supabase. Cópiala de Project Settings → API Keys (anon / publishable).';
  console.error(`[Systemic] ${motivoSinAuth}`);
} else {
  cliente = createClient(url, clave, {
    auth: {
      flowType: 'pkce', // los enlaces de correo traen un código de un solo uso, no tokens en la URL
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  });
}

export const supabase = cliente;
