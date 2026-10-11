import { AnimatePresence, motion, useMotionValueEvent, useScroll } from 'framer-motion';
import { LogIn, Menu, X } from 'lucide-react';
import { useEffect, useState } from 'react';
import { Link, NavLink, useLocation } from 'react-router';
import { useSesion } from '../auth/Sesion';
import { whatsappUrl } from '../datos/contenido';
import { IconoWhatsApp, Logo } from './Basicos';

export const enlaces = [
  { a: '/', texto: 'Inicio' },
  { a: '/productos', texto: 'Productos' },
  { a: '/servicios', texto: 'Servicios' },
  { a: '/reparaciones', texto: 'Reparaciones' },
  { a: '/desarrollo', texto: 'Desarrollo' },
  { a: '/cursos', texto: 'Cursos' },
  { a: '/contacto', texto: 'Contacto' },
];

export function BotonWhatsApp({ className = '', compacto = false }: { className?: string; compacto?: boolean }) {
  const clases = `inline-flex h-10 items-center gap-2 rounded-lg border border-whatsapp/50 text-sm font-semibold text-whatsapp transition-colors hover:bg-whatsapp/10 ${
    compacto ? 'px-2.5 xl:px-4' : 'px-4'
  } ${className}`;
  const contenido = (
    <>
      <IconoWhatsApp className="size-5" /> <span className={compacto ? 'hidden xl:inline' : ''}>WhatsApp</span>
    </>
  );
  // Sin número configurado (VITE_WHATSAPP_NUMERO en frontend/.env) se envía a la página de contacto.
  return whatsappUrl ? (
    <a href={whatsappUrl} target="_blank" rel="noopener noreferrer" aria-label="WhatsApp" className={clases}>
      {contenido}
    </a>
  ) : (
    <Link to="/contacto" aria-label="WhatsApp" className={clases}>
      {contenido}
    </Link>
  );
}

/** "Ingresar" sin sesión; con sesión, acceso a "Mi cuenta" con la inicial del usuario. */
function BotonCuenta({ movil = false }: { movil?: boolean }) {
  const { sesion, lista, nombre } = useSesion();
  if (!lista) return <span className={movil ? 'block h-12' : 'block h-10 w-24'} />;
  if (sesion) {
    return (
      <Link
        to="/cuenta"
        className={`inline-flex h-10 items-center gap-2 rounded-lg border border-cian/30 bg-cian/10 pr-3 pl-1.5 text-sm font-semibold text-hueso transition-colors hover:border-brillo ${movil ? 'h-12 w-full justify-center' : ''}`}
      >
        <span className="grid size-7 place-items-center rounded-md bg-gradient-to-br from-brillo to-medio font-display text-xs font-bold text-noche uppercase">
          {nombre?.[0] ?? '?'}
        </span>
        Mi cuenta
      </Link>
    );
  }
  return (
    <Link to="/ingresar" className={`btn-primario h-10 px-4 py-0 ${movil ? 'h-12 w-full' : ''}`}>
      <LogIn className="size-4" /> Ingresar
    </Link>
  );
}

export function Encabezado() {
  const { scrollY } = useScroll();
  const [compacto, setCompacto] = useState(false);
  const [abierto, setAbierto] = useState(false);
  const { pathname } = useLocation();

  useMotionValueEvent(scrollY, 'change', (y) => setCompacto(y > 24));
  useEffect(() => setAbierto(false), [pathname]);
  useEffect(() => {
    if (!abierto) return;
    const cerrar = (e: KeyboardEvent) => e.key === 'Escape' && setAbierto(false);
    window.addEventListener('keydown', cerrar);
    return () => window.removeEventListener('keydown', cerrar);
  }, [abierto]);

  const fondo = compacto || abierto;

  return (
    <header
      className={`fixed inset-x-0 top-0 z-50 transition-[background-color,border-color,backdrop-filter] duration-300 ${
        fondo ? 'border-b border-cian/10 bg-noche/75 backdrop-blur-xl' : 'border-b border-transparent'
      }`}
    >
      <div className={`contenedor flex items-center justify-between gap-4 transition-[height] duration-300 ${compacto ? 'h-16' : 'h-20 lg:h-24'}`}>
        <Link to="/" aria-label="Systemic Tech & Support, ir al inicio" className="shrink-0">
          <Logo compacto={compacto} />
        </Link>

        <nav aria-label="Principal" className="hidden lg:block">
          <ul className="flex items-center gap-1">
            {enlaces.map((e) => (
              <li key={e.a}>
                <NavLink to={e.a} end={e.a === '/'} className="relative block rounded-lg px-3 py-2 font-display text-sm font-medium xl:px-4">
                  {({ isActive }) => (
                    <>
                      {isActive && (
                        <motion.span
                          layoutId="indicador-menu"
                          className="absolute inset-0 rounded-lg bg-cian/12 ring-1 ring-cian/25"
                          transition={{ type: 'spring', stiffness: 380, damping: 32 }}
                        >
                          <span className="absolute -bottom-px left-1/2 h-0.5 w-6 -translate-x-1/2 rounded-full bg-brillo shadow-[0_0_10px_#22E3E0]" />
                        </motion.span>
                      )}
                      <span className={`relative transition-colors ${isActive ? 'text-brillo' : 'text-hueso/85 hover:text-hueso'}`}>{e.texto}</span>
                    </>
                  )}
                </NavLink>
              </li>
            ))}
          </ul>
        </nav>

        <div className="flex items-center gap-2">
          <span className="hidden sm:block lg:hidden xl:block">
            <BotonWhatsApp compacto />
          </span>
          <span className="hidden sm:block">
            <BotonCuenta />
          </span>
          <button
            type="button"
            className="grid size-11 place-items-center rounded-lg text-hueso hover:bg-white/5 lg:hidden"
            aria-expanded={abierto}
            aria-controls="menu-movil"
            aria-label={abierto ? 'Cerrar menú' : 'Abrir menú'}
            onClick={() => setAbierto((v) => !v)}
          >
            {abierto ? <X className="size-6" /> : <Menu className="size-6" />}
          </button>
        </div>
      </div>

      <AnimatePresence>
        {abierto && (
          <motion.nav
            id="menu-movil"
            aria-label="Principal (móvil)"
            initial={{ opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.2 }}
            className="border-t border-cian/10 lg:hidden"
          >
            <ul className="contenedor flex flex-col gap-1 py-4">
              {enlaces.map((e) => (
                <li key={e.a}>
                  <NavLink
                    to={e.a}
                    end={e.a === '/'}
                    className={({ isActive }) =>
                      `block rounded-lg px-4 py-3 font-display font-medium ${isActive ? 'bg-cian/12 text-brillo' : 'text-hueso/85 hover:bg-white/5'}`
                    }
                  >
                    {e.texto}
                  </NavLink>
                </li>
              ))}
              <li className="mt-2 grid gap-2 sm:hidden">
                <BotonCuenta movil />
                <BotonWhatsApp className="h-12 w-full justify-center" />
              </li>
            </ul>
          </motion.nav>
        )}
      </AnimatePresence>
    </header>
  );
}
