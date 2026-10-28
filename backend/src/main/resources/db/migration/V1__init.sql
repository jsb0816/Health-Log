-- =====================================================================
-- V1: 초기 스키마 (PLAN.md 4장 ERD)
-- MariaDB 11.8 / InnoDB / utf8mb4
-- 규칙: ENUM 은 VARCHAR + 애플리케이션 enum, 시각은 DATETIME(3), JSON 컬럼 사용
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4.1 사용자 · 목표
-- ---------------------------------------------------------------------
CREATE TABLE users (
    id            BIGINT        NOT NULL AUTO_INCREMENT,
    email         VARCHAR(255)  NOT NULL,
    password_hash VARCHAR(255)  NULL,
    created_at    DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uk_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE user_profiles (
    user_id          BIGINT        NOT NULL,
    sex              VARCHAR(10)   NOT NULL,                 -- MALE | FEMALE
    birth_date       DATE          NOT NULL,
    height_cm        DECIMAL(5,1)  NOT NULL,
    activity_level   VARCHAR(20)   NOT NULL,                 -- SEDENTARY | LIGHT | MODERATE | ACTIVE | VERY_ACTIVE
    intensity_factor DECIMAL(3,2)  NOT NULL DEFAULT 1.00,    -- 운동 칼로리 보정 계수 0.8~1.3
    unit_pref        VARCHAR(10)   NOT NULL DEFAULT 'METRIC',
    updated_at       DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (user_id),
    CONSTRAINT fk_user_profiles_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE goal_periods (
    id               BIGINT        NOT NULL AUTO_INCREMENT,
    user_id          BIGINT        NOT NULL,
    mode             VARCHAR(20)   NOT NULL,                 -- MAINTAIN | LEAN_BULK | DIET | CUT
    start_date       DATE          NOT NULL,
    end_date         DATE          NULL,
    start_weight_kg  DECIMAL(5,2)  NOT NULL,
    target_weight_kg DECIMAL(5,2)  NULL,
    target_weeks     INT           NULL,
    calorie_target   INT           NOT NULL,
    protein_g        INT           NOT NULL,
    carb_g           INT           NOT NULL,
    fat_g            INT           NOT NULL,
    notes            TEXT          NULL,
    created_at       DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_goal_periods_user_start (user_id, start_date),
    CONSTRAINT fk_goal_periods_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 4.2 인바디
-- ---------------------------------------------------------------------
CREATE TABLE inbody_records (
    id                   BIGINT        NOT NULL AUTO_INCREMENT,
    user_id              BIGINT        NOT NULL,
    measured_at          DATETIME(3)   NOT NULL,
    weight_kg            DECIMAL(5,2)  NOT NULL,
    skeletal_muscle_kg   DECIMAL(5,2)  NULL,
    body_fat_kg          DECIMAL(5,2)  NULL,
    body_fat_pct         DECIMAL(4,1)  NULL,
    bmi                  DECIMAL(4,1)  NULL,
    visceral_fat_level   INT           NULL,
    total_body_water_l   DECIMAL(5,2)  NULL,
    protein_kg           DECIMAL(5,2)  NULL,
    mineral_kg           DECIMAL(5,2)  NULL,
    bmr_kcal             INT           NULL,
    segmental            JSON          NULL,                 -- 부위별 근육/지방
    source               VARCHAR(10)   NOT NULL DEFAULT 'MANUAL',  -- MANUAL | OCR | DEVICE
    image_url            VARCHAR(500)  NULL,
    created_at           DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_inbody_user_measured (user_id, measured_at),
    CONSTRAINT fk_inbody_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 4.3 식단
-- ---------------------------------------------------------------------
CREATE TABLE foods (
    id              BIGINT        NOT NULL AUTO_INCREMENT,
    user_id         BIGINT        NULL,                      -- NULL = 공공 DB 캐시
    name            VARCHAR(200)  NOT NULL,
    brand           VARCHAR(100)  NULL,
    source          VARCHAR(10)   NOT NULL,                  -- KFIND | USER | AI
    external_id     VARCHAR(100)  NULL,
    serving_size_g  DECIMAL(7,1)  NOT NULL DEFAULT 100,
    serving_label   VARCHAR(50)   NULL,                      -- "1개", "1공기" 등
    kcal            DECIMAL(7,1)  NOT NULL,
    protein_g       DECIMAL(6,1)  NOT NULL DEFAULT 0,
    carb_g          DECIMAL(6,1)  NOT NULL DEFAULT 0,
    fat_g           DECIMAL(6,1)  NOT NULL DEFAULT 0,
    fiber_g         DECIMAL(6,1)  NULL,
    sugar_g         DECIMAL(6,1)  NULL,
    sodium_mg       DECIMAL(8,1)  NULL,
    extra           JSON          NULL,
    created_at      DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_foods_user (user_id),
    KEY idx_foods_source_ext (source, external_id),
    FULLTEXT KEY ft_foods_name (name, brand),
    CONSTRAINT fk_foods_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE meal_logs (
    id          BIGINT        NOT NULL AUTO_INCREMENT,
    user_id     BIGINT        NOT NULL,
    eaten_at    DATETIME(3)   NOT NULL,
    meal_type   VARCHAR(20)   NOT NULL,                      -- BREAKFAST | LUNCH | DINNER | SNACK | PRE_WORKOUT | POST_WORKOUT
    note        VARCHAR(500)  NULL,
    created_at  DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_meal_logs_user_eaten (user_id, eaten_at),
    CONSTRAINT fk_meal_logs_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE meal_log_items (
    id           BIGINT        NOT NULL AUTO_INCREMENT,
    meal_log_id  BIGINT        NOT NULL,
    food_id      BIGINT        NOT NULL,
    quantity     DECIMAL(7,2)  NOT NULL DEFAULT 1,
    unit         VARCHAR(10)   NOT NULL DEFAULT 'SERVING',   -- SERVING | G | ML
    kcal         DECIMAL(7,1)  NOT NULL,                     -- 입력 시점 스냅샷
    protein_g    DECIMAL(6,1)  NOT NULL DEFAULT 0,
    carb_g       DECIMAL(6,1)  NOT NULL DEFAULT 0,
    fat_g        DECIMAL(6,1)  NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    KEY idx_meal_log_items_log (meal_log_id),
    CONSTRAINT fk_meal_log_items_log  FOREIGN KEY (meal_log_id) REFERENCES meal_logs(id) ON DELETE CASCADE,
    CONSTRAINT fk_meal_log_items_food FOREIGN KEY (food_id)     REFERENCES foods(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE meal_templates (
    id          BIGINT        NOT NULL AUTO_INCREMENT,
    user_id     BIGINT        NOT NULL,
    name        VARCHAR(100)  NOT NULL,
    icon        VARCHAR(20)   NULL,
    sort_order  INT           NOT NULL DEFAULT 0,
    created_at  DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_meal_templates_user (user_id, sort_order),
    CONSTRAINT fk_meal_templates_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE meal_template_items (
    id           BIGINT        NOT NULL AUTO_INCREMENT,
    template_id  BIGINT        NOT NULL,
    food_id      BIGINT        NOT NULL,
    quantity     DECIMAL(7,2)  NOT NULL DEFAULT 1,
    unit         VARCHAR(10)   NOT NULL DEFAULT 'SERVING',
    PRIMARY KEY (id),
    KEY idx_meal_template_items_tpl (template_id),
    CONSTRAINT fk_meal_template_items_tpl  FOREIGN KEY (template_id) REFERENCES meal_templates(id) ON DELETE CASCADE,
    CONSTRAINT fk_meal_template_items_food FOREIGN KEY (food_id)     REFERENCES foods(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE pantry_items (
    id          BIGINT        NOT NULL AUTO_INCREMENT,
    user_id     BIGINT        NOT NULL,
    name        VARCHAR(100)  NOT NULL,
    quantity    DECIMAL(7,2)  NULL,
    unit        VARCHAR(20)   NULL,
    expires_at  DATE          NULL,
    food_id     BIGINT        NULL,
    created_at  DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_pantry_user (user_id),
    CONSTRAINT fk_pantry_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_pantry_food FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE ai_coaching_logs (
    id          BIGINT        NOT NULL AUTO_INCREMENT,
    user_id     BIGINT        NOT NULL,
    kind        VARCHAR(20)   NOT NULL,                      -- MEAL_PLAN | REPORT | ROUTINE_EXTRACT | INBODY_OCR
    request     JSON          NOT NULL,
    response    JSON          NULL,
    model       VARCHAR(50)   NULL,
    tokens_in   INT           NULL,
    tokens_out  INT           NULL,
    created_at  DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_ai_logs_user_created (user_id, created_at),
    CONSTRAINT fk_ai_logs_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 4.4 운동
-- ---------------------------------------------------------------------
CREATE TABLE exercises (
    id             BIGINT        NOT NULL AUTO_INCREMENT,
    user_id        BIGINT        NULL,                       -- NULL = 기본 제공 운동
    name           VARCHAR(100)  NOT NULL,
    muscle_group   VARCHAR(20)   NOT NULL,                   -- CHEST | BACK | SHOULDERS | ARMS | LEGS | CORE | CARDIO | FULL_BODY
    equipment      VARCHAR(20)   NOT NULL,                   -- BARBELL | DUMBBELL | MACHINE | CABLE | BODYWEIGHT | KETTLEBELL | CARDIO_MACHINE | OTHER
    movement_type  VARCHAR(10)   NOT NULL,                   -- COMPOUND | ISOLATION | CARDIO
    default_met    DECIMAL(3,1)  NOT NULL DEFAULT 3.5,
    is_unilateral  TINYINT(1)    NOT NULL DEFAULT 0,
    created_at     DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_exercises_user (user_id),
    KEY idx_exercises_group (muscle_group),
    CONSTRAINT fk_exercises_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE exercise_aliases (
    id           BIGINT        NOT NULL AUTO_INCREMENT,
    exercise_id  BIGINT        NOT NULL,
    alias        VARCHAR(100)  NOT NULL,
    alias_norm   VARCHAR(100)  NOT NULL,                     -- 소문자 · 공백 제거
    lang         VARCHAR(5)    NOT NULL DEFAULT 'ko',
    PRIMARY KEY (id),
    KEY idx_exercise_aliases_norm (alias_norm),
    CONSTRAINT fk_exercise_aliases_ex FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE youtube_imports (
    id                 BIGINT        NOT NULL AUTO_INCREMENT,
    user_id            BIGINT        NOT NULL,
    url                VARCHAR(500)  NOT NULL,
    video_id           VARCHAR(20)   NULL,
    title              VARCHAR(300)  NULL,
    channel            VARCHAR(200)  NULL,
    duration_sec       INT           NULL,
    transcript_source  VARCHAR(20)   NULL,                   -- MANUAL_SUB | AUTO_SUB | PASTED | WHISPER
    transcript         LONGTEXT      NULL,
    extracted          JSON          NULL,
    status             VARCHAR(10)   NOT NULL DEFAULT 'PENDING',  -- PENDING | DONE | FAILED
    error              TEXT          NULL,
    created_at         DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_youtube_imports_user (user_id, created_at),
    CONSTRAINT fk_youtube_imports_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE routines (
    id                 BIGINT        NOT NULL AUTO_INCREMENT,
    user_id            BIGINT        NOT NULL,
    name               VARCHAR(100)  NOT NULL,
    description        TEXT          NULL,
    source             VARCHAR(10)   NOT NULL DEFAULT 'MANUAL',  -- MANUAL | YOUTUBE | AI
    youtube_import_id  BIGINT        NULL,
    target_mode        VARCHAR(20)   NULL,
    estimated_minutes  INT           NULL,
    created_at         DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_routines_user (user_id),
    CONSTRAINT fk_routines_user   FOREIGN KEY (user_id)           REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_routines_import FOREIGN KEY (youtube_import_id) REFERENCES youtube_imports(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE routine_exercises (
    id             BIGINT        NOT NULL AUTO_INCREMENT,
    routine_id     BIGINT        NOT NULL,
    exercise_id    BIGINT        NOT NULL,
    order_no       INT           NOT NULL,
    display_name   VARCHAR(100)  NOT NULL,                   -- 유튜버 표현 그대로
    rest_seconds   INT           NULL,
    note           VARCHAR(500)  NULL,
    timestamp_sec  INT           NULL,
    PRIMARY KEY (id),
    KEY idx_routine_exercises_routine (routine_id, order_no),
    CONSTRAINT fk_routine_exercises_routine FOREIGN KEY (routine_id)  REFERENCES routines(id) ON DELETE CASCADE,
    CONSTRAINT fk_routine_exercises_ex      FOREIGN KEY (exercise_id) REFERENCES exercises(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE routine_sets (
    id                   BIGINT        NOT NULL AUTO_INCREMENT,
    routine_exercise_id  BIGINT        NOT NULL,
    set_no               INT           NOT NULL,
    set_type             VARCHAR(15)   NOT NULL DEFAULT 'NORMAL',
                         -- WARMUP | NORMAL | TOP | BACKOFF | DROP | PYRAMID_UP | PYRAMID_DOWN | SUPERSET | AMRAP | FAILURE | REST_PAUSE
    target_reps_min      INT           NULL,
    target_reps_max      INT           NULL,
    target_weight_kg     DECIMAL(6,2)  NULL,
    target_rpe           DECIMAL(3,1)  NULL,
    target_pct_1rm       DECIMAL(4,1)  NULL,
    config               JSON          NULL,                 -- 유형별 가변 설정
    PRIMARY KEY (id),
    KEY idx_routine_sets_ex (routine_exercise_id, set_no),
    CONSTRAINT fk_routine_sets_ex FOREIGN KEY (routine_exercise_id) REFERENCES routine_exercises(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE workout_sessions (
    id              BIGINT        NOT NULL AUTO_INCREMENT,
    user_id         BIGINT        NOT NULL,
    routine_id      BIGINT        NULL,
    started_at      DATETIME(3)   NOT NULL,
    ended_at        DATETIME(3)   NULL,
    duration_min    INT           NULL,
    estimated_kcal  INT           NULL,
    avg_met         DECIMAL(3,1)  NULL,
    note            VARCHAR(500)  NULL,
    client_id       UUID          NOT NULL,                  -- 오프라인 생성 키 (동기화 멱등성)
    created_at      DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uk_workout_sessions_client (client_id),
    KEY idx_workout_sessions_user_started (user_id, started_at),
    CONSTRAINT fk_workout_sessions_user    FOREIGN KEY (user_id)    REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_workout_sessions_routine FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE workout_sets (
    id            BIGINT        NOT NULL AUTO_INCREMENT,
    session_id    BIGINT        NOT NULL,
    exercise_id   BIGINT        NOT NULL,
    display_name  VARCHAR(100)  NOT NULL,
    set_no        INT           NOT NULL,
    set_type      VARCHAR(15)   NOT NULL DEFAULT 'NORMAL',
    weight_kg     DECIMAL(6,2)  NULL,
    reps          INT           NULL,
    rpe           DECIMAL(3,1)  NULL,
    is_pr         TINYINT(1)    NOT NULL DEFAULT 0,
    completed_at  DATETIME(3)   NULL,
    drop_stages   JSON          NULL,                        -- 드랍세트 단계별 실측
    PRIMARY KEY (id),
    KEY idx_workout_sets_session (session_id, set_no),
    KEY idx_workout_sets_exercise (exercise_id, completed_at),
    CONSTRAINT fk_workout_sets_session FOREIGN KEY (session_id)  REFERENCES workout_sessions(id) ON DELETE CASCADE,
    CONSTRAINT fk_workout_sets_ex      FOREIGN KEY (exercise_id) REFERENCES exercises(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 4.5 리포트
-- ---------------------------------------------------------------------
CREATE TABLE weekly_reports (
    id               BIGINT        NOT NULL AUTO_INCREMENT,
    user_id          BIGINT        NOT NULL,
    week_start       DATE          NOT NULL,
    week_end         DATE          NOT NULL,
    goal_period_id   BIGINT        NULL,
    metrics          JSON          NOT NULL,
    analysis         TEXT          NULL,                     -- LLM 분석 본문 (마크다운)
    recommendations  JSON          NULL,
    model            VARCHAR(50)   NULL,
    created_at       DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uk_weekly_reports_user_week (user_id, week_start),
    CONSTRAINT fk_weekly_reports_user FOREIGN KEY (user_id)        REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_weekly_reports_goal FOREIGN KEY (goal_period_id) REFERENCES goal_periods(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE report_deliveries (
    id          BIGINT        NOT NULL AUTO_INCREMENT,
    report_id   BIGINT        NOT NULL,
    channel     VARCHAR(10)   NOT NULL,                      -- NOTION | GMAIL
    status      VARCHAR(10)   NOT NULL DEFAULT 'PENDING',    -- PENDING | SENT | FAILED
    sent_at     DATETIME(3)   NULL,
    error       TEXT          NULL,
    PRIMARY KEY (id),
    KEY idx_report_deliveries_report (report_id),
    CONSTRAINT fk_report_deliveries_report FOREIGN KEY (report_id) REFERENCES weekly_reports(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
