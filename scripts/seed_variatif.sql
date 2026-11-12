-- ============================================================================
-- SEEDING VARIATIF MAKSIMAL - Mengisi data dummy lengkap untuk semua fitur
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
  END IF;
END $$;

-- ============================================================================
-- 1. PRODUK - lebih banyak produk per cabang
-- ============================================================================
INSERT INTO products (id, branch, nama_barang, harga, stok_sistem, stok_booking, stok_diterima, kategori, satuan, nama_supplier, order_type)
SELECT
  'PRD-' || branch || '-' || lpad(gs.seq::text, 4, '0') AS id,
  branch,
  s.nama,
  s.harga,
  (random() * 500)::int + 50 AS stok_sistem,
  (random() * 50)::int AS stok_booking,
  (random() * 30)::int AS stok_diterima,
  s.kategori,
  s.satuan,
  s.supplier,
  CASE WHEN random() < 0.3 THEN '4P' ELSE 'REGULER' END AS order_type
FROM branches b
CROSS JOIN LATERAL generate_series(1, 20) AS gs(seq)
CROSS JOIN LATERAL (
  SELECT
    CASE (gs.seq % 6)
      WHEN 0 THEN 'Minyak Goreng ' || lpad((gs.seq % 10 + 1)::text, 2, '0') || 'ml'
      WHEN 1 THEN 'Air Mineral ' || lpad((gs.seq % 5 + 1)::text, 1, '0') || 'kg'
      WHEN 2 THEN 'Wafer ' || lpad((gs.seq % 4 + 1)::text, 1, '0') || 'L'
      WHEN 3 THEN 'Deterjen ' || lpad((gs.seq % 3 + 1)::text, 1, '0') || 'x24'
      WHEN 4 THEN 'Popok Bayi ' || lpad((gs.seq % 6 + 1)::text, 1, '0') || 'x6'
      ELSE 'Lipstik ' || lpad((gs.seq % 5 + 1)::text, 1, '0') || 'ml'
    END AS nama,
    (random() * 50000 + 5000)::int AS harga,
    CASE (gs.seq % 6)
      WHEN 0 THEN 'Sembako'
      WHEN 1 THEN 'Minuman'
      WHEN 2 THEN 'Makanan'
      WHEN 3 THEN 'Perawatan'
      WHEN 4 THEN 'Bayi'
      ELSE 'Kosmetik'
    END AS kategori,
    'pcs' AS satuan,
    CASE (gs.seq % 6)
      WHEN 0 THEN 'PT SINAR ABADI'
      WHEN 1 THEN 'UD BERKAH JAYA'
      WHEN 2 THEN 'CANDRA FOOD, CV'
      WHEN 3 THEN 'PT MEGA DISTRIBUSI'
      WHEN 4 THEN 'PT SUMBER MAKMUR'
      ELSE 'Supplier Test E2E'
    END AS supplier
) s
WHERE NOT EXISTS (
  SELECT 1 FROM products p2 WHERE p2.id = 'PRD-' || b.code || '-' || lpad(gs.seq::text, 4, '0') AND p2.branch = b.code
);

SELECT 'produk total: ' || count(*) FROM products;

-- ============================================================================
-- 2. CUSTOMERS - lebih banyak toko per cabang
-- ============================================================================
INSERT INTO customers (id, branch, kode, nama_toko, alamat, kode_area, created_at, updated_at)
SELECT
  gen_random_uuid() AS id,
  b.code AS branch,
  upper(b.code) || lpad(gs.seq::text, 3, '0') AS kode,
  c.nama AS nama_toko,
  c.alamat AS alamat,
  c.kode_area AS kode_area,
  now() - (random() * interval '90 days') AS created_at,
  now() - (random() * interval '30 days') AS updated_at
