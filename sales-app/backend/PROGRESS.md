# Progress Checklist — Aplikasi Manajemen Order Sales

**Referensi:** PRD v1.1 (PRD-rev.md)
**Terakhir diupdate:** 2026-08-10
**Backend version:** 1.1
**Flutter version:** 1.0.0 (Mobile Sales App)

---

## Ringkasan Status

| Komponen | Progress |
|----------|----------|
| Backend FastAPI | **93%** |
| Flutter Mobile (Sales) | **80%** (UI selesai, perlu test integration) |
| Flutter Web (Admin) | **0%** |
| **Overall** | **~60%** |

---

## 1. Arsitektur & Setup Project

### Backend

| # | Item | Status | Catatan |
|---|------|--------|---------|
| 1.1 | Struktur direktori sesuai PRD | ✅ DONE | `api/endpoints/`, `core/`, `models/`, `schemas/`, `services/` |
| 1.2 | Database PostgreSQL (Supabase) | ✅ DONE | pool_size=20, max_overflow=10 |
| 1.3 | Koneksi Google Sheets API | ✅ DONE | Service Account, credentials.json |
| 1.4 | JWT Authentication | ✅ DONE | Access token (30 menit) + Refresh token (7 hari) |
| 1.5 | Role-based access (ADMIN / SALES) | ✅ DONE | `require_admin`, `require_auth` dependencies |
| 1.6 | CORS middleware | ✅ DONE | allow_origins=["*"] |
| 1.7 | requirements.txt | ✅ DONE | 13 library dengan versi |

### Flutter Mobile (Sales)

| # | Item | Status | Catatan |
|---|------|--------|---------|
| 1.8 | Project Flutter dibuat | ✅ DONE | `flutter create` di sales-app/ |
| 1.9 | Dependencies | ✅ DONE | http, provider, flutter_secure_storage, intl, flutter_spinkit |
| 1.10 | Struktur direktori sesuai PRD | ✅ DONE | `core/`, `data/models/`, `data/repositories/`, `presentation/providers/`, `presentation/screens/` |

---

## 2. Database Schema (Backend)

| # | Tabel | Status | Catatan |
|---|-------|--------|---------|
| 2.1 | `users` | ✅ DONE | id (UUID PK), username (unique, indexed), password_hash, role |
| 2.2 | `products` | ✅ DONE | id (String PK, SKU), nama_barang (indexed), harga, stok_sistem, stok_booking |
| 2.3 | `orders` | ✅ DONE | id (UUID PK), sales_id (FK), status, created_at, expired_at |
| 2.4 | `order_items` | ✅ DONE | id (UUID PK), order_id (FK), product_id (FK), qty |
| 2.5 | `stok_log` | ✅ DONE | id, product_id (indexed), sumber, field_terdampak, delta, nilai_sebelum, nilai_sesudah, actor_id, order_id, created_at |

---

## 3. Modul Admin — Backend API

### 3.1 Sinkronisasi Data

| # | Item | Status | Endpoint |
|---|------|--------|----------|
| 3.1.1 | Tombol sync dari Google Sheets | ✅ DONE | `POST /api/v1/products/sync` |
| 3.1.2 | Validasi: SKU kosong | ✅ DONE | Skip + catat error |
| 3.1.3 | Validasi: angka negatif | ✅ DONE | Skip + catat error |
| 3.1.4 | Validasi: SKU duplikat dalam sheet | ✅ DONE | Skip + catat error |
| 3.1.5 | Bulk Upsert (insert/update SKU) | ✅ DONE | Cek existing → update else insert |
| 3.1.6 | Laporan error hasil sync | ✅ DONE | `GET /api/v1/products/sync/errors` |
| 3.1.7 | Logging ke `stok_log` saat sync | ✅ DONE | sumber=SYNC |
| 3.1.8 | Handle: stok_sistem < stok_booking | ✅ DONE | `perlu_ditinjau` flag di response |
| 3.1.9 | Konfigurasi spreadsheet name via env | ✅ DONE | `GOOGLE_SHEETS_NAME` di .env |

### 3.2 Manajemen Stok (Manual Override)

| # | Item | Status | Endpoint |
|---|------|--------|----------|
| 3.2.1 | Ubah stok_sistem manual | ✅ DONE | `PUT /api/v1/products/{product_id}/stock` |
| 3.2.2 | Logging ke `stok_log` | ✅ DONE | sumber=MANUAL |
| 3.2.3 | Proteksi role ADMIN | ✅ DONE | `require_admin` |

### 3.3 Approval Order

