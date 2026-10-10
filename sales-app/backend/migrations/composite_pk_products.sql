-- Migration: Add composite primary key (id, branch) to products table
-- and composite FK to order_items and stok_log.
-- Run this against your PostgreSQL database before deploying the updated code.

BEGIN;

-- ============================================================
-- Step 1: Drop existing FK constraints that reference products.id
-- ============================================================

ALTER TABLE order_items DROP CONSTRAINT IF EXISTS order_items_product_id_fkey;
ALTER TABLE stok_log DROP CONSTRAINT IF EXISTS stok_log_product_id_fkey;

DO $$
BEGIN
    RAISE NOTICE 'Step 1: Dropped old single-column FK constraints';
END $$;

-- ============================================================
-- Step 2: Add branch column to order_items if not exists
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'order_items' AND column_name = 'branch'
    ) THEN
        ALTER TABLE order_items ADD COLUMN branch VARCHAR(20);
        RAISE NOTICE 'Step 2: Added branch column to order_items (nullable first)';
    ELSE
        RAISE NOTICE 'Step 2: branch column already exists in order_items';
    END IF;
END $$;

-- ============================================================
-- Step 3: Backfill branch in order_items from orders table
-- ============================================================

-- Backfill from orders (for order_items that have a valid order with branch)
UPDATE order_items oi
SET branch = o.branch
FROM orders o
WHERE oi.order_id = o.id
  AND o.branch IS NOT NULL
  AND o.branch != ''
  AND (oi.branch IS NULL OR oi.branch = '');

DO $$
DECLARE backfilled INTEGER;
BEGIN
    GET DIAGNOSTICS backfilled = ROW_COUNT;
    RAISE NOTICE 'Step 3a: Backfilled % order_items from orders', backfilled;
END $$;

-- For remaining orphan order_items, set branch from product's branch
UPDATE order_items oi
SET branch = p.branch
FROM products p
WHERE oi.product_id = p.id
  AND (oi.branch IS NULL OR oi.branch = '');

DO $$
DECLARE from_product INTEGER;
BEGIN
    GET DIAGNOSTICS from_product = ROW_COUNT;
    RAISE NOTICE 'Step 3b: Set % orphan order_items branch from product', from_product;
END $$;

-- Verify no NULL/empty branch remains
DO $$
DECLARE remaining INTEGER;
BEGIN
    SELECT COUNT(*) INTO remaining FROM order_items WHERE branch IS NULL OR branch = '';
    IF remaining > 0 THEN
        RAISE WARNING 'Step 3c: % order_items still have empty branch', remaining;
    ELSE
        RAISE NOTICE 'Step 3c: All order_items have valid branch';
    END IF;
END $$;

-- Set NOT NULL constraint
ALTER TABLE order_items ALTER COLUMN branch SET NOT NULL;
ALTER TABLE order_items ALTER COLUMN branch SET DEFAULT '';

DO $$
BEGIN
    RAISE NOTICE 'Step 3d: Set branch NOT NULL';
END $$;

-- ============================================================
-- Step 4: Fix corrupted stok_log branch data before adding FK
-- ============================================================

-- stok_log.branch has mixed data:
-- 1. 'BJM' (branch code) -> should be 'BANJARMASIN'
-- 2. Numeric values (corrupted: product ID prefixes) -> fix to 'BANJARMASIN'
-- All products exist in BANJARMASIN branch

UPDATE stok_log
SET branch = 'BANJARMASIN'
WHERE branch != 'BANJARMASIN';

DO $$
DECLARE fixed INTEGER;
BEGIN
    GET DIAGNOSTICS fixed = ROW_COUNT;
    RAISE NOTICE 'Step 4: Fixed % corrupted stok_log branch values to BANJARMASIN', fixed;
END $$;

-- ============================================================
-- Step 5: Drop products old primary key, create composite PK
-- ============================================================

ALTER TABLE products DROP CONSTRAINT IF EXISTS products_pkey;
ALTER TABLE products ADD PRIMARY KEY (id, branch);

DO $$
BEGIN
    RAISE NOTICE 'Step 5: Changed products PK to composite (id, branch)';
END $$;

-- ============================================================
-- Step 6: Add composite FK constraints
-- ============================================================

ALTER TABLE order_items
ADD CONSTRAINT order_items_product_fk
FOREIGN KEY (product_id, branch) REFERENCES products(id, branch);

ALTER TABLE stok_log
ADD CONSTRAINT stok_log_product_fk
FOREIGN KEY (product_id, branch) REFERENCES products(id, branch);

DO $$
BEGIN
    RAISE NOTICE 'Step 6: Added composite FK constraints';
END $$;

COMMIT;
