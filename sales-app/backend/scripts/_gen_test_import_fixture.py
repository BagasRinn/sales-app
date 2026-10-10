"""Generate test Excel fixtures for product AND customer import per-branch.

Output: sales-app/backend/tests/fixtures/
  Products (1 file per branch, 1 sheet each, header CCODE/KATEGORI/...):
    test_import_batulicin.xlsx, test_import_barabai.xlsx,
    test_import_palangkaraya.xlsx, test_import_sampit.xlsx

  Customers (1 file per branch, 1 sheet each, header kode/nama_toko/...):
    test_customers_batulicin.xlsx, test_customers_barabai.xlsx,
    test_customers_palangkaraya.xlsx, test_customers_sampit.xlsx

(BANJARMASIN omitted — it's the pre-existing populated branch, not a test target.)

Setiap file punya 1 sheet berisi data 1 branch. Dipisah supaya mudah
mengetes apakah branch benar-benar di-set server-side dari JWT user
(yakni "get branch" berfungsi), baik untuk produk maupun customer/toko.

Format refs:
  products header → backend EXCEL_COLUMNS at sheets_sync.py:20
  customers header → EXCEL_COLUMNS at customer_sync.py:27
  product endpoint → products.py:191-232
  customer endpoint → customers.py:363-394

Server-side branch is taken dari JWT (sama untuk produk & customer) — NO
branch column di Excel. Admin logs in as the branch they want to populate;
filename cuma label untuk manusia.

Run from repo root:
    python sales-app/backend/scripts/_gen_test_import_fixture.py
"""
import os
import shutil
import tempfile
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill

OUTPUT_DIR = os.path.normpath(os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "..", "tests", "fixtures",
))
README_PATH = os.path.normpath(os.path.join(OUTPUT_DIR, "README.md"))

# ─────────────────────────────────────────────────────────────────────────
# PRODUCTS
# ─────────────────────────────────────────────────────────────────────────

PRODUCT_HEADERS = ["CCODE", "KATEGORI", "NAME ITEM", "GOOD", "OUM", "FIX", "LAST SUPPLIER"]

# SUPPLIERS_4P per services/sheets_sync.py:39-46 — items here get order_type=4P
SUPPLIERS_4P = {
    "CANDRA FOOD, CV",
    "CUAN BERKAT BERSAMA, PT",
    "DARMAWAN SUKSES MANDIRI, PT",
    "PANGAN INDUSTRI BANUA, PT",
}

# Per-branch data: (sku, kategori, name, stok, satuan, harga, supplier)
PRODUCTS = {
    "BATULICIN": [
        ("BL-001", "MIE",    "Indomie Kuah Soto",               80, "PCS", 3500,  "INDOFOOD, PT"),
        ("BL-002", "MINYAK", "Minyak Goreng Sania 1L",          55, "BTL", 21000, "WINGS, PT"),
        ("BL-003", "ROTI",   "Roti Tawar Sari Roti",            50, "PCS", 14500, "CANDRA FOOD, CV"),     # 4P
        ("BL-004", "SUSU",   "Susu Dancow 400g",                30, "KALENG", 52000, "NESTLE, PT"),
        ("BL-005", "KOPI",   "Good Day Mocca 200ml",            90, "PCS", 4500,  "INDOFOOD, PT"),
        ("BL-006", "DETERJEN","Rinso Anti Noda 800g",           35, "PAK", 21000, "UNILEVER, PT"),
        ("BL-007", "SNACK",  "Tango Wafer 47g",                 75, "PCS", 8500,  "DARMAWAN SUKSES MANDIRI, PT"),  # 4P
        ("BL-008", "TEPUNG", "Tepung Protein Tinggi 1kg",       25, "PAK", 22000, "SRIBOGA, PT"),
    ],
    "BARABAI": [
        ("BR-001", "MIE",    "Sarimi Goreng",                   65, "PCS", 3500,  "INDOFOOD, PT"),
        ("BR-002", "GULA",   "Gula Kristal Gulaku 1kg",         50, "PAK", 17000, "INDOFOOD, PT"),
        ("BR-003", "BERAS",  "Beras Biasa 5kg",                 30, "KARUNG", 68000, "PANGAN JAYA, CV"),
        ("BR-004", "ROTI",   "Roti Sobet Isi Coklat",           70, "PCS", 7500,  "CANDRA FOOD, CV"),     # 4P
        ("BR-005", "KECAP",  "Kecap Manis Bango 600ml",         45, "BTL", 27500, "INDOFOOD, PT"),
        ("BR-006", "SNACK",  "Chitato BBQ 68g",                 60, "PCS", 12000, "INDOFOOD, PT"),
        ("BR-007", "MINUM",  "Teh Pucuk Harum 350ml",           85, "PCS", 4500,  "INDOFOOD, PT"),
    ],
    "PALANGKARAYA": [
        ("PK-001", "MIE",    "Indomie Aceh",                    90, "PCS", 4000,  "INDOFOOD, PT"),
        ("PK-002", "MINYAK", "Minyak Goreng Fortune 2L",         40, "BTL", 38000, "WINGS, PT"),
        ("PK-003", "BERAS",  "Beras Pandan Wangi 5kg",          50, "KARUNG", 82000, "PANGAN JAYA, CV"),
        ("PK-004", "ROTI",   "Roti Burger Coklat",              95, "PCS", 9500,  "CANDRA FOOD, CV"),     # 4P
        ("PK-005", "ROTI",   "Roti Burger Keju",                85, "PCS", 9500,  "CANDRA FOOD, CV"),     # 4P
        ("PK-006", "SNACK",  "Qtela Balado 55g",                70, "PCS", 8500,  "PANGAN INDUSTRI BANUA, PT"),  # 4P
        ("PK-007", "DETERJEN","Sunlight Sabun Cuci 800ml",      30, "PCS", 18000, "UNILEVER, PT"),
        ("PK-008", "SUSU",   "Indomilk Kental Manis 370g",      55, "KALENG", 13500, "INDOSOP, PT"),
        ("PK-009", "BUMBU",  "Indofood Sambal Pedas 340ml",     65, "BTL", 18500, "INDOFOOD, PT"),
    ],
    "SAMPIT": [
        ("SP-001", "MIE",    "Indomie Goreng",                  50, "PCS", 3500,  "INDOFOOD, PT"),
        ("SP-002", "KOPI",   "ABC Susu 200ml",                  60, "PCS", 5500,  "INDOFOOD, PT"),
        ("SP-003", "ROTI",   "Roti Manis isi Srikaya",          40, "PCS", 7500,  "CANDRA FOOD, CV"),     # 4P
        ("SP-004", "MINYAK", "Minyak Goreng Tropical 1L",       25, "BTL", 22000, "WINGS, PT"),
        ("SP-005", "GULA",   "Gula Merah 500g",                 20, "PAK", 12500, "PANGAN JAYA, CV"),
        ("SP-006", "BERAS",  "Beras Premium 10kg",              15, "KARUNG", 145000, "PANGAN JAYA, CV"),
    ],
}

# ─────────────────────────────────────────────────────────────────────────
# CUSTOMERS
# ─────────────────────────────────────────────────────────────────────────

CUSTOMER_HEADERS = ["kode", "nama_toko", "alamat", "kode_area"]

# Per-branch customer data: (kode, nama_toko, alamat, kode_area)
# SEMUA 4 kolom wajib terisi — fixture ini untuk happy-path testing, bukan
# untuk test validasi field kosong. Kalau mau test "kode kosong" / "alamat
# kosong" / etc, bikin file terpisah.
#
# Identity customer = (branch, kode, kode_area) triple. Same kode di branch
# berbeda atau di kode_area berbeda tetap dianggap customer berbeda. Dalam
# file per branch ini, semua (kode, kode_area) unik supaya tidak ada
# duplicate-identity di file.
CUSTOMERS = {
    "BATULICIN": [
        ("BL-C001", "Toko Sumber Rezeki",      "Jl. Lambung Mangkurat No.12, Batulicin", "MULIA2"),
        ("BL-C002", "Warung Ibu Hj. Aminah",   "Jl. Dharma Praja No.45, Batulicin",     "MULIA1"),
        ("BL-C003", "Toko Aneka Bumbu",        "Jl. Raya Batulicin RT 03/01",           "MULIA2"),
        ("BL-C004", "Sembako Jaya Makmur",     "Jl. Veteran No.7, Batulicin",           "MULIA1"),
        ("BL-C005", "Toko Hj. Halimah",        "Jl. Sulawesi No.23, Simpang Empat",     "MULIA3"),
        ("BL-C006", "Toko Baru Batulicin",     "Jl. Baru No.1, Batulicin",              "MULIA2"),
    ],
    "BARABAI": [
        ("BR-C001", "Toko Sinar Jaya",         "Jl. Murakata No.8, Barabai",            "HULU"),
        ("BR-C002", "Warung Beras Mak Tiah",   "Jl. H. M. Syarkawi No.14, Barabai",     "HULU"),
        ("BR-C003", "Toko Sumber Rezeki II",   "Jl. Pangeran Antasari No.5, Barabai",   "HILIR"),
        ("BR-C004", "Sembako Pak Ahmad",       "Jl. Gardu Induk No.21, Barabai",        "HULU"),
        ("BR-C005", "Toko Kelontong Madu",     "Jl. Veteran No.3, Barabai",             "HILIR"),
    ],
    "PALANGKARAYA": [
        ("PK-C001", "Toko Borneo Mart",        "Jl. RTA. Milono Km.2, Palangkaraya",    "BUKIT"),
        ("PK-C002", "Warung Sumber Hidup",     "Jl. Diponegoro No.45, Palangkaraya",    "BUKIT"),
        ("PK-C003", "Toko Jaya Abadi",         "Jl. Ahmad Yani No.88, Palangkaraya",    "SEBANGAU"),
        ("PK-C004", "Sembako Hj. Maryani",     "Jl. Tjilik Riwut Km.5, Palangkaraya",   "BUKIT"),
        ("PK-C005", "Toko Rezeki Tiada Henti", "Jl. Seth Adji No.12, Palangkaraya",     "SEBANGAU"),
        ("PK-C006", "Warung Barokah",          "Jl. Imam Bonjol No.7, Palangkaraya",    "BUKIT"),
        ("PK-C007", "Toko Aneka",              "Jl. Pelataran No.2, Palangkaraya",      "SEBANGAU"),
    ],
    "SAMPIT": [
        ("SP-C001", "Toko Sumber Jaya",        "Jl. MT. Haryono No.15, Sampit",         "KOTA"),
        ("SP-C002", "Warung Pak Hadi",         "Jl. Jenderal Sudirman Km.3, Sampit",   "KOTA"),
        ("SP-C003", "Sembako Nurul Iman",      "Jl. Cilik Riwut No.10, Sampit",         "MENTAWA"),
        ("SP-C004", "Toko H. Basir",           "Jl. Samekto No.5, Sampit",              "KOTA"),
    ],
}


def _make_product_sheet(wb, branch_name, rows):
    ws = wb.create_sheet(branch_name)
    header_fill = PatternFill("solid", fgColor="D9E1F2")
    header_font = Font(bold=True)

    for col_idx, h in enumerate(PRODUCT_HEADERS, start=1):
        cell = ws.cell(row=1, column=col_idx, value=h)
        cell.fill = header_fill
        cell.font = header_font

    for row_offset, (sku, kategori, name, stok, satuan, harga, supplier) in enumerate(rows, start=2):
        ws.cell(row=row_offset, column=1, value=sku)
        ws.cell(row=row_offset, column=2, value=kategori)
        ws.cell(row=row_offset, column=3, value=name)
        ws.cell(row=row_offset, column=4, value=stok)
        ws.cell(row=row_offset, column=5, value=satuan)
        ws.cell(row=row_offset, column=6, value=harga)
        ws.cell(row=row_offset, column=7, value=supplier)

    ws.column_dimensions["A"].width = 14
    ws.column_dimensions["B"].width = 14
    ws.column_dimensions["C"].width = 36
    ws.column_dimensions["D"].width = 10
    ws.column_dimensions["E"].width = 12
    ws.column_dimensions["F"].width = 12
    ws.column_dimensions["G"].width = 42
    ws.freeze_panes = "A2"


def _make_customer_sheet(wb, branch_name, rows):
    ws = wb.create_sheet(branch_name)
    header_fill = PatternFill("solid", fgColor="E2EFDA")
    header_font = Font(bold=True)

    for col_idx, h in enumerate(CUSTOMER_HEADERS, start=1):
        cell = ws.cell(row=1, column=col_idx, value=h)
        cell.fill = header_fill
        cell.font = header_font

    for row_offset, (kode, nama_toko, alamat, kode_area) in enumerate(rows, start=2):
        ws.cell(row=row_offset, column=1, value=kode)
        ws.cell(row=row_offset, column=2, value=nama_toko)
        ws.cell(row=row_offset, column=3, value=alamat)
        ws.cell(row=row_offset, column=4, value=kode_area)

    ws.column_dimensions["A"].width = 14
    ws.column_dimensions["B"].width = 32
    ws.column_dimensions["C"].width = 50
    ws.column_dimensions["D"].width = 14
    ws.freeze_panes = "A2"


def _atomic_save(wb, final_path: str) -> bool:
    """Save workbook atomically: write to .tmp, then os.replace.

    Returns True on success, False if final_path is locked (e.g. open in
    Excel). Tolerates the locked case so the rest of the run (other files
    + README) still completes.
    """
    os.makedirs(os.path.dirname(final_path), exist_ok=True)
    tmp_dir = os.path.dirname(final_path) or "."
    fd, tmp_path = tempfile.mkstemp(prefix=".tmp_", suffix=".xlsx", dir=tmp_dir)
    os.close(fd)
    try:
        wb.save(tmp_path)
        try:
            os.replace(tmp_path, final_path)
            return True
        except PermissionError:
            os.remove(tmp_path)
            print(f"  [LOCKED] {final_path} — sedang dibuka Excel, skip. Tutup file, re-run script.")
            return False
    except Exception:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        raise


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    product_total = 0
    product_4p = 0
    for branch, rows in PRODUCTS.items():
        wb = Workbook()
        wb.remove(wb.active)
        _make_product_sheet(wb, branch, rows)
        out_path = os.path.join(OUTPUT_DIR, f"test_import_{branch.lower()}.xlsx")
        if _atomic_save(wb, out_path):
            print(f"Generated: {out_path}")
        product_total += len(rows)
        product_4p += sum(1 for r in rows if r[6] in SUPPLIERS_4P)

    customer_total = 0
    for branch, rows in CUSTOMERS.items():
        wb = Workbook()
        wb.remove(wb.active)
        _make_customer_sheet(wb, branch, rows)
        out_path = os.path.join(OUTPUT_DIR, f"test_customers_{branch.lower()}.xlsx")
        if _atomic_save(wb, out_path):
            print(f"Generated: {out_path}")
        customer_total += len(rows)

    print(
        f"\n  Products: {len(PRODUCTS)} file, {product_total} row, {product_4p} 4P. "
        f"Customers: {len(CUSTOMERS)} file, {customer_total} row."
    )

    _write_readme(product_total, product_4p, customer_total)


def _write_readme(product_rows, product_4p, customer_rows):
    body = f"""# Test fixture: import per-branch (products + customers)

## Products (4 file)

| Branch        | File                              | SKU prefix | Rows |
|---------------|-----------------------------------|------------|------|
| BATULICIN     | `test_import_batulicin.xlsx`      | `BL-`      | 8    |
| BARABAI       | `test_import_barabai.xlsx`        | `BR-`      | 7    |
| PALANGKARAYA  | `test_import_palangkaraya.xlsx`   | `PK-`      | 9    |
| SAMPIT        | `test_import_sampit.xlsx`         | `SP-`      | 6    |

Total {product_rows} rows, {product_4p} item 4P. Backend upsert key: `(id, branch)`.

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

Total {customer_rows} rows. Backend identity: `(branch, kode)` — sama pattern
dengan Product `(id, branch)`. Header wajib persis:
`kode, nama_toko, alamat, kode_area`. Lihat:
`sales-app/backend/app/services/customer_sync.py:27`.

**Identity rule**: `kode` unique per branch. Same `kode` BOLEH di branch
berbeda (mis. `OUT001` di BATULICIN dan `OUT001` di BARABAI = 2 customer
beda), tapi dalam 1 branch harus unik. `kode_area` jadi field deskriptif
saja (bukan bagian dari identity).

**Semua 4 kolom wajib terisi** — fixture ini happy-path only, tidak cover
case "kode kosong" / "kode_area kosong". Kalau mau test validasi field
kosong, bikin file terpisah.

`nama_toko` & `alamat` di backend wajib non-empty (validator skip kalau
kosong, lihat `customer_sync.py:88-96`). `kode` & `kode_area` opsional
nullable di DB, tapi fixture ini tetap mengisinya untuk konsistensi.

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
`order_type` di-tag `4P` hanya untuk supplier di {{CANDRA FOOD, CV,
CUAN BERKAT BERSAMA, PT, DARMAWAN SUKSES MANDIRI, PT, PANGAN INDUSTRI BANUA, PT}}.

Total 4P items: {product_4p}.

## Catatan per-fitur

**Customer import: branch dari JWT** — `customer_sync.py` sekarang propagate
`current_user.get("branch")` ke `_bulk_upsert_customers`, dan kolom `branch`
di-set di bulk INSERT row. Identity lookup + ON CONFLICT clause juga
mengikuti unique constraint asli `(branch, kode, kode_area)`.

**Error log truncate** — handler pakai `_safe_reason()` (clamp ke 240 char)
sebelum tulis ke `sync_validation_errors.reason` (VARCHAR(255)). Sebelumnya
psycopg dump SQL+params (>2K char) bikin `StringDataRightTruncation` → error
log sendiri gagal → user lihat "Sync completed" padahal data tidak masuk.

## Cleanup
Setelah selesai testing:
```
cd sales-app/backend
python scripts/cleanup_test_products.py --apply
python scripts/cleanup_test_customers.py --apply
```
Keduanya idempotent, default dry-run. HANYA menyentuh row dengan prefix
SKU/kode di atas (4 branch test). TIDAK menyentuh BANJARMASIN.
"""
    with open(README_PATH, "w", encoding="utf-8") as f:
        f.write(body)
    print(f"Generated: {README_PATH}")


if __name__ == "__main__":
    main()
