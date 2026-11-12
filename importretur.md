Rencana: Import Excel Retur & Omzet/Margin NET

Tujuan
Menambah fitur import file Excel Retur ke halaman Data Penjualan, sehingga:

Omzet dan margin penjualan menjadi NET (penjualan − retur), untuk tiap bulan & scope cabang/Global.
Pengurangan berlaku per dimensi: TOTAL, Produk, Sales, Pelanggan, Devisi, Supplier.
Kartu ranking menampilkan angka net.
Kartu baru Supplier Diretur menampilkan Top 10 supplier berdasarkan nilai retur.
Manager-only import; supervisor read-only.
Retur bisa dihapus per bulan (sebelum import ulang file yang benar).
Bar target (rencana kartu target) memakai omzet realisasi = NET.
Konteks & Keterkaitan
Tiga rencana / pekerjaan sebelumnya harus jalan dulu atau bersamaan karena saling memengaruhi:

sales-import-template-v2 — margin, devisi, mother_sku, upsert, manager-only. Retur menggantung pada pipeline ini.
sales-target-cards — bar target pakai omzet NET.
Retur ini dibangun di atas keduanya.
Urutan implementasi: v2 sales import → kartu target → retur.

File Retur
Kolom yang dipakai (setelah revisi diskusi):

Cabang | Tanggal (retur) | Kode Item | Nama Item | TOTAL | MARGIN | Supplier | Devisi | Mother SKU | Kode Pelanggan | Nama Pelanggan | Sales

TOTAL = nilai retur omzet (bukan jumlah qty).
MARGIN = nilai retur margin.
Tanggal menentukan bulan retur (format sama seperti parser tanggal existing).
Sales = nama sales (mencocokkan format file Data Penjualan, normalisasi nama).
Kode Pelanggan = kunci pelanggan (Nama Pelanggan sebagai label, dinormalisasi).
Tanpa qty.
Keputusan User (final)
Topik	Keputusan
Periode	Per bulan; tanggal di file menentukan bulan target.
Efek ke data	Omzet & margin NET; ranking produk/sales/pelanggan/devisi/supplier semua net; dianggap barang gagal terjual.
Margin retur	Ikut dikurangi (MARGIN ditambahkan ke file).
Cara mengurangi	Kurangi secara agregat (bukan menghapus baris penjualan).
Tampilan	Kartu baru Supplier Diretur: Top 10 supplier by retur, toggle Omzet/Margin, proporsi bar thd total retur, dan % retur dari omzet supplier.
Layout	Baris kedua halaman Data Penjualan: Supplier Teratas dan Supplier Diretur; kartu ranking jadi baris 4 kolom (Produk, Sales, Pelanggan, Devisi).
Ranking retur	Toggle Omzet/Margin; persen dari total retur; % retur dari omzet supplier = retur / (net + retur).
Target bar	NET (realisasi = omzet setelah retur).
Hapus per bulan	Ya; tombol hapus retur per bulan (per cabang / semua cabang), sama mekanisme Data Penjualan.
Kolom tambahan	Kode+Nama Pelanggan dan Sales ditambahkan ke file Retur.
Desain Tabel
imported_returns
id               UUID pk
import_log_id    UUID  FK import_logs
branch           VARCHAR(20)  NULL
sale_date        DATE         NOT NULL
product_kode     VARCHAR(50)  NULL
product_nama     VARCHAR(200) NULL
mother_sku       VARCHAR(100) NULL
devisi           VARCHAR(100) NULL
supplier         VARCHAR(100) NULL
customer_kode    VARCHAR(50)  NULL
customer_nama    VARCHAR(200) NULL
sales_nama       VARCHAR(200) NULL
revenue          BIGINT       NOT NULL   -- TOTAL retur (≥ 0)
margin           BIGINT       NULL
dedupe_key       VARCHAR(64)  NULL
created_at / updated_at      TIMESTAMPTZ
UNIQUE (dedupe_key)                    -- occurrence suffix, sama seperti v2
INDEX (branch, sale_date)
Dedupe v2 style: key = (branch, sale_date, product_kode, customer_kode, sales_nama, supplier) + #occurrence; TOTAL/MARGIN/Devisi/Mother SKU mutable sehingga koreksi = update.
DDL idempotent saat startup (_ensure_* di main.py); kolom margin di imported_returns.
imported_sales_monthly_summary (perluasan kecil)
Tambah dimensi baru RETUR_SUP (per supplier, by retur revenue) + kolom TOTAL:

retur_revenue BIGINT NOT NULL DEFAULT 0
retur_margin  BIGINT NOT NULL DEFAULT 0
retur_rows    BIGINT NOT NULL DEFAULT 0
(semua NULLABLE dengan default 0 → data lama tetap valid)

Strategi agregasi: NET saat recompute
Recompute snapshot setelah import/hapus retur (atau sales), dalam satu transaksi:

Agregasi imported_sales per (scope, month) → TOTAL + dimensi (PRODUCT by coalesce(mother_sku, product_kode), SALES by coalesce(kode, nama), CUSTOMER by kode, DEVISI, SUPPLIER).
Agregasi imported_returns → mengurangi grup yang sama (TOTAL & semua dimensi di atas), serta menambah grup RETUR_SUP.
Persist ke imported_sales_monthly_summary dengan nilai NET.
Keuntungan: seluruh kode read/ranking/KPI tetap polos (sudah NET); ordering top-N benar; tanpa perubahan pada API read selain field tambahan.

