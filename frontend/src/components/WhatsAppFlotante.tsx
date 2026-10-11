import { motion } from 'framer-motion';
import { Link } from 'react-router';
import { whatsappUrl } from '../datos/contenido';
import { IconoWhatsApp } from './Basicos';

export function WhatsAppFlotante() {
  const clases = 'relative grid size-14 place-items-center rounded-full bg-whatsapp text-white shadow-[0_8px_30px_-6px_rgba(37,211,102,0.65)] transition-transform hover:scale-105';
  const interior = (
    <>
      <span aria-hidden className="onda absolute inset-0 rounded-full bg-whatsapp" />
      <IconoWhatsApp className="relative size-7" />
    </>
  );
  return (
    <motion.div
      className="fixed right-4 bottom-4 z-40 sm:right-6 sm:bottom-6"
      initial={{ opacity: 0, scale: 0.6 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ delay: 1.6, type: 'spring', stiffness: 260, damping: 18 }}
    >
      {whatsappUrl ? (
        <a href={whatsappUrl} target="_blank" rel="noopener noreferrer" aria-label="Escríbenos por WhatsApp" className={clases}>
          {interior}
        </a>
      ) : (
        <Link to="/contacto" aria-label="Contáctanos" className={clases}>
          {interior}
        </Link>
      )}
    </motion.div>
  );
}
