import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

const serverPort = 5174; // express server

export default defineConfig({
  plugins: [sveltekit()],
  server: {
    port: 5173,
    proxy: {
      '/api': `http://localhost:${serverPort}`
    }
  }
});

