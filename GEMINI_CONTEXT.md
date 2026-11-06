# SISTEM INFORMASI MANAJEMEN ORDER SALES - Konteks Lengkap untuk Gemini


## 1. RINGKASAN SISTEM
Nama: Aplikasi Manajemen Order Sales. Sistem order sales mandiri (standalone) untuk sales di lapangan. Semua transaksi ONLINE ke API; tidak ada mode offline. Versi API: 1.1.

Komponen:
- Backend API: Python FastAPI + SQLAlchemy 2 + PostgreSQL (Linux/Docker/Railway)
- Mobile Sales: Flutter (Dart ^3.12.1) - Android, iOS, Windows
- Sales Web: Flutter Web (browser)
- Admin Web: Flutter Web (browser)
- Paket bersama: datetime_utils (Dart) - dipakai ketiga klien

Arsitektur 3 lapisan:
1. Client Layer: Mobile Sales, Sales Web, Admin Web
2. Service/API Layer: FastAPI backend (port 8000)
3. Data Layer: PostgreSQL + Berkas Excel (.xlsx) untuk impor

Alur komunikasi: Klien -> REST API (JWT) -> FastAPI -> SQLAlchemy -> PostgreSQL
Semua request autentikasi memakai JWT Bearer token (access token 30 menit, refresh token 7 hari).

## 2. TEKNOLOGI
Backend (Python): FastAPI 0.141.1, SQLAlchemy 2.0.51, psycopg 3.2.3, Pydantic 2.13.4, PyJWT 2.13.0, bcrypt 5.0.0, Uvicorn 0.52.1, APScheduler 3.11.3, python-multipart, openpyxl 3.1.5, boto3 1.43.114, python-dotenv
Frontend (Flutter/Dart): provider 6.1.2, http 1.2.2, dio 5.8.0, flutter_secure_storage 9.2.2, intl 0.20.2, file_picker 8.1.6, web 1.1.0
Infrastructure: Docker, Railway.app, PostgreSQL, Git

## 3. MODEL DATABASE (SQLAlchemy)
Semua tabel menggunakan branch scoping (kolom branch = kode cabang) untuk multi-tenansi antar cabang.

User (users): id (UUID PK), username (unique), password_hash, role (ADMIN/SUPERVISOR/MANAGER/SALES), nama, branch (NULL=MANAGER global), is_active, token_version, created_at/updated_at/deleted_at

Branch (branches): code (PK, contoh: BANJARMASIN/BATULICIN/BARABAI/PALANGKARAYA/SAMPIT), nama, is_active

Product (products) - Composite PK: (id, branch): id (SKU), branch, nama barang, harga, stok_sistem, stok_booking, stok_diterima, kategori, satuan, nama_supplier, order_type (REGULER/4P)
Rumus stok_tersedia = max(0, stok_sistem - stok_booking - stok_diterima)

Customer (customers) - Composite PK: (branch, kode, kode_area): id (UUID), branch, kode, nama_toko, alamat, kode_area, deleted_at

Order (orders): id (UUID), branch, sales_id, customer_id, status (DRAFT/PENDING/APPROVED/REJECTED/CANCELLED), notes, order_type, cancelled_items (JSON), reject_reason, invoice_number, client_request_id (idempotency), order_discount_type/nominal, order_up_price_type/nominal

OrderItem (order_items): id (UUID), order_id, product_id, branch, qty, discount_type/percent/nominal (Layer 1), discount2_type/percent/nominal (Layer 2), discount3_type/percent/nominal (Layer 3), up_price_type/percent/nominal

StokLog (stok_log): id, product_id, branch, sumber (DRAFT/CHECKOUT/APPROVE/CANCEL/MANUAL/SYNC/EDIT/DRAFT_DELETE), field_terdampak (stok_booking/stok_diterima/stok_sistem), delta, nilai_sebelum, nilai_sesudah, actor_id, order_id, created_at

Tabel lain: CustomerAssignment (M2M sales-customer), AreaAssignment (coverage by kode_area), SalesTarget, SupplierTarget, Supplier, Bulletin, BulletinDismiss, ImportLog, SyncValidationError, CustomerRegistrationSubmission, ImportedSale

## 4. AUTENTIKASI & OTORIZASI

Role dan Akses:
- ADMIN (cabang scoped): Approve/reject order, ubah diskon, batalkan item, hapus produk, import & edit stok/customer, bulletin, laporan. TIDAK bisa approve/reject order dan TIDAK bisa mengelola user.
- SUPERVISOR (cabang scoped): Kelola produk/stok/customer/user (hanya akun SALES di cabangnya sendiri), bulletin, import, target supplier. TIDAK bisa approve/reject order.
- MANAGER (global, branch=NULL): Laporan & monitoring lintas cabang, kelola master cabang, operasi tulis. TIDAK bisa approve/reject order.
- SALES (cabang scoped): Order milik sendiri, customer di area-nya, katalog, bulletin.

