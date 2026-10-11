// Mi cuenta (RF-05): perfil desde el backend (GET/PUT /api/cuenta/yo) con el token de Supabase.
// Las demás secciones (pedidos, cotizaciones, proyectos…) se conectan en las próximas tareas.
import { motion } from 'framer-motion';
import { Bell, FileText, FolderKanban, History, LogOut, Mail, Package, Phone, ReceiptText, RefreshCw, UserRound } from 'lucide-react';
import { useCallback, useEffect, useState, type ChangeEvent, type FormEvent } from 'react';
import { useSearchParams } from 'react-router';
import { useSesion } from '../auth/Sesion';
import { Escalonado, varianteHijo } from '../components/Aparecer';
import { Aviso, BotonEnviar, Campo, correoValido, limpiarTelefono, telefonoValido } from '../components/Formulario';
import { api, ErrorApi, type Perfil } from '../lib/api';
import { supabase } from '../lib/supabase';

const secciones = [
  { icono: Package, titulo: 'Mis pedidos', texto: 'Estado e historial de tus compras' },
  { icono: FileText, titulo: 'Cotizaciones', texto: 'Revisa, acepta o rechaza' },
  { icono: FolderKanban, titulo: 'Proyectos', texto: 'Avance de tu desarrollo de software' },
  { icono: ReceiptText, titulo: 'Facturas', texto: 'Consulta y descarga tus facturas' },
  { icono: History, titulo: 'Historial', texto: 'Servicios y reparaciones anteriores' },
  { icono: Bell, titulo: 'Notificaciones', texto: 'Novedades de tus solicitudes' },
];

type Estado = { tipo: 'cargando' } | { tipo: 'error'; mensaje: string } | { tipo: 'listo'; perfil: Perfil };

function FormularioPerfil({ perfil, token, alGuardar }: { perfil: Perfil; token: string; alGuardar: (p: Perfil) => void }) {
  const [f, setF] = useState({
    nombres: perfil.nombres ?? '',
    apellidos: perfil.apellidos ?? '',
    telefono: perfil.telefono ?? '',
    correo_contacto: perfil.correo_contacto ?? '',
  });
  const [errores, setErrores] = useState<Partial<Record<keyof typeof f, string>>>({});
  const [aviso, setAviso] = useState<{ tipo: 'exito' | 'error'; texto: string } | null>(null);
  const [cargando, setCargando] = useState(false);

  async function guardar(e: FormEvent) {
    e.preventDefault();
    const tel = limpiarTelefono(f.telefono);
    const sinContacto = !tel && !f.correo_contacto.trim();
    const nuevos = {
      nombres: f.nombres.trim() ? undefined : 'Escribe tu nombre.',
      telefono: sinContacto ? 'Deja al menos un teléfono o un correo de contacto.' : !tel || telefonoValido(tel) ? undefined : 'Escribe un teléfono válido.',
      correo_contacto: !f.correo_contacto.trim() || correoValido(f.correo_contacto) ? undefined : 'Escribe un correo válido.',
    };
    setErrores(nuevos);
    if (Object.values(nuevos).some(Boolean)) return;
    setCargando(true);
    setAviso(null);
    try {
      const actualizado = await api.actualizarPerfil(token, {
        nombres: f.nombres.trim(),
        apellidos: f.apellidos.trim() || null,
        telefono: tel || null,
        correo_contacto: f.correo_contacto.trim() || null,
      });
      alGuardar(actualizado);
      setAviso({ tipo: 'exito', texto: 'Tus datos se guardaron.' });
      // El encabezado muestra el nombre desde la sesión de Supabase: se sincroniza para que no quede el anterior.
      await supabase?.auth.updateUser({ data: { nombres: actualizado.nombres } }).catch(() => undefined);
    } catch (err) {
      setAviso({ tipo: 'error', texto: err instanceof ErrorApi ? err.message : 'No pudimos guardar los cambios.' });
    } finally {
      setCargando(false);
    }
  }

  const cambiar = (k: keyof typeof f) => (e: ChangeEvent<HTMLInputElement>) => setF({ ...f, [k]: e.target.value });

  return (
    <form onSubmit={guardar} noValidate className="space-y-5">
      {aviso && <Aviso tipo={aviso.tipo}>{aviso.texto}</Aviso>}
      <div className="grid gap-5 sm:grid-cols-2">
        <Campo etiqueta="Nombres" icono={UserRound} autoComplete="given-name" value={f.nombres} onChange={cambiar('nombres')} error={errores.nombres} required />
        <Campo etiqueta="Apellidos" autoComplete="family-name" value={f.apellidos} onChange={cambiar('apellidos')} />
        <Campo etiqueta="Teléfono / celular" icono={Phone} type="tel" autoComplete="tel" value={f.telefono} onChange={cambiar('telefono')} error={errores.telefono} />
        <Campo
          etiqueta="Correo de contacto"
          icono={Mail}
          type="email"
          autoComplete="email"
          value={f.correo_contacto}
          onChange={cambiar('correo_contacto')}
          error={errores.correo_contacto}
          ayuda="Donde te escribimos sobre tus pedidos y servicios."
        />
      </div>
      <div className="sm:max-w-xs">
        <BotonEnviar cargando={cargando}>Guardar cambios</BotonEnviar>
      </div>
    </form>
  );
}

