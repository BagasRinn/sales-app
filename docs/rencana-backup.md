# Rencana Backup & Restore

Status: **rencana saja — belum ada skrip atau jadwal yang dieksekusi.**

Dokumen ini melengkapi `docs/rencana-migrasi-vps.md`. Fokusnya: memastikan data order,
stok, customer, dan konfigurasi server bisa dipulihkan kalau VPS rusak, database korup,
atau terjadi kesalahan operasional.

---

## 1. Target

| Parameter | Target fase 1 | Catatan |
|---|---|---|
| **RPO** (maksimal data hilang) | **≤ 1 jam** | Backup penuh tiap jam; DB hanya 31 MB |
| **RTO** (waktu pemulihan) | **≤ 1 jam** | Restore dump + start ulang stack |
| Titik pemulihan | 48 jam terakhir per jam | Plus harian, mingguan, bulanan |
| Lokasi | 3-2-1 | lokal + offsite + arsip/snapshot |
| Enkripsi | Wajib | Backup berisi data pelanggan dan hash password |
| Uji restore | Bulanan | Backup yang belum diuji belum bisa disebut backup |

Kalau nanti butuh RPO < 1 jam (misalnya 5–15 menit), naikkan ke WAL archiving/pgBackRest.
Untuk ukuran dan pola pemakaian saat ini, dump per jam sudah lebih dari cukup.

---

## 2. Apa yang dibackup

| Objek | Isi | Frekuensi | Retensi | Prioritas |
|---|---|---|---|---|
| **Database** | `pg_dump` schema `public` + data | Tiap jam | 48 jam (hourly) | Kritis |
| Database harian | dump yang sama, prefix `daily/` | 01:05 WITA | 14 hari | Kritis |
| Database mingguan | dump yang sama, prefix `weekly/` | Minggu 02:05 | 8 minggu | Kritis |
| Database bulanan | dump yang sama, prefix `monthly/` | Tanggal 1, 03:05 | 6 bulan | Kritis |
| **Konfigurasi deploy** | `compose.prod.yaml`, `Caddyfile`, `.env.production`, `backup.sh`, `restore.sh`, unit systemd | Saat berubah + harian | 30 hari | Kritis |
| **Manifest** | commit git, versi Postgres, ukuran dump, SHA-256, waktu | Setiap backup | Ikut dump | Penting |
| **Uploads** (PDF bulletin) | volume lokal `uploads/` atau bucket S3/R2 | Harian | 30 hari | Sedang |
| **Snapshot VPS** | disk penuh | Sebelum upgrade/cutover | 7–14 hari | Operasional |
| **Dump final Supabase** | sebelum migrasi | Sekali | 90 hari | Kritis |
| Git repository | sudah ada di GitHub | Setiap push | Selamanya | Kritis |

Tidak perlu dibackup:

- Image Docker (bisa dibuild ulang dari git).
- Sertifikat Caddy (bisa diterbitkan ulang otomatis).
- OS dan paket (bisa provisioning ulang).
- Log aplikasi (kecuali ada kebutuhan audit; audit stok sudah ada di tabel `stok_log`).
- Schema internal Supabase (`auth`, `storage`, `realtime`, dll.).

Catatan: saat ini Supabase Storage berisi **0 object**, jadi belum ada file yang perlu
disalin. Kalau nanti bulletin sudah dipakai, tentukan dulu apakah file disimpan di lokal
VPS atau object storage.

---

## 3. Arsitektur 3-2-1

```
                    ┌─────────────────────────────┐
                    │  VPS: /opt/sales-app/backups │  ← copy 1 (cepat restore)
                    │  dump terenkripsi            │
                    └──────────────┬──────────────┘
                                   │ upload via TLS
                                   ▼
                    ┌─────────────────────────────┐
                    │  Object storage offsite      │  ← copy 2 (tahan VPS hilang)
                    │  Cloudflare R2 / B2 / VPS    │
                    │  bucket private + lifecycle  │
                    └──────────────┬──────────────┘
                                   │ unduh bulanan
                                   ▼
                    ┌─────────────────────────────┐
                    │  Laptop / external drive     │  ← copy 3 (arsip jangka panjang)
                    └─────────────────────────────┘
```

