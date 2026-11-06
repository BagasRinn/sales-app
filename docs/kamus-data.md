# Kamus Data

Kamus data berikut disusun berdasarkan model basis data pada codebase (`sales-app/backend/app/models/models.py`). Tipe data mengikuti PostgreSQL. Singkatan: **PK** = *primary key*, **FK** = *foreign key*, **NULL** = boleh kosong.

## Daftar Tabel dan Deskripsi

| No | Nama Tabel | Deskripsi |
|---:|---|---|
| 1 | `branches` | Data master cabang sebagai acuan pembatasan data antarcabang. |
| 2 | `users` | Akun pengguna beserta role dan cabangnya. |
| 3 | `products` | Data master produk per cabang beserta informasi harga dan stok. |
| 4 | `customers` | Data master customer/toko per cabang. |
| 5 | `suppliers` | Data master supplier beserta status aktif dan tipe order. |
| 6 | `orders` | Data header order yang dibuat sales. |
| 7 | `order_items` | Rincian produk, qty, diskon, dan up price pada setiap order. |
| 8 | `stok_log` | Riwayat perubahan stok sebagai audit trail. |
| 9 | `customer_assignments` | Penugasan customer tertentu kepada sales. |
| 10 | `area_assignments` | Penugasan area/rayon kepada sales. |
| 11 | `customer_registration_submissions` | Pengajuan customer baru dari sales beserta status persetujuannya. |
| 12 | `sales_targets` | Target penjualan dan insentif per sales per periode. |
| 13 | `supplier_targets` | Target penjualan per supplier per cabang per periode. |
| 14 | `bulletins` | Pengumuman/bulletin untuk sales, global atau per cabang. |
| 15 | `bulletin_dismisses` | Riwayat bulletin yang sudah ditutup oleh sales. |
| 16 | `import_logs` | Riwayat proses impor data dari file Excel. |
| 17 | `sync_validation_errors` | Detail baris yang gagal divalidasi saat impor. |

## Tabel 3.1 `branches`

**Deskripsi:** Menyimpan data master cabang sebagai acuan pembatasan data (*branch scoping*) pada pengguna, produk, customer, order, dan data operasional lainnya.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | code | VARCHAR(20) | PK; kode unik cabang, misalnya `BANJARMASIN`. |
| 2 | nama | VARCHAR(100) | Nama cabang yang ditampilkan pada aplikasi. |
| 3 | is_active | BOOLEAN | Status aktif cabang; default `TRUE`. |
| 4 | created_at | TIMESTAMPTZ | Waktu data dibuat; default `CURRENT_TIMESTAMP`. |
| 5 | updated_at | TIMESTAMPTZ | Waktu data terakhir diubah. |

## Tabel 3.2 `users`

**Deskripsi:** Menyimpan akun pengguna beserta role dan cabangnya untuk kebutuhan autentikasi dan otorisasi.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | id | UUID | PK; ID unik pengguna. |
| 2 | username | VARCHAR(50) | Username untuk login; unik. |
| 3 | password_hash | VARCHAR | Password yang sudah di-hash. |
| 4 | role | VARCHAR(10) | Peran pengguna: `ADMIN`, `SUPERVISOR`, `MANAGER`, atau `SALES`. |
| 5 | nama | VARCHAR(100) | Nama lengkap pengguna. |
| 6 | branch | VARCHAR(20) | FK ke `branches.code`; `NULL` untuk MANAGER global. |
| 7 | is_active | BOOLEAN | Status aktif akun; default `TRUE`. |
| 8 | token_version | INTEGER | Versi token JWT; dinaikkan agar token lama tidak berlaku. |
| 9 | created_at | TIMESTAMPTZ | Waktu data dibuat. |
| 10 | updated_at | TIMESTAMPTZ | Waktu data terakhir diubah. |
| 11 | deleted_at | TIMESTAMPTZ | Soft delete; `NULL` berarti akun belum dihapus. |

## Tabel 3.3 `products`

