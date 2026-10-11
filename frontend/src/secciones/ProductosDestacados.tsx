// Productos destacados: datos reales del catálogo vía GET /api/productos (backend).
import { motion } from 'framer-motion';
import { ArrowRight, ImageOff, RefreshCw } from 'lucide-react';
import { useEffect, useState } from 'react';
import { Link } from 'react-router';
import { Escalonado, varianteHijo } from '../components/Aparecer';
import { TituloSeccion } from '../components/Basicos';
import { TarjetaTilt } from '../components/TarjetaTilt';
import { api, API_URL, ErrorApi, type Producto } from '../lib/api';
import { formatoPrecio } from '../lib/formato';

// Con pocos productos la grilla no deja columnas vacías.
const columnas: Record<number, string> = { 1: 'max-w-sm', 2: 'max-w-3xl', 3: 'lg:grid-cols-3', 4: 'lg:grid-cols-4' };

type Estado = { tipo: 'cargando' } | { tipo: 'error'; mensaje: string } | { tipo: 'listo'; productos: Producto[] };

function TarjetaProducto({ p }: { p: Producto }) {
  const [sinImagen, setSinImagen] = useState(!p.imagen);
  return (
    <TarjetaTilt>
      <Link to={`/productos?id=${p.id}`} className="flex h-full flex-col">
        <div className="relative aspect-[4/3] overflow-hidden rounded-t-[15px] bg-gradient-to-br from-profundo/40 to-noche">
          {sinImagen ? (
            <div className="grid h-full place-items-center text-gris/50">
              <ImageOff className="size-10" aria-hidden />
            </div>
          ) : (
            <img
              src={p.imagen!}
              alt={p.nombre}
              loading="lazy"
              onError={() => setSinImagen(true)}
              className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105"
            />
          )}
          <span className="etiqueta-tecnica absolute top-3 left-3 rounded-md bg-noche/80 px-2 py-1 text-[0.6rem]! text-cian backdrop-blur">
            {p.categoria}
          </span>
        </div>
        <div className="flex flex-1 flex-col p-5">
          <h3 className="line-clamp-2 font-display font-semibold">{p.nombre}</h3>
          {p.descripcion && <p className="mt-1.5 line-clamp-2 text-sm text-gris">{p.descripcion}</p>}
          <div className="mt-auto flex items-end justify-between gap-2 pt-5">
            <span className="font-display text-xl font-bold text-brillo">{formatoPrecio(p.precio_vigente, p.moneda)}</span>
            <span className="text-xs text-gris">{Number(p.stock_disponible) > 0 ? 'Disponible' : 'Agotado'}</span>
          </div>
        </div>
      </Link>
    </TarjetaTilt>
  );
}

function Esqueleto() {
  return (
    <div className="overflow-hidden rounded-2xl bg-noche-2 ring-1 ring-white/5" aria-hidden>
      <div className="aspect-[4/3] animate-pulse bg-white/5" />
      <div className="space-y-3 p-5">
        <div className="h-4 w-3/4 animate-pulse rounded bg-white/8" />
        <div className="h-3 w-full animate-pulse rounded bg-white/5" />
        <div className="h-5 w-1/3 animate-pulse rounded bg-cian/15" />
      </div>
    </div>
  );
}

export function ProductosDestacados() {
  const [estado, setEstado] = useState<Estado>({ tipo: 'cargando' });
  const [intento, setIntento] = useState(0);

  useEffect(() => {
    const control = new AbortController();
    setEstado({ tipo: 'cargando' });
    api
      .productos({ limite: 4 }, control.signal)
      .then((productos) => setEstado({ tipo: 'listo', productos }))
      .catch((e: unknown) => {
        if ((e as Error).name === 'AbortError') return;
        setEstado({ tipo: 'error', mensaje: e instanceof ErrorApi ? e.message : 'No pudimos cargar los productos.' });
      });
    return () => control.abort();
  }, [intento]);

  return (
    <section className="relative py-24 sm:py-32">
      <div aria-hidden className="absolute inset-0 -z-10 bg-[radial-gradient(ellipse_at_20%_50%,#0E4E7A33,transparent_60%)]" />
      <div className="contenedor">
        <div className="flex flex-wrap items-end justify-between gap-6">
          <TituloSeccion etiqueta="Tienda" titulo="Productos destacados" descripcion="Precios y disponibilidad en tiempo real." />
          <Link to="/productos" className="btn-secundario mb-12">
            Ver catálogo <ArrowRight className="size-4" />
          </Link>
        </div>

        <div aria-live="polite" aria-busy={estado.tipo === 'cargando'}>
          {estado.tipo === 'cargando' && (
            <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
              {Array.from({ length: 4 }, (_, i) => (
                <Esqueleto key={i} />
              ))}
            </div>
          )}

          {estado.tipo === 'error' && (
            <motion.div variants={varianteHijo} initial="oculto" animate="visible" className="rounded-2xl border border-cian/15 bg-noche-2/70 p-8 text-center">
              <p className="text-gris">{estado.mensaje}</p>
              {import.meta.env.DEV && (
                <p className="mt-2 font-mono text-xs text-amber-300/80">
                  (Desarrollo) ¿Está encendido el backend en {API_URL}? → cd systemic-backend · npm run dev
                </p>
              )}
              <button type="button" onClick={() => setIntento((n) => n + 1)} className="btn-secundario mt-5">
                <RefreshCw className="size-4" /> Reintentar
              </button>
            </motion.div>
          )}

          {estado.tipo === 'listo' &&
            (estado.productos.length === 0 ? (
              <p className="rounded-2xl border border-cian/15 bg-noche-2/70 p-8 text-center text-gris">Pronto tendremos productos disponibles.</p>
            ) : (
              <Escalonado className={`grid gap-5 sm:grid-cols-2 ${columnas[Math.min(estado.productos.length, 4)]}`}>
                {estado.productos.map((p) => (
                  <TarjetaProducto key={p.id} p={p} />
                ))}
              </Escalonado>
            ))}
        </div>
      </div>
    </section>
  );
}
