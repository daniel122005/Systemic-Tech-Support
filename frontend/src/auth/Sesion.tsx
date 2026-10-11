// Estado de la sesión de Supabase Auth para toda la app.
// El access_token se envía al backend en "Authorization: Bearer ..."; el backend lo verifica.
import type { Session } from '@supabase/supabase-js';
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router';
import { supabase } from '../lib/supabase';

interface ContextoSesion {
  sesion: Session | null;
  /** false mientras se lee la sesión guardada (evita parpadeos y redirecciones falsas). */
  lista: boolean;
  nombre: string | null;
  cerrarSesion: () => Promise<void>;
}

const Contexto = createContext<ContextoSesion | null>(null);

export function ProveedorSesion({ children }: { children: ReactNode }) {
  const [sesion, setSesion] = useState<Session | null>(null);
  const [lista, setLista] = useState(!supabase);
  const navegar = useNavigate();

  useEffect(() => {
    if (!supabase) return;
    supabase.auth.getSession().then(({ data }) => {
      setSesion(data.session);
      setLista(true);
    });
    const { data } = supabase.auth.onAuthStateChange((evento, nueva) => {
      setSesion(nueva);
      setLista(true);
      // Llegó desde el enlace "restablecer contraseña" del correo.
      if (evento === 'PASSWORD_RECOVERY') navegar('/nueva-contrasena', { replace: true });
    });
    return () => data.subscription.unsubscribe();
  }, [navegar]);

  const cerrarSesion = async () => {
    await supabase?.auth.signOut();
    navegar('/', { replace: true });
  };

  const meta = sesion?.user.user_metadata as { nombres?: string } | undefined;
  const nombre = meta?.nombres ?? sesion?.user.email?.split('@')[0] ?? null;

  return <Contexto.Provider value={{ sesion, lista, nombre, cerrarSesion }}>{children}</Contexto.Provider>;
}

export function useSesion() {
  const c = useContext(Contexto);
  if (!c) throw new Error('useSesion debe usarse dentro de <ProveedorSesion>');
  return c;
}

/** Envuelve páginas que exigen sesión: sin sesión, envía a /ingresar y luego regresa. */
export function RutaPrivada({ children }: { children: ReactNode }) {
  const { sesion, lista } = useSesion();
  const { pathname } = useLocation();
  if (!lista) return <div className="min-h-[70svh]" aria-busy="true" />;
  if (!sesion) return <Navigate to={`/ingresar?siguiente=${encodeURIComponent(pathname)}`} replace />;
  return <>{children}</>;
}

/** Solo rutas internas (evita redirecciones a otros sitios). */
export function destinoSeguro(valor: string | null, porDefecto = '/cuenta'): string {
  return valor && /^\/(?![/\\])/.test(valor) ? valor : porDefecto;
}
