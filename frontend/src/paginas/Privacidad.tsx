// Política de tratamiento de datos personales (Ley 1581 de 2012).
// El texto legal debe redactarlo/aprobarlo la empresa: NO se inventa aquí.
import { Pendiente } from '../components/Basicos';

export function Privacidad() {
  return (
    <section className="relative pt-32 pb-24">
      <div aria-hidden className="fondo-rejilla absolute inset-x-0 top-0 -z-10 h-96" />
      <div className="contenedor max-w-3xl">
        <p className="etiqueta-tecnica text-cian">{'// '}Legal</p>
        <h1 className="mt-3 font-display text-3xl font-bold sm:text-4xl">Política de tratamiento de datos personales</h1>
        <div className="mt-8 space-y-4 rounded-2xl border border-cian/15 bg-noche-2/60 p-6 text-gris">
          <Pendiente className="block text-sm" />
          <p>
            Aquí irá la política oficial de Systemic Tech &amp; Support: responsable del tratamiento, finalidades, derechos del titular
            (conocer, actualizar, rectificar y suprimir sus datos), canales de atención y vigencia.
          </p>
        </div>
      </div>
    </section>
  );
}
