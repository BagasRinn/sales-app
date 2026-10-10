# Test fixture: import per-branch (products + customers)

## Products (4 file)

| Branch        | File                              | SKU prefix | Rows |
|---------------|-----------------------------------|------------|------|
| BATULICIN     | `test_import_batulicin.xlsx`      | `BL-`      | 8    |
| BARABAI       | `test_import_barabai.xlsx`        | `BR-`      | 7    |
| PALANGKARAYA  | `test_import_palangkaraya.xlsx`   | `PK-`      | 9    |
| SAMPIT        | `test_import_sampit.xlsx`         | `SP-`      | 6    |

Total 30 rows, 7 item 4P. Backend upsert key: `(id, branch)`.

Header wajib persis: `CCODE, KATEGORI, NAME ITEM, GOOD, OUM, FIX, LAST SUPPLIER`.
Backend scan di 10 baris pertama — validator literal cari `CCODE`.
Lihat: `sales-app/backend/app/services/sheets_sync.py:20`.

## Customers (4 file)

| Branch        | File                              | Kode prefix | Rows |
|---------------|-----------------------------------|-------------|------|
| BATULICIN     | `test_customers_batulicin.xlsx`   | `BL-C`      | 6    |
| BARABAI       | `test_customers_barabai.xlsx`     | `BR-C`      | 5    |
| PALANGKARAYA  | `test_customers_palangkaraya.xlsx`| `PK-C`      | 7    |
| SAMPIT        | `test_customers_sampit.xlsx`      | `SP-C`      | 4    |

Total 22 rows. Backend identity: `(branch, kode, kode_area)`. Header
wajib persis: `kode, nama_toko, alamat, kode_area`. Lihat:
`sales-app/backend/app/services/customer_sync.py:27`.

`kode` dan `kode_area` opsional — kosong/None artinya insert baru tanpa
identity conflict. `nama_toko` & `alamat` wajib non-empty (validator skip
kalau kosong).

## Setup pakai

Login admin web sebagai `admin.<branch>` (atau `supervisor.<branch>`) →
Products/Customers tab → Import Excel → pilih file untuk branch tersebut.
Filename cuma label — backend ambil branch dari JWT.

## Test case utama: verify "get branch" berfungsi (produk + customer)

1. Login `admin.batulicin` → import `test_import_batulicin.xlsx` →
   8 row produk `branch=BATULICIN`. Cek tab Products BATULICIN.
2. Login `admin.batulicin` → import `test_customers_batulicin.xlsx` →
   6 row customer `branch=BATULICIN`. Cek tab Customers BATULICIN.
3. Ulangi untuk 3 branch lain (products + customers).
4. Login `supervisor.batulicin` → tab Products → **hanya** muncul
   8 produk `BL-*`. Produk `BR-*`/`PK-*`/`SP-*` invisible.
5. Login `admin.banjarmasin` → produk & customer `BL-*`/`BR-*`/
   `PK-*`/`SP-*` TIDAK boleh muncul.
6. Query langsung di DB:
   ```sql
   SELECT branch, COUNT(*) FROM products
   WHERE id LIKE 'BL-%' OR id LIKE 'BR-%' OR id LIKE 'PK-%' OR id LIKE 'SP-%'
   GROUP BY branch;
   -- expect: BATULICIN=8, BARABAI=7, PALANGKARAYA=9, SAMPIT=6

   SELECT branch, COUNT(*) FROM customers
   WHERE kode LIKE 'BL-C%' OR kode LIKE 'BR-C%' OR kode LIKE 'PK-C%' OR kode LIKE 'SP-C%'
   GROUP BY branch;
   -- expect: BATULICIN=6, BARABAI=5, PALANGKARAYA=7, SAMPIT=4
   ```

Kalau hasil query di langkah 6 menunjukkan branch NULL atau branch yang
salah, berarti "get branch" di import customer belum ter-implement dengan
benar. Cek `customer_sync.py:191-213` (`_bulk_upsert_customers`) — field
`branch` di row INSERT dibanding `sheets_sync.py:197,207` yang eksplisit
set `"branch": cabang`.

## 4P items (products)
`order_type` di-tag `4P` hanya untuk supplier di {CANDRA FOOD, CV,
CUAN BERKAT BERSAMA, PT, DARMAWAN SUKSES MANDIRI, PT, PANGAN INDUSTRI BANUA, PT}.

Total 4P items: 7.

## Catatan per-fitur

**Customer bulk INSERT path** (`customer_sync.py:191-213`) — saat ini
hanya set 4 kolom (`kode`, `nama_toko`, `alamat`, `kode_area`). Kalau
ditemukan `customers.branch` tidak ter-tag dari JWT saat testing, fix
dengan menambahkan `"branch": current_user.get("branch")` ke row dict
yang di-INSERT, dan propagate `current_user` ke `_bulk_upsert_customers`
(mirror pattern dari `sheets_sync.py:197,207,212`).

## Cleanup
Setelah selesai testing:
```
cd sales-app/backend
python scripts/cleanup_test_products.py --apply
python scripts/cleanup_test_customers.py --apply
```
Keduanya idempotent, default dry-run. HANYA menyentuh row dengan prefix
SKU/kode di atas (4 branch test). TIDAK menyentuh BANJARMASIN.
