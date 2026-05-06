"""
ELT Pipeline DAG — Modern Data Stack
흐름: RAW 검증 → dbt staging → dbt marts → dbt test → 결과 리포트
"""
from __future__ import annotations
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook

DBT_DIR = "/opt/dbt"
DBT_CMD  = f"cd {DBT_DIR} && dbt"

default_args = {
    "owner": "data-team",
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=3),
    "email_on_failure": False,
}


def check_raw_data(**context):
    hook = PostgresHook(postgres_conn_id="postgres_default")
    checks = {
        "raw.customers":       "SELECT COUNT(*) FROM raw.customers",
        "raw.products":        "SELECT COUNT(*) FROM raw.products",
        "raw.orders":          "SELECT COUNT(*) FROM raw.orders",
        "raw.marketing_spend": "SELECT COUNT(*) FROM raw.marketing_spend",
    }
    print("=" * 55)
    print("📊 RAW 데이터 현황")
    print("=" * 55)
    for table, sql in checks.items():
        count = hook.get_first(sql)[0]
        print(f"  {table:30s}: {count:>6,} 건")
        if count == 0:
            raise ValueError(f"❌ {table} 에 데이터 없음")
    print("✅ 모든 RAW 테이블 확인 완료")


def log_pipeline_result(**context):
    hook = PostgresHook(postgres_conn_id="postgres_default")
    marts = {
        "marts.dim_customers": "SELECT COUNT(*) FROM marts.dim_customers",
        "marts.fct_orders":    "SELECT COUNT(*) FROM marts.fct_orders",
        "marts.monthly_sales": "SELECT COUNT(*) FROM marts.monthly_sales",
        "marts.marketing_roi": "SELECT COUNT(*) FROM marts.marketing_roi",
    }
    print("=" * 55)
    print("🎉 ELT 완료 — MARTS 결과")
    print("=" * 55)
    for table, sql in marts.items():
        try:
            count = hook.get_first(sql)[0]
            print(f"  {table:35s}: {count:>5,} 건")
        except Exception as e:
            print(f"  {table}: 조회 실패 → {e}")

    # 핵심 KPI 출력
    try:
        kpi_sql = """
            SELECT
                SUM(revenue_amount)                            AS total_revenue,
                COUNT(DISTINCT customer_id)                    AS unique_customers,
                ROUND(AVG(revenue_amount)::numeric, 0)         AS avg_order_value
            FROM marts.fct_orders
            WHERE is_revenue = true
        """
        kpi = hook.get_first(kpi_sql)
        print(f"\n  📌 연간 총 매출    : ₩{kpi[0]:>15,.0f}")
        print(f"  📌 고유 구매 고객  : {kpi[1]:>5,} 명")
        print(f"  📌 평균 주문금액   : ₩{kpi[2]:>10,.0f}")
    except Exception as e:
        print(f"  KPI 조회 실패: {e}")
    print("=" * 55)


with DAG(
    dag_id="elt_pipeline",
    description="ELT: RAW → dbt staging → dbt marts → 검증",
    default_args=default_args,
    schedule_interval="0 0 * * *",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["elt", "dbt", "mds"],
) as dag:

    t1 = PythonOperator(
        task_id="check_raw_data",
        python_callable=check_raw_data,
        provide_context=True,
    )

    t2 = BashOperator(
        task_id="dbt_deps",
        bash_command=f"{DBT_CMD} deps --profiles-dir {DBT_DIR} 2>&1 || true",
    )

    t3 = BashOperator(
        task_id="dbt_run_staging",
        bash_command=f"{DBT_CMD} run --profiles-dir {DBT_DIR} --select staging",
    )

    t4 = BashOperator(
        task_id="dbt_run_marts",
        bash_command=f"{DBT_CMD} run --profiles-dir {DBT_DIR} --select marts",
    )

    t5 = BashOperator(
        task_id="dbt_test",
        bash_command=f"{DBT_CMD} test --profiles-dir {DBT_DIR}",
    )

    t6 = PythonOperator(
        task_id="log_pipeline_result",
        python_callable=log_pipeline_result,
        provide_context=True,
    )

    t1 >> t2 >> t3 >> t4 >> t5 >> t6