**Deskripsi:** Menyimpan data master produk per cabang, termasuk harga, stok sistem, stok booking, stok diterima, serta tipe order.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | id | VARCHAR | PK komposit bersama `branch`; kode/SKU produk. |
| 2 | branch | VARCHAR(20) | PK komposit; FK ke `branches.code`; memungkinkan SKU sama di cabang berbeda. |
| 3 | nama_barang | VARCHAR | Nama produk. |
| 4 | harga | INTEGER | Harga jual satuan dalam rupiah. |
| 5 | stok_sistem | INTEGER | Stok fisik menurut data master; default `0`. |
| 6 | stok_booking | INTEGER | Stok yang ditahan order berstatus DRAFT/PENDING; default `0`. |
| 7 | stok_diterima | INTEGER | Jumlah stok yang sudah di-approve; default `0`. |
| 8 | kategori | VARCHAR | Kategori produk. |
| 9 | satuan | VARCHAR | Satuan produk, misalnya pcs atau dus. |
| 10 | nama_supplier | VARCHAR | Nama supplier; mengacu pada `suppliers.name`. |
| 11 | order_type | VARCHAR(10) | Tipe order produk: `REGULER` atau `4P`; default `REGULER`. |

## Tabel 3.4 `customers`

**Deskripsi:** Menyimpan data master customer/toko per cabang, termasuk kode, area, dan alamat.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | id | UUID | PK; ID unik customer. |
| 2 | branch | VARCHAR(20) | FK ke `branches.code`; cabang customer. |
| 3 | kode | VARCHAR(50) | Kode customer; unik bersama `branch` dan `kode_area`. |
| 4 | nama_toko | VARCHAR(200) | Nama toko/customer. |
| 5 | alamat | VARCHAR(500) | Alamat customer. |
| 6 | kode_area | VARCHAR(50) | Kode area/rayon customer; dipakai untuk cakupan sales. |
| 7 | created_at | TIMESTAMPTZ | Waktu data dibuat. |
| 8 | updated_at | TIMESTAMPTZ | Waktu data terakhir diubah. |
| 9 | deleted_at | TIMESTAMPTZ | Soft delete; `NULL` berarti customer belum dihapus. |

## Tabel 3.5 `suppliers`

**Deskripsi:** Menyimpan data master supplier beserta status aktif dan tipe order yang digunakan produk.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | name | VARCHAR | PK; nama supplier dan menjadi acuan `products.nama_supplier`. |
| 2 | is_active | BOOLEAN | Status aktif supplier; default `TRUE`. |
| 3 | order_type | VARCHAR(10) | Tipe order supplier: `REGULER` atau `4P`; default `REGULER`. |
| 4 | created_at | TIMESTAMPTZ | Waktu data dibuat. |
| 5 | updated_at | TIMESTAMPTZ | Waktu data terakhir diubah. |

## Tabel 3.6 `orders`

**Deskripsi:** Menyimpan data header order yang dibuat sales, termasuk status, tipe order, data toko, diskon, dan informasi invoice.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | id | UUID | PK; ID unik order. |
| 2 | branch | VARCHAR(20) | FK ke `branches.code`; cabang order. |
| 3 | sales_id | UUID | FK ke `users.id`; sales pembuat order. |
| 4 | customer_id | UUID | FK ke `customers.id`; `NULL` jika order memakai data toko manual. |
| 5 | status | VARCHAR(20) | Status order: `DRAFT`, `PENDING`, `APPROVED`, `REJECTED`, atau `CANCELLED`; default `DRAFT`. |
| 6 | notes | VARCHAR(1000) | Catatan tambahan dari sales. |
| 7 | created_at | TIMESTAMPTZ | Waktu order dibuat. |
| 8 | store_name | VARCHAR(200) | Snapshot nama toko saat order dibuat. |
| 9 | store_contact | VARCHAR(50) | Snapshot kontak toko. |
| 10 | store_address | VARCHAR(500) | Snapshot alamat toko. |
| 11 | order_type | VARCHAR(10) | Tipe order: `REGULER` atau `4P`; default `REGULER`. |
| 12 | cancelled_items | JSON | Daftar item yang dibatalkan admin beserta alasannya. |
| 13 | reject_reason | TEXT | Alasan order ditolak. |
| 14 | invoice_number | VARCHAR(50) | Nomor invoice untuk pelacakan order. |
| 15 | client_request_id | VARCHAR(128) | Kunci idempotensi untuk mencegah order ganda. |
| 16 | order_discount_type | VARCHAR(10) | Jenis diskon tingkat order: `PERCENT` atau `NOMINAL`; default `PERCENT`. |
| 17 | order_discount_nominal | INTEGER | Nilai diskon tingkat order; default `0`. |
| 18 | order_up_price_type | VARCHAR(10) | Jenis up price: `PERCENT` atau `NOMINAL`; default `NOMINAL`. |
| 19 | order_up_price_nominal | INTEGER | Nilai up price tingkat order; default `0`. |

