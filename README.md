C:\Projects\data-stack\
├─ docker-compose.yml          ← 교체
├─ Dockerfile.airflow          ← 교체 (dbt 버전 수정)
├─ portal\
│  └─ index.html               ← 신규 (서비스 포털)
├─ pgadmin\
│  └─ servers.json             ← 신규 (자동 DB 연결)
├─ scripts\
│  └─ init-db.sql              ← 교체 (데이터 보강)
├─ dags\
│  └─ elt_pipeline.py          ← 교체
├─ dbt_project\
│  ├─ dbt_project.yml          ← 교체
│  ├─ profiles.yml
│  ├─ macros\
│  │  └─ generate_schema_name.sql
│  └─ models\
│     ├─ sources.yml
│     ├─ staging\
│     │  ├─ stg_customers.sql
│     │  ├─ stg_products.sql
│     │  ├─ stg_orders.sql
│     │  └─ stg_marketing_spend.sql  ← 신규
│     └─ marts\
│        ├─ dim_customers.sql  (RFM 포함)
│        ├─ fct_orders.sql
│        ├─ monthly_sales.sql
│        └─ marketing_roi.sql  ← 신규 (ROAS/CAC)
└─ superset_config\
   └─ superset_config.py

   cd C:\Projects\data-stack
mkdir portal, pgadmin, logs, plugins -ErrorAction SilentlyContinue

# 클린 재빌드
docker compose down -v
docker rmi airflow-with-dbt:2.9.1 -f 2>$null

docker compose up --build -d
docker compose logs -f airflow-init
# "=== 초기화 완료 ===" 메시지 확인 후 Ctrl+C

🌐 접속 주소 요약
서비스URL계정서비스 포털http://localhost—Airflowhttp://localhost:8080admin / adminpgAdminhttp://localhost:5050admin@example.com / adminSupersethttp://localhost:8088admin / admin

x-airflow-common: &airflow-common
  build:
    context: .
    dockerfile: Dockerfile.airflow
  image: airflow-with-dbt:2.9.1
  environment: &airflow-common-env
    AIRFLOW__CORE__EXECUTOR: LocalExecutor
    AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres:5432/airflow
    AIRFLOW__CORE__FERNET_KEY: "46BKJoQYlPPOexq0OhDZnIlNepKFf87WFwLt0nfd4uM="
    AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: "true"
    AIRFLOW__CORE__LOAD_EXAMPLES: "false"
    AIRFLOW__API__AUTH_BACKENDS: "airflow.api.auth.backend.basic_auth,airflow.api.auth.backend.session"
    AIRFLOW__WEBSERVER__EXPOSE_CONFIG: "true"
    AIRFLOW__WEBSERVER__SECRET_KEY: "webserverSECRETkey_mds_2024"
    AIRFLOW_UID: "50000"
    AIRFLOW_GID: "0"
    AIRFLOW_CONN_POSTGRES_DEFAULT: "postgresql+psycopg2://airflow:airflow@postgres:5432/airflow"
  volumes:
    - ./dags:/opt/airflow/dags
    - ./logs:/opt/airflow/logs
    - ./plugins:/opt/airflow/plugins
    - ./dbt_project:/opt/dbt
  depends_on: &airflow-common-depends-on
    postgres:
      condition: service_healthy

