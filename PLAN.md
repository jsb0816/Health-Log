# 나만의 헬스 앱 — 기획서 (v3: Spring Boot + Vue.js + MariaDB)

작성일: 2026-10-28 (v1 Expo/Node → v2 Spring Boot + Vue → v3 DB를 MariaDB로 변경)
상태: 기획 단계 (코드 없음)

---

## 0. 한눈에 보는 결론

| 항목 | 선택 | 한 줄 이유 |
|---|---|---|
| 앱 형태 | **Vue 웹앱(PWA)** 을 폰 홈화면에 설치 → 필요 시 **Capacitor**로 네이티브 앱 패키징 | Vue 하나로 폰·PC 모두 커버, 앱스토어 없이 바로 사용 |
| 프론트엔드 | **Vue 3 + Vite + TypeScript + Pinia + Vuetify 3** | 모바일 친화 컴포넌트, PWA 플러그인 성숙 |
| 백엔드 | **Spring Boot 4.1 (Java 21, Gradle)** + Spring Data JPA + Flyway | 안정적, 스케줄링·보안·LLM(Spring AI 2.0) 모두 공식 모듈. (P0 시점 Initializr 에서 3.5는 더 이상 제공되지 않아 4.1.2 채택) |
| DB | **MariaDB 11.8 LTS** | JSON 컬럼(세트 설정·LLM 결과), 윈도우 함수(추이 분석), Spring/JPA/Flyway 1급 지원 |
| 로컬 저장 | **IndexedDB (Dexie)** 로 운동 세션 오프라인 큐 | 지하 헬스장 신호 불량 대비, 복귀 시 동기화 |
| LLM | **Spring AI + Claude** (claude-sonnet-5-5 기본, 리포트는 claude-opus-5-5) | 구조화 출력으로 루틴 추출·식단 코칭·리포트 |
| 유튜브 자막 | **yt-dlp** 를 `ProcessBuilder`로 실행 + 수동 붙여넣기 폴백 | 클라우드 IP 차단 이슈 있음 → 폴백 필수 |
| 음식 DB | **식약처 K-FIND 공공 Open API** + 사용자 직접 등록 | 32만 건 한국 음식 영양성분, 무료 |
| 칼로리 계산 | **2024 Adult Compendium MET 값** | kcal = MET × 3.5 × 체중(kg) / 200 × 분 |
| 개발 환경 | Docker Compose(MariaDB) + Gradle 래퍼 + Vite dev server | JDK 21 설치만 추가로 필요 |
| 배포(후순위) | Vue 빌드를 Spring Boot jar에 포함 → 집 PC/미니PC 또는 저가 VPS에 단일 jar 실행 | 유튜브 자막 수집이 거주지 IP에서 가장 안정적 |

> **환경 확인 결과**: 로컬에 Java 1.8 만 설치돼 있습니다. Spring Boot 3.x는 Java 17 이상이 필요하므로 **JDK 21(LTS)** 설치가 선행돼야 합니다. Maven/Gradle은 프로젝트에 포함되는 Gradle 래퍼(`gradlew`)를 쓰므로 별도 설치가 필요 없습니다. Node 26, Docker는 이미 설치돼 있습니다.

---

## 1. 요구사항 정리

### 1.1 사용자가 요청한 기능

| # | 기능 | 세부 |
|---|---|---|
| F1 | 식단 관리 | 음식 직접 등록, 재료 기반 AI 식단 코칭, +/− 로 유동 추가·제외, 자주 먹는 식단 원터치 등록 |
| F2 | 인바디 관리 | 기록 + 추이 그래프 |
| F3 | 운동 관리 | 루틴 직접 설정, 세트·횟수, 세트 유형(TOP/드랍/피라미드 등), 유튜브 링크 → 자막 → 자동 루틴, 소모 칼로리 추정 |
| F4 | DB 관리 | 인바디·운동 기록을 관계형 DB로 |
| F5 | 주간 리포트 | 한 주 운동량·식단 추이 분석 → 다음 주 조절 가이드. 추후 Notion/Gmail 전송 |
| F6 | 목표 모드 | 린매스업 / 다이어트(목표 감량 kg) / 컷팅 / (유지). 성별·나이·키·몸무게 기반으로 식단·운동량 가이드 |

### 1.2 비기능 요구사항 (추가)

- **오프라인 대응**: 운동 세션 입력은 네트워크 없이 가능, 복귀 시 동기화 (PWA 서비스워커 + IndexedDB)
- **입력 속도**: 세트 1개 기록에 탭 3회 이내 (이전 세션 값 자동 채움)
- **단일 사용자부터 시작하되 다중 사용자 구조**: 모든 테이블에 `user_id`
- **LLM 결과는 항상 사용자 검토 후 저장**: 자동 루틴·AI 식단은 "제안" 상태 → 확인 후 확정
- **건강 면책**: 리포트와 코칭은 의학적 조언이 아님을 UI에 명시

