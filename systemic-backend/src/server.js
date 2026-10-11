// Punto de entrada: npm run dev (con recarga automática) o npm start.
import { config } from './config.js';
import { crearDb, crearConIdentidad } from './db.js';
import { crearVerificadorSupabase } from './auth.js';
import { crearApp } from './app.js';

const sql = crearDb(config);
const app = crearApp({ conIdentidad: crearConIdentidad(sql), verificarToken: crearVerificadorSupabase(config), config });

const servidor = app.listen(config.puerto, () => {
  console.log(`Systemic backend escuchando en http://localhost:${config.puerto}  (prueba: /api/salud)`);
});

async function apagar() {
  servidor.close();
  await sql.end({ timeout: 5 });
  process.exit(0);
}
process.on('SIGINT', apagar);
process.on('SIGTERM', apagar);
