// Cursos — FASE 1: aún no hay oferta publicada. Los clientes (con o sin cuenta) dejan su interés
// y la empresa les avisa cuando abra inscripciones. Backend: POST /api/cursos/interes.
import { AnimatePresence, motion } from 'framer-motion';
import { BellRing, GraduationCap, Mail, MessageSquareText, Phone, Send, Sparkles, UserRound } from 'lucide-react';
import { useState, type ChangeEvent, type FormEvent } from 'react';
import { Link } from 'react-router';
import { useSesion } from '../auth/Sesion';
import { Escalonado, varianteHijo } from '../components/Aparecer';
import { AreaTexto, Aviso, BotonEnviar, Campo, correoValido, limpiarTelefono, telefonoValido } from '../components/Formulario';
import { api, ErrorApi, type InteresCurso } from '../lib/api';

const pasos = [
  { icono: MessageSquareText, titulo: 'Cuéntanos qué quieres aprender', texto: 'Escribe el tema que te interesa y cómo prefieres estudiarlo.' },
  { icono: BellRing, titulo: 'Te avisamos', texto: 'Cuando abramos un curso sobre ese tema, te contactamos primero.' },
  { icono: GraduationCap, titulo: 'Te inscribes', texto: 'Eliges fecha y modalidad, y empiezas a aprender con nosotros.' },
];

const modalidades = [
  { valor: 'presencial', texto: 'Presencial' },
  { valor: 'virtual', texto: 'Virtual' },
  { valor: 'cualquiera', texto: 'Me da igual' },
] as const;

type Errores = Partial<Record<'tema' | 'nombres' | 'correo' | 'telefono' | 'contacto' | 'acepta', string>>;

