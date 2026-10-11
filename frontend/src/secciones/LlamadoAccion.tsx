import { ArrowRight } from 'lucide-react';
import { Link } from 'react-router';
import { Aparecer } from '../components/Aparecer';

export function LlamadoAccion() {
  return (
    <section className="py-24 sm:py-32">
      <div className="contenedor">
        <Aparecer className="relative overflow-hidden rounded-3xl border border-cian/25 bg-gradient-to-br from-profundo/70 via-noche-2 to-noche px-6 py-16 text-center sm:px-12">
          <div aria-hidden className="fondo-rejilla absolute inset-0" />
          <div aria-hidden className="absolute -top-24 left-1/2 size-72 -translate-x-1/2 rounded-full bg-cian/25 blur-3xl" />
          <div className="relative">
            <p className="etiqueta-tecnica text-cian">{'// '}¿Hablamos?</p>
            <h2 className="mx-auto mt-4 max-w-2xl font-display text-3xl font-bold tracking-tight text-balance sm:text-5xl">
              ¿Tu equipo o tu proyecto necesitan ayuda?
            </h2>
            <p className="mx-auto mt-5 max-w-xl text-lg text-gris">Solicita un servicio o una cotización ahora mismo. No necesitas crear una cuenta.</p>
            <div className="mt-9 flex flex-wrap justify-center gap-3">
              <Link to="/reparaciones" className="btn-primario group">
                Solicitar servicio <ArrowRight className="size-4 transition-transform group-hover:translate-x-1" />
              </Link>
              <Link to="/contacto" className="btn-secundario">
                Pedir cotización
              </Link>
            </div>
          </div>
        </Aparecer>
      </div>
    </section>
  );
}
