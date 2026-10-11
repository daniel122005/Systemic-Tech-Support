// Cubo del logo en 3D real (CSS 3D: preserve-3d), sin librerías pesadas.
// - Seis caras separadas (como las ranuras del logo) con pistas de circuito que se dibujan.
// - Núcleo de luz cian que se ve entre las caras.
// - Entra girando, flota, oscila suave y sigue al mouse (mx, my entre -0.5 y 0.5).
// El tamaño se toma del contenedor: el padre debe tener `container-type: inline-size`.
import { animate, motion, useAnimationFrame, useInView, useMotionValue, useReducedMotion, useTransform, type MotionValue } from 'framer-motion';
import { useEffect, useRef, type CSSProperties } from 'react';

const ISO_X = -35.26; // inclinación isométrica (se ve la cara superior)
const ISO_Y = 45;

type Pista = { d: string; nodos: [number, number][] };

// Pistas por tipo de cara (coordenadas 0–100), inspiradas en el logo.
const pistasLateralA: Pista[] = [
  { d: 'M18 12 L18 55 L45 78 L45 100', nodos: [[18, 12]] },
  { d: 'M42 30 L60 50 L60 100', nodos: [[42, 30]] },
];
const pistasLateralB: Pista[] = [
  { d: 'M84 16 L56 34 L48 64 L18 84 L0 84', nodos: [[84, 16]] },
  { d: 'M100 52 L72 70 L72 86', nodos: [[72, 90]] },
];
const pistasSuperior: Pista[] = [
  { d: 'M76 24 L30 70', nodos: [[76, 24]] },
  { d: 'M24 26 L24 46 L44 46', nodos: [[24, 26]] },
];

const caras: { nombre: string; transform: string; fondo: string; pistas: Pista[] }[] = [
  { nombre: 'frente', transform: 'translateZ(var(--medio))', fondo: 'linear-gradient(160deg,#0E4E7A 0%,#062246 100%)', pistas: pistasLateralA },
  { nombre: 'derecha', transform: 'rotateY(90deg) translateZ(var(--medio))', fondo: 'linear-gradient(200deg,#0BB5C0 0%,#0F6B92 55%,#0B3B6E 100%)', pistas: pistasLateralB },
  { nombre: 'atras', transform: 'rotateY(180deg) translateZ(var(--medio))', fondo: 'linear-gradient(160deg,#0E4E7A 0%,#062246 100%)', pistas: pistasLateralB },
  { nombre: 'izquierda', transform: 'rotateY(-90deg) translateZ(var(--medio))', fondo: 'linear-gradient(200deg,#0BB5C0 0%,#0F6B92 55%,#0B3B6E 100%)', pistas: pistasLateralA },
  { nombre: 'arriba', transform: 'rotateX(90deg) translateZ(var(--medio))', fondo: 'linear-gradient(225deg,#22E3E0 0%,#0F6B92 100%)', pistas: pistasSuperior },
  { nombre: 'abajo', transform: 'rotateX(-90deg) translateZ(var(--medio))', fondo: 'linear-gradient(45deg,#04203F 0%,#0E4E7A 100%)', pistas: pistasSuperior },
];

