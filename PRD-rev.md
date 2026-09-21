# Product Requirements Document (PRD)

**Nama Proyek:** Aplikasi Manajemen Order Sales (Sistem Offline-Sync)
**Versi:** 1.1 (Revisi MVP — perbaikan logika stok, audit trail, autentikasi)

---

## Riwayat Revisi

| Versi | Perubahan |
|---|---|
| 1.0 | Draft awal MVP |
| 1.1 | Perbaikan bug logika reset stok_booking, penambahan mekanisme locking checkout, tabel audit log (stok_log), auto-expire pending order, fitur cancel order oleh sales, migrasi sumber sinkronisasi ke Google Sheets API, penambahan spesifikasi JWT untuk autentikasi & otorisasi |

---

## 1. Latar Belakang & Tujuan

**Latar Belakang:**
Tenaga penjualan (sales) di lapangan sering mengalami race condition (bentrok pesanan) karena tidak memiliki akses real-time ke data stok. Aplikasi ini tidak memiliki otorisasi untuk terhubung langsung secara dua arah dengan sistem ERP utama perusahaan.

**Tujuan:**
Membangun sebuah sistem manajemen order mandiri (standalone) yang menggunakan spreadsheet sebagai jembatan sinkronisasi data satu arah, serta memfasilitasi proses penahanan stok sementara (stok booking) dan sistem approval pesanan oleh admin guna mencegah bentrok data (overselling).

---

## 2. Arsitektur & Spesifikasi Teknologi

Sistem ini dirancang untuk menangani ribuan baris data stok dan transaksi serentak dari belasan sales tanpa mengalami lag.

- **Frontend (Mobile & Web):** Flutter.
- **Backend API:** Python (FastAPI).
- **Database:** PostgreSQL (Cloud-managed via Supabase untuk menyimulasikan lingkungan production dan memanfaatkan fitur Multi-Version Concurrency Control / MVCC).
- **Sumber Data Sinkronisasi:** **Google Sheets API** (bukan lagi tautan CSV publik).
- **Autentikasi & Otorisasi:** **JWT (JSON Web Token)**.

### 2.1 Perubahan Sumber Sinkronisasi: Google Sheets API

Sebelumnya direncanakan menggunakan tautan publik Google Spreadsheet (format CSV). Pada revisi ini, sinkronisasi dipindahkan ke **Google Sheets API** dengan pertimbangan:

- Spreadsheet tidak perlu diatur ke akses publik ("anyone with the link"), sehingga menghilangkan risiko sheet diedit pihak luar tanpa sepengetahuan admin.
- Akses dikontrol lewat **Service Account** (kredensial JSON) yang diberi izin *read-only* (Viewer) pada spreadsheet tertentu.
- Data diambil dalam bentuk terstruktur (array of rows) langsung dari `spreadsheets.values.get`, tanpa perlu parsing CSV manual.

### 2.2 Autentikasi & Otorisasi: JWT

- Login menghasilkan **access token** (JWT, umur pendek, misal 15–60 menit) dan **refresh token** (umur lebih panjang, disimpan aman di device Flutter — gunakan `flutter_secure_storage`, bukan `shared_preferences`).
- Payload JWT minimal memuat: `user_id`, `role`, `exp`.
- Setiap endpoint di backend FastAPI diberi *dependency* pengecekan token:
  - Endpoint modul Admin (sync, manual override, approve/reject) **wajib** `role == ADMIN`.
  - Endpoint modul Sales (checkout, riwayat, cancel order) **wajib** token valid, dan hanya boleh mengakses/mengubah data milik `sales_id` sendiri.
- Refresh token endpoint terpisah untuk memperpanjang sesi tanpa perlu login ulang.

---

## 3. Kebutuhan Fungsional (Functional Requirements)

### A. Modul Admin (Web Dashboard)

**Fitur Sinkronisasi Data (Sync):**
- Sistem menyediakan satu tombol untuk menarik data stok dari Google Sheets melalui Google Sheets API.
- Sistem melakukan **validasi baris** sebelum bulk update dieksekusi: SKU kosong, angka negatif, atau baris duplikat SKU akan **dilewati** (skip) dan dicatat sebagai laporan error hasil sync (bukan menggagalkan seluruh proses).
- Sistem menggunakan metode **Bulk Upsert** (update jika SKU sudah ada, insert jika SKU baru) untuk menimpa nilai `stok_sistem` pada database sesuai data dari Google Sheets, dalam waktu kurang dari 5 detik.
- Setiap perubahan `stok_sistem` hasil sync dicatat ke tabel `stok_log` (lihat bagian 4.5).
- **Penanganan kasus stok_sistem < stok_booking setelah sync:** jika sync menurunkan `stok_sistem` sehingga lebih kecil dari `stok_booking` yang sedang berjalan, sistem tetap menyimpan nilai apa adanya, namun `stok_tersedia` yang ditampilkan ke sales **dibatasi minimum 0** (tidak ditampilkan negatif), dan produk terkait ditandai pada dashboard admin sebagai "perlu ditinjau" (stok_sistem < stok_booking).