FROM branches b
CROSS JOIN LATERAL generate_series(1, 15) AS gs(seq)
CROSS JOIN LATERAL (
  SELECT
    CASE (gs.seq % 8)
      WHEN 0 THEN 'Toko Abadi Jaya'
      WHEN 1 THEN 'Warung Makmur Sejahtera'
      WHEN 2 THEN 'Agen Berkah Tani'
      WHEN 3 THEN 'UD Sumber Rejeki'
      WHEN 4 THEN 'PT Cahaya Abadi'
      WHEN 5 THEN 'Grosir Sentosa Baru'
      WHEN 6 THEN 'Koperasi Tunas Harapan'
      ELSE 'Toko Sejahtera Mandiri'
    END AS nama,
    'Jl. ' || CASE (gs.seq % 5)
      WHEN 0 THEN 'Merah Putih'
      WHEN 1 THEN 'Sudirman'
      WHEN 2 THEN 'Thamrin'
      WHEN 3 THEN 'Gajah Mada'
      ELSE 'HOS Cokroaminoto'
    END || ' No. ' || lpad((gs.seq * 7 + 3)::text, 2, '0') AS alamat,
    CASE (gs.seq % 4)
      WHEN 0 THEN 'AREA-01'
      WHEN 1 THEN 'AREA-02'
      WHEN 2 THEN 'AREA-03'
      ELSE 'AREA-04'
    END AS kode_area
) c
WHERE NOT EXISTS (
  SELECT 1 FROM customers c2 WHERE c2.kode = upper(b.code) || lpad(gs.seq::text, 3, '0') AND c2.branch = b.code AND c2.kode_area = c.kode_area
);

SELECT 'customers total: ' || count(*) FROM customers;

-- ============================================================================
-- 3. ORDERS - semua status termasuk CANCELLED
-- ============================================================================
INSERT INTO orders (
  id, branch, sales_id, customer_id, status, notes, created_at,
  store_name, store_contact, store_address, order_type,
  cancelled_items, reject_reason, invoice_number, client_request_id,
  order_discount_type, order_discount_nominal,
  order_up_price_type, order_up_price_nominal
)
SELECT
  gen_random_uuid() AS id,
  o.branch AS branch,
  o.sales_id AS sales_id,
  o.customer_id AS customer_id,
  o.status AS status,
  o.notes AS notes,
  o.created_at AS created_at,
  o.store_name AS store_name,
  o.store_contact AS store_contact,
  o.store_address AS store_address,
  o.order_type AS order_type,
  o.cancelled_items AS cancelled_items,
  o.reject_reason AS reject_reason,
  o.invoice_number AS invoice_number,
  o.client_request_id AS client_request_id,
  o.order_discount_type AS order_discount_type,
  o.order_discount_nominal AS order_discount_nominal,
  o.order_up_price_type AS order_up_price_type,
  o.order_up_price_nominal AS order_up_price_nominal
