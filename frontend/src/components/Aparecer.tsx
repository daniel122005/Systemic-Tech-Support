// Aparición al hacer scroll (fade + slide) y contenedor con stagger para listas de tarjetas.
// Con prefers-reduced-motion, MotionConfig (en App) quita el desplazamiento y deja solo la opacidad.
import { motion, type Variants } from 'framer-motion';
import type { ReactNode } from 'react';

const facil = [0.22, 1, 0.36, 1] as const;

export const varianteHijo: Variants = {
  oculto: { opacity: 0, y: 28 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.6, ease: facil } },
};

interface Props {
  children: ReactNode;
  className?: string;
  retraso?: number;
}

export function Aparecer({ children, className, retraso = 0 }: Props) {
  return (
    <motion.div
      className={className}
      initial={{ opacity: 0, y: 28 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.25 }}
      transition={{ duration: 0.7, ease: facil, delay: retraso }}
    >
      {children}
    </motion.div>
  );
}

/** Contenedor que revela a sus hijos (motion.* con variants={varianteHijo}) uno tras otro. */
export function Escalonado({ children, className, intervalo = 0.1 }: { children: ReactNode; className?: string; intervalo?: number }) {
  return (
    <motion.div
      className={className}
      initial="oculto"
      whileInView="visible"
      viewport={{ once: true, amount: 0.15 }}
      variants={{ oculto: {}, visible: { transition: { staggerChildren: intervalo } } }}
    >
      {children}
    </motion.div>
  );
}
