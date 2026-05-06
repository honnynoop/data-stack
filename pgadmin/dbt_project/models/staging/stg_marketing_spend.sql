with source as (
    select * from {{ source('raw', 'marketing_spend') }}
),
renamed as (
    select
        id                                          as spend_id,
        spend_date,
        to_char(spend_date, 'YYYY-MM')             as year_month,
        extract(year  from spend_date)::int         as spend_year,
        extract(month from spend_date)::int         as spend_month,
        channel,
        campaign,
        spend_amount,
        coalesce(impressions, 0)                   as impressions,
        coalesce(clicks, 0)                        as clicks,
        -- CTR (클릭률)
        case
            when coalesce(impressions, 0) > 0
            then round(clicks::numeric / impressions * 100, 4)
            else 0
        end                                        as ctr,
        -- CPC (클릭당 비용)
        case
            when coalesce(clicks, 0) > 0
            then round(spend_amount / clicks, 0)
            else 0
        end                                        as cpc,
        created_at
    from source
)
select * from renamed