---

## 2. 기술 스택 선정 근거

### 2.1 프론트엔드: Vue 3 웹앱(PWA) → Capacitor

Vue는 웹 프레임워크이므로 "앱"의 형태는 다음 세 단계로 확장합니다.

| 단계 | 형태 | 할 수 있는 것 | 못 하는 것 |
|---|---|---|---|
| 1 (시작) | **PWA** — 폰 브라우저에서 홈화면에 추가 | 전체 기능, 오프라인 캐시, 전체화면 실행, PC에서도 동일 화면 | iOS 백그라운드 푸시 제약, 건강앱(HealthKit) 접근 불가 |
| 2 | **Capacitor** 로 같은 Vue 코드를 iOS/Android 앱으로 패키징 | 푸시 알림, 네이티브 SQLite, 카메라, HealthKit/Health Connect 플러그인 | 앱스토어 등록 절차(개인 사용은 사이드로드/TestFlight) |
| 3 | 앱스토어 배포 | — | — |

**라이브러리 선택**

| 역할 | 선택 | 비고 |
|---|---|---|
| 빌드 | Vite + TypeScript | 공식 권장 |
| 상태 | Pinia | Vue 공식 상태 라이브러리 |
| 라우팅 | Vue Router | — |
| UI | **Vuetify 3** | 모바일 친화 머티리얼 컴포넌트, 폼·스테퍼·바텀시트 풍부. 대안: Quasar(PWA·Capacitor 통합 내장, 더 opinionated) |
| 차트 | Apache ECharts (vue-echarts) | 인바디 추이·볼륨 히트맵 |
| 서버 통신 | Axios + TanStack Query(Vue) | 캐시·재시도 |
| 타입 공유 | springdoc-openapi → `openapi-typescript` | 서버 DTO에서 TS 타입 자동 생성 |
| 오프라인 | vite-plugin-pwa + Dexie(IndexedDB) | 운동 세션 로컬 큐 |
| 폼 검증 | VeeValidate + Zod | — |

### 2.2 백엔드: Spring Boot

| 역할 | 선택 | 비고 |
|---|---|---|
| 런타임 | **Java 21 (LTS)** | 가상 스레드로 LLM·외부 API 호출 대기 비용 감소 |
| 프레임워크 | **Spring Boot 3.5+** (4.x 가능) | Spring Web MVC |
| 빌드 | Gradle (Kotlin DSL) 래퍼 | 설치 불필요 |
| 영속성 | **Spring Data JPA + Hibernate 6** | JSON 컬럼은 `@JdbcTypeCode(SqlTypes.JSON)` 으로 매핑 (MariaDB Dialect 내장 지원) |
| 마이그레이션 | **Flyway** | `V1__init.sql` 부터 버전 관리 |
| 집계 쿼리 | 네이티브 SQL (`@Query(nativeQuery=true)`) 또는 jOOQ | 주간 리포트 집계는 윈도우 함수 필요 → 네이티브 |
| 검증 | Jakarta Validation | DTO 레벨 |
| 보안 | Spring Security + JWT | 처음엔 단일 사용자, 구조는 다중 사용자 |
| 스케줄 | `@Scheduled` (주간 리포트), `@Async` | DB 스케줄러 불필요 |
| LLM | **Spring AI (Anthropic 모듈)** | `BeanOutputConverter` 로 JSON 구조화 출력, 프롬프트 템플릿, 토큰 사용량 메타데이터 |
| 외부 프로세스 | `ProcessBuilder` → yt-dlp.exe | 타임아웃·stdout 파싱 |
| HTTP 클라이언트 | `RestClient` | K-FIND·Notion·Gmail |
| API 문서 | springdoc-openapi | Swagger UI + 프론트 타입 생성 |
| 테스트 | JUnit 5 + Testcontainers(MariaDB) | 집계 SQL 검증 |

**Node/Expo 안과 비교해 달라지는 점**

| 항목 | v1 (Expo+Node) | v2 (Spring+Vue) |
|---|---|---|
| 언어 | TS 단일 | Java(서버) + TS(프론트), OpenAPI로 타입 연결 |
| 모바일 네이티브 | 기본 | Capacitor 추가 시 |
| 오프라인 | SQLite 네이티브 | IndexedDB (충분하나 약함) |
| 계산 로직 공유 | 한 패키지 공유 | BMR/TDEE/MET 는 **서버가 단일 진실** , 프론트는 표시용 간이 계산만 |
| 스케줄링 | DB 스케줄러 / 워커 | `@Scheduled` 내장 |
| 배포 | API + 앱 빌드 분리 | **단일 jar** (Vue 빌드를 `static/` 에 포함) |

### 2.3 DB: MariaDB 11.8 LTS

**선정: MariaDB 11.8 LTS** (사용자 선호 + Spring 생태계 1급 지원). 이 앱의 요구사항을 MariaDB로 어떻게 충족하는지와 주의점을 정리합니다.

