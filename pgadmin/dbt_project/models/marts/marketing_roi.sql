-- 마케팅 ROI 분석 테이블
-- 채널별 광고비 vs 매출 → ROAS, CAC 계산

with spend as (
    select * from {{ ref('stg_marketing_spend') }}
),
-- 신규 고객의 첫 주문 채널 기준으로 매출 귀속
new_customer_revenue as (
    select
        c.acquisition_channel,
        to_char(o.order_date, 'YYYY-MM') as year_month,
        count(distinct o.customer_id)    as new_customers_acquired,
        sum(o.revenue_amount)            as attributed_revenue
    from {{ ref('fct_orders') }} o
    join {{ ref('dim_customers') }} c using (customer_id)
    where o.is_revenue = true
      and o.order_date = c.first_order_date   -- 첫 구매만
    group by c.acquisition_channel, to_char(o.order_date, 'YYYY-MM')
),
monthly_spend as (
    select
        year_month,
        channel,
        sum(spend_amount)   as total_spend,
        sum(impressions)    as total_impressions,
        sum(clicks)         as total_clicks,
        -- 평균 CTR
        round(sum(clicks)::numeric / nullif(sum(impressions),0) * 100, 4) as avg_ctr,
        -- 평균 CPC
        round(sum(spend_amount) / nullif(sum(clicks),0), 0)               as avg_cpc
    from spend
    group by year_month, channel
),
final as (
    select
        s.year_month,
        s.channel,
        s.total_spend,
        s.total_impressions,
        s.total_clicks,
        s.avg_ctr,
        s.avg_cpc,
        coalesce(r.new_customers_acquired, 0) as new_customers,
        coalesce(r.attributed_revenue,     0) as attributed_revenue,
        -- ROAS (광고비 대비 매출)
        case
            when s.total_spend > 0
            then round(coalesce(r.attributed_revenue,0)::numeric / s.total_spend, 2)
            else 0
        end as roas,
        -- CAC (고객 획득 비용)
        case
            when coalesce(r.new_customers_acquired, 0) > 0
            then round(s.total_spend / r.new_customers_acquired, 0)
            else null
        end as cac
    from monthly_spend s
    left join new_customer_revenue r
        on  s.year_month = r.year_month
        and s.channel    = r.acquisition_channel
)
select * from final
order by year_month, channel
