import { motion } from 'framer-motion';
import { ArrowRight, ChartLine, Layers, MessagesSquare } from 'lucide-react';
import { Link } from 'react-router';
import { Aparecer, Escalonado, varianteHijo } from '../components/Aparecer';
import { Pendiente, TituloSeccion } from '../components/Basicos';
import { TarjetaTilt } from '../components/TarjetaTilt';
import { casosDesarrollo } from '../datos/contenido';

const puntos = [
  { icono: Layers, texto: 'Software a la medida de tu negocio' },
  { icono: ChartLine, texto: 'Seguimiento del avance de tu proyecto en línea' },
  { icono: MessagesSquare, texto: 'Comunicación directa con el equipo y archivos compartidos' },
];

export function Desarrollo() {
  return (
    <section className="relative py-24 sm:py-32">
      <div aria-hidden className="fondo-rejilla absolute inset-0 -z-10 opacity-60" />
      <div className="contenedor grid gap-14 lg:grid-cols-[0.9fr_1.1fr] lg:items-center">
        <div>
          <TituloSeccion
            etiqueta="Desarrollo de software"
            titulo={
              <>
                Convertimos tus ideas en <span className="text-cian">software que funciona</span>
              </>
            }
            descripcion="Solicita tu proyecto, recibe una propuesta y acompaña cada etapa desde tu cuenta."
          />
          <Escalonado className="space-y-4">
            {puntos.map(({ icono: Icono, texto }) => (
              <motion.p key={texto} variants={varianteHijo} className="flex items-center gap-4">
                <span className="grid size-10 shrink-0 place-items-center rounded-lg bg-cian/10 text-cian ring-1 ring-cian/25">
                  <Icono className="size-5" />
                </span>
                <span className="text-hueso/90">{texto}</span>
              </motion.p>
            ))}
          </Escalonado>
          <Aparecer retraso={0.2} className="mt-10">
            <Link to="/desarrollo" className="btn-primario group">
              Solicitar un proyecto <ArrowRight className="size-4 transition-transform group-hover:translate-x-1" />
            </Link>
          </Aparecer>
        </div>

        <div>
          <p className="etiqueta-tecnica mb-4 text-gris">Casos y portafolio</p>
          <Escalonado className="grid gap-5 sm:grid-cols-2">
            {casosDesarrollo.map((c, i) => (
              <TarjetaTilt key={i} className="p-6" envoltura={i === 0 ? 'sm:col-span-2' : ''}>
                <span className="font-mono text-xs text-cian">{String(i + 1).padStart(2, '0')}</span>
                <h3 className="mt-3 font-display text-lg font-semibold">{c.titulo ?? <Pendiente />}</h3>
                <p className="mt-2 text-sm text-gris">{c.descripcion ?? 'Aquí irá la descripción de un proyecto real de la empresa.'}</p>
                {c.etiquetas.length > 0 && (
                  <ul className="mt-4 flex flex-wrap gap-2">
                    {c.etiquetas.map((e) => (
                      <li key={e} className="rounded-md bg-cian/10 px-2 py-0.5 font-mono text-xs text-cian">
                        {e}
                      </li>
                    ))}
                  </ul>
                )}
              </TarjetaTilt>
            ))}
          </Escalonado>
        </div>
      </div>
    </section>
  );
}
