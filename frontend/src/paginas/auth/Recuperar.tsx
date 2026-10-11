// Recuperar contraseña (RF-04): Supabase envía un enlace que abre /nueva-contrasena.
import { Mail, MailCheck } from 'lucide-react';
import { useState, type FormEvent } from 'react';
import { Link } from 'react-router';
import { mensajeAuth } from '../../auth/errores';
import { Aviso, BotonEnviar, Campo, correoValido } from '../../components/Formulario';
import { supabase } from '../../lib/supabase';
import { DisenoAcceso } from './DisenoAcceso';

export function Recuperar() {
  const [correo, setCorreo] = useState('');
  const [errorCampo, setErrorCampo] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [enviado, setEnviado] = useState(false);
  const [cargando, setCargando] = useState(false);

  async function enviar(e: FormEvent) {
    e.preventDefault();
    if (!correoValido(correo)) return setErrorCampo('Escribe un correo válido.');
    setErrorCampo(null);
    if (!supabase) return;
    setCargando(true);
    setError(null);
    const { error } = await supabase.auth.resetPasswordForEmail(correo.trim(), {
      redirectTo: `${window.location.origin}/nueva-contrasena`,
    });
    setCargando(false);
    if (error) return setError(mensajeAuth(error));
    setEnviado(true);
  }

  return (
    <DisenoAcceso
      etiqueta="Recuperar acceso"
      titulo={enviado ? 'Revisa tu correo' : '¿Olvidaste tu contraseña?'}
      descripcion={enviado ? undefined : 'Escribe el correo de tu cuenta y te enviaremos un enlace para crear una nueva.'}
      pie={
        <Link to="/ingresar" className="font-semibold text-cian hover:text-brillo">
          Volver a ingresar
        </Link>
      }
    >
      {enviado ? (
        <div className="space-y-4 text-center">
          <span className="mx-auto grid size-16 place-items-center rounded-2xl bg-cian/10 text-brillo ring-1 ring-cian/30">
            <MailCheck className="size-8" />
          </span>
          {/* Mismo mensaje exista o no la cuenta: no revelamos qué correos están registrados. */}
          <p className="text-hueso/90">
            Si <strong className="text-brillo">{correo.trim()}</strong> tiene una cuenta, recibirás un enlace para restablecer tu contraseña.
          </p>
          <p className="text-sm text-gris">Ábrelo en este mismo navegador. Revisa también la carpeta de spam.</p>
        </div>
      ) : (
        <form onSubmit={enviar} noValidate className="space-y-5">
          {error && <Aviso tipo="error">{error}</Aviso>}
          <Campo etiqueta="Correo electrónico" icono={Mail} type="email" inputMode="email" autoComplete="email" value={correo} onChange={(e) => setCorreo(e.target.value)} error={errorCampo} required />
          <BotonEnviar cargando={cargando}>Enviar enlace</BotonEnviar>
        </form>
      )}
    </DisenoAcceso>
  );
}
