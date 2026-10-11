import { Hero } from '../components/hero/Hero';
import { CursosTeaser } from '../secciones/CursosTeaser';
import { Desarrollo } from '../secciones/Desarrollo';
import { LlamadoAccion } from '../secciones/LlamadoAccion';
import { ProcesoReparacion } from '../secciones/ProcesoReparacion';
import { ProductosDestacados } from '../secciones/ProductosDestacados';
import { Servicios } from '../secciones/Servicios';
import { Testimonios } from '../secciones/Testimonios';

export function Inicio() {
  return (
    <>
      <Hero />
      <Servicios />
      <ProductosDestacados />
      <ProcesoReparacion />
      <Desarrollo />
      <CursosTeaser />
      <Testimonios />
      <LlamadoAccion />
    </>
  );
}
