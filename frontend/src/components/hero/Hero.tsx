import { motion, useInView, useReducedMotion, useSpring, useTransform, type Variants } from 'framer-motion';
import { ArrowRight, ShieldCheck } from 'lucide-react';
import { useMemo, useRef, type PointerEvent } from 'react';
import { Link } from 'react-router';
import { cifras } from '../../datos/contenido';
import { Pendiente } from '../Basicos';
import { Contador } from '../Contador';
import { CircuitoExterno } from './CuboCircuito';
import { Cubo3D } from './Cubo3D';

const facil = [0.22, 1, 0.36, 1] as const;

const palabras: Variants = {
  oculto: {},
  visible: { transition: { staggerChildren: 0.16, delayChildren: 0.25 } },
};
const palabra: Variants = {
  oculto: { y: '105%', opacity: 0 },
  visible: { y: '0%', opacity: 1, transition: { duration: 0.8, ease: facil } },
};
const entrar = (retraso: number) => ({
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.7, ease: facil, delay: retraso },
});

function Particulas() {
  // Posiciones fijas por montaje (no cambian en cada render).
  const puntos = useMemo(
    () =>
      Array.from({ length: 28 }, () => ({
        left: `${Math.random() * 100}%`,
        top: `${Math.random() * 100}%`,
        tam: Math.random() < 0.25 ? 3 : 2,
        dur: `${5 + Math.random() * 6}s`,
        retraso: `${-Math.random() * 8}s`,
      })),
    [],
  );
  return (
    <>
      {puntos.map((p, i) => (
        <span
          key={i}
          className="particula absolute rounded-full bg-brillo shadow-[0_0_8px_#22E3E0]"
          style={{ left: p.left, top: p.top, width: p.tam, height: p.tam, ['--dur' as string]: p.dur, ['--retraso' as string]: p.retraso }}
        />
      ))}
    </>
  );
}

