// Franja de "Próximamente: cursos" en el Inicio (fase 1: solo se registra el interés).
import { ArrowRight, GraduationCap } from 'lucide-react';
import { Link } from 'react-router';
import { Aparecer } from '../components/Aparecer';

export function CursosTeaser() {
  return (
    <section className="py-12 sm:py-16">
      <div className="contenedor">
        <Aparecer className="group relative overflow-hidden rounded-2xl border border-white/10 bg-gradient-to-r from-noche-2 via-profundo/40 to-noche-2 p-6 sm:p-8">
          <div aria-hidden className="absolute inset-y-0 -left-1/3 w-1/3 skew-x-12 bg-gradient-to-r from-transparent via-white/5 to-transparent transition-transform duration-1000 group-hover:translate-x-[400%]" />
          <div className="relative flex flex-col items-start gap-6 sm:flex-row sm:items-center">
            <span className="grid size-14 shrink-0 place-items-center rounded-2xl bg-cian/10 text-brillo ring-1 ring-cian/30">
              <GraduationCap className="size-7" />
            </span>
            <div className="flex-1">
              <p className="etiqueta-tecnica text-amber-200">Próximamente</p>
              <h2 className="mt-1 font-display text-xl font-bold sm:text-2xl">Cursos para aprender tecnología con nosotros</h2>
              <p className="mt-1 text-sm text-gris">Cuéntanos qué te gustaría aprender y te avisamos apenas abramos inscripciones.</p>
            </div>
            <Link to="/cursos" className="btn-primario group/b shrink-0">
              Me interesa <ArrowRight className="size-4 transition-transform group-hover/b:translate-x-1" />
            </Link>
          </div>
        </Aparecer>
      </div>
    </section>
  );
}