Rekomendasi penyedia offsite:

| Opsi | Kelebihan | Kekurangan |
|---|---|---|
| **Cloudflare R2** | 10 GB gratis, egress gratis, S3-compatible | Perlu akun Cloudflare |
| **Backblaze B2** | 10 GB gratis, murah, object lock | Egress terbatas 3× storage |
| **Object Storage VPS Murah** | Satu tagihan, mulai Rp5.000/bln | Masih satu penyedia dengan VPS |

Rekomendasi: **Cloudflare R2** sebagai offsite utama, lokal VPS sebagai copy cepat.
Kalau ingin semuanya satu tagihan, object storage VPS Murah cukup, tapi sadari risikonya
kalau seluruh datacenter/provider bermasalah.

---

## 4. Jadwal dan retensi

Semua waktu memakai **Asia/Makassar (WITA)**.

| Tier | Jadwal | Jumlah disimpan | Perkiraan ukuran |
|---|---|---|---|
| Hourly | setiap jam menit ke-5 | 48 file | ±48 × 6 MB = 288 MB |
| Daily | 01:05 | 14 file | ±84 MB |
| Weekly | Minggu 02:05 | 8 file | ±48 MB |
| Monthly | tanggal 1, 03:05 | 6 file | ±36 MB |
| Config | setiap perubahan + harian | 30 file | < 1 MB |
| Pre-migration | manual | 1 file | ±6 MB |
| Snapshot VPS | sebelum upgrade | 7–14 snapshot | tergantung provider |

Total perkiraan < 500 MB, masih jauh di bawah kuota gratis R2/B2 10 GB. Bahkan dengan
pertumbuhan database 10×, masih muat.

Prinsip retensi:

- Hourly untuk mengantisipasi kesalahan input/order dalam 1–2 hari terakhir.
- Daily untuk pemulihan mingguan.
- Weekly/monthly untuk audit dan kasus yang baru diketahui belakangan.
- Jangan menyimpan backup selamanya tanpa alasan; data pelanggan sebaiknya dibatasi.
- Backup pre-migration disimpan minimal 90 hari.

---

## 5. Enkripsi dan kredensial

Backup **wajib dienkripsi sebelum meninggalkan VPS**. Dump berisi:

- data customer (nama, alamat, kode area),
- user dan password hash,
- data order dan stok,
- konfigurasi `.env.production` yang berisi password DB dan `SECRET_KEY`.

Rekomendasi: **age** (simple, modern, satu keypair).

### Membuat keypair

Di laptop, bukan di VPS:

```bash
age-keygen -o sales-backup-key.txt
# Simpan file private key di password manager / media offline.
# Public key (age1...) ditempel di .env.backup server.
```

Aturan:

- **Private key tidak disimpan di VPS.** Kalau VPS compromis, penyerang tidak bisa
  mendekripsi backup offsite.
- Public key boleh ada di VPS untuk enkripsi.
- Simpan salinan private key di dua tempat aman (password manager + media offline).
- Jangan commit private key ke git.
- Ganti keypair kalau ada indikasi kebocoran; backup lama tetap bisa dibuka dengan key lama.

### Kredensial object storage

- Buat bucket **private**, bukan public.
- Buat token S3 khusus backup, hanya boleh `Object Read & Write` pada bucket tersebut.
- Aktifkan **versioning** dan, kalau tersedia, **object lock** untuk melindungi dari
  penghapusan/ransomware.
- Simpan kredensial di `/opt/sales-app/deploy/.env.backup` dengan `chmod 600`.
- Rotasi token setiap 6–12 bulan.
- Aktifkan 2FA di akun Cloudflare/B2.

Contoh `.env.backup`:

```dotenv
AGE_PUBLIC_KEY=age1...
R2_ACCOUNT_ID=...
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_BUCKET=sales-backups
R2_ENDPOINT=https://<account>.r2.cloudflarestorage.com
HEALTHCHECK_URL=https://hc-ping.com/<uuid>
```

---

## 6. Implementasi backup

### 6.1 Prasyarat di VPS

```bash
sudo apt update
sudo apt install -y age rclone curl jq
```

Tambahkan volume/mount untuk backup lokal:

```
/opt/sales-app/deploy/backups/
```

Pastikan hanya user `deploy` dan root yang bisa membaca:

```bash
chmod 700 /opt/sales-app/deploy/backups
chmod 600 /opt/sales-app/deploy/.env.backup
```

### 6.2 Alur skrip `backup.sh`

Skrip harus melakukan ini, berurutan, dan berhenti kalau ada langkah gagal:

1. **Lock** supaya tidak ada dua backup berjalan bersamaan (`flock`).
2. **Dump** database dari container Postgres 17:
   ```bash
   docker compose -f deploy/compose.prod.yaml exec -T db \
     pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
     --schema=public \
     --format=custom --compress=9 \
     --no-owner --no-privileges \
     --lock-wait-timeout=60s \
     > "$TMP_DUMP"
   ```
3. **Validasi dump** sebelum dienkripsi:
   ```bash
   docker compose -f deploy/compose.prod.yaml exec -T db \
     pg_restore --list < "$TMP_DUMP" > /dev/null
   ```
4. **Cek ukuran wajar**: kalau dump < 1 MB atau turun > 50% dari median 7 hari,
   anggap gagal dan kirim alert. Ini mencegah backup "kosong" lolos.
5. **Enkripsi**:
   ```bash
   age -r "$AGE_PUBLIC_KEY" -o "$TMP_DUMP.age" "$TMP_DUMP"
   sha256sum "$TMP_DUMP.age" > "$TMP_DUMP.age.sha256"
   ```
6. **Upload** ke offsite:
   ```bash
   rclone copyto "$TMP_DUMP.age" \
     "r2:$R2_BUCKET/db/hourly/$(basename "$TMP_DUMP.age")"
   rclone copyto "$TMP_DUMP.age.sha256" \
     "r2:$R2_BUCKET/db/hourly/$(basename "$TMP_DUMP.age.sha256")"
   ```
7. **Salin ke tier** kalau waktunya tepat:
   - jam 01 → `db/daily/`
   - hari Minggu → `db/weekly/`
   - tanggal 1 → `db/monthly/`
8. **Tulis manifest** `latest.json` berisi timestamp, commit git, versi Postgres,
   ukuran, SHA-256, dan nama file.
9. **Hapus file sementara** yang tidak terenkripsi.
10. **Retensi lokal**: hapus file lebih tua dari batas tier.
11. **Healthcheck**: ping URL sukses; kalau gagal, ping URL `/fail`.

Contoh kerangka:

```bash
#!/usr/bin/env bash
set -euo pipefail
umask 077

cd /opt/sales-app
source deploy/.env.backup

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TMP="$(mktemp /tmp/sales-backup.XXXXXX.dump)"
trap 'rm -f "$TMP" "$TMP.age" "$TMP.age.sha256"; curl -fsS -m 10 "$HEALTHCHECK_URL/fail" || true' ERR

exec 9>/var/lock/sales-backup.lock
flock -n 9 || { echo "Backup lain sedang berjalan"; exit 1; }

docker compose -f deploy/compose.prod.yaml exec -T db \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  --schema=public --format=custom --compress=9 \
  --no-owner --no-privileges --lock-wait-timeout=60s > "$TMP"

docker compose -f deploy/compose.prod.yaml exec -T db \
  pg_restore --list < "$TMP" > /dev/null

SIZE=$(stat -c %s "$TMP")
[ "$SIZE" -ge 1000000 ] || { echo "Dump terlalu kecil: $SIZE byte"; exit 1; }

age -r "$AGE_PUBLIC_KEY" -o "$TMP.age" "$TMP"
sha256sum "$TMP.age" > "$TMP.age.sha256"

rclone copyto "$TMP.age" "r2:$R2_BUCKET/db/hourly/$(basename "$TMP.age")"
rclone copyto "$TMP.age.sha256" "r2:$R2_BUCKET/db/hourly/$(basename "$TMP.age.sha256")"

# Salin ke tier harian/mingguan/bulanan sesuai jadwal (rclone copyto server-side).

rm -f "$TMP"
curl -fsS -m 10 "$HEALTHCHECK_URL" || true
```