**Fitur Manajemen Stok (Manual Override):**
- Admin dapat mengubah nilai `stok_sistem` secara manual melalui antarmuka web apabila terdapat transaksi fisik di luar aplikasi.
- Setiap perubahan manual dicatat ke tabel `stok_log` dengan sumber `MANUAL` dan `actor_id` admin yang bersangkutan.

**Fitur Approval Order:**
- Sistem menampilkan daftar pesanan berstatus `PENDING`, termasuk yang mendekati batas waktu (lihat 3.C — auto-expire).
- Admin dapat melakukan **Approve**: mengubah status menjadi `APPROVED`, mengurangi `stok_sistem` sebesar qty pada order tersebut, dan mengurangi `stok_booking` sebesar qty yang sama (**bukan me-reset ke 0** — lihat catatan perbaikan bug di bagian 4.6).
- Admin dapat melakukan **Reject**: mengubah status menjadi `REJECTED`, dan mengurangi `stok_booking` sebesar qty pada order tersebut. `stok_sistem` **tidak berubah** saat reject, karena stok fisik belum pernah dikurangi selama status masih `PENDING`.
- Proses approve/reject dibungkus dalam satu **database transaction** dengan row-level lock pada baris produk terkait, agar tidak bentrok dengan proses checkout/sync yang berjalan bersamaan.
- Setiap approve/reject dicatat ke tabel `stok_log`.

### B. Modul Sales (Mobile Application)

**Fitur Katalog & Cek Stok:**
- Sales dapat melihat daftar produk.
- Sistem menampilkan Stok Tersedia dengan rumus kalkulasi internal: `stok_tersedia = MAX(0, stok_sistem - stok_booking)`.

**Fitur Checkout (Keranjang):**
- Sistem melakukan validasi **atomic** saat tombol checkout ditekan, menggunakan conditional update pada level database, contoh pola:
  `UPDATE products SET stok_booking = stok_booking + :qty WHERE id = :id AND (stok_sistem - stok_booking) >= :qty`
  Jika baris yang terpengaruh (`rowcount`) adalah 0, maka stok tidak mencukupi dan transaksi checkout ditolak. Pendekatan ini memanfaatkan MVCC PostgreSQL sehingga tidak perlu explicit row-lock terpisah untuk kasus ini.
- Jika berhasil, sistem membuat data order dengan status `PENDING` (qty sudah otomatis tertahan lewat langkah di atas), dengan `expired_at` diisi sesuai konfigurasi durasi pending (lihat 3.C).
- Setiap penambahan `stok_booking` dari checkout dicatat ke tabel `stok_log`.

**Fitur Riwayat Transaksi:**
- Sales dapat melihat status terkini dari pesanan mereka (`PENDING`, `APPROVED`, `REJECTED`, `EXPIRED`, `CANCELLED`).

**Fitur Cancel Order (baru):**
- Sales dapat membatalkan order miliknya sendiri **selama status masih `PENDING`**.
- Efeknya setara dengan reject: status berubah menjadi `CANCELLED`, `stok_booking` dikurangi sebesar qty order tersebut, `stok_sistem` tidak berubah.
- Dicatat ke tabel `stok_log` dengan sumber `CANCEL`.

### C. Auto-Expire Pending Order (baru)

- Setiap order yang dibuat diberi kolom `expired_at` (misal: `created_at` + 24 jam, durasi dapat dikonfigurasi).
- Sebuah job terjadwal (scheduled task, misal via cron/APScheduler) atau endpoint yang dipanggil berkala akan mencari order berstatus `PENDING` dengan `expired_at` telah lewat, lalu mengubah status menjadi `EXPIRED` dan mengurangi `stok_booking` sebesar qty terkait — sama seperti alur reject.
- Tujuannya mencegah stok tertahan selamanya akibat pesanan yang tidak pernah diproses admin.

---

## 4. Desain Skema Database (Entity Relationship)

Sistem menggunakan desain relasional pada PostgreSQL. Kolom yang sering diakses untuk pencarian barang akan diberikan Indexing (`index=True`) agar proses kalkulasi katalog oleh backend berjalan instan.

### 4.1 Tabel `users`

| Kolom | Tipe Data | Keterangan |
|---|---|---|
| id | UUID (PK) | Identifier unik pengguna |
| username | Varchar | Nama akses login |
| password_hash | Varchar | Kata sandi terenkripsi |
| role | Varchar | ADMIN atau SALES |

### 4.2 Tabel `products`

| Kolom | Tipe Data | Keterangan |
|---|---|---|
| id | Varchar (PK) | SKU atau Kode Barang (Terindeks) |
| nama_barang | Varchar | Nama Produk (Terindeks) |
| harga | Integer | Harga satuan |
| stok_sistem | Integer | Stok aktual dari Google Sheets/Admin |
| stok_booking | Integer | Akumulasi stok ditahan dari order PENDING |

### 4.3 Tabel `orders`