function Cara({ transform, fondo, pistas, indice, reducido }: (typeof caras)[number] & { indice: number; reducido: boolean | null }) {
  return (
    <div
      className="absolute inset-0 overflow-hidden rounded-[6%] [backface-visibility:hidden]"
      style={{
        // scale(.93) separa las caras: por las ranuras se ve el núcleo de luz.
        transform: `${transform} scale(0.93)`,
        background: fondo,
        boxShadow: 'inset 0 0 0 1.5px rgba(34,227,224,0.6), inset 0 0 12px rgba(34,227,224,0.18)',
      }}
    >
      {/* Brillo especular */}
      <div className="absolute inset-0 bg-[linear-gradient(135deg,rgba(255,255,255,0.22)_0%,transparent_38%)]" />
      <svg viewBox="0 0 100 100" className="absolute inset-0 h-full w-full" aria-hidden>
        <g fill="none" stroke="#EEF0EF" strokeWidth={3.6} strokeLinecap="round" strokeLinejoin="round" style={{ filter: 'drop-shadow(0 0 2px rgba(34,227,224,0.9))' }}>
          {pistas.map((p, i) => (
            <motion.path
              key={p.d}
              d={p.d}
              initial={reducido ? false : { pathLength: 0 }}
              animate={{ pathLength: 1 }}
              transition={{ delay: 0.9 + indice * 0.12 + i * 0.2, duration: 1.1, ease: 'easeInOut' }}
            />
          ))}
        </g>
        {pistas.flatMap((p, i) =>
          p.nodos.map(([x, y]) => (
            // Latido en CSS (clase nodo-latido): se pausa fuera de pantalla y respeta reduced-motion.
            <circle
              key={`${p.d}-${x}-${y}`}
              cx={x}
              cy={y}
              r={5}
              fill="#0E4E7A"
              stroke="#EEF0EF"
              strokeWidth={3}
              className="nodo-latido"
              style={{ animationDelay: `${2 + indice * 0.35 + i * 0.5}s` }}
            />
          )),
        )}
      </svg>
    </div>
  );
}

interface Props {
  mx?: MotionValue<number>;
  my?: MotionValue<number>;
  /** Lado del cubo en unidades del contenedor (cqw). */
  lado?: number;
  className?: string;
}

export function Cubo3D({ mx, my, lado = 30, className = '' }: Props) {
  const reducido = useReducedMotion();
  const cero = useMotionValue(0);
  const ratonX = mx ?? cero;
  const ratonY = my ?? cero;
  const giro = useMotionValue(reducido ? 0 : -300); // entrada girando
  // Reloj de la oscilación: solo avanza mientras el cubo está en pantalla (fuera de ella no recalcula nada).
  const contenedor = useRef<HTMLDivElement>(null);
  const visible = useInView(contenedor);
  const tiempo = useMotionValue(0);
  useAnimationFrame((_t, delta) => {
    if (visible && !reducido) tiempo.set(tiempo.get() + delta);
  });

  useEffect(() => {
    if (reducido) return;
    const c = animate(giro, 0, { duration: 2.4, ease: [0.16, 1, 0.3, 1], delay: 0.2 });
    return () => c.stop();
  }, [giro, reducido]);

  const rotateY = useTransform(() => (reducido ? ISO_Y : ISO_Y + giro.get() + ratonX.get() * 50 + Math.sin(tiempo.get() / 2400) * 12));
  const rotateX = useTransform(() => (reducido ? ISO_X : ISO_X - ratonY.get() * 30 + Math.sin(tiempo.get() / 3300) * 5));
  const flotar = useTransform(() => (reducido ? 0 : Math.sin(tiempo.get() / 1000) * 3)); // en % del contenedor
  const y = useTransform(flotar, (v) => `${v}cqw`);
  const escalaSombra = useTransform(flotar, (v) => 1 - v * 0.05);

  const estilo = { '--lado': `${lado}cqw`, '--medio': `${lado / 2}cqw` } as CSSProperties;

  return (
    <div ref={contenedor} className={`pointer-events-none absolute inset-0 grid place-items-center ${className}`} style={estilo} aria-hidden>
      {/* Sombra sobre el "piso" */}
      <motion.div
        className="absolute top-[78%] left-1/2 h-[6cqw] w-[34cqw] -translate-x-1/2 rounded-[50%] bg-[radial-gradient(closest-side,rgba(8,198,196,0.45),transparent)] blur-md"
        style={{ scale: escalaSombra }}
      />
      <motion.div className="[perspective:1400px]" style={{ y }}>
        <motion.div className="relative size-[var(--lado)] [transform-style:preserve-3d]" style={{ rotateX, rotateY }}>
          {/* Núcleo de luz: se ve por las ranuras entre caras */}
          <div className="absolute inset-[18%] rounded-full bg-[radial-gradient(circle,#ffffff_0%,#22E3E0_35%,rgba(8,198,196,0)_70%)] blur-[2px]" />
          {caras.map((c, i) => (
            <Cara key={c.nombre} {...c} indice={i} reducido={reducido} />
          ))}
        </motion.div>
      </motion.div>
    </div>
  );
}