Catatan: `POSTGRES_USER` dan `POSTGRES_DB` bisa dibaca dari `.env.production` atau
di-hardcode sesuai compose. Jangan menaruh password di skrip.

### 6.3 Konfigurasi backup

Selain database, buat arsip konfigurasi:

```bash
tar -czf "$TMP_CONFIG" \
  deploy/compose.prod.yaml \
  deploy/Caddyfile \
  deploy/.env.production \
  deploy/backup.sh \
  deploy/restore.sh \
  deploy/systemd/ \
  README.md
age -r "$AGE_PUBLIC_KEY" -o "$TMP_CONFIG.age" "$TMP_CONFIG"
rclone copyto "$TMP_CONFIG.age" "r2:$R2_BUCKET/config/$(date -u +%Y%m%dT%H%M%SZ).tar.gz.age"
```

Simpan juga `.env.production` di password manager, karena kalau VPS hilang dan backup
config ikut tidak terbaca, kamu tetap butuh `SECRET_KEY` dan password DB.

### 6.4 Penjadwalan dengan systemd timer

Lebih disarankan daripada cron karena tahan reboot dan log-nya rapi.

`/etc/systemd/system/sales-backup.service`:

```ini
[Unit]
Description=Backup database Sales App
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
User=deploy
WorkingDirectory=/opt/sales-app
ExecStart=/opt/sales-app/deploy/backup.sh
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
```

`/etc/systemd/system/sales-backup.timer`:

```ini
[Unit]
Description=Jalankan backup Sales App setiap jam

[Timer]
OnCalendar=*-*-* *:05:00
Persistent=true
RandomizedDelaySec=120

[Install]
WantedBy=timers.target
```

