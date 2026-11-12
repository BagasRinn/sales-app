-- Update some products to use new suppliers for variety
UPDATE products
SET nama_supplier = 'PT BERKAT SEJATI'
WHERE id LIKE 'PRD-%' AND nama_supplier = 'Supplier Test E2E' AND (random() < 0.3);

UPDATE products
SET nama_supplier = 'CV MITRA ABADI'
WHERE id LIKE 'PRD-%' AND nama_supplier = 'CANDRA FOOD, CV' AND (random() < 0.3);

UPDATE products
SET nama_supplier = 'UD SUKSES MAKMUR'
WHERE id LIKE 'PRD-%' AND nama_supplier = 'UD BERKAH JAYA' AND (random() < 0.3);

UPDATE products
SET nama_supplier = 'CV PRIMA MANDIRI'
WHERE id LIKE 'PRD-%' AND nama_supplier = 'PT MEGA DISTRIBUSI' AND (random() < 0.3);

SELECT nama_supplier, count(*) FROM products GROUP BY nama_supplier ORDER BY nama_supplier;