FROM (
  SELECT
    b.code AS branch,
    u.id AS sales_id,
    c.id AS customer_id,
    CASE (gs.seq % 7)
      WHEN 0 THEN 'DRAFT'
      WHEN 1 THEN 'PENDING'
      WHEN 2 THEN 'APPROVED'
      WHEN 3 THEN 'REJECTED'
      WHEN 4 THEN 'CANCELLED'
      WHEN 5 THEN 'APPROVED'
      ELSE 'PENDING'
    END AS status,
    CASE (gs.seq % 5)
      WHEN 0 THEN 'Order bulk untuk restock mingguan'
      WHEN 1 THEN 'Tambahan stok promosi'
      WHEN 2 THEN 'Ganti produk rusak'
      WHEN 3 THEN 'Order pertama kali toko baru'
      ELSE 'Order reguler harian'
    END AS notes,
    now() - (random() * interval '60 days') AS created_at,
    c.nama_toko AS store_name,
    '08' || lpad((gs.seq * 13 + 7)::text, 10, '0') AS store_contact,
    c.alamat AS store_address,
    CASE WHEN random() < 0.4 THEN '4P' ELSE 'REGULER' END AS order_type,
    CASE WHEN (gs.seq % 7) = 4 THEN '{"item_1": 2, "item_2": 1}'::json ELSE NULL END AS cancelled_items,
    CASE WHEN (gs.seq % 7) = 3 THEN 'Budget melebihi target bulanan' ELSE NULL END AS reject_reason,
    'INV-' || b.code || '-' || lpad(gs.seq::text, 4, '0') AS invoice_number,
    'req-' || gen_random_uuid()::text AS client_request_id,
    CASE (gs.seq % 4)
      WHEN 0 THEN 'PERCENT'
      WHEN 1 THEN 'NOMINAL'
      ELSE NULL
    END AS order_discount_type,
    CASE (gs.seq % 4)
      WHEN 0 THEN 50000
      WHEN 1 THEN 100000
      ELSE NULL
    END AS order_discount_nominal,
    CASE (gs.seq % 3)
      WHEN 0 THEN 'PERCENT'
      WHEN 1 THEN 'NOMINAL'
      ELSE NULL
    END AS order_up_price_type,
    CASE (gs.seq % 3)
      WHEN 0 THEN 25000
      WHEN 1 THEN 50000
      ELSE NULL
    END AS order_up_price_nominal
  FROM branches b
  CROSS JOIN LATERAL generate_series(1, 25) AS gs(seq)
  CROSS JOIN LATERAL (
    SELECT id FROM users u WHERE u.role = 'SALES' AND u.branch = b.code AND u.is_active = true ORDER BY random() LIMIT 1
  ) u
  CROSS JOIN LATERAL (
    SELECT id, nama_toko, alamat FROM customers c WHERE c.branch = b.code ORDER BY random() LIMIT 1
  ) c
) o
WHERE NOT EXISTS (
  SELECT 1 FROM orders o2 WHERE o2.invoice_number = o.invoice_number
);

SELECT 'orders total: ' || count(*) FROM orders;
SELECT status, count(*) FROM orders GROUP BY status ORDER BY status;

-- ============================================================================
-- 4. ORDER_ITEMS - variasi discount, up_price, qty
-- ============================================================================
INSERT INTO order_items (
  id, order_id, product_id, branch, qty,
  discount_percent, discount_type, discount_nominal,
  discount2_type, discount2_percent, discount2_nominal,
  discount3_type, discount3_percent, discount3_nominal,
  up_price_type, up_price_percent, up_price_nominal
)
SELECT
  gen_random_uuid() AS id,
  oi.order_id AS order_id,
  oi.product_id AS product_id,
  oi.branch AS branch,
  oi.qty AS qty,
  oi.discount_percent AS discount_percent,
  oi.discount_type AS discount_type,
  oi.discount_nominal AS discount_nominal,
  oi.discount2_type AS discount2_type,
  oi.discount2_percent AS discount2_percent,
  oi.discount2_nominal AS discount2_nominal,
  oi.discount3_type AS discount3_type,
  oi.discount3_percent AS discount3_percent,
  oi.discount3_nominal AS discount3_nominal,
  oi.up_price_type AS up_price_type,
  oi.up_price_percent AS up_price_percent,
  oi.up_price_nominal AS up_price_nominal
FROM (
  SELECT
    o.id AS order_id,
    o.branch AS branch,
    p.id AS product_id,
    (random() * 20 + 1)::int AS qty,
    CASE (gs.seq % 5)
      WHEN 0 THEN (random() * 10 + 1)::numeric(10,4)
      ELSE 0
    END AS discount_percent,
    CASE (gs.seq % 5)
      WHEN 0 THEN 'PERCENT'
      ELSE NULL
    END AS discount_type,
    CASE (gs.seq % 5)
      WHEN 1 THEN (random() * 5000 + 1000)::int
      ELSE 0
    END AS discount_nominal,
    'NONE' AS discount2_type,
    0 AS discount2_percent,
    0 AS discount2_nominal,
    'NONE' AS discount3_type,
    0 AS discount3_percent,
    0 AS discount3_nominal,
    CASE (gs.seq % 4)
      WHEN 0 THEN 'PERCENT'
      WHEN 1 THEN 'NOMINAL'
      ELSE 'NONE'
    END AS up_price_type,
    CASE (gs.seq % 4)
      WHEN 0 THEN (random() * 5 + 1)::numeric(10,4)
      WHEN 1 THEN (random() * 500 + 100)::numeric(10,4)
      ELSE 0
    END AS up_price_percent,
    CASE (gs.seq % 4)
      WHEN 1 THEN (random() * 2000 + 500)::int
      ELSE 0
    END AS up_price_nominal
  FROM orders o
  CROSS JOIN LATERAL (
    SELECT p.id FROM products p WHERE p.branch = o.branch ORDER BY random() LIMIT 1
  ) p
  CROSS JOIN LATERAL generate_series(1, 3) AS gs(seq)
  WHERE o.status IN ('PENDING', 'APPROVED', 'DRAFT')
) oi
ON CONFLICT DO NOTHING;

