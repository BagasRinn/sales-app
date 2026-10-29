# Sales Order App

Aplikasi manajemen order sales berbasis offline-sync. Ada tiga komponen utama:

| Komponen | Stack | Port Default |
|----------|-------|-------------|
| Mobile (sales) | Flutter | - |
| Admin Web | Flutter Web | 8080 |
| Backend API | Python FastAPI | 8000 |

## Arsitektur Singkat

Sales di lapangan pakai mobile app untuk lihat katalog, cek stok, dan bikin order. Admin manage semuanya dari web — approve order, sinkronisasi stok dari Google Sheets, tracking performa sales, dll.

Stok itu shared resource antara sales dan admin. Ada mekanisme `stok_booking` supaya race condition dihindari: saat sales checkout, stok langsung di-booking. Admin approve = stok dikurangi permanen; reject/cancel/expiry = stok booking dibebaskan.

Sinkronisasi dari Google Sheets memastikan stok_terakhir selalu sinkron dengan data master.

## Struktur Folder

```
.
├── sales-app/
│   ├── lib/                    # Mobile (sales)
│   ├── admin_web/lib/           # Admin web panel
│   └── backend/
│       ├── app/
│       │   ├── api/endpoints/  # Route handlers
│       │   ├── core/           # Auth, security, utils
│       │   ├── models/         # SQLAlchemy models
│       │   ├── schemas/        # Pydantic schemas
│       │   └── services/       # Business logic (sync, storage, etc.)
│       ├── requirements.txt
│       └── .env
```

## Setup Dev

### Backend

```bash
cd sales-app/backend
python -m venv venv
# Windows:
.\venv\Scripts\activate
# Linux/Mac:
source venv/bin/activate

pip install -r requirements.txt
cp .env.example .env
# Edit .env sesuai environment lo

python -m app
```

API jalan di `http://localhost:8000`. Docs Swagger ada di `/docs`.

### Admin Web

```bash
cd sales-app/admin_web
flutter pub get
flutter run -d chrome
```

### Mobile

```bash
cd sales-app
flutter pub get
flutter run
```

Pilih device yang mau dipake (emulator atau fisik via USB debugging).

## Variabel Environment (.env)

```
# Database (Supabase PostgreSQL)
DATABASE_URL=postgresql://user:pass@host:5432/dbname

# JWT secrets
JWT_SECRET_KEY=...
JWT_REFRESH_SECRET_KEY=...

# Google Sheets (untuk sync stok)
GOOGLE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
SHEETS_SPREADSHEET_ID=...

# Supabase (storage + auth)
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=...

# Opt-in demo user seeding
SEED_DEMO_USERS=false
RUN_SCHEDULER=true
```

## Roles & Permission

| Role | Akses |
|------|-------|
| ADMIN | Full write: approve/reject order, edit produk/toko/user, sync Sheets |
| SUPERVISOR | Read + approve/reject. Bisa manage user dan bulletin di cabangnya |
| MANAGER | Read-only monitoring semua cabang. Bisa generate laporan lintas cabang |
| SALES | Buat order, lihat katalog & stok, cancel order sendiri |

## Endpoint API Utama

```
POST   /api/v1/auth/login
POST   /api/v1/auth/refresh
GET    /api/v1/products
POST   /api/v1/orders
GET    /api/v1/orders/{id}
POST   /api/v1/orders/{id}/approve   (ADMIN only)
POST   /api/v1/orders/{id}/reject    (ADMIN only)
POST   /api/v1/sync/stok             (ADMIN only)
GET    /api/v1/reports/performance
```

Lihat `/docs` untuk daftar lengkap.

## Catatan Deployment

- `pubspec.lock` di-commit — Flutter build jadi deterministic antar mesin.
- Folder `build/`, `venv/`, `__pycache__/` di-gitignore.
- Credential files (`credentials.json`, `*.pem`, `*.key`, `.env`) jangan di-commit.
- Web production build & deploy — **jangan** `flutter build web` lalu `firebase deploy` manual:
  - `.\scripts\deploy_web.ps1 -App sales_web`
  - `.\scripts\deploy_web.ps1 -App admin_web`

  Script itu menjalankan build, lalu `scripts/stamp_flutter_web.mjs` menambahkan
  `?v=<buildId>` ke `flutter_bootstrap.js` dan `main.dart.js` sebelum deploy.
  Tanpa langkah itu browser bisa memakai bundle lama sampai 1 tahun.
  Di CI (push ke `main`) langkah ini sudah otomatis.

- Strategi cache web (lihat `firebase.json` di tiap app):
  - `index.html`, `/`, `build-id.json` → `no-cache` (selalu revalidasi, ±300 byte).
  - `flutter_bootstrap.js`, `main.dart.js` → cache 1 tahun, **aman** karena URL-nya
    ber-versi (`?v=<buildId>`), jadi build baru = URL baru = unduh baru.
  - Hasilnya: user selalu dapat versi terbaru tanpa hapus cache, dan tidak ada
    tambahan kuota saat tidak ada deploy.

- Verifikasi setelah deploy:
  ```powershell
  curl.exe -sI https://sales-order-web.web.app/main.dart.js | Select-String cache-control
  curl.exe -sI https://sales-order-web.web.app/               | Select-String cache-control
  ```
  Harus muncul `max-age=31536000, immutable` untuk `main.dart.js` dan `no-cache` untuk `/`.


## Troubleshooting

**CORS error setelah login di web**
→ Set `CORS_ORIGINS` di `.env` ke URL web app lo, contoh: `http://localhost:8080`

**Sync Sheets gagal**
→ Cek `GOOGLE_SERVICE_ACCOUNT_JSON` dan `SHEETS_SPREADSHEET_ID`. Service account harus punya akses Viewer ke spreadsheet.

**Stok minus / overselling**
→ Ini seharusnya tidak terjadi kalau mekanismenya bener. Cek apakah ada proses manual yang bypass aplikasi dan langsung nge-hit database.