API
POST /sales-imports/returns/excel — .xlsx/.xls, 10 MB, MANAGER global only, SUPERVISOR/ADMIN → 403.
Parser alias: date tanggal|tgl|retur|tgl retur; item kode item|kodeitem|item kode; nama nama item|namaitem|nama barang; total total|grand total (exact-match menahan total ppn seperti biasa); margin margin|margin rp; supplier, devisi, mother sku, kode→customer_kode, nama pelanggan→customer_nama, sales|nama sales.
Deteksi template: mengandung margin dan kode item dan tanpa qty; gunakan jalur retur (bukan sales).
Validasi: baris tanpa tanggal/supplier/kode item/pelanggan → skipped + error (maks 50 baris error ditulis).
Upsert per (branch, month) berbasis dedupe_key; occurrence berlanjut dari baris existing.
Audit: ImportLog(import_type="SALES_RETUR", ...).
Response: {success, total_rows, inserted, updated, skipped, errors[], versions[]}.
DELETE /sales-imports/returns/month?month=YYYY-MM&branch=|all_branches=true — MANAGER global; sama dengan hapus penjualan (lock, audit log, bump versi, recompute).
GET /sales-imports/summary:
Semua angka (total_revenue, total_margin, total_qty, semua by_*) otomatis NET.
Tambahan field: total_retur_revenue, total_retur_margin, total_retur_rows, by_supplier_retur (top 10 RETUR_SUP; item: supplier, revenue(retur), margin(retur), row_count).
include=supplier_retur ditambahkan.
Frontend
SalesAnalytics: tambahan totalReturRevenue, totalReturMargin, returRows, supplierRetur (list item retur).
KPI/Hero otomatis NET (tidak ada perubahan wiring).
Ranking Produk/Sales/Pelanggan/Devisi/Supplier otomatis NET.
Kartu baru Supplier Diretur (model _SupplierReturnCard di tab atau SalesRankingList mode retur):
Top 10 supplier by retur; sorted by retur selected metric.
Toggle Omzet | Margin.
Tiap baris: supplier, retur omzet/margin, bar proporsi vs total retur, dan x% retur dari omzet supplier (retur / (net + retur)).
Empty state: "Belum ada retur periode ini" + tombol Import Retur (manager-only).
Toolbar: tombol Import Retur (manager-only, outline) di samping Import Retur/Import Target; dialog konfirmasi hapus retur per bulan (danger, ketik YYYY-MM).
Supervisor: kedua tombol tidak tampil; kartu retur tetap terlihat.
Banner hasil import/hapus mengikuti pola SalesImportBanner.
Matching Detail
Dimensi PRODUCT: sama seperti v2 — key coalesce(mother_sku, product_kode), label max(product_nama) / fallback.
SALES: key coalesce(sales_kode?, sales_nama) → dalam file retur hanya sales_nama → key nama normalized; label max(sales_nama).
CUSTOMER: key customer_kode (dinormalisasi), label max(customer_nama).
DEVISI / SUPPLIER: strings as-is normalized.
Normalisasi nama: collapse space + trim + uppercase (sama dengan kunci sales existing).
Tes
Backend:

Import parse template retur; deteksi retur vs sales; TOTAL vs TOTAL PPN; margin negatif; cabang tidak dikenal → skipped.
Idempotency: file sama 2× → inserted=0, versi tidak naik; ubah MARGIN/TOTAL → updated; pindah supplier → baris baru.
NET correctness: sales 100, retur 30 supplier X → omzet total 70 net; produk/sales/pelanggan/devisi/supplier dikurangi 30; bar target memakai 70.
Hapus retur bulan Y: retur hilang dari NET; bulan lain tidak ikut.
Permission: supervisor upload/delete → 403.
Frontend:

Kartu Supplier Diretur: ranking, toggle, proporsi bar, % dari supplier omzet; empty state; read-only supervisor.
KPI menunjukkan nilai NET; chip periode 3/6/12 bulan meneruskan NET.
Dokumentasi & Migrasi
Update docs/sales-import-dedupe.md / dok internal: format retur, perilaku NET, cara hapus per bulan, penjelasan"% retur dari omzet supplier".
DDL idempotent: imported_returns, kolom margin (import returns), kolom TOTAL snapshot (retur_revenue/margin/rows) + dimensi sepenuhnya backward-compatible (retur=0 untuk snapshot lama; snapshot dibangun ulang otomatis).
Data lama (tanpa retur) tidak perlu backfill; retur pertama memicu rebuild snapshot (transient sedikit).
Risiko & Catatan
Supplier punya omzet NET = 0: bisa menutup total; bukan bug (file retur dianggap benar).
Ordering top-N setelah pengurangan: dijamin karena aggregated setelah retur dikurangi, bukan dari top-N gross.
Nama supplier beda spasi/tanda baca antar file retur dan penjualan → pakai normalisasi yang sama; mismatch dilaporkan pada hasil import (unmatched_suppliers).
Target bar NET: pastikan kartu target mendeklarasikan basis (net) di copy.
Hapus retur permanen; wajib konfirmasi ketik YYYY-MM dan audit log.
Periode: tanggal retur di file wajib valid; baris tanpa tanggal di-skip.
Tidak ada delete/rollback single row; hanya hapus per bulan.
Out of Scope
Menghapus baris penjualan yang terkait retur (we intentionally net, not delete).
Retur berdasarkan row-level join ke transaksi asli.
Retur memengaruhi halaman selain Data Penjualan (mis. Laporan Lintas Cabang, Performa Sales).