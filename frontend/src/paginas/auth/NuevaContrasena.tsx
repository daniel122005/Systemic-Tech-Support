// Se abre desde el enlace del correo de recuperación. supabase-js canjea el código de la URL
// por una sesión temporal y aquí se fija la nueva contraseña.
import { Lock } from 'lucide-react';
import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router';
import { errorEnUrl, mensajeAuth } from '../../auth/errores';
import { useSesion } from '../../auth/Sesion';
import { Aviso, BotonEnviar, Campo, claveValida, ReglasClave } from '../../components/Formulario';
import { supabase } from '../../lib/supabase';
import { DisenoAcceso } from './DisenoAcceso';

export function NuevaContrasena() {
  const { sesion, lista } = useSesion();
  const navegar = useNavigate();
  const [clave, setClave] = useState('');
  const [confirmar, setConfirmar] = useState('');
  const [errores, setErrores] = useState<{ clave?: string; confirmar?: string }>({});
  const [error, setError] = useState<string | null>(errorEnUrl);
  const [cargando, setCargando] = useState(false);

  async function enviar(e: FormEvent) {
    e.preventDefault();
    const nuevos = {
      clave: claveValida(clave) ? undefined : 'La contraseña no cumple los requisitos.',
      confirmar: confirmar === clave ? undefined : 'Las contraseñas no coinciden.',
    };
    setErrores(nuevos);
    if (nuevos.clave || nuevos.confirmar || !supabase) return;
    setCargando(true);
    setError(null);
    const { error } = await supabase.auth.updateUser({ password: clave });
    setCargando(false);
    if (error) return setError(mensajeAuth(error));
    navegar('/cuenta?clave=actualizada', { replace: true });
  }

  const sinEnlace = lista && !sesion;

  return (
    <DisenoAcceso etiqueta="Nueva contraseña" titulo="Crea una nueva contraseña" descripcion={sinEnlace ? undefined : 'Elige una contraseña segura que no uses en otros sitios.'}>
      {error && (
        <div className="mb-5">
          <Aviso tipo="error">{error}</Aviso>
        </div>
      )}
      {sinEnlace ? (
        <div className="space-y-4 text-sm text-gris">
          <p>Para cambiar tu contraseña abre el enlace que te enviamos al correo, o solicita uno nuevo.</p>
          <Link to="/recuperar" className="btn-secundario w-full">
            Solicitar un enlace nuevo
          </Link>
        </div>
      ) : (
        <form onSubmit={enviar} noValidate className="space-y-5">
          <Campo
            etiqueta="Nueva contraseña"
            icono={Lock}
            type="password"
            autoComplete="new-password"
            value={clave}
            onChange={(e) => setClave(e.target.value)}
            error={errores.clave}
            ayuda={<ReglasClave clave={clave} />}
            required
          />
          <Campo etiqueta="Confirmar contraseña" icono={Lock} type="password" autoComplete="new-password" value={confirmar} onChange={(e) => setConfirmar(e.target.value)} error={errores.confirmar} required />
          <BotonEnviar cargando={cargando || !lista}>Guardar contraseña</BotonEnviar>
        </form>
      )}
    </DisenoAcceso>
  );
}