| Kolom | Tipe Data | Keterangan |
|---|---|---|
| id | UUID (PK) | Identifier unik pesanan |
| sales_id | UUID (FK) | Relasi ke users.id |
| status | Varchar | PENDING, APPROVED, REJECTED, EXPIRED, CANCELLED |
| created_at | Timestamp | Waktu pesanan dibuat |
| expired_at | Timestamp | Batas waktu pesanan berstatus PENDING otomatis kedaluwarsa |

### 4.4 Tabel `order_items`

| Kolom | Tipe Data | Keterangan |
|---|---|---|
| id | **UUID (PK)** | Identifier detail (diseragamkan dengan tabel lain) |
| order_id | UUID (FK) | Relasi ke orders.id |
| product_id | Varchar (FK) | Relasi ke products.id |
| qty | Integer | Jumlah barang dipesan |

### 4.5 Tabel `stok_log` (baru — Audit Trail)

| Kolom | Tipe Data | Keterangan |
|---|---|---|
| id | UUID (PK) | Identifier unik log |
| product_id | Varchar (FK) | Relasi ke products.id (Terindeks) |
| sumber | Varchar | SYNC, MANUAL, CHECKOUT, APPROVE, REJECT, CANCEL, EXPIRE |
| field_terdampak | Varchar | stok_sistem atau stok_booking |
| delta | Integer | Perubahan nilai (bisa positif/negatif) |
| nilai_sebelum | Integer | Nilai sebelum perubahan |
| nilai_sesudah | Integer | Nilai sesudah perubahan |
| actor_id | UUID (FK, nullable) | Relasi ke users.id — null jika sumber = SYNC atau EXPIRE (job otomatis) |
| order_id | UUID (FK, nullable) | Relasi ke orders.id — diisi jika perubahan berasal dari order (checkout/approve/reject/cancel/expire) |
| created_at | Timestamp | Waktu perubahan dicatat |

Tabel ini menjadi sumber utama untuk menelusuri selisih stok di kemudian hari, tanpa harus menebak-nebak dari kombinasi status order.

### 4.6 Catatan Perbaikan Bug (dari v1.0)

Pada v1.0 tertulis "Approve: ... me-reset stok_booking" — ini berpotensi menghapus hold dari order PENDING lain pada produk yang sama, menyebabkan overselling. Pada v1.1, approve/reject/cancel/expire **hanya mengurangi `stok_booking` sebesar qty order yang bersangkutan**, bukan mereset seluruh nilai `stok_booking` produk ke 0.

---

## 5. Kebutuhan Non-Fungsional (Kinerja & Skalabilitas)

- **Concurrency Handling:** Penggunaan PostgreSQL dengan arsitektur Python FastAPI memastikan kueri baca dari belasan sales tidak akan memblokir (lock) proses tulis saat admin sedang melakukan sinkronisasi data besar-besaran.
- **Checkout Atomicity:** Validasi stok saat checkout menggunakan conditional update tunggal (lihat 3.B) untuk mencegah race condition tanpa mengorbankan performa baca.
- **Approve/Reject Locking:** Menggunakan database transaction + row-level lock pada baris produk terkait untuk memastikan konsistensi saat beberapa admin memproses order secara bersamaan.
- **Efisiensi Database:** FastAPI akan dikonfigurasi dengan Connection Pooling (misal: `pool_size=20`, `max_overflow=10`) melalui SQLAlchemy untuk menghindari antrean koneksi pada database cloud.
- **Keamanan Token:** Access token JWT berumur pendek untuk membatasi dampak jika token bocor; refresh token disimpan di secure storage pada perangkat Flutter.
- **Keamanan Kredensial Google Sheets API:** Service Account credential (JSON key) disimpan sebagai environment variable/secret di server, tidak pernah di-commit ke repository maupun diekspos ke client Flutter.

---

*Dokumen ini adalah revisi dari PRD v1.0. Perubahan difokuskan pada perbaikan logika stok booking, penambahan audit trail, dan penguatan keamanan (autentikasi JWT, sinkronisasi via Google Sheets API), tanpa mengubah scope arsitektur inti yang telah ditetapkan.*


lib/
├── core/                    # Konfigurasi global (theme, API client, error handling)
├── features/
│   ├── auth/                # Fitur Login
│   ├── product/             # Fitur List Produk & Stok
│   │   ├── domain/          # Models (Product model)
│   │   ├── presentation/    # UI Screens & Widgets
│   │   └── providers/       # State management (Riverpod/Bloc)
│   └── order/               # Fitur Checkout / Cart
└── main.dart                # Entry point aplikasi Flutter


backend/
├── app/
│   ├── api/                 # Endpoint / Routes (users.py, products.py, orders.py)
│   ├── core/                # Config, Security, Database settings, Redis client
│   ├── models/              # SQLAlchemy Database Models
│   ├── schemas/             # Pydantic models (Request/Response validation)
│   ├── services/            # Business logic (e.g., Redis checkout logic)
│   └── main.py              # Entry point aplikasi FastAPI
├── requirements.txt         # Daftar library (fastapi, uvicorn, redis, sqlalchemy)
└── .env                     # Variabel environment (URL database, URL Redis)