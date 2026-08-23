import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Threaded Godot web exports need SharedArrayBuffer, which requires cross-origin
// isolation. These make `crossOriginIsolated === true` in dev and preview; on
// itch.io the equivalent comes from the "SharedArrayBuffer support" checkbox.
const crossOriginIsolation = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
};

export default defineConfig({
  // itch serves the build from a CDN subpath, so emit relative asset URLs.
  base: './',
  plugins: [react()],
  server: { port: 5173, host: true, headers: crossOriginIsolation },
  preview: { headers: crossOriginIsolation },
});
