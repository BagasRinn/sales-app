-- ============================================================================
-- SEED IMPORTED_RETURNS - Data retur penjualan untuk halaman Data Penjualan
-- Mengisi table imported_returns dengan data variatif berbasis produk aktual
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
  END IF;
END $$;

-- Helper: generate dedupe key
CREATE OR REPLACE FUNCTION gen_dedupe_key(text, date, text) RETURNS text AS $$
  SELECT encode(digest(concat($1, '|', $2, '|', $3), 'sha256'), 'hex');
$$ LANGUAGE sql IMMUTABLE;

-- ---------------------------------------------------------------
-- 1. Buat import_log untuk returns
-- ---------------------------------------------------------------
DELETE FROM imported_returns;
DELETE FROM import_logs WHERE import_type = 'SALES_RETURNS';

INSERT INTO import_logs (id, user_id, nama, import_type, total_rows, inserted, updated, skipped, file_name, branch, created_at)
SELECT
  gen_random_uuid() AS id,
  'seed-system' AS user_id,
  'Seed System' AS nama,
  'SALES_RETURNS' AS import_type,
  0 AS total_rows,
  0 AS inserted,
  0 AS updated,
  0 AS skipped,
  'seed_returns.xlsx' AS file_name,
  b.code AS branch,
  now() - make_interval(days := (abs(hashtext(b.code || 'retur')) % 10) + 1) AS created_at
FROM branches b;

-- ---------------------------------------------------------------
-- 2. Temp mapping import_log_id per branch
-- ---------------------------------------------------------------
DROP TABLE IF EXISTS tmp_branch_return_log;
CREATE TEMP TABLE tmp_branch_return_log AS
SELECT il.branch, il.id AS import_log_id
FROM import_logs il
WHERE il.import_type = 'SALES_RETURNS' AND il.file_name = 'seed_returns.xlsx';

-- ---------------------------------------------------------------
-- 3. Insert imported_returns based on actual product data
--    Ambil sample produk per branch, buat retur dengan qty parsial
--    revenue = qty_returned * avg_price * faktor(0.3-0.9)
-- ---------------------------------------------------------------
WITH product_samples AS (
  SELECT DISTINCT
    branch,
    product_kode,
    product_nama,
    supplier,
    devisi,
    (avg(net_per_unit) OVER (PARTITION BY branch, product_kode))::bigint AS avg_price
  FROM imported_sales
  WHERE product_kode IS NOT NULL AND product_kode <> ''
),
return_rows AS (
  SELECT
    ps.branch,
    ps.product_kode,
    ps.product_nama,
    ps.supplier,
    ps.devisi,
    ps.avg_price,
    (random() * 20 + 1)::int AS qty_returned,
    (make_timestamp(
      2026,
      (9 + (abs(hashtext(ps.product_kode || ps.branch)) % 4))::int,
      (1 + (abs(hashtext(ps.product_kode || ps.branch || 'd')) % 28))::int,
      0, 0, 0
    ))::date AS sale_date,
    ('CUST-' || ps.branch || '-' || lpad((abs(hashtext(ps.product_kode || ps.branch || 'c')) % 200 + 1)::text, 3, '0')) AS customer_kode,
    ('Toko Pelanggan ' || lpad((abs(hashtext(ps.product_kode || ps.branch || 'c')) % 200 + 1)::text, 3, '0')) AS customer_nama,
    ('Sales ' || ps.branch || '_' || lpad((abs(hashtext(ps.product_kode || ps.branch || 's')) % 12 + 1)::text, 2, '0')) AS sales_nama
  FROM product_samples ps
  WHERE random() < 0.15  -- ~15% of products become return rows
)
INSERT INTO imported_returns (
  id, import_log_id, branch, sale_date, product_kode, product_nama,
  mother_sku, devisi, supplier, customer_kode, customer_nama, sales_nama,
  revenue, margin, dedupe_key, created_at, updated_at
)
SELECT
  gen_random_uuid() AS id,
  tmp.import_log_id AS import_log_id,
  rr.branch AS branch,
  rr.sale_date AS sale_date,
  rr.product_kode AS product_kode,
  rr.product_nama AS product_nama,
  'MSKU-' || upper(rr.product_kode) AS mother_sku,
  rr.devisi AS devisi,
  rr.supplier AS supplier,
  rr.customer_kode AS customer_kode,
  rr.customer_nama AS customer_nama,
  rr.sales_nama AS sales_nama,
  (rr.qty_returned * rr.avg_price * (0.3 + random() * 0.6))::bigint AS revenue,
  (rr.qty_returned * rr.avg_price * (0.3 + random() * 0.6) * (0.15 + random() * 0.15))::bigint AS margin,
  gen_dedupe_key(rr.branch, rr.sale_date, rr.product_kode || '_' || rr.qty_returned::text) AS dedupe_key,
  now() - make_interval(days := (abs(hashtext(rr.product_kode || rr.branch)) % 30) + 1) AS created_at,
  now() - make_interval(days := (abs(hashtext(rr.product_kode || rr.branch)) % 30) + 1) AS updated_at
FROM return_rows rr
JOIN tmp_branch_return_log tmp ON tmp.branch = rr.branch
ON CONFLICT (dedupe_key) DO NOTHING;

-- ---------------------------------------------------------------
-- RINGKASAN
-- ---------------------------------------------------------------
SELECT 'SELESAI' AS status;
SELECT 'imported_returns total: ' || count(*) FROM imported_returns
UNION ALL SELECT '  by branch:';
SELECT branch, count(*) as jumlah_retur, sum(revenue) as total_revenue_retur
FROM imported_returns
GROUP BY branch
ORDER BY branch;

SELECT '--- by devisi ---';
SELECT devisi, count(*) as jumlah, sum(revenue) as total_revenue
FROM imported_returns
GROUP BY devisi
ORDER BY devisi;

SELECT '--- sample data ---';
SELECT branch, sale_date, product_kode, product_nama, supplier, devisi, sales_nama, revenue, margin
FROM imported_returns
ORDER BY sale_date DESC, branch
LIMIT 10;