| # | Item | Status | Endpoint |
|---|------|--------|----------|
| 3.3.1 | List order PENDING | ✅ DONE | `GET /api/v1/orders/pending` |
| 3.3.2 | Approve order | ✅ DONE | `POST /api/v1/orders/{order_id}/approve` |
| 3.3.3 | Reject order | ✅ DONE | `POST /api/v1/orders/{order_id}/reject` |
| 3.3.4 | Logic approve: kurangi stok_sistem + stok_booking | ✅ DONE | masing-masing -= qty |
| 3.3.5 | Logic reject: kurangi stok_booking saja | ✅ DONE | stok_sistem tidak berubah |
| 3.3.6 | Logging approve/reject ke `stok_log` | ✅ DONE | sumber=APPROVE, REJECT |
| 3.3.7 | Proteksi role ADMIN | ✅ DONE | `require_admin` |

---

## 4. Modul Sales — Backend API

### 4.1 Katalog & Cek Stok

| # | Item | Status | Endpoint |
|---|------|--------|----------|
| 4.1.1 | List produk dengan stok_tersedia | ✅ DONE | `GET /api/v1/products` |
| 4.1.2 | Detail satu produk | ✅ DONE | `GET /api/v1/products/{product_id}` |
| 4.1.3 | Search produk | ✅ DONE | query param `?search=...` |
| 4.1.4 | Filter produk perlu ditinjau | ✅ DONE | query param `?needs_review=true` |

### 4.2 Checkout (Keranjang)

| # | Item | Status | Endpoint |
|---|------|--------|----------|
| 4.2.1 | Checkout dengan conditional atomic update | ✅ DONE | `POST /api/v1/orders` |
| 4.2.2 | Validasi: (stok_sistem - stok_booking) >= qty | ✅ DONE | SQL conditional update |
| 4.2.3 | Set expired_at (24 jam) | ✅ DONE | timedelta(hours=24) |
| 4.2.4 | Logging checkout ke `stok_log` | ✅ DONE | sumber=CHECKOUT |

### 4.3 Riwayat Transaksi

| # | Item | Status | Endpoint |
|---|------|--------|----------|
| 4.3.1 | Riwayat order milik sendiri | ✅ DONE | `GET /api/v1/orders/my` |
| 4.3.2 | Filter by status | ✅ DONE | `?status=PENDING` |
| 4.3.3 | Detail order | ✅ DONE | `GET /api/v1/orders/{order_id}` |

### 4.4 Cancel Order

| # | Item | Status | Endpoint |
|---|------|--------|----------|
| 4.4.1 | Cancel order milik sendiri | ✅ DONE | `POST /api/v1/orders/{order_id}/cancel` |
| 4.4.2 | Logic: kurangi stok_booking | ✅ DONE | -= qty |
| 4.4.3 | Logging ke `stok_log` | ✅ DONE | sumber=CANCEL |
| 4.4.4 | Proteksi: hanya owner | ✅ DONE | Cek sales_id dari token |

---

## 5. Modul Sistem Otomatis (Backend)

| # | Item | Status | Catatan |
|---|------|--------|---------|
| 5.1 | Auto-expire job (APScheduler) | ✅ DONE | Interval 5 menit |
| 5.2 | Logic: PENDING → EXPIRED, bebaskan stok_booking | ✅ DONE | Di `expire_pending_orders()` |
| 5.3 | Logging expire ke `stok_log` | ✅ DONE | sumber=EXPIRE |

---

## 6. Modul Sales — Flutter Mobile App

### 6.1 Autentikasi

| # | Item | Status | File |
|---|------|--------|------|
| 6.1.1 | Login screen | ✅ DONE | `presentation/screens/auth/login_screen.dart` |
| 6.1.2 | Auth state management | ✅ DONE | `presentation/providers/auth_provider.dart` |
| 6.1.3 | Secure token storage | ✅ DONE | `data/repositories/auth_repository.dart` |
| 6.1.4 | Auto-login check | ✅ DONE | `main.dart` AuthWrapper |

### 6.2 Katalog Produk

| # | Item | Status | File |
|---|------|--------|------|
| 6.2.1 | Product list screen | ✅ DONE | `presentation/screens/products/product_catalog_screen.dart` |
| 6.2.2 | Product card (stok, harga, add to cart) | ✅ DONE | `_ProductCard` widget |
| 6.2.3 | Search produk | ✅ DONE | TextField dengan debounce |
| 6.2.4 | Tampilan stok tersedia | ✅ DONE | `stok_tersedia` dari API |

### 6.3 Keranjang & Checkout

| # | Item | Status | File |
|---|------|--------|------|
| 6.3.1 | Cart screen | ✅ DONE | `presentation/screens/cart/cart_screen.dart` |
| 6.3.2 | Cart state management | ✅ DONE | `presentation/providers/cart_provider.dart` |
| 6.3.3 | Tambah/kurang qty | ✅ DONE | increment/decrement di cart |
| 6.3.4 | Checkout confirmation dialog | ✅ DONE | Konfirmasi sebelum submit |
| 6.3.5 | Refresh katalog setelah checkout | ✅ DONE | `ProductProvider.loadProducts()` |

### 6.4 Riwayat Order & Cancel

