# Deployment VPS

Stack produksi untuk backend FastAPI + PostgreSQL 17 + Caddy dalam satu VPS.
Database tidak terbuka ke internet; hanya API yang bisa mengaksesnya lewat network
internal Docker.

```
Internet ──► Caddy :443 (HTTPS otomatis)
                └──► api:8000 (FastAPI)
                        └──► db:5432 (PostgreSQL, tanpa port publik)
```

## Isi folder

| File | Fungsi |
|---|---|
| `compose.prod.yaml` | Definisi service `db`, `api`, `caddy` |
| `Caddyfile` | Reverse proxy + TLS otomatis |
| `.env.production.example` | Template environment produksi |
| `backup.env.example` | Template konfigurasi backup |
| `backup.sh` | Dump + enkripsi + retensi + upload offsite opsional |
| `restore.sh` | Restore dump ke database produksi |

## 0. Bootstrap VPS (disarankan)

`bootstrap-vps.sh` menyiapkan VPS baru dalam satu langkah: user `deploy`, akses SSH,
sudo, Docker + Compose, UFW, fail2ban, update otomatis, timezone, dan swap 2 GB.

Dari laptop:

```bash
# 1. Buat SSH key kalau belum punya
ssh-keygen -t ed25519 -C "sales-app-vps"

# 2. Kirim skrip ke VPS
scp deploy/bootstrap-vps.sh root@<IP-VPS>:/root/

# 3. Jalankan, sambil mendaftarkan public key Anda
ssh root@<IP-VPS> \
  "SSH_PUBKEY='$(cat ~/.ssh/id_ed25519.pub)' bash /root/bootstrap-vps.sh"
```

Di Windows PowerShell, ganti `$(cat ~/.ssh/id_ed25519.pub)` dengan
`$(Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub -Raw)`. Kalau key sudah
terpasang oleh provider, `SSH_PUBKEY` boleh dilewati.

Setelah selesai, login sebagai `deploy`:

```bash
ssh deploy@<IP-VPS>
```

Skrip **tidak** akan mematikan login root/password kalau public key untuk `deploy`
belum ada, supaya Anda tidak terkunci. Jalankan ulang setelah key terpasang.

## 1. Prasyarat

- VPS Ubuntu 24.04, 2 vCPU / 4 GB RAM / 60 GB NVMe.
- Docker Engine + Compose plugin terpasang.
- DNS `A` record `api.<domain>` sudah mengarah ke IP VPS.
- Port 80 dan 443 terbuka di firewall.
- Repo sudah di-clone, misalnya ke `/opt/sales-app`.

Kalau memakai Cloudflare, awalnya pilih **DNS only** (bukan proxy oranye) supaya
Caddy bisa menerbitkan sertifikat Let's Encrypt. Proxy bisa diaktifkan nanti.

### Kalau VPS di belakang NAT provider

Beberapa provider (termasuk paket NAT VPS Murah) tidak meneruskan port 80/443
langsung ke VPS. IP publik adalah IP bersama, dan hanya port SSH yang di-NAT.
Ciri-cirinya:

- `ip -4 addr` menunjukkan IP privat (mis. `10.10.0.157`), bukan IP publik.
- Membuka `http://<IP-publik>/` menampilkan halaman provider
  “Domain belum terhubung ke VPS”.
- Caddy gagal menerbitkan sertifikat (`http-01` 404).

Langkah yang diperlukan:

1. Daftarkan domain di **my.vpsmurah.co.id → VPS Saya → Domain & Website**.
   Proxy provider akan meneruskan domain itu ke VPS.
2. Pastikan A record domain mengarah ke IP publik provider.

Perilaku yang terverifikasi pada paket NAT VPS Murah (6 November 2026):

- Port 80 diteruskan sebagai HTTP ke Caddy (ada header `X-Forwarded-Proto`).
- Port 443 diteruskan sebagai TCP passthrough, sehingga Caddy tetap bisa
  menerbitkan sertifikat Let's Encrypt lewat `http-01`.
- `Caddyfile` tidak perlu diubah: Caddy menangani TLS dan redirect HTTP→HTTPS.

Kalau provider memakai model berbeda (TLS diterminasi di proxy), baru ubah
situs Caddy menjadi `http://{$API_DOMAIN}` tanpa ACME.

Alternatif yang tidak bergantung pada proxy provider: **Cloudflare Tunnel**
(`cloudflared`) dengan domain yang nameserver-nya sudah pindah ke Cloudflare.

## 2. Siapkan environment

```bash
cd /opt/sales-app/deploy
cp .env.production.example .env.production
chmod 600 .env.production
```

Isi `.env.production`:

1. `API_DOMAIN` → domain final, mis. `api.salesapp.my.id`.
2. `POSTGRES_PASSWORD` → hasil `openssl rand -hex 24`.
3. `DATABASE_URL` → **sama persis** dengan password di atas.
4. `SECRET_KEY` → salin nilai lama dari Railway (jangan dirotasi saat migrasi).
5. `CORS_ORIGINS` → origin Firebase yang sekarang.

