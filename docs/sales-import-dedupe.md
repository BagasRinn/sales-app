# Dedupe / Upsert Import Data Penjualan (Fase 3)

Dokumen ini menjelaskan perilaku import laporan penjualan setelah Fase 3:
re-import file yang sama tidak lagi menggandakan baris.

## Kunci dedupe

Setiap baris `imported_sales` punya `dedupe_key` berbentuk:

```
<md5 base>#<occurrence>
```

Bentuk *base key* ditentukan oleh isi baris:

| Kondisi | Base key |
| --- | --- |
| Ada `trans_no` | `(branch, sale_date, trans_no, product_kode)` |
| Tidak ada `trans_no` | fingerprint `(branch, sale_date, customer_kode, product_kode, qty, total_amount, diskon, net_per_unit, sales_kode, channel)` |

Teks dinormalisasi (trim, collapse spasi, uppercase) dan tanggal memakai ISO
`YYYY-MM-DD`, sehingga perbedaan kapitalisasi/spasi antar-export tidak membuat
baris baru.

`occurrence` dimulai dari `0` untuk setiap base di dalam satu file. Baris yang
memang identik dan sah (misalnya dua baris produk yang sama pada satu file)
tetap tersimpan terpisah sebagai `#0` dan `#1`. Saat file yang sama di-import
ulang, urutan occurrence yang sama membuat baris-baris itu cocok satu-per-satu.

## Alur import

1. Parser memvalidasi baris seperti sebelumnya (tanggal wajib, baris kosong
   dilewati).
2. `upsert_sales_rows` mengambil advisory lock per `(branch, month)`.
3. Baris legacy dengan `dedupe_key IS NULL` pada pasangan `(branch, month)`
   yang terdampak diberi key terlebih dahulu (lazy migration).
4. Setiap baris file dihitung key-nya, lalu dicocokkan dengan baris existing.
   - key belum ada → insert (`inserted`).
   - key sudah ada dan ada field data yang berubah → update (`updated`).
   - key sudah ada dan isinya sama → dihitung `updated` tetapi **tidak ada
     write**.
5. Hanya pasangan `(branch, month)` yang benar-benar berubah yang menaikkan
   versi dan membangun ulang snapshot ringkasan.

Konsekuensinya, re-import file yang sama:

- `inserted = 0`, `updated = jumlah baris file`, `skipped` sesuai validasi;
- versi ringkasan **tidak** naik;
- snapshot ringkasan tidak dihitung ulang;
- cache summary di admin_web tetap valid (hanya probe versi yang jalan).

## Legacy dan backfill

Deployment lama belum punya kolom `dedupe_key`. Startup aplikasi menjalankan
DDL idempotent:

```sql
ALTER TABLE imported_sales ADD COLUMN IF NOT EXISTS dedupe_key VARCHAR(64);
CREATE UNIQUE INDEX IF NOT EXISTS uq_imported_sales_dedupe_key
    ON imported_sales (dedupe_key);
```

Baris lama tetap `NULL` (unique index Postgres mengizinkan banyak `NULL`).
Migrasi terjadi otomatis saat import menyentuh `(branch, month)` tersebut.
Untuk memigrasikan semuanya lebih awal:

```bash
cd sales-app/backend
python scripts/backfill_sales_dedupe_keys.py --dry-run
python scripts/backfill_sales_dedupe_keys.py
```

Script aman dijalankan berulang: hanya baris `NULL` yang disentuh, dan
occurrence melanjutkan key yang sudah ada.

## Trade-off yang disengaja

- **Baris identik tetap bisa berdiri sendiri.** Dedupe tidak menghapus baris
  duplikat historis; ia hanya mencegah file yang sama menambah baris baru.
- **Koreksi tanggal dianggap baris baru.** `sale_date` adalah bagian dari key,
  jadi mengubah tanggal pada file akan menghasilkan baris di bulan baru dan
  baris lama tetap ada. Ini konsekuensi dari natural key yang dipilih agar
  transaksi di bulan berbeda tidak saling menimpa.
- **Baris tanpa `trans_no` memakai fingerprint.** Jika laporan aplikasi yang
  sama di-export ulang dengan qty/nominal/diskon yang berubah, baris itu
  dianggap baris baru (tidak ada ID transaksi yang bisa dipakai untuk
  mencocokkan). Perubahan pada kolom deskriptif (nama customer, alamat, nama
  produk) tidak memengaruhi key.
- **Atribusi cabang memengaruhi key.** Global MANAGER yang meng-import file
  tanpa kolom `Cabang` menyimpan baris `branch = NULL`; file yang sama yang
  di-import oleh user cabang akan punya key berbeda karena `branch` berbeda.
- **Tidak ada delete/rollback batch.** Import hanya insert/update; menghapus
  batch import belum termasuk Fase 3.
- **`updated` mencakup baris yang tidak berubah.** Response API tidak punya
  field `unchanged`; baris yang cocok tetapi isinya sama tetap dihitung
  `updated` agar kompatibel dengan UI yang sudah ada.
