Rencana: Progress Bar Target di Kartu Data Penjualan (Sales & Supplier)

Approved
Tujuan
Kartu Sales Teratas dan Supplier Teratas di halaman Data Penjualan menampilkan progress bar target: realisasi omzet vs target omzet, per sales/supplier per bulan.

Sumber target: file Excel target terpisah, bukan bagian file Data Penjualan. Sebuah file berisi dua sheet:

Sheet Target Sales: kolom Cabang | Periode (YYYY-MM) | Sales | Target (omzet)
Sheet Target Supplier: kolom Cabang | Periode (YYYY-MM) | Supplier | Target (omzet)
Kedua sheet dideteksi dari isi header, bukan urutan posisi.

Keputusan User (final)
Topik	Keputusan
Sumber file	File target terpisah dari file Data Penjualan.
Identitas sales	Match by nama sales (normalisasi).
Basis target Sales	Target omzet (revenue).
Target supplier	Per cabang; tampilan GLOBAL menjumlahkan target lintas cabang.
Perilaku import	Upsert; deteksi via header, bukan posisi sheet.
Skema	Tabel dedicated khusus Data Penjualan, karena halaman ini independen dari Performa Sales/Supplier.
Lokasi tombol	Tab Data Penjualan (manager-only), di samping Import Excel.
Target belum ada	Bar tidak digambar; teks kecil Target belum di-set.
Rumus bar	omzet realisasi / target omzet. Jika > 100%: bar penuh, teks menampilkan mis. 120% dari target.
Mode Margin	Bar tetap target omzet; tidak berubah saat toggle Omzet/Margin.
Periode	Kolom Periode (YYYY-MM) di file; satu file bisa mengisi banyak bulan.
Kondisi Kode Terkait
Ranking card ada di imported_sales_tab.dart → SalesRankingList di sales_cards.dart (belum mendukung bar target/target param).
SalesAnalytics.sales / .sales/supplier? — belum ada supplier ranking; perlu dicek by_supplier di summary (kemungkinan perlu ditambahkan, dikonfirmasi saat implementasi; rencana menganggap supplier ranking sudah ada sebagai analytics.suppliers).
Summary endpoint /sales-imports/summary sudah mendukung by_sales/by_product/by_customer/by_devisi; perlu menambah dua blok target (sales_targets, supplier_targets).
Import file handling & alias parser sudah ada (sales_import_service.py); target import baru bisa memakai pola serupa.
MANAGER global only: pakai guard yang sama seperti import Data Penjualan (kerja dilanjutkan dari rencana jadi satu PR).
Perubahan yang Direncanakan
1. Tabel baru: data_penjualan_targets
id              UUID pk
branch          VARCHAR(20)  NOT NULL
period          VARCHAR(7)   NOT NULL        -- YYYY-MM
target_type     VARCHAR(10)  NOT NULL        -- 'SALES' | 'SUPPLIER'
name            VARCHAR(200) NOT NULL        -- tampilan (mis. 'Yusuf Hidayat')
name_key        VARCHAR(200) NOT NULL        -- normalisasi
target_value    BIGINT       NOT NULL        -- omzet target, >= 0
import_log_id   UUID         NULL            -- audit trail
created_at      TIMESTAMPTZ  DEFAULT now()
updated_at      TIMESTAMPTZ  DEFAULT now()
UNIQUE (branch, period, target_type, name_key)
INDEX (branch, period, target_type)
DDL idempotent saat startup (pola _ensure_* di main.py).
name_key = normalisasi: uppercase, &/tanda baca dihapus, spasi collapse (re.sub(r'[^A-Z0-9]+',' ', s)), trim. Fungsi dispesifikasikan ulang di app/services/target_import_service.py (atau sales_import_keys.py bila cocok) — tidak mencampur dengan dedupe lama.
Tujuan: matching "CANDRA FOOD, CV" = "Candra Food CV" = "CANDRA FOOD CV".
2. Parser & import file target
Endpoint baru: POST /sales-imports/targets/excel — require_manager_global, .xlsx/.xls, limit 10 MB.

Alur:

Baca semua sheet dari workbook.
Klasifikasikan sheet lewat header:
SALES bila header mengandung kolom Cabang + salah satu dari Sales|Nama Sales|Salesman + kolom Target + Periode.
SUPPLIER bila Cabang + salah satu dari Supplier|Nama Supplier + Target + Periode.
Skor berbasis exact-match (pola existing); tie → sheet dengan baris data terbanyak.
Jika tidak ada satu pun sheet teridentifikasi → error File target tidak valid: sheet Target Sales / Target Supplier tidak ditemukan.
Alias kolom (dinormalisasi dulu):
cabang|branch|kode cabang
periode|period|bulan|periode yyyy-mm|periode penjualan (nilai: YYYY-MM atau tanggal → ambil tahun+bulan; validasi hasilnya 7 karakter)
sales|nama sales|nama salesman|salesman|entitas
supplier|nama supplier|last supplier|supplier name
target|target omzet|target penjualan|target revenue|nilai target
Validasi per baris: branch di-resolve ke kode cabang terkenal (wajib); period valid; name non-kosong; target_value angka ≥ 0. Baris invalid → skipped + error (maks 50 baris error ditulis).
Upsert per baris oleh (branch, period, target_type, name_key) (INSERT ... ON CONFLICT DO UPDATE atau query + compare): jika target_value berubah → update; sama → tidak ada write.
Audit: 1 ImportLog(import_type="SALES_TARGETS", total_rows, inserted, updated, skipped, file_name).
Response: { success, total_rows, inserted, updated, skipped, errors[], logs:{ sales:{rows, inserted, updated}, supplier:{...} } }.
3. Response API summary
Endpoint /sales-imports/summary (dan dengan range_months>1) menambahkan:

