// Construye la aplicación Express. Separado de server.js para poder probarla.
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import { autenticacion } from './auth.js';
import { manejadorErrores } from './errores.js';
import { rutasSalud } from './rutas/salud.js';
import { rutasCatalogo } from './rutas/catalogo.js';
import { rutasCarrito } from './rutas/carrito.js';
import { rutasCuenta } from './rutas/cuenta.js';
import { rutasCursos } from './rutas/cursos.js';

export function crearApp({ conIdentidad, verificarToken, config }) {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', 1);
  app.use(helmet());
  app.use(cors({ origin: config.origenFrontend, credentials: true }));
  app.use(express.json({ limit: '100kb' }));
  app.use(cookieParser());

  const deps = { conIdentidad, config };
  const sesionOpcional = autenticacion(verificarToken, { obligatoria: false });
  const sesionObligatoria = autenticacion(verificarToken, { obligatoria: true });

  app.use('/api', rutasSalud(deps));
  app.use('/api', sesionOpcional, rutasCatalogo(deps));
  app.use('/api', sesionOpcional, rutasCarrito(deps));
  app.use('/api', sesionOpcional, rutasCursos(deps));
  app.use('/api/cuenta', sesionObligatoria, rutasCuenta(deps));

  app.use((req, res) => res.status(404).json({ error: `Ruta no encontrada: ${req.method} ${req.path}` }));
  app.use(manejadorErrores);
  return app;
}
