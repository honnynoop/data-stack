
<img width="498" height="819" alt="image" src="https://github.com/user-attachments/assets/461c55e1-6d9a-4015-b82f-1f038ad7e828" />

<img width="1341" height="415" alt="image" src="https://github.com/user-attachments/assets/9a87df6a-b448-4810-ae2a-04ff4b8d64f7" />


<img width="681" height="551" alt="image" src="https://github.com/user-attachments/assets/fbcf21f6-7811-4c8d-ad15-138f78089a4d" />



SELECT
  year_month,
  total_revenue
FROM marts.monthly_sales
ORDER BY year_month;


<img width="957" height="728" alt="image" src="https://github.com/user-attachments/assets/b32d966b-729f-4407-b88e-af03b4abb8ad" />


SELECT
  year_month,
  SUM(total_revenue)     AS 매출,
  SUM(order_count)       AS 주문수,
  SUM(unique_customers)  AS 구매고객,
  ROUND(AVG(gross_margin_rate),1) AS 이익률
FROM marts.monthly_sales
GROUP BY year_month
ORDER BY year_month;

<img width="1055" height="607" alt="image" src="https://github.com/user-attachments/assets/81ff2d6a-cf14-471a-950c-a505be813868" />


PS C:\WINDOWS\system32> docker exec -it mds_airflow_web bash
airflow@165b4fd98717:/opt/airflow$ # 2. 커넥션 등록
airflow connections add postgres_mds \
  --conn-type postgres \
  --conn-host mds_postgres \
  --conn-schema airflow \
  --conn-login airflow \
  --conn-password airflow \
  --conn-port 5432
[2026-05-08T03:27:03.899+0000] {providers_manager.py:283} INFO - Optional provider feature disabled when importing 'airflow.providers.google.leveldb.hooks.leveldb.LevelDBHook' from 'apache-airflow-providers-google' package
Successfully added `conn_id`=postgres_mds : postgres://airflow:******@mds_postgres:5432/airflow
airflow@165b4fd98717:/opt/airflow$ # 3. 등록 확인
airflow connections get postgres_mds
   |              |           |             |              |         |         |          |      |              | is_extra_enc |              |
id | conn_id      | conn_type | description | host         | schema  | login   | password | port | is_encrypted | rypted       | extra_dejson | get_uri
===+==============+===========+=============+==============+=========+=========+==========+======+==============+==============+==============+===============
3  | postgres_mds | postgres  | None        | mds_postgres | airflow | airflow | airflow  | 5432 | True         | True         | {}           | postgres://air
   |              |           |             |              |         |         |          |      |              |              |              | flow:airflow@m
   |              |           |             |              |         |         |          |      |              |              |              | ds_postgres:54
   |              |           |             |              |         |         |          |      |              |              |              | 32/airflow
   
<img width="1167" height="360" alt="image" src="https://github.com/user-attachments/assets/12530dc9-bab0-4089-baaa-8c81e578bed5" />
