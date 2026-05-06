with orders as (
    select * from {{ ref('stg_orders') }}
),
customers as (
    select customer_id, customer_name, city, region, age_group, gender,
           acquisition_channel, is_capital_region, customer_grade
    from {{ ref('dim_customers') }}
),
products as (
    select product_id, product_name, category, subcategory, brand,
           price as list_price, cost, margin_rate, price_tier
    from {{ ref('stg_products') }}
),
final as (
    select
        o.order_id,
        o.order_date,
        o.year_month,
        o.order_year,
        o.order_month,
        o.order_quarter,
        o.day_of_week,
        -- 고객
        o.customer_id,
        c.customer_name,
        c.city,
        c.region,
        c.age_group,
        c.gender,
        c.acquisition_channel,
        c.is_capital_region,
        c.customer_grade,
        -- 상품
        o.product_id,
        p.product_name,
        p.category,
        p.subcategory,
        p.brand,
        p.list_price,
        p.price_tier,
        -- 거래
        o.quantity,
        o.unit_price,
        o.discount_rate,
        o.gross_amount,
        o.discount_amount,
        o.total_amount,
        o.order_channel,
        o.status,
        o.is_revenue,
        -- 매출 인식 (completed만)
        case when o.is_revenue then o.total_amount           else 0 end as revenue_amount,
        case when o.is_revenue then p.cost * o.quantity      else 0 end as cost_amount,
        case when o.is_revenue
             then (o.unit_price * (1 - o.discount_rate) - p.cost) * o.quantity
             else 0
        end as gross_profit
    from orders o
    left join customers c using (customer_id)
    left join products  p using (product_id)
)
select * from final
