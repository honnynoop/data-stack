with source as (
    select * from {{ source('raw', 'customers') }}
),
renamed as (
    select
        customer_id,
        name                                    as customer_name,
        lower(trim(email))                      as email,
        city,
        region,
        age_group,
        gender,
        channel                                 as acquisition_channel,
        signup_date,
        current_date - signup_date              as days_since_signup,
        case when region = '수도권' then true else false end as is_capital_region,
        created_at
    from source
    where email is not null
)
select * from renamed
