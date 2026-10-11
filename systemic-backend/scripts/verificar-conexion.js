// npm run verificar  — comprueba la conexión a Supabase con st_backend sin modificar nada.
import { config } from '../src/config.js';
import { crearDb } from '../src/db.js';

const sql = crearDb(config);
try {
  await sql.begin(async (tx) => {
    const [yo] = await tx`select current_user as usuario, current_setting('server_version') as version`;
    console.log(`Conectado como ${yo.usuario} a PostgreSQL ${yo.version}`);
    if (yo.usuario !== 'st_backend') throw new Error('Se esperaba el usuario st_backend');
    const [ctx] = await tx`select identidad.iniciar_contexto_supabase(gen_random_uuid()) as usuario_id`;
    if (ctx.usuario_id !== null) throw new Error('Un usuario inexistente obtuvo identidad');
    const [n] = await tx`select (select count(*) from comercial.pedido)::int as pedidos_visibles,
                                (select count(*) from inventario.v_productos_disponibles)::int as productos`;
    if (n.pedidos_visibles !== 0) throw new Error('Sin identidad no debería verse ningún pedido');
    console.log(`Productos publicados: ${n.productos}. Pedidos visibles sin sesión: 0 (correcto).`);
    try {
      await tx.savepoint((sp) => sp`update comercial.pedido set estado = estado where false`);
      throw new Error('st_backend tiene escritura directa sobre pedidos');
    } catch (e) {
      if (e.code !== '42501') throw e;
    }
  });
  console.log('CONEXION VERIFICADA: el backend puede usar la base de forma segura.');
} catch (e) {
  console.error('FALLO:', e.message);
  if (/password authentication failed/i.test(e.message)) console.error('-> Revisa la contraseña de st_backend en DATABASE_URL.');
  if (/Tenant or user not found/i.test(e.message)) console.error('-> Revisa el usuario: debe ser st_backend.REF_DEL_PROYECTO');
  process.exitCode = 1;
} finally {
  await sql.end({ timeout: 5 });
}
