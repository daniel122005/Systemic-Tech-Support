import { AnimatePresence, MotionConfig, motion } from 'framer-motion';
import { lazy, Suspense, useEffect } from 'react';
import { Route, Routes, useLocation } from 'react-router';
import { Encabezado } from './components/Encabezado';
import { PiePagina } from './components/PiePagina';
import { WhatsAppFlotante } from './components/WhatsAppFlotante';
import { ProveedorSesion, RutaPrivada } from './auth/Sesion';
import { Inicio } from './paginas/Inicio';
import { Proximamente } from './paginas/Proximamente';

// Páginas que se descargan solo cuando alguien las abre (el Inicio carga más rápido).
const Cursos = lazy(() => import('./paginas/Cursos').then((m) => ({ default: m.Cursos })));
const Ingresar = lazy(() => import('./paginas/auth/Ingresar').then((m) => ({ default: m.Ingresar })));
const Registro = lazy(() => import('./paginas/auth/Registro').then((m) => ({ default: m.Registro })));
const Recuperar = lazy(() => import('./paginas/auth/Recuperar').then((m) => ({ default: m.Recuperar })));
const NuevaContrasena = lazy(() => import('./paginas/auth/NuevaContrasena').then((m) => ({ default: m.NuevaContrasena })));
const MiCuenta = lazy(() => import('./paginas/MiCuenta').then((m) => ({ default: m.MiCuenta })));
const Privacidad = lazy(() => import('./paginas/Privacidad').then((m) => ({ default: m.Privacidad })));

const titulos: Record<string, string> = {
  '/': 'Systemic Tech & Support · Soporte técnico integral',
  '/productos': 'Productos · Systemic Tech & Support',
  '/servicios': 'Servicios · Systemic Tech & Support',
  '/reparaciones': 'Reparaciones · Systemic Tech & Support',
  '/desarrollo': 'Desarrollo de software · Systemic Tech & Support',
  '/contacto': 'Contacto · Systemic Tech & Support',
  '/cursos': 'Cursos · Systemic Tech & Support',
  '/ingresar': 'Ingresar · Systemic Tech & Support',
  '/registro': 'Crear cuenta · Systemic Tech & Support',
  '/recuperar': 'Recuperar contraseña · Systemic Tech & Support',
  '/nueva-contrasena': 'Nueva contraseña · Systemic Tech & Support',
  '/cuenta': 'Mi cuenta · Systemic Tech & Support',
  '/privacidad': 'Tratamiento de datos · Systemic Tech & Support',
};

export default function App() {
  const ubicacion = useLocation();

  useEffect(() => {
    document.title = titulos[ubicacion.pathname] ?? 'Systemic Tech & Support';
  }, [ubicacion.pathname]);

  return (
    <ProveedorSesion>
      {/* reducedMotion="user": si el sistema pide menos movimiento, Framer Motion omite los desplazamientos. */}
      <MotionConfig reducedMotion="user">
        <a href="#contenido" className="sr-only z-[60] rounded-lg bg-cian px-4 py-2 font-semibold text-noche focus:not-sr-only focus:fixed focus:top-3 focus:left-3">
          Saltar al contenido
        </a>
        <Encabezado />
        <AnimatePresence mode="wait" onExitComplete={() => window.scrollTo({ top: 0, behavior: 'instant' })}>
          <motion.main
            id="contenido"
            key={ubicacion.pathname}
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -12 }}
            transition={{ duration: 0.35, ease: [0.22, 1, 0.36, 1] }}
          >
            <Suspense fallback={<div className="min-h-[80svh]" aria-busy="true" />}>
              <Routes location={ubicacion}>
                <Route path="/" element={<Inicio />} />
                <Route path="/productos" element={<Proximamente titulo="Productos" />} />
                <Route path="/servicios" element={<Proximamente titulo="Servicios" />} />
                <Route path="/reparaciones" element={<Proximamente titulo="Reparaciones" />} />
                <Route path="/desarrollo" element={<Proximamente titulo="Desarrollo de software" />} />
                <Route path="/contacto" element={<Proximamente titulo="Contacto" />} />
                <Route path="/cursos" element={<Cursos />} />
                <Route path="/ingresar" element={<Ingresar />} />
                <Route path="/registro" element={<Registro />} />
                <Route path="/recuperar" element={<Recuperar />} />
                <Route path="/nueva-contrasena" element={<NuevaContrasena />} />
                <Route path="/privacidad" element={<Privacidad />} />
                <Route
                  path="/cuenta"
                  element={
                    <RutaPrivada>
                      <MiCuenta />
                    </RutaPrivada>
                  }
                />
                <Route path="*" element={<Proximamente titulo="Página no encontrada" />} />
              </Routes>
            </Suspense>
          </motion.main>
        </AnimatePresence>
        <PiePagina />
        <WhatsAppFlotante />
      </MotionConfig>
    </ProveedorSesion>
  );
}
