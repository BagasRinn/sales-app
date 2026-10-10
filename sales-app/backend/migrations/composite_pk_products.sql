-- Migration: Add composite primary key (id, branch) to products table
-- and composite FK to order_items and stok_log.
-- Run this against your PostgreSQL database before deploying the updated code.

BEGIN;

-- ============================================================
-- Step 1: Drop existing FK constraints that reference products.id
-- ============================================================

-- Find FK on order_items referencing products (single-column)
DO $$
DECLARE
    fk_name text;
BEGIN
    SELECT constraint_name INTO fk_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_name = 'order_items'
      AND kcu.column_name = 'product_id'
      AND kcu referenced_table_name = 'products';

    IF fk_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE order_items DROP CONSTRAINT %I', fk_name);
        RAISE NOTICE 'Dropped FK: %', fk_name;
    ELSE
        RAISE NOTICE 'No single-column FK found on order_items.product_id';
    END IF;
END $$;

-- Find FK on stok_log referencing products (single-column)
DO $$
DECLARE
    fk_name text;
BEGIN
    SELECT constraint_name INTO fk_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_name = 'stok_log'
      AND kcu.column_name = 'product_id'
      AND kcu referenced_table_name = 'products';

    IF fk_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE stok_log DROP CONSTRAINT %I', fk_name);
        RAISE NOTICE 'Dropped FK: %', fk_name;
    ELSE
        RAISE NOTICE 'No single-column FK found on stok_log.product_id';
    END IF;
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
        ALTER TABLE order_items ADD COLUMN branch VARCHAR(20) NOT NULL DEFAULT '';
        RAISE NOTICE 'Added branch column to order_items';
    ELSE
        RAISE NOTICE 'branch column already exists in order_items';
    END IF;
END $$;

-- ============================================================
-- Step 3: Backfill branch in order_items from orders table
-- ============================================================

UPDATE order_items oi
SET branch = COALESCE(
    (SELECT branch FROM orders WHERE id = oi.order_id LIMIT 1),
    ''
)
WHERE oi.branch IS NULL OR oi.branch = '';

RAISE NOTICE 'Backfilled branch in order_items';

-- ============================================================
-- Step 4: Drop products old primary key, create composite PK
-- ============================================================

ALTER TABLE products DROP CONSTRAINT IF EXISTS products_pkey;
ALTER TABLE products ADD PRIMARY KEY (id, branch);
RAISE NOTICE 'Changed products PK to composite (id, branch)';

-- ============================================================
-- Step 5: Add composite FK constraints
-- ============================================================

ALTER TABLE order_items
ADD CONSTRAINT order_items_product_fk
FOREIGN KEY (product_id, branch) REFERENCES products(id, branch);

ALTER TABLE stok_log
ADD CONSTRAINT stok_log_product_fk
FOREIGN KEY (product_id, branch) REFERENCES products(id, branch);

RAISE NOTICE 'Added composite FK constraints';

COMMIT;
