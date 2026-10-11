// Cifra que cuenta hacia arriba cuando entra en pantalla.
import { animate, useInView, useReducedMotion } from 'framer-motion';
import { useEffect, useRef } from 'react';
import { formatoNumero } from '../lib/formato';

export function Contador({ valor, prefijo = '', sufijo = '' }: { valor: number; prefijo?: string; sufijo?: string }) {
  const ref = useRef<HTMLSpanElement>(null);
  const visible = useInView(ref, { once: true, amount: 0.6 });
  const reducido = useReducedMotion();

  useEffect(() => {
    const nodo = ref.current;
    if (!nodo || !visible) return;
    const pintar = (v: number) => (nodo.textContent = `${prefijo}${formatoNumero(Math.round(v))}${sufijo}`);
    if (reducido) return void pintar(valor);
    const control = animate(0, valor, { duration: 1.8, ease: [0.16, 1, 0.3, 1], onUpdate: pintar });
    return () => control.stop();
  }, [visible, valor, prefijo, sufijo, reducido]);

  return (
    <span ref={ref} aria-label={`${prefijo}${formatoNumero(valor)}${sufijo}`}>
      {prefijo}0{sufijo}
    </span>
  );
}
