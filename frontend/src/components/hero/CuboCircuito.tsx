// Pistas de circuito del hero: salen alrededor del cubo 3D (Cubo3D) hacia los bordes,
// se "dibujan", los nodos se encienden en secuencia y viajan pulsos de luz.
// También exporta CuboIcono: el cubo plano y estático para el logo del header y del pie.
import { motion, useReducedMotion } from 'framer-motion';

// Lienzo 600 × 600 con el cubo en el centro. Cada pista empieza en un conector separado
// del cubo (así no se desalinea cuando el cubo gira o sigue al mouse).
const pistasExternas = [
  { d: 'M300 150 L300 95 L345 50 L345 14', inicio: [300, 150], fin: [345, 14] },
  { d: 'M372 172 L400 156 L400 72', inicio: [372, 172], fin: [400, 72] },
  { d: 'M450 250 L470 250 L505 215 L586 215', inicio: [450, 250], fin: [586, 215] },
  { d: 'M450 345 L485 345 L525 385 L588 385', inicio: [450, 345], fin: [588, 385] },
  { d: 'M300 450 L300 500 L255 545 L255 588', inicio: [300, 450], fin: [255, 588] },
  { d: 'M150 345 L115 345 L75 385 L14 385', inicio: [150, 345], fin: [14, 385] },
  { d: 'M150 255 L120 255 L85 220 L85 118', inicio: [150, 255], fin: [85, 118] },
  { d: 'M228 172 L200 156 L200 60', inicio: [228, 172], fin: [200, 60] },
] as const;

// Pistas sobre las caras del cubo plano (CuboIcono), inspiradas en el logo.
const pistasCubo = [
  { d: 'M352 212 L262 264', nodo: [352, 212] },
  { d: 'M210 265 L210 330 L245 360 L245 394', nodo: [210, 265] },
  { d: 'M240 300 L265 328 L265 405', nodo: [240, 300] },
  { d: 'M385 268 L352 287 L340 325 L306 345', nodo: [385, 268] },
  { d: 'M413 298 L368 324 L368 352', nodo: [368, 359] },
] as const;

const INICIO = 0.5; // segundos antes de empezar a dibujar

export function CircuitoExterno() {
  const reducido = useReducedMotion();
  const dibujo = (i: number) =>
    reducido
      ? { initial: false as const }
      : {
          initial: { pathLength: 0, opacity: 0 },
          animate: { pathLength: 1, opacity: 1 },
          transition: { pathLength: { delay: INICIO + i * 0.14, duration: 1.1, ease: 'easeInOut' as const }, opacity: { delay: INICIO + i * 0.14, duration: 0.2 } },
        };

  return (
    <svg viewBox="0 0 600 600" className="h-full w-full overflow-visible" aria-hidden>
      <defs>
        <filter id="resplandor" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="4" result="b" />
          <feMerge>
            <feMergeNode in="b" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      {/* Pistas externas */}
      <g fill="none" strokeLinecap="round" strokeLinejoin="round">
        {pistasExternas.map((p, i) => (
          <g key={p.d}>
            <motion.path d={p.d} stroke="#0F6B92" strokeWidth={2.5} {...dibujo(i)} />
            {/* Conector junto al cubo */}
            <circle cx={p.inicio[0]} cy={p.inicio[1]} r={4} fill="#0F6B92" />
            {/* Pulso de luz que viaja por la pista */}
            <motion.path
              d={p.d}
              pathLength={1}
              stroke="#22E3E0"
              strokeWidth={3.5}
              filter="url(#resplandor)"
              className="pulso-pista"
              style={{ animationDelay: `${INICIO + 1.4 + i * 0.37}s` }}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: INICIO + 1.4 + i * 0.37 }}
            />
            {/* Nodo final que se enciende en secuencia */}
            <motion.circle
              cx={p.fin[0]}
              cy={p.fin[1]}
              r={6}
              fill="#011631"
              stroke="#22E3E0"
              strokeWidth={2.5}
              filter="url(#resplandor)"
              initial={reducido ? false : { opacity: 0, scale: 0 }}
              animate={reducido ? { opacity: 1 } : { opacity: [0, 1, 0.45, 1], scale: [0, 1.4, 1, 1] }}
              transition={{ delay: INICIO + 0.9 + i * 0.14, duration: 0.8 }}
            />
          </g>
        ))}
      </g>
    </svg>
  );
}

/** Versión pequeña y estática del cubo (header, íconos). */
export function CuboIcono({ className = '' }: { className?: string }) {
  return (
    <svg viewBox="176 160 248 280" className={className} aria-hidden>
      <defs>
        <linearGradient id="ic-sup" x1="0.1" y1="0.9" x2="0.9" y2="0.1">
          <stop offset="0" stopColor="#0F6B92" />
          <stop offset="1" stopColor="#22E3E0" />
        </linearGradient>
        <linearGradient id="ic-izq" x1="0" y1="0" x2="0.3" y2="1">
          <stop offset="0" stopColor="#0F6B92" />
          <stop offset="1" stopColor="#072B57" />
        </linearGradient>
        <linearGradient id="ic-der" x1="1" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#08C6C4" />
          <stop offset="1" stopColor="#0B3B6E" />
        </linearGradient>
      </defs>
      <g stroke="#011631" strokeWidth={8} strokeLinejoin="round">
        <polygon points="300,170 413,235 300,300 187,235" fill="url(#ic-sup)" />
        <polygon points="187,235 300,300 300,430 187,365" fill="url(#ic-izq)" />
        <polygon points="300,300 413,235 413,365 300,430" fill="url(#ic-der)" />
      </g>
      <g fill="none" stroke="#EEF0EF" strokeWidth={9} strokeLinecap="round" strokeLinejoin="round">
        {pistasCubo.map((p) => (
          <path key={p.d} d={p.d} />
        ))}
      </g>
      <g fill="#0E4E7A" stroke="#EEF0EF" strokeWidth={6}>
        {pistasCubo.map((p) => (
          <circle key={p.d} cx={p.nodo[0]} cy={p.nodo[1]} r={11} />
        ))}
      </g>
    </svg>
  );
}
