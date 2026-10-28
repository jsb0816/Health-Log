import { createRouter, createWebHistory } from 'vue-router'

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', name: 'home', component: () => import('./views/HomeView.vue') },
    // P1~P5 에서 추가: /diet, /workout, /inbody, /report, /settings
  ],
})
