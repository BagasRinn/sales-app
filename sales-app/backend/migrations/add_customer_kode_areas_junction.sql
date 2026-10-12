-- Migration: Add customer_kode_areas junction table
-- Run these statements step by step against your PostgreSQL database.

-- ============================================================
-- Step 1: Fix existing duplicate (BANJARMASIN, P7932)
-- ============================================================
-- Keep the row with kode_area='MULIA1', delete the one with kode_area='Risna Candra Food'

DELETE FROM customers
WHERE kode = 'P7932'
  AND kode_area = 'Risna Candra Food';

-- ============================================================
-- Step 2: Create unique constraint on customers(branch, kode)
-- ============================================================
CREATE UNIQUE INDEX uq_customers_branch_kode ON customers (branch, kode);

ALTER TABLE customers ALTER COLUMN branch SET NOT NULL;

-- ============================================================
-- Step 3: Create junction table
-- ============================================================
CREATE TABLE customer_kode_areas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    kode_area VARCHAR(50) NOT NULL,
    branch VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(customer_id, kode_area)
);

CREATE INDEX idx_cka_customer ON customer_kode_areas(customer_id);
CREATE INDEX idx_cka_kode_area ON customer_kode_areas(kode_area);
CREATE INDEX idx_cka_branch ON customer_kode_areas(branch);

-- ============================================================
-- Step 4: Backfill junction table from existing kode_area data
-- ============================================================
INSERT INTO customer_kode_areas (customer_id, kode_area, branch)
SELECT id, kode_area, branch
FROM customers
WHERE kode_area IS NOT NULL
  AND kode_area != '';

-- ============================================================
-- Step 5: Clear deprecated kode_area column in customers
-- (kept for backward compat, new data goes to junction table)
-- ============================================================
UPDATE customers SET kode_area = NULL WHERE TRUE;
