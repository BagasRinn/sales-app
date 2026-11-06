# Log Uji Backup & Restore

Catatan hasil uji nyata. Jangan menaruh kredensial atau data pelanggan di file ini.

---

## 2026-11-06 — Supabase → PostgreSQL 17 lokal

### Tujuan

Membuktikan dump Supabase bisa direstore ke PostgreSQL 17 bersih dan backend bisa
berjalan terhadap database hasil restore, sebelum migrasi ke VPS.

### Lingkungan

| Item | Detail |
|---|---|
| Sumber | Supabase PostgreSQL 17.11 |
| Koneksi dump | Session pooler port `5432` (bukan transaction pooler `6543`) |
| Metode | `pg_dump --schema=public --format=custom --compress=9 --no-owner --no-privileges` |
| Target restore | Container PostgreSQL 17.11 lokal, database `sales_restore` |
| Tool | Image `public.ecr.aws/supabase/postgres:17.11.0.004` |

### Hasil dump

| Item | Nilai |
|---|---|
| Ukuran dump | **3.043.817 byte (3,04 MB)** |
| SHA-256 | `E75AAF90E920578BAC7EF6F95AA1F41601BF3D2290DF93B7C455068A520BC955` |
| TOC entries | 148 |
| Tabel di dump | 18 |
| Estimasi waktu dump | < 1 menit |

### Hasil restore

| Item | Hasil |
|---|---|
| `pg_restore` | Sukses, exit code 0 |
| Tabel `public` | 18 (sesuai sumber) |
| Kolom | 202 (identik) |
| Index | 55 (identik) |
| Constraint | 41 (identik) |
| Estimasi waktu restore | < 1 menit |

### Verifikasi data

Tabel master cocok persis:

| Tabel | Sumber saat verifikasi | Restore |
|---|---:|---:|
| `users` | 48 | 48 |
| `branches` | 5 | 5 |
| `products` | 8.623 | 8.623 |
| `customers` | 5.324 | 5.324 |
| `customer_assignments` | 9 | 9 |
| `area_assignments` | 30 | 30 |
| `customer_registration_submissions` | 3 | 3 |
| `sync_validation_errors` | 4.082 | 4.082 |
| `import_logs` | 231 | 231 |
| `supplier_targets` | 39 | 39 |
| `suppliers` | 126 | 126 |

Tabel transaksi berbeda dari sumber **live** karena masih ada order baru masuk ke Supabase
selama pengujian. Untuk membuktikan snapshot konsisten, jumlah baris sumber dihitung
sampai waktu maksimum yang ada di hasil restore:

| Pemeriksaan | Sumber | Restore | Cocok |
|---|---:|---:|---|
| `orders` dengan `created_at <= max(restore.orders.created_at)` | 3.599 | 3.599 | Ya |
| `stok_log` dengan `created_at <= max(restore.stok_log.created_at)` | 45.206 | 45.206 | Ya |

Selisih terhadap data live saat verifikasi:

- `orders`: sumber 3.601 vs restore 3.599.
- `order_items`: sumber 11.117 vs restore 11.115.
- `stok_log`: sumber 45.234 vs restore 45.206.

Selisih ini konsisten dengan write baru setelah snapshot dump. Tabel master tidak berubah.

### Temuan data yang sudah ada sebelum migrasi

- Ada **94 `order_items` yang tidak punya order induk** di Supabase. Jumlah yang sama juga
  ada di hasil restore, jadi ini **bukan** akibat proses backup/restore.
- Perlu diselidiki terpisah: kemungkinan order pernah dihapus dengan cara yang melewati
  foreign key, atau data lama diimpor dengan constraint dimatikan.
- Jangan menghapus data ini tanpa konfirmasi, karena bisa memengaruhi laporan/riwayat.

### Temuan schema

- `imported_sales` di produksi **belum** punya kolom `dedupe_key` dan index
  `uq_imported_sales_dedupe_key`, juga belum punya `ix_imported_sales_branch_sale_date`.
- Setelah backend dijalankan terhadap database hasil restore, startup DDL berhasil
  menambahkan:
  - kolom `dedupe_key`,
  - unique index `uq_imported_sales_dedupe_key`,
  - index `ix_imported_sales_branch_sale_date`,
  - tabel `sales_import_versions`,
  - tabel `imported_sales_monthly_summary`,
  - tabel `imported_sales_summary_state`.
- Jumlah tabel `public` berubah dari 18 menjadi 21, sesuai model aplikasi.

### Uji backend terhadap database hasil restore

Backend dijalankan dengan `DATABASE_URL` ke database hasil restore,
`RUN_SCHEDULER=false`, `ENVIRONMENT=development`.

| Endpoint | Hasil |
|---|---|
| `GET /health` | `200 {"status":"healthy"}` |
| `GET /` | `200 {"message":"API Manajemen Order Sales berjalan normal","version":"1.1"}` |
| Branch cache | `Loaded 5 active branches from DB` |

Artinya koneksi SQLAlchemy, startup DDL, dan pembacaan data berjalan normal.

### Kendala saat uji

- Pull image resmi `postgres:17` dan `postgres:17-alpine` macet di tahap ekstraksi layer
  pada Docker Desktop. Solusinya memakai image Supabase yang sudah tersedia
  (`public.ecr.aws/supabase/postgres:17.11.0.004`) yang memiliki `pg_dump`,
  `pg_restore`, dan `psql` versi 17.11.
- Dump menyertakan `CREATE SCHEMA public`, sedangkan database target baru sudah punya
  schema `public`. Solusi:
  - sebagai owner database, jalankan `DROP SCHEMA public CASCADE;` sebelum restore, atau
  - filter entry `SCHEMA - public` dari TOC dan restore dengan `pg_restore -L`.
- Image Supabase memakai role `supabase_admin`, bukan `postgres`. Di VPS nanti gunakan
  role aplikasi yang menjadi owner database (`sales_app`).

### Kesimpulan

- Backup logis Supabase **berhasil** dan dapat direstore ke PostgreSQL 17 bersih.
- Schema dan data master **identik**.
- Backend **berhasil start** dan membaca data dari hasil restore.
- Prosedur ini layak dipakai untuk migrasi ke VPS, dengan tambahan penanganan schema
  `public` dan role database.
- Backup belum dienkripsi dan belum diunggah offsite pada uji ini; untuk produksi wajib
  mengikuti `docs/rencana-backup.md` (enkripsi `age`, upload R2/B2, retensi, monitoring).

### Tindak lanjut

- [ ] Selidiki 94 `order_items` tanpa order induk.
- [ ] Tambahkan penanganan schema `public` ke `restore.sh`.
- [ ] Buat backup terenkripsi + upload offsite pada uji berikutnya.
- [ ] Uji restore penuh ke VPS baru sebagai simulasi disaster recovery.
