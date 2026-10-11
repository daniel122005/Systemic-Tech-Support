import { ArrowUpRight, CodeXml, Laptop, Settings2, ShoppingBag } from 'lucide-react';
import { Link } from 'react-router';
import { Escalonado } from '../components/Aparecer';
import { TituloSeccion } from '../components/Basicos';
import { TarjetaTilt } from '../components/TarjetaTilt';

const servicios = [
  {
    icono: Laptop,
    titulo: 'Reparación de equipos',
    texto: 'Diagnóstico y reparación de computadores y equipos. Sigue el estado de tu reparación en línea.',
    a: '/reparaciones',
  },
  {
    icono: Settings2,
    titulo: 'Mantenimiento',
    texto: 'Mantenimiento preventivo y correctivo. Elige la fecha que más te convenga al solicitarlo.',
    a: '/reparaciones',
  },
  {
    icono: ShoppingBag,
    titulo: 'Venta de equipos',
    texto: 'Productos tecnológicos con precio y disponibilidad actualizados. Compra sin crear cuenta.',
    a: '/productos',
  },
  {
    icono: CodeXml,
    titulo: 'Desarrollo de software',
    texto: 'Soluciones a la medida de tu negocio, con seguimiento del avance de tu proyecto.',
    a: '/desarrollo',
  },
];

export function Servicios() {
  return (
    <section id="servicios" className="relative scroll-mt-20 py-24 sm:py-32">
      <div className="contenedor">
        <TituloSeccion
          etiqueta="Lo que hacemos"
          titulo={
            <>
              Todo lo que tu tecnología necesita, <span className="text-cian">en un solo lugar</span>
            </>
          }
          descripcion="Desde tu equipo personal hasta el software de tu empresa."
        />
        <Escalonado className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {servicios.map(({ icono: Icono, titulo, texto, a }) => (
            <TarjetaTilt key={titulo}>
              <Link to={a} className="flex h-full flex-col p-6 sm:p-7">
                <span className="mb-6 grid size-12 place-items-center rounded-xl bg-gradient-to-br from-cian/25 to-medio/20 text-brillo ring-1 ring-cian/30 transition-shadow group-hover:shadow-[0_0_24px_-4px_#22E3E0]">
                  <Icono className="size-6" />
                </span>
                <h3 className="font-display text-lg font-semibold">{titulo}</h3>
                <p className="mt-2 flex-1 text-sm leading-relaxed text-gris">{texto}</p>
                <span className="mt-6 inline-flex items-center gap-1 text-sm font-semibold text-cian">
                  Ver más
                  <ArrowUpRight className="size-4 transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5" />
                </span>
              </Link>
            </TarjetaTilt>
          ))}
        </Escalonado>
      </div>
    </section>
  );
}
