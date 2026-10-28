import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'
import { VitePWA } from 'vite-plugin-pwa'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    vue(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.svg'],
      manifest: {
        name: 'Fit — 나만의 헬스 앱',
        short_name: 'Fit',
        description: '식단 · 인바디 · 운동 기록과 주간 AI 리포트',
        theme_color: '#1e88e5',
        background_color: '#ffffff',
        display: 'standalone',
        start_url: '/',
        lang: 'ko',
        icons: [
          { src: 'favicon.svg', sizes: 'any', type: 'image/svg+xml', purpose: 'any' },
        ],
      },
      workbox: {
        // API 응답은 캐시하지 않음 (오프라인 큐는 Dexie 로 별도 처리)
        navigateFallbackDenylist: [/^\/api\//],
      },
    }),
  ],
  server: {
    port: 5173,
    proxy: {
      '/api': { target: 'http://localhost:8080', changeOrigin: true },
      '/swagger-ui': { target: 'http://localhost:8080', changeOrigin: true },
      '/api-docs': { target: 'http://localhost:8080', changeOrigin: true },
    },
  },
  build: {
    // Spring Boot 단일 jar 배포 시 backend/src/main/resources/static 으로 복사
    outDir: 'dist',
  },
})
