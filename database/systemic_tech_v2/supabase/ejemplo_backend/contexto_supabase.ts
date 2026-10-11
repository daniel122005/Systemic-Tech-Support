// Ejemplo mínimo (Node.js/TypeScript) del contrato entre el backend y la base en Supabase.
// NO es la plataforma: muestra cómo fijar la identidad en cada transacción.
// Dependencias: npm i postgres @supabase/supabase-js
// Variables de entorno SOLO en el servidor (nunca en el frontend ni en el repositorio):
//   DATABASE_URL_BACKEND = postgresql://st_backend.<REF>:<CONTRASEÑA>@<HOST_POOLER>:6543/postgres?sslmode=require
//   SUPABASE_URL, SUPABASE_ANON_KEY  (la clave anon es pública; service_role NO se usa aquí)
import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";

const sql = postgres(process.env.DATABASE_URL_BACKEND!, {
  prepare: false, // el pooler en modo transacción (6543) no conserva sentencias preparadas
  max: 10,
});
const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_ANON_KEY!);

type Tx = postgres.TransactionSql;

/**
 * Ejecuta `trabajo` dentro de una transacción con la identidad correcta:
 *  - accessToken (JWT de Supabase Auth) => cliente/personal registrado
 *  - tokenInvitado (secreto opaco emitido por el worker tras verificar el contacto) => visitante con concesión
 *  - ninguno => visitante anónimo (solo información pública)
 * Nunca acepta un usuario_id enviado por el navegador.
 */
export async function conIdentidad<T>(
  opciones: { accessToken?: string | null; tokenInvitado?: string | null; correlacion?: string },
  trabajo: (tx: Tx) => Promise<T>,
): Promise<T> {
  let sub: string | null = null;
  if (opciones.accessToken) {
    const { data, error } = await supabase.auth.getUser(opciones.accessToken); // verifica el JWT con Supabase Auth
    if (error || !data.user) throw Object.assign(new Error("No autenticado"), { status: 401 });
    sub = data.user.id;
  }
  return sql.begin(async (tx) => {
    if (sub) {
      const [fila] = await tx`select identidad.iniciar_contexto_supabase(${sub}::uuid, ${opciones.correlacion ?? null}::uuid) as usuario_id`;
      if (fila.usuario_id === null) {
        // Cuenta pendiente de confirmar, bloqueada o inexistente: la base ya quedó sin identidad.
        throw Object.assign(new Error("Cuenta no habilitada"), { status: 403 });
      }
    } else {
      await tx`select set_config('app.usuario_id', '', true),
                      set_config('app.invitado_token', ${opciones.tokenInvitado ?? ""}, true)`;
    }
    return trabajo(tx);
  });
}

// Ejemplos de uso -------------------------------------------------------------

// RF-07/RF-08: catálogo público (sin cuenta).
export const buscarProductos = (texto: string) =>
  conIdentidad({}, (tx) => tx`
    select id, sku, nombre, descripcion, categoria, precio_vigente, moneda, stock_disponible
    from inventario.v_productos_disponibles
    where nombre ilike ${"%" + texto + "%"} order by nombre limit 50`);

// RF-11: pedidos del cliente autenticado (RLS filtra por titularidad).
export const misPedidos = (accessToken: string) =>
  conIdentidad({ accessToken }, (tx) => tx`select * from comercial.v_resumen_pedidos order by created_at desc`);

// RF-21: responder una cotización (procedimiento; parámetros siempre enlazados, nunca concatenados).
export const responderCotizacion = (accessToken: string, version: number, aceptar: boolean, evidencia: string) =>
  conIdentidad({ accessToken }, (tx) => tx`call comercial.responder_cotizacion(${version}, ${aceptar}, ${evidencia})`);

// RF-09: carrito de visitante. El backend genera el secreto (256 bits) y lo guarda en una cookie httpOnly.
export const crearCarritoVisitante = (secreto: string) =>
  conIdentidad({}, async (tx) => {
    const [r] = await tx`call comercial.crear_carrito(null, ${secreto}, null)`;
    return r.p_id as number;
  });
