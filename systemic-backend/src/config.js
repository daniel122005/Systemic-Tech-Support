// Lee y valida la configuración desde .env. Si falta algo, el servidor no arranca.
import 'dotenv/config';

function requerida(nombre) {
  const valor = process.env[nombre];
  if (!valor || valor.includes('PON_AQUI')) {
    throw new Error(`Falta configurar ${nombre} en el archivo .env (mira .env.example)`);
  }
  return valor;
}

const databaseUrl = requerida('DATABASE_URL');
const usuarioDb = decodeURIComponent(new URL(databaseUrl).username).split('.')[0];
if (usuarioDb !== 'st_backend') {
  // Seguridad: el backend nunca debe usar postgres (dueño de todo, salta RLS).
  throw new Error(`DATABASE_URL usa el usuario "${usuarioDb}". El backend debe conectarse como st_backend.`);
}
if (process.env.SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error('No configures SUPABASE_SERVICE_ROLE_KEY en este backend: no se necesita y salta la seguridad.');
}

// La clave anon/publishable es un JWT (eyJ...) o empieza por sb_publishable_. Si no, se pegó otra cosa
// (por ejemplo una contraseña) y la verificación de sesiones fallaría con "Invalid API key".
const supabaseAnonKey = requerida('SUPABASE_ANON_KEY').trim();
if (supabaseAnonKey.startsWith('sb_secret_')) {
  throw new Error('SUPABASE_ANON_KEY tiene la clave SECRETA. Usa la clave anon / publishable.');
}
if (!/^sb_publishable_\S+$/.test(supabaseAnonKey) && !/^eyJ[\w-]+\.[\w-]+\.[\w-]+$/.test(supabaseAnonKey)) {
  throw new Error('SUPABASE_ANON_KEY no parece una clave de Supabase. Cópiala de Supabase → Project Settings → API Keys (anon / publishable).');
}

export const config = {
  puerto: Number(process.env.PORT || 3000),
  databaseUrl,
  dbSsl: process.env.DB_SSL === 'false' ? false : 'require',
  supabaseUrl: requerida('SUPABASE_URL').replace(/\/$/, ''),
  supabaseAnonKey,
  origenFrontend: (process.env.FRONTEND_ORIGIN || 'http://localhost:5173').split(',').map((s) => s.trim()),
  produccion: process.env.NODE_ENV === 'production',
};