## Tabel 3.7 `order_items`

**Deskripsi:** Menyimpan rincian produk pada setiap order, termasuk qty, diskon bertingkat, dan up price.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | id | UUID | PK; ID unik item order. |
| 2 | order_id | UUID | FK ke `orders.id`; order induk. |
| 3 | product_id | VARCHAR | Bagian FK komposit ke `products.id`. |
| 4 | branch | VARCHAR(20) | Bagian FK komposit ke `products.branch`; cabang item. |
| 5 | qty | INTEGER | Jumlah produk yang dipesan. |
| 6 | discount_percent | NUMERIC(10,4) | Diskon lapis pertama dalam persen; default `0`. |
| 7 | discount_type | VARCHAR(10) | Jenis diskon lapis pertama: `PERCENT` atau `NOMINAL`; default `PERCENT`. |
| 8 | discount_nominal | INTEGER | Nilai diskon nominal lapis pertama; default `0`. |
| 9 | discount2_type | VARCHAR(10) | Jenis diskon lapis kedua; default `PERCENT`. |
| 10 | discount2_percent | NUMERIC(10,4) | Diskon lapis kedua dalam persen; default `0`. |
| 11 | discount2_nominal | INTEGER | Diskon nominal lapis kedua; default `0`. |
| 12 | discount3_type | VARCHAR(10) | Jenis diskon lapis ketiga; default `PERCENT`. |
| 13 | discount3_percent | NUMERIC(10,4) | Diskon lapis ketiga dalam persen; default `0`. |
| 14 | discount3_nominal | INTEGER | Diskon nominal lapis ketiga; default `0`. |
| 15 | up_price_type | VARCHAR(10) | Jenis up price per item: `PERCENT` atau `NOMINAL`; default `NOMINAL`. |
| 16 | up_price_percent | NUMERIC(10,4) | Up price dalam persen; default `0`. |
| 17 | up_price_nominal | INTEGER | Up price nominal per satuan; default `0`. |

## Tabel 3.8 `stok_log`

**Deskripsi:** Menyimpan riwayat perubahan stok produk sebagai audit trail, baik akibat order, import, maupun perubahan manual.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | id | UUID | PK; ID unik log stok. |
| 2 | branch | VARCHAR(20) | FK ke `branches.code`; cabang produk. |
| 3 | product_id | VARCHAR | Bagian FK komposit ke `products.id`. |
| 4 | sumber | VARCHAR(20) | Asal perubahan stok, misalnya `DRAFT`, `APPROVE`, `REJECT`, `CANCEL`, atau `IMPORT`. |
| 5 | field_terdampak | VARCHAR(20) | Kolom stok yang berubah: `stok_booking` atau `stok_diterima`. |
| 6 | delta | INTEGER | Nilai perubahan stok, positif atau negatif. |
| 7 | nilai_sebelum | INTEGER | Nilai stok sebelum perubahan. |
| 8 | nilai_sesudah | INTEGER | Nilai stok setelah perubahan. |
| 9 | actor_id | UUID | FK ke `users.id`; pengguna yang melakukan perubahan. |
| 10 | order_id | UUID | FK ke `orders.id`; order yang menyebabkan perubahan; `NULL` jika order dihapus. |
| 11 | created_at | TIMESTAMPTZ | Waktu perubahan stok dicatat. |

## Tabel 3.9 `customer_assignments`

**Deskripsi:** Menyimpan penugasan customer tertentu kepada sales; digunakan untuk mengatur customer mana yang dapat diakses sales.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | customer_id | UUID | PK komposit; FK ke `customers.id`; customer yang ditugaskan. |
| 2 | sales_id | UUID | PK komposit; FK ke `users.id`; sales yang menerima penugasan. |
| 3 | assigned_at | TIMESTAMPTZ | Waktu penugasan dibuat; default `CURRENT_TIMESTAMP`. |
| 4 | assigned_by | UUID | FK ke `users.id`; pengguna yang melakukan penugasan. |

## Tabel 3.10 `area_assignments`

**Deskripsi:** Menyimpan penugasan area/rayon kepada sales; customer dengan kode area yang sama otomatis masuk cakupan sales.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | kode_area | VARCHAR(50) | PK komposit; kode area/rayon yang ditugaskan. |
| 2 | sales_id | UUID | PK komposit; FK ke `users.id`; sales yang ditugaskan. |
| 3 | branch | VARCHAR(20) | PK komposit; FK ke `branches.code`; cabang area. |
| 4 | assigned_at | TIMESTAMPTZ | Waktu penugasan dibuat; default `CURRENT_TIMESTAMP`. |
| 5 | assigned_by | UUID | FK ke `users.id`; pengguna yang melakukan penugasan. |