| 요구 | MariaDB에서의 구현 | 비고 |
|---|---|---|
| 세트 유형별 가변 설정 저장 | `JSON` 컬럼 (`LONGTEXT` + `CHECK(JSON_VALID(...))`), `JSON_EXTRACT`/`JSON_VALUE` 로 조회 | 인덱스가 필요하면 가상 컬럼(`AS (JSON_VALUE(config,'$.stages[0].pct')) VIRTUAL`)에 인덱스. 이 앱에선 JSON 내부 검색이 거의 없어 문제 없음 |
| 인바디 추이·전회 대비 Δ | 윈도우 함수 `LAG()`, `AVG() OVER (ROWS 6 PRECEDING)` | 10.2+ 지원, 11.x에서 안정 |
| 주간 집계 (요일별 빈 날 포함) | `SEQUENCE` 스토리지 엔진의 `seq_0_to_6` 테이블로 날짜 생성 후 LEFT JOIN | Postgres `generate_series` 대체. MariaDB 고유 기능 |
| 주 시작일 계산 | `DATE_SUB(d, INTERVAL WEEKDAY(d) DAY)` (월요일 기준) | — |
| 운동 별칭·음식 이름 검색 | `LOWER(alias) LIKE '%q%'` + 별칭 테이블 소규모 유지. 음식은 `FULLTEXT` 인덱스(`utf8mb4`) 또는 LIKE | 한국어는 띄어쓰기 단위라 FULLTEXT로 대부분 커버. 오타 유사 검색은 LLM 추출 단계에서 별칭 후보를 함께 받아 보완 |
| ENUM | 네이티브 `ENUM` 지원 | JPA는 `@Enumerated(EnumType.STRING)` + `VARCHAR` 로 두는 편이 마이그레이션에 안전 |
| UUID (오프라인 멱등 키) | 네이티브 `UUID` 타입 (10.7+) | — |
| 문자셋 | `utf8mb4_unicode_ci` 전역 설정 | 한글·이모지 아이콘(템플릿 아이콘) 대응 |
| 시간대 | `DATETIME` + 서버 `Asia/Seoul`, JPA는 `LocalDateTime` | `TIMESTAMP` 는 2038 한계·UTC 변환 혼란 → 사용 안 함 |
| 드라이버 | `org.mariadb.jdbc:mariadb-java-client` | Hibernate `MariaDBDialect` 자동 선택 |
| 로컬 실행 | Docker `mariadb:11.8` | — |

**Postgres 대비 포기하는 것**: JSONB 인덱싱, `pg_trgm` 유사 검색, 범위 타입. 이 앱에서는 JSON을 "저장 후 통째로 읽는" 용도로만 쓰고, 유사 검색은 별칭 테이블과 LLM으로 보완하므로 실질적 손실은 작습니다.

### 2.4 유튜브 자막 수집 — 가장 리스크가 큰 부분

2025~2026년 YouTube가 클라우드(AWS·GCP 등) IP의 자막 요청을 적극 차단합니다. yt-dlp, youtube-transcript-api 모두 로컬 PC에서는 잘 되지만 클라우드 서버에서는 실패하거나 429 오류가 납니다.

**설계:**

1. **1순위: yt-dlp 서브프로세스** (`--write-subs --write-auto-subs --sub-langs ko,en --skip-download`). 수동 자막 → 자동 자막 순.
2. **2순위: 사용자 수동 붙여넣기.** 유튜브 "스크립트 표시" 화면에서 복사해 붙여넣는 입력창.
3. **3순위(선택): 오디오 → Whisper STT.**
4. 서버가 클라우드면 자막 수집만 집 PC에서 돌리거나 유료 Transcript API 사용.

**루틴 추출 파이프라인 (Spring 구현 관점)**

```
POST /api/youtube-imports {url}
  → YoutubeImportService: yt-dlp 실행(@Async, 타임아웃 60s) → VTT 파싱(타임스탬프 유지)
  → RoutineExtractionService: Spring AI ChatClient
       .system(프로필·모드·운동 별칭 목록)
       .user(자막)
       .entity(ExtractedRoutine.class)   // JSON 구조화 출력
     - 운동명은 유튜버가 말한 표현 그대로 (display_name)
     - 세트 수·횟수·세트 유형·휴식·타임스탬프·confidence
     - canonical_exercise 후보 (별칭 테이블 LIKE 매칭 + LLM이 제안한 별칭)
  → status=done, extracted JSON 저장
GET /api/youtube-imports/{id}  → 프론트 "제안 루틴" 화면 → 수정·확정
POST /api/routines (source=youtube)
```

### 2.5 음식 영양성분 데이터

- **식약처 K-FIND (2026년 7월 출범)**: 약 32.7만 건, 130여 영양 항목, 공공데이터포털 Open API.
- **사용자 직접 등록**: 공공 DB에 없는 음식·직접 만든 요리·보충제.
- **전략**: 검색 결과만 `foods` 테이블에 캐시(출처 표기). `RestClient` 로 호출, 응답은 Caffeine 캐시 24h.

