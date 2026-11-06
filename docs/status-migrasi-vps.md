# Status Migrasi VPS — 6 November 2026

Dokumen ini mencatat kondisi nyata di lapangan, terpisah dari rencana di
`rencana-migrasi-vps.md`.

## Ringkasan

| Item | Status |
|---|---|
| VPS & hardening | Selesai |
| Docker + Compose | Selesai |
| PostgreSQL di VPS | Selesai, data Supabase sudah direstore |
| Backend terbaru | Selesai, healthy |
| HTTPS publik | **Selesai** — Let's Encrypt valid sampai 4 Feb 2027 |
| DNS `api.madsalesapp.my.id` | Berfungsi (A record → `217.216.146.21`) |
| Cutover produksi | Belum — menunggu jadwal malam |

URL API staging/produksi sementara:

```
https://api.madsalesapp.my.id
https://api.madsalesapp.my.id/health   -> {"status":"healthy"}
https://api.madsalesapp.my.id/docs     -> Swagger UI
```

## Infrastruktur

- IP publik: `217.216.146.21` (IP bersama / NAT provider)
- IP internal VPS: `10.10.0.157/22`
- SSH: `ssh -i ~/.ssh/id_ed25519_madsales -p 20155 deploy@217.216.146.21`
- Repo: `/opt/sales-app`
- Compose: `/opt/sales-app/deploy`
- Environment: `/opt/sales-app/deploy/.env.production` (mode 600)

Status container:

- `deploy-db-1` — healthy, PostgreSQL 17
- `deploy-api-1` — healthy, FastAPI 1.1
- `deploy-caddy-1` — healthy, TLS Let's Encrypt untuk `api.madsalesapp.my.id`

## Cara provider meneruskan trafik

VPS berada di belakang NAT. Setelah domain didaftarkan di panel provider:

- Port **80** diteruskan oleh reverse proxy provider ke Caddy di VPS
  (`X-Forwarded-Proto: http`, remote `10.10.0.1`).
- Port **443** diteruskan sebagai **TCP passthrough** ke Caddy. Bukti: klien
  menerima sertifikat Let's Encrypt milik Caddy untuk
  `api.madsalesapp.my.id`, bukan sertifikat provider.
- Jadi TLS tetap ditangani Caddy, dan `Caddyfile` yang sekarang sudah benar.
- HTTP otomatis dialihkan ke HTTPS (308).

Konsekuensi:

- Domain **wajib** terdaftar di **my.vpsmurah.co.id → VPS Saya →
  Domain & Website** sebelum trafik bisa sampai. Tanpa itu, provider
  menampilkan halaman “Domain belum terhubung ke VPS”.
- SOA zona masih `a.misconfigured.dns.server.invalid`, tetapi A record
  `api` sudah tersimpan dan berfungsi. Perbaikan zona tetap disarankan
  supaya perubahan record lain bisa dilakukan lewat panel, tetapi **tidak
  menghalangi cutover**.

## Data

Restore dari dump Supabase 6 November 2026:

| Tabel | Baris |
|---|---|
| users | 48 |
| branches | 5 |
| products | 8.623 |
| customers | 5.327 |
| orders | 3.667 |
| order_items | 11.314 |
| stok_log | 46.600 |

Setelah startup backend terbaru: 21 tabel `public`, kolom
`imported_sales.dedupe_key`, index `uq_imported_sales_dedupe_key`, dan
`ix_imported_sales_branch_sale_date` sudah ada.

`SECRET_KEY` di VPS identik dengan yang lama (diverifikasi lewat SHA-256),
sehingga token login pengguna tetap valid setelah cutover.

## Verifikasi yang sudah lolos

- `https://api.madsalesapp.my.id/health` → 200 `{"status":"healthy"}`
- `https://api.madsalesapp.my.id/` → 200, pesan API versi 1.1
- Sertifikat TLS: Let's Encrypt, CN `api.madsalesapp.my.id`, valid s/d
  4 Feb 2027, TLS 1.3
- Preflight CORS dari `https://sales-order-web.web.app` → 200 dengan
  `Access-Control-Allow-Origin` yang benar
- `http://api.madsalesapp.my.id/health` → 308 ke HTTPS
- Container `db`, `api`, `caddy` semuanya healthy

### Bukti backend membaca database VPS (6 Nov, setelah rebuild `a5f1b40`)

- Env backend: `postgresql+psycopg://…@db:5432/sales` — `is_supabase: False`
- PostgreSQL 17.11, `inet_server_addr()` = lokal (container `db`)
- Log 24 jam: 0 baris `ERROR`/`Traceback`/`Exception`; request nyata terlihat
  (`GET /api/v1/users` 200, `GET /reports/sales-performance/dashboard` 200,
  `GET /orders/pending` 200)
- Angka dashboard admin web cocok dengan isi database:
  | Angka dashboard (Banjarmasin) | Query database |
  |---|---|
  | Pesanan hari ini 20 (10 disetujui, 10 menunggu) | `APPROVED 10 + PENDING 10` |
  | Total Produk 2.054 | `products where branch='BANJARMASIN'` = 2.054 |
  | Total Toko 2.032 | `customers branch='BANJARMASIN' and deleted_at is null` = 2.032 |
  | Draft Pesanan 5 | `orders status='DRAFT'` = 5 |
- Uji API role: login 4 akun QA, MANAGER/SUPERVISOR boleh `GET /users`,
  ADMIN/SALES 403; MANAGER bisa buat SALES lintas cabang; SUPERVISOR hanya
  SALES di cabangnya; ADMIN/SALES gagal 403 (semua lulus).
- Catatan: `imported_sales` masih 0 baris pada snapshot ini; menu Imported
  Sales memang belum diaktifkan di admin web.

### Supabase selama staging

Supabase **tidak disentuh**. Pemeriksaan read-only dari `.env` lokal:

- Host `aws-0-ap-northeast-1.pooler.supabase.com:6543`, database `postgres`
- Saat diperiksa: users 52, orders 3.768, order terbaru
  `2026-11-06 06:56 UTC` (14:56 WITA)
- Artinya produksi masih menulis ke Supabase setelah snapshot VPS
  (`03:21 UTC`). Angka VPS akan tertinggal sampai dump final saat cutover.

Selisih snapshot VPS vs Supabase saat pemeriksaan:

| Tabel | VPS (snapshot) | Supabase (live) |
|---|---|---|
| users | 54 (48 asli + 6 QA/uji) | 52 |
| products | 8.623 | 8.627 |
| customers | 5.327 | 5.330 |
| orders | 3.667 | 3.768 |
| order_items | 11.314 | 11.646 |
| stok_log | 46.600 | 47.255 |
| imported_sales | 0 | 3 |
| suppliers | 126 | 128 |

Kesimpulan: snapshot tertinggal ±101 order. Saat cutover, dump final harus
mencakup **semua** tabel di atas (termasuk `imported_sales`) supaya tidak ada
data yang hilang.

## Yang masih perlu dilakukan

### 1. ~~Commit & push~~ — selesai

Commit `a5f1b40` sudah di-push; VPS sudah `git reset --hard origin/main`.

### 2. ~~Kebijakan kelola user~~ — selesai

Kebijakan final: **MANAGER global + SUPERVISOR (hanya SALES di cabangnya
sendiri)**. ADMIN dan SALES tidak boleh membuat user. Test
`test_security_hardening.py` sudah disesuaikan (26 passed).

### 3. Checklist cutover (belum selesai)

Konfigurasi inti sudah selesai dan teruji. Yang masih terbuka:

**Wajib diputuskan/dikerjakan sebelum cutover:**

1. **Strategi mobile lama.** APK lama hardcoded ke Railway. Pilihan:
   - paksa update sebelum cutover (paling aman untuk konsistensi data), atau
   - jadikan layanan Railway sebagai reverse proxy ke
     `https://api.madsalesapp.my.id` sehingga URL lama tetap hidup tanpa
     divergensi data (opsi transisi yang paling mulus), atau
   - tunda cutover sampai update mobile tersebar.
2. **Storage bulletin.** `.env.production` VPS belum punya
   `SUPABASE_URL`/`SUPABASE_SERVICE_KEY` maupun `AWS_*`, jadi upload PDF
   bulletin baru akan gagal. Pilih: isi kredensial Supabase Storage, atau
   simpan PDF lokal di VPS (perlu perubahan kode).
3. **Base URL frontend.** Tiga `config.dart` masih default ke Railway.
   Update defaultnya ke `https://api.madsalesapp.my.id/api/v1` atau selalu
   build dengan `--dart-define=API_BASE_URL=...`.
4. **Freeze writes.** Hentikan aplikasi Railway **sebelum** dump final
   Supabase, supaya tidak ada data masuk setelah dump.
5. **Final sync.** Dump final Supabase → restore ke VPS lewat
   `deploy/restore.sh` (skrip ini menghapus schema public, jadi akun QA dan
   data uji ikut hilang) → smoke test API, login, dashboard, dan hitung baris.
6. **Deploy frontend.** Build ulang `sales_web` + `admin_web`, deploy ke
   Firebase; distribusikan mobile.
7. **Simpan dump final + `.env.production` di luar VPS.** Backup offsite
   ditunda, tapi minimal salinan dump final dan `SECRET_KEY` harus ada di
   mesin lain.
8. **Pantau 1–2 jam.** Railway + Supabase tetap hidup sebagai rollback
   minimal 3–7 hari.

**Opsional tapi disarankan:** Uptime Kuma + Dozzle + health check eksternal
gratis ke `https://api.madsalesapp.my.id/health`.

## Rollback

Selama cutover belum dilakukan, Railway + Supabase masih menjadi produksi.
Kalau staging bermasalah, cukup hentikan container di VPS; tidak ada data
pengguna yang terpengaruh. Setelah cutover, rollback berarti mengembalikan
DNS/URL ke Railway dan Supabase.
