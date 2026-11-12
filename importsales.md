Rencana: Template Excel Baru Data Penjualan (v2) + Margin, Devisi, Mother SKU

Approved
Tujuan
Mendukung template Excel baru dari manager dengan kolom yang dipakai: Cabang, Penjualan, Kode, Nama Pelanggan, Kode Item, Nama Item, TOTAL, MARGIN, Sales, Supplier, Mother SKU, Devisi, dengan perilaku:

Upload hanya MANAGER global; SUPERVISOR & ADMIN view-only.
Upload ulang bersifat update, bukan duplikat, termasuk saat TOTAL/MARGIN dikoreksi.
Upload hanya menyentuh bulan yang ada di file (file November tidak menghapus September).
Kolom yang tidak ada di file (baris yang dihapus dari sumber) tidak dihapus — sesuai keputusan user: upsert-only.
Metrik UI berbasis margin menggantikan metrik berbasis qty.
Devisi dan Mother SKU menjadi dimensi; Mother SKU jadi kunci produk lintas cabang.
Keputusan User (final)
Topik	Keputusan
File re-upload	Upsert-only (insert/update). Tidak ada delete baris. Scope perubahan alami per (branch, month) dari baris file, jadi bulan lain tidak tersentuh.
Identitas baris	Natural key (Cabang, Penjualan, Kode Pelanggan, Kode Item, Sales, Supplier) + suffix #occurrence karena kombinasi bisa berulang. TOTAL/MARGIN/Devisi/Mother SKU bukan bagian key.
Metrik qty	Diganti metrik margin (Total Margin, Margin %, rata-rata omzet per baris).
Hak upload	Hanya MANAGER global. Endpoint upload menolak role lain (403).
Devisi & Mother SKU	Keduanya dimensi. Produk lintas cabang di-group memakai Mother SKU (fallback Kode Item).
Hapus data	Tombol manager untuk menghapus data per bulan (opsional per cabang), lalu import ulang file yang benar.
Filter periode	Chip Bulanan / 3 Bulan / 6 Bulan / 12 Bulan ke belakang dari bulan yang dipilih.
Ukuran file	Naikkan limit import penjualan ke 70 MB (seeding mulai Januari bisa >50 MB).
Kondisi Kode Saat Ini (hasil scan)
POST /sales-imports/excel memakai require_write_access → ADMIN/SUPERVISOR/MANAGER bisa upload (app/api/endpoints/sales_imports.py:61-66).
Parser alias (app/services/sales_import_service.py:86-148) sudah mengenali cabang, penjualan, kode, nama pelanggan, kode item, nama item, total, sales, supplier; belum ada margin, mother sku, devisi.
Dedupe (app/services/sales_import_keys.py:59-109): tanpa trans_no memakai fingerprint yang memasukkan qty/total/diskon/net/sales/channel → koreksi TOTAL/MARGIN akan membuat baris baru (melanggar kebutuhan).
Upsert membandingkan DATA_FIELDS (sales_import_upsert.py:43-66) dan menaikkan versi hanya untuk (branch, month) yang berubah (sales_import_service.py:860-887).
Ringkasan precomputed (ImportedSalesMonthlySummary) hanya punya qty, revenue, row_count, dan dimensi PRODUCT/SALES/CUSTOMER/CHANNEL (models.py:493-538).
UI Data Penjualan memakai qty untuk KPI & ranking (sales_analytics_models.dart, imported_sales_tab.dart).
ImportedSalesTab di-instantiate tanpa readOnly (dashboard_screen.dart:477-479) → supervisor juga melihat tombol import.
Perubahan yang Direncanakan
1. Skema database (nullable, backward compatible)
imported_sales tambah kolom:

margin BIGINT NULL — margin nominal (Rupiah, boleh negatif)
mother_sku VARCHAR(100) NULL
devisi VARCHAR(100) NULL
updated_at TIMESTAMPTZ NOT NULL DEFAULT now() (untuk audit perubahan baris)
imported_sales_monthly_summary tambah kolom:

margin BIGINT NOT NULL DEFAULT 0
Migrasi idempotent di startup mengikuti pola _ensure_imported_sales_dedupe_key() (app/main.py:97-151):

ALTER TABLE ... ADD COLUMN IF NOT EXISTS ...
Setelah kolom summary margin dibuat, reset imported_sales_summary_state (mis. DELETE FROM imported_sales_summary_state) agar snapshot lama dibangun ulang dengan margin/dimensi baru. Dijalankan hanya pada blok migrasi (sekali).
2. Parser template v2
SALES_FIELD_ALIASES tambah:

margin: margin, margin rp, nilai margin, margin rupiah (guard: alias margin tidak boleh menang untuk header margin %/margin persen, mengikuti pola guard diskon)
mother_sku: mother sku, mothersku, sku induk, kode induk, parent sku
devisi: devisi, divisi, division
Deteksi template:

v2 bila header mengandung margin dan (mother sku atau devisi) dan tidak ada header qty.
Selain itu tetap jalur lama (tidak mengubah perilaku file historis).
Simpan hasil deteksi di SalesRow.key_mode (tidak perlu kolom DB); opsional dikembalikan di response import sebagai template: "v2".
Validasi baris v2:

Wajib: sale_date valid, total_amount ada, identitas item ada (product_kode/product_nama), dan Cabang bisa di-resolve ke kode cabang yang dikenal.
Baris dengan cabang kosong/tidak dikenal → skipped + error baris (bukan disimpan NULL), supaya laporan per cabang tidak bocor.
margin boleh NULL; mother_sku kosong → fallback product_kode saat agregasi (hitung sebagai missing_mother_sku di ringkasan import).
Angka negatif didukung (_to_int harus aman untuk minus).
Sales pada template ini berisi nama entitas/salesman; disimpan di sales_nama (bukan sales_kode).
3. Dedupe v2 (kunci stabil, update bukan duplikat)
Tambah di sales_import_keys.py:

canonical_sales_key_v2(branch, sale_date, customer_kode, product_kode, sales_nama, supplier)
payload = ["v2", branch, sale_date, customer_kode, product_kode, sales_nama, supplier]
Aturan pemilihan key di SalesRow.base_key:

key_mode == "v2" → key v2
ada trans_no → natural key lama (kompatibel)
lainnya → fingerprint lama (kompatibel file historis)
Konsekuensi:

Koreksi TOTAL, MARGIN, Devisi, Mother SKU, nama pelanggan/produk → key sama → update.
Baris identik dalam satu file tetap terpisah via #0, #1, dan cocok satu-per-satu saat re-import.
Pindah cabang/tanggal/customer/item/sales/supplier → dianggap baris baru (disengaja, karena identitas berubah).
DATA_FIELDS tambah margin, mother_sku, devisi; updated_at di-set saat apply_to.

4. Hak akses
Backend:

POST /sales-imports/excel → require_manager_global (helper sudah ada di core/security.py sekitar baris 195; hanya MANAGER dengan branch IS NULL).
GET /sales-imports/version & /summary → require_supervisor_or_manager_global (ADMIN tidak lagi bisa membaca via API; menu memang hanya untuk MANAGER/SUPERVISOR).
Pastikan tidak ada konsumen lain dari endpoint tersebut (hanya ImportedSalesTab).
Frontend:

ImportedSalesTab menerima readOnly; di dashboard_screen.dart kirim readOnly: !provider.isGlobalManager (aman untuk MANAGER cabang).
Saat readOnly: sembunyikan tombol Import Excel, panel import bawah, dan file picker; tampilkan catatan "Hanya manager yang dapat memperbarui data penjualan".
SUPERVISOR tetap bisa lihat semua kartu, filter bulan, dan filter cabang (bila ada).
5. Ringkasan & API
app/services/sales_summary_service.py:

Total: total_margin = coalesce(sum(margin), 0)
Dimensi baru DEVISI.
Dimensi PRODUCT:
key: coalesce(nullif(mother_sku,''), product_kode)
label: max(product_nama) (atau nama non-kosong pertama)
payload menyertakan mother_sku dan product_kode representatif
Dimensi SALES:
key: coalesce(nullif(sales_kode,''), sales_nama) (template v2 hanya punya nama)
label: sales_nama
Dimensi CUSTOMER tetap.
CHANNEL dipertahankan untuk data lama; baris v2 tidak punya channel.
app/api/endpoints/sales_imports.py:

_VALID_SECTIONS tambah devisi.
Response /summary tambah total_margin, by_devisi; tiap item breakdown tambah margin.
Tetap memakai snapshot + version probe (tidak ada perubahan pola caching).
6. UI Data Penjualan
sales_analytics_models.dart:

SalesAnalytics: totalMargin, devisi, item punya margin, marginShare, motherSku.
Helper format margin (termasuk negatif).
imported_sales_tab.dart:

KPI row (4 kartu): Rata-rata omzet/hari aktif, Total Margin, Margin % (margin/omzet), Transaksi.
Insight card: Produk unggulan (omzet), Hari puncak, Devisi dominan (fallback "Kanal dominan" untuk data lama), Momentum 7 hari.
Ranking grid: Produk (group Mother SKU, tampilkan kode item sebagai sub-label), Sales, Pelanggan, Devisi — tiap kartu punya toggle Omzet | Margin.
Card Partisipasi Sales: toggle Omzet/Margin (default Omzet).
Toolbar: tetap Top 10/50, bulan, filter cabang (manager global).
Banner import menampilkan hasil inserted/updated/skipped + peringatan missing_mother_sku.
7. Tes
Backend:

Key v2: TOTAL/MARGIN/Devisi/Mother SKU berubah → key sama; cabang/tanggal/customer/item/sales/supplier berubah → key beda; occurrence #0/#1.
Parser: file contoh v2 (kolom persis seperti daftar user) terdeteksi v2; TOTAL vs TOTAL PPN tidak tertukar; margin negatif; cabang "Banjarmasin"/"Cabang Banjarmasin"; baris cabang kosong → skipped.
Upsert: upload file sama 2× → inserted=0, versi tidak naik; ubah MARGIN → updated + versi naik; ubah TOTAL → tetap baris sama; file November tidak menyentuh September.
Summary: total_margin, by_devisi, grouping produk via Mother SKU lintas cabang, fallback ke product_kode.
Permission: SUPERVISOR/ADMIN POST → 403; SUPERVISOR/ADMIN DELETE month → 403; MANAGER POST/DELETE → 200; SUPERVISOR GET summary → 200; ADMIN GET summary → 403.
Hapus bulan: hapus cabang X bulan Y → hanya baris cabang X bulan Y hilang, bulan lain & cabang lain utuh; deleted benar; versi naik; summary jadi nol; hapus ulang → deleted=0 tanpa bump.
Hapus semua cabang: hanya untuk all_branches=true; tanpa parameter itu → 400.
Range: range_months=3 menjumlahkan 3 bulan terakhir dengan benar (bandingkan dengan SUM raw SQL); range_months=1 hasilnya identik dengan snapshot lama; versi gabungan berubah saat salah satu bulan berubah.
File besar: workbook sintetis 50 ribu baris ter-parse streaming (memori wajar), batch upsert benar, occurrence konsisten antar batch.
Frontend:

ImportedSalesTab readOnly menyembunyikan tombol/panel import dan tombol hapus.
KPI margin, margin %, format negatif.
Ranking toggle Omzet/Margin.
Chip periode mengganti query & judul hero; state provider menyimpan rangeMonths.
Dialog hapus: tombol baru aktif setelah mengetik YYYY-MM; tidak muncul untuk supervisor.
Update test provider untuk payload baru (total_margin, by_devisi, margin, range_months).
8. Dokumentasi & rollout
Update docs/sales-import-dedupe.md: tambah bagian "Template v2", aturan key v2, upsert-only, dan catatan bahwa baris yang hilang dari file tidak dihapus.
Tidak ada backfill wajib: baris lama mother_sku NULL otomatis fallback product_kode saat agregasi.
Snapshot lama dibangun ulang sekali lewat reset state (langkah migrasi).
Uji manual dengan file asli manager: cocokkan Total Omzet & Total Margin dengan pivot Excel.
Setelah deploy, lakukan satu kali import file v2 di staging/lokal lalu cek angka di UI.
9. Hapus data per bulan (manager only)
Backend — endpoint baru:

