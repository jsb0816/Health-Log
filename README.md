# Fit — 나만의 헬스 앱

식단 · 인바디 · 운동 기록을 관리하고, 매주 AI 분석 리포트를 받는 개인용 앱.
기획: [PLAN.md](PLAN.md)

## 구성

| 디렉터리 | 내용 |
|---|---|
| `backend/` | Spring Boot 4.1 (Java 21) · Spring Data JPA · Flyway · Spring AI(Claude) · springdoc |
| `frontend/` | Vue 3 · Vite · TypeScript · Vuetify · Pinia · TanStack Query · ECharts · Dexie · PWA |
| `docker-compose.yml` | MariaDB 11.8 (호스트 포트 **3307**, DB `fit`, 계정 `fit`/`fitpw`, utf8mb4, Asia/Seoul) |

## 사전 준비

| 도구 | 버전 | 비고 |
|---|---|---|
| JDK | 21 (LTS) | `winget install --id EclipseAdoptium.Temurin.21.JDK -e` — Gradle 이 toolchain 을 자동 내려받으므로 빌드만이라면 JDK 17 이상이면 됨 |
| Node | 20+ | 프론트 |
| Docker Desktop | — | MariaDB 컨테이너 |

## 실행

```bash
# 1) DB
docker compose up -d

# 2) 백엔드 (http://localhost:8080)
cd backend
./gradlew bootRun            # Windows: .\gradlew.bat bootRun

# 3) 프론트 (http://localhost:5173, /api 는 8080 으로 프록시)
cd frontend
npm install
npm run dev
```

브라우저에서 http://localhost:5173 을 열면 홈 화면이 서버·DB 상태를 표시한다.

- API 문서: http://localhost:8080/swagger-ui.html
- 헬스체크: http://localhost:8080/api/health
- 프론트 타입 생성(서버 실행 중): `cd frontend && npm run gen:api`

## 환경 변수

`.env.example` 참고. Claude API 키는 P4(AI 기능)부터 필요하다.

```
ANTHROPIC_API_KEY=sk-ant-...
```

## 테스트

```bash
cd backend
./gradlew test               # GoalPlanner 단위 테스트 + (Docker 필요) 컨텍스트 로드 테스트
```

## DB 스키마

Flyway 가 `backend/src/main/resources/db/migration/V*.sql` 을 순서대로 적용한다.
JPA `ddl-auto` 는 `validate` 이므로 스키마 변경은 반드시 새 마이그레이션 파일로 한다.

## 로드맵

PLAN.md 7장. 현재 **P0 세팅** 완료 → 다음은 **P1 프로필 · 목표 모드 · 인바디**.
