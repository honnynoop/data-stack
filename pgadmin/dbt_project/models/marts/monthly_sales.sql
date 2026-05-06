with fct as (
    select * from {{ ref('fct_orders') }}
    where is_revenue = true
),
monthly as (
    select
        year_month,
        order_year,
        order_month,
        order_quarter,
        category,
        region,
        count(order_id)              as order_count,
        sum(quantity)                as total_quantity,
        sum(revenue_amount)          as total_revenue,
        avg(revenue_amount)          as avg_order_revenue,
        sum(cost_amount)             as total_cost,
        sum(gross_profit)            as total_gross_profit,
        round(
            sum(gross_profit)::numeric / nullif(sum(revenue_amount),0) * 100, 2
        )                            as gross_margin_rate,
        count(distinct customer_id)  as unique_customers
    from fct
    group by year_month, order_year, order_month, order_quarter, category, region
),
with_growth as (
    select
        *,
        lag(total_revenue) over (
            partition by category, region order by year_month
        ) as prev_month_revenue,
        round(
            (total_revenue - lag(total_revenue) over (
                partition by category, region order by year_month
            ))::numeric
            / nullif(lag(total_revenue) over (
                partition by category, region order by year_month
            ), 0) * 100, 2
        ) as mom_growth_rate
    from monthly
)
select * from with_growth
order by year_month, category, region
