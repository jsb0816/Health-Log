<script setup lang="ts">
import { useQuery } from '@tanstack/vue-query'
import { fetchHealth } from '../api/client'

const { data, isPending, isError, error, refetch } = useQuery({
  queryKey: ['health'],
  queryFn: fetchHealth,
  retry: 1,
})
</script>

<template>
  <v-container class="py-6" max-width="600">
    <h1 class="text-h5 mb-4">Fit — P0 세팅 확인</h1>

    <v-card>
      <v-card-title>서버 상태</v-card-title>
      <v-card-text>
        <div v-if="isPending" class="d-flex align-center ga-2">
          <v-progress-circular indeterminate size="20" />
          <span>서버에 연결 중…</span>
        </div>

        <v-alert v-else-if="isError" type="error" variant="tonal">
          서버에 연결할 수 없습니다. 백엔드(localhost:8080)가 실행 중인지 확인하세요.
          <div class="text-caption mt-1">{{ (error as Error)?.message }}</div>
        </v-alert>

        <v-list v-else density="compact">
          <v-list-item>
            <template #prepend><v-icon color="success">mdi-check-circle</v-icon></template>
            <v-list-item-title>API: {{ data?.status }}</v-list-item-title>
          </v-list-item>
          <v-list-item>
            <template #prepend>
              <v-icon :color="data?.db === 'ok' ? 'success' : 'error'">mdi-database</v-icon>
            </template>
            <v-list-item-title>MariaDB: {{ data?.db }}</v-list-item-title>
          </v-list-item>
          <v-list-item>
            <template #prepend><v-icon>mdi-clock-outline</v-icon></template>
            <v-list-item-title>서버 시각: {{ data?.serverTime }}</v-list-item-title>
          </v-list-item>
        </v-list>
      </v-card-text>
      <v-card-actions>
        <v-btn variant="text" @click="refetch()">다시 확인</v-btn>
      </v-card-actions>
    </v-card>

    <p class="text-caption text-medium-emphasis mt-6">
      다음 단계(P1): 온보딩 · 목표 모드 · 인바디 입력과 추이 차트
    </p>
  </v-container>
</template>