SELECT 'order_items total: ' || count(*) FROM order_items;

-- ============================================================================
-- 5. SALES_TARGETS - target per sales per periode
-- ============================================================================
INSERT INTO sales_targets (id, user_id, period, target_type, target_value, incentive_amount, created_at, updated_at)
SELECT
  gen_random_uuid() AS id,
  u.id AS user_id,
  st.period AS period,
  st.target_type AS target_type,
  st.target_value AS target_value,
  st.incentive_amount AS incentive_amount,
  now() - interval '30 days' AS created_at,
  now() - interval '30 days' AS updated_at
FROM users u
CROSS JOIN LATERAL (
  SELECT * FROM (
    VALUES
      ('2026-09', 'OMZET', 50000000, 1000000),
      ('2026-09', 'JUMLAH_ORDER', 100, 500000),
      ('2026-10', 'OMZET', 60000000, 1200000),
      ('2026-10', 'JUMLAH_ORDER', 120, 600000),
      ('2026-11', 'OMZET', 70000000, 1500000),
      ('2026-11', 'JUMLAH_ORDER', 150, 800000),
      ('2026-12', 'OMZET', 80000000, 2000000),
      ('2026-12', 'JUMLAH_ORDER', 180, 1000000)
  ) AS v(period, target_type, target_value, incentive_amount)
) st
WHERE u.role = 'SALES' AND u.is_active = true
ON CONFLICT (user_id, period) DO NOTHING;

SELECT 'sales_targets total: ' || count(*) FROM sales_targets;

-- ============================================================================
-- 6. BULLETINS - tanggal expired variatif
-- ============================================================================
INSERT INTO bulletins (id, branch, title, description, pdf_url, expire_at, created_at, updated_at)
SELECT
  gen_random_uuid() AS id,
  b.code AS branch,
  bt.title AS title,
  bt.description AS description,
  NULL AS pdf_url,
  bt.expire_at::timestamptz AS expire_at,
  now() - interval '15 days' AS created_at,
  now() - interval '15 days' AS updated_at
FROM branches b
CROSS JOIN LATERAL (
  SELECT * FROM (
    VALUES
      ('Promo Akhir Tahun', 'Diskon spesial untuk semua produk hingga akhir tahun.', '2026-12-31 23:59:59+00'),
      ('Produk Baru Baby Care', 'Koleksi popok bayi dan perawatan bayi baru telah tiba.', '2026-12-15 23:59:59+00'),
      ('Update Harga Supplier', 'Perubahan harga dari beberapa supplier mulai bulan depan.', '2026-11-30 23:59:59+00'),
      ('Reminder Stock Opname', 'Mohon semua sales untuk melakukan stok opname minggu ini.', '2026-11-20 23:59:59+00'),
      ('Diskon 4P Minggu Ini', 'Diskon spesial untuk produk dengan order_type 4P minggu ini.', '2026-11-17 23:59:59+00'),
      ('Target Bonus Tahun Baru', 'Bonus spesial untuk sales yang mencapai target Desember.', '2027-01-15 23:59:59+00'),
      ('Promo Sembako Murah', 'Harga spesial untuk semua produk sembako bulan ini.', '2026-11-25 23:59:59+00')
  ) AS v(title, description, expire_at)
) bt
WHERE NOT EXISTS (
  SELECT 1 FROM bulletins b2 WHERE b2.title = bt.title AND b2.branch = b.code
);

SELECT 'bulletins total: ' || count(*) FROM bulletins;

-- ============================================================================
-- 7. AREA_ASSIGNMENTS (no id column, PK = kode_area + sales_id + branch)
-- ============================================================================
INSERT INTO area_assignments (kode_area, sales_id, branch, assigned_by, assigned_at)
SELECT
  'AREA-' || lpad((gs.seq % 4 + 1)::text, 2, '0') AS kode_area,
  u.id AS sales_id,
  u.branch AS branch,
  (SELECT id FROM users WHERE role = 'SUPERVISOR' AND branch = u.branch AND is_active = true ORDER BY random() LIMIT 1) AS assigned_by,
  now() - interval '10 days' AS assigned_at
FROM users u
CROSS JOIN LATERAL generate_series(1, 2) AS gs(seq)
WHERE u.role = 'SALES' AND u.is_active = true
ON CONFLICT (kode_area, sales_id, branch) DO NOTHING;

SELECT 'area_assignments total: ' || count(*) FROM area_assignments;

-- ============================================================================
-- 8. CUSTOMER_ASSIGNMENTS (no id column, PK = customer_id + sales_id)
-- ============================================================================
INSERT INTO customer_assignments (customer_id, sales_id, assigned_by, assigned_at)
SELECT
  c.id AS customer_id,
  u.id AS sales_id,
  (SELECT id FROM users WHERE role = 'SUPERVISOR' AND branch = u.branch AND is_active = true ORDER BY random() LIMIT 1) AS assigned_by,
  now() - interval '8 days' AS assigned_at
FROM users u
JOIN customers c ON c.branch = u.branch
WHERE u.role = 'SALES' AND u.is_active = true
AND NOT EXISTS (
  SELECT 1 FROM customer_assignments ca WHERE ca.sales_id = u.id AND ca.customer_id = c.id
)
LIMIT 200;

SELECT 'customer_assignments total: ' || count(*) FROM customer_assignments;

-- ============================================================================
-- 9. STOK_LOG - column names: sumber, field_terdampak, nilai_sebelum, nilai_sesudah
-- ============================================================================
INSERT INTO stok_log (id, order_id, product_id, branch, sumber, field_terdampak, delta, nilai_sebelum, nilai_sesudah, actor_id, created_at)
SELECT
  gen_random_uuid() AS id,
  o.id AS order_id,
  p.id AS product_id,
  p.branch AS branch,
  'ORDER_APPROVE' AS sumber,
  'stok_diterima' AS field_terdampak,
  (random() * 10 + 1)::int AS delta,
  p.stok_diterima AS nilai_sebelum,
  p.stok_diterima + (random() * 10 + 1)::int AS nilai_sesudah,
  u.id AS actor_id,
  now() - interval '5 days' AS created_at
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON p.id = oi.product_id AND p.branch = o.branch
JOIN users u ON u.role = 'ADMIN' AND u.is_active = true
WHERE o.status = 'APPROVED'
ORDER BY random()
LIMIT 100;

SELECT 'stok_log total: ' || count(*) FROM stok_log;

-- ============================================================================
-- RINGKASAN
-- ============================================================================
SELECT 'SELESAI' AS status;
SELECT 'branches: ' || count(*) FROM branches
UNION ALL SELECT 'users: ' || count(*) FROM users
UNION ALL SELECT 'products: ' || count(*) FROM products
UNION ALL SELECT 'customers: ' || count(*) FROM customers
UNION ALL SELECT 'orders: ' || count(*) FROM orders
UNION ALL SELECT 'order_items: ' || count(*) FROM order_items
UNION ALL SELECT 'suppliers: ' || count(*) FROM suppliers
UNION ALL SELECT 'bulletins: ' || count(*) FROM bulletins
UNION ALL SELECT 'sales_targets: ' || count(*) FROM sales_targets
UNION ALL SELECT 'area_assignments: ' || count(*) FROM area_assignments
UNION ALL SELECT 'customer_assignments: ' || count(*) FROM customer_assignments
UNION ALL SELECT 'stok_log: ' || count(*) FROM stok_log;