Aktifkan:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now sales-backup.timer
systemctl list-timers sales-backup.timer
journalctl -u sales-backup.service -n 100
```

Alternatif cron:

```cron
5 * * * * /opt/sales-app/deploy/backup.sh >> /var/log/sales-backup.log 2>&1
```

### 6.5 Snapshot VPS

- Ambil snapshot sebelum upgrade Postgres, perubahan besar, atau cutover.
- Snapshot bukan pengganti dump: kalau data korup/logical error, snapshot ikut korup.
- Simpan 7–14 hari.
- Cek apakah VPS Murah menyediakan snapshot/backup add-on dan berapa biayanya.

---

## 7. Verifikasi dan monitoring

### 7.1 Pemeriksaan otomatis setiap backup

- Exit code `pg_dump` dan `pg_restore --list`.
- Ukuran dump wajar.
- SHA-256 tersimpan.
- Upload ke offsite berhasil.
- Healthcheck ping sukses.

### 7.2 Dead man's switch

Gunakan **healthchecks.io** (atau Uptime Kuma):

- Buat check dengan periode **1 jam**, grace **15 menit**.
- Skrip ping URL di akhir backup.
- Kalau backup tidak jalan / gagal, healthchecks mengirim alert ke email/Telegram.
- Ini menangkap kasus "timer mati" atau "VPS mati", bukan hanya error skrip.

### 7.3 Alert tambahan

- Backup terakhir > 2 jam.
- Ukuran dump turun drastis.
- Disk VPS > 80%.
- Upload offsite gagal.
- Restore drill gagal.

### 7.4 Uji restore

| Uji | Frekuensi | Siapa |
|---|---|---|
| Backup manual + cek file | Setiap perubahan skrip | Operator |
| Restore ke database percobaan | **Bulanan** | Operator |
| Simulasi VPS hilang (restore ke VPS baru) | **Kuartalan** | Operator |
| Cek akses offsite dari mesin lain | Bulanan | Operator |

Catat hasilnya di `docs/backup-drill-log.md` (tanggal, file, ukuran, waktu restore,
hasil verifikasi, catatan).

---

## 8. Prosedur restore

### 8.1 Restore database ke VPS yang sama (data korup / salah hapus)

1. Hentikan API agar tidak ada write baru, biarkan Postgres jalan:
   ```bash
   docker compose -f deploy/compose.prod.yaml stop api
   ```
2. Unduh dan dekripsi dump terbaru:
   ```bash
   rclone copy "r2:$R2_BUCKET/db/hourly/" ./restore/
   age -d -i ~/sales-backup-key.txt \
     -o restore.dump restore/sales_...dump.age
   ```
3. Buat database percobaan dan restore ke sana:
   ```bash
   docker compose -f deploy/compose.prod.yaml exec -T db \
     psql -U postgres -c "CREATE DATABASE sales_restore OWNER sales_app;"

   docker compose -f deploy/compose.prod.yaml exec -T db \
     pg_restore -U sales_app -d sales_restore \
     --no-owner --no-privileges --exit-on-error < restore.dump
   ```
4. Verifikasi:
   ```sql
   SELECT count(*) FROM users;
   SELECT count(*) FROM orders;
   SELECT max(created_at) FROM orders;
   SELECT count(*) FROM stok_log;
   ```
5. Kalau bagus, arahkan `DATABASE_URL` ke `sales_restore` dan start API:
   ```bash
   docker compose -f deploy/compose.prod.yaml up -d api caddy
   ```
6. Setelah yakin, baru rename/swap database dan hapus database lama.

Jangan pernah restore langsung menimpa database produksi tanpa menyimpan dump kondisi
sekarang. Kalau restore salah, kamu butuh jalan kembali.

### 8.2 Restore total setelah VPS hilang

1. Order VPS baru, install Docker + `age` + `rclone`.
2. Clone repo pada commit yang tercatat di manifest:
   ```bash
   git clone <repo> /opt/sales-app
   git checkout <commit>
   ```
3. Restore konfigurasi:
   ```bash
   rclone copy "r2:$R2_BUCKET/config/" ./config/
   age -d -i ~/sales-backup-key.txt -o config.tar.gz config/<file>.age
   tar -xzf config.tar.gz
   ```
4. Isi ulang `.env.production` bila perlu (dari password manager).
5. Jalankan database:
   ```bash
   docker compose -f deploy/compose.prod.yaml up -d db
   ```
6. Restore dump terbaru ke database `sales`.
7. Jalankan API + Caddy:
   ```bash
   docker compose -f deploy/compose.prod.yaml up -d --build api caddy
   ```
8. Ubah DNS `api.domain.com` ke IP VPS baru.
9. Smoke test: login, katalog, buat order, approve, cek stok.
10. Simpan dump sebelum restore dan sesudah restore untuk audit.

Target RTO: **30–60 menit** setelah VPS baru siap.

### 8.3 Restore satu tabel / baris

- Restore dump ke database sementara `sales_restore`.
- Ambil tabel yang dibutuhkan:
  ```bash
  pg_dump -U sales_app -d sales_restore -t nama_tabel \
    --format=custom > tabel.dump
  ```
- Restore ke produksi dengan hati-hati, atau gunakan `COPY` untuk baris tertentu.
- Jangan restore seluruh database hanya untuk satu baris.

### 8.4 Rollback migrasi Supabase

- Gunakan dump final Supabase yang disimpan saat Fase 0 migrasi.
- Restore ke Postgres 17 lokal atau kembali ke Supabase.
- Simpan minimal 90 hari setelah cutover.

---

## 9. Uji coba sebelum produksi

Hasil uji pertama (6 November 2026) ada di **`docs/backup-drill-log.md`**: dump Supabase
3,04 MB berhasil direstore ke PostgreSQL 17, schema identik, backend bisa start, dan
startup DDL menambahkan kolom/index/tabel baru dengan benar. Temuan yang perlu ditindak
lanjuti: 94 `order_items` tanpa order induk yang sudah ada di sumber, dan perlunya
menangani `CREATE SCHEMA public` saat restore.

Checklist yang harus lulus sebelum backup dianggap selesai:

- [ ] Jalankan `backup.sh` manual, exit code 0.
- [ ] File `.age` dan `.sha256` muncul di lokal.
- [ ] `sha256sum -c` cocok.
- [ ] Upload ke R2 berhasil dan terlihat di bucket.
- [ ] Unduh dari mesin lain, dekripsi dengan private key.
- [ ] Restore ke container Postgres 17 baru tanpa error.
- [ ] Jumlah baris `users`, `orders`, `stok_log` sama dengan sumber.
- [ ] Backend bisa start terhadap database hasil restore.
- [ ] Login, buat draft order, submit, approve berhasil.
- [ ] Ukur waktu restore (target < 1 jam).
- [ ] Matikan database / salahkan kredensial → healthcheck mengirim alert.
- [ ] Uji retensi: file lama terhapus, file baru tetap ada.
- [ ] Catat hasil di `docs/backup-drill-log.md`.

---

## 10. Keamanan dan kepatuhan

- Backup mengandung data pribadi customer dan hash password. Perlakukan seperti data
  produksi.
- Enkripsi sebelum upload; bucket private; akses minimum.
- Private key tidak di VPS; simpan offline.
- Aktifkan 2FA pada akun Cloudflare/B2/VPS.
- Batasi masa simpan; hapus backup yang tidak lagi diperlukan.
- Audit akses bucket secara berkala.
- Jangan menaruh dump di git, Google Drive publik, atau folder yang disajikan web server.
- Kalau ada karyawan keluar, rotasi kredensial backup.

---

## 11. Perkiraan biaya

| Item | Biaya |
|---|---|
| Cloudflare R2 (10 GB gratis) | Rp0 untuk pemakaian sekarang |
| Backblaze B2 (10 GB gratis) | Rp0 untuk pemakaian sekarang |
| Object Storage VPS Murah | mulai Rp5.000/bulan |
| Disk VPS 60 GB | sudah termasuk |
| Snapshot VPS | cek add-on provider |
| **Total** | **±Rp0–5.000/bulan** |

Dengan ukuran backup < 1 GB, biaya backup praktis tidak signifikan dibanding VPS.

---

## 12. Keputusan yang perlu dikonfirmasi

1. **RPO**: 1 jam (rekomendasi) atau 24 jam? Kalau butuh < 1 jam, pakai WAL/pgBackRest.
2. **Offsite**: Cloudflare R2 (rekomendasi), Backblaze B2, atau object storage VPS Murah?
3. **Retensi**: 6 bulan (rekomendasi), 3 bulan, atau 12 bulan?
4. **Private key**: siapa yang memegang, dan di mana salinannya disimpan?
5. **Uploads**: akan disimpan di lokal VPS atau object storage?
6. **Snapshot VPS**: aktifkan add-on atau cukup dump?
7. **Jadwal restore drill**: bulanan tanggal berapa?

---

## 13. Checklist implementasi

- [ ] Buat bucket private + token terbatas.
- [ ] Generate keypair `age`, simpan private key offline.
- [ ] Install `age`, `rclone`, `curl`, `jq` di VPS.
- [ ] Buat `.env.backup` dan `chmod 600`.
- [ ] Buat `deploy/backup.sh` + `deploy/restore.sh`.
- [ ] Buat systemd service + timer.
- [ ] Buat healthchecks.io check + alert Telegram/email.
- [ ] Jalankan backup manual pertama.
- [ ] Uji restore ke database percobaan.
- [ ] Catat hasil di `docs/backup-drill-log.md`.
- [ ] Simpan dump final Supabase sebelum cutover.
- [ ] Jadwalkan restore drill bulanan.
