SELECT
  pl.date_created AS Date,
  pl.order_id AS OrderID,
  o.status,
  pl.product_qty AS Qty,
  pml.sku AS SKU,
  it.order_item_name AS ProductName,
  -- Category Logic
  CASE
    WHEN pml.sku LIKE 'POP%' THEN 'POPPERS'
    WHEN pml.sku LIKE 'DLD%' THEN 'DILDO'
    WHEN pml.sku LIKE 'VIB%' THEN 'VIBRADOR'
    WHEN pml.sku LIKE 'LUB%' OR pml.sku IN ('COS008N', 'COS005N', 'COS009C', 'COS010G') THEN 'LUBRICANTE'
    WHEN pml.sku = 'COS012S' THEN 'TOY SHAMPOO'
    WHEN pml.sku LIKE 'COS%' THEN 'COSILLAS'
    WHEN pml.sku LIKE 'BON%' THEN 'BSDM'
    WHEN pml.sku LIKE 'SUC%' THEN 'SUCCIONADOR'
    WHEN pml.sku LIKE 'LEN%' OR pml.sku LIKE 'MED%' THEN 'LENCERIA'
    WHEN pml.sku LIKE 'PLG%' THEN 'PLUG ANAL'
    WHEN pml.sku LIKE 'COB%' THEN 'COBRE'
    ELSE 'COSILLAS'
  END AS Category,
  CASE
    WHEN o.payment_method LIKE '%mercado-pago%' OR o.payment_method LIKE '%TipTop%' OR o.payment_method = 'wc-clip' THEN "Online"
    ELSE 'COD'
  END AS OrderType,
  o.customer_note,
  -- Payment Type Logic
  CASE
    WHEN o.payment_method LIKE '%mercado-pago%' OR o.payment_method LIKE '%TipTop%' OR o.payment_method = 'wc-clip' or o.customer_note = 'Tarjeta' THEN "Tarjeta"
    WHEN o.payment_method IN ('cheque', 'bacs') OR o.customer_note = 'Transferencia' THEN 'Transferencia'
    ELSE 'Efectivo'
  END AS Payment_Type,
    CASE
    WHEN o.payment_method LIKE '%mercado-pago%' OR o.payment_method LIKE '%TipTop%' OR o.payment_method = 'wc-clip' THEN "3.49% + $4 + IVA"
    WHEN o.customer_note = 'Tarjeta' THEN "3.49% + IVA"
    ELSE 0
  END AS Commission,
  -- Financial Columns (Using Historical Cost)
  ROUND(pl.product_net_revenue, 2) AS ProductNet,
  ROUND(pl.tax_amount, 2) AS Tax,
  ROUND(pl.product_net_revenue + pl.tax_amount, 2) AS ProductPrice,
  
  -- CHANGED: Using COALESCE on the Snapshot Cost from Order Item Meta
  ROUND(pl.product_qty * COALESCE(historical_cost.meta_value, 0), 2) AS ProductCost,
  
  ROUND((pl.product_net_revenue + pl.tax_amount) / NULLIF(pl.product_qty, 0), 2) AS ProductSale,
  COALESCE(historical_cost.meta_value, 0) AS purchase_price,
  
  -- Profit calculation using historical cost
  ROUND((pl.product_net_revenue + pl.tax_amount) - (pl.product_qty * COALESCE(historical_cost.meta_value, 0)), 2) AS Profit,

  -- Commission Calculation
  ROUND(
    ((pl.product_net_revenue + pl.tax_amount + pl.shipping_amount + pl.shipping_tax_amount) * CASE 
        WHEN o.payment_method LIKE '%mercado-pago%' OR o.payment_method LIKE '%TipTop%' OR o.payment_method = 'wc-clip' OR o.customer_note = 'Tarjeta' THEN 0.040484
        ELSE 0 
    END + 
    CASE 
        WHEN o.payment_method LIKE '%mercado-pago%' OR o.payment_method LIKE '%TipTop%' OR o.payment_method = 'wc-clip' 
        THEN 4.64 / COUNT(*) OVER(PARTITION BY pl.order_id) 
        ELSE 0 
    END), 2
  ) AS Commission_Net,

  -- Final Net Profit using historical cost
  ROUND(
    ((pl.product_net_revenue + pl.tax_amount) - (pl.product_qty * COALESCE(historical_cost.meta_value, 0))) 
    - ((pl.product_net_revenue + pl.tax_amount + pl.shipping_amount + pl.shipping_tax_amount)
    * CASE 
        WHEN o.payment_method LIKE '%mercado-pago%' OR o.payment_method LIKE '%TipTop%' OR o.payment_method = 'wc-clip' OR o.customer_note = 'Tarjeta' THEN 0.040484
        ELSE 0 
    END + 
    CASE 
        WHEN o.payment_method LIKE '%mercado-pago%' OR o.payment_method LIKE '%TipTop%' OR o.payment_method = 'wc-clip' 
        THEN 4.64 / COUNT(*) OVER(PARTITION BY pl.order_id) 
        ELSE 0 
    END), 2
  ) AS Net_Profit,

  ROUND(pl.shipping_amount, 2) AS shipping_cost,
  ROUND(pl.shipping_tax_amount, 2) AS shipping_tax,
  IF(pl.variation_id > 0, pl.variation_id, pl.product_id) AS replaced_id

FROM wp_wc_order_product_lookup AS pl
JOIN wp_wc_orders AS o ON o.id = pl.order_id
JOIN wp_wc_product_meta_lookup AS pml ON pml.product_id = IF(pl.variation_id > 0, pl.variation_id, pl.product_id)
JOIN wp_woocommerce_order_items AS it ON it.order_item_id = pl.order_item_id

-- NEW JOIN: Pulling the cost that was saved at the time of sale
LEFT JOIN wp_woocommerce_order_itemmeta AS historical_cost 
    ON it.order_item_id = historical_cost.order_item_id 
    AND historical_cost.meta_key = '_alg_wc_cog_item_cost'

WHERE pml.SKU NOT LIKE 'BZR%' AND o.status = 'wc-completed'
ORDER BY Date DESC;