-- Step 1: Cek berapa order per customer di setiap pasangan duplikat
-- Tampilkan per (branch, kode) — customer mana yang punya order, mana yang tidak
SELECT
    c.branch,
    c.kode,
    c.id,
    c.nama_toko,
    c.created_at,
    COUNT(o.id) AS order_count
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
WHERE c.kode IN (
    SELECT kode FROM customers GROUP BY branch, kode HAVING COUNT(*) > 1
)
GROUP BY c.branch, c.kode, c.id, c.nama_toko, c.created_at
ORDER BY c.branch, c.kode, COUNT(o.id) DESC, c.created_at DESC;