| # | Item | Status | File |
|---|------|--------|------|
| 6.4.1 | Order history screen | ✅ DONE | `presentation/screens/orders/order_history_screen.dart` |
| 6.4.2 | Order state management | ✅ DONE | `presentation/providers/order_provider.dart` |
| 6.4.3 | Filter by status | ✅ DONE | FilterChip (Semua, Menunggu, Disetujui, Ditolak, Dibatalkan) |
| 6.4.4 | Cancel order | ✅ DONE | Konfirmasi + API call |
| 6.4.5 | Status badge dengan icon | ✅ DONE | Color-coded per status |

---

## 7. API Endpoints (17 total — Backend)

```
Authentication:
  POST /api/v1/auth/register
  POST /api/v1/auth/login
  POST /api/v1/auth/refresh

Products (SALES: katalog, ADMIN: full):
  GET  /api/v1/products
  GET  /api/v1/products/{product_id}
  PUT  /api/v1/products/{product_id}/stock        (ADMIN)
  POST /api/v1/products/sync                       (ADMIN)
  GET  /api/v1/products/sync/errors                (ADMIN)

Orders:
  POST /api/v1/orders                    (SALES: checkout)
  GET  /api/v1/orders/my                 (SALES: riwayat saya)
  POST /api/v1/orders/{order_id}/cancel  (SALES: cancel)
  GET  /api/v1/orders/pending            (ADMIN)
  GET  /api/v1/orders                    (ADMIN: semua order)
  GET  /api/v1/orders/{order_id}         (SALES/ADMIN)
  POST /api/v1/orders/{order_id}/approve (ADMIN)
  POST /api/v1/orders/{order_id}/reject  (ADMIN)
```

---

## 8. Struktur File

### Backend

```
backend/
├── app/
│   ├── main.py                  # Entry point, CORS, scheduler
│   ├── api/endpoints/
│   │   ├── auth.py             # register, login, refresh
│   │   ├── products.py          # CRUD produk, sync, manual stock
│   │   └── orders.py           # checkout, cancel, approve, reject
│   ├── core/security.py         # JWT, bcrypt, role dependencies
│   ├── models/
│   │   ├── database.py         # SQLAlchemy engine, session
│   │   └── models.py           # Table models
│   ├── schemas/schemas.py       # Pydantic models
│   └── services/
│       ├── sheets_sync.py       # Google Sheets sync
│       ├── stock_logger.py      # Audit trail helper
│       └── tasks.py            # Background tasks
├── .env
├── requirements.txt
└── credentials.json
```

### Flutter Mobile

```
lib/
├── main.dart                    # Entry point, MultiProvider, AuthWrapper
├── core/
│   ├── config.dart             # Base URL, token keys
│   ├── theme.dart              # Material 3 theme
│   └── api_exception.dart      # ApiException class
├── data/
│   ├── models/
│   │   ├── product.dart        # Product model
│   │   ├── order.dart         # Order, OrderItem models
│   │   └── cart_item.dart     # CartItem model
│   └── repositories/
│       ├── api_service.dart    # HTTP client singleton
│       ├── auth_repository.dart # Login, logout, token storage
│       ├── product_repository.dart
│       └── order_repository.dart
└── presentation/
    ├── providers/
    │   ├── auth_provider.dart   # Auth state
    │   ├── product_provider.dart # Products state
    │   ├── cart_provider.dart   # Cart state
    │   └── order_provider.dart   # Orders state
    └── screens/
        ├── auth/login_screen.dart
        ├── home/home_screen.dart  # Bottom nav (Katalog, Keranjang, Pesanan)
        ├── products/product_catalog_screen.dart
        ├── cart/cart_screen.dart
        └── orders/order_history_screen.dart
```

---

## 9. Yang Belum Dilakukan

| # | Item | Priority | Catatan |
|---|------|----------|---------|
| 9.1 | Flutter Web Admin Dashboard | 🔴 HIGH | Sync, approve/reject, override stok, lihat laporan |
| 9.2 | Test integration (backend ↔ Flutter) | 🔴 HIGH | APK debug harus dicek dengan server hidup |
| 9.3 | Android release build | 🟡 MED | Optimasi dan signing |
| 9.4 | Unit test backend | 🟡 MED | pytest untuk endpoint critical |
| 9.5 | Token auto-refresh di Flutter | 🟡 MED | Refresh sebelum expired |

---

## Cara Menjalankan

### Backend

```bash
cd sales-app/backend
pip install -r requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
# Swagger: http://localhost:8000/docs
```

### Flutter Mobile (Development)

```bash
cd sales-app

# Debug APK
flutter build apk --debug

# Run di emulator/device
flutter run

# Analyze code
flutter analyze
```

### Konfigurasi API URL

Untuk emulator Android: `http://10.0.2.2:8000/api/v1`
Untuk device: Ganti `baseUrl` di `lib/core/config.dart` ke IP komputer kamu.

### Register Admin

```bash
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password123","role":"ADMIN"}'

curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"sales1","password":"password123","role":"SALES"}'
```