### 2.6 운동 소모 칼로리 계산

2024 Adult Compendium of Physical Activities 기준.

```
kcal = MET × 3.5 × 체중(kg) / 200 × 운동 시간(분)
```

| 운동 유형 | 기본 MET | 비고 |
|---|---|---|
| 웨이트(일반, 8~15회 다종목) | 3.5 | 기본값 |
| 웨이트(고강도·바디빌딩) | 6.0 | TOP/드랍/실패 세트 포함 시 |
| 스쿼트·데드리프트 | 5.0 | 복합 하체 |
| 맨몸 고강도 | 6.5 | |
| 서킷·케틀벨 | 7.5 | |
| 유산소 | 속도별 테이블 | 러닝 8~12, 사이클 6~10, 걷기 3.5 |

- 사용자 **강도 보정 계수**(0.8~1.3) 제공. 휴식 시간은 1/2 가중.
- 인바디가 있으면 제지방량 기반 BMR(Katch-McArdle)로 정확도 향상.
- 계산은 서버 `CalorieCalculator` 한 곳에서 수행하고, 세션 종료 시 `estimated_kcal` 로 저장.

### 2.7 목표 모드 알고리즘 (F6)

**입력**: 성별, 나이, 키, 체중, 활동량, (있으면) 인바디 체지방률·골격근량, 목표 모드, 목표 체중·기간.

**BMR**
- 인바디 없음: Mifflin-St Jeor — 남 = 10×kg + 6.25×cm − 5×나이 + 5 / 여 = 10×kg + 6.25×cm − 5×나이 − 161
- 인바디 있음: Katch-McArdle = 370 + 21.6 × 제지방량(kg)

**TDEE** = BMR × 활동계수(1.2 / 1.375 / 1.55 / 1.725 / 1.9) + 앱이 기록한 운동 소모 kcal (활동계수는 "비운동" 기준으로 낮춰 중복 방지)

| 모드 | 칼로리 목표 | 단백질 | 탄수/지방 | 운동 가이드 | 주간 체중 변화 목표 |
|---|---|---|---|---|---|
| 유지 | TDEE | 1.6 g/kg | 잔여 | 현재 유지 | ±0 |
| 린매스업 | TDEE +10~15% | 1.8~2.0 g/kg | 탄수 우선 | 점진적 과부하, 주 4~5회 | +0.25~0.5%/주 |
| 다이어트 | 목표 kg·기간 역산 (1kg 지방 ≈ 7,700 kcal), 최대 −20% | 2.0 g/kg | 지방 ≥0.8 g/kg | 근력 유지 + 유산소 | −0.5~1%/주 |
| 컷팅 | TDEE −20~25% | 2.2~2.4 g/kg | 탄수 운동 전후 집중 | 볼륨·강도 유지, 유산소↑ | −0.7~1%/주 |

**성별·안전 규칙**
- 칼로리 하한: 여성 1,200 / 남성 1,500 kcal 미만이면 경고 + 기간 연장 제안
- 여성 체지방률 하한 경고 기준 별도(필수 지방 10~13% vs 남성 2~5%)
- 주 1% 초과 감량 목표는 "너무 빠름" 경고
- 모드 전환 이력은 `goal_periods` 로 관리 → 리포트가 "컷팅 4주차" 문맥 인지

구현: `GoalPlanner` 도메인 서비스 (순수 Java, 외부 의존 없음) + 단위 테스트로 표의 수치 고정.

---

## 3. 시스템 아키텍처

```
┌──────────────────────────────────────┐
│  Vue 3 PWA (Vite / TS / Vuetify)      │  폰 브라우저·홈화면 / PC
│  - Pinia, Vue Router, TanStack Query  │
│  - Dexie(IndexedDB): 오프라인 세션 큐 │
│  - vue-echarts: 추이 차트             │
│  (후순위) Capacitor → iOS/Android     │
└──────────────────┬───────────────────┘
                   │ HTTPS / JSON (OpenAPI → TS 타입)
┌──────────────────▼───────────────────┐
│  Spring Boot 3.5+ (Java 21)            │
│  controller → service → repository     │
│  - Spring Security(JWT)                │
│  - Spring Data JPA + Flyway            │
│  - @Scheduled: 주간 리포트             │
│  - @Async(가상스레드): yt-dlp, LLM     │
│  - Spring AI ChatClient (Claude)       │
│  - RestClient: K-FIND, Notion, Gmail   │
│  - static/: Vue 빌드 포함 (단일 jar)   │
└───┬───────────────┬──────────────────┘
    │               │
┌───▼────────┐ ┌────▼─────────────────┐
│ MariaDB    │ │ 외부                  │
│ 11.8 LTS   │ │ - yt-dlp.exe (로컬)   │
│ (utf8mb4)  │ │ - Claude API          │
│            │ │ - K-FIND Open API     │
│            │ │ - Notion / Gmail API  │
└────────────┘ └──────────────────────┘
```

**저장소 구조**

```
jsb/
├── backend/                      # Spring Boot (Gradle)
│   ├── build.gradle.kts
│   └── src/main/java/.../
│       ├── user/      (profile, goal)
│       ├── inbody/
│       ├── diet/      (food, meal, template, pantry, coaching)
│       ├── workout/   (exercise, routine, session, calorie)
│       ├── youtube/   (import, extraction)
│       ├── report/    (aggregation, llm, delivery)
│       ├── ai/        (Spring AI 설정, 프롬프트 템플릿)
│       └── common/
│   └── src/main/resources/db/migration/V1__init.sql
├── frontend/                     # Vue 3 + Vite
│   └── src/
│       ├── api/       (openapi-typescript 생성 타입 + axios)
│       ├── stores/    (pinia)
│       ├── views/     (home, diet, workout, inbody, report, settings)
│       ├── components/
│       └── offline/   (dexie, sync)
├── docker-compose.yml            # mariadb:11.8
├── PLAN.md
└── README.md
```

패키지는 **도메인별(기능별)** 로 나눕니다(`workout/`, `diet/` …). 레이어별(`controller/`, `service/`)로 나누면 기능이 늘수록 찾기 어려워집니다.

---

## 4. 데이터베이스 설계 (ERD 요약)

Flyway `V1__init.sql` 기준. JPA 엔티티는 이 스키마를 따라가며, `ddl-auto` 는 `validate` 로만 둡니다.
표기 규칙: 아래 `JSON` 은 MariaDB `JSON` 컬럼, `ENUM(...)` 은 실제 DDL에서 `VARCHAR(20)` + 애플리케이션 enum 으로 구현, 모든 테이블 `ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`, 시각 컬럼은 `DATETIME(3)`.

### 4.1 사용자·목표

```sql
users              (id, email, password_hash, created_at)
user_profiles      (user_id PK, sex ENUM('male','female'), birth_date, height_cm,
                    activity_level ENUM, intensity_factor NUMERIC DEFAULT 1.0,
                    unit_pref, updated_at)
goal_periods       (id, user_id, mode ENUM('maintain','lean_bulk','diet','cut'),
                    start_date, end_date NULL, start_weight_kg, target_weight_kg NULL,
                    target_weeks NULL, calorie_target, protein_g, carb_g, fat_g,
                    notes, created_at)   -- 모드 전환 이력
```

### 4.2 인바디

```sql
inbody_records     (id, user_id, measured_at, weight_kg, skeletal_muscle_kg,
                    body_fat_kg, body_fat_pct, bmi, visceral_fat_level,
                    total_body_water_l, protein_kg, mineral_kg, bmr_kcal,
                    segmental JSON,       -- 부위별 근육/지방
                    source ENUM('manual','ocr','device'),
                    image_url NULL, created_at)
```

### 4.3 식단

```sql
foods              (id, user_id NULL,     -- NULL이면 공공 DB 캐시
                    name, brand NULL, source ENUM('kfind','user','ai'),
                    external_id NULL, serving_size_g, serving_label,
                    kcal, protein_g, carb_g, fat_g, fiber_g, sugar_g, sodium_mg,
                    extra JSON, created_at)
                    -- FULLTEXT INDEX ft_foods_name (name, brand)
meal_logs          (id, user_id, eaten_at, meal_type ENUM('breakfast','lunch','dinner','snack','pre_workout','post_workout'),
                    note, created_at)
meal_log_items     (id, meal_log_id, food_id, quantity NUMERIC, unit ENUM('serving','g','ml'),
                    kcal, protein_g, carb_g, fat_g)   -- 입력 시점 스냅샷
meal_templates     (id, user_id, name, icon, sort_order)         -- 자주 먹는 식단
meal_template_items(id, template_id, food_id, quantity, unit)
pantry_items       (id, user_id, name, quantity, unit, expires_at NULL, food_id NULL)
ai_coaching_logs   (id, user_id, kind ENUM('meal_plan','report','routine_extract','inbody_ocr'),
                    request JSON, response JSON, model, tokens_in, tokens_out, created_at)
```

### 4.4 운동