Jangan memakai karakter khusus di password database. Kalau terpaksa, URL-encode
nilainya di `DATABASE_URL` (mis. `@` menjadi `%40`).

## 3. Jalankan database

```bash
docker compose --env-file .env.production -f compose.prod.yaml up -d db
docker compose --env-file .env.production -f compose.prod.yaml ps
docker compose --env-file .env.production -f compose.prod.yaml logs db
```

Tunggu sampai status `healthy`.

## 4. Restore data dari Supabase

Dump yang dipakai adalah hasil `pg_dump --schema=public --format=custom` dari
Supabase (lihat `docs/backup-drill-log.md`).

```bash
# Dari folder deploy/
docker compose --env-file .env.production -f compose.prod.yaml exec -T db \
  sh -c 'cat > /tmp/restore.dump' < /path/ke/sales_final.dump

docker compose --env-file .env.production -f compose.prod.yaml exec -T db \
  sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
         -c "DROP SCHEMA public CASCADE;"'

docker compose --env-file .env.production -f compose.prod.yaml exec -T db \
  sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
         --no-owner --no-privileges --exit-on-error /tmp/restore.dump'
```

Atau langsung pakai skrip:

```bash
chmod +x restore.sh backup.sh
./restore.sh /path/ke/sales_final.dump
```

Catatan: dump Supabase menyertakan `CREATE SCHEMA public`. Karena database baru
sudah punya schema `public`, schema itu harus dikosongkan dulu seperti perintah
di atas.

## 5. Jalankan API + Caddy

```bash
docker compose --env-file .env.production -f compose.prod.yaml up -d --build api caddy
docker compose --env-file .env.production -f compose.prod.yaml ps
docker compose --env-file .env.production -f compose.prod.yaml logs -f api
```

Saat startup, backend akan:

- membuat tabel yang belum ada (`create_all`),
- menambahkan kolom/index `imported_sales` yang belum ada,
- memuat branch cache,
- menjalankan scheduler dengan timezone `Asia/Makassar`.

Verifikasi:

```bash
curl -sS https://api.<domain>/health
# {"status":"healthy"}

curl -sSI https://api.<domain>/api/v1/products
```

`/docs` dan `/openapi.json` harus 404 karena `ENVIRONMENT=production`.

## 6. Update frontend dan mobile

Setelah API baru stabil, ganti `baseUrl` di:

- `sales-app/lib/core/config.dart`
- `sales-app/sales_web/lib/core/config.dart`
- `sales-app/admin_web/lib/core/config.dart`

menjadi `https://api.<domain>/api/v1`, lalu build ulang web dan mobile.
Jangan matikan Railway sebelum aplikasi mobile lama tidak dipakai lagi.

## 7. Backup

Backup harian lokal:

```bash
cp backup.env.example backup.env
chmod 600 backup.env
# isi AGE_RECIPIENT (public key age) dan opsional RCLONE_REMOTE
./backup.sh
```

Contoh cron untuk user `deploy`:

```cron
15 2 * * * /opt/sales-app/deploy/backup.sh >> /var/log/sales-backup.log 2>&1
```

Tanpa `AGE_RECIPIENT`, backup tersimpan **plaintext**. Untuk produksi, enkripsi
dengan `age` dan simpan private key di tempat terpisah dari VPS.

Upload offsite saat ini ditunda. Kalau nanti diaktifkan, isi `RCLONE_REMOTE`
(mis. `r2:sales-backup`) dan pastikan `rclone config` sudah dijalankan untuk user
yang menjalankan cron.

## 8. Restore

```bash
./restore.sh /var/backups/sales/sales-20261106T120000Z.dump.age
```

Skrip akan:

1. dekripsi file `.age` kalau perlu,
2. memvalidasi arsip,
3. menghentikan API,
4. menghapus schema `public`,
5. restore ulang,
6. menyalakan API dan menunggu `/health`.

Gunakan `--yes` hanya untuk otomasi. Untuk produksi, jalankan manual dan baca
konfirmasinya.

## 9. Catatan operasional

- **Satu worker Uvicorn.** Jangan menaikkan worker tanpa memisahkan scheduler,
  karena job terjadwal bisa berjalan ganda.
- **Timezone container tetap UTC** agar perilaku timestamp sama dengan Railway.
  Scheduler sudah eksplisit memakai `Asia/Makassar`.
- **Jangan publish port 5432.** Cek dengan `sudo ss -tulpn` dan scan dari luar.
- **Log Docker** dibatasi 10 MB × 3 file per service.
- **Caddy** menyimpan sertifikat di volume `caddy_data`. Jangan hapus volume ini
  tanpa alasan.
- **Rollback**: selama masa observasi, Supabase dan Railway tetap hidup. Kalau
  cutover gagal sebelum ada write di VPS, kembalikan DNS ke Railway.
