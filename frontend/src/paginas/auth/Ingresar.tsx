import { ArrowRight, Lock, Mail } from 'lucide-react';
import { useEffect, useState, type FormEvent } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router';
import { errorEnUrl, mensajeAuth } from '../../auth/errores';
import { destinoSeguro, useSesion } from '../../auth/Sesion';
import { Aviso, BotonEnviar, Campo, correoValido } from '../../components/Formulario';
import { supabase } from '../../lib/supabase';
import { DisenoAcceso } from './DisenoAcceso';

export function Ingresar() {
  const [params] = useSearchParams();
  const navegar = useNavigate();
  const { sesion, lista } = useSesion();
  const siguiente = destinoSeguro(params.get('siguiente'));

  const [correo, setCorreo] = useState('');
  const [clave, setClave] = useState('');
  const [errores, setErrores] = useState<{ correo?: string; clave?: string }>({});
  const [error, setError] = useState<string | null>(errorEnUrl);
  const [cargando, setCargando] = useState(false);

  // Ya tiene sesión (o acaba de confirmar su correo con el enlace): seguir de largo.
  useEffect(() => {
    if (lista && sesion) navegar(siguiente, { replace: true });
  }, [lista, sesion, siguiente, navegar]);

  async function enviar(e: FormEvent) {
    e.preventDefault();
    const nuevos = {
      correo: correoValido(correo) ? undefined : 'Escribe un correo válido.',
      clave: clave ? undefined : 'Escribe tu contraseña.',
    };
    setErrores(nuevos);
    if (nuevos.correo || nuevos.clave || !supabase) return;
    setCargando(true);
    setError(null);
    const { error } = await supabase.auth.signInWithPassword({ email: correo.trim(), password: clave });
    setCargando(false);
    if (error) setError(mensajeAuth(error));
    // Si todo sale bien, onAuthStateChange actualiza la sesión y el efecto de arriba redirige.
  }

  return (
    <DisenoAcceso
      etiqueta="Ingresar"
      titulo="Bienvenido de nuevo"
      descripcion="Ingresa para ver tus pedidos, reparaciones, cotizaciones y proyectos."
      pie={
        <>
          ¿No tienes cuenta?{' '}
          <Link to={`/registro${params.get('siguiente') ? `?siguiente=${encodeURIComponent(siguiente)}` : ''}`} className="font-semibold text-cian hover:text-brillo">
            Créala gratis
          </Link>
          <span className="mt-2 block text-xs">Recuerda: puedes comprar y pedir servicios sin cuenta.</span>
        </>
      }
    >
      <form onSubmit={enviar} noValidate className="space-y-5">
        {params.get('confirmado') && !error && <Aviso tipo="exito">¡Correo confirmado! Ya puedes ingresar.</Aviso>}
        {error && <Aviso tipo="error">{error}</Aviso>}
        <Campo
          etiqueta="Correo electrónico"
          icono={Mail}
          type="email"
          autoComplete="email"
          inputMode="email"
          placeholder="tucorreo@ejemplo.com"
          value={correo}
          onChange={(e) => setCorreo(e.target.value)}
          error={errores.correo}
          required
        />
        <div>
          <Campo
            etiqueta="Contraseña"
            icono={Lock}
            type="password"
            autoComplete="current-password"
            value={clave}
            onChange={(e) => setClave(e.target.value)}
            error={errores.clave}
            required
          />
          <div className="mt-2 text-right">
            <Link to="/recuperar" className="text-sm text-cian hover:text-brillo">
              ¿Olvidaste tu contraseña?
            </Link>
          </div>
        </div>
        <BotonEnviar cargando={cargando}>
          Ingresar <ArrowRight className="size-4" />
        </BotonEnviar>
      </form>
    </DisenoAcceso>
  );
}