```sql
exercises          (id, user_id NULL, name, muscle_group ENUM, equipment ENUM,
                    movement_type ENUM('compound','isolation','cardio'),
                    default_met NUMERIC, is_unilateral BOOL, created_at)
exercise_aliases   (id, exercise_id, alias, alias_norm, lang)   -- alias_norm: 소문자·공백 제거, INDEX

routines           (id, user_id, name, description, source ENUM('manual','youtube','ai'),
                    youtube_import_id NULL, target_mode NULL, estimated_minutes, created_at)
routine_exercises  (id, routine_id, exercise_id, order_no, display_name,  -- 유튜버 용어 그대로
                    rest_seconds, note, timestamp_sec NULL)
routine_sets       (id, routine_exercise_id, set_no,
                    set_type ENUM('warmup','normal','top','backoff','drop','pyramid_up',
                                  'pyramid_down','superset','amrap','failure','rest_pause'),
                    target_reps_min, target_reps_max, target_weight_kg NULL,
                    target_rpe NULL, target_pct_1rm NULL,
                    config JSON)         -- 유형별 가변 설정

workout_sessions   (id, user_id, routine_id NULL, started_at, ended_at,
                    duration_min, estimated_kcal, avg_met, note,
                    client_id UUID UNIQUE,   -- MariaDB 네이티브 UUID, 오프라인 생성 → 동기화 멱등성
                    created_at)
workout_sets       (id, session_id, exercise_id, display_name, set_no, set_type,
                    weight_kg, reps, rpe NULL, is_pr BOOL, completed_at,
                    drop_stages JSON NULL)

youtube_imports    (id, user_id, url, video_id, title, channel, duration_sec,
                    transcript_source ENUM('manual_sub','auto_sub','pasted','whisper'),
                    transcript LONGTEXT, extracted JSON, status ENUM('pending','done','failed'),
                    error, created_at)
```

### 4.5 리포트

```sql
weekly_reports     (id, user_id, week_start DATE, week_end DATE, goal_period_id,
                    metrics JSON, analysis TEXT, recommendations JSON,
                    model, created_at)
report_deliveries  (id, report_id, channel ENUM('notion','gmail'), status, sent_at, error)
```

**`set_type` 별 `config` JSON 예시**

```json
// drop:       {"stages": [{"pct": 100}, {"pct": 80}, {"pct": 60}], "reps_each": "failure"}
// pyramid_up: {"steps": 4, "weight_increment_kg": 5, "reps_decrement": 2}
// top:        {"backoff_sets": 2, "backoff_pct": 85}
// superset:   {"group": "A", "partner_exercise_id": 123}
// rest_pause: {"pause_sec": 15, "mini_sets": 3}
```

JPA 매핑: `@JdbcTypeCode(SqlTypes.JSON) @Column(columnDefinition="json") SetConfig config` (Hibernate 6 내장, 별도 라이브러리 불필요). 세트 유형별 설정 객체는 `sealed interface SetConfig` 로 타입 안전하게 역직렬화.

**추이·집계 쿼리 예시 (MariaDB)**

```sql
-- 인바디 전회 대비 변화
SELECT measured_at, weight_kg,
       weight_kg - LAG(weight_kg) OVER (ORDER BY measured_at) AS weight_delta,
       skeletal_muscle_kg - LAG(skeletal_muscle_kg) OVER (ORDER BY measured_at) AS muscle_delta
FROM inbody_records WHERE user_id = ? ORDER BY measured_at;

-- 주간 일별 섭취 kcal (기록 없는 날도 0으로)
SELECT DATE_ADD(?, INTERVAL s.seq DAY) AS d,
       COALESCE(SUM(i.kcal), 0) AS kcal
FROM seq_0_to_6 s
LEFT JOIN meal_logs m ON DATE(m.eaten_at) = DATE_ADD(?, INTERVAL s.seq DAY) AND m.user_id = ?
LEFT JOIN meal_log_items i ON i.meal_log_id = m.id
GROUP BY d ORDER BY d;
```

---

## 5. 기능별 상세 명세 & API

### 5.1 온보딩 & 프로필 (F6)
- `PUT /api/me/profile`, `POST /api/me/goal-periods`, `GET /api/me/targets` (오늘 목표 kcal·매크로)
- 성별·생년월일·키·체중·활동량 → 모드 선택 → 목표 즉시 표시. 안전 규칙 위반 시 경고.
- 홈 상단 카드: "현재 모드 · N주차 · 오늘 목표 / 섭취 / 잔여"

### 5.2 식단 (F1)
- `GET /api/foods?q=` (로컬 → 사용자 → K-FIND 순), `POST /api/foods` (직접 등록)
- `GET/POST /api/meal-logs?date=`, `PATCH /api/meal-log-items/{id}` (수량 ±), `DELETE`
- `POST /api/meal-templates` (현재 끼니를 템플릿으로), `POST /api/meal-templates/{id}/apply?date=&mealType=` (원터치 등록)
- `GET/POST /api/pantry-items`, `POST /api/coaching/meal-plan` → 2~3개 식단 옵션(JSON) → "식단에 추가" 시 `foods(source='ai')` 생성
- 화면: 끼니별 카드, 각 음식 행 `−` 수량 `+` 스테퍼, 하단 고정 kcal·P·C·F 진행 바

### 5.3 인바디 (F2)
- `GET/POST /api/inbody`, `POST /api/inbody/ocr` (결과지 사진 → Claude 비전 → 폼 자동 채움, 추가 제안)
- `GET /api/inbody/trend?range=3m` → 체중·골격근·체지방률 시계열 + 전회 대비 Δ (윈도우 함수 `LAG`)
- 차트에 목표 모드 기간을 배경 밴드로 겹쳐 표시

### 5.4 운동 (F3)
- `GET /api/exercises?q=` (별칭 `alias_norm LIKE` 검색), `POST /api/routines`, `PUT /api/routines/{id}`
- `POST /api/workout-sessions` (client_id 멱등), `POST /api/workout-sessions/{id}/sets`, `POST /.../finish` → kcal·볼륨·PR 계산
- `POST /api/youtube-imports`, `GET /api/youtube-imports/{id}` (status 폴링), `POST /api/youtube-imports/{id}/transcript` (수동 붙여넣기 폴백)
- 세션 화면: 이전 세션 값 자동 채움, 휴식 타이머, 오프라인 시 Dexie 큐 → 온라인 복귀 시 일괄 전송
- 유튜브 제안 루틴 화면: 운동명은 유튜버 표현, 타임스탬프 탭 → 해당 구간 재생, 추정 항목 노란색

### 5.5 주간 리포트 (F5)
- `@Scheduled(cron="0 0 21 * * SUN")` → `WeeklyReportService.generate(userId, week)`. 앱에 "지금 생성" 버튼(`POST /api/reports/generate`)
- 집계(네이티브 SQL): 운동 횟수·시간·총 볼륨·부위별 볼륨·소모 kcal·PR 수 / 일평균 섭취·매크로 달성률·기록 누락일 / 체중 7일 이동평균 / 인바디 Δ / 전주 대비
- 분석(Spring AI): 집계 JSON + 모드 + 기간 경과 + 지난주 권고 이행 여부 → `WeeklyReportResult` 구조화 출력
  - 요약 3줄 / 잘한 점 / 아쉬운 점 / **더 할 것** / **덜 할 것** / 수치 조정 제안(수락 시 `goal_periods` 갱신)
- 전송(후순위): `NotionDelivery`, `GmailDelivery` 구현체 → `report_deliveries` 기록

---

## 6. LLM 설계 원칙 (Spring AI)

| 용도 | 모델 | 출력 | 비용 통제 |
|---|---|---|---|
| 유튜브 루틴 추출 | claude-sonnet-5-5 | `ExtractedRoutine` 구조화 | 자막 30분 ≈ 1~2만 토큰 |
| AI 식단 코칭 | claude-sonnet-5-5 | `MealPlanOptions` | 하루 N회 제한 |
| 주간 리포트 | claude-opus-5-5 | `WeeklyReportResult` + 마크다운 | 주 1회 |
| 인바디 OCR | claude-sonnet-5-5 (비전) | `InbodyOcrResult` | 회당 1장 |

- 모든 호출은 `ai_coaching_logs` 에 요청·응답·토큰 기록 (Spring AI `ChatResponse.getMetadata().getUsage()`)
- 시스템 프롬프트에 프로필·모드·최근 7일 요약, 프롬프트 캐싱 활용
- 결과는 항상 "제안" → 사용자 확정. 수치를 바꾸는 제안은 확인 다이얼로그
- 면책 문구 고정 노출

---

## 7. 개발 로드맵

| 단계 | 기간(예상) | 산출물 | 완료 기준 |
|---|---|---|---|
| **P0 세팅** | 1주 | JDK 21 설치, Spring Initializr 프로젝트, Docker MariaDB, Flyway V1, Vite+Vue 프로젝트, `/api/health` | Vue 화면에서 서버 헬스체크 표시 |
| **P1 프로필·모드·인바디** | 2주 | 온보딩, `GoalPlanner`, 인바디 입력·추이 차트 | 모드별 목표 표시, 그래프 동작 |
| **P2 식단 핵심** | 2~3주 | K-FIND 검색·직접 등록, 끼니 로그 ±, 템플릿, 진행 바 | 하루 식단 1분 내 기록 |
| **P3 운동 핵심** | 3주 | 운동 DB·별칭, 루틴 빌더(세트 유형), 세션 실행, 칼로리, 오프라인 큐 | 헬스장에서 실제 세션 기록 |
| **P4 AI 기능** | 2~3주 | yt-dlp 루틴 추출(+폴백), 재료 기반 식단 코칭 | 유튜브 3개로 루틴 생성 |
| **P5 주간 리포트** | 2주 | 집계 SQL, Spring AI 리포트, 리포트 화면 | 2주 연속 생성 |
| **P6 연동·배포** | 2주 | Notion/Gmail, PWA 설치, 단일 jar 자가호스팅 | 폰 홈화면 앱 + 매주 메일 |
| **P7 고도화** | 지속 | Capacitor 네이티브화, 아래 제안 중 선택 | — |

총 약 3~4개월(주말·저녁 기준). P1~P3 까지만 해도 AI 없이 쓸 수 있는 앱이 됩니다.

---

## 8. 추가 제안

### 강력 추천
1. **인바디 결과지 사진 → 자동 입력** (Claude 비전 OCR)
2. **이전 세션 자동 채움 + 점진적 과부하 제안** ("+2.5 kg 제안")
3. **추정 1RM(Epley) 및 PR 추적** — 컷팅 중 근력 유지 판단 근거
4. **체중 7일 이동평균** — 일일 체중 변동 노이즈 제거
5. **오프라인 큐** — 헬스장에서 입력 안 되면 앱을 안 쓰게 됨
6. **휴식 타이머 + 알림** (PWA 단계에선 화면 켜진 상태 알림, Capacitor 후 백그라운드 푸시)

### 추천
7. 부위별 주간 볼륨 히트맵
8. 음식 사진 → 영양 추정
9. 바코드 스캔 (식약처 바코드 연계)
10. 걸음수·수면 연동 (Capacitor + Health Connect/HealthKit 플러그인 단계에서)
11. 보충제 체크리스트
12. 지난주 권고 이행 추적

### 나중에
13. 데이터 내보내기(CSV/JSON)
14. 홈 화면 위젯 (Capacitor 이후)
15. 다중 사용자/공유
16. 워치 심박 연동

---

## 9. 주요 리스크와 대응

| 리스크 | 영향 | 대응 |
|---|---|---|
| 유튜브 자막 수집 차단 | 자동 루틴 불가 | 수동 붙여넣기 폴백, 자가호스팅 우선, 필요 시 유료 API |
| K-FIND API 제한·장애 | 검색 지연 | 결과 캐시, 사용자 등록 음식 우선 |
| LLM 비용 | 월 비용 | 토큰 로그·일일 제한, 프롬프트 캐싱, 리포트만 상위 모델 |
| 칼로리 추정 오차 | 목표 왜곡 | "추정치" 명시, 보정 계수, 2~3주 체중 추이로 TDEE 역산 |
| PWA 알림·백그라운드 제약(iOS) | 휴식 타이머 UX | 화면 켜짐 유지(Wake Lock) → Capacitor 전환 시 해결 |
| 건강 데이터 보안 | 유출 | HTTPS, JWT, DB 암호화 볼륨, 외부 전송은 명시 설정 시만 |
| 과도한 감량 목표 | 건강 | 하한 칼로리·주 1% 상한 경고 강제 |

---

## 10. 바로 시작할 때 (P0)

```
1. JDK 21 설치 (Eclipse Temurin 21 LTS) → JAVA_HOME 설정
2. start.spring.io → Web, Data JPA, Validation, Security, Flyway, MariaDB Driver,
   Spring AI Anthropic, springdoc 선택 → backend/ 에 압축 해제
3. docker compose up -d        # mariadb:11.8 (MARIADB_DATABASE=fit, utf8mb4, Asia/Seoul)
4. npm create vite@latest frontend -- --template vue-ts
   npm i vuetify pinia vue-router axios @tanstack/vue-query vue-echarts echarts dexie
   npm i -D vite-plugin-pwa openapi-typescript
5. backend: V1__init.sql (4장 ERD) → ./gradlew bootRun
6. frontend: npm run dev → /api/health 호출 확인
```

첫 작업 파일: `docker-compose.yml`, `backend/src/main/resources/db/migration/V1__init.sql`, `backend/.../user/GoalPlanner.java`(+테스트), `frontend/src/api/client.ts`.

---

## 참고 자료

- 유튜브 자막 클라우드 IP 차단 논의: https://github.com/jdepoix/youtube-transcript-api/issues/593
- yt-dlp 자동자막 429 이슈: https://github.com/yt-dlp/yt-dlp/issues/13831
- 식약처 K-FIND 식품영양성분 DB: https://www.mfds.go.kr/brd/m_580/view.do?seq=69
- 공공데이터포털 식품영양성분 API: https://www.data.go.kr/biz/dcat/metadata/15127578.do
- 2024 Adult Compendium of Physical Activities: https://pubmed.ncbi.nlm.nih.gov/38242596/ , https://pacompendium.com/conditioning-exercise
- MariaDB JSON 타입: https://mariadb.com/kb/en/json-data-type/ , 윈도우 함수: https://mariadb.com/kb/en/window-functions/ , SEQUENCE 엔진: https://mariadb.com/kb/en/sequence-storage-engine/
- Spring AI 공식 문서: https://docs.spring.io/spring-ai/reference/
- Spring Boot 시스템 요구사항(Java 17+): https://docs.spring.io/spring-boot/system-requirements.html
- Vuetify 3: https://vuetifyjs.com/ , vite-plugin-pwa: https://vite-pwa-org.netlify.app/
- Capacitor: https://capacitorjs.com/
- Supabase 무료 플랜 제한(2026): https://automationatlas.io/answers/supabase-free-tier-limits-2026/
