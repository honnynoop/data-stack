with source as (
    select * from {{ source('raw', 'orders') }}
),
renamed as (
    select
        order_id,
        customer_id,
        product_id,
        quantity,
        unit_price,
        discount_rate,
        -- 실제 결제 금액 (할인 적용)
        round(quantity * unit_price * (1 - discount_rate), 0) as total_amount,
        -- 할인 전 금액
        quantity * unit_price                                  as gross_amount,
        -- 할인액
        round(quantity * unit_price * discount_rate, 0)        as discount_amount,
        order_date,
        extract(year    from order_date)::int   as order_year,
        extract(month   from order_date)::int   as order_month,
        extract(quarter from order_date)::int   as order_quarter,
        to_char(order_date, 'YYYY-MM')          as year_month,
        extract(dow from order_date)::int       as day_of_week,
        status,
        channel                                 as order_channel,
        case when status = 'completed' then true else false end as is_revenue,
        created_at
    from source
    where order_id is not null
)
select * from renamed
