Product Requirements Document (PRD)
Nama Proyek: Aplikasi Manajemen Order Sales (Sistem Offline-Sync)
Versi: 1.0 (Draft Awal)
1. Latar Belakang & Tujuan
Latar Belakang:

Tenaga penjualan (sales) di lapangan sering mengalami race condition (bentrok pesanan) karena tidak memiliki akses real-time ke data stok. Aplikasi ini tidak memiliki otorisasi untuk terhubung langsung secara dua arah dengan sistem ERP utama perusahaan.

Tujuan:

Membangun sebuah sistem manajemen order mandiri (standalone) yang menggunakan spreadsheet sebagai jembatan sinkronisasi data satu arah, serta memfasilitasi proses penahanan stok sementara (stok booking) dan sistem approval pesanan oleh admin guna mencegah bentrok data (overselling).

2. Arsitektur & Spesifikasi Teknologi
Sistem ini dirancang untuk menangani ribuan baris data stok dan transaksi serentak dari belasan sales tanpa mengalami antrean proses (lag).

Frontend (Mobile & Web): Flutter.
Backend API: Python (FastAPI).
Database: PostgreSQL (Cloud-managed via Supabase untuk menyimulasikan lingkungan production dan memanfaatkan fitur Multi-Version Concurrency Control / MVCC).
Sumber Data Sinkronisasi: Google Sheets API. Akses dikontrol melalui Service Account (kredensial JSON) dengan izin read-only (Viewer) pada spreadsheet operasional.
Autentikasi & Otorisasi: JWT (JSON Web Token).
Menggunakan access token berumur pendek dan refresh token berumur panjang yang disimpan di secure storage perangkat.

Setiap endpoint dilindungi pengecekan role pengguna (ADMIN atau SALES).

3. Kebutuhan Fungsional (Functional Requirements)
A. Modul Admin (Web Dashboard)
1. Fitur Sinkronisasi Data (Sync):
Sistem menyediakan tombol untuk menarik data stok dari Google Sheets melalui API.

Sistem melakukan validasi baris: SKU kosong, angka negatif, atau baris duplikat SKU akan dilewati (skip) dan dicatat sebagai laporan error (tidak menggagalkan keseluruhan proses).

Sistem menggunakan metode Bulk Upsert (update jika SKU sudah ada, insert jika SKU baru) untuk menimpa nilai stok_sistem dalam waktu kurang dari 5 detik.

Jika hasil sync membuat stok_sistem menjadi lebih kecil dari stok_booking yang sedang berjalan, data tetap disimpan apa adanya, namun produk tersebut ditandai pada dashboard admin sebagai "perlu ditinjau".

2. Fitur Manajemen Stok (Manual Override):
Admin dapat mengubah nilai stok_sistem secara manual melalui antarmuka web apabila terdapat transaksi fisik di luar aplikasi.

3. Fitur Approval Order:
Sistem menampilkan daftar pesanan berstatus PENDING.

Approve: Mengubah status menjadi APPROVED, mengurangi stok_sistem sebesar kuantitas pesanan, dan mengurangi stok_booking sebesar kuantitas pesanan.
Reject: Mengubah status menjadi REJECTED, dan mengurangi stok_booking sebesar kuantitas pesanan. stok_sistem tidak berubah.
B. Modul Sales (Mobile Application)
1. Fitur Katalog & Cek Stok:
Sales dapat melihat daftar produk.

Sistem menampilkan Stok Tersedia dengan kalkulasi: stok_tersedia = MAX(0, stok_sistem - stok_booking).

2. Fitur Checkout (Keranjang):
Sistem melakukan validasi ketersediaan stok secara atomik saat checkout. Transaksi otomatis ditolak jika perhitungan (stok_sistem - stok_booking) lebih kecil dari jumlah yang dipesan.

Jika berhasil, sistem membuat data order dengan status PENDING dan secara otomatis menambahkan jumlah barang ke dalam nilai stok_booking.

3. Fitur Riwayat Transaksi & Pembatalan:
Sales dapat melihat status terkini dari pesanan mereka (PENDING, APPROVED, REJECTED, EXPIRED, CANCELLED).

Sales dapat membatalkan pesanan (Cancel) selama status masih PENDING. Pembatalan akan mengurangi nilai stok_booking sebesar kuantitas pesanan tersebut.

C. Modul Sistem Otomatis
1. Auto-Expire Pending Order:
Setiap order memiliki batas waktu (misal: 24 jam setelah dibuat).

Sistem akan secara berkala memindai pesanan PENDING yang melewati batas waktu, mengubah statusnya menjadi EXPIRED, dan membebaskan penahanan stok dengan mengurangi nilai stok_booking.

2. Pencatatan Jejak Audit (Audit Trail):
Setiap perubahan pada nilai stok_sistem maupun stok_booking (baik melalui sync, pesanan masuk, persetujuan, penolakan, pembatalan, maupun kedaluwarsa) akan dicatat secara mendetail ke dalam log sistem untuk keperluan pelacakan.

4. Desain Skema Database (Entity Relationship)
Tabel dirancang relasional pada PostgreSQL. Kolom pencarian diberikan Indexing (index=True) untuk optimalisasi kecepatan baca.

4.1 Tabel users
Kolom Tipe Data Keterangan id UUID (PK) Identifier unik pengguna username Varchar Nama akses login password_hash Varchar Kata sandi terenkripsi role Varchar ADMIN atau SALES
4.2 Tabel products
Kolom Tipe Data Keterangan id Varchar (PK) SKU atau Kode Barang (Terindeks) nama_barang Varchar Nama Produk (Terindeks) harga Integer Harga satuan stok_sistem Integer Stok aktual dari Google Sheets/Admin stok_booking Integer Akumulasi stok ditahan dari order PENDING
4.3 Tabel orders
Kolom Tipe Data Keterangan id UUID (PK) Identifier unik pesanan sales_id UUID (FK) Relasi ke users.id status Varchar PENDING, APPROVED, REJECTED, EXPIRED, CANCELLED created_at Timestamp Waktu pesanan dibuat expired_at Timestamp Batas waktu pesanan otomatis kedaluwarsa
4.4 Tabel order_items
Kolom Tipe Data Keterangan id UUID (PK) Identifier detail order_id UUID (FK) Relasi ke orders.id product_id Varchar (FK) Relasi ke products.id qty Integer Jumlah barang dipesan
4.5 Tabel stok_log
Kolom Tipe Data Keterangan id UUID (PK) Identifier unik log product_id Varchar (FK) Relasi ke products.id (Terindeks) sumber Varchar SYNC, MANUAL, CHECKOUT, APPROVE, REJECT, CANCEL, EXPIRE field_terdampak Varchar stok_sistem atau stok_booking delta Integer Perubahan nilai (positif/negatif) nilai_sebelum Integer Nilai sebelum perubahan nilai_sesudah Integer Nilai sesudah perubahan actor_id UUID (FK) Relasi ke users.id (Bisa null untuk proses otomatis) order_id UUID (FK) Relasi ke orders.id (Bisa null untuk proses sync/manual) created_at Timestamp Waktu perubahan dicatat
5. Kebutuhan Non-Fungsional (Kinerja & Skalabilitas)
Concurrency Handling: Penggunaan PostgreSQL dengan arsitektur FastAPI memastikan kueri baca dari katalog tidak akan memblokir (lock) proses tulis saat admin melakukan sinkronisasi ribuan data.

Checkout Atomicity: Validasi stok dilakukan dengan conditional update pada level database (UPDATE ... WHERE stok_sistem - stok_booking >= qty) untuk mencegah race condition.

Transaction Locking: Proses approve/reject dibungkus dalam satu database transaction dengan row-level lock pada baris produk terkait untuk memastikan integritas data.

Efisiensi Database: FastAPI akan dikonfigurasi dengan Connection Pooling untuk menghindari antrean koneksi.

Keamanan Data: Kredensial Service Account Google Sheets disimpan sebagai environment variable di server, tidak diekspos ke klien.