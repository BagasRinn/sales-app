# Supabase Egress Reduction Plan

> Plan ini menurunkan **uncached egress** ke Supabase (lonjakan 15 Okt 2026 ≈ 250 MB/hari vs normal 0-50 MB/hari) dengan kombinasi **client-side debounce/caching** (mobile + admin_web) dan **backend N+1 elimination + connection pool** — tanpa mengubah API response shape.

**Tanggal:** 2026-10-17
**Scope:** `sales-app/lib/**` (mobile), `sales-app/admin_web/lib/**` (admin), `sales-app/backend/app/**` (Python)
**Backend API:** TIDAK BERUBAH (API shape frozen — tidak tambah param wajib, tidak kurangi field).
**Git:** User commit manual — plan ini tidak menyertakan langkah git.

---

## 0. Keputusan User (locked in)

| # | Topik | Keputusan |
|---|---|---|
| 1 | Backend API shape | **Frozen.** Hanya optimasi di sisi dalam (query batching, pool). Tidak tambah `?limit=`/`?skip=`/`?fields=` di endpoint manapun. |
| 2 | Strategi pagination | **Client-side.** Kalau list sudah ditarik 3000 baris, paginasi/filter di klien. Tidak paksa backend paginasi. |
| 3 | Realtime | **Tidak dipakai** (hasil audit: zero `channel()`/`stream()` di codebase). Fokus ke HTTP polling. |
| 4 | Image compression | **Out of scope** untuk plan ini. Tidak ada upload foto produk/avatar. Hanya bulletin PDF yang sudah jarang berubah. |
| 5 | Test backend | **Tetap pakai pytest** di `sales-app/backend/tests/`. Tests yang insert row wajib cleanup sebelum exit (lihat `live-db-test-cleanup.md`). |
| 6 | Test mobile Flutter | **Skip test infrastructure untuk `lib/`.** Sales-app mobile belum punya direktori `test/` (hanya `admin_web/test/widgets/` yang ada). Plan ini melindungi perilaku via dev-server manual + log egress. |
| 7 | Server-side pagination | **Additive only.** Tambah `?limit=&offset=` sebagai **param opsional** (default = tidak ada = kembalikan semua, 100% backward compat). Frontend boleh pakai atau tidak. Memory `api-shape-frozen` tetap dihormati karena tidak ada breaking change. |
| 8 | Excel report strategy | **Pisah endpoint**: `/reports/summary` (agregat via SQL, hanya summary) + `/reports/daily` & `/reports/period` jadi **opt-in detail** (`?detail=true`, default `false` = summary saja). Validasi rentang tanggal. |

**Execution rules:**
- 1 phase = 1 commit (user commit manual).
- Verifikasi per fase via: (a) `flutter run` di mobile/admin, (b) jalankan pytest di backend, (c) observasi grafik egress Supabase sebelum & sesudah fase.
- Setiap fase harus ada summary: file berubah/baru, perkiraan reduksi egress, langkah verifikasi.

---

## 1. Ringkasan & Tujuan

Hasil audit 2026-10-17 menemukan 7 kategori anti-pattern. Tiga yang paling berdampak:

| # | Anti-pattern | File | Egress impact |
|---|---|---|---|
| A | `step_pick_customer` fetch `/customers/my` (limit 3000) **tiap keystroke** tanpa debounce | `lib/presentation/screens/order_flow/step_pick_customer.dart:88-92` | Sangat tinggi — single mobile pattern paling boros |
| B | `product_provider` fire `loadProducts()` **tiap perubahan filter** tanpa debounce | `lib/presentation/providers/product_provider.dart:199-228` | Tinggi |
| C | `admin_provider.approveOrder/rejectOrder/cancelOrderItem` panggil `loadAll()` (5 query paralel) **tiap mutasi 1 order** | `admin_web/lib/presentation/providers/admin_provider.dart:835-877` | Tinggi |

Penyebab lonjakan 15 Okt paling mungkin: **kombinasi A+B+C** sepanjang hari + kemungkinan user run laporan Excel wide-date (`/reports/daily` atau `/reports/period` dengan rentang lebar, lihat [reports.py:99-313](sales-app/backend/app/api/endpoints/reports.py#L99-L313)).

**Outcome yang diharapkan:**
- Mobile fetch customer **turun 80-95%** (debounce + cache).
- Admin `loadAll` calls **turun 70%** (skip refetch on mutation).
- Backend per-request overhead **turun 30-50%** (pool reuse, N+1 eliminated).
- Egress harian ke Supabase: target **< 50 MB/hari** kecuali ada export laporan wide-range.

---

## 2. Phase 1 — Mobile Search Debounce (HIGH impact, 1 fase)

**Tujuan:** Hapus fetch berulang di mobile saat user mengetik/memfilter.

**File baru:**
- `sales-app/lib/core/utils/debouncer.dart` — utilitas `Debouncer` (Timer-based)

**File diubah:**
- `sales-app/lib/presentation/screens/order_flow/step_pick_customer.dart` (line 44-92)
- `sales-app/lib/presentation/providers/product_provider.dart` (line 199-228)

### Task 1.1 — Tambah `Debouncer` di mobile

**File:** `sales-app/lib/core/utils/debouncer.dart`

API:
```dart
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 300)});
  final Duration delay;
  Timer? _timer;
  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }
  void dispose() { _timer?.cancel(); _timer = null; }
}
```

**Verifikasi manual:** Di `main.dart` atau smoke test, instantiate `Debouncer`, panggil 3× dalam 100ms, tunggu 400ms — callback fire 1× dengan argumen terakhir. Lalu `dispose()` — callback berikutnya tidak fire.

### Task 1.2 — Debounce `step_pick_customer` search

**File:** `sales-app/lib/presentation/screens/order_flow/step_pick_customer.dart`

- Tambah field `final _searchDebouncer = Debouncer(delay: Duration(milliseconds: 350));`
- Di `_onSearchChanged(String value)`, ganti direct call ke `_load()` dengan `_searchDebouncer(() => _load(search: value))`.
- Tambah `search` parameter ke `_load()` jika belum ada. Implementasinya: panggil endpoint existing (saat ini load semua 3000 customers) lalu filter di sisi klien dengan `customers.where((c) => c.name.toLowerCase().contains(value.toLowerCase()))` SEBELUM set ke `state`.
- `dispose()`: panggil `_searchDebouncer.dispose()`.

**Verifikasi manual:**
1. `flutter run -d <device>` di mobile.
2. Buka Order Flow → Pilih Customer.
3. Ketik 5 huruf dalam 1 detik.
4. Buka **DevTools → Network tab**, hitung request ke `/customers/my` (atau endpoint customer list). Harusnya **1 request** (bukan 5).
5. Inspect list yang ditampilkan: harusnya terfilter sesuai 5 huruf yang diketik.

### Task 1.3 — Debounce `product_provider` filter

**File:** `sales-app/lib/presentation/providers/product_provider.dart`

- Tambah field `final _filterDebouncer = Debouncer(delay: Duration(milliseconds: 350));`
- Di `search/clearSearch/setStatusFilter/setCategoryFilter/clearFilters` (line 199-228): bungkus `loadProducts()` dengan `_filterDebouncer(loadProducts)`.
- Implementasi filter (search/status/category): **saring dari `_allProducts` cache di klien** setelah fetch pertama. Pattern:
  - Field `List<Product> _allProducts = []` di provider.
  - `loadProducts()` hanya fire kalau `_allProducts.isEmpty` ATAU `forceRefresh == true`.
  - Setelah fetch, set `_allProducts` lalu apply filter lokal → set ke state.
  - Method `search/filter` TIDAK panggil `loadProducts()`, hanya re-apply filter ke `_allProducts`.
- `dispose()`: panggil `_filterDebouncer.dispose()`.

**Verifikasi manual:**
1. Mobile → Product Catalog.
2. Ketik "prod" di search, ganti ke "pro", "p" dalam 1 detik.
3. Network tab: harusnya 1 request (atau 0 kalau cache hit), bukan 3.
4. Tap filter kategori 3×: harusnya 0 request tambahan.

---

## 3. Phase 2 — Admin Web Debounce + Stop Refetch on Mutation (HIGH impact, 1 fase)

**Tujuan:** Hapus fetch berulang di admin dan hentikan full-refetch saat satu order di-approve/reject/cancel.

**File baru:**
- `sales-app/admin_web/lib/core/utils/debouncer.dart` — copy `Debouncer` (atau import shared package; default: duplicate, 30 baris)

**File diubah:**
- `sales-app/admin_web/lib/presentation/providers/admin_provider.dart` (line 216-265, 741-770, 835-877)
- `sales-app/admin_web/lib/presentation/screens/orders_tab.dart` (line 50-101)

### Task 2.1 — Tambah `Debouncer` di admin_web

**File:** `sales-app/admin_web/lib/core/utils/debouncer.dart`

Sama persis dengan `lib/core/utils/debouncer.dart` di mobile. Default `delay: 400ms` (sedikit lebih panjang untuk admin, biar tidak fetchnya terlalu agresif).

### Task 2.2 — Debounce `orders_tab` search

**File:** `sales-app/admin_web/lib/presentation/screens/orders_tab.dart`

- Field: `final _searchDebouncer = Debouncer(delay: Duration(milliseconds: 400));`
- Cari `onChanged: (v) => _applyFilters()` di TextField search. Ganti dengan `onChanged: (v) => _searchDebouncer(() => _applyFilters())`.
- Filter dropdown (status, tanggal, dll) **tidak di-debounce** — perubahan dropdown biasanya final.
- `dispose()`: panggil `_searchDebouncer.dispose()`.

**Verifikasi manual:**
1. Admin → tab Pesanan.
2. Ketik 6 huruf search dalam 1 detik.
3. Network tab: harusnya 1 request `loadAllOrders` + 1 `loadPendingOrders` (atau sesuai debounce policy), bukan 6.

### Task 2.3 — Stop `loadAll()` di `approveOrder/rejectOrder/cancelOrderItem`

**File:** `sales-app/admin_web/lib/presentation/providers/admin_provider.dart`

Saat ini `approveOrder` (line ~835) panggil `await loadAll()` setelah mutasi. Ganti dengan **local state update**:

```dart
Future<void> approveOrder(String orderId) async {
  await _apiService.approveOrder(orderId);
  // Update local state — TIDAK fetch ulang
  final idx = _orders.indexWhere((o) => o.id == orderId);
  if (idx != -1) {
    _orders[idx] = _orders[idx].copyWith(status: 'approved', updatedAt: DateTime.now());
  }
  _pendingOrders.removeWhere((o) => o.id == orderId);
  if (_stats != null) _stats = _stats.copyWith(pendingCount: _stats.pendingCount - 1);
  notifyListeners();
}
```

Pola yang sama untuk `rejectOrder` dan `cancelOrderItem`:
- `rejectOrder`: update `_orders[idx].status = 'rejected'`, hapus dari pending, decrement counter.
- `cancelOrderItem`: update item dalam order, recompute total di order itu saja, **TIDAK fetch ulang customers/products**.

**Catatan:** Endpoint backend harus return updated `Order` (cek `PUT /orders/{id}/cancel-item` di [orders.py](sales-app/backend/app/api/endpoints/orders.py)). Kalau return value sudah lengkap, pakai itu untuk update lokal. Kalau tidak, optimistically update dengan field yang jelas berubah saja.

**Verifikasi manual:**
1. Admin → Pesanan.
2. Klik "Approve" pada 1 order.
3. Network tab: harusnya 1 request ke `approveOrder` endpoint, **bukan 5 request loadAll()** (orders + pending + customers + products + stats).
4. UI harus update: order pindah dari "Menunggu" ke "Disetujui", counter pending turun, tanpa refresh manual.

### Task 2.4 — Skip auto-refresh saat tab tersembunyi

**File:** `sales-app/admin_web/lib/presentation/providers/admin_provider.dart` (line 216-265)

`_autoRefreshTimer.tick` saat ini selalu fire 3 fetch. Ganti dengan:

```dart
void _onAutoRefreshTick() {
  // Skip kalau tab tersembunyi (user pindah ke tab lain)
  if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
    return;
  }
  _loadPendingOrders();
  _loadStats();
  _loadCustomerSubmissions();
}
```

`AdminProvider` (atau `DashboardScreen`) implement `WidgetsBindingObserver`. Override `didChangeAppLifecycleState` → kalau `paused/hidden`, set flag `isPageVisible = false`; kalau `resumed`, set `true` dan trigger 1 immediate refresh (sehingga data tidak stale saat user balik).

**Verifikasi manual:**
1. Admin dashboard terbuka, auto-refresh 30s berjalan.
2. Pindah ke tab browser lain (atau minimize window) selama 2 menit.
3. Network tab: harusnya **0 request** selama 2 menit (sebelumnya: ~4 request).
4. Balik ke tab: 1 immediate refresh fire, data up-to-date.

---

## 4. Phase 3 — Backend N+1 Elimination (MEDIUM impact, 1 fase)

**Tujuan:** Hapus pola `for item in items: db.query(Product)` di order create/update.

**File diubah:**
- `sales-app/backend/app/api/endpoints/orders.py` (line 465-519, 772-806)

### Task 3.1 — Batched `Product` lookup di `POST /orders`

**File:** `sales-app/backend/app/api/endpoints/orders.py` (line 465-484 + 509-519)

Saat ini ada **dua loop** yang query `Product` per-item (untuk validasi `order_type` lalu untuk baca harga). Refactor:

```python
# Sebelum order dibuat:
product_ids = {item.product_id for item in order_req.items}
products = db.query(Product).filter(Product.id.in_(product_ids)).all()
product_map = {p.id: p for p in products}

# Loop pertama (validasi order_type):
for item in order_req.items:
    p = product_map.get(item.product_id)
    if not p: raise HTTPException(404, ...)
    if p.order_type != item.order_type: raise HTTPException(400, ...)

# Loop kedua (pricing):
for item in order_req.items:
    p = product_map[item.product_id]
    item.price = p.harga_jual  # atau sesuai field
```

**Test:** Tambah `tests/api/endpoints/test_orders_create.py::test_create_order_uses_batched_product_query`. Spy pada `db.query(Product)` (gunakan `unittest.mock.patch` atau `query_counter` fixture) — assert dipanggil **1×** (bukan 2×N). Assert response tetap 201 + items berisi harga benar.

**Cleanup:** Test yang insert Order/OrderItem/Product wajib hapus row-nya sebelum exit (lihat memory `live-db-test-cleanup.md`). Pakai `try/finally` atau fixture `autouse=True` dengan rollback.

**Verifikasi:**
1. `cd sales-app/backend && pytest tests/api/endpoints/test_orders_create.py -v`
2. Expected: PASS
3. Cek log Supabase: per create order, query count ke tabel `products` turun dari `2 × N` ke `1`.

### Task 3.2 — Batched `Product` lookup di `PUT /orders/{id}`

**File:** `sales-app/backend/app/api/endpoints/orders.py` (line 772-806)

Pola yang sama dengan Task 3.1. Test: `tests/api/endpoints/test_orders_update.py::test_update_order_uses_batched_product_query`.

**Cleanup:** Test insert Order/Item/Product wajib hapus sebelum exit.

**Verifikasi:** `pytest tests/api/endpoints/test_orders_update.py -v`

---

## 5. Phase 4 — Backend Connection Pool (MEDIUM impact, 1 fase)

**Tujuan:** Ganti `NullPool` (per-request TCP+TLS handshake) dengan pool reuse.

**File diubah:**
- `sales-app/backend/app/models/database.py` (line 25-29)

### Task 4.1 — Ganti NullPool dengan connection pool

**File:** `sales-app/backend/app/models/database.py`

```python
# Sebelum:
from sqlalchemy.pool import NullPool
engine = create_engine(DATABASE_URL, poolclass=NullPool, ...)

# Sesudah:
engine = create_engine(
    DATABASE_URL,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,    # deteksi koneksi stale
    pool_recycle=3600,     # recycle tiap 1 jam
    ...
)
```

**Test:** `tests/test_database_pool.py::test_engine_uses_connection_pool`:
```python
from app.models.database import engine
assert engine.pool.size() >= 1
```

**Verifikasi:**
1. `pytest tests/test_database_pool.py -v` — PASS
2. Manual: jalankan backend, lakukan 50 request berurutan via `hey -n 50 -c 5 http://localhost:8000/health`. Cek timing: harusnya makin cepat setelah warmup, bukan tetap konstan.

---

## 6. Phase 5 — Excel Report Optimization (HIGH impact, 1 fase)

**Tujuan:** Turunkan egress dari `/reports/daily` dan `/reports/period` (penyebab parsial lonjakan 15 Okt) dengan pisah summary vs detail, dan agregat via SQL.

**File baru:**
- `sales-app/backend/app/api/endpoints/reports.py` — tambah endpoint `GET /reports/summary` (pure SQL aggregation, no row fetch)

**File diubah:**
- `sales-app/backend/app/api/endpoints/reports.py` (line 99-313) — `/reports/daily` & `/reports/period` jadi opt-in detail
- `sales-app/admin_web/lib/presentation/screens/stats_tab.dart` (line 114-233) — pakai endpoint summary by default, detail via toggle

### Task 5.1 — Endpoint baru `GET /reports/summary` (agregat SQL)

**File:** `sales-app/backend/app/api/endpoints/reports.py`

Response schema (Pydantic):
```python
class ReportSummary(BaseModel):
    period_start: date
    period_end: date
    total_orders: int
    total_revenue: Decimal
    total_items_sold: int
    by_status: dict[str, int]            # {"approved": 100, "rejected": 5, ...}
    by_product: list[TopProduct]         # top 20 by revenue
    by_sales: list[TopSales]             # top 20 by revenue
    by_branch: list[BranchTotal]         # per-branch breakdown
```

Query: **satu query SQL dengan GROUP BY** via SQLAlchemy `func.count`, `func.sum`. **TIDAK ada `joinedload`** dan **TIDAK ada `.all()` pada Order**. Bukti di test dengan query counter.

**Test:** `tests/api/endpoints/test_reports_summary.py::test_summary_uses_aggregation_not_joinedload`. Spy pada query log → harusnya ≤ 5 query (1 per GROUP BY), bukan N query (1 per order).

**Cleanup:** Test insert Order wajib hapus sebelum exit.

**Verifikasi:**
1. `pytest tests/api/endpoints/test_reports_summary.py -v` — PASS
2. Manual: `curl /reports/summary?start=2026-10-01&end=2026-10-17` — payload < 50KB (vs `/reports/daily` sebelumnya ~500KB-2MB).

### Task 5.2 — `/reports/daily` & `/reports/period` jadi opt-in detail

**File:** `sales-app/backend/app/api/endpoints/reports.py` (line 99-313)

Tambah param query:
```python
@router.get("/reports/daily")
def daily(
    date: date,
    detail: bool = Query(False, description="Include per-order rows; default = summary only"),
    ...
):
    if not detail:
        return _build_summary(date, date)   # reuse dari Task 5.1
    # else: existing joinedload logic, unchanged
```

Backward compat: existing caller yang tidak kirim `detail=true` akan dapat summary (ringan). Caller yang butuh detail harus eksplisit pakai `?detail=true`.

**Test:** `tests/api/endpoints/test_reports_daily.py::test_daily_default_returns_summary`. Assert response tidak punya field `orders` (array), hanya summary fields.

**Verifikasi:**
1. `pytest tests/api/endpoints/test_reports_daily.py -v` — PASS
2. Existing caller (kalau ada) yang sebelumnya hit endpoint tanpa `detail=true` — cek tidak break.

### Task 5.3 — Validasi rentang tanggal

**File:** `sales-app/backend/app/api/endpoints/reports.py` (line 99-313)

```python
@router.get("/reports/daily")
def daily(date: date, ...):
    # date is single day, no range validation needed
    ...

@router.get("/reports/period")
def period(start: date, end: date, ...):
    if (end - start).days > 365:
        raise HTTPException(400, "Period max 365 days")
    ...

@router.get("/reports/summary")
def summary(start: date, end: date, ...):
    if (end - start).days > 365:
        raise HTTPException(400, "Period max 365 days")
    ...
```

**Test:** `tests/api/endpoints/test_reports_period.py::test_period_rejects_over_365_days` — assert 400.

**Verifikasi:** `pytest tests/api/endpoints/test_reports_period.py -v` — PASS

### Task 5.4 — Frontend `stats_tab.dart` pakai summary by default

**File:** `sales-app/admin_web/lib/presentation/screens/stats_tab.dart` (line 114-233)

- `_downloadReport()` → ganti endpoint ke `/reports/summary?start=&end=`. Backend yang handle konversi ke XLSX.
- Tambah toggle "Include detail" di UI. Default **off**. Kalau on, frontend hit `/reports/period?start=&end=&detail=true` (atau `?detail=true` di summary yang return XLSX langsung).
- Tampilkan summary di layar (revenue, order count, top 5 products/sales) **tanpa download XLSX** — kebanyakan user cukup lihat angka, tidak perlu spreadsheet.

**Verifikasi manual:**
1. Admin → tab Stats.
2. Pilih rentang 1 bulan.
3. Network tab: 1 request ke `/reports/summary` (~10-50KB payload).
4. UI tampilkan angka ringkasan. Tidak ada auto-download XLSX.
5. Kalau user centang "Include detail" + klik Download: 1 request ke endpoint yang return XLSX stream, payload lebih besar tapi hanya atas permintaan eksplisit.

---

## 7. Phase 6 — Server-side Pagination (HIGH impact, ADDITIVE only, 1 fase)

**Tujuan:** Turunkan egress list endpoint besar dengan optional `?limit=&offset=`, **100% backward compat**.

**File diubah (semua di `sales-app/backend/app/api/endpoints/`):**
- `customers.py` — endpoint list
- `bulletins.py` — endpoint list
- `products.py` — endpoint list
- `customer_submissions.py` — endpoint list
- `users.py` — endpoint list
- `sales.py` — endpoint area-assignments

**File frontend (opsional, default tidak dipakai):**
- `sales-app/lib/data/repositories/product_provider.dart`
- `sales-app/admin_web/lib/data/repositories/admin_repository.dart`

### Task 6.1 — Tambah `?limit=&offset=` ke 6 endpoint list

Pattern seragam (contoh untuk `customers.py`):
```python
@router.get("/customers")
def list_customers(
    limit: int = Query(None, description="Optional; default = return all"),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    q = db.query(Customer)
    if limit is not None:
        q = q.limit(limit).offset(offset)
    return q.all()
```

**Backward compat:** `limit=None` → `q.limit/offset` TIDAK dipanggil → return semua data seperti sekarang. 100% tidak ada breaking change.

**Limiter aman:**
- Frontend call tanpa `limit` → backend return semua (default).
- Frontend call dengan `limit=100&offset=0` → backend return 100 row.
- Kalau `limit > 1000` → backend clamp ke 1000 (defensive).

**Test per endpoint:**
- `tests/api/endpoints/test_customers_list.py::test_list_without_limit_returns_all` — assert response count == all customers di DB.
- `tests/api/endpoints/test_customers_list.py::test_list_with_limit_returns_n_rows` — assert response count == `limit`.
- `tests/api/endpoints/test_customers_list.py::test_list_with_offset_skips_rows` — assert row pertama == `offset`-th customer.

**Cleanup:** Test insert Customer/Product/Bulletin/Submission/User wajib hapus sebelum exit.

**Verifikasi:** `pytest tests/api/endpoints/test_customers_list.py -v` (dan 5 file lain) — PASS semua.

### Task 6.2 — Tambah optional `?include_total=true` (untuk frontend yang butuh tau total)

**File:** semua 6 endpoint dari Task 6.1

```python
class PaginatedResponse(BaseModel, Generic[T]):
    items: list[T]
    total: int | None = None  # None kalau include_total=false atau query mahal
```

```python
@router.get("/customers")
def list_customers(
    limit: int = Query(None),
    offset: int = Query(0, ge=0),
    include_total: bool = Query(False),
    db: Session = Depends(get_db),
):
    q = db.query(Customer)
    if include_total and limit is not None:
        total = q.count()  # +1 query, opt-in
    else:
        total = None
    if limit is not None:
        q = q.limit(limit).offset(offset)
    return {"items": q.all(), "total": total}
```

**Catatan:** Response shape hanya berubah kalau frontend pakai `?include_total=true` AND `?limit=`. Tanpa kedua param itu, response tetap array polos seperti sekarang.

**Test:** Verify existing caller (yang tidak pakai param baru) tetap dapat response array polos. Verify new caller dengan param dapat `{items, total}`.

**Verifikasi:** Existing integration test (kalau ada) masih PASS.

### Task 6.3 — Frontend opt-in pakai pagination (default: tidak)

**File:** `sales-app/lib/data/repositories/product_provider.dart` dan `sales-app/admin_web/lib/data/repositories/admin_repository.dart`

- Tambah method `getProductsPage({int limit = 50, int offset = 0, bool includeTotal = true})` di repository.
- Default behavior method existing **TIDAK berubah** — masih fetch semua.
- Tambah ScrollController-based pagination di list screen yang mau pakai (UI opsional, bisa di fase lain).

**Catatan:** Ini hanya fondasi. Migrasi UI ke pagination akan dilakukan di iterasi berikut (out of scope plan ini).

**Verifikasi:** Manual: panggil `getProductsPage(limit: 50)` di DevTools console — dapat 50 row, ada field `total`.

---

## 8. Phase 7 — Cross-branch Report Optimization (MEDIUM impact, 1 fase)

**Tujuan:** Turunkan query count dari 45 query per halaman cross-branch menjadi 2 query.

**File diubah:**
- `sales-app/backend/app/api/endpoints/reports.py` (line 563-616, 629-673)

### Task 7.1 — Refactor `/cross-branch/sales-summary` jadi 1 query

**File:** `sales-app/backend/app/api/endpoints/reports.py` (line 563-616)

Saat ini:
```python
for branch in branches:
    approved_count = db.query(func.count(Order.id)).filter(...).scalar()  # query 1
    revenue = db.query(func.sum(Order.total)).filter(...).scalar()          # query 2
    pending_count = db.query(func.count(Order.id)).filter(...).scalar()    # query 3
    customer_count = db.query(func.count(Customer.id)).filter(...).scalar() # query 4
    sales_count = db.query(func.count(User.id)).filter(...).scalar()        # query 5
```

Total 5 × N branches = 25 query untuk 5 branch.

Refactor jadi **2 query** dengan subquery / `case when`:
```python
# Query 1: order stats per branch
order_stats = db.query(
    Order.branch_code,
    func.sum(case((Order.status == 'approved', 1), else_=0)).label('approved_count'),
    func.sum(case((Order.status == 'pending', 1), else_=0)).label('pending_count'),
    func.coalesce(func.sum(Order.total), 0).label('revenue'),
).filter(Order.created_at >= start, Order.created_at <= end).group_by(Order.branch_code).all()

# Query 2: customer + sales count per branch (1 query with subquery)
# Pakai func.count(distinct) + filter
...
```

**Test:** `tests/api/endpoints/test_cross_branch_sales_summary.py::test_uses_max_2_queries`. Spy query count via `SQLAlchemy event listen` atau `query_counter` fixture. Assert ≤ 2 query (vs 5 × N sebelumnya). Assert output schema **identik** dengan implementasi lama.

**Cleanup:** Test insert Order/Customer/User wajib hapus sebelum exit.

**Verifikasi:** `pytest tests/api/endpoints/test_cross_branch_sales_summary.py -v` — PASS. Manual: hit endpoint, cek log Supabase: 1-2 query saja.

### Task 7.2 — Refactor `/cross-branch/stock-summary` jadi 1 query

**File:** `sales-app/backend/app/api/endpoints/reports.py` (line 629-673)

Pola sama dengan Task 7.1. 4 × N = 20 query → 1 query dengan GROUP BY.

**Test:** `tests/api/endpoints/test_cross_branch_stock_summary.py::test_uses_max_2_queries`.

**Verifikasi:** `pytest` — PASS. Output schema identik.

### Task 7.3 — Performance test pembanding (before vs after)

**File:** `tests/api/endpoints/test_cross_branch_perf.py`

Generate ~1000 dummy Order/Customer/User/Product di DB. Hit endpoint:
- Implementasi lama: timing ~2-5 detik (25 query × 40ms each).
- Implementasi baru: timing ~100-200ms (2 query).

Assert new implementation < 500ms.

**Cleanup:** Test yang generate 1000 row wajib hapus SEMUA sebelum exit (cleanup script atau fixture `autouse=True` dengan rollback).

**Verifikasi:** `pytest tests/api/endpoints/test_cross_branch_perf.py -v` — PASS.

---

## 9. Out of Scope (updated)

Item yang **tetap di luar scope** plan ini:

| Item | Alasan |
|---|---|
| `pdf_url` di bulletin list response | Impact egress sangat kecil (~50 byte × N row). Bisa dibahas di iterasi berikut. |
| Flutter mobile test infrastructure | Effort setup besar. Verifikasi via dev-server manual dulu; tambah test di iterasi berikut. |
| Migrasi UI ke server-side pagination (Phase 6.3) | Fondasi backend sudah ada di Phase 6.1-6.2. Migrasi UI adalah kerja UI terpisah. |
| Penghapusan field `joinedload` di order list response (kolom `customer.alamat`, dll) | Butuh diskusi API shape (perlu eksplisit `?fields=` param atau schema baru). Bisa di iterasi berikut. |

---

## 10. Phase Execution Order & Verifikasi

| Phase | Fokus | Estimasi | Egress impact |
|---|---|---|---|
| 1 | Mobile debounce | 4-6 jam | -80% mobile fetch customer/product |
| 2 | Admin debounce + stop refetch on mutation + visibility auto-refresh | 6-8 jam | -70% admin mutation fetches |
| 3 | Backend N+1 (orders create/update) | 3-4 jam | -10-20% DB load |
| 4 | Backend connection pool | 1-2 jam | -30-50% per-request overhead |
| 5 | Excel report optimization (summary endpoint + opt-in detail + range validation) | 6-8 jam | -90% report egress (1×-2× per bulan, tapi payload besar) |
| 6 | Server-side pagination (additive `?limit=&offset=`) | 4-6 jam | Foundation, dampak aktual saat UI migrasi |
| 7 | Cross-branch report (5N→1 query) | 4-5 jam | -95% query count, -80% response time |

**Total estimasi:** 28-39 jam kerja.

**Urutan eksekusi (impact terbesar dulu):**
1. **Phase 5** (Excel) — palng mungkin penyebab lonjakan 15 Okt, **mulai dari sini**
2. Phase 1 (mobile debounce) — volume fetch mobile paling tinggi
3. Phase 2 (admin debounce + mutation)
4. Phase 3 (N+1)
5. Phase 7 (cross-branch) — low frequency
6. Phase 6 (pagination foundation) — dampak aktual di iterasi berikut saat UI migrasi
7. Phase 4 (pool) — quick win, bisa kapan saja

**Per fase, sebelum commit:**
- Run `cd sales-app/backend && pytest tests/ -v` — harus PASS.
- Cek `git status` dan `git diff` (user yang commit).
- Test manual di dev server per "Verifikasi manual" di tiap task.
- Snapshot metric egress dari dashboard Supabase sebelum & sesudah fase.

---

## 11. Catatan Teknis

- **`WidgetsBindingObserver` vs `dart:html`:** Untuk visibility (Task 2.4), pakai `WidgetsBindingObserver` + `AppLifecycleState` — Flutter-recommended, tidak butuh `dart:html` (yang deprecated).
- **Optimistic update consistency:** Saat update local state (Task 2.3), kalau endpoint return data lebih lengkap (mis. updated_at server), pakai itu. Kalau hanya return success boolean, optimistically update dengan `DateTime.now()` — risiko minor: jam client mungkin beda ±1 menit dengan server. Acceptable untuk UI.
- **Pool sizing:** `pool_size=10, max_overflow=20` — dipilih untuk workload concurrent ringan (10-30 RPS). Kalau traffic naik, naikkan sesuai metrik.
- **Filter cache di `product_provider`:** Pattern `_allProducts` cache di klien hanya work kalau dataset manageable (≤5000 rows). Untuk produk yang akan tembus 10K+, frontend migrasi ke server-side pagination (Phase 6.3 fondasi sudah ada).
- **Excel summary strategy:** SQL aggregation di `reports.py` harus pakai index yang sudah ada (cek `Order.branch_code`, `Order.created_at`, `Product.id`). Kalau index belum ada, tambahkan di migration terpisah (out of scope plan ini).
- **Pagination default behavior:** `?limit=` absence = return all. Ini **penting** untuk backward compat — jangan ubah default behavior supaya tidak break caller lama.
- **Egress measurement:** Sebelum mulai, capture baseline harian (3-5 hari). Setelah tiap fase, capture lagi. Bandingkan di akhir.
