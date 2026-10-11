// Flujo de una reparación tal como lo soporta la plataforma (RF-14, RF-16, RF-17, RF-21, RF-30).
// Revisar con la empresa que los textos coincidan con su proceso real.
import { motion } from 'framer-motion';
import { CalendarCheck, ClipboardCheck, PackageCheck, Stethoscope, Wrench } from 'lucide-react';
import { Escalonado, varianteHijo } from '../components/Aparecer';
import { TituloSeccion } from '../components/Basicos';

const pasos = [
  { icono: CalendarCheck, titulo: 'Solicita y agenda', texto: 'Cuéntanos qué le pasa a tu equipo y elige una fecha. No necesitas cuenta.' },
  { icono: Stethoscope, titulo: 'Diagnóstico', texto: 'Un técnico revisa tu equipo y encuentra la causa del problema.' },
  { icono: ClipboardCheck, titulo: 'Cotización', texto: 'Recibes la cotización y decides si la aceptas o la rechazas.' },
  { icono: Wrench, titulo: 'Reparación', texto: 'Trabajamos en tu equipo y puedes consultar su estado en todo momento.' },
  { icono: PackageCheck, titulo: 'Entrega', texto: 'Recoges tu equipo listo y nos cuentas cómo te fue con el servicio.' },
];

export function ProcesoReparacion() {
  return (
    <section className="relative overflow-hidden py-24 sm:py-32">
      <div className="contenedor">
        <TituloSeccion
          centrado
          etiqueta="Proceso"
          titulo={
            <>
              Así funciona una <span className="text-cian">reparación</span>
            </>
          }
          descripcion="Claro y transparente, de principio a fin."
        />

        <div className="relative">
          {/* Línea de circuito que se dibuja al entrar (horizontal en escritorio, vertical en móvil) */}
          <motion.div
            aria-hidden
            className="absolute top-7 right-[10%] left-[10%] hidden h-0.5 origin-left bg-gradient-to-r from-cian/10 via-cian to-cian/10 shadow-[0_0_12px_#08C6C4] lg:block"
            initial={{ scaleX: 0 }}
            whileInView={{ scaleX: 1 }}
            viewport={{ once: true, amount: 0.5 }}
            transition={{ duration: 1.6, ease: 'easeInOut' }}
          />
          <motion.div
            aria-hidden
            className="absolute top-7 bottom-7 left-7 w-0.5 origin-top bg-gradient-to-b from-cian via-cian/60 to-cian/10 lg:hidden"
            initial={{ scaleY: 0 }}
            whileInView={{ scaleY: 1 }}
            viewport={{ once: true, amount: 0.2 }}
            transition={{ duration: 1.6, ease: 'easeInOut' }}
          />

          <Escalonado intervalo={0.22} className="relative grid gap-8 lg:grid-cols-5 lg:gap-6">
            {pasos.map(({ icono: Icono, titulo, texto }, i) => (
              <motion.div key={titulo} variants={varianteHijo} className="flex gap-5 lg:flex-col lg:items-center lg:text-center">
                <span className="relative grid size-14 shrink-0 place-items-center rounded-full bg-noche ring-2 ring-cian/60 shadow-[0_0_24px_-6px_#22E3E0]">
                  <Icono className="size-6 text-brillo" />
                  <span className="absolute -top-1.5 -right-1.5 grid size-6 place-items-center rounded-full bg-cian font-mono text-[0.7rem] font-bold text-noche">
                    {i + 1}
                  </span>
                </span>
                <div>
                  <h3 className="font-display text-lg font-semibold lg:mt-5">{titulo}</h3>
                  <p className="mt-1.5 text-sm leading-relaxed text-gris">{texto}</p>
                </div>
              </motion.div>
            ))}
          </Escalonado>
        </div>
      </div>
    </section>
  );
}
