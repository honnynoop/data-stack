with source as (
    select * from {{ source('raw', 'products') }}
),
renamed as (
    select
        product_id,
        name                                        as product_name,
        category,
        subcategory,
        brand,
        price,
        cost,
        stock_qty,
        price - cost                                as margin_amount,
        round((price - cost)::numeric / nullif(price,0) * 100, 2) as margin_rate,
        case
            when price < 40000  then '저가'
            when price < 100000 then '중가'
            when price < 180000 then '고가'
            else '프리미엄'
        end                                         as price_tier,
        created_at
    from source
    where product_id is not null and price > 0
)
select * from renamed