services:

  postgres:
    image: postgres:15
    container_name: mds_postgres
    environment:
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: airflow
      POSTGRES_DB: airflow
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U airflow -d airflow"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 20s
    restart: unless-stopped

  pgadmin:
    image: dpage/pgadmin4:8.5
    container_name: mds_pgadmin
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@example.com
      PGADMIN_DEFAULT_PASSWORD: admin
      PGADMIN_CONFIG_SERVER_MODE: "False"
      PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED: "False"
    volumes:
      - pgadmin_data:/var/lib/pgadmin
      - ./pgadmin/servers.json:/pgadmin4/servers.json:ro
    ports:
      - "5050:80"
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped

  airflow-init:
    <<: *airflow-common
    container_name: mds_airflow_init
    entrypoint: /bin/bash
    command:
      - -c
      - |
        echo "=== Airflow DB 초기화 ==="
        airflow db migrate
        echo "=== Admin 계정 생성 ==="
        airflow users create --username admin --firstname Admin --lastname User --role Admin --email admin@example.com --password admin || echo "이미 존재"
        echo "=== postgres_default Connection 등록 ==="
        airflow connections delete postgres_default 2>/dev/null || true
        airflow connections add postgres_default --conn-type postgres --conn-host postgres --conn-login airflow --conn-password airflow --conn-port 5432 --conn-schema airflow
        echo "=== dbt 버전 ==="
        dbt --version
        echo "=== 초기화 완료 ==="
    environment:
      <<: *airflow-common-env
      _AIRFLOW_DB_MIGRATE: "true"
      _AIRFLOW_WWW_USER_CREATE: "true"
    restart: "no"

  airflow-webserver:
    <<: *airflow-common
    container_name: mds_airflow_web
    command: webserver
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD-SHELL", "curl --fail http://localhost:8080/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    restart: unless-stopped
    depends_on:
      <<: *airflow-common-depends-on
      airflow-init:
        condition: service_completed_successfully

  airflow-scheduler:
    <<: *airflow-common
    container_name: mds_airflow_scheduler
    command: scheduler
    healthcheck:
      test: ["CMD-SHELL", "airflow jobs check --job-type SchedulerJob --hostname \"$${HOSTNAME}\" || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    restart: unless-stopped
    depends_on:
      <<: *airflow-common-depends-on
      airflow-init:
        condition: service_completed_successfully

  # ──────────────────────────────────────────────────────
  # Apache Superset :8088
  #
  # 핵심 수정:
  #   YAML > 블록 + bash -c 안에서 \ 줄 연속은 동작 안 함
  #   → superset fab create-admin 을 한 줄로 작성
  #   → | (literal block) 으로 변경하여 줄바꿈 그대로 유지
  # ──────────────────────────────────────────────────────
  superset:
    image: apache/superset:3.1.0
    container_name: mds_superset
    environment:
      SUPERSET_SECRET_KEY: "supersetSECRETkey_mds_2024_xK9mN"
      SUPERSET_DATABASE_URI: "postgresql+psycopg2://airflow:airflow@postgres:5432/superset"
      PYTHONPATH: /app/pythonpath
      SUPERSET_CONFIG_PATH: /app/pythonpath/superset_config.py
      SUPERSET_LOAD_EXAMPLES: "false"
    volumes:
      - superset_home:/app/superset_home
      - ./superset_config/superset_config.py:/app/pythonpath/superset_config.py:ro
    ports:
      - "8088:8088"
    # ★ | 블록 사용 → 줄바꿈 보존, 각 명령이 별도 줄로 실행됨
    # ★ fab create-admin 인수를 모두 한 줄에 작성
    command:
      - bash
      - -c
      - |
        set -e
        echo "=== [1/4] Superset DB 마이그레이션 ==="
        superset db upgrade

        echo "=== [2/4] Admin 계정 생성 ==="
        superset fab create-admin --username admin --firstname Admin --lastname User --email admin@example.com --password admin 2>/dev/null || true

        echo "=== [3/4] Superset 초기화 ==="
        superset init

        echo "=== [4/4] 웹서버 시작 (0.0.0.0:8088) ==="
        superset run -p 8088 --host 0.0.0.0 --with-threads
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:8088/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 120s
    depends_on:
      postgres:
        condition: service_healthy
    restart: on-failure

  portal:
    image: nginx:alpine
    container_name: mds_portal
    volumes:
      - ./portal/index.html:/usr/share/nginx/html/index.html:ro
      - ./portal/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    ports:
      - "80:80"
    restart: unless-stopped

volumes:
  postgres_data:
  pgadmin_data:
  superset_home:





  ----------------------
🧪 확인 순서
1단계 — pgAdmin에서 데이터 확인
localhost:5050 접속 → 왼쪽 트리에서 Servers → MDS-PostgreSQL → airflow → Schemas 확인. raw, staging, marts 3개 스키마가 보여야 합니다. (staging/marts는 Airflow DAG 실행 후 생성됨)
2단계 — Airflow에서 DAG 실행
localhost:8080 → elt_pipeline DAG 토글 ON → ▶️ Trigger → 6개 태스크 모두 초록색 확인
3단계 — pgAdmin에서 marts 검증
sql-- 월별 매출 확인
SELECT year_month, SUM(total_revenue) AS 매출
FROM marts.monthly_sales
GROUP BY year_month ORDER BY year_month;
4단계 — Superset 데이터소스 연결
localhost:8088 → Settings → Database Connections → postgresql+psycopg2://airflow:airflow@postgres:5432/airflow 입력 → Dataset에 marts.fct_orders, marts.monthly_sales, marts.marketing_roi 추가 → 차트 생성

📊 새로 추가된 데이터 포인트
기존 대비 추가된 내용입니다. 고객 30명, 상품 25개, 주문 120건으로 확장했고, 마케팅 지출 데이터(채널별 월별 광고비 36건)가 추가됐습니다. dbt 모델도 4개 staging(마케팅 스테이징 신규) + 4개 mart(마케팅 ROI 신규)로 확장되어, marketing_roi 테이블에서 채널별 ROAS와 고객획득비용(CAC)을 바로 조회할 수 있습니다. dim_customers에는 RFM 점수(R/F/M 각 1~5점)가 포함됩니다.
  