export function MiCuenta() {
  const { sesion, nombre, cerrarSesion } = useSesion();
  const [params] = useSearchParams();
  const [estado, setEstado] = useState<Estado>({ tipo: 'cargando' });
  const token = sesion?.access_token ?? '';

  const cargar = useCallback(
    (signal?: AbortSignal) => {
      setEstado({ tipo: 'cargando' });
      api
        .perfil(token, signal)
        .then((perfil) => setEstado({ tipo: 'listo', perfil }))
        .catch((e: unknown) => {
          if ((e as Error).name === 'AbortError') return;
          setEstado({ tipo: 'error', mensaje: e instanceof ErrorApi ? e.message : 'No pudimos cargar tu cuenta.' });
        });
    },
    [token],
  );

  // Se carga una vez por usuario (el token se renueva solo cada hora y no hace falta recargar).
  const usuarioId = sesion?.user.id;
  useEffect(() => {
    const c = new AbortController();
    cargar(c.signal);
    return () => c.abort();
  }, [usuarioId]);

  const perfil = estado.tipo === 'listo' ? estado.perfil : null;

  return (
    <section className="relative isolate pt-28 pb-24 lg:pt-36">
      <div aria-hidden className="fondo-rejilla absolute inset-x-0 top-0 -z-10 h-[32rem]" />
      <div className="contenedor">
        <motion.header initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} className="flex flex-wrap items-end justify-between gap-6">
          <div>
            <p className="etiqueta-tecnica text-cian">{'// '}Mi cuenta</p>
            <h1 className="mt-3 font-display text-3xl font-bold tracking-tight sm:text-4xl">
              Hola, <span className="text-cian">{perfil?.nombres ?? nombre ?? ''}</span>
            </h1>
            <p className="mt-2 text-gris">{sesion?.user.email}</p>
            {perfil && perfil.roles.length > 0 && (
              <ul className="mt-3 flex flex-wrap gap-2">
                {perfil.roles.map((r) => (
                  <li key={r} className="rounded-md bg-cian/10 px-2 py-0.5 font-mono text-xs text-cian capitalize">
                    {r}
                  </li>
                ))}
              </ul>
            )}
          </div>
          <button type="button" onClick={cerrarSesion} className="btn-secundario">
            <LogOut className="size-4" /> Cerrar sesión
          </button>
        </motion.header>

        {params.get('clave') === 'actualizada' && (
          <div className="mt-8">
            <Aviso tipo="exito">Tu contraseña se actualizó correctamente.</Aviso>
          </div>
        )}

        <div className="mt-10 grid gap-8 lg:grid-cols-[1.3fr_1fr]">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 }}
            className="rounded-3xl border border-cian/15 bg-noche-2/70 p-6 sm:p-8"
          >
            <h2 className="font-display text-xl font-semibold">Mis datos</h2>
            <p className="mt-1 mb-6 text-sm text-gris">Mantén tus datos al día para que podamos contactarte.</p>
            {estado.tipo === 'cargando' && (
              <div className="grid gap-5 sm:grid-cols-2" aria-busy="true">
                {Array.from({ length: 4 }, (_, i) => (
                  <div key={i} className="h-[4.5rem] animate-pulse rounded-xl bg-white/5" />
                ))}
              </div>
            )}
            {estado.tipo === 'error' && (
              <div className="space-y-4">
                <Aviso tipo="error">{estado.mensaje}</Aviso>
                <button type="button" onClick={() => cargar()} className="btn-secundario">
                  <RefreshCw className="size-4" /> Reintentar
                </button>
              </div>
            )}
            {perfil && <FormularioPerfil key={perfil.usuario_id} perfil={perfil} token={token} alGuardar={(p) => setEstado({ tipo: 'listo', perfil: p })} />}
          </motion.div>

          <div>
            <h2 className="etiqueta-tecnica mb-4 text-gris">Tu actividad</h2>
            <Escalonado className="grid gap-3 sm:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2">
              {secciones.map(({ icono: Icono, titulo, texto }) => (
                <motion.div key={titulo} variants={varianteHijo} className="flex items-start gap-3 rounded-2xl border border-white/5 bg-noche-2/50 p-4">
                  <span className="grid size-10 shrink-0 place-items-center rounded-xl bg-cian/10 text-cian ring-1 ring-cian/20">
                    <Icono className="size-5" />
                  </span>
                  <span>
                    <span className="block font-semibold">{titulo}</span>
                    <span className="block text-xs text-gris">{texto}</span>
                    <span className="mt-1.5 inline-block rounded bg-white/5 px-1.5 py-0.5 font-mono text-[0.6rem] tracking-wider text-gris uppercase">Próximamente</span>
                  </span>
                </motion.div>
              ))}
            </Escalonado>
          </div>
        </div>
      </div>
    </section>
  );
}
