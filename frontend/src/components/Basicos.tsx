import type { ReactNode, SVGProps } from 'react';
import { CuboIcono } from './hero/CuboCircuito';
import { PENDIENTE } from '../datos/contenido';
import { Aparecer } from './Aparecer';

/** "SYST≡MIC": la E del logo son tres barras en degradado cian. */
function Palabra() {
  return (
    <span className="flex items-center font-display font-extrabold tracking-[0.06em]">
      SYST
      <span aria-hidden className="mx-[0.06em] flex h-[0.7em] w-[0.62em] flex-col justify-between">
        {[0, 1, 2].map((i) => (
          <span key={i} className="h-[0.13em] rounded-[1px] bg-gradient-to-r from-brillo to-medio" />
        ))}
      </span>
      MIC
    </span>
  );
}

/** Logo de marca para fondo oscuro: cubo vectorial + palabra + "TECH & SUPPORT" con líneas, como el logo oficial. */
export function Logo({ compacto = false, grande = false }: { compacto?: boolean; grande?: boolean }) {
  const icono = grande ? 'size-16' : compacto ? 'size-9' : 'size-11';
  return (
    <span className="flex items-center gap-3" role="img" aria-label="Systemic Tech & Support">
      <CuboIcono className={`shrink-0 drop-shadow-[0_0_12px_rgba(8,198,196,0.5)] transition-[width,height] duration-300 ${icono}`} />
      <span className="leading-none" aria-hidden>
        <span className={`block ${grande ? 'text-3xl' : 'text-lg'}`}>
          <Palabra />
        </span>
        <span className={`mt-1.5 flex items-center gap-1.5 font-mono tracking-[0.28em] text-cian uppercase ${grande ? 'text-[0.7rem]' : 'text-[0.55rem]'}`}>
          {grande && <span className="h-px w-5 bg-gradient-to-r from-transparent to-cian" />}
          {grande && <span className="size-1 rounded-full bg-cian" />}
          Tech &amp; Support
          {grande && <span className="size-1 rounded-full bg-cian" />}
          {grande && <span className="h-px w-5 bg-gradient-to-l from-transparent to-cian" />}
        </span>
      </span>
    </span>
  );
}

export function TituloSeccion({ etiqueta, titulo, descripcion, centrado = false }: { etiqueta: string; titulo: ReactNode; descripcion?: ReactNode; centrado?: boolean }) {
  return (
    <Aparecer className={`mb-12 max-w-2xl ${centrado ? 'mx-auto text-center' : ''}`}>
      <p className="etiqueta-tecnica mb-3 text-cian">{'// '}{etiqueta}</p>
      <h2 className="font-display text-3xl font-bold tracking-tight text-balance sm:text-4xl">{titulo}</h2>
      {descripcion && <p className="mt-4 text-lg text-gris">{descripcion}</p>}
    </Aparecer>
  );
}

/** Marcador visible para datos del negocio que aún no están confirmados. */
export function Pendiente({ className = '' }: { className?: string }) {
  return <span className={`font-mono text-xs tracking-wide text-amber-300/90 ${className}`}>{PENDIENTE}</span>;
}

export function IconoWhatsApp(props: SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden {...props}>
      <path d="M17.47 14.38c-.3-.15-1.76-.87-2.03-.97-.27-.1-.47-.15-.67.15-.2.3-.77.97-.94 1.17-.17.2-.35.22-.65.07-.3-.15-1.26-.46-2.4-1.48-.89-.79-1.49-1.77-1.66-2.07-.17-.3-.02-.46.13-.61.13-.13.3-.35.45-.52.15-.17.2-.3.3-.5.1-.2.05-.37-.02-.52-.08-.15-.67-1.62-.92-2.22-.24-.58-.49-.5-.67-.51h-.57c-.2 0-.52.07-.8.37-.27.3-1.04 1.02-1.04 2.48 0 1.46 1.07 2.88 1.21 3.08.15.2 2.1 3.2 5.08 4.49.71.31 1.27.49 1.7.63.72.23 1.37.2 1.88.12.57-.09 1.76-.72 2.01-1.41.25-.7.25-1.29.17-1.41-.07-.13-.27-.2-.57-.35zM12.05 21.5h-.01a9.4 9.4 0 0 1-4.79-1.31l-.34-.2-3.56.93.95-3.47-.22-.36a9.38 9.38 0 0 1-1.44-5.01c0-5.19 4.23-9.41 9.42-9.41 2.52 0 4.88.98 6.66 2.76a9.35 9.35 0 0 1 2.75 6.66c0 5.19-4.22 9.41-9.42 9.41zm8.02-17.43A11.27 11.27 0 0 0 12.05.75C5.8.75.72 5.83.72 12.08c0 2 .52 3.95 1.52 5.66L.62 23.25l5.65-1.48a11.3 11.3 0 0 0 5.78 1.47h.01c6.25 0 11.33-5.08 11.33-11.33 0-3.03-1.18-5.87-3.32-8.01z" />
    </svg>
  );
}
