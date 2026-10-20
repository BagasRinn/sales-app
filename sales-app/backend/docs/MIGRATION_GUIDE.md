# ============================================================
# MIGRASI DARI SUPABASE KE RAILWAY — PANDUAN LENGKAP
# ============================================================
#
# FILE INI: sales-app/backend/docs/MIGRATION_GUIDE.md
#
# ============================================================
# PERHATIAN: BACKUP DULU SEBELUM JALANKAN MIGRASI!
# ============================================================
#
# Langkah-langkah:
#
#   PHASE 1 — Persiapan
#   ├── 1.1  Buat Railway Project + PostgreSQL
#   ├── 1.2  Dapatkan Railway Connection String
#   ├── 1.3  Buat S3 Bucket (opsional, untuk bulletin PDF)
#   └── 1.4  Install dependencies
#
#   PHASE 2 — Migrasi Data
#   ├── 2.1  Export data dari Supabase (.env masih pointing ke Supabase)
#   ├── 2.2  Buat tabel di Railway
#   ├── 2.3  Import data ke Railway
#   └── 2.4  Verifikasi data
#
#   PHASE 3 — Update Kode
#   ├── 3.1  Update .env ke Railway
#   ├── 3.2  Migrasi storage ke S3 (opsional)
#   └── 3.3  Test koneksi
#
# ============================================================
# PHASE 1 — PERSIAPAN
# ============================================================
#
# 1.1  Buat Railway Project + PostgreSQL
# ----------------------------------------
#   a. Buka https://railway.app
#   b. Login / Sign up
#   c. Klik "New Project" → "Provision PostgreSQL"
#   d. Tunggu sampai PostgreSQL ready (biasanya ~1 menit)
#
# 1.2  Dapatkan Railway Connection String
# ----------------------------------------
#   a. Di Railway dashboard, klik PostgreSQL instance
#   b. Tab "Variables" → cari variabel "DATABASE_URL"
#   c. Format-nya seperti:
#      postgresql://postgres:xxxxxxxx@xxxx.railway.app:5432/railway
#
#   CONNECTION STRING INI AKAN DIGUNAKAN DI STEP 2.3 DAN 3.1
#
# 1.3  Buat S3 Bucket (untuk bulletin PDF)
# ----------------------------------------
#   OPSIONAL A — Tigris (S3-compatible, gratis, di Railway):
#   a. Di Railway project yang sama, klik "New" → "Database" → "Tigris"
#   b. Tunggu provision selesai
#   c. Di tab "Variables", cari:
#      TIGRIS_ACCESS_KEY
#      TIGRIS_SECRET_KEY
#      TIGRIS_ENDPOINT (format: https://fly.storage.tigris.dev)
#      TIGRIS_BUCKET (nama bucket, default: tigris-bucket)
#
#   OPSIONAL B — AWS S3 Langsung:
#   a. Buka https://s3.console.aws.amazon.com
#   b. Buat bucket baru (misal: sales-bulletins)
#   c. Buat IAM user dengan policy S3FullAccess atau lebih restrict
#   d. Simpan Access Key, Secret Key, Bucket Name, Region
#
# 1.4  Install Dependencies
# ----------------------------------------
#   cd sales-app/backend
#   pip install boto3  # Untuk S3
#   pip install psycopg[binary]  # Sudah ada di requirements.txt
#
# ============================================================
# PHASE 2 — MIGRASI DATA
# ============================================================
#
# JALANKAN SEMUA COMMAND DI PHASE 2 SAAT .env MASIH MENUNJUK SUPABASE
#
# 2.1  Export Data dari Supabase
# ----------------------------------------
#   python scripts/migrate_to_railway.py --export-only
#
#   Akan membuat file:
#   - exports/users.json
#   - exports/branches.json
#   - exports/products.json
#   - exports/customers.json
#   - exports/orders.json
#   - exports/order_items.json
#   - exports/stok_log.json
#   - exports/customer_assignments.json
#   - exports/area_assignments.json
#   - exports/customer_registration_submissions.json
#   - exports/sync_validation_errors.json
#   - exports/import_logs.json
#   - exports/sales_targets.json
#   - exports/supplier_targets.json
#   - exports/suppliers.json
#   - exports/bulletins.json
#   - exports/bulletin_dismisses.json
#
# 2.2  Buat Tabel di Railway
# ----------------------------------------
#   python scripts/create_tables_railway.py
#
#   PASTIKAN VARIABEL ENVIRONMENT:
#   - RAILWAY_DATABASE_URL=postgresql://postgres:xxx@host:5432/railway
#   (BUKAN DATABASE_URL yang masih ke Supabase!)
#
#   Script ini membuat semua 17 tabel sesuai SQLAlchemy models.
#   Jika tabel sudah ada, script akan SKIP (tidak overwrite).
#
# 2.3  Import Data ke Railway
# ----------------------------------------
#   python scripts/migrate_to_railway.py --import-only
#
#   PASTIKAN VARIABEL ENVIRONMENT:
#   - RAILWAY_DATABASE_URL=postgresql://postgres:xxx@host:5432/railway
#
#   Script akan:
#   - Load semua file JSON dari folder exports/
#   - Insert ke Railway PostgreSQL
#   - Handle foreign key constraints (urutan penting!)
#
# 2.4  Verifikasi Data
# ----------------------------------------
#   python scripts/migrate_to_railway.py --verify
#
#   Akan menampilkan:
#   - Jumlah row per tabel di Supabase vs Railway
#   - Status: ✅ MATCH / ⚠️ MISMATCH / ❌ ERROR
#
# ============================================================
# PHASE 3 — UPDATE KODE
# ============================================================
#
# 3.1  Update .env ke Railway
# ----------------------------------------
#   Edit file: sales-app/backend/.env
#
#   SEBELUM (Supabase):
#   DATABASE_URL=postgresql://postgres.mdtydisgpqbcgsiuabhv:xxx@aws-0-ap-south-1.pooler.supabase.com:5432/postgres
#
#   SESUDAH (Railway):
#   DATABASE_URL=postgresql://postgres:xxx@xxxx.railway.app:5432/railway
#
# 3.2  Migrasi Storage ke S3 (Opsional)
# ----------------------------------------
#   JIKA MENGGUNAKAN TIGRIS (Railway Add-on):
#   Tambahkan di .env:
#     STORAGE_PROVIDER=tigris
#     AWS_ACCESS_KEY_ID=<TIGRIS_ACCESS_KEY>
#     AWS_SECRET_ACCESS_KEY=<TIGRIS_SECRET_KEY>
#     AWS_ENDPOINT_URL=https://fly.storage.tigris.dev
#     AWS_BUCKET_NAME=<TIGRIS_BUCKET>
#
#   JIKA MENGGUNAKAN AWS S3:
#   Tambahkan di .env:
#     STORAGE_PROVIDER=aws
#     AWS_ACCESS_KEY_ID=<AWS_ACCESS_KEY>
#     AWS_SECRET_ACCESS_KEY=<AWS_SECRET_KEY>
#     AWS_BUCKET_NAME=<NAMA_BUCKET>
#     AWS_REGION=<REGION, misal: ap-southeast-1>
#
#   LAKUKAN MIGRASI FILE (jika ada data bulletin PDF):
#   python scripts/migrate_storage_to_s3.py
#
# 3.3  Test Koneksi
# ----------------------------------------
#   cd sales-app/backend
#   python -c "
#   from app.models.database import engine
#   with engine.connect() as conn:
#       print('✅ Koneksi Railway OK')
#   "
#
#   JALANKAN BACKEND:
#   uvicorn app.main:app --reload
#
#   TEST API:
#   curl http://localhost:8000/api/branches
#
# ============================================================
# JIKA TERJADI ERROR
# ============================================================
#
# ERROR: "relation does not exist"
#   → Pastikan Phase 2.2 (create_tables) sudah selesai
#
# ERROR: "foreign key constraint"
#   → Pastikan urutan import data sudah benar (parents dulu)
#
# ERROR: "connection refused"
#   → Cek Railway PostgreSQL sudah running?
#
# ERROR: "duplicate key"
#   → Data sudah ada, gunakan --force-import untuk overwrite
#
# ROLLBACK:
#   Jika perlu kembali ke Supabase:
#   1. Ganti DATABASE_URL di .env ke format Supabase
#   2. Restart backend
#   3. Railway PostgreSQL tetap aman (tidak dihapus)
#
