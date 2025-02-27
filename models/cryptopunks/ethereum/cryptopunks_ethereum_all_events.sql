{{ config(
        alias ='all_events',
        post_hook='{{ expose_spells(\'["ethereum"]\',
                                    "project",
                                    "cryptopunks",
                                    \'["cat"]\') }}'
        )
}}

select *
from 
(
    select  evt_block_time
            , punk_id
            , event_type
            , cast(NULL as varchar(5)) as sale_type
            , bidder as from 
            , cast(NULL as varchar(5)) as to 
            , eth_amount
            , usd_amount
            , evt_block_number
            , evt_index
            , evt_tx_hash
    from {{ ref('cryptopunks_ethereum_punk_bid_events') }}

    union all 

    select  evt_block_time
            , punk_id
            , event_type
            , cast(NULL as varchar(5)) as sale_type
            , from 
            , to 
            , eth_amount
            , usd_amount
            , evt_block_number
            , evt_index
            , evt_tx_hash 
    from {{ ref('cryptopunks_ethereum_punk_offer_events') }}

    union all 

    select  block_time
            , token_id 
            , 'Sold' as event_type
            , case when trade_category = 'Offer Accepted' then 'Bid Accept' else trade_category end as sale_type -- convert nft.trades wording to match cryptopunks.app
            , seller
            , buyer
            , amount_original
            , amount_usd
            , block_number 
            , evt_index
            , tx_hash
    from {{ ref('cryptopunks_ethereum_trades') }}

    union all 

    select block_time
            , token_id
            , 'Sold' as event_type
            , 'Wrapped Sale' as sale_type
            , seller
            , buyer
            , amount_original
            , amount_usd
            , block_number
            , cast(NULL as double) as evt_index
            , tx_hash
    from {{ ref('nft_trades') }}
    where nft_contract_address = lower('0xb7f7f6c52f2e2fdb1963eab30438024864c313f6') -- wrapped punk contract
        and blockchain = 'ethereum'

    union all

    -- temporary until rarible history is added to nft_trades - likely missing some other rarible contracts
    select evt_block_time
            , tokenId
            , 'Sold' as event_type
            , 'Wrapped Sale' as sale_type
            , seller
            , buyer
            , price/1e18 as eth_amount
            , cast(NULL as double) as usd_amount
            , evt_block_number
            , evt_index
            , evt_tx_hash
    from {{ source('rarible_v1_ethereum','ERC721Sale_v2_evt_Buy') }}
    where token = lower('0xb7f7f6c52f2e2fdb1963eab30438024864c313f6')

    union all 

    select  evt_block_time
            , punk_id 
            , case  when from = '0x0000000000000000000000000000000000000000' then 'Claimed' 
                    when from = '0xb7f7f6c52f2e2fdb1963eab30438024864c313f6' then 'Unwrap'
                    when to = '0xb7f7f6c52f2e2fdb1963eab30438024864c313f6' then 'Wrap'
                else 'Transfer' end as event_type
            , cast(NULL as varchar(5)) as sale_type
            , from
            , to
            , cast(NULL as double) as eth_amount
            , cast(NULL as double) as usd_amount
            , evt_block_number 
            , evt_index
            , evt_tx_hash
    from {{ ref('cryptopunks_ethereum_punk_transfers') }}
    where evt_tx_hash not in (select distinct tx_hash from {{ ref('cryptopunks_ethereum_trades') }} )
) a 
order by evt_block_number desc, evt_index desc