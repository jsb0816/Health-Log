<script setup lang="ts">
import { useRoute } from 'vue-router'

const route = useRoute()

// P1 이후 하단 네비게이션 항목이 늘어난다 (식단 · 운동 · 인바디 · 리포트 · 설정)
const tabs = [
  { to: '/', icon: 'mdi-home', label: '홈' },
]
</script>

<template>
  <v-app>
    <v-app-bar color="primary" density="comfortable">
      <v-app-bar-title>Fit</v-app-bar-title>
    </v-app-bar>

    <v-main>
      <router-view />
    </v-main>

    <v-bottom-navigation grow>
      <v-btn v-for="t in tabs" :key="t.to" :to="t.to" :active="route.path === t.to">
        <v-icon>{{ t.icon }}</v-icon>
        <span>{{ t.label }}</span>
      </v-btn>
    </v-bottom-navigation>
  </v-app>
</template>