function Formulario() {
  const { sesion, nombre } = useSesion();
  const [f, setF] = useState({ tema: '', modalidad: '' as InteresCurso['modalidad'], mensaje: '', nombres: '', apellidos: '', correo: '', telefono: '' });
  const [trampa, setTrampa] = useState('');
  const [acepta, setAcepta] = useState(false);
  const [errores, setErrores] = useState<Errores>({});
  const [error, setError] = useState<string | null>(null);
  const [enviado, setEnviado] = useState<string | null>(null);
  const [cargando, setCargando] = useState(false);
  const cambiar = (k: keyof typeof f) => (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => setF({ ...f, [k]: e.target.value });

  async function enviar(e: FormEvent) {
    e.preventDefault();
    const tel = limpiarTelefono(f.telefono);
    const nuevos: Errores = { tema: f.tema.trim() ? undefined : 'Cuéntanos qué te gustaría aprender.' };
    if (!sesion) {
      nuevos.nombres = f.nombres.trim() ? undefined : 'Escribe tu nombre.';
      nuevos.correo = !f.correo.trim() || correoValido(f.correo) ? undefined : 'Escribe un correo válido.';
      nuevos.telefono = !tel || telefonoValido(tel) ? undefined : 'Escribe un teléfono válido (solo números).';
      nuevos.contacto = f.correo.trim() || tel ? undefined : 'Déjanos un correo o un teléfono para avisarte.';
      nuevos.acepta = acepta ? undefined : 'Debes autorizar el tratamiento de tus datos.';
    }
    setErrores(nuevos);
    if (Object.values(nuevos).some(Boolean)) return;

    setCargando(true);
    setError(null);
    try {
      const datos: InteresCurso = { tema: f.tema.trim(), modalidad: f.modalidad, mensaje: f.mensaje.trim(), sitio_web: trampa };
      if (!sesion) Object.assign(datos, { nombres: f.nombres.trim(), apellidos: f.apellidos.trim(), correo: f.correo.trim(), telefono: tel });
      const r = await api.interesCurso(datos, sesion?.access_token);
      setEnviado(r.mensaje);
    } catch (err) {
      setError(err instanceof ErrorApi ? err.message : 'No pudimos enviar tu solicitud. Inténtalo de nuevo.');
    } finally {
      setCargando(false);
    }
  }

  return (
    <AnimatePresence mode="wait">
      {enviado ? (
        <motion.div key="ok" initial={{ opacity: 0, scale: 0.96 }} animate={{ opacity: 1, scale: 1 }} className="py-10 text-center">
          <motion.span
            initial={{ scale: 0, rotate: -20 }}
            animate={{ scale: 1, rotate: 0 }}
            transition={{ type: 'spring', stiffness: 260, damping: 16, delay: 0.1 }}
            className="mx-auto grid size-20 place-items-center rounded-2xl bg-cian/10 text-brillo ring-1 ring-cian/30 shadow-[0_0_40px_-8px_#22E3E0]"
          >
            <Sparkles className="size-9" />
          </motion.span>
          <h3 className="mt-6 font-display text-2xl font-bold">¡Listo!</h3>
          <p className="mx-auto mt-2 max-w-sm text-gris">{enviado}</p>
          <button
            type="button"
            onClick={() => {
              setEnviado(null);
              setF((v) => ({ ...v, tema: '', mensaje: '' }));
            }}
            className="btn-secundario mt-8"
          >
            Me interesa otro tema
          </button>
        </motion.div>
      ) : (
        <motion.form key="form" exit={{ opacity: 0 }} onSubmit={enviar} noValidate className="space-y-5">
          {error && <Aviso tipo="error">{error}</Aviso>}
          <Campo
            etiqueta="¿Qué te gustaría aprender?"
            icono={GraduationCap}
            placeholder="Ej.: mantenimiento de computadores"
            maxLength={120}
            value={f.tema}
            onChange={cambiar('tema')}
            error={errores.tema}
            required
          />

          <fieldset>
            <legend className="mb-2 text-sm font-medium text-hueso/90">Modalidad preferida</legend>
            <div className="grid grid-cols-3 gap-2">
              {modalidades.map((m) => {
                const activo = f.modalidad === m.valor;
                return (
                  <label
                    key={m.valor}
                    className={`relative cursor-pointer rounded-xl border px-3 py-2.5 text-center text-sm transition-colors has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-brillo ${
                      activo ? 'border-cian bg-cian/10 text-brillo' : 'border-white/10 text-gris hover:border-white/25'
                    }`}
                  >
                    <input type="radio" name="modalidad" value={m.valor} checked={activo} onChange={() => setF({ ...f, modalidad: m.valor })} className="sr-only" />
                    {m.texto}
                  </label>
                );
              })}
            </div>
          </fieldset>

          <AreaTexto etiqueta="Mensaje (opcional)" placeholder="Cuéntanos tu nivel, horarios que te sirven o lo que necesites." maxLength={1000} value={f.mensaje} onChange={cambiar('mensaje')} />

          {sesion ? (
            <p className="rounded-xl border border-cian/20 bg-cian/5 p-4 text-sm text-hueso/90">
              Te contactaremos con los datos de tu cuenta, <strong className="text-brillo">{nombre}</strong>. Puedes actualizarlos en{' '}
              <Link to="/cuenta" className="text-cian underline-offset-2 hover:underline">
                Mi cuenta
              </Link>
              .
            </p>
          ) : (
            <>
              <div className="grid gap-5 sm:grid-cols-2">
                <Campo etiqueta="Nombres" icono={UserRound} autoComplete="given-name" value={f.nombres} onChange={cambiar('nombres')} error={errores.nombres} required />
                <Campo etiqueta="Apellidos" autoComplete="family-name" value={f.apellidos} onChange={cambiar('apellidos')} />
                <Campo etiqueta="Correo" icono={Mail} type="email" inputMode="email" autoComplete="email" value={f.correo} onChange={cambiar('correo')} error={errores.correo} />
                <Campo etiqueta="Teléfono / WhatsApp" icono={Phone} type="tel" inputMode="tel" autoComplete="tel" value={f.telefono} onChange={cambiar('telefono')} error={errores.telefono} />
              </div>
              {errores.contacto ? (
                <p className="-mt-2 text-xs text-red-300">{errores.contacto}</p>
              ) : (
                <p className="-mt-2 text-xs text-gris">Déjanos al menos un correo o un teléfono.</p>
              )}
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
                    Autorizo el tratamiento de mis datos para que me contacten según la{' '}
                    <Link to="/privacidad" target="_blank" className="text-cian underline-offset-2 hover:underline">
                      política de tratamiento de datos
                    </Link>
                    .
                  </span>
                </label>
                {errores.acepta && <p className="mt-1.5 text-xs text-red-300">{errores.acepta}</p>}
              </div>
            </>
          )}

          {/* Campo trampa anti-bots: oculto para personas y lectores de pantalla. */}
          <div aria-hidden className="absolute -left-[9999px] h-0 w-0 overflow-hidden">
            <label>
              No llenar
              <input type="text" name="sitio_web" tabIndex={-1} autoComplete="off" value={trampa} onChange={(e) => setTrampa(e.target.value)} />
            </label>
          </div>

          <BotonEnviar cargando={cargando}>
            Quiero que me avisen <Send className="size-4" />
          </BotonEnviar>
        </motion.form>
      )}
    </AnimatePresence>
  );
}

export function Cursos() {
  return (
    <section className="relative isolate overflow-hidden pt-28 pb-24 lg:pt-36">
      <div aria-hidden className="fondo-diagonales absolute inset-0 -z-10" />
      <div aria-hidden className="fondo-rejilla absolute inset-x-0 top-0 -z-10 h-[40rem]" />
      <div aria-hidden className="absolute -top-20 -left-20 -z-10 size-[30rem] rounded-full bg-profundo/30 blur-3xl" />

      <div className="contenedor grid gap-14 lg:grid-cols-[1fr_minmax(0,32rem)] lg:gap-20">
        <div>
          <motion.p
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            className="etiqueta-tecnica inline-flex items-center gap-2 rounded-md border border-amber-300/40 bg-amber-300/10 px-3 py-1.5 text-amber-200"
          >
            <span className="size-1.5 rounded-full bg-amber-300" /> Próximamente
          </motion.p>
          <motion.h1
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1, duration: 0.6 }}
            className="mt-6 font-display text-4xl font-extrabold tracking-tight text-balance sm:text-5xl lg:text-6xl"
          >
            Aprende tecnología <span className="texto-brillo">con nosotros</span>
          </motion.h1>
          <motion.p initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2, duration: 0.6 }} className="mt-6 max-w-xl text-lg text-gris">
            Estamos preparando cursos para que aprendas de la mano de nuestro equipo. Cuéntanos qué te interesa y te avisamos apenas abramos
            inscripciones. No necesitas crear cuenta.
          </motion.p>

          <Escalonado intervalo={0.15} className="relative mt-12 space-y-6">
            <div aria-hidden className="absolute top-6 bottom-6 left-6 w-px bg-gradient-to-b from-cian via-cian/40 to-transparent" />
            {pasos.map(({ icono: Icono, titulo, texto }, i) => (
              <motion.div key={titulo} variants={varianteHijo} className="relative flex gap-5">
                <span className="relative grid size-12 shrink-0 place-items-center rounded-xl bg-noche ring-2 ring-cian/50 shadow-[0_0_20px_-6px_#22E3E0]">
                  <Icono className="size-5 text-brillo" />
                  <span className="absolute -top-2 -right-2 grid size-5 place-items-center rounded-full bg-cian font-mono text-[0.65rem] font-bold text-noche">{i + 1}</span>
                </span>
                <div>
                  <h2 className="font-display text-lg font-semibold">{titulo}</h2>
                  <p className="mt-1 text-sm text-gris">{texto}</p>
                </div>
              </motion.div>
            ))}
          </Escalonado>
        </div>

        <motion.div
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.25, duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
          className="relative self-start rounded-3xl border border-cian/15 bg-noche-2/70 p-6 shadow-[0_30px_80px_-30px_rgba(0,0,0,0.6)] backdrop-blur-xl sm:p-8"
        >
          <div aria-hidden className="absolute inset-x-10 -top-px h-px bg-gradient-to-r from-transparent via-brillo to-transparent" />
          <h2 className="font-display text-2xl font-bold">Quiero que me avisen</h2>
          <p className="mt-1 mb-7 text-sm text-gris">Toma menos de un minuto.</p>
          <Formulario />
        </motion.div>
      </div>
    </section>
  );
}
