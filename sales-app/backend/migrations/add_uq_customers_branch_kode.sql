-- Migration: Add unique constraint uq_customers_branch_kode to customers table
-- Run this against your PostgreSQL database before deploying the updated code.

-- Run these two statements (without BEGIN/COMMIT wrapping):
CREATE UNIQUE INDEX uq_customers_branch_kode ON customers (branch, kode);
ALTER TABLE customers ALTER COLUMN branch SET NOT NULL;
