C:\Projects\data-stack\docker-compose.yml

C:\Projects\data-stack\Dockerfile.airflow

C:\Projects\data-stack\scripts\init-db.sql

docker compose exec airflow-scheduler bash -c "dbt --version"
docker compose exec airflow-scheduler bash -c "cd /opt/dbt && dbt debug --profiles-dir /opt/dbt --project-dir /opt/dbt"
docker compose exec airflow-scheduler bash -c "cd /opt/dbt && dbt run --select staging --profiles-dir /opt/dbt --project-dir /opt/dbt"
docker compose exec airflow-scheduler bash -c "cd /opt/dbt && dbt run --select marts --profiles-dir /opt/dbt --project-dir /opt/dbt"
docker compose exec airflow-scheduler bash -c "cd /opt/dbt && dbt test --profiles-dir /opt/dbt --project-dir /opt/dbt"

C:\Projects\data-stack\
├─ docker-compose.yml
├─ Dockerfile.airflow
├─ dags\
├─ logs\
├─ plugins\
├─ dbt_project\
│  ├─ dbt_project.yml
│  ├─ profiles.yml
│  └─ models\
├─ scripts\
│  └─ init-db.sql
└─ superset_config\
   └─ superset_config.py

mkdir dags, logs, plugins, dbt_project, scripts, superset_config
mkdir dbt_project\models
mkdir dbt_project\models\staging
mkdir dbt_project\models\marts


cd C:\Projects\data-stack
docker compose down -v
docker compose build --no-cache
docker compose up airflow-init
docker compose up -d



