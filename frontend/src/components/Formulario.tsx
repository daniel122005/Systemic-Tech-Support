// Piezas de formulario accesibles: etiqueta visible, error asociado (aria-describedby) e ícono.
import { AnimatePresence, motion } from 'framer-motion';
import { CircleAlert, CircleCheck, Eye, EyeOff, LoaderCircle, type LucideIcon } from 'lucide-react';
import { useId, useState, type InputHTMLAttributes, type ReactNode, type TextareaHTMLAttributes } from 'react';

interface CampoProps extends InputHTMLAttributes<HTMLInputElement> {
  etiqueta: string;
  icono?: LucideIcon;
  error?: string | null;
  ayuda?: ReactNode;
}

export function Campo({ etiqueta, icono: Icono, error, ayuda, type = 'text', className = '', ...resto }: CampoProps) {
  const id = useId();
  const [visible, setVisible] = useState(false);
  const esClave = type === 'password';
  const describe = [error ? `${id}-error` : null, ayuda ? `${id}-ayuda` : null].filter(Boolean).join(' ') || undefined;

  return (
    <div className={className}>
      <label htmlFor={id} className="mb-1.5 block text-sm font-medium text-hueso/90">
        {etiqueta}
        {resto.required && <span className="text-cian"> *</span>}
      </label>
      <div className="relative">
        {Icono && <Icono aria-hidden className="pointer-events-none absolute top-1/2 left-3.5 size-4.5 -translate-y-1/2 text-gris" />}
        <input
          id={id}
          type={esClave && visible ? 'text' : type}
          aria-invalid={error ? true : undefined}
          aria-describedby={describe}
          className={`w-full rounded-xl border bg-noche/60 py-3 text-hueso placeholder:text-gris/50 transition-[border-color,box-shadow] outline-none focus:shadow-[0_0_0_3px_rgba(8,198,196,0.18)] ${
            Icono ? 'pl-10' : 'pl-4'
          } ${esClave ? 'pr-11' : 'pr-4'} ${error ? 'border-red-400/70 focus:border-red-400' : 'border-white/10 hover:border-white/20 focus:border-cian'}`}
          {...resto}
        />
        {esClave && (
          <button
            type="button"
            onClick={() => setVisible((v) => !v)}
            aria-label={visible ? 'Ocultar contraseña' : 'Mostrar contraseña'}
            aria-pressed={visible}
            className="absolute top-1/2 right-2 grid size-8 -translate-y-1/2 place-items-center rounded-lg text-gris hover:text-hueso"
          >
            {visible ? <EyeOff className="size-4.5" /> : <Eye className="size-4.5" />}
          </button>
        )}
      </div>
      {ayuda && !error && (
        <div id={`${id}-ayuda`} className="mt-1.5 text-xs text-gris">
          {ayuda}
        </div>
      )}
      {error && (
        <p id={`${id}-error`} className="mt-1.5 flex items-center gap-1.5 text-xs text-red-300">
          <CircleAlert className="size-3.5 shrink-0" /> {error}
        </p>
      )}
    </div>
  );
}

export function AreaTexto({ etiqueta, error, className = '', ...resto }: TextareaHTMLAttributes<HTMLTextAreaElement> & { etiqueta: string; error?: string | null }) {
  const id = useId();
  return (
    <div className={className}>
      <label htmlFor={id} className="mb-1.5 block text-sm font-medium text-hueso/90">
        {etiqueta}
      </label>
      <textarea
        id={id}
        rows={4}
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? `${id}-error` : undefined}
        className={`w-full resize-y rounded-xl border bg-noche/60 px-4 py-3 text-hueso placeholder:text-gris/50 transition-[border-color,box-shadow] outline-none focus:shadow-[0_0_0_3px_rgba(8,198,196,0.18)] ${
          error ? 'border-red-400/70' : 'border-white/10 hover:border-white/20 focus:border-cian'
        }`}
        {...resto}
      />
      {error && (
        <p id={`${id}-error`} className="mt-1.5 flex items-center gap-1.5 text-xs text-red-300">
          <CircleAlert className="size-3.5 shrink-0" /> {error}
        </p>
      )}
    </div>
  );
}

/** Mensaje general del formulario (error o éxito), anunciado a lectores de pantalla. */
export function Aviso({ tipo, children }: { tipo: 'error' | 'exito' | 'info'; children: ReactNode }) {
  const estilos = {
    error: 'border-red-400/40 bg-red-500/10 text-red-200',
    exito: 'border-cian/40 bg-cian/10 text-hueso',
    info: 'border-amber-300/40 bg-amber-300/10 text-amber-100',
  }[tipo];
  const Icono = tipo === 'exito' ? CircleCheck : CircleAlert;
  return (
    <motion.div
      role={tipo === 'error' ? 'alert' : 'status'}
      initial={{ opacity: 0, y: -6 }}
      animate={{ opacity: 1, y: 0 }}
      className={`flex gap-3 rounded-xl border p-4 text-sm ${estilos}`}
    >
      <Icono className={`mt-0.5 size-4.5 shrink-0 ${tipo === 'exito' ? 'text-brillo' : ''}`} />
      <div>{children}</div>
    </motion.div>
  );
}

export function BotonEnviar({ cargando, children }: { cargando: boolean; children: ReactNode }) {
  return (
    <button type="submit" disabled={cargando} className="btn-primario w-full py-3.5 disabled:cursor-wait disabled:opacity-70">
      <AnimatePresence mode="wait" initial={false}>
        {cargando ? (
          <motion.span key="c" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="flex items-center gap-2">
            <LoaderCircle className="size-4.5 animate-spin" /> Un momento…
          </motion.span>
        ) : (
          <motion.span key="t" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="flex items-center gap-2">
            {children}
          </motion.span>
        )}
      </AnimatePresence>
    </button>
  );
}

/** Reglas de contraseña con indicador en vivo. */
export const reglasClave = [
  { texto: 'Mínimo 8 caracteres', cumple: (c: string) => c.length >= 8 },
  { texto: 'Al menos una letra', cumple: (c: string) => /[A-Za-zÁÉÍÓÚáéíóúÑñ]/.test(c) },
  { texto: 'Al menos un número', cumple: (c: string) => /\d/.test(c) },
];
export const claveValida = (c: string) => reglasClave.every((r) => r.cumple(c));

export function ReglasClave({ clave }: { clave: string }) {
  return (
    <ul className="mt-1 grid gap-1 sm:grid-cols-3">
      {reglasClave.map((r) => {
        const ok = r.cumple(clave);
        return (
          <li key={r.texto} className={`flex items-center gap-1.5 transition-colors ${ok ? 'text-brillo' : 'text-gris'}`}>
            <CircleCheck className={`size-3.5 transition-opacity ${ok ? 'opacity-100' : 'opacity-40'}`} aria-hidden />
            {r.texto}
            <span className="sr-only">{ok ? '(cumple)' : '(pendiente)'}</span>
          </li>
        );
      })}
    </ul>
  );
}

export const correoValido = (c: string) => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(c.trim());

/** Igual que el backend: quita espacios, guiones y paréntesis; admite + al inicio y 7 a 15 dígitos. */
export const limpiarTelefono = (t: string) => t.replace(/[\s()-]/g, '');
export const telefonoValido = (t: string) => /^\+?\d{7,15}$/.test(limpiarTelefono(t));
