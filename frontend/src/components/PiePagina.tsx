// Pie de página. Los datos de contacto se llenan en src/datos/contenido.ts (objeto `contacto`).
import { Clock, Mail, MapPin, Navigation, Phone, ShieldCheck } from 'lucide-react';
import type { ReactNode } from 'react';
import { Link } from 'react-router';
import { contacto } from '../datos/contenido';
import { Logo, Pendiente } from './Basicos';
import { BotonWhatsApp, enlaces } from './Encabezado';
import { CuboIcono } from './hero/CuboCircuito';

const servicios = [
  { a: '/reparaciones', texto: 'Reparación de equipos' },
  { a: '/reparaciones', texto: 'Mantenimiento' },
  { a: '/productos', texto: 'Venta de equipos' },
  { a: '/desarrollo', texto: 'Desarrollo de software' },
  { a: '/cursos', texto: 'Cursos (próximamente)' },
];

function Dato({ icono, titulo, valor, href }: { icono: ReactNode; titulo: string; valor: string | null; href?: string }) {
  return (
    <li className="flex items-start gap-3">
      <span className="mt-0.5 grid size-8 shrink-0 place-items-center rounded-lg bg-cian/10 text-cian ring-1 ring-cian/20">{icono}</span>
      <span className="min-w-0">
        <span className="block text-xs text-gris/70">{titulo}</span>
        {valor === null ? (
          <Pendiente />
        ) : href ? (
          <a href={href} className="break-words text-hueso/90 transition-colors hover:text-brillo">
            {valor}
          </a>
        ) : (
          <span className="break-words text-hueso/90">{valor}</span>
        )}
      </span>
    </li>
  );
}

function Columna({ titulo, children }: { titulo: string; children: ReactNode }) {
  return (
    <div>
      <h2 className="etiqueta-tecnica mb-5 text-cian">{titulo}</h2>
      {children}
    </div>
  );
}

function ListaEnlaces({ items }: { items: { a: string; texto: string }[] }) {
  return (
    <ul className="space-y-2.5 text-sm">
      {items.map((e) => (
        <li key={e.texto}>
          <Link to={e.a} className="group inline-flex items-center gap-2 text-gris transition-colors hover:text-brillo">
            <span className="h-px w-0 bg-brillo transition-all duration-300 group-hover:w-3" />
            {e.texto}
          </Link>
        </li>
      ))}
    </ul>
  );
}

export function PiePagina() {
  const { telefono, correo, ciudad, direccion, horario } = contacto;
  return (
    <footer className="relative overflow-hidden border-t border-cian/10 bg-[linear-gradient(180deg,#04203F_0%,#011631_100%)]">
      {/* Decoración: línea de luz superior, rejilla y cubo de marca de agua */}
      <div aria-hidden className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-brillo/70 to-transparent" />
      <div aria-hidden className="fondo-rejilla absolute inset-0 opacity-40" />
      <CuboIcono className="pointer-events-none absolute -right-16 -bottom-24 size-[26rem] opacity-[0.05]" />

      <div className="contenedor relative grid gap-12 py-16 sm:grid-cols-2 lg:grid-cols-[1.5fr_1fr_1fr_1.4fr]">
        <div className="sm:col-span-2 lg:col-span-1">
          <Link to="/" aria-label="Systemic Tech & Support, ir al inicio" className="inline-block">
            <Logo grande />
          </Link>
          <p className="mt-6 max-w-sm text-sm leading-relaxed text-gris">
            Reparación, mantenimiento, venta de equipos y desarrollo de software. Tu aliado tecnológico en Colombia.
          </p>
          <p className="mt-4 inline-flex items-center gap-2 rounded-lg border border-cian/20 bg-cian/5 px-3 py-2 text-xs text-hueso/90">
            <ShieldCheck className="size-4 text-cian" />
            Compra o solicita un servicio sin crear cuenta
          </p>
          <div className="mt-6">
            <BotonWhatsApp />
          </div>
        </div>

        <Columna titulo="Navegación">
          <nav aria-label="Pie de página">
            <ListaEnlaces items={enlaces} />
          </nav>
        </Columna>

        <Columna titulo="Servicios">
          <ListaEnlaces items={servicios} />
        </Columna>

        <Columna titulo="Contacto">
          <ul className="space-y-4 text-sm">
            <Dato icono={<Phone className="size-4" />} titulo="Teléfono" valor={telefono} href={telefono ? `tel:${telefono.replace(/[^\d+]/g, '')}` : undefined} />
            <Dato icono={<Mail className="size-4" />} titulo="Correo" valor={correo} href={correo ? `mailto:${correo}` : undefined} />
            <Dato icono={<Navigation className="size-4" />} titulo="Ciudad" valor={ciudad} />
            <Dato icono={<MapPin className="size-4" />} titulo="Dirección" valor={direccion} />
            <Dato icono={<Clock className="size-4" />} titulo="Horario" valor={horario} />
          </ul>
        </Columna>
      </div>

      <div className="relative border-t border-white/5">
        <div className="contenedor flex flex-col items-center justify-between gap-3 py-6 text-xs text-gris/80 sm:flex-row">
          <p>© {new Date().getFullYear()} Systemic Tech &amp; Support · Todos los derechos reservados</p>
          <Link to="/privacidad" className="transition-colors hover:text-brillo">
            Política de tratamiento de datos
          </Link>
        </div>
      </div>
    </footer>
  );
}
