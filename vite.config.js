import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 80, // Explicitly setting the port
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./vitest.setup.js'],
  },
  base: '/react-ciccd-actions/'
})
