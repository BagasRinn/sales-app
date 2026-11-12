-- imported_sales: margin (10-30% of net_per_unit)
UPDATE imported_sales
SET margin = (net_per_unit * (10 + (abs(hashtext(id::text)) % 21)) / 100)::bigint
WHERE margin IS NULL;
SELECT 'imported_sales margin: ' || count(*) FROM imported_sales WHERE margin IS NOT NULL;

-- imported_sales: mother_sku
UPDATE imported_sales
SET mother_sku = 'MSKU-' || coalesce(upper(product_kode), 'UNK')
WHERE mother_sku IS NULL;
SELECT 'imported_sales mother_sku: ' || count(*) FROM imported_sales WHERE mother_sku IS NOT NULL;

-- imported_sales: devisi based on kategori
UPDATE imported_sales
SET devisi = CASE
    WHEN lower(kategori) IN ('sembako','minuman','makanan') THEN 'FOOD_BEV'
    WHEN lower(kategori) IN ('perawatan','bayi') THEN 'PERSONAL_CARE'
    WHEN lower(kategori) = 'kosmetik' THEN 'COSMETIC'
    ELSE 'GENERAL'
END
WHERE devisi IS NULL;
SELECT 'imported_sales devisi: ' || count(*) FROM imported_sales WHERE devisi IS NOT NULL;

UPDATE imported_sales SET updated_at = now();

-- imported_sales_monthly_summary: product_kode for PRODUCT dimension
UPDATE imported_sales_monthly_summary
SET product_kode = dim_key
WHERE product_kode IS NULL AND dimension = 'PRODUCT' AND dim_key IS NOT NULL AND dim_key <> '';
SELECT 'summary product_kode (PRODUCT): ' || count(*) FROM imported_sales_monthly_summary WHERE product_kode IS NOT NULL;

-- imported_sales_monthly_summary: product_kode from dim_label pattern
UPDATE imported_sales_monthly_summary
SET product_kode = substring(dim_label from '^([A-Z]+-[0-9]+)')
WHERE product_kode IS NULL AND dimension <> 'PRODUCT' AND dim_label ~ '^[A-Z]+-[0-9]+';
SELECT 'summary product_kode (from label): ' || count(*) FROM imported_sales_monthly_summary WHERE product_kode IS NOT NULL;

-- imported_sales_monthly_summary: mother_sku
UPDATE imported_sales_monthly_summary
SET mother_sku = 'MSKU-' || coalesce(product_kode, dim_key, 'UNK')
WHERE mother_sku IS NULL;
SELECT 'summary mother_sku: ' || count(*) FROM imported_sales_monthly_summary WHERE mother_sku IS NOT NULL;

-- imported_sales_monthly_summary: margin for non-TOTAL rows
UPDATE imported_sales_monthly_summary
SET margin = (revenue * (10 + (abs(hashtext(id::text)) % 21)) / 100)::bigint
WHERE dimension <> 'TOTAL' AND margin = 0;
SELECT 'summary margin (>0): ' || count(*) FROM imported_sales_monthly_summary WHERE margin > 0;

UPDATE imported_sales_monthly_summary SET updated_at = now();

SELECT 'Done.' AS status;
