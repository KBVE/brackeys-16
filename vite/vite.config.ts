import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { contractPlugin } from './src/plugins/contract';

const crossOriginIsolation = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
};

export default defineConfig({
  base: './',
  plugins: [contractPlugin(), react()],
  server: { port: 5173, host: true, headers: crossOriginIsolation },
  preview: { headers: crossOriginIsolation },
});
