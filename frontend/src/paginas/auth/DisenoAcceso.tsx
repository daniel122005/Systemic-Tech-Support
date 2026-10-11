// Diseño compartido de Ingresar / Registro / Recuperar: formulario + panel con el cubo 3D.
import { motion } from 'framer-motion';
import { Bell, FileText, Package, Wrench } from 'lucide-react';
import type { ReactNode } from 'react';
import { Aviso } from '../../components/Formulario';
import { Cubo3D } from '../../components/hero/Cubo3D';
import { motivoSinAuth } from '../../lib/supabase';

const beneficios = [
  { icono: Package, texto: 'Sigue tus pedidos y compras' },
  { icono: Wrench, texto: 'Consulta el estado de tus reparaciones' },
  { icono: FileText, texto: 'Acepta cotizaciones y descarga facturas' },
  { icono: Bell, texto: 'Recibe notificaciones de cada avance' },
];

interface Props {
  etiqueta: string;
  titulo: ReactNode;
  descripcion?: ReactNode;
  children: ReactNode;
  pie?: ReactNode;
}

export function DisenoAcceso({ etiqueta, titulo, descripcion, children, pie }: Props) {
  return (
    <section className="relative isolate overflow-hidden pt-28 pb-20 lg:pt-36">
      <div aria-hidden className="fondo-diagonales absolute inset-0 -z-10" />
      <div aria-hidden className="fondo-rejilla absolute inset-0 -z-10" />
      <div aria-hidden className="absolute top-1/3 right-0 -z-10 size-[36rem] rounded-full bg-profundo/30 blur-3xl" />

      <div className="contenedor grid items-center gap-12 lg:grid-cols-[minmax(0,30rem)_1fr] lg:gap-20">
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
          className="relative rounded-3xl border border-cian/15 bg-noche-2/70 p-6 shadow-[0_30px_80px_-30px_rgba(0,0,0,0.6)] backdrop-blur-xl sm:p-9"
        >
          <div aria-hidden className="absolute inset-x-10 -top-px h-px bg-gradient-to-r from-transparent via-brillo to-transparent" />
          <p className="etiqueta-tecnica text-cian">{'// '}{etiqueta}</p>
          <h1 className="mt-3 font-display text-3xl font-bold tracking-tight sm:text-4xl">{titulo}</h1>
          {descripcion && <p className="mt-3 text-gris">{descripcion}</p>}
          {motivoSinAuth && (
            <div className="mt-6">
              <Aviso tipo="info">
                El inicio de sesión aún no está configurado.
                {import.meta.env.DEV && <span className="mt-1 block font-mono text-xs opacity-80">(Desarrollo) {motivoSinAuth}</span>}
              </Aviso>
            </div>
          )}
          <div className="mt-8">{children}</div>
          {pie && <div className="mt-8 border-t border-white/5 pt-6 text-center text-sm text-gris">{pie}</div>}
        </motion.div>

        {/* Panel decorativo (solo pantallas grandes) */}
        <div className="hidden lg:block">
          <div className="relative mx-auto aspect-square w-full max-w-md [container-type:inline-size]">
            <div aria-hidden className="absolute inset-[15%] rounded-full bg-[radial-gradient(circle,#08C6C455_0%,transparent_70%)] blur-2xl" />
            <Cubo3D lado={38} />
          </div>
          <motion.ul
            initial="o"
            animate="v"
            variants={{ o: {}, v: { transition: { staggerChildren: 0.1, delayChildren: 0.4 } } }}
            className="mx-auto mt-2 grid max-w-md grid-cols-2 gap-3"
          >
            {beneficios.map(({ icono: Icono, texto }) => (
              <motion.li
                key={texto}
                variants={{ o: { opacity: 0, y: 12 }, v: { opacity: 1, y: 0 } }}
                className="flex items-center gap-3 rounded-xl border border-white/5 bg-noche-2/50 p-3 text-sm text-hueso/85"
              >
                <Icono className="size-4.5 shrink-0 text-cian" />
                {texto}
              </motion.li>
            ))}
          </motion.ul>
        </div>
      </div>
    </section>
  );
}