## Tabel 3.11 `customer_registration_submissions`

**Deskripsi:** Menyimpan pengajuan customer baru dari sales beserta data calon customer dan status persetujuannya.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | id | UUID | PK; ID unik pengajuan customer. |
| 2 | branch | VARCHAR(20) | FK ke `branches.code`; cabang pengajuan. |
| 3 | sales_id | UUID | FK ke `users.id`; sales yang mengajukan. |
| 4 | status | VARCHAR(20) | Status pengajuan: `PENDING`, `APPROVED`, atau `REJECTED`; default `PENDING`. |
| 5 | reject_reason | TEXT | Alasan penolakan pengajuan. |
| 6 | approved_customer_id | UUID | FK ke `customers.id`; customer hasil persetujuan. |
| 7 | bareng_customer_id | UUID | FK ke `customers.id`; customer yang langsung dibuat saat pengajuan. |
| 8 | reviewed_by | UUID | FK ke `users.id`; pengguna yang memeriksa pengajuan. |
| 9 | reviewed_at | TIMESTAMPTZ | Waktu pengajuan diperiksa. |
| 10 | created_at | TIMESTAMPTZ | Waktu pengajuan dibuat. |
| 11 | updated_at | TIMESTAMPTZ | Waktu pengajuan terakhir diubah. |
| 12 | nama_langganan | VARCHAR(200) | Nama langganan/toko calon customer. |
| 13 | nomor_id_ktp | VARCHAR(50) | Nomor KTP pemilik. |
| 14 | alamat_ktp | TEXT | Alamat sesuai KTP. |
| 15 | nama_kontak_pemilik | VARCHAR(200) | Nama kontak pemilik. |
| 16 | telpon_hp | VARCHAR(50) | Nomor telepon/HP. |
| 17 | alamat_kirim | TEXT | Alamat pengiriman. |
| 18 | propinsi | VARCHAR(100) | Provinsi customer. |
| 19 | kecamatan | VARCHAR(100) | Kecamatan customer. |
| 20 | kota | VARCHAR(100) | Kota customer. |
| 21 | kelurahan | VARCHAR(100) | Kelurahan customer. |
| 22 | area_route | VARCHAR(100) | Rute/area kunjungan sales. |
| 23 | kode_area | VARCHAR(50) | Kode area calon customer; disalin ke `customers.kode_area` saat disetujui. |
| 24 | tipe_langganan | VARCHAR(50) | Tipe langganan customer. |
| 25 | tipe_pembayaran | VARCHAR(20) | Tipe pembayaran, misalnya tunai atau kredit. |
| 26 | nama_pasar | VARCHAR(200) | Nama pasar lokasi customer. |
| 27 | jangka_kredit_hari | INTEGER | Jangka waktu kredit dalam hari. |
| 28 | batas_kredit_rupiah | BIGINT | Batas kredit dalam rupiah. |
| 29 | channel_kategori | VARCHAR(50) | Channel/kategori customer. |
| 30 | key_account_ref_id | VARCHAR(50) | Referensi key account. |
| 31 | cluster_langganan | VARCHAR(100) | Cluster langganan. |
| 32 | kode_salesman | VARCHAR(50) | Kode salesman. |
| 33 | nama_salesman | VARCHAR(200) | Nama salesman. |
| 34 | siklus_kunjungan | VARCHAR(100) | Siklus kunjungan sales. |
| 35 | hari_kunjungan | VARCHAR(50) | Hari kunjungan sales. |

## Tabel 3.12 `sales_targets`

**Deskripsi:** Menyimpan target penjualan dan insentif per sales per periode.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | id | UUID | PK; ID unik target sales. |
| 2 | user_id | UUID | FK ke `users.id`; sales yang memiliki target; unik bersama `period`. |
| 3 | period | VARCHAR(7) | Periode target dalam format `YYYY-MM`. |
| 4 | target_type | VARCHAR(20) | Jenis target: `ORDER_COUNT` atau `REVENUE`; default `ORDER_COUNT`. |
| 5 | target_value | BIGINT | Nilai target sesuai jenisnya. |
| 6 | incentive_amount | BIGINT | Bonus bila target tercapai. |
| 7 | created_at | TIMESTAMPTZ | Waktu data dibuat. |
| 8 | updated_at | TIMESTAMPTZ | Waktu data terakhir diubah. |

