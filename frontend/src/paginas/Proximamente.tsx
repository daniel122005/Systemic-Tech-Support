// Marcador para las páginas que se construirán en las siguientes tareas.
import { ArrowLeft } from 'lucide-react';
import { Link } from 'react-router';

export function Proximamente({ titulo }: { titulo: string }) {
  return (
    <section className="relative flex min-h-[80svh] items-center pt-28 pb-20">
      <div aria-hidden className="fondo-rejilla absolute inset-0 -z-10" />
      <div className="contenedor text-center">
        <p className="etiqueta-tecnica text-cian">{'// '}En construcción</p>
        <h1 className="mt-4 font-display text-4xl font-bold sm:text-5xl">{titulo}</h1>
        <p className="mx-auto mt-4 max-w-md text-gris">Estamos preparando esta sección. Muy pronto estará disponible.</p>
        <Link to="/" className="btn-secundario mt-8">
          <ArrowLeft className="size-4" /> Volver al inicio
        </Link>
      </div>
    </section>
  );
}