Token: Access token JWT HS256 expired 30 menit (type=access), Refresh token expired 7 hari (type=refresh). token_version bertambah 1 setiap kali password diubah -> semua sesi lama invalid. Role + branch dibaca dari DB setiap request (bukan dari JWT payload), jadi perubahan role berlaku tanpa menunggu token kedaluwarsa.

Branch Guard: Global MANAGER (branch=NULL) lihat semua cabang. Role lain (branch diisi) hanya data cabangnya sendiri. Non-manager tanpa branch -> akses ditolak (fail-closed).

## 5. ALUR BISNIS

Siklus Status Order:
DRAFT --submit--> PENDING --approve--> APPROVED
  |                  |
  |                  --reject--> REJECTED
  |                  --cancel--> CANCELLED
  --delete--> (dihapus, stok booking dilepaskan)

Stok & Booking:
- Buat order (DRAFT): stok_booking + qty (atomic, 409 Conflict kalau stok tidak cukup)
- Submit DRAFT -> PENDING: stok booking tetap
- Approve PENDING -> APPROVED: stok_booking - qty, stok_diterima + qty
- Reject/Cancel PENDING: stok_booking - qty (dikembalikan ke tersedia)
- Hapus DRAFT: stok_booking - qty
- Edit stok manual (admin): stok_sistem ditimpa nilai baru
- Import Excel: stok_booking dipertahankan, stok_diterima di-reset ke 0, stok_sistem ditimpa kolom GOOD

3-Layer Discount (per item): Setiap item memiliki 3 lapisan diskon yang diterapkan SEQUENTIAL (layer 1 -> 2 -> 3 dari sisa running subtotal). Setiap layer bisa PERCENT atau NOMINAL. Up Price diterapkan SEBELUM 3-layer diskon (ditambah ke base subtotal).

Order Type: REGULER (order biasa) atau 4P (order khusus supplier 4P). Produk harus cocok dengan order_type.

Visibilitas Customer untuk Sales (3-Tier Rule): Sales hanya bisa melihat dan memesan customer yang memenuhi salah satu: (1) Direct assignment di customer_assignments, (2) Area coverage (kode_area cocok dengan area_assignments), (3) Unassigned (tanpa direct assignment dan tanpa kode_area yang di-assign ke siapapun).

## 6. ENDPOINT API (Prefix: /api/v1)

Auth (/auth): POST /register (MANAGER global), POST /login (Public), POST /refresh, POST /change-password (Auth)
Products (/products): GET / (Auth, filter search/kategori/supplier/order_type/status), GET /{id}, PUT /{id} (Write access), DELETE /{id} (Admin), PUT /{id}/stock (Write access), POST /import-excel (Write access, max 10MB), POST /sync, GET /import-logs, GET /sync/errors, GET /sales-stats, GET /suppliers/4p, GET /stats, GET /count, GET /kategori, GET /supplier
Orders (/orders): POST / (Auth, buat DRAFT booking stok atomic), GET /my (Auth, list order sendiri), GET /my/stats (Auth, dashboard sales), PUT /{id} (Auth, edit DRAFT/PENDING), DELETE /{id} (Auth, hapus DRAFT), POST /{id}/submit (Auth, DRAFT->PENDING), POST /{id}/cancel (Auth, PENDING->CANCELLED), GET /pending (Write access), GET / (Write access, list semua order)
Customers (/customers): GET / (Auth, 3-tier visibility), GET /my (Auth), GET /{id}, POST / (Write access), PUT /{id} (Write access), DELETE /{id} (Write access, soft delete), GET /{id}/assignments, PUT /{id}/assignments, GET /kode-areas, POST /import-excel, GET /count
Customer Submissions (/customer-submissions): Pengajuan toko baru dari sales, approve/reject oleh admin
Users (/users): CRUD user, role, branch (MANAGER global / SUPERVISOR)
Branches (/branches): CRUD cabang, statistik (MANAGER global)
Reports (/reports): GET /daily, GET /period, GET /summary (agregat by status/product/sales/branch), GET /sales-performance, GET /sales-performance/dashboard, GET /cross-branch/sales-summary (MANAGER global), GET /cross-branch/stock-summary (MANAGER global), GET /supplier-performance
Sales Targets (/sales-targets): Target & incentive per sales per bulan
Supplier Targets (/supplier-targets): Target penjualan per supplier per bulan
Suppliers (/suppliers): Master supplier (nama_supplier, is_active, order_type)
Sales Imports (/sales-imports): Impor data penampilan dari Excel rekap
Bulletins (/bulletins): CRUD pengumuman + upload PDF + dismiss tracking

## 7. FRONTEND APPS (FLUTTER)

Mobile Sales (sales-app/lib/): Beranda (omset hari ini, jumlah order hari ini, order menunggu approval, target bulanan), Katalog (produk + stok tersedia, pencarian dengan debounce), Buat order (4 langkah: pilih toko -> tipe order -> produk & qty -> review dengan diskon per baris, up price, item gratis, hapus baris), Pesanan (riwayat + status, detail, hapus draft, batal selama PENDING), Toko (daftar customer sesuai area sales, pengajuan customer baru), Bulletin (pengumuman dari admin, bisa di-dismiss).

Sales Web (sales-app/sales_web/): Flutter Web, layout mobile untuk browser, menggunakan dio untuk HTTP.

Admin Web (sales-app/admin_web/): Flutter Web, dashboard admin dengan 13 menu: Dashboard, Pesanan, Toko, Pengajuan Customer, Produk & Stok, Supplier, Sinkronisasi, User, Performa Sales, Penugasan Sales, Bulletin, Data Penjualan, Laporan Lintas Cabang (khusus MANAGER). Layout responsif: sidebar (desktop), NavigationRail (tablet), Drawer (HP). Menggunakan file_picker untuk impor Excel. Font lokal: PlusJakartaSans (bukan CDN).

## 8. USE CASE SCENARIOS

UC-01 Sales Buat Order: Sales login -> lihat katalog (stok tersedia) -> pilih toko (customer) -> pilih tipe order (REGULER/4P) -> tambah produk & qty -> atur diskon per baris (3 layer) dan up price -> review -> submit -> status PENDING, stok di-book -> admin approve -> stok dikonfirmasi (stok_diterima bertambah)

UC-02 Admin Approve Order: Admin login -> lihat daftar order PENDING -> pilih order, review detail -> approve atau reject (dengan alasan) -> approve: stok_booking berkurang, stok_diterima bertambah -> reject: stok_booking dilepaskan, status REJECTED

UC-03 Impor Stok dari Excel: Admin upload file .xlsx (max 10MB) -> validasi per baris -> produk baru di-insert, existing di-update -> stok_diterima di-reset ke 0, stok_sistem ditimpa dari kolom GOOD -> error per baris ditampilkan di menu Sinkronisasi -> Riwayat Error

UC-04 Pengajuan Toko Baru: Sales mengajukan customer baru via mobile (nama, alamat, KTP, area, kredit, dll) -> admin approve/reject di admin web -> approve: Customer baru dibuat dengan kode yang diinput admin

UC-05 Laporan Performa Sales: Manager buka dashboard -> lihat order count, revenue, submission count per sales -> filter per rentang tanggal, status, cabang -> export ke Excel

UC-06 Manajemen Multi-Cabang: Manager global lihat data semua cabang -> Admin cabang hanya lihat data cabangnya sendiri -> Stok, customer, user dipisah per cabang

## 9. KONFIGURASI PENTING (.env)
DATABASE_URL: Connection string PostgreSQL (Supabase cloud atau lokal)
SECRET_KEY: Secret untuk JWT signing (wajib diisi)
CORS_ORIGINS: Origin web app yang diizinkan (comma-separated)
ENVIRONMENT: development / production
SEED_DEMO_USERS: true = buat admin/admin dan sales/sales saat boot
RUN_SCHEDULER: true = jalankan scheduler bulletin

## 10. CATATAN PENTING UNTUK USE CASE
1. Semua transaksi online - tidak ada mode offline, harus terconnections ke API
2. Multi-cabang - setiap cabang berdiri sendiri untuk stok, customer, user
3. Role-based access control - 4 role dengan hak akses yang berbeda
4. Stok booking atomic - DRAFT langsung menahan stok, 409 Conflict jika tidak cukup
5. 3-layer diskon sequential - setiap layer dipotong dari sisa running subtotal
6. Timezone WITA - sistem menggunakan Asia/Makassar (UTC+8) untuk laporan
7. Soft delete - customer dan user menggunakan deleted_at, tidak hard delete
8. Token versioning - ganti password invalidate semua sesi
9. Excel import - produk dan customer bisa diimpor via file .xlsx
10. Bulletin scheduler - expire otomatis setiap hari jam 00:05 WITA, reset setiap tanggal 1 jam 00:10 WITA
