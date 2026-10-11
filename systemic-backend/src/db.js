// Conexión a PostgreSQL (Supabase) y contexto de identidad por transacción.
import postgres from 'postgres';
import { ErrorHttp } from './errores.js';

export function crearDb(config) {
  return postgres(config.databaseUrl, {
    ssl: config.dbSsl,
    prepare: false,        // compatible con el pooler de Supabase
    max: 10,
    idle_timeout: 20,
    connect_timeout: 15,
    onnotice: () => {},
  });
}

/**
 * Ejecuta `trabajo(tx)` dentro de una transacción con la identidad correcta.
 * REGLA DE ORO: toda consulta a la base pasa por aquí. Nunca uses `sql` directamente en las rutas.
 *  - auth.sub (usuario de Supabase Auth verificado) => cliente o personal registrado
 *  - tokenInvitado (concesión verificada para un visitante) => visitante con acceso a un proceso
 *  - nada => visitante anónimo (solo información pública)
 */
export function crearConIdentidad(sql) {
  return async function conIdentidad({ auth = null, tokenInvitado = null } = {}, trabajo) {
    return sql.begin(async (tx) => {
      if (auth?.sub) {
        const [fila] = await tx`select identidad.iniciar_contexto_supabase(${auth.sub}::uuid) as usuario_id`;
        if (fila.usuario_id === null) {
          throw new ErrorHttp(403, 'Tu cuenta no está habilitada. ¿Ya confirmaste tu correo?');
        }
        tx.usuarioId = Number(fila.usuario_id);
      } else {
        await tx`select set_config('app.usuario_id', '', true), set_config('app.invitado_token', ${tokenInvitado ?? ''}, true)`;
        tx.usuarioId = null;
      }
      return trabajo(tx);
    });
  };
}
