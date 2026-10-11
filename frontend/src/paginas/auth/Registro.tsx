// Registro (RF-02). Supabase Auth crea el usuario y un trigger de la base crea
// automáticamente persona, usuario y cliente con los datos de `options.data` (nombres, apellidos, telefono).
import { Lock, Mail, MailCheck, Phone, UserRound } from 'lucide-react';
import { useState, type ChangeEvent, type FormEvent } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router';
import { mensajeAuth } from '../../auth/errores';
import { destinoSeguro } from '../../auth/Sesion';
import { Aviso, BotonEnviar, Campo, claveValida, correoValido, limpiarTelefono, ReglasClave, telefonoValido } from '../../components/Formulario';
import { supabase } from '../../lib/supabase';
import { DisenoAcceso } from './DisenoAcceso';

/** Cambia este número si se publica una nueva versión de la política de datos. */
const VERSION_POLITICA = '[DATO REAL PENDIENTE]';

type Errores = Partial<Record<'nombres' | 'correo' | 'telefono' | 'clave' | 'confirmar' | 'acepta', string>>;

export function Registro() {
  const [params] = useSearchParams();
  const navegar = useNavigate();
  const [f, setF] = useState({ nombres: '', apellidos: '', correo: '', telefono: '', clave: '', confirmar: '' });
  const [acepta, setAcepta] = useState(false);
  const [errores, setErrores] = useState<Errores>({});
  const [error, setError] = useState<string | null>(null);
  const [enviadoA, setEnviadoA] = useState<string | null>(null);
  const [cargando, setCargando] = useState(false);
  const cambiar = (k: keyof typeof f) => (e: ChangeEvent<HTMLInputElement>) => setF({ ...f, [k]: e.target.value });

  async function enviar(e: FormEvent) {
    e.preventDefault();
    const tel = limpiarTelefono(f.telefono);
    const nuevos: Errores = {
      nombres: f.nombres.trim() ? undefined : 'Escribe tu nombre.',
      correo: correoValido(f.correo) ? undefined : 'Escribe un correo válido.',
      telefono: !tel || telefonoValido(tel) ? undefined : 'Escribe un teléfono válido (solo números).',
      clave: claveValida(f.clave) ? undefined : 'La contraseña no cumple los requisitos.',
      confirmar: f.confirmar === f.clave ? undefined : 'Las contraseñas no coinciden.',
      acepta: acepta ? undefined : 'Debes aceptar la política de tratamiento de datos.',
    };
    setErrores(nuevos);
    if (Object.values(nuevos).some(Boolean) || !supabase) return;

    setCargando(true);
    setError(null);
    const siguiente = destinoSeguro(params.get('siguiente'));
    const { data, error } = await supabase.auth.signUp({
      email: f.correo.trim(),
      password: f.clave,
      options: {
        emailRedirectTo: `${window.location.origin}/ingresar?confirmado=1&siguiente=${encodeURIComponent(siguiente)}`,
        data: {
          nombres: f.nombres.trim(),
          apellidos: f.apellidos.trim() || undefined,
          telefono: tel || undefined,
          // Constancia de autorización de tratamiento de datos (Ley 1581 de 2012).
          acepta_tratamiento_datos: true,
          acepta_tratamiento_datos_en: new Date().toISOString(),
          politica_datos_version: VERSION_POLITICA,
        },
      },
    });
    setCargando(false);
    if (error) return setError(mensajeAuth(error));
    // Si el proyecto no exige confirmar el correo, Supabase ya devuelve la sesión.
    if (data.session) return navegar(siguiente, { replace: true });
    // Por seguridad Supabase no revela si el correo ya existía: en ambos casos mostramos lo mismo.
    if (data.user) setEnviadoA(f.correo.trim());
  }

  if (enviadoA) {
    return (
      <DisenoAcceso etiqueta="Registro" titulo="Revisa tu correo" pie={<Link to="/ingresar" className="font-semibold text-cian hover:text-brillo">Ir a ingresar</Link>}>
        <div className="space-y-5 text-center">
          <span className="mx-auto grid size-16 place-items-center rounded-2xl bg-cian/10 text-brillo ring-1 ring-cian/30">
            <MailCheck className="size-8" />
          </span>
          <p className="text-hueso/90">
            Enviamos un enlace de confirmación a <strong className="text-brillo">{enviadoA}</strong>.
          </p>
          <p className="text-sm text-gris">Ábrelo para activar tu cuenta. Si no lo ves en unos minutos, revisa la carpeta de spam o correo no deseado.</p>
        </div>
      </DisenoAcceso>
    );
  }

  return (
    <DisenoAcceso
      etiqueta="Crear cuenta"
      titulo="Crea tu cuenta"
      descripcion="Es opcional: te sirve para hacer seguimiento a tus pedidos, servicios y proyectos."
      pie={
        <>
          ¿Ya tienes cuenta?{' '}
          <Link to="/ingresar" className="font-semibold text-cian hover:text-brillo">
            Ingresa
          </Link>
        </>
      }
    >
      <form onSubmit={enviar} noValidate className="space-y-5">
        {error && <Aviso tipo="error">{error}</Aviso>}
        <div className="grid gap-5 sm:grid-cols-2">
          <Campo etiqueta="Nombres" icono={UserRound} autoComplete="given-name" value={f.nombres} onChange={cambiar('nombres')} error={errores.nombres} required />
          <Campo etiqueta="Apellidos" autoComplete="family-name" value={f.apellidos} onChange={cambiar('apellidos')} />
        </div>
        <Campo etiqueta="Correo electrónico" icono={Mail} type="email" inputMode="email" autoComplete="email" placeholder="tucorreo@ejemplo.com" value={f.correo} onChange={cambiar('correo')} error={errores.correo} required />
        <Campo etiqueta="Teléfono / celular" icono={Phone} type="tel" inputMode="tel" autoComplete="tel" placeholder="Opcional" value={f.telefono} onChange={cambiar('telefono')} error={errores.telefono} />
        <Campo
          etiqueta="Contraseña"
          icono={Lock}
          type="password"
          autoComplete="new-password"
          value={f.clave}
          onChange={cambiar('clave')}
          error={errores.clave}
          ayuda={<ReglasClave clave={f.clave} />}
          required
        />
        <Campo etiqueta="Confirmar contraseña" icono={Lock} type="password" autoComplete="new-password" value={f.confirmar} onChange={cambiar('confirmar')} error={errores.confirmar} required />

        <div>
          <label className="flex cursor-pointer items-start gap-3 text-sm text-gris">
            <input
              type="checkbox"
              checked={acepta}
              onChange={(e) => setAcepta(e.target.checked)}
              aria-invalid={errores.acepta ? true : undefined}
              className="mt-0.5 size-4.5 shrink-0 cursor-pointer accent-[#08C6C4]"
            />
            <span>
              Autorizo el tratamiento de mis datos personales según la{' '}
              <Link to="/privacidad" target="_blank" className="text-cian underline-offset-2 hover:underline">
                política de tratamiento de datos
              </Link>
              .
            </span>
          </label>
          {errores.acepta && <p className="mt-1.5 text-xs text-red-300">{errores.acepta}</p>}
        </div>

        <BotonEnviar cargando={cargando}>Crear cuenta</BotonEnviar>
      </form>
    </DisenoAcceso>
  );
}
