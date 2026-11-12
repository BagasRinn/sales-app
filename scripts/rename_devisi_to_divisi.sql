-- ============================================================================
-- Rename devisi -> divisi columns and add more divisi variety
-- ============================================================================

-- 1. Rename columns in imported_sales and imported_returns
ALTER TABLE imported_sales RENAME COLUMN devisi TO divisi;
ALTER TABLE imported_returns RENAME COLUMN devisi TO divisi;

-- 2. Add more divisi variety to imported_sales (currently only 3 values)
-- Update some rows to new divisi values for better coverage
UPDATE imported_sales
SET divisi = CASE
    WHEN abs(hashtext(id::text)) % 8 = 0 THEN 'ELEKTRONIK'
    WHEN abs(hashtext(id::text)) % 8 = 1 THEN 'KECANTIKAN'
    WHEN abs(hashtext(id::text)) % 8 = 2 THEN 'OLAHRAGA'
    WHEN abs(hashtext(id::text)) % 8 = 3 THEN 'BUKU'
    WHEN abs(hashtext(id::text)) % 8 = 4 THEN 'OTO'
    WHEN abs(hashtext(id::text)) % 8 = 5 THEN 'PERTANIAN'
    WHEN abs(hashtext(id::text)) % 8 = 6 THEN 'COSMETIC'
    ELSE 'FOOD_BEV'
END
WHERE random() < 0.6;

-- 3. Add more divisi variety to imported_returns
UPDATE imported_returns
SET divisi = CASE
    WHEN abs(hashtext(id::text)) % 8 = 0 THEN 'ELEKTRONIK'
    WHEN abs(hashtext(id::text)) % 8 = 1 THEN 'KECANTIKAN'
    WHEN abs(hashtext(id::text)) % 8 = 2 THEN 'OLAHRAGA'
    WHEN abs(hashtext(id::text)) % 8 = 3 THEN 'BUKU'
    WHEN abs(hashtext(id::text)) % 8 = 4 THEN 'OTO'
    WHEN abs(hashtext(id::text)) % 8 = 5 THEN 'PERTANIAN'
    WHEN abs(hashtext(id::text)) % 8 = 6 THEN 'COSMETIC'
    ELSE 'FOOD_BEV'
END
WHERE random() < 0.6;

-- 4. Clear summary state so snapshots recompute with new divisi data
DELETE FROM imported_sales_summary_state;
DELETE FROM imported_sales_monthly_summary;

-- 5. Verify
SELECT 'imported_sales divisi:' AS info;
SELECT divisi, count(*) FROM imported_sales GROUP BY divisi ORDER BY divisi;
SELECT 'imported_returns divisi:' AS info;
SELECT divisi, count(*) FROM imported_returns GROUP BY divisi ORDER BY divisi;
SELECT 'summary cleared:' AS info;
SELECT count(*) AS remaining_summary_rows FROM imported_sales_monthly_summary;
SELECT count(*) AS remaining_state_rows FROM imported_sales_summary_state;
