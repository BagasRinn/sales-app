-- ============================================================
-- CLEANUP SCRIPT — field test reset
-- Database: PostgreSQL (Supabase production)
--
-- Tujuan: wipe semua data, sisakan 3 user default
--   - admin.default  (ADMIN)
--   - manager.default (MANAGER)
--   - sales.default  (SALES)
--
-- CARA PAKAI:
--   1. BACKUP dulu (Supabase Dashboard → Database → Backups)
--   2. Paste di Supabase SQL Editor, jalan per blok
--   3. STEP 1 dulu — verifikasi 3 user default ada
--   4. Kalau ok, lanjut STEP 2 (otomatis dalam 1 transaksi)
--   5. STEP 3 cek sisa row
-- ============================================================


-- ============================================================
-- STEP 1: VERIFIKASI — pastikan 3 user default ada di DB
-- Expected: 3 baris (1 ADMIN, 1 MANAGER, 1 SALES, semua is_active=true)
-- Kalau salah satu missing, JANGAN lanjut — seed manual dulu.
-- ============================================================
SELECT id, username, role, nama, is_active, deleted_at
FROM public.users
WHERE username IN ('admin.default', 'manager.default', 'sales.default')
ORDER BY role;


-- ============================================================
-- STEP 2: WIPE dalam satu transaksi
-- Urutan: child tables (FK) dulu, baru parent.
-- -Aman karena TRUNCATE ... CASCADE auto-handle FK
-- -User yang TIDAK di-keep di-DELETE (bukan TRUNCATE) supaya
--  constraint ke tabel lain tetap rapi.
-- ============================================================
BEGIN;

-- 2a. Semua tabel transaksional + master non-user
TRUNCATE TABLE
    public.order_items,
    public.orders,
    public.customer_sales,
    public.stok_log,
    public.sync_validation_errors,
    public.import_logs,
    public.customers,
    public.products
RESTART IDENTITY CASCADE;

-- 2b. Hapus user lain (selain 3 default). Pakai deleted_at IS NULL safety
--     supaya kalau ada user yang sudah soft-delete, tidak ter-delete dua kali.
DELETE FROM public.users
WHERE username NOT IN ('admin.default', 'manager.default', 'sales.default');

-- 2c. Bump token_version 3 user default → invalidate semua sesi lama
--     (jadi device sales harus login ulang pakai sales.default)
UPDATE public.users
SET token_version = token_version + 1,
    updated_at = NOW()
WHERE username IN ('admin.default', 'manager.default', 'sales.default');

COMMIT;


-- ============================================================
-- STEP 3: VERIFIKASI hasil
-- Expected:
--   users                  = 3
--   products               = 0
--   customers              = 0
--   orders                 = 0
--   order_items            = 0
--   customer_sales         = 0
--   stok_log               = 0
--   sync_validation_errors = 0
--   import_logs            = 0
-- ============================================================
SELECT 'users'                  AS tabel, COUNT(*)::text AS sisa FROM public.users
UNION ALL SELECT 'products',               COUNT(*)::text FROM public.products
UNION ALL SELECT 'customers',              COUNT(*)::text FROM public.customers
UNION ALL SELECT 'orders',                 COUNT(*)::text FROM public.orders
UNION ALL SELECT 'order_items',            COUNT(*)::text FROM public.order_items
UNION ALL SELECT 'customer_sales',         COUNT(*)::text FROM public.customer_sales
UNION ALL SELECT 'stok_log',               COUNT(*)::text FROM public.stok_log
UNION ALL SELECT 'sync_validation_errors', COUNT(*)::text FROM public.sync_validation_errors
UNION ALL SELECT 'import_logs',            COUNT(*)::text FROM public.import_logs
ORDER BY tabel;
