import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'


export default defineConfig({
  plugins: [
    vue(),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  build: {
    emptyOutDir: true,
    outDir: '../../output/app/',
    rollupOptions: {
      output: {
        // Specify that `.tif` files should be treated as assets
        assetFileNames: '[name][extname]',
      }
    }
  },
})
