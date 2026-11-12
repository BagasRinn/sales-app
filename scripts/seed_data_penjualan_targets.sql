-- ============================================================================
-- RE-SEED DATA PENJUALAN TARGETS - Realistic targets based on actual omset
-- Target = actual omset * random(0.85, 1.15) so achievement is ~85%-115%
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
  END IF;
END $$;

-- Helper: normalize name key
CREATE OR REPLACE FUNCTION normalize_target_name_sql(value text) RETURNS text AS $$
  SELECT trim(regexp_replace(regexp_replace(upper(coalesce(value, '')), '[^A-Z0-9]+', ' ', 'g'), '\s+', ' ', 'g'));
$$ LANGUAGE sql IMMUTABLE;

-- ---------------------------------------------------------------
-- 1. Delete existing SALES_TARGETS data
-- ---------------------------------------------------------------
DELETE FROM data_penjualan_targets WHERE target_type IN ('SALES', 'SUPPLIER');
DELETE FROM import_logs WHERE import_type = 'SALES_TARGETS' AND file_name = 'seed_targets.xlsx';

SELECT 'deleted existing SALES_TARGETS data';

-- ---------------------------------------------------------------
-- 2. Create import_log entri per branch
-- ---------------------------------------------------------------
INSERT INTO import_logs (id, user_id, nama, import_type, total_rows, inserted, updated, skipped, file_name, branch, created_at)
SELECT
  gen_random_uuid() AS id,
  'seed-system' AS user_id,
  'Seed System' AS nama,
  'SALES_TARGETS' AS import_type,
  0 AS total_rows,
  0 AS inserted,
  0 AS updated,
  0 AS skipped,
  'seed_targets.xlsx' AS file_name,
  b.code AS branch,
  now() - make_interval(days := (abs(hashtext(b.code)) % 10) + 1) AS created_at
FROM branches b;

-- ---------------------------------------------------------------
-- 3. Temp mapping import_log_id per branch
-- ---------------------------------------------------------------
DROP TABLE IF EXISTS tmp_branch_import_log;
CREATE TEMP TABLE tmp_branch_import_log AS
SELECT il.branch, il.id AS import_log_id
FROM import_logs il
WHERE il.import_type = 'SALES_TARGETS' AND il.file_name = 'seed_targets.xlsx';

-- ---------------------------------------------------------------
-- 4. Insert SALES targets based on ACTUAL omset per sales per period
--    Target = actual_omset * (0.85 + random() * 0.30)  => 85%-115% of actual
-- ---------------------------------------------------------------
WITH actual_omset AS (
  SELECT
    sales_nama AS name,
    branch,
    to_char(sale_date, 'YYYY-MM') AS period,
    sum(total_amount) AS actual_omset
  FROM imported_sales
  WHERE sale_date >= '2026-09-01' AND sale_date <= '2026-12-31'
  GROUP BY sales_nama, branch, to_char(sale_date, 'YYYY-MM')
)
INSERT INTO data_penjualan_targets (
  id, branch, period, target_type, name, name_key, target_value, import_log_id, created_at, updated_at
)
SELECT
  gen_random_uuid() AS id,
  ao.branch AS branch,
  ao.period AS period,
  'SALES' AS target_type,
  ao.name AS name,
  normalize_target_name_sql(ao.name) AS name_key,
  (ao.actual_omset * (0.85 + random() * 0.30))::bigint AS target_value,
  tmp.import_log_id AS import_log_id,
  now() - make_interval(days := (abs(hashtext(ao.name || ao.period)) % 7) + 1) AS created_at,
  now() - make_interval(days := (abs(hashtext(ao.name || ao.period)) % 7) + 1) AS updated_at
FROM actual_omset ao
JOIN tmp_branch_import_log tmp ON tmp.branch = ao.branch
ON CONFLICT (branch, period, target_type, name_key) DO NOTHING;

SELECT 'SALES targets (from actual omset): ' || count(*) FROM data_penjualan_targets WHERE target_type = 'SALES';

-- ---------------------------------------------------------------
-- 5. Insert SUPPLIER targets based on ACTUAL omset per supplier per period
-- ---------------------------------------------------------------
WITH actual_supplier_omset AS (
  SELECT
    supplier AS name,
    branch,
    to_char(sale_date, 'YYYY-MM') AS period,
    sum(total_amount) AS actual_omset
  FROM imported_sales
  WHERE sale_date >= '2026-09-01' AND sale_date <= '2026-12-31'
    AND supplier IS NOT NULL AND supplier <> ''
  GROUP BY supplier, branch, to_char(sale_date, 'YYYY-MM')
)
INSERT INTO data_penjualan_targets (
  id, branch, period, target_type, name, name_key, target_value, import_log_id, created_at, updated_at
)
SELECT
  gen_random_uuid() AS id,
  ao.branch AS branch,
  ao.period AS period,
  'SUPPLIER' AS target_type,
  ao.name AS name,
  normalize_target_name_sql(ao.name) AS name_key,
  (ao.actual_omset * (0.85 + random() * 0.30))::bigint AS target_value,
  tmp.import_log_id AS import_log_id,
  now() - make_interval(days := (abs(hashtext(ao.name || ao.period)) % 7) + 1) AS created_at,
  now() - make_interval(days := (abs(hashtext(ao.name || ao.period)) % 7) + 1) AS updated_at
FROM actual_supplier_omset ao
JOIN tmp_branch_import_log tmp ON tmp.branch = ao.branch
ON CONFLICT (branch, period, target_type, name_key) DO NOTHING;

SELECT 'SUPPLIER targets (from actual omset): ' || count(*) FROM data_penjualan_targets WHERE target_type = 'SUPPLIER';

-- ---------------------------------------------------------------
-- RINGKASAN
-- ---------------------------------------------------------------
SELECT 'SELESAI' AS status;
SELECT 'total: ' || count(*) FROM data_penjualan_targets
UNION ALL SELECT '  SALES: ' || count(*) FROM data_penjualan_targets WHERE target_type = 'SALES'
UNION ALL SELECT '  SUPPLIER: ' || count(*) FROM data_penjualan_targets WHERE target_type = 'SUPPLIER';

-- Sample: check achievement ratios are realistic (85%-115%)
SELECT
  dt.branch,
  dt.period,
  dt.name,
  dt.target_type,
  dt.target_value,
  COALESCE(ao.actual_omset, 0) AS actual_omset,
  round(100.0 * COALESCE(ao.actual_omset, 0) / NULLIF(dt.target_value, 0), 1) AS achievement_pct
FROM data_penjualan_targets dt
LEFT JOIN (
  SELECT sales_nama AS name, branch, to_char(sale_date, 'YYYY-MM') AS period, sum(total_amount) AS actual_omset
  FROM imported_sales
  WHERE sale_date >= '2026-09-01' AND sale_date <= '2026-12-31'
  GROUP BY sales_nama, branch, to_char(sale_date, 'YYYY-MM')
) ao ON ao.name = dt.name AND ao.branch = dt.branch AND ao.period = dt.period
WHERE dt.target_type = 'SALES'
ORDER BY dt.branch, dt.period, achievement_pct DESC
LIMIT 15;