"sales_targets":    [ {name, value} ],   // nama tampilan + target, scope sesuai request
"supplier_targets": [ {name, value} ]
range_months=1: target untuk bulan tersebut.
range_months>1: jumlah target semua bulan dalam rentang (per (branch, target_type, name_key) dijumlahkan).
Scope branch/Global identik dengan scope data.
Tidak menambah query mahal: 2 SELECT terindex kecil.
4. Frontend
Model (sales_analytics_models.dart):

SalesAnalytics tambahan: salesTargets: Map<String, int>, supplierTargets: Map<String, int> (key = name_key).
SalesRankItem tetap sama; target dicocokkan di widget lewat name_key.
Provider: parse sales_targets / supplier_targets; cache ikut (bulan, rangeMonths, branch).

Ranking card (sales_cards.dart):

SalesRankingList menerima Map<String, int>? targets.
Tiap baris: setelah bar omzet yang ada, tambah progress bar target:
track: height 4px, AppRadius.full, warna subtle; fill: lebar clamp(0,1,realisasi/target), warna AppColors.info (normal) / AppColors.success (≥100%).
Teks kecil di bawah: 58% dari target · Rp 2 M / Target belum di-set.
Bar cap 100%; teks menampilkan persen asli.
Card Supplier memakai supplier target yang sama (key = normalized supplier name).
Jika targets null/empty → tidak ada bar (perilaku seperti sekarang).
Toolbar (imported_sales_tab.dart):

Tombol Import Target (outline/secondary) di samping Import Excel; hanya MANAGER global; buka file picker (xlsx/xls).
Setelah import sukses: refresh probe versi + summary; tampilkan banner (pola SalesImportBanner) berisi hasil per sheet.
SUPERVISOR/ADMIN: tombol disembunyikan; bar target tetap tampil.
Toggle Margin: tidak mengubah bar target (selalu omzet vs target omzet). Subtitle kartu tetap Top N berdasarkan omzet.

5. Contoh perilaku yang diharapkan
Yusuf Hidayat omzet Rp 1,16 M, target Rp 2 M → bar 58%, teks 58% dari target · Rp 2 M.
Mujehan Ningsih tidak ada di target file → bar disembunyikan, teks Target belum di-set.
Supplier CANDRA FOOD, CV: di file target tulis Candra Food CV → tetap match lewat normalisasi.
Manager upload file berisi periode 2026-09 s/d 2026-11 dalam satu file → semua bulan terisi; tampilan Februari di-filter manual bulan tersebut.
6. Tes
Backend (tests/test_target_import.py):

Sheet klasifikasi: terbalik (supplier dulu) tetap benar; sheet tanpa header target → error.
Normalisasi nama: CANDRA FOOD, CV = Candra Food CV; Yusuf Hidayat = yusuf hidayat.
Upsert: file sama 2× → inserted=0; target diubah → updated; skipped untuk baris invalid (cabang tidak dikenal, periode salah, target negatif).
Permission: SUPERVISOR/ADMIN upload → 403; MANAGER upload → 200.
Scope target di Global menyusun sum lintas cabang; per cabang hanya miliknya.
Frontend (imported_sales_tab_test.dart):

Ranking render bar target + teks persen; baris tanpa target menampilkan Target belum di-set; toggle Margin tidak mengubah bar; tombol Import Target tidak tampil untuk supervisor.
7. Dokumentasi
docs/data-penjualan-target.md baru: format file target (kolom, contoh), perilaku upsert, normalisasi nama, target per cabang vs Global, cara cek hasil import.
Update README bagian Data Penjualan singkat.
Urutan Implementasi
Tabel data_penjualan_targets + DDL idempotent.
Service target_import_service.py: klasifikasi sheet, alias, normalisasi, validasi, upsert, audit ImportLog.
Endpoint POST /sales-imports/targets/excel + permission.
Summary API: sales_targets/supplier_targets (scope + range).
Frontend: model + provider + SalesRankingList progress bar + tombol Import Target + banner hasil.
Tes backend/frontend; flutter analyze, flutter test, pytest.
Dokumentasi + uji dengan file asli manager.
Risiko & Catatan
Mismatch nama: kalau ejaan di file target beda total (mis. entitas SALESMAN JKT 1 TBK, PT vs Yusuf Hidayat), bar dianggap belum ada. Import response melaporkan jumlah unmatched, dan disarankan import summary menampilkan peringatan untuk dicek.
Supplier target global: menjumlahkan target lintas cabang bisa tampak aneh bila bulan yang berbeda punya target berbeda; tampilan branch-filter menyelesaikan ini.
Periode di file: satu file bisa berisi banyak bulan; salah ketik periode (mis. 2026/11 vs 2026-11) dinormalisasi selama bisa jadi tahun+bulan yang valid.
Over-target diperbolehkan (> 100%); bar cap 100% tapi teks asli.
Redundansi skema: target tidak tersambung ke users/performa — disengaja agar Data Penjualan mandiri.
Tidak ada delete target di scope ini; koreksi lewat re-import (otomatis upsert).
Out of Scope
Target insentif / bonus harian.
Menghubungkan target ini dengan tabel sales_targets lama (Performa Sales) atau supplier_targets (halaman Supplier).
Delete target per bulan.
Validasi target terhadap kesepakatan kontrak.