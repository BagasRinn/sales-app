# Mobile App Rebuild — Sales Order App

**Tanggal:** 2026-09-22
**Status:** Draft untuk review
**Scope:** Rebuild aplikasi mobile `sales-app/` (Flutter) + backend & admin-web additions yang dibutuhkan untuk mendukung mobile baru.

---

## 1. Konteks & Motivasi

Aplikasi mobile sales saat ini hanya punya alur linear: pilih produk → keranjang → submit. Tidak ada halaman beranda/dashboard, tidak ada status intermediate yang jelas, dan flow "Simpan Draft" tidak ada (semua order langsung submit).

User ingin rebuild agar:
- Ada **Beranda** sebagai dashboard penjualan (konteks performa harian).
- Ada alur **Order** yang jelas (pilih toko dulu → produk → review) dengan kemampuan **Simpan Draft** dan **Edit Draft**.
- Konsep "Lainnya" sebagai catch-all dengan minimal **Profil + Logout**.

Karena backend & admin-web masih akan dipakai, rebuild ini menyentuh ketiganya dengan perubahan terkoordinasi.

---

## 2. Goals & Non-Goals

### Goals
1. Mobile punya 4 tab utama: **Beranda**, **Pesanan**, **Katalog**, **Lainnya**.
2. Ada konsep **status order** dengan 4 status utama yang terlihat di mobile: Draft, Submitted (Pending), Dikirim (Approved), Dibatalkan (Cancelled/Rejected). **Tidak ada status Completed** karena flow cukup sampai admin approve & cetak struk.
3. Sales bisa **simpan order sebagai draft** lalu **edit draft** sebelum submit.
4. **Beranda menampilkan ringkasan performa sales** (omset hari ini dari order Dikirim, jumlah Pending, ringkasan lain yang datanya tersedia).
5. **Toko (customer) menjadi entity** terpisah, di-import via Excel di admin-web (pakai pola yang sudah ada untuk produk).
6. Setiap sales hanya bisa **memilih toko yang di-assign** kepadanya saat bikin order.

### Non-Goals (di luar scope rebuild ini)
- Status `COMPLETED` di mobile atau backend.
- Notifikasi push untuk sales.
- Pembayaran / payment tracking di mobile.
- Multi-bahasa (UI tetap Bahasa Indonesia saja).
- Refactor besar admin-web di luar halaman sinkronisasi.

---

## 3. Backend Additions

### 3.1 Entity Baru

#### `customers` (Toko)
| Field | Tipe | Constraint |
|---|---|---|
| `id` | UUID | PK |
| `nama_toko` | String(200) | required, indexed |
| `pemilik` | String(200) | nullable |
| `kontak` | String(50) | nullable |
| `alamat` | String(500) | nullable |
| `kategori` | String(100) | nullable, indexed |
| `catatan` | String(1000) | nullable |
| `created_at` | DateTime | server default now() |
| `updated_at` | DateTime | server default now() |

#### `customer_sales` (Assignment)
| Field | Tipe | Constraint |
|---|---|---|
| `customer_id` | UUID | FK → customers.id, composite PK |
| `sales_id` | UUID | FK → users.id, composite PK |
| `assigned_at` | DateTime | server default now() |

> Sales user hanya boleh `SELECT` customer yang ada di tabel assignment ini.

### 3.2 Schema Changes pada `orders`

Tambah field:
- `customer_id` (UUID, FK → customers.id, **nullable** untuk backward compatibility dengan order lama yang belum pakai customer entity)
- `notes` (String(1000), nullable)
- Ubah default `status` jadi `DRAFT` (lihat 3.3)

Tambah index baru:
- `ix_orders_customer_id` pada `customer_id`

### 3.3 Perubahan Status Enum

Enum `OrderStatus` di `schemas.py`:
```python
class OrderStatus(str, Enum):
    DRAFT = "DRAFT"
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    EXPIRED = "EXPIRED"
    CANCELLED = "CANCELLED"
```

**Mapping terminologi mobile ↔ backend:**
| Mobile UI | Backend enum |
|---|---|
| Draft | `DRAFT` |
| Submitted (Pending) | `PENDING` |
| Dikirim | `APPROVED` |
| Dibatalkan | `CANCELLED` (oleh sales) atau `REJECTED` (oleh admin) |
| Kedaluwarsa | `EXPIRED` (auto, tidak muncul sebagai tab) |

> Catatan: `COMPLETED` sengaja tidak dibuat. Setelah `APPROVED`, sales/admin tinggal cetak struk detail dan dianggap selesai dari sisi sales app.

### 3.4 Endpoints Baru

#### Customers
- `GET /customers` (admin) — list semua customer dengan pagination + search
- `GET /customers/my` (sales) — list customer yang di-assign ke sales yang login, dengan search
- `POST /customers` (admin) — buat 1 customer
- `PUT /customers/{id}` (admin) — update customer
- `DELETE /customers/{id}` (admin) — hapus customer
- `POST /customers/{id}/assign` (admin) — body: `{sales_ids: [...]}` set assignment (replace)
- `GET /customers/{id}/assignments` (admin) — list sales yang di-assign
- `POST /customers/import-excel` (admin) — upload `.xlsx`, sama pattern dengan `/products/import-excel`

#### Orders — perubahan & tambahan
- `POST /orders` (sales) — behavior existing, **tapi `customer_id` jadi field wajib** dan default `status` jadi `DRAFT` (lihat catatan di 3.5)
- `PUT /orders/{id}` (sales) — **endpoint baru**: update items & customer info. Hanya bisa kalau `status == DRAFT` dan order milik sales tersebut. Validasi stok: rollback booking lama, apply booking baru (sama logika seperti create).
- `POST /orders/{id}/submit` (sales) — **endpoint baru**: transisi `DRAFT → PENDING`. Hanya bisa kalau status DRAFT dan milik sales. Response sama seperti create.
- `GET /orders/my/stats` (sales) — **endpoint baru**: ringkasan untuk dashboard. Response:
  ```json
  {
    "omset_hari_ini": 2500000,
    "pending_count": 3,
    "selesai_bulan_ini_count": 24,
    "selesai_bulan_ini_total": 18000000
  }
  ```
  Definisi:
  - `omset_hari_ini`: sum dari `(harga_satuan × qty)` untuk order dengan `status=APPROVED` dan `created_at` hari ini (UTC+7, timezone sales). Bisa juga pakai `approved_at` jika backend menambahkan timestamp — untuk versi awal, gunakan `created_at`.
  - `pending_count`: jumlah order dengan `status=PENDING` milik sales tersebut.
  - `selesai_bulan_ini_count` & `_total`: order dengan `status=APPROVED` di bulan berjalan.

- `GET /orders/{id}` — tambahkan field `notes` & `customer_id` di response.

#### Existing — minor
- `GET /orders/my` — pastikan response sudah include `notes`, `customer_id`, dan nama customer (join).
- `POST /orders/{id}/cancel` — tetap, hanya bisa `PENDING`. Sales boleh batalkan PENDING (CANCELLED).
- Existing admin endpoints (`/orders/pending`, `/orders`, `/orders/{id}/approve`, `/orders/{id}/reject`) **tidak berubah**.

### 3.5 Migrasi & Backward Compatibility

1. Tambah kolom baru (`customer_id`, `notes`) dengan `nullable=True` supaya order lama tidak rusak.
2. Existing order yang `store_name`/`store_contact`/`store_address` masih bisa dibaca, tapi order baru **wajib** isi `customer_id`.
3. Ubah default `status` dari `PENDING` ke `DRAFT`. **Namun**, demi backward compatibility untuk mobile lama yang mungkin masih jalan, atau admin-web yang tidak lewat alur draft, **deprecated**: admin tetap bisa create order via `/orders` admin endpoint tanpa draft (tapi tidak dipakai di mobile baru).
4. Tabel `customers` di-seed via import Excel.

### 3.6 Excel Format untuk Customer Import

File `.xlsx` dengan kolom (case-insensitive, header di baris 1-10):

| Kolom Wajib | Kolom Opsional |
|---|---|
| `nama_toko` | `pemilik` |
| | `kontak` |
| | `alamat` |
| | `kategori` |
| | `catatan` |
| | `sales_usernames` (comma-separated, contoh: `"budi,andi"`) |

Logic import:
- Upsert by `nama_toko` (case-insensitive exact match).
- Sync `sales_usernames` ke tabel `customer_sales` (replace assignment).
- Validasi: `sales_usernames` harus ada di tabel users dengan role=SALES, kalau tidak valid → catat sebagai error per baris.

Service baru: `app/services/customer_sync.py` (mirror dari `sheets_sync.py`).

### 3.7 Files Backend yang Akan Berubah/Ditambah

**Berubah:**
- `app/models/models.py` — tambah model `Customer`, `CustomerSales`, field baru di `Order`.
- `app/schemas/schemas.py` — tambah `Customer*`, ubah `OrderStatus`.
- `app/api/endpoints/orders.py` — tambah `PUT`, `POST /submit`, `GET /my/stats`, update `POST /` & `GET /{id}`.
- `app/api/endpoints/products.py` — (tidak berubah, hanya jadi referensi untuk endpoint customer).

**Baru:**
- `app/api/endpoints/customers.py` — endpoint customer.
- `app/services/customer_sync.py` — Excel import logic.
- Migration script: `backend/migrate_add_customers.py` (atau via Alembic kalau di-setup; project ini pakai raw SQL, jadi script manual).

---

## 4. Admin Web Additions

### 4.1 Halaman Sinkronisasi — Customer Import Card

Pada [sync_tab.dart](../../sales-app/admin_web/lib/presentation/screens/sync_tab.dart) (file ini), tambahkan **card kedua** di bawah card "Import Excel" produk, dengan struktur identik:

```
┌─────────────────────────────────────────────┐
│ [icon] Import Toko (Customer)               │
│        Upload .xlsx untuk data toko +       │
│        assignment sales                     │
│                                              │
│ Metode: Upsert                              │
│ Transaksi: Atomic                           │
│ Match: by nama_toko                         │
│ Kolom wajib: nama_toko                      │
│ Kolom opsional: pemilik, kontak, alamat,    │
│                kategori, catatan,            │
│                sales_usernames              │
│                                              │
│ [Pilih File Excel (.xlsx)]                  │
└─────────────────────────────────────────────┘
```

Tambah histori import customer terpisah (atau reuse `_ImportHistorySection` dengan type parameter — untuk versi awal, sediakan section kecil khusus customer agar tidak tercampur dengan histori produk).

### 4.2 Tab Customers (Opsional, untuk melengkapi)

Untuk admin yang ingin manage customer satu-satu tanpa Excel, tambahkan tab "Toko" di admin-web:

- List customer dengan search & filter by kategori / sales.
- Tombol "+ Tambah Toko" → modal form.
- Tap row → edit modal + lihat list sales yang di-assign.
- Toggle assignment per sales.

> **Catatan:** ini opsional untuk MVP. Versi minimum yang wajib: hanya endpoint & import Excel. Tab ini boleh ditambah di iterasi berikutnya.

### 4.3 Files Admin Web yang Akan Berubah/Ditambah

**Berubah:**
- `lib/presentation/screens/sync_tab.dart` — tambah card customer + section histori import customer.
- `lib/data/repositories/admin_repository.dart` — tambah method `importCustomersExcel`, opsional `getCustomers/CRUD`.
- `lib/data/models/customer.dart` (baru) — model customer.

---

## 5. Mobile App Rebuild

### 5.1 Navigasi & Layout Global

Bottom Navigation (4 tab):

```
[ 🏠 Beranda ]  [ 📋 Pesanan ]  [ 📦 Katalog ]  [ ⋯ Lainnya ]
```

Floating Action Button `⊕ Order Baru` muncul di semua tab kecuali saat user sedang di dalam flow order.

### 5.2 Halaman Beranda (Dashboard Sales)

```
┌─────────────────────────────────────────────────────┐
│ Halo, {nama_sales} 👋                  [👤 avatar]  │
│ Sales · {hari, tanggal bulan tahun}                │
│                                                      │
│ ┌──────────────────┐ ┌──────────────────┐          │
│ │ Omset Hari Ini   │ │ Pending          │          │
│ │ Rp {X}           │ │ {n} order        │          │
│ │ ↑ {x}% dari kmrn │ │ nunggu admin     │          │
│ └──────────────────┘ └──────────────────┘          │
│ ┌──────────────────┐ ┌──────────────────┐          │
│ │ Selesai (Bulan)  │ │ ...              │          │
│ │ {n} order        │ │ (slot kosong     │          │
│ │ Rp {X}           │ │  untuk metric    │          │
│ │                  │ │  masa depan)     │          │
│ └──────────────────┘ └──────────────────┘          │
│                                                      │
│ Orderan Terbaru              [Lihat semua →]        │
│ {List 5 orderan terbaru — lihat 5.3}                │
│                                                      │
│ [Beranda] [Pesanan] [Katalog] [Lainnya]  [⊕]      │
└─────────────────────────────────────────────────────┘
```

**Definisi kartu ringkasan (wajib backend support):**
- **Omset Hari Ini**: dari `GET /orders/my/stats` field `omset_hari_ini`.
- **Pending**: dari `GET /orders/my/stats` field `pending_count`.
- **Selesai (Bulan)**: dari `GET /orders/my/stats` field `selesai_bulan_ini_count` & `_total`.
- **Slot ke-4**: kartu placeholder "Segera hadir" — reserved untuk metric masa depan (misal target penjualan).

**State & loading:**
- Pull-to-refresh.
- Skeleton shimmer di 4 kartu saat loading awal.
- Empty state di list "Orderan Terbaru" dengan ilustrasi.

**File/Component:** `lib/presentation/screens/home/home_screen.dart` (rewrite) + `lib/presentation/providers/home_stats_provider.dart` (baru).

### 5.3 Halaman Pesanan

```
┌─────────────────────────────────────────────────────┐
│ Pesanan                                             │
│ ┌─────────────────────────────────────────────┐    │
│ │ 🔍 Cari nomor/order/toko...                  │    │
│ └─────────────────────────────────────────────┘    │
│                                                      │
│ [ Semua ({n}) ] [ Draft ({n}) ] [ Submitted ({n}) ] │
│ [ Dikirim ({n}) ] [ Selesai ({n}) ]                │
│ ──────────────────────────────────────────           │
│                                                      │
│ ┌─────────────────────────────────────────────┐    │
│ │ #ORD-007 · Maju Jaya          [Draft]       │    │
│ │ 3 item · Rp 75.000 · 22 Sep 14:30           │    │
│ ├─────────────────────────────────────────────┤    │
│ │ #ORD-006 · Sumber Rezeki    [Submitted]     │    │
│ │ 2 item · Rp 120.000 · 22 Sep 11:15          │    │
│ └─────────────────────────────────────────────┘    │
│                                          [⊕]      │
└─────────────────────────────────────────────────────┘
```

**Behavior:**
- Default tab: **Semua** (sesuai konfirmasi).
- Tap chip tab → load ulang dengan filter `status`. Counter chip dihitung dari hasil (atau pre-loaded saat first open).
- Tap item **Draft** → buka Flow Order dengan mode edit (prefill).
- Tap item status lain → buka OrderDetailScreen (read-only).
- FAB `⊕ Order Baru` di kanan bawah.
- Search realtime by nomor order atau nama toko.

**Status chip warna:**
| Status mobile | Warna | Hex (acak, samakan dengan design_system) |
|---|---|---|
| Draft | Kuning outline | `warning` |
| Submitted | Biru muda | `info` |
| Dikirim | Biru tua | `primary` |
| Selesai | Hijau | `success` |
| Dibatalkan | Abu/merah | `error` |

**File/Component:** `lib/presentation/screens/orders/order_list_screen.dart` (rewrite dari `order_history_screen.dart`) + provider reuse `OrderProvider`.

### 5.4 Halaman Katalog

(Tidak banyak berubah dari existing `product_catalog_screen.dart`, hanya restyle grid supaya konsisten dengan design baru.)

### 5.5 Halaman Order Detail (Read-only)

```
┌─────────────────────────────────────────────────────┐
│ [←]   Detail Order                  #ORD-005        │
│                                                      │
│ Status: [Dikirim]                                    │
│ Tanggal: 21 Sep 2026 · 16:45                         │
│                                                      │
│ Toko                                                 │
│ 🏪 Warung Barokah                                    │
│ 📍 Jl. Pattimura No. 8, Surabaya                    │
│                                                      │
│ Produk (5)                                           │
│ ┌──────────────────────────────────────────────┐   │
│ │ Produk A × 2        Rp 30.000                │   │
│ │ Produk B × 1        Rp 8.500                 │   │
│ │ ...                                          │   │
│ └──────────────────────────────────────────────┘   │
│                                                      │
│ Total                       Rp 82.500                │
│                                                      │
│ Catatan: "Tolong kirim sebelum jam 12"              │
└─────────────────────────────────────────────────────┘
```

**File/Component:** `lib/presentation/screens/orders/order_detail_screen.dart` (baru).

### 5.6 Flow Order (Step 1 → 2 → 3)

**Ini adalah halaman modal** (full screen dengan tombol "Batal" / close). Dipakai untuk:
1. Buat order baru (entry dari FAB atau empty state).
2. Edit draft (entry dari tab Pesanan → tap item Draft).

#### Step 1 — Pilih Toko

```
┌─────────────────────────────────────────────────────┐
│ [X]   Order Baru              Step 1/3               │
│ ●━━━━○━━━━○                                          │
│ Toko  Produk  Review                                │
│                                                      │
│ Pilih Toko                                           │
│ ┌────────────────────────────────────────────┐      │
│ │ 🔍 Cari nama toko...                       │      │
│ └────────────────────────────────────────────┘      │
│                                                      │
│ Toko yang sering order                              │
│ ┌────────────────────────────────────────────┐      │
│ │ 🏪 Toko Maju Jaya                          │      │
│ │    Jl. Sudirman No. 12                     │      │
│ ├────────────────────────────────────────────┤      │
│ │ 🏪 Toko Sumber Rezeki                      │      │
│ │    Jl. Thamrin No. 5                       │      │
│ └────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────┘
```

- Data dari `GET /customers/my`.
- Search realtime (filter client-side, atau backend support query).
- Tap toko → simpan `customerId` di DraftOrderProvider → push ke Step 2.

#### Step 2 — Pilih Produk

```
┌─────────────────────────────────────────────────────┐
│ [←]   Order Baru              Step 2/3               │
│ Toko: Maju Jaya                       [Ganti ▼]     │
│                                                      │
│ ┌────────────────────────────────────────────┐      │
│ │ 🔍 Cari produk...                          │      │
│ └────────────────────────────────────────────┘      │
│                                                      │
│ ┌────────────────────────────────────────────┐      │
│ │ [img] Produk A                  [- 2 +]    │      │
│ │       Rp 15.000 · Stok: 120                │      │
│ ├────────────────────────────────────────────┤      │
│ │ [img] Produk B                  [- 0 +]    │      │
│ │       Rp 8.500 · Stok: 45                 │      │
│ └────────────────────────────────────────────┘      │
│                                                      │
│ ┌─ Sticky Bottom ───────────────────────────┐       │
│ │  3 item · Rp 161.000      [Lanjut →]      │       │
│ └───────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────┘
```

- Stepper per produk, default 0.
- Tombol "Ganti ▼" kembali ke Step 1 (data Step 2 tidak hilang).
- Tombol "Lanjut" disabled kalau total item == 0.

#### Step 3 — Review & Submit

```
┌─────────────────────────────────────────────────────┐
│ [←]   Order Baru              Step 3/3               │
│                                                      │
│ Toko                                       [Ganti]   │
│ 🏪 Maju Jaya                                        │
│    Jl. Sudirman No. 12                              │
│                                                      │
│ Produk (3)                                           │
│ ┌────────────────────────────────────────────┐      │
│ │ Produk A × 2        Rp 30.000      [🗑]   │      │
│ │ Produk B × 5        Rp 42.500      [🗑]   │      │
│ │ [+ Tambah Produk]                          │      │
│ └────────────────────────────────────────────┘      │
│                                                      │
│ Catatan (opsional)                                   │
│ ┌────────────────────────────────────────────┐      │
│ │ Tulis catatan untuk order ini...           │      │
│ └────────────────────────────────────────────┘      │
│                                                      │
│ Total                       Rp 72.500               │
│                                                      │
│ ┌───────────────────────────────────────────┐       │
│ │ [Simpan Draft]    [Kirim Order →]         │       │
│ └───────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────┘
```

**Simpan Draft**:
- Panggil `POST /orders` dengan `status=DRAFT` (atau `PUT /orders/{id}` kalau edit).
- Stok tidak di-booking (booking hanya saat submit) — untuk efisiensi backend, **draft boleh di-booking ringan** atau tidak sama sekali. **Putusan awal: tidak booking stok untuk draft**, supaya draft bisa dibuat tanpa mempengaruhi stok. Stok baru di-booking saat transisi ke PENDING via `POST /submit`.
- Setelah sukses → tutup flow, kembali ke tab Pesanan dengan snackbar "Draft disimpan".

**Kirim Order**:
- Kalau dari order baru (belum ada `orderId`): `POST /orders` dengan status PENDING (atau `POST /orders` draft dulu lalu `POST /submit`). **Putusan awal: 1 call `POST /orders` dengan status PENDING langsung**, abaikan alur draft di kasus ini.
- Kalau dari edit draft: `POST /orders/{id}/submit`.
- Setelah sukses → tutup flow, kembali ke tab Pesanan (data refresh) dengan snackbar "Order berhasil dikirim".

**Hapus Order** (khusus mode edit draft):
- Ikon tempat sampah di header Step 3, dengan konfirmasi. Panggil `DELETE /orders/{id}` (perlu endpoint baru — lihat catatan di 5.10).

### 5.7 Edit Draft Mode

Flow Order yang sama, dengan perbedaan:
- Step 1: toko sudah prefill (tapi tetap bisa diganti).
- Step 2: produk sudah prefill dengan qty existing.
- Step 3: ada tombol "Hapus Order" (danger) di header.
- Step 3 "Simpan Draft" → panggil `PUT /orders/{id}` (update).
- Step 3 "Kirim Order" → panggil `POST /orders/{id}/submit` (transisi ke PENDING).

### 5.8 Halaman Lainnya

```
┌─────────────────────────────────────────────────────┐
│ Lainnya                                              │
│                                                      │
│ ┌─────────────────────────────────────────────┐    │
│ │  [👤]  {nama_sales}                         │    │
│ │        Sales · ID: {kode_sales}              │    │
│ └─────────────────────────────────────────────┘    │
│                                                      │
│ ┌─────────────────────────────────────────────┐    │
│ │ 👤  Profil Saya                          → │    │
│ ├─────────────────────────────────────────────┤    │
│ │ ❓  Bantuan                              → │    │
│ │     (placeholder: hubungi admin di ...)      │    │
│ ├─────────────────────────────────────────────┤    │
│ │ 🚪  Keluar     (warna merah)             ⏏ │    │
│ └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

- **Profil Saya**: layar read-only dengan field nama, username, role, info tambahan kalau ada di JWT/endpoint profil.
- **Bantuan**: static page placeholder. Konten minimum: "Untuk bantuan, hubungi admin di {kontak}" (nomor HP/email di-hardcode dulu atau via config).
- **Keluar**: dialog konfirmasi → kembali ke LoginScreen (pakai pattern dari kode lama).

### 5.9 Struktur File Baru di Mobile

```
lib/
├── core/
│   ├── config.dart (sudah ada, tidak banyak berubah)
│   ├── design_system.dart (sudah ada, mungkin tambah warna chip status)
│   └── ...
├── data/
│   ├── models/
│   │   ├── customer.dart (BARU)
│   │   ├── order.dart (UBAH — tambah notes, customerId, customerName)
│   │   ├── product.dart (sudah ada)
│   │   └── cart_item.dart (mungkin jadi obsolete, lihat 5.10)
│   └── repositories/
│       ├── api_service.dart (sudah ada)
│       ├── auth_repository.dart (sudah ada)
│       ├── customer_repository.dart (BARU)
│       ├── order_repository.dart (UBAH — tambah updateOrder, submitOrder, getStats, deleteOrder)
│       └── product_repository.dart (sudah ada)
├── presentation/
│   ├── providers/
│   │   ├── auth_provider.dart (sudah ada)
│   │   ├── cart_provider.dart (mungkin obsolete — lihat 5.10)
│   │   ├── draft_order_provider.dart (BARU — state untuk flow order)
│   │   ├── home_stats_provider.dart (BARU)
│   │   ├── order_provider.dart (UBAH)
│   │   └── product_provider.dart (sudah ada)
│   └── screens/
│       ├── auth/login_screen.dart (sudah ada)
│       ├── home/home_screen.dart (REWRITE)
│       ├── orders/
│       │   ├── order_list_screen.dart (REWRITE dari order_history_screen)
│       │   └── order_detail_screen.dart (BARU)
│       ├── products/product_catalog_screen.dart (REWRITE — restyle)
│       ├── order_flow/
│       │   ├── order_flow_screen.dart (BARU — handle 3 step dalam 1 widget tree)
│       │   ├── step_pick_customer.dart (BARU)
│       │   ├── step_pick_products.dart (BARU)
│       │   └── step_review.dart (BARU)
│       └── misc/misc_screen.dart (BARU — halaman Lainnya)
└── main.dart (UBAH — provider setup, routing)
```

### 5.10 Catatan Tambahan / Resolusi Teknis

1. **Cart lama (`CartProvider`, `CartScreen`, `cart_item.dart`)** — flow baru tidak butuh keranjang terpisah. Step 2 langsung pilih qty per produk dan disimpan di `DraftOrderProvider`. Cart lama **dihapus**.
2. **Delete draft order** — endpoint `DELETE /orders/{id}` belum ada di backend. Tambahkan di spec backend (3.4), hanya boleh kalau status DRAFT.
3. **Halaman Katalog terpisah** — di design baru, Katalog adalah tab navigasi. Pertanyaan: apakah user masih butuh halaman ini, atau cukup Step 2 yang sudah punya list produk? **Putusan awal: tetap ada tab Katalog** untuk browsing cepat tanpa harus masuk flow order. Implementasi: reuse `ProductCatalogScreen` yang sudah ada.
4. **Foto produk** — di model existing belum ada field image. Step 2 menampilkan `[img]` placeholder dulu. Image bisa jadi iterasi berikutnya.
5. **Customer field tambahan** — saat ini design tidak menampilkan field `pemilik`, `kategori`, `catatan` di UI mobile (hanya `nama_toko`, `kontak`, `alamat`). Cukup untuk MVP; sisanya di admin-web.

### 5.11 State Management Pattern

Tetap pakai `provider` (sudah ada, tidak perlu tambah dependency). Pola:

- **`DraftOrderProvider`** (ChangeNotifier) — single source of truth untuk flow order:
  ```dart
  class DraftOrderProvider extends ChangeNotifier {
    String? customerId;
    String? customerName;
    Map<String, int> items = {};  // productId -> qty
    String notes = '';
    String? editingOrderId;  // null = new, non-null = editing existing draft
    
    void reset();
    void setCustomer(Customer c);
    void setQty(String productId, int qty);
    void setNotes(String notes);
    void loadFromDraft(Order draft);
    bool get hasItems => items.values.any((q) => q > 0);
    int get totalItems => items.values.fold(0, (a, b) => a + b);
    int get totalPrice => ...;  // hitung dari katalog price
  }
  ```

- **`OrderProvider`** — list, detail, submit, delete, update.
- **`HomeStatsProvider`** — data dashboard (omset, pending, selesai).

---

## 6. Error Handling

### Mobile
- Tiap provider expose `errorMessage`. UI render via SnackBar.
- Empty state di setiap list (Pesanan, Orderan Terbaru, Step 1 toko kosong).
- Pull-to-refresh di Beranda & Pesanan.
- Network error → SnackBar + tombol retry di list.
- Token expired → handler di `ApiService.onTokenExpired` (sudah ada, pattern reuse).

### Backend
- 400 untuk validasi (misal qty <= 0, customer bukan assigned).
- 403 untuk akses yang tidak sah.
- 404 untuk resource tidak ditemukan.
- 409 untuk konflik stok (pattern sudah ada di `POST /orders`).
- 422 untuk perubahan status yang tidak valid (misal edit order bukan DRAFT).

---

## 7. Testing Strategy

### Backend
- **Unit test** untuk service baru (`customer_sync.py`): parsing Excel, validasi baris, error reporting.
- **Integration test** untuk endpoint baru: `PUT /orders/{id}` validasi status, `POST /orders/{id}/submit` transisi, `GET /orders/my/stats` filtering by sales & date.
- **Regression test** untuk endpoint existing yang berubah (POST /orders dengan status DRAFT default).

### Mobile
- **Widget test** untuk flow step (Step 1 → Step 2 → Step 3 → Submit). Mock API service.
- **Widget test** untuk filter tab Pesanan.
- **Widget test** untuk chip status & tap navigation.
- **Unit test** untuk `DraftOrderProvider`: setQty, totalPrice, loadFromDraft, reset.

### Admin Web
- **Widget test** untuk card Import Customer.
- **Manual test** untuk upload Excel + cek assignment ter-update.

---

## 8. Out of Scope / Future Work

- Status `COMPLETED` (alur cukup sampai APPROVED + cetak struk).
- Image produk di mobile.
- Notifikasi push untuk sales.
- Offline mode / draft sync.
- Multi-bahasa.
- Refactor admin-web di luar sinkronisasi.

---

## 9. Open Questions

1. **Backend timezone untuk `omset_hari_ini`** — pakai UTC atau UTC+7 (WIB)? Default usulan: WIB (sesuai zona sales). Perlu konfirmasi.
2. **Customer delete behavior** — kalau customer dihapus tapi punya order history, hard delete atau soft delete (flag `is_deleted`)? Usulan: hard delete OK karena `customer_id` di order hanya nullable foreign reference; order history tetap punya `store_name` snapshot.
3. **Penomoran order** — saat ini order ID adalah UUID (`ORD-XXX` sepertinya hanya display). Apakah perlu penomoran yang lebih readable (`ORD-YYYYMMDD-NNNN`)? Di luar scope rebuild kecuali user minta.

---

## 10. Ringkasan Perubahan per Repo

| Repo | Jenis | File |
|---|---|---|
| backend | Ubah | `app/models/models.py`, `app/schemas/schemas.py`, `app/api/endpoints/orders.py` |
| backend | Baru | `app/api/endpoints/customers.py`, `app/services/customer_sync.py`, migration script |
| admin_web | Ubah | `lib/presentation/screens/sync_tab.dart`, `lib/data/repositories/admin_repository.dart` |
| admin_web | Baru | `lib/data/models/customer.dart` (+ opsional `customers_tab.dart`) |
| sales-app (mobile) | Ubah | `lib/main.dart`, `lib/data/models/order.dart`, `lib/data/repositories/order_repository.dart`, `lib/presentation/providers/order_provider.dart` |
| sales-app (mobile) | Baru | `lib/data/models/customer.dart`, `lib/data/repositories/customer_repository.dart`, `lib/presentation/providers/draft_order_provider.dart`, `lib/presentation/providers/home_stats_provider.dart`, `lib/presentation/screens/orders/order_list_screen.dart`, `lib/presentation/screens/orders/order_detail_screen.dart`, `lib/presentation/screens/order_flow/*.dart`, `lib/presentation/screens/misc/misc_screen.dart` |
| sales-app (mobile) | Hapus | `lib/presentation/screens/cart/cart_screen.dart`, `lib/presentation/providers/cart_provider.dart`, `lib/data/models/cart_item.dart`, `lib/presentation/screens/orders/order_history_screen.dart` (diganti `order_list_screen.dart`) |

---

## 11. Urutan Eksekusi yang Disarankan

1. **Backend**: Tambah entity Customer + assignment + migration.
2. **Backend**: Tambah kolom `customer_id`, `notes` di orders.
3. **Backend**: Ubah default status → `DRAFT`, tambah `PUT /orders/{id}`, `POST /orders/{id}/submit`, `DELETE /orders/{id}`, `GET /orders/my/stats`.
4. **Backend**: Endpoint customers + Excel import.
5. **Admin web**: Card Import Customer di sync_tab.dart + (opsional) tab Customers.
6. **Mobile**: Tambah `CustomerRepository`, `DraftOrderProvider`, `HomeStatsProvider`.
7. **Mobile**: Rewrite `HomeScreen` jadi dashboard.
8. **Mobile**: Rewrite `OrderListScreen` + `OrderDetailScreen`.
9. **Mobile**: Buat Flow Order (3 step) + integrasi dengan provider.
10. **Mobile**: Hapus CartProvider & CartScreen.
11. **Mobile**: Buat halaman Lainnya.
12. **End-to-end test**: alur sales bikin order → submit → admin approve → sales lihat status Dikirim.
