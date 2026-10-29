# Aplikasi Manajemen Order Sales

Sistem order sales mandiri (standalone) untuk sales di lapangan. Sales membuat order dari
katalog yang stoknya sudah di-booking, admin memverifikasi lewat dashboard web, dan stok
antar cabang tetap konsisten — tanpa perlu koneksi dua arah ke ERP perusahaan.

Satu backend FastAPI melayani tiga klien Flutter. Semua transaksi **online** ke API; tidak ada
mode offline.

## Komponen

| Komponen | Folder | Stack | Jalan di |
|---|---|---|---|
| Backend API | `sales-app/backend` | Python 3.12 · FastAPI · SQLAlchemy 2 · PostgreSQL | Railway |
| Mobile sales | `sales-app` | Flutter (Android, iOS, Windows) | HP sales |
| Sales web | `sales-app/sales_web` | Flutter Web | `sales-order-web.web.app` |
| Admin web | `sales-app/admin_web` | Flutter Web | `sales-admin-web.web.app` |
| Package bersama | `sales-app/packages/datetime_utils` | Dart | dipakai ketiga klien |

Backend production: `https://sales-app-production-1872.up.railway.app` (docs Swagger di `/docs`).

## Fitur

### Sales — mobile (`sales-app`) & web (`sales-app/sales_web`)

- **Beranda**: omset hari ini, jumlah order hari ini, order menunggu approval, target bulanan.
- **Katalog**: produk + stok tersedia, pencarian dengan debounce.
- **Buat order** (4 langkah): pilih toko → tipe order → produk & qty → review.
  Di review bisa atur diskon per baris, up price, item gratis, dan hapus baris.
  Draft tersimpan di provider selama aplikasi hidup.
- **Pesanan**: riwayat + status, detail, hapus draft, batal selama masih `PENDING`.
- **Toko**: daftar customer sesuai area sales, pengajuan customer baru untuk disetujui admin.
- **Bulletin**: pengumuman dari admin, bisa di-dismiss.

### Admin — `sales-app/admin_web`

Dashboard dengan 13 menu: Dashboard, Pesanan, Toko, Pengajuan Customer, Produk & Stok,
Supplier, Sinkronisasi, User, Performa Sales, Penugasan Sales, Bulletin, Data Penjualan,
Laporan Lintas Cabang (khusus MANAGER).

- Approve/reject order, ubah diskon, batalkan item sebagian.
- Edit/hapus produk, CRUD customer & user, tambah supplier + atur aktif/`order_type`, target
  sales & supplier.
- Import stok & customer dari Excel, riwayat error per baris.
- Laporan harian/periode, performa sales, stok, lintas cabang. Unduh laporan (harian & periode)
  hanya ada di tab Dashboard.
- Layout responsif: sidebar 256px di desktop, `NavigationRail` di tablet, `Drawer` di HP.

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
kolom `GOOD` sudah neto, jadi `stok_diterima` selalu di-reset ke 0. Setiap perubahan dicatat ke
`stok_log` (sumber, field, delta, nilai sebelum/sesudah, aktor, order).

## Multi-cabang & role

Cabang: `BANJARMASIN`, `BATULICIN`, `BARABAI`, `PALANGKARAYA`, `SAMPIT`
(dimuat dari tabel `branches` saat startup).

| Role | Akses |
|---|---|
| `ADMIN` | Terbatas cabangnya. Approve/reject order, ubah diskon, batalkan item, hapus produk, kelola user, import & edit stok/customer, bulletin, laporan |
| `SUPERVISOR` | Terbatas cabangnya. Kelola produk/stok/customer/user, bulletin, import, target supplier — **tidak** bisa approve/reject order |
| `MANAGER` | Global lintas cabang. Laporan & monitoring, kelola master cabang, operasi tulis yang diizinkan `require_write_access` — **tidak** bisa approve/reject order |
| `SALES` | Order miliknya sendiri, customer di area-nya, katalog, bulletin |

Guard tiap endpoint ada di `app/core/security.py` (`require_admin`, `require_admin_or_supervisor`,
`require_write_access`, `require_manager_global`, dst.).

Role dan cabang dibaca ulang dari DB setiap request (bukan dari payload JWT), jadi perubahan
role berlaku tanpa menunggu token kedaluwarsa. Selain `MANAGER` dengan cabang kosong, data
otomatis difilter ke cabang user (`apply_branch_filter`).

## Struktur repo

```
.
├── sales-app/
│   ├── lib/                    # aplikasi mobile
│   ├── test/                   # unit/widget test mobile
│   ├── android/ ios/ windows/  # platform mobile & desktop
│   ├── sales_web/              # sales web (Flutter Web + firebase.json)
│   ├── admin_web/              # admin web (Flutter Web + firebase.json + tests/e2e)
│   ├── packages/datetime_utils # parsing & format waktu (WIB/WITA/WIT)
│   └── backend/
│       ├── app/
│       │   ├── api/endpoints/  # 14 router
│       │   ├── core/           # auth/JWT, role, cabang, timezone
│       │   ├── models/         # SQLAlchemy
│       │   ├── schemas/        # Pydantic
│       │   └── services/       # import Excel, storage, audit stok
│       ├── tests/              # pytest
│       ├── docs/               # panduan migrasi Supabase → Railway
│       └── migrate_*.py        # migrasi skema manual
├── scripts/                    # stamp build id + deploy web
├── .github/workflows/          # deploy sales web & admin web
├── Dockerfile                  # image backend (Railway)
└── railway.json
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

API di `http://localhost:8000`, dokumentasi di `/docs`, health check di `/health`.
Tabel dibuat otomatis saat startup (`Base.metadata.create_all`).

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

Base URL API di-hardcode ke production di `lib/core/config.dart` tiap app. Untuk backend lokal,
tukar komentar dengan baris `http://localhost:8000/api/v1` (mobile Android emulator:
`http://10.0.2.2:8000/api/v1`).

## Environment (`.env` backend)

| Variabel | Wajib | Keterangan |
|---|---|---|
| `DATABASE_URL` | ya | Connection string PostgreSQL |
| `SECRET_KEY` | ya | Secret JWT. Generate: `python -c "import secrets; print(secrets.token_hex(32))"` |
| `CORS_ORIGINS` | ya untuk web | Origin web dipisah koma, mis. `https://sales-order-web.web.app,https://sales-admin-web.web.app` |
| `SEED_DEMO_USERS` | tidak | `true` = buat `admin/admin` dan `sales/sales` saat boot. Jangan di production |
| `RUN_SCHEDULER` | tidak | `true` (default) = jalankan job bulletin. Set `false` di worker selain worker pertama |
| `STORAGE_PROVIDER` | tidak | Tidak dipakai untuk memilih provider; pemilihan otomatis dari kredensial di bawah (S3 dulu, lalu Supabase) |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_BUCKET_NAME`, `AWS_REGION`, `AWS_ENDPOINT_URL` | tidak | Storage S3-compatible (AWS/Tigris) untuk PDF bulletin. Butuh `pip install boto3` (tidak ada di `requirements.txt`) |
| `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `SUPABASE_BUCKET` | tidak | Fallback Supabase Storage |

Token: access 30 menit, refresh 7 hari. Mobile & admin web memakai `flutter_secure_storage`;
sales web memakai `sessionStorage` (hilang saat tab ditutup).

Job terjadwal (zona `Asia/Makassar`): bulletin kedaluwarsa tiap hari 00:05, reset bulletin
bulanan tiap tanggal 1 00:10.

## API

Semua di bawah prefix `/api/v1`:

| Prefix | Isi |
|---|---|
| `/auth` | login, refresh, register, change-password |
| `/products` | list/detail/update, stok manual, import Excel, riwayat import, hapus error |
| `/orders` | buat, submit, edit, diskon, approve, reject, cancel, cancel item, statistik |
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

# Backend — pytest tidak ada di requirements.txt, install dulu
cd sales-app/backend
pip install pytest
pytest tests/

# E2E admin (Playwright)
cd sales-app/admin_web/tests/e2e
npm install && npx playwright install --with-deps
npm test
```

## Deploy

**Backend** — Railway build dari `Dockerfile` di root, konfigurasi di `railway.json`
(`uvicorn app.main:app --host 0.0.0.0 --port 8000`). Perubahan skema dijalankan manual lewat
`migrate_*.py`; panduan lama Supabase → Railway ada di
`sales-app/backend/docs/MIGRATION_GUIDE.md`.

**Web** — Firebase Hosting, project `sales-admin-web`, dua site: `sales-order-web` dan
`sales-admin-web`. Push ke `main` yang menyentuh folder app (atau `scripts/**`) memicu workflow
terkait (`.github/workflows/deploy-*-firebase.yml`, juga bisa `workflow_dispatch`):
build → stamp → deploy. Manual dari Windows:

```powershell
.\scripts\deploy_web.ps1 -App sales_web
.\scripts\deploy_web.ps1 -App admin_web
```

Jangan `flutter build web` lalu `firebase deploy` langsung: langkah stamp di
`scripts/stamp_flutter_web.mjs` menambahkan `?v=<buildId>` ke `flutter_bootstrap.js` dan
`main.dart.js`. Tanpa itu browser bisa memakai bundle lama sampai setahun.

Strategi cache (`firebase.json` tiap app):

| Path | Cache-Control |
|---|---|
| `/`, `*.html`, `build-id.json` | `no-cache` |
| `main.dart.js`, `flutter_bootstrap.js` | `immutable`, 1 tahun (aman karena URL ber-versi) |
| `flutter.js`, `flutter_service_worker.js` | `no-cache` |
| `canvaskit/**`, gambar, font | 1 hari / 7 hari |

Halaman memasang banner "Versi baru tersedia" (cek `build-id.json` tiap 15 menit dan saat tab
aktif lagi), tanpa auto-reload supaya draft order tidak hilang.

Verifikasi setelah deploy:

```powershell
curl.exe -sI https://sales-order-web.web.app/main.dart.js | Select-String cache-control
curl.exe -sI https://sales-order-web.web.app/               | Select-String cache-control
```

Harus `max-age=31536000, immutable` dan `no-cache`.

## Troubleshooting

**CORS error di web** — `CORS_ORIGINS` harus berisi origin persis (skema + host, tanpa slash
di akhir). Kalau kosong, backend menolak semua origin karena `allow_credentials=True`.

**Import Excel gagal** — file harus `.xlsx` dengan kolom `CCODE`, `KATEGORI`, `NAME ITEM`,
`GOOD`, `OUM`, `FIX`, `LAST SUPPLIER`. Baris invalid tidak menggagalkan proses; lihat
"Sinkronisasi → Riwayat Error".

**Stok terlihat minus / overselling** — aplikasi membatasi tampilan minimum 0. Kalau stok
nyata berbeda, cek `stok_log`: kemungkinan ada perubahan langsung ke database di luar aplikasi.

**Bulletin tidak bisa diunduh** — cek konfigurasi storage (S3 atau Supabase). Tanpa keduanya,
upload PDF akan gagal.

## Catatan: beda dengan PRD v1.1

Beberapa hal di PRD awal sudah berubah mengikuti kebutuhan lapangan:

- Sinkronisasi stok lewat **import Excel**, bukan Google Sheets API. Endpoint `/products/sync`
  (tanpa file) masih ada tapi tidak dipakai — pakai `/products/import-excel`.
- **Tidak ada auto-expire order**; status `EXPIRED` dihapus dan stok yang tertahan hanya lepas
  lewat approve, reject, atau cancel.
- Status `DRAFT` ditambahkan di depan `PENDING`; stok sudah di-booking sejak draft dibuat,
  bukan saat submit.
- Role bertambah dari `ADMIN`/`SALES` menjadi empat, plus scoping per cabang.
- `stok_diterima` ditambahkan: approve memindahkan qty dari `stok_booking` ke `stok_diterima`
  tanpa menyentuh `stok_sistem`.
