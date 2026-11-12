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

### Template v2

Template baru (Cabang, Penjualan, Kode, Nama Pelanggan, Kode Item, Nama Item,
TOTAL, MARGIN, Sales, Supplier, Mother SKU, Devisi) memakai kunci stabil:

```
md5(["v2", branch, sale_date, customer_kode, product_kode, sales_nama, supplier])#occurrence
```

Nilai `TOTAL`, `MARGIN`, nama/deskripsi, Mother SKU, dan Devisi bukan bagian
dari key. Koreksi nilai tersebut memperbarui baris yang sama, bukan membuat
duplikat. `Sales` disimpan sebagai `sales_nama`; margin adalah nominal Rupiah
dan dapat bernilai negatif. Header margin persen tidak dipetakan sebagai
margin nominal. Template v2 wajib berisi tanggal, TOTAL, identitas produk, dan
cabang yang dikenali.

Upload v2 diterima hanya dari MANAGER global. SUPERVISOR dapat membaca
dashboard, tetapi tidak dapat mengunggah atau menghapus data.

## Import retur dan omzet NET

MANAGER global mengunggah laporan retur melalui `POST
/sales-imports/returns/excel` (`.xlsx`/`.xls`, maksimal 10 MB). Kolom yang
digunakan adalah Cabang, Tanggal Retur, Kode Item, Nama Item, TOTAL, MARGIN,
Supplier, Devisi, Mother SKU, Kode Pelanggan, Nama Pelanggan, dan Sales.
`TOTAL` harus berupa nilai retur nonnegatif; `TOTAL PPN` tidak dipakai.
`MARGIN` boleh negatif. Cabang harus dikenal, sedangkan tanggal, kode item,
supplier, dan kode pelanggan wajib ada. Baris tidak valid dilewati dan
dilaporkan pada hasil import.

Identitas retur memakai `(branch, sale_date, product_kode, customer_kode,
sales_nama, supplier)` ditambah suffix occurrence. TOTAL, MARGIN, nama,
Mother SKU, dan Devisi dapat dikoreksi melalui upload ulang tanpa
menggandakan retur. Mengganti supplier membentuk identitas baru. Supplier yang
tidak ditemukan pada penjualan di cabang/bulan yang sama dicantumkan pada
`unmatched_suppliers`.

Snapshot Data Penjualan mengurangi TOTAL dan MARGIN retur secara agregat
sebelum menghitung total, dimensi Produk, Sales, Pelanggan, Devisi, Supplier,
tren harian, dan top-N. Qty serta jumlah baris penjualan tetap berasal dari
laporan penjualan. Kartu Supplier Diretur menampilkan 10 supplier teratas,
dapat diurutkan menurut omzet atau margin retur, dan menghitung persentase
retur dari omzet kotor supplier sebagai `retur / (omzet NET + retur)`.
Target omzet menggunakan angka NET yang sama.

Retur dapat dihapus permanen melalui
`DELETE /sales-imports/returns/month?month=YYYY-MM&branch=KODE` atau dengan
`all_branches=true`. Penghapusan hanya untuk bulan yang dipilih, tercatat di
`import_logs` sebagai `SALES_RETUR_DELETE`, menaikkan versi ringkasan bila
ada baris yang dihapus, dan membangun ulang snapshot dalam transaksi yang
sama. Di dashboard, konfirmasi membutuhkan ketikan `YYYY-MM`.

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
- file diproses upsert-only: baris yang tidak ada pada upload ulang **tidak
  dihapus**, dan bulan yang tidak ada di file tidak berubah.

Untuk mengganti seluruh data satu bulan, MANAGER global dapat menghapus data
bulan (opsional per cabang) terlebih dahulu, lalu mengimpor ulang file yang
benar. Penghapusan permanen dicatat pada `import_logs` sebagai
`SALES_DELETE`; konfirmasi dilakukan dengan mengetik `YYYY-MM`.

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

Startup juga membuat tabel `imported_returns`, indeks dedupe dan
`(branch, sale_date)`, serta kolom ringkasan retur dengan default 0. Penambahan
kolom snapshot menginvalidasi state lama satu kali agar ringkasan dibangun
ulang dengan angka NET; data penjualan historis tidak perlu di-backfill.

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
- **Tidak ada delete saat upload.** File yang lebih kecil tidak menghapus
  baris lama; gunakan penghapusan terkonfirmasi per bulan bila memang ingin
  mengganti seluruh bulan.
- **`updated` mencakup baris yang tidak berubah.** Response API tidak punya
  field `unchanged`; baris yang cocok tetapi isinya sama tetap dihitung
  `updated` agar kompatibel dengan UI yang sudah ada.

## Template v2, margin, dan dimensi

Kolom `margin`, `mother_sku`, `devisi`, dan `updated_at` ditambahkan secara
idempotent saat startup. Snapshot bulanan lama diinvalidasi satu kali saat
kolom margin/dimensi snapshot tersedia, lalu dibangun ulang secara lazy.
Mother SKU dipakai untuk mengelompokkan produk lintas cabang; jika kosong,
agregasi memakai Kode Item. Data historis yang belum memiliki Mother SKU tetap
dapat dibaca tanpa backfill.

Ringkasan dapat diminta untuk 1, 3, 6, atau 12 bulan yang berakhir pada bulan
pilihan. Satu bulan tetap memakai snapshot; rentang lebih panjang diagregasi
langsung dari baris sumber agar top-N gabungan tetap tepat.

## Batas upload

`.xlsx` diproses dengan reader read-only dan batch upsert 5.000 baris; upload
ditulis ke file sementara dan dibatasi 70 MB. `.xls` dibatasi 20 MB karena
reader legacy memuat workbook ke memori. Proxy Caddy menerima request hingga
80 MB dan memberi waktu 10 menit untuk transfer/import.
