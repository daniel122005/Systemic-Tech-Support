import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: { port: 5173, strictPort: true }, // el backend solo acepta este origen (FRONTEND_ORIGIN)
  build: {
    rollupOptions: {
      output: {
        // Librerías en archivos aparte: cambian poco y el navegador las guarda en caché entre versiones del sitio.
        manualChunks(id) {
          if (!id.includes('node_modules')) return undefined;
          if (id.includes('@supabase')) return 'supabase';
          if (id.includes('framer-motion') || id.includes('motion-dom') || id.includes('motion-utils')) return 'animaciones';
          if (id.includes('react')) return 'react';
          return undefined;
        },
      },
    },
  },
});