export function Hero() {
  const reducido = useReducedMotion();
  // Fuera de pantalla se pausan las animaciones CSS del hero (partículas, pulsos, halo, anillos, nodos).
  const seccion = useRef<HTMLElement>(null);
  const enPantalla = useInView(seccion);
  // Parallax con el mouse: -0.5 … 0.5 en cada eje, suavizado con resorte.
  const mx = useSpring(0, { stiffness: 60, damping: 18 });
  const my = useSpring(0, { stiffness: 60, damping: 18 });
  const rejillaX = useTransform(mx, (v) => v * -24);
  const rejillaY = useTransform(my, (v) => v * -24);
  const particulasX = useTransform(mx, (v) => v * -48);
  const particulasY = useTransform(my, (v) => v * -48);
  const cuboX = useTransform(mx, (v) => v * 30);
  const cuboY = useTransform(my, (v) => v * 30);

  const mover = (e: PointerEvent<HTMLElement>) => {
    if (reducido || e.pointerType !== 'mouse') return;
    const r = e.currentTarget.getBoundingClientRect();
    mx.set((e.clientX - r.left) / r.width - 0.5);
    my.set((e.clientY - r.top) / r.height - 0.5);
  };

  return (
    <section
      ref={seccion}
      onPointerMove={mover}
      aria-labelledby="titulo-hero"
      className={`relative isolate flex min-h-svh items-center ${enPantalla ? '' : 'pausado'} overflow-hidden bg-[radial-gradient(ellipse_at_70%_40%,#0E4E7A55_0%,transparent_55%),linear-gradient(180deg,#04203F_0%,#011631_70%)] pt-28 pb-24 lg:pt-32`}
    >
      {/* Fondo: diagonales, rejilla y partículas con parallax */}
      <div aria-hidden className="fondo-diagonales absolute inset-0 -z-10" />
      <motion.div aria-hidden style={{ x: rejillaX, y: rejillaY }} className="fondo-rejilla absolute -inset-10 -z-10" />
      <motion.div aria-hidden style={{ x: particulasX, y: particulasY }} className="absolute -inset-12 -z-10">
        <Particulas />
      </motion.div>

      <div className="contenedor grid items-center gap-14 lg:grid-cols-[1.05fr_1fr] lg:gap-8">
        {/* Texto */}
        <div className="relative z-10">
          <motion.p {...entrar(0)} className="etiqueta-tecnica inline-flex items-center gap-2.5 rounded-md border border-cian/40 bg-cian/5 px-3 py-1.5 text-cian">
            <span className="relative flex size-2">
              <span className="onda absolute inset-0 rounded-full bg-brillo" />
              <span className="relative size-2 rounded-full bg-brillo" />
            </span>
            Systemic Tech &amp; Support
          </motion.p>

          <motion.h1
            id="titulo-hero"
            variants={palabras}
            initial="oculto"
            animate="visible"
            className="mt-6 font-display text-[clamp(2.75rem,9vw,5.75rem)] leading-[0.95] font-extrabold tracking-tight uppercase"
          >
            {['Soporte', 'Técnico', 'Integral'].map((p) => (
              <span key={p} className="-mt-[0.18em] block overflow-hidden pt-[0.18em] pb-[0.08em]">
                <motion.span variants={palabra} className={`block ${p === 'Técnico' ? 'texto-brillo' : ''}`}>
                  {p}
                </motion.span>
              </span>
            ))}
          </motion.h1>

          <motion.p {...entrar(0.85)} className="mt-6 max-w-xl text-lg text-gris sm:text-xl">
            Reparación, mantenimiento, venta de equipos y desarrollo de software. Tu aliado tecnológico en Colombia.
          </motion.p>

          <motion.div {...entrar(1)} className="mt-9 flex flex-wrap gap-3">
            <Link to="/servicios" className="btn-primario group">
              Ver servicios
              <ArrowRight className="size-4 transition-transform group-hover:translate-x-1" />
            </Link>
            <Link to="/reparaciones" className="btn-secundario">
              Consultar reparación
            </Link>
          </motion.div>

          <motion.p {...entrar(1.1)} className="mt-4 flex items-center gap-2 text-sm text-gris">
            <ShieldCheck className="size-4 text-cian" />
            Compra, agenda o cotiza sin necesidad de crear una cuenta.
          </motion.p>

          <motion.dl {...entrar(1.2)} className="mt-12 grid max-w-xl grid-cols-3 gap-4">
            {cifras.map((c) => (
              <div key={c.etiqueta} className="border-l-2 border-cian/40 pl-4">
                <dt className="sr-only">{c.etiqueta}</dt>
                <dd className="font-display text-2xl font-bold text-cian sm:text-3xl">
                  {c.valor === null ? <Pendiente className="block text-[0.65rem] leading-tight" /> : <Contador valor={c.valor} prefijo={c.prefijo} sufijo={c.sufijo} />}
                </dd>
                <dd aria-hidden className="mt-1 text-xs text-gris sm:text-sm">
                  {c.etiqueta}
                </dd>
              </div>
            ))}
          </motion.dl>
        </div>

        {/* Arte: cubo con circuitos */}
        <motion.div style={{ x: cuboX, y: cuboY }} className="relative mx-auto aspect-square w-full max-w-[min(88vw,540px)] [container-type:inline-size]">
          {/* Halo cian pulsante (entra con Framer; el latido continuo es CSS para poder pausarlo) */}
          <motion.div aria-hidden className="absolute inset-[18%]" initial={{ opacity: 0, scale: 0.6 }} animate={{ opacity: 1, scale: 1 }} transition={{ duration: 0.8 }}>
            <div className="halo-pulso h-full w-full rounded-full bg-[radial-gradient(circle,#08C6C4_0%,#0F6B92_45%,transparent_70%)] blur-2xl" />
          </motion.div>
          {/* Anillos orbitales */}
          <svg aria-hidden viewBox="0 0 100 100" className="giro-lento absolute inset-[6%] opacity-60">
            <circle cx="50" cy="50" r="49" fill="none" stroke="#08C6C4" strokeOpacity="0.35" strokeWidth="0.25" strokeDasharray="1 2.5" />
            <circle cx="50" cy="1" r="0.9" fill="#22E3E0" />
          </svg>
          <svg aria-hidden viewBox="0 0 100 100" className="giro-inverso absolute inset-[16%] opacity-50">
            <circle cx="50" cy="50" r="49" fill="none" stroke="#0F6B92" strokeWidth="0.35" strokeDasharray="12 6" />
          </svg>
          {/* Pistas de circuito alrededor del cubo */}
          <div className="absolute inset-0">
            <CircuitoExterno />
          </div>
          {/* Cubo 3D: entra girando, flota y sigue al mouse */}
          <motion.div className="absolute inset-0" initial={{ opacity: 0, scale: 0.7 }} animate={{ opacity: 1, scale: 1 }} transition={{ duration: 1.2, ease: facil }}>
            <Cubo3D mx={mx} my={my} />
          </motion.div>
        </motion.div>
      </div>

      {/* Indicador de scroll */}
      <motion.a
        href="#servicios"
        {...entrar(1.6)}
        className="etiqueta-tecnica absolute bottom-6 left-1/2 hidden -translate-x-1/2 flex-col items-center gap-2 text-gris hover:text-brillo md:flex"
      >
        Scroll
        <span className="relative h-10 w-px overflow-hidden bg-cian/20">
          <motion.span
            className="absolute inset-x-0 top-0 h-3 bg-brillo"
            animate={reducido ? undefined : { y: [-12, 40] }}
            transition={{ duration: 1.6, repeat: Infinity, ease: 'easeInOut' }}
          />
        </span>
      </motion.a>
    </section>
  );
}