DELETE /sales-imports/month?month=YYYY-MM&branch=BANJARMASIN
DELETE /sales-imports/month?month=YYYY-MM&all_branches=true
Dependency require_manager_global (hanya MANAGER branch IS NULL).
Salah satu dari branch atau all_branches=true wajib; tanpa itu → 400 (mencegah hapus global tak sengaja).
Hapus imported_sales pada rentang sale_date bulan tersebut (dan branch bila dipilih).
Advisory lock per (scope, month) selama transaksi, sama seperti import, agar tidak balapan dengan upload.
Catat audit: tambah ImportLog(import_type="SALES_DELETE", total_rows=deleted, branch=...); log import lama tidak dihapus.
Bila deleted > 0: bump versi untuk cabang terkait + GLOBAL, lalu recompute snapshot (bulan kosong → semua nol).
Idempotent: hapus ulang bulan kosong → deleted=0, versi tidak naik.
Response: {success, month, branch, all_branches, deleted, versions}.
Frontend:

Tombol Hapus data bulan ini (gaya danger) di samping Import Excel, hanya tampil untuk MANAGER global.
Dialog konfirmasi menampilkan: bulan, cakupan (cabang / semua cabang), jumlah baris dan omzet saat ini, serta wajib mengetik YYYY-MM untuk mengaktifkan tombol hapus.
Setelah sukses: refresh probe versi + summary, tampilkan banner hasil seperti import.
SUPERVISOR tidak melihat tombol (read-only).
10. Chip filter periode (1/3/6/12 bulan)
UI:

Chip group di toolbar: Bulanan | 3 Bulan | 6 Bulan | 12 Bulan (pakai AppChoiceChip yang sudah ada).
Bulan yang dipilih = bulan akhir; rentang = N bulan ke belakang termasuk bulan akhir.
Hero/KPI/ranking memakai total rentang; judul hero menyesuaikan (OMZET 3 BULAN s.d. NOVEMBER 2026).
Tren harian: rentang 90/180/366 titik; label sumbu dijarangkan (per 2 minggu / per bulan) agar tetap terbaca.
Top Produk/Sales/Pelanggan/Devisi dan Partisipasi Sales diagregasi untuk seluruh rentang.
Pilihan chip disimpan di state provider; cache summary dipisah per (bulan, rangeMonths, branch).
Backend:

GET /sales-imports/summary?month=YYYY-MM&range_months=1|3|6|12 (default 1).
range_months=1 → tetap memakai snapshot precomputed (jalur cepat, tidak berubah).
range_months>1 → agregasi exact dari imported_sales untuk rentang tersebut (GROUP BY), memakai index ix_imported_sales_branch_sale_date yang sudah ada. Alasan: snapshot per bulan hanya menyimpan top-100, sehingga penjumlahan snapshot bisa salah untuk produk yang naik peringkat secara agregat.
Response menambah range_months; by_day mencakup seluruh rentang (maks ~366 baris); by_sales_day top 10 sales pada rentang.
GET /sales-imports/version?month=...&range_months=N mengembalikan versi gabungan (jumlah versi tiap bulan dalam rentang) sehingga cache lama otomatis invalid saat salah satu bulan berubah.
Target performa: < 2 detik untuk 12 bulan pada ~500 ribu baris; verifikasi dengan EXPLAIN ANALYZE di lokal sebelum rilis.
Optimasi opsional (bila lambat): cache in-memory TTL 60 detik per (scope, end_month, range, version).
11. Limit file 70 MB + parsing streaming
sales-app/backend/app/api/endpoints/sales_imports.py:42 → MAX_EXCEL_UPLOAD_BYTES = 70 * 1024 * 1024 (endpoint lain tetap 10 MB).
Upload ditulis ke temporary file sambil menghitung ukuran (bukan read() seluruh isi ke memori) agar 70 MB tidak terduplikasi.
Parser .xlsx diubah ke streaming: openpyxl.load_workbook(..., read_only=True, data_only=True), buffer hanya 200 baris pertama untuk deteksi header, lalu iterasi baris per baris (values_only=True). Saat ini _read_xlsx_matrices memuat seluruh workbook ke list-of-list (rawan OOM untuk 500 ribu baris).
Baris divalidasi lalu diakumulasi per batch (5.000 baris) dan di-upsert per batch; penghitung occurrence tetap dibagi seluruh file; bump versi + recompute dilakukan sekali di akhir setelah semua batch sukses.
.xls (xlrd) tidak punya mode streaming: tolak file .xls > 20 MB dengan pesan "simpan ulang sebagai .xlsx".
Frontend: pre-check ukuran file, pesan "Maksimal 70 MB"; progress indeterminate + peringatan bahwa file besar bisa memakan beberapa menit.
Reverse proxy Caddy (deploy/Caddyfile) perlu dinaikkan:
request_body {
    max_size 80MB
}
reverse_proxy api:8000 {
    transport http {
        read_timeout 10m
        write_timeout 10m
    }
}
Uji beban lokal dengan file sintetis ~70 MB / ~300–500 ribu baris: ukur waktu import, puncak memori proses, dan ukuran DB setelah import.
Urutan Implementasi
Migrasi kolom + reset snapshot state.
Refactor parser jadi streaming + temp file upload + limit 70 MB (fondasi seeding besar).
Parser alias + deteksi template v2 + validasi.
Key v2 + DATA_FIELDS + updated_at + upsert batch.
Permission backend (upload & delete = MANAGER global; read = SUPERVISOR/MANAGER).
Endpoint hapus per bulan + audit log + recompute.
Summary service (margin, devisi, mother sku) + response API.
Endpoint range 3/6/12 bulan + version gabungan.
Model & UI analytics frontend: KPI margin, chip periode, ranking Devisi, toggle Omzet/Margin, read-only supervisor, tombol hapus.
Tes backend & frontend.
Dokumentasi (dedupe, batas 70 MB, hapus per bulan) + QA dengan file asli.
Risiko & Catatan
Baris yang dihapus dari sumber tetap ada (konsekuensi upsert-only). Solusinya: tombol hapus per bulan (bagian 9) dipakai sebelum import ulang file yang benar.
Hapus per bulan bersifat permanen dan tidak punya undo; karena itu wajib konfirmasi ketik YYYY-MM dan audit log. Backup DB produksi sebelum seeding Januari.
Range 12 bulan membaca raw rows; pada data sangat besar (>1 juta baris) bisa > 2 detik. Bila perlu, tambahkan cache TTL atau tabel snapshot range.
File 70 MB membutuhkan RAM lebih; parser streaming wajib selesai sebelum limit dinaikkan, kalau tidak worker bisa OOM.
Import besar bersifat sinkron: request bisa berjalan menit-an. Pastikan Caddy timeout dinaikkan dan user tidak menutup tab; pertimbangkan job Async di iterasi berikutnya.
Occurrence bergantung urutan baris identik; secara nilai dampaknya kecil karena key-nya sama.
Mother SKU kosong membuat produk terpecah per kode item; pantau missing_mother_sku di hasil import.
Arti MARGIN diasumsikan nominal Rupiah (bukan persen) berdasarkan file contoh; perlu konfirmasi final dari tim sumber data.
Kolom Sales berisi nama entitas, bukan kode sales orang; label ranking perlu disesuaikan ("Sales / Entitas").
Ambigu kolom TOTAL pada file lebar (TOTAL, TOTAL PPN) ditangani lewat skor exact-match; wajib diuji dengan file asli.
Di Luar Scope
Menghapus/mengganti data historis.
Perubahan pada import produk/supplier atau tab Sinkronisasi.
Perubahan pada data penjualan mobile (sales_web/app mobile).