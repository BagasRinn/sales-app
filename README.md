# Aplikasi Manajemen Order Sales

Sistem order sales mandiri (standalone) untuk sales di lapangan. Sales membuat order dari
katalog yang stoknya sudah di-booking, admin memverifikasi lewat dashboard web, dan stok
antar cabang tetap konsisten — tanpa perlu koneksi dua arah ke ERP perusahaan.

Satu backend API (FastAPI) melayani tiga klien berbasis Flutter. Semua transaksi **online**
ke API; tidak ada mode offline.

## Komponen

| Komponen | Folder | Stack |
|---|---|---|
| Backend API | `sales-app/backend` | Python · FastAPI · SQLAlchemy 2 · PostgreSQL |
| Mobile sales | `sales-app` | Flutter (Android, iOS, Windows) |
| Sales web | `sales-app/sales_web` | Flutter Web (browser) |
| Admin web | `sales-app/admin_web` | Flutter Web (browser) |
| Package bersama | `sales-app/packages/datetime_utils` | Dart — dipakai ketiga klien |

## Fitur

### Sales — mobile & web

- **Beranda**: omset hari ini, jumlah order hari ini, order menunggu approval, target bulanan.
- **Katalog**: produk + stok tersedia, pencarian dengan debounce.
- **Buat order** (4 langkah): pilih toko → tipe order → produk & qty → review.
  Di review bisa atur diskon per baris, up price, item gratis, dan hapus baris.
  Draft tersimpan di provider selama aplikasi hidup.
- **Pesanan**: riwayat + status, detail, hapus draft, batal selama masih `PENDING`.
- **Toko**: daftar customer sesuai area sales, pengajuan customer baru untuk disetujui admin.
- **Bulletin**: pengumuman dari admin, bisa di-dismiss.

### Admin

Dashboard dengan 13 menu: Dashboard, Pesanan, Toko, Pengajuan Customer, Produk & Stok,
Supplier, Sinkronisasi, User, Performa Sales, Penugasan Sales, Bulletin, Data Penjualan,
Laporan Lintas Cabang (khusus MANAGER).

- Approve/reject order, ubah diskon, batalkan item sebagian.
- Edit/hapus produk, CRUD customer & user, tambah supplier + atur aktif/`order_type`, target
  sales & supplier.
- Import stok & customer dari Excel, riwayat error per baris.
- Laporan harian/periode, performa sales, stok, lintas cabang.
- Layout responsif: sidebar di desktop, `NavigationRail` di tablet, `Drawer` di HP.

## Alur order & stok

Produk punya tiga angka stok:

| Kolom | Arti |
|---|---|
| `stok_sistem` | stok fisik menurut data master (hasil import / edit manual admin) |
| `stok_booking` | stok yang ditahan order yang belum diputuskan |
| `stok_diterima` | qty yang sudah di-approve (barang keluar) |

`stok_tersedia = max(0, stok_sistem - stok_booking - stok_diterima)`

Siklus status order:

```
DRAFT ──submit──> PENDING ──approve──> APPROVED
  │                  │
  │                  ├──reject───> REJECTED
  │                  └──cancel───> CANCELLED
  └──delete──> (dihapus)
```

| Aksi | `stok_booking` | `stok_diterima` | `stok_sistem` |
|---|---|---|---|
| Buat order (DRAFT) | + qty (atomic, gagal 409 kalau kurang) | – | – |
| Submit → PENDING | – | – | – |
| Approve | − qty | + qty | – |
| Reject / Cancel (PENDING) | − qty | – | – |
| Hapus DRAFT | − qty | – | – |
| Edit stok manual (admin) | – | – | ditimpa nilai baru |
| Import Excel | – (booking dipertahankan) | 0 (reset) | ditimpa kolom `GOOD` |

`stok_sistem` hanya berubah lewat import dan edit manual, bukan lewat order. Import menganggap
kolom `GOOD` sudah neto, jadi `stok_diterima` selalu di-reset ke 0. Setiap perubahan stok dicatat
ke log audit (sumber, field, delta, nilai sebelum/sesudah, aktor, order).

## Multi-cabang & role

Cabang dimuat dari tabel `branches` saat startup; setiap cabang berdiri sendiri untuk stok,
customer, dan user-nya.

| Role | Akses |
|---|---|
| `ADMIN` | Terbatas cabangnya. Approve/reject order, ubah diskon, batalkan item, hapus produk, kelola user, import & edit stok/customer, bulletin, laporan |
| `SUPERVISOR` | Terbatas cabangnya. Kelola produk/stok/customer/user, bulletin, import, target supplier — **tidak** bisa approve/reject order |
| `MANAGER` | Global lintas cabang. Laporan & monitoring, kelola master cabang, operasi tulis yang diizinkan guard akses — **tidak** bisa approve/reject order |
| `SALES` | Order miliknya sendiri, customer di area-nya, katalog, bulletin |

Role dan cabang dibaca ulang dari database setiap request, jadi perubahan role berlaku tanpa
menunggu token kedaluwarsa. Data otomatis difilter ke cabang user (kecuali MANAGER dengan
cabang kosong).

## Struktur repo

```
.
├── sales-app/
│   ├── lib/                    # aplikasi mobile
│   ├── test/                   # unit/widget test mobile
│   ├── android/ ios/ windows/  # platform mobile & desktop
│   ├── sales_web/              # sales web (Flutter Web)
│   ├── admin_web/              # admin web (Flutter Web)
│   ├── packages/datetime_utils # parsing & format waktu (WIB/WITA/WIT)
│   └── backend/
│       ├── app/
│       │   ├── api/endpoints/  # router per domain
│       │   ├── core/           # auth/JWT, role, cabang, timezone
│       │   ├── models/         # SQLAlchemy
│       │   ├── schemas/        # Pydantic
│       │   └── services/       # import Excel, storage, audit stok
│       └── tests/              # pytest
└── scripts/                    # util build & deploy
```

## Menjalankan lokal

### Backend

```bash
cd sales-app/backend
python -m venv venv
# Windows
.\venv\Scripts\activate
# Linux/macOS
source venv/bin/activate

pip install -r requirements.txt
cp .env.example .env      # Windows: copy .env.example .env
uvicorn app.main:app --reload
```

API berjalan di `http://localhost:8000`, dokumentasi interaktif di `/docs`, health check di
`/health`. Tabel dibuat otomatis saat startup.

### Mobile

```bash
cd sales-app
flutter pub get
flutter run
```

### Sales web / Admin web

```bash
cd sales-app/sales_web    # atau admin_web
flutter pub get
flutter run -d chrome
```

Base URL API dikonfigurasi di `lib/core/config.dart` masing-masing aplikasi. Untuk
development lokal, serializer URL backend diganti ke `http://localhost:8000/api/v1`
(mobile Android emulator: `http://10.0.2.2:8000/api/v1`).

## Konfigurasi

Konfigurasi backend dibaca dari file `.env` (contoh lengkap di `.env.example`). Yang terpenting:

| Variabel | Keterangan |
|---|---|
| `DATABASE_URL` | Connection string PostgreSQL |
| `SECRET_KEY` | Secret untuk JWT |
| `CORS_ORIGINS` | Origin aplikasi web yang diizinkan, dipisah koma |
| lainnya | Variabel opsional: storage untuk PDF bulletin, seed data demo, job terjadwal |

## API

Semua endpoint berada di bawah prefix `/api/v1`:

| Prefix | Isi |
|---|---|
| `/auth` | login, refresh, register, change-password |
| `/products` | list/detail/update, stok manual, import Excel, riwayat import |
| `/orders` | buat, submit, edit, diskon, approve, reject, cancel, statistik |
| `/customers` | CRUD, import Excel, kode area, assignment per customer |
| `/customer-submissions` | pengajuan toko baru dari sales, approve/reject |
| `/reports` | harian, periode, ringkasan, performa sales, performa supplier, stok & sales lintas cabang |
| `/sales`, `/sales-targets`, `/sales-imports` | penugasan area, target, import data penjualan |
| `/suppliers`, `/supplier-targets` | master supplier (aktif, `order_type`), target supplier |
| `/users` | manajemen user |
| `/branches` | daftar/kelola cabang, statistik |
| `/bulletins` | CRUD + upload PDF + dismiss |

## Testing

```bash
# Flutter (mobile / sales_web / admin_web)
cd sales-app && flutter test
cd sales-app/admin_web && flutter test

# Backend
cd sales-app/backend
pip install pytest
pytest tests/
```

## Troubleshooting umum

**CORS error di web** — origin aplikasi web harus terdaftar persis (skema + host, tanpa slash
di akhir) di `CORS_ORIGINS`.

**Import Excel gagal** — pastikan file berekstensi `.xlsx` dan kolom header sesuai format.
Baris invalid tidak menggagalkan seluruh proses; daftar errornya bisa dilihat di menu
Sinkronisasi → Riwayat Error.

**Stok terlihat minus** — aplikasi membatasi tampilan minimum 0. Kalau stok nyata berbeda,
cek log audit stok: kemungkinan ada perubahan langsung ke database di luar aplikasi.
