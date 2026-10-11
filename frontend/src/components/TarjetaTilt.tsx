// Tarjeta con inclinación 3D leve y borde de gradiente animado al pasar el mouse.
import { motion, useMotionValue, useReducedMotion, useSpring, useTransform } from 'framer-motion';
import type { PointerEvent, ReactNode } from 'react';
import { varianteHijo } from './Aparecer';

export function TarjetaTilt({ children, className = '', envoltura = '' }: { children: ReactNode; className?: string; envoltura?: string }) {
  const reducido = useReducedMotion();
  const x = useMotionValue(0.5);
  const y = useMotionValue(0.5);
  const rotateX = useSpring(useTransform(y, [0, 1], [7, -7]), { stiffness: 200, damping: 20 });
  const rotateY = useSpring(useTransform(x, [0, 1], [-7, 7]), { stiffness: 200, damping: 20 });

  const mover = (e: PointerEvent<HTMLDivElement>) => {
    if (reducido || e.pointerType !== 'mouse') return;
    const r = e.currentTarget.getBoundingClientRect();
    x.set((e.clientX - r.left) / r.width);
    y.set((e.clientY - r.top) / r.height);
  };
  const salir = () => {
    x.set(0.5);
    y.set(0.5);
  };

  return (
    <motion.div variants={varianteHijo} className={`h-full [perspective:900px] ${envoltura}`}>
      <motion.div
        onPointerMove={mover}
        onPointerLeave={salir}
        style={reducido ? undefined : { rotateX, rotateY }}
        className="group relative h-full overflow-hidden rounded-2xl p-px"
      >
        {/* Borde: gradiente cónico que gira detrás del contenido */}
        <span aria-hidden className="absolute inset-0 rounded-2xl bg-white/8" />
        <span
          aria-hidden
          className="borde-giratorio absolute top-1/2 left-1/2 aspect-square w-[160%] -translate-x-1/2 -translate-y-1/2 opacity-0 transition-opacity duration-500 group-hover:opacity-100"
          style={{ background: 'conic-gradient(from 0deg, transparent 0 55%, #08C6C4 75%, #22E3E0 82%, transparent 92%)' }}
        />
        <div className={`relative h-full rounded-[15px] bg-noche-2/95 ${className}`}>{children}</div>
      </motion.div>
    </motion.div>
  );
}
