import axios from 'axios'

/**
 * 서버 API 클라이언트.
 * 개발: Vite 프록시가 /api → http://localhost:8080 으로 전달
 * 배포: Spring Boot 가 같은 origin 에서 서빙
 *
 * 타입은 `npm run gen:api` 로 springdoc(/api-docs)에서 생성한 src/api/schema.d.ts 를 사용한다.
 */
export const api = axios.create({
  baseURL: '/api',
  timeout: 15_000,
  headers: { 'Content-Type': 'application/json' },
})

export interface HealthResponse {
  status: string
  db: string
  serverTime: string
}

export async function fetchHealth(): Promise<HealthResponse> {
  const { data } = await api.get<HealthResponse>('/health')
  return data
}
