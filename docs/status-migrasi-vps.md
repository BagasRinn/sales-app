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

## Yang masih perlu dilakukan

### 1. Putuskan commit & push

Working tree lokal masih jauh di depan commit `5819f66`:

- 38 file termodifikasi, 20 file/folder untracked
- Termasuk dedupe import sales, security hardening, dan service baru
- Kode ini sudah berjalan di VPS lewat arsip, tetapi belum masuk git
- Sebelum cutover sebaiknya di-commit dan di-push supaya VPS bisa
  `git pull` dan hasilnya reproducible

### 2. Putuskan kebijakan kelola user

Hasil uji backend lokal: **53 passed, 2 failed**.

Dua kegagalan ada di `tests/test_security_hardening.py`:

- Kode: hanya **MANAGER global** yang boleh membuat user; ADMIN tidak.
- Test: mengharapkan ADMIN boleh membuat SUPERVISOR dan mengelola user cabang.
- `README.md` menyebut ADMIN boleh “kelola user”.

Perlu keputusan: ikuti kode yang lebih ketat, atau longgarkan kode dan
perbarui test.

### 3. Siapkan cutover malam

Urutan yang direncanakan:

1. Umumkan ke pengguna bahwa aplikasi mobile akan diperbarui.
2. Update `baseUrl` di tiga `config.dart` ke
   `https://api.madsalesapp.my.id/api/v1`.
3. Build ulang web (`sales_web`, `admin_web`) dan mobile.
4. Malam cutover: hentikan penulisan di Railway, dump final Supabase,
   restore ke VPS, smoke test.
5. Deploy web ke Firebase dan distribusikan mobile.
6. Pantau 1–2 jam.

**Risiko yang harus diputuskan:** mobile lama masih hardcoded ke Railway.
Kalau Railway dibiarkan hidup setelah cutover, data baru dari pengguna lama
masuk ke Supabase dan tidak ada di VPS. Pilihannya:

- paksa update sebelum jam cutover (paling aman untuk konsistensi data), atau
- arahkan Railway ke database VPS selama masa transisi (butuh koneksi DB
  yang aman dari luar), atau
- terima divergensi dan sinkronkan manual setelah semua pengguna update.

## Rollback

Selama cutover belum dilakukan, Railway + Supabase masih menjadi produksi.
Kalau staging bermasalah, cukup hentikan container di VPS; tidak ada data
pengguna yang terpengaruh. Setelah cutover, rollback berarti mengembalikan
DNS/URL ke Railway dan Supabase.
