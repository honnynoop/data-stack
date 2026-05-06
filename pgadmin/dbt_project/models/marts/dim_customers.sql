-- 고객 차원 테이블: RFM 세그멘테이션 포함

with customers as (
    select * from {{ ref('stg_customers') }}
),
orders as (
    select * from {{ ref('stg_orders') }}
    where is_revenue = true
),
order_stats as (
    select
        customer_id,
        count(order_id)                              as total_orders,
        sum(total_amount)                            as lifetime_value,
        avg(total_amount)                            as avg_order_value,
        max(order_date)                              as last_order_date,
        min(order_date)                              as first_order_date,
        current_date - max(order_date)               as days_since_last_order,
        max(order_date) - min(order_date)            as customer_lifespan_days
    from orders
    group by customer_id
),
-- RFM 점수 (각 1~5점)
rfm as (
    select
        customer_id,
        -- Recency: 최근 구매일일수록 높은 점수
        ntile(5) over (order by days_since_last_order desc nulls last) as r_score,
        -- Frequency: 구매 횟수 많을수록 높은 점수
        ntile(5) over (order by total_orders asc nulls first)          as f_score,
        -- Monetary: 구매 금액 많을수록 높은 점수
        ntile(5) over (order by lifetime_value asc nulls first)        as m_score
    from order_stats
),
final as (
    select
        c.customer_id,
        c.customer_name,
        c.email,
        c.city,
        c.region,
        c.age_group,
        c.gender,
        c.acquisition_channel,
        c.signup_date,
        c.is_capital_region,
        c.days_since_signup,
        coalesce(o.total_orders,          0) as total_orders,
        coalesce(o.lifetime_value,        0) as lifetime_value,
        coalesce(o.avg_order_value,       0) as avg_order_value,
        o.first_order_date,
        o.last_order_date,
        coalesce(o.days_since_last_order, 999) as days_since_last_order,
        coalesce(o.customer_lifespan_days,  0) as customer_lifespan_days,
        -- RFM 점수
        coalesce(r.r_score, 0) as rfm_r,
        coalesce(r.f_score, 0) as rfm_f,
        coalesce(r.m_score, 0) as rfm_m,
        coalesce(r.r_score, 0) + coalesce(r.f_score, 0) + coalesce(r.m_score, 0) as rfm_total,
        -- 고객 등급
        case
            when coalesce(o.lifetime_value, 0) >= 600000  then 'VIP'
            when coalesce(o.lifetime_value, 0) >= 300000  then '골드'
            when coalesce(o.lifetime_value, 0) >= 100000  then '실버'
            when coalesce(o.total_orders,   0) =  0       then '신규'
            else '브론즈'
        end as customer_grade,
        case when o.customer_id is not null then true else false end as has_purchased
    from customers c
    left join order_stats o using (customer_id)
    left join rfm r using (customer_id)
)
select * from final