## Tabel 3.13 `supplier_targets`

**Deskripsi:** Menyimpan target penjualan per supplier per cabang per periode.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | id | UUID | PK; ID unik target supplier. |
| 2 | branch | VARCHAR(20) | FK ke `branches.code`; cabang target. |
| 3 | supplier_name | VARCHAR | Nama supplier; mengacu pada `suppliers.name`; unik bersama `branch` dan `period`. |
| 4 | period | VARCHAR(7) | Periode target dalam format `YYYY-MM`. |
| 5 | target_value | BIGINT | Nilai target penjualan supplier. |
| 6 | created_at | TIMESTAMPTZ | Waktu data dibuat. |
| 7 | updated_at | TIMESTAMPTZ | Waktu data terakhir diubah. |

## Tabel 3.14 `bulletins`

**Deskripsi:** Menyimpan pengumuman/bulletin yang ditampilkan ke sales, dapat bersifat global atau per cabang.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | id | UUID | PK; ID unik bulletin. |
| 2 | branch | VARCHAR(20) | FK ke `branches.code`; `NULL` berarti bulletin global. |
| 3 | title | VARCHAR(200) | Judul bulletin. |
| 4 | description | TEXT | Isi/deskripsi bulletin. |
| 5 | pdf_url | VARCHAR(500) | URL file PDF bulletin. |
| 6 | expire_at | TIMESTAMPTZ | Batas waktu tampil; `NULL` berarti tidak kedaluwarsa. |
| 7 | created_at | TIMESTAMPTZ | Waktu data dibuat. |
| 8 | updated_at | TIMESTAMPTZ | Waktu data terakhir diubah. |

## Tabel 3.15 `bulletin_dismisses`

**Deskripsi:** Menyimpan riwayat bulletin yang telah ditutup/dismiss oleh masing-masing sales.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | id | UUID | PK; ID unik riwayat dismiss. |
| 2 | bulletin_id | UUID | FK ke `bulletins.id`; bulletin yang ditutup; unik bersama `sales_id`. |
| 3 | sales_id | UUID | FK ke `users.id`; sales yang menutup bulletin. |
| 4 | dismissed_at | TIMESTAMPTZ | Waktu bulletin ditutup; default `CURRENT_TIMESTAMP`. |

## Tabel 3.16 `import_logs`

**Deskripsi:** Menyimpan riwayat proses impor data dari file Excel, termasuk jenis impor, jumlah baris, dan hasilnya.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | id | UUID | PK; ID unik proses impor. |
| 2 | user_id | VARCHAR | ID pengguna pelaksana impor. |
| 3 | nama | VARCHAR | Nama pengguna pelaksana impor. |
| 4 | import_type | VARCHAR | Jenis impor: `PRODUCT`, `CUSTOMER`, atau `SALES`; default `PRODUCT`. |
| 5 | total_rows | INTEGER | Jumlah baris yang diproses; default `0`. |
| 6 | inserted | INTEGER | Jumlah baris baru yang berhasil disimpan; default `0`. |
| 7 | updated | INTEGER | Jumlah baris yang diperbarui; default `0`. |
| 8 | skipped | INTEGER | Jumlah baris yang dilewati; default `0`. |
| 9 | file_name | VARCHAR | Nama file Excel yang diimpor. |
| 10 | branch | VARCHAR(20) | FK ke `branches.code`; cabang pelaksana impor; `NULL` untuk log lama. |
| 11 | created_at | TIMESTAMPTZ | Waktu proses impor dijalankan. |

## Tabel 3.17 `sync_validation_errors`

**Deskripsi:** Menyimpan detail baris yang gagal divalidasi saat proses impor, sehingga admin dapat menelusuri penyebabnya.

| No | Nama Field | Tipe Data | Keterangan |
|---:|---|---|---|
| 1 | id | UUID | PK; ID unik error validasi. |
| 2 | import_log_id | UUID | FK ke `import_logs.id`; proses impor terkait. |
| 3 | row_number | INTEGER | Nomor baris pada file Excel. |
| 4 | sku | VARCHAR | Kode produk yang bermasalah. |
| 5 | reason | VARCHAR(255) | Alasan baris tersebut tidak valid. |
| 6 | created_at | TIMESTAMPTZ | Waktu error dicatat. |
