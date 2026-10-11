import { motion } from 'framer-motion';
import { Quote } from 'lucide-react';
import { Escalonado, varianteHijo } from '../components/Aparecer';
import { Pendiente, TituloSeccion } from '../components/Basicos';
import { testimonios } from '../datos/contenido';

export function Testimonios() {
  return (
    <section className="relative py-24 sm:py-32">
      <div className="contenedor">
        <TituloSeccion centrado etiqueta="Testimonios" titulo="Lo que dicen nuestros clientes" />
        <Escalonado className="grid gap-5 md:grid-cols-3">
          {testimonios.map((t, i) => (
            <motion.figure key={i} variants={varianteHijo} className="relative flex flex-col rounded-2xl border border-cian/15 bg-noche-2/60 p-7">
              <Quote aria-hidden className="size-8 text-cian/40" />
              <blockquote className="mt-4 flex-1 text-hueso/90">{t.texto ? `“${t.texto}”` : <Pendiente />}</blockquote>
              <figcaption className="mt-6 flex items-center gap-3 border-t border-white/5 pt-5">
                <span aria-hidden className="grid size-10 place-items-center rounded-full bg-gradient-to-br from-cian to-profundo font-display font-bold text-noche">
                  {t.nombre?.[0] ?? '?'}
                </span>
                <span>
                  <span className="block font-semibold">{t.nombre ?? <Pendiente />}</span>
                  {t.cargo && <span className="block text-sm text-gris">{t.cargo}</span>}
                </span>
              </figcaption>
            </motion.figure>
          ))}
        </Escalonado>
      </div>
    </section>
  );
}
