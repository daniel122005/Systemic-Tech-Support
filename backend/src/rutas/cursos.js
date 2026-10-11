// Cursos — FASE 1 (sin cambios en la base).
// Los clientes registran su interés en un curso, con o sin cuenta. Se guarda como una solicitud de
// cotización (comercial.solicitar_cotizacion, RF-19) cuya necesidad empieza por "[CURSO] ".
// Ese prefijo es el que debe usar el panel administrativo para filtrar las solicitudes de cursos.
// FASE 2 (cuando se oferten): esquema `formacion` con curso y solicitud_curso mediante una migración nueva.
import { Router } from 'express';
import { texto, correo as validarCorreo, telefono as validarTelefono } from '../validar.js';
import { ErrorHttp } from '../errores.js';
import { limitePorIp } from '../limite.js';

export const PREFIJO_CURSO = '[CURSO]';
const MODALIDADES = { presencial: 'Presencial', virtual: 'Virtual', cualquiera: 'Cualquiera' };

export function rutasCursos({ conIdentidad }) {
  const r = Router();
  const consumirCupo = limitePorIp({
    ventanaMs: 15 * 60 * 1000,
    maximo: 5,
    mensaje: 'Recibimos varias solicitudes desde tu conexión. Espera unos minutos e inténtalo de nuevo.',
  });

  // POST /api/cursos/interes
  // { tema, modalidad?, mensaje?, nombres?, apellidos?, correo?, telefono?, sitio_web? }
  // Con sesión, los datos de contacto que no se envíen se toman del perfil.
  r.post('/cursos/interes', async (req, res) => {
    const b = req.body || {};

    // Campo trampa: invisible para personas; si llega lleno es un bot. Se responde igual, sin guardar.
    if (typeof b.sitio_web === 'string' && b.sitio_web.trim() !== '') {
      return res.status(201).json({ mensaje: 'Recibimos tu solicitud.' });
    }

    const tema = texto(b.tema, 'el curso o tema de interés', { max: 120 });
    const modalidad = b.modalidad == null || b.modalidad === '' ? null : MODALIDADES[b.modalidad];
    if (modalidad === undefined) throw new ErrorHttp(400, 'Modalidad no válida');
    const mensaje = texto(b.mensaje, 'mensaje', { opcional: true, max: 1000 });
    const nombres = texto(b.nombres, 'nombres', { opcional: true, max: 100 });
    const apellidos = texto(b.apellidos, 'apellidos', { opcional: true, max: 100 });
    const correo = validarCorreo(b.correo);
    const telefono = validarTelefono(b.telefono);
    if (!req.auth) {
      if (!nombres) throw new ErrorHttp(400, 'Escribe tu nombre');
      if (!correo && !telefono) throw new ErrorHttp(400, 'Déjanos un correo o un teléfono para avisarte');
    }

    const necesidad = [
      `${PREFIJO_CURSO} ${tema}`,
      modalidad && `Modalidad preferida: ${modalidad}`,
      mensaje && `Mensaje: ${mensaje}`,
    ]
      .filter(Boolean)
      .join('\n');

    consumirCupo(req);
    await conIdentidad({ auth: req.auth }, async (tx) => {
      let persona = null;
      if (req.auth) {
        const [fila] = await tx`select persona_id from identidad.usuario where id = ${tx.usuarioId}`;
        persona = fila?.persona_id ?? null;
      }
      await tx`call comercial.solicitar_cotizacion(${persona}, ${nombres}, ${apellidos}, ${correo}, ${telefono}, ${necesidad}, null)`;
    });

    res.status(201).json({ mensaje: 'Recibimos tu solicitud. Te avisaremos cuando abramos ese curso.' });
  });

  return r;
}
