INSERT INTO suppliers (name, is_active, order_type)
SELECT s.nama, s.is_active, s.order_type
FROM (
  VALUES
    ('PT BERKAT SEJATI', true, 'REGULER'),
    ('CV MITRA ABADI', true, '4P'),
    ('UD SUKSES MAKMUR', true, 'REGULER'),
    ('PT INDAH JAYA', false, 'REGULER'),
    ('CV PRIMA MANDIRI', true, '4P'),
    ('UD TUNGAAL', true, 'REGULER'),
    ('PT SAMUDRA INDAH', false, '4P'),
    ('CV CAHAYA ABADI', true, 'REGULER')
) AS s(nama, is_active, order_type)
WHERE NOT EXISTS (SELECT 1 FROM suppliers sup WHERE sup.name = s.nama);

SELECT * FROM suppliers ORDER BY name;
