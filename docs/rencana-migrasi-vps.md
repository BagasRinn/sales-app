# Rencana Migrasi Backend + Database ke VPS Murah

Status: **staging di VPS sudah berjalan dan HTTPS publik aktif di `api.madsalesapp.my.id`.**
Cutover produksi tinggal menunggu jadwal malam. Lihat `docs/status-migrasi-vps.md`
untuk kondisi terkini.

Tujuan: memindahkan backend FastAPI dan PostgreSQL dari Railway + Supabase ke satu VPS
di Indonesia supaya biaya egress tetap/murah, latensi ke pengguna Indonesia lebih rendah,
dan biaya bulanan mudah diprediksi.

---

## 1. Ringkasan hasil audit

| Komponen | Kondisi sekarang | Dampak ke migrasi |
|---|---|---|
| Backend | FastAPI + Uvicorn, Docker, deploy di Railway | Dockerfile sudah ada, tinggal dipakai di VPS |
| Database | PostgreSQL 17.11 di Supabase, region `ap-northeast-1` (Tokyo), diakses lewat pooler port `6543` | Pindah ke Postgres 17 lokal di VPS yang sama dengan backend |
| Ukuran database | **31 MB**, 18 tabel di schema `public` | Dump/restore hitungan detik, downtime kecil |
| Data terbesar | `stok_log` ~44.7k baris, `products` ~8.6k, `customers` ~5.3k, `orders` ~3.6k | Tidak perlu strategi migrasi khusus |
| Storage | Supabase Storage: **0 object**, 1 bucket kosong | Tidak ada file yang perlu dipindahkan |
| Frontend | Flutter Web di Firebase Hosting; mobile memakai default URL Railway | Perlu rebuild web + rilis mobile baru setelah domain API aktif |
| Migration tool | Tidak ada Alembic; schema dibuat `Base.metadata.create_all()` + DDL idempotent saat startup | Restore dump lalu start app; tabel baru otomatis dibuat |
| Ekstensi DB | `pgcrypto`, `uuid-ossp`, dll. milik Supabase, **tidak dipakai aplikasi** (UUID dibuat di Python) | Cukup PostgreSQL vanilla |
| Auth | JWT custom, bukan Supabase Auth | Tidak ada dependensi ke Supabase Auth |
| File upload | Hanya PDF bulletin; saat ini belum ada data | Bisa tetap di Supabase Storage dulu, atau pindah ke S3/R2 nanti |

Artinya: **tidak ada ketergantungan aplikasi ke fitur khusus Supabase** selain PostgreSQL
dan (opsional) Storage. Migrasi database murni `pg_dump` → `pg_restore`.

---

## 2. Arsitektur target

```
Internet
   │
   ├── Firebase Hosting (sales_web & admin_web)  ← tetap dulu
   ├── Mobile app (Android/iOS)                  ← rebuild, arahkan ke api.domain.com
   │
   ▼
api.domain.com  ──►  Caddy (TLS otomatis, port 80/443)
                         │
                         ▼
                    FastAPI container (127.0.0.1 / network internal, :8000)
                         │
                         ▼
                    PostgreSQL 17 container (tanpa port publik)
                         │
                         ▼
                    Volume NVMe /var/lib/postgresql

Backup harian ──► object storage / S3 terpisah (terenkripsi)
Monitoring    ──► healthchecks.io / UptimeRobot → alert Telegram/email
```

Prinsip:

- Database **tidak boleh** terbuka ke internet. Hanya container backend yang bisa akses.
- Backend dan database berada di VPS yang sama → tidak ada egress DB lintas region.
- Caddy menangani HTTPS otomatis (Let's Encrypt), jadi tidak perlu beli sertifikat.
- Frontend tetap di Firebase pada fase ini. Kalau nanti egress Firebase juga besar,
  opsi berikutnya adalah Cloudflare Pages (bandwidth gratis) atau Nginx di VPS yang sama.

### 2.1 Temuan penting: VPS berada di belakang NAT provider

VPS `217.216.146.21` yang dipakai **bukan** IP milik VPS secara langsung. Di dalam
server, `eth0` mendapat `10.10.0.157/22`, dan IP publik itu adalah IP bersama
(shared) milik provider. Port SSH eksternal `20155` diteruskan ke internal `22`.

Perilaku yang sudah terverifikasi (6 November 2026):

- Port **80** diteruskan oleh reverse proxy provider ke Caddy di VPS
  (`X-Forwarded-Proto: http`, remote `10.10.0.1`).
- Port **443** diteruskan sebagai **TCP passthrough**. Klien menerima sertifikat
  Let's Encrypt milik Caddy, jadi TLS tetap ditangani Caddy.
- Domain **wajib** didaftarkan di **my.vpsmurah.co.id → VPS Saya →
  Domain & Website**. Sebelum terdaftar, provider menjawab dengan halaman
  “Domain belum terhubung ke VPS” dan Let's Encrypt gagal
  (`http-01` 404, `tls-alpn-01` connection error).
- Setelah domain terdaftar, `http-01` berhasil dan Caddy memperoleh sertifikat
  untuk `api.madsalesapp.my.id` (valid sampai 4 Feb 2027).

Konsekuensi konfigurasi:

- `Caddyfile` yang sekarang sudah benar: Caddy tetap menangani TLS otomatis dan
  mengalihkan HTTP ke HTTPS.
- Kalau domain API berubah, daftarkan domain baru itu di panel provider **dan**
  ganti `API_DOMAIN` di `deploy/.env.production`, lalu restart Caddy.
- SOA zona masih `a.misconfigured.dns.server.invalid`, tetapi A record `api`
  sudah tersimpan dan berfungsi. Perbaikan zona tetap disarankan agar perubahan
  record lain bisa dilakukan lewat panel.
- Alternatif yang tidak bergantung pada proxy provider: **Cloudflare Tunnel**
  (`cloudflared`) sehingga VPS hanya membuka koneksi keluar. Ini juga menyelesaikan
  masalah TLS, tetapi memerlukan domain yang nameserver-nya di Cloudflare.

---

## 3. Rekomendasi spesifikasi VPS & biaya

Berdasarkan konfigurator `vpsmurah.co.id` (harga komponen: vCPU Rp2.500/core/bulan,
RAM Rp5.000/GB/bulan, NVMe Rp1.500/GB/bulan, biaya dasar −Rp12.500, IPv4 dedicated
Rp35.000/bulan):

| Paket | Spesifikasi | Estimasi biaya/bulan* |
|---|---|---|
| Minimum | 1 vCPU / 1 GB / 20 GB NVMe | Rp25.000 + IP Rp35.000 = **Rp60.000** |
| **Rekomendasi** | **2 vCPU / 4 GB / 60 GB NVMe** | Rp102.500 + IP Rp35.000 = **±Rp137.500** |
| Lega | 4 vCPU / 8 GB / 120 GB NVMe | Rp217.500 + IP Rp35.000 = **±Rp252.500** |

\*Harga dapat berubah; cek ulang di halaman checkout. Object storage untuk backup mulai
Rp5.000/bulan. Domain `.my.id` mulai Rp29.000/tahun.

**Pilih 2 vCPU / 4 GB / 60 GB NVMe**, alasan:

- PostgreSQL + FastAPI + Caddy + Docker butuh ±1–1.5 GB. Dengan 2 GB, build image,
  import Excel besar, dan laporan bisa memicu OOM.
- 2 vCPU cukup untuk build di VPS dan request paralel.
- 60 GB memberi ruang untuk OS, image Docker, pertumbuhan DB, log, dan backup lokal.
- Lokasi **Indonesia** (latensi rendah, egress ke ISP lokal murah). Singapura hanya
  alternatif kalau stok Indonesia habis.
- Pilih **KVM**, bukan OpenVZ/LXC, supaya Docker dan PostgreSQL berjalan normal.
- OS: **Ubuntu 24.04 LTS** (lebih matang untuk Docker dibanding 26.04).
- **Wajib konfirmasi ke admin VPS Murah:** apakah bandwidth benar-benar unmetered/fair use
  dan apakah 1 IPv4 dedicated sudah termasuk. Ini poin krusial karena tujuan utama adalah
  egress murah.

> Catatan biaya: angka di atas adalah biaya tetap. Bandingkan dengan tagihan Railway +
> Supabase saat ini. Kalau egress Supabase/Railway sudah di atas ±20–30 GB/bulan, VPS
> dengan bandwidth tetap akan lebih murah dan predictable.

**Jangan pilih managed PostgreSQL** untuk sekarang: DB hanya 31 MB, self-host di VPS yang
sama menghilangkan biaya tambahan dan menghilangkan egress DB. Konsekuensinya backup dan
maintenance jadi tanggung jawab kita — sudah masuk rencana di Fase 5.

### Pilihan opsional saat order VPS

| Pilihan di halaman order | Pilih | Alasan |
|---|---|---|
| **Install Aplikasi** | **Tidak ada** | Stack kita pakai Docker Compose sendiri: PostgreSQL 17 container + FastAPI + Caddy. Template "Docker and Traefik" akan memasang Traefik yang bentrok dengan Caddy di port 80/443. Template "PostgreSQL" memasang Postgres di host (bisa terbuka publik, versi/config beda). Template lain (n8n, Nextcloud, dll.) tidak dipakai. |
| **Control Panel** | **Tidak ada** | cPanel/Plesk/DirectAdmin ditujukan untuk hosting PHP/shared dan menambah lisensi + RAM. Coolify/Dokploy bisa jadi GUI, tapi menambah 1–2 GB RAM dan kompleksitas. Untuk satu stack Docker, SSH + Compose + Caddy lebih ringan dan mudah direproduksi. |

Kalau nanti butuh monitoring tambahan, pasang Uptime Kuma **setelah** VPS aktif lewat
Docker (atau cukup pakai healthchecks.io gratis dari luar), jangan lewat template installer
karena port dan resource-nya bisa bentrok.

---

## 4. Supabase & Railway: pindah atau tetap?

**Keputusan yang direkomendasikan: pindahkan database ke VPS, dan pindahkan backend ke VPS
yang sama. Jangan dipisah.**

Perbandingan skenario:

| Skenario | Egress | Latensi | Biaya | Nilai |
|---|---|---|---|---|
| Backend + DB di VPS yang sama | Paling rendah (lokal) | Paling rendah | Tetap ±Rp137.500/bln | ✅ Rekomendasi |
| Backend di VPS, DB tetap Supabase Tokyo | Setiap query DB menyeberang internet | Lebih tinggi | VPS + Supabase | ❌ Tidak masuk akal |
| Backend tetap Railway, DB pindah VPS | Setiap query DB menyeberang internet | Lebih tinggi | Railway + VPS | ❌ Lebih buruk dari sekarang |
| Backend Railway + DB Supabase (sekarang) | Egress Railway + Supabase | Sedang | Usage-based | Hanya kalau tidak mau operasikan server |

### Bisakah bayar egress saja di Supabase tanpa upgrade ke Pro?

**Tidak.** Supabase tidak menyediakan add-on atau pay-as-you-go egress untuk plan Free.
Billing egress per GB hanya tersedia di plan berbayar (Pro/Team/Enterprise).

| Plan | Kuota egress | Kelebihan |
|---|---|---|
| Free | 5 GB uncached + 5 GB cached | Tidak bisa dibayar; kena grace period lalu dibatasi |
| Pro | 250 GB uncached + 250 GB cached | $0,09/GB uncached, $0,03/GB cached (jika spend cap dimatikan) |
| Team | 250 GB + 250 GB | Sama seperti Pro |

Detail penting:

- Plan Free yang melewati kuota akan mendapat notifikasi + grace period, lalu organisasi
  dibatasi. Pembatasan hilang di awal siklus berikutnya atau setelah upgrade.
- Di Pro, **spend cap aktif secara default**. Kalau ingin kelebihan egress benar-benar
  ditagih (bukan dibatasi), spend cap harus dimatikan.
- Kuota egress bersifat **unified**: database, Auth, Storage, Realtime, Edge Functions,
  dan log drain dihitung bersama.
- Aplikasi ini mengakses database lewat **Supavisor shared pooler** (port 6543), sehingga
  trafiknya tercatat sebagai **Shared Pooler Egress** — tetap dihitung egress.
- Backup manual lewat pooler juga menambah egress. Backup harian lewat pooler bisa
  memperbesar pemakaian.

Implikasi biaya: kalau egress masih di bawah 5 GB/bulan, Free memang Rp0. Begitu lewat,
biaya minimum adalah **Pro $25/bulan** (±Rp400 ribu dengan kurs ±Rp16.000/USD), bukan
sekadar membayar selisih beberapa GB. Pada titik itu VPS ±Rp137.500/bulan sudah jauh
lebih murah, apalagi karena backend ikut pindah dan tidak ada egress DB lintas region.

### Apa yang terjadi kalau kena pembatasan?

Supabase tidak menjamin bentuk pembatasannya selalu sama. Menurut Fair Use Policy,
restriksi bisa berupa salah satu atau kombinasi:

- **Project di-pause** → aplikasi tidak bisa connect sama sekali.
- **Database dijadikan read-only** → login dan baca data mungkin masih jalan, tetapi
  create order, approve, update stok, dan semua write gagal.
- **Semua request API dibalas HTTP 402** → backend gagal mengambil/menyimpan data.
- **Pembuatan/transfer project baru diblokir** (tidak terlalu relevan untuk aplikasi ini).

Untuk aplikasi order sales, dampaknya bisa **total outage**: login pun melakukan query ke
tabel `users`, jadi kalau akses DB diblokir, semua user gagal login. Jangan menganggap
pembatasan hanya "data tidak bisa dibaca" — bisa jadi aplikasi berhenti total.

Alur waktunya:

1. Melewati kuota → notifikasi email + **grace period**.
2. Masih melewati kuota setelah grace period → restriksi diterapkan.
3. Restriksi berlaku untuk **semua project dalam organisasi**, bukan hanya satu project.
4. Restriksi hilang di awal siklus billing berikutnya, atau langsung setelah upgrade ke Pro
   (Free) / mematikan spend cap (Pro).
5. Setelah pernah kena, peringatan di dashboard tetap muncul. Kalau melewati kuota lagi,
   **tidak ada grace period kedua** — langsung dibatasi.
6. Pausing atau menghapus project **tidak menghapus pemakaian** yang sudah terjadi di
   siklus berjalan; kuota tetap terhitung sampai siklus reset.

Karena ini aplikasi produksi yang dipakai sales untuk membuat order, menjalankannya di
Free Plan saat pemakaian sudah mendekati 5 GB berisiko outage tanpa peringatan yang cukup.
Pilihannya: upgrade Pro, atau pindahkan DB ke VPS sebelum kuota habis.

Alasan memindahkan **database**:

- Ukurannya hanya 31 MB dan tidak memakai fitur khas Supabase (Auth, RLS, Realtime,
  ekstensi khusus). Tidak ada alasan teknis untuk tetap di Supabase.
- Kalau backend di VPS tapi DB tetap di Tokyo, semua query tetap menyeberang internet.
  Ini justru menambah latensi dan bisa tetap menghasilkan egress.
- Database yang berada di container yang sama dengan backend menghilangkan biaya dan
  latensi jaringan DB sepenuhnya.
- Supabase **tetap disimpan 2–4 minggu** setelah cutover sebagai rollback, baru dihapus.

Kapan sebaiknya **tetap** di Supabase? Kalau kamu tidak ingin mengurus backup, patching,
dan monitoring database, dan tagihan egress sekarang masih kecil. Tapi konsekuensinya
tujuan "egress murah" tidak tercapai, dan backend sebaiknya juga tetap di Railway.

Alasan memindahkan **backend**:

- Supaya dekat dengan database. Backend di Railway + DB di VPS adalah kombinasi terburuk:
  setiap request melakukan query lintas internet.
- Dockerfile sudah siap; VPS hanya menjalankan image yang sama.
- Kenyamanan Railway (auto-deploy, log) bisa diganti GitHub Actions atau satu skrip
  `git pull && docker compose up -d --build`.
- Railway **tetap dipertahankan sementara** sampai aplikasi mobile lama tidak dipakai lagi
  (lihat risiko di bagian 9).

Untuk **Supabase Storage**: karena saat ini 0 object, tidak ada migrasi file. Pilihan:
biarkan di Supabase selama transisi, atau langsung arahkan ke S3/R2/local disk saat
Supabase dihapus. Ini tidak memengaruhi keputusan DB/backend.

## 5. Keputusan sebelum eksekusi

Status per 6 November 2026:

| # | Topik | Keputusan | Status |
|---|---|---|---|
| 1 | Domain API | **Beli `.my.id` sekarang**; produksi `api.<domain>.my.id`, staging pakai alamat gratis | ⏳ menunggu domain dibeli |
| 2 | Cutover window | **Malam hari**, di luar jam sales | ✅ disetujui — tapi dipercepat karena egress hampir limit |
| 3 | Aplikasi mobile lama | Aman; cukup beri pemberitahuan update ke pengguna | ✅ disetujui |
| 4 | Frontend | **Tetap di Firebase** untuk fase ini | ✅ disetujui |
| 5 | Backup offsite | Ditunda dulu | ⏸️ ditunda |
| 6 | Docker Compose | Setuju dipakai | ✅ disetujui |
| 7 | `SECRET_KEY` | **Tetap pakai nilai sekarang**, tidak dirotasi | ✅ disetujui |

Keputusan ini menggantikan daftar pertanyaan awal. Yang masih perlu dijawab hanya
**nama domain** (poin 1), karena semua langkah DNS dan `baseUrl` bergantung padanya.

### 5.1 Subdomain yang dipakai

Rekomendasi: **`api.<domain-anda>`**, misalnya `api.salesapp.my.id`.

Alasannya:

- Satu nama khusus untuk backend, mudah diingat dan mudah diganti nanti.
- Tidak bercampur dengan frontend, jadi kalau frontend pindah hosting, URL API tidak berubah.
- Caddy bisa menerbitkan sertifikat Let's Encrypt otomatis untuk subdomain ini.
- Pola ini sama dengan yang sekarang dipakai Railway (`.../api/v1`), jadi perubahan di
  kode hanya mengganti host.

Kalau nanti frontend ikut pindah ke VPS, skema subdomain yang disarankan:

| Subdomain | Isi |
|---|---|
| `api.<domain>` | Backend FastAPI (sekarang) |
| `admin.<domain>` | Admin web (Flutter Web build) |
| `order.<domain>` | Sales web (Flutter Web build) |
| `<domain>` / `www.<domain>` | Landing page atau redirect, opsional |

#### Bisakah tetap memakai alamat yang sekarang?

Tidak untuk API. Alamat yang dipakai sekarang bukan domain milik kita:

| Komponen | Alamat sekarang | Bisa diarahkan ke VPS? |
|---|---|---|
| API | `sales-app-production-1872.up.railway.app` | ❌ Milik Railway, hanya bisa menunjuk service Railway |
| Admin web | `sales-admin-web.web.app` | ✅ Tetap dipakai, memang tidak pindah |
| Sales web | `sales-order-web.web.app` | ✅ Tetap dipakai, memang tidak pindah |

`*.up.railway.app` tidak bisa dijadikan A record ke IP VPS. Frontend `*.web.app` aman
karena tetap di Firebase.

Satu-satunya cara mempertahankan URL API lama adalah **menahan Railway sebagai reverse
proxy tipis** ke VPS. Dengan begitu APK lama tetap jalan tanpa update. Tapi Railway tetap
berada di jalur trafik dan tetap menagih egress, jadi ini hanya cocok sebagai masa
transisi singkat — bukan solusi permanen.

#### Opsi gratis dulu, bayar nanti

Secara teknis bisa. Pilihannya:

| Opsi | Alamat contoh | Kelebihan | Kekurangan |
|---|---|---|---|
| **DuckDNS** | `namakita.duckdns.org` | Gratis, Caddy bisa pasang HTTPS otomatis | Milik pihak lain, pernah downtime, sebagian jaringan memblokir |
| **FreeDNS (afraid.org)** | `namakita.mooo.com` | Gratis, banyak pilihan domain | Antarmuka lawas, kualitas domain tidak seragam |
| **nip.io / sslip.io** | `api.203.0.113.10.nip.io` | Tanpa daftar, langsung resolve ke IP | Jelek, rawan kena rate limit sertifikat, **jangan untuk produksi** |
| **Cloudflare Tunnel quick** | `random-xxx.trycloudflare.com` | Gratis, tanpa buka port | URL acak dan berubah, tidak cocok untuk API |

Kalau tetap mau gratis untuk produksi, **DuckDNS** paling masuk akal. Tapi ada biaya
tersembunyi: saat nanti pindah ke domain berbayar, Anda harus mengulang:

1. Ganti `baseUrl` di tiga `config.dart`.
2. Build ulang `sales_web` dan `admin_web`, deploy ke Firebase.
3. Build ulang APK/IPA dan distribusikan lagi ke semua perangkat.
4. Umumkan update lagi ke pengguna.
5. Uji ulang CORS dan login di semua platform.

Artinya migrasi dikerjakan **dua kali**. Domain `.my.id` hanya ±Rp29.000/tahun — jauh lebih
murah daripada biaya operasional mengulang distribusi aplikasi.

#### Keputusan: beli domain berbayar sekarang

Disetujui 6 November 2026: **beli `.my.id` sekarang** untuk produksi, sementara staging
boleh memakai alamat gratis. Alasannya, mengganti domain setelah produksi berjalan berarti
mengulang build web + mobile dan distribusi ulang ke pengguna.

1. **Beli `.my.id` sekarang** (1 tahun) dan pakai `api.<domain>` untuk produksi.
2. **Untuk staging sebelum cutover**, boleh pakai alamat gratis (`api.<IP>.nip.io` atau
   DuckDNS) karena URL staging tidak perlu permanen dan tidak dipakai pengguna.
3. Frontend tidak perlu domain berbayar: Firebase `*.web.app` sudah gratis, dan kalau
   nanti pindah ke Cloudflare Pages tersedia `*.pages.dev` gratis.
4. Jadi satu-satunya komponen yang benar-benar butuh domain sendiri adalah **API**.

Yang dibutuhkan dari Anda: **nama domain** (atau konfirmasi mau beli `.my.id` sekarang)
dan **akses DNS**-nya.

Catatan DNS: buat **A record** `api` → IP VPS. Kalau memakai Cloudflare, awalnya pakai
mode **DNS only** (bukan proxy oranye) supaya Caddy bisa menerbitkan sertifikat tanpa
konflik. Proxy bisa diaktifkan setelah TLS stabil.

### 5.2 Kalau frontend nanti pindah dari Firebase

Dua opsi yang realistis:

| Opsi | Kelebihan | Kekurangan | Cocok kalau |
|---|---|---|---|
| **Cloudflare Pages** (rekomendasi) | Bandwidth & request statis gratis, CDN global, deploy dari Git, HTTPS otomatis, tidak menambah beban VPS | Perlu akun Cloudflare dan domain diarahkan ke sana | Ingin egress frontend tetap Rp0 dan VPS tetap ringan |
| **Caddy/Nginx di VPS yang sama** | Semua di satu tempat, satu tagihan, kontrol penuh | Bandwidth frontend keluar dari VPS; build Flutter Web ikut memakai RAM/disk VPS | Trafik web kecil dan ingin semuanya self-hosted |

Rekomendasi: **Cloudflare Pages**. Alasannya, tujuan utama migrasi ini adalah menekan
egress. Flutter Web menghasilkan banyak file statis (main.dart.js, CanvasKit, font), dan
aset seperti itu paling murah disajikan lewat CDN dengan bandwidth gratis. VPS sebaiknya
fokus melayani API + database.

Kalau tetap ingin self-host di VPS: build `flutter build web` untuk `sales_web` dan
`admin_web`, taruh hasilnya di `/srv/sales-web` dan `/srv/admin-web`, lalu tambahkan blok
`admin.<domain>` dan `order.<domain>` di `Caddyfile` dengan `root * /srv/...` dan
`file_server`. Ini sudah cukup, tidak perlu Nginx terpisah.

### 5.3 Urgensi karena egress hampir limit

Karena egress Supabase hampir menyentuh batas, jangan menunggu jadwal "ideal". Urutan
yang disarankan:

1. **Sekarang**: selesaikan nama domain + order VPS (langkah paling lama karena propagasi
   dan provisioning).
2. **Hari yang sama VPS aktif**: jalankan Fase 0–3 (backup, provision, stack, restore) —
   ini tidak mengganggu produksi karena masih memakai Supabase/Railway.
3. **Malam pertama setelah stack VPS lolos smoke test**: cutover Fase 4.
4. Kalau egress ternyata mentok sebelum VPS siap: matikan fitur yang paling banyak
   menghasilkan trafik (misalnya backup manual berulang lewat pooler) dan prioritaskan
   cutover. Jangan menunggu hingga akun kena restriksi.

Backup harian lewat pooler juga menambah egress, jadi setelah cutover backup diambil dari
PostgreSQL lokal di VPS, bukan dari Supabase.

---

## 6. Rencana eksekusi

### Fase 0 — Persiapan & backup (≈1 jam)

- [ ] Catat semua environment variable di Railway (bukan hanya yang ada di `.env.example`):
      `DATABASE_URL`, `SECRET_KEY`, `CORS_ORIGINS`, `ENVIRONMENT`, `SEED_DEMO_USERS`,
      `RUN_SCHEDULER`, dan kredensial storage (`AWS_*` / `SUPABASE_*`) bila ada.
- [ ] Simpan `SECRET_KEY` yang sekarang di password manager. Ganti nanti hanya kalau
      memang ingin memaksa semua user login ulang.
- [ ] Buat backup penuh Supabase:
      ```bash
      # Gunakan koneksi langsung (port 5432) atau session pooler.
      # JANGAN pakai transaction pooler port 6543 untuk pg_dump.
      pg_dump "$SUPABASE_DB_URL" \
        --schema=public \
        --no-owner --no-privileges \
        --format=custom --compress=9 \
        --file=sales_before_vps_$(date +%F).dump
      ```
      Kalau `pg_dump` lokal belum ada, jalankan lewat Docker:
      ```bash
      docker run --rm -v "$PWD:/dump" postgres:17 \
        pg_dump "$SUPABASE_DB_URL" --schema=public --no-owner --no-privileges \
        --format=custom --file=/dump/sales_before_vps.dump
      ```
- [ ] Uji restore dump itu ke container Postgres lokal/percobaan. Jangan baru tahu dump
      rusak saat cutover.
- [ ] Catat baseline jumlah baris tabel penting:
      `users`, `products`, `customers`, `orders`, `order_items`, `stok_log`,
      `imported_sales`, `import_logs`.
- [ ] Turunkan TTL DNS domain API menjadi 300 detik, 24 jam sebelum cutover.
- [ ] Pastikan akses ke dashboard Railway, Supabase, Firebase, dan DNS.

### Fase 1 — Provision & hardening VPS (≈1 jam)

- [ ] Order VPS: 2 vCPU / 4 GB / 60 GB NVMe, Indonesia, Ubuntu 24.04, IPv4 dedicated.
- [ ] Simpan IP, user root, dan password awal dari panel.
- [ ] **Cara cepat:** jalankan `deploy/bootstrap-vps.sh` sebagai root (lihat
      `deploy/README.md`). Skrip itu melakukan pembuatan user, hardening, firewall,
      Docker, timezone, dan swap di bawah. Langkah manual berikut bisa dipakai sebagai
      referensi atau kalau skrip tidak dipakai.
- [ ] Login SSH, lalu:
      ```bash
      adduser deploy
      usermod -aG sudo deploy
      rsync --archive --chown=deploy:deploy ~/.ssh /home/deploy
      ```
- [ ] Hardening dasar:
      ```bash
      # SSH: nonaktifkan login root & password
      sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
      sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
      sudo systemctl restart ssh

      # Firewall
      sudo ufw default deny incoming
      sudo ufw default allow outgoing
      sudo ufw allow 22/tcp
      sudo ufw allow 80/tcp
      sudo ufw allow 443/tcp
      sudo ufw enable

      # Fail2ban & update otomatis
      sudo apt update && sudo apt install -y fail2ban unattended-upgrades
      sudo systemctl enable --now fail2ban
      sudo dpkg-reconfigure -plow unattended-upgrades
      ```
- [ ] Set timezone server ke `Asia/Makassar` (aplikasi memakai WITA untuk tampilan):
      `sudo timedatectl set-timezone Asia/Makassar`
- [ ] Tambah swap 2 GB sebagai pengaman (walau RAM 4 GB):
      ```bash
      sudo fallocate -l 2G /swapfile
      sudo chmod 600 /swapfile
      sudo mkswap /swapfile
      sudo swapon /swapfile
      echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
      ```
- [ ] Install Docker Engine + Compose plugin dari repo resmi Docker.
- [ ] Buat DNS `A` record `api.domain.com` → IP VPS. Tunggu propagasi.
- [ ] (Opsional) aktifkan Cloudflare proxy setelah setup TLS stabil. Untuk tahap awal,
      gunakan **DNS only** agar Caddy bisa menerbitkan sertifikat tanpa konflik.

### Fase 2 — Susun stack produksi (≈2 jam)

File deployment **sudah dibuat** dan siap dipakai (belum dijalankan ke server):

- `deploy/compose.prod.yaml` — `db` + `api` + `caddy`, DB tanpa port publik
- `deploy/Caddyfile` — reverse proxy + TLS otomatis
- `deploy/.env.production.example` — template rahasia (salin ke `.env.production`)
- `deploy/backup.env.example` — template konfigurasi backup
- `deploy/backup.sh` — dump + enkripsi age + retensi + upload offsite opsional
- `deploy/restore.sh` — restore dengan konfirmasi dan health check
- `deploy/README.md` — langkah operasional lengkap

Contoh inti `compose.prod.yaml`:

```yaml
services:
  db:
    image: postgres:17
    restart: unless-stopped
    environment:
      POSTGRES_DB: sales
      POSTGRES_USER: sales_app
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    command:
      - postgres
      - -c
      - shared_buffers=1GB
      - -c
      - effective_cache_size=3GB
      - -c
      - work_mem=16MB
      - -c
      - max_connections=50
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sales_app -d sales"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks: [internal]
    # TIDAK ada "ports:" — database tidak boleh publik

  api:
    build:
      context: ..
      dockerfile: Dockerfile
    restart: unless-stopped
    env_file: .env.production
    depends_on:
      db:
        condition: service_healthy
    expose:
      - "8000"
    networks: [internal, web]
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  caddy:
    image: caddy:2
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - api
    networks: [web]

volumes:
  pgdata:
  caddy_data:
  caddy_config:

networks:
  internal:
    internal: true
  web:
```

`Caddyfile`:

```
api.domain.com {
    encode gzip
    reverse_proxy api:8000
    header {
        -Server
    }
}
```

`.env.production` (jangan commit):

```dotenv
DATABASE_URL=postgresql+psycopg://sales_app:GANTI_PASSWORD_KUAT@db:5432/sales

SECRET_KEY=SALIN_DARI_RAILWAY
CORS_ORIGINS=https://sales-admin-web.web.app,https://sales-order-web.web.app
ENVIRONMENT=production
SEED_DEMO_USERS=false
RUN_SCHEDULER=true

# Storage opsional — kosongkan dulu kalau belum dipakai
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
# AWS_BUCKET_NAME=
# AWS_ENDPOINT_URL=
```

Langkah:

- [ ] Clone repo ke `/opt/sales-app` dengan user `deploy`.
- [ ] Salin `deploy/.env.production.example` → `.env.production`, isi nilainya,
      lalu `chmod 600 .env.production`.
- [ ] Jalankan `docker compose -f deploy/compose.prod.yaml up -d db` lalu cek
      `docker compose logs db`.
- [ ] Restore dump ke database kosong (lihat Fase 3).
- [ ] Jalankan `docker compose up -d --build api caddy`, cek log startup:
      `create_all`, index `imported_sales`, scheduler, CORS.
- [ ] Verifikasi `https://api.domain.com/health` → `{"status":"healthy"}`.
- [ ] Pastikan `/docs` dan `/openapi.json` **404** karena `ENVIRONMENT=production`.
- [ ] Cek `docker compose ps`, `docker stats`, dan `free -h`.

Catatan worker: Dockerfile memakai satu proses Uvicorn. **Pertahankan 1 worker** dulu.
Kalau nanti butuh lebih dari satu worker, scheduler harus dipisah (misalnya satu container
dengan `RUN_SCHEDULER=true` dan worker lain `false`), karena kalau tidak job terjadwal
bisa berjalan ganda.

### Fase 3 — Migrasi database (≈1 jam, termasuk verifikasi)

- [ ] Umumkan maintenance window.
- [ ] Hentikan backend Railway (scale to zero / stop service) supaya tidak ada write baru.
      Jangan hanya mengandalkan "sebentar lagi selesai".
- [ ] Dump final dari Supabase (perintah Fase 0, dengan nama file final).
- [ ] Restore ke VPS:
      ```bash
      docker compose -f deploy/compose.prod.yaml exec -T db \
        psql -U sales_app -d postgres -c "CREATE DATABASE sales OWNER sales_app;"

      # Dump dari Supabase menyertakan "CREATE SCHEMA public". Database baru
      # sudah punya schema public, jadi kosongkan dulu sebagai owner database.
      docker compose -f deploy/compose.prod.yaml exec -T db \
        psql -U sales_app -d sales -c "DROP SCHEMA public CASCADE;"

      cat sales_final.dump | docker compose -f deploy/compose.prod.yaml exec -T db \
        pg_restore -U sales_app -d sales --no-owner --no-privileges --exit-on-error
      ```
      (Kalau database `sales` sudah dibuat oleh `POSTGRES_DB`, lewati `CREATE DATABASE`.)

      Alternatif yang lebih aman kalau tidak ingin drop schema: filter entry
      `SCHEMA - public` dari TOC lalu restore dengan `pg_restore -L`:
      ```bash
      pg_restore -l sales_final.dump \
        | grep -v 'SCHEMA - public' > sales_final.toc
      pg_restore -L sales_final.toc -d sales --no-owner --no-privileges --exit-on-error
      ```
      Hasil uji restore 6 Nov 2026: dump 3,04 MB, 18 tabel, schema/kolom/index/constraint
      identik dengan sumber. Detail di `docs/backup-drill-log.md`.
- [ ] Start backend VPS. `create_all` akan membuat tabel yang belum ada di dump
      (di produksi ada 18 tabel; model saat ini punya beberapa tabel baru seperti
      `sales_import_versions`, `imported_sales_monthly_summary`,
      `imported_sales_summary_state`).
- [ ] Verifikasi:
      ```sql
      SELECT count(*) FROM users;
      SELECT count(*) FROM products;
      SELECT count(*) FROM customers;
      SELECT count(*) FROM orders;
      SELECT count(*) FROM order_items;
      SELECT count(*) FROM stok_log;
      SELECT max(created_at) FROM stok_log;
      SELECT count(*) FROM pg_indexes WHERE schemaname = 'public';
      ```
      Bandingkan dengan baseline Fase 0.
- [ ] Cek khusus `imported_sales`:
      kolom `dedupe_key` ada, unique index `uq_imported_sales_dedupe_key` ada, dan index
      `ix_imported_sales_branch_sale_date` ada.
- [ ] Jalankan `VACUUM ANALYZE;` (opsional, DB kecil).
- [ ] Smoke test lewat IP/domain sementara:
      login admin, buka katalog, buat draft order, submit, approve di admin web,
      cek stok dan laporan. Hapus/benarkan data uji setelahnya.

### Fase 4 — Cutover domain & frontend (≈1 jam + propagasi DNS)

- [ ] Arahkan DNS `api.domain.com` dari Railway ke IP VPS (TTL sudah rendah).
- [ ] Verifikasi dari luar:
      ```bash
      curl -sS https://api.domain.com/health
      curl -sSI https://api.domain.com/api/v1/products
      ```
- [ ] Uji CORS dari browser: buka admin web Firebase, login, pastikan tidak ada error CORS.
- [ ] Update default base URL di tiga file:
      - `sales-app/lib/core/config.dart`
      - `sales-app/sales_web/lib/core/config.dart`
      - `sales-app/admin_web/lib/core/config.dart`
      menjadi `https://api.domain.com/api/v1`.
- [ ] Commit + push → workflow Firebase otomatis rebuild `sales_web` & `admin_web`.
- [ ] Build & distribusikan ulang aplikasi mobile (APK/IPA) ke semua perangkat.
- [ ] Pantau log Caddy + backend selama 1–2 jam pertama.
- [ ] Jangan matikan Railway/Supabase sampai minimal 3–7 hari stabil.

### Fase 5 — Backup, monitoring, dan hardening (≈2 jam)

- [ ] Terapkan **`docs/rencana-backup.md`**: dump Postgres tiap jam, enkripsi `age`,
      upload offsite (R2/B2), retensi bertingkat, systemd timer, dan healthcheck.
- [ ] Wajib: simpan salinan backup di lokasi berbeda dari VPS (bukan hanya folder yang
      sama).
- [ ] Wajib: **uji restore bulanan** ke database percobaan. Backup yang belum pernah
      direstore belum bisa disebut backup.
- [ ] Simpan dump final Supabase sebelum cutover minimal 90 hari.
- [ ] Monitoring uptime: healthchecks.io / UptimeRobot memantau
      `https://api.domain.com/health`, alert ke Telegram/email.
- [ ] Monitoring disk: cron sederhana yang alert kalau `df` > 80%.
- [ ] Log rotation Docker sudah diset di compose; pastikan tidak memenuhi disk.
- [ ] Batasi akses SSH, matikan password login, aktifkan `unattended-upgrades`.
- [ ] Pastikan port 5432 tidak terbuka: `sudo ss -tulpn` dan scan dari luar.
- [ ] Opsional: tambahkan rate limit untuk `/api/v1/auth/login` di reverse proxy
      (Caddy butuh plugin, atau ganti Nginx + `limit_req`). Saat ini belum ada rate limit
      login di aplikasi.
- [ ] Opsional: snapshot VPS sebelum setiap upgrade besar.

### Fase 6 — Decommission (setelah 2–4 minggu stabil)

- [ ] Pastikan semua pengguna mobile sudah memakai versi baru.
- [ ] Simpan dump final Supabase + konfigurasi lama di tempat aman.
- [ ] Hentikan Railway dan Supabase.
- [ ] Update `README.md` dan `.env.example` (hapus referensi Supabase/Railway,
      ganti dengan PostgreSQL lokal + domain baru).
- [ ] Update dokumentasi deployment di repo.

---

## 7. Perubahan kode/konfigurasi yang diperlukan

| File | Perubahan | Wajib? |
|---|---|---|
| `sales-app/lib/core/config.dart` | default `baseUrl` → domain baru | Ya |
| `sales-app/sales_web/lib/core/config.dart` | default `baseUrl` → domain baru | Ya |
| `sales-app/admin_web/lib/core/config.dart` | default `baseUrl` → domain baru | Ya |
| `deploy/compose.prod.yaml` | stack produksi | Ya |
| `deploy/Caddyfile` | reverse proxy + TLS | Ya |
| `deploy/.env.production.example` | dokumentasi env produksi | Ya |
| `deploy/backup.sh`, `deploy/restore.sh` | backup & restore | Ya |
| `sales-app/backend/app/models/database.py` | komentar Supabase diganti; pool bisa dinaikkan; `prepare_threshold` boleh tetap | Tidak wajib |
| `sales-app/backend/.env.example` | ganti contoh Supabase → PostgreSQL lokal | Ya (dokumentasi) |
| `README.md` | bagian deployment | Ya |
| Storage provider | tetap Supabase Storage dulu (0 object), atau pindah ke S3/R2 | Tidak wajib |
| Rate limit login | tambahan keamanan | Disarankan |

Catatan penting: **jangan ubah `SECRET_KEY`** saat migrasi kalau tidak ingin semua user
logout. Salin nilai yang sekarang dari Railway.

---

## 8. Checklist cutover (ringkas)

**Sebelum hari-H**

- [ ] Backup Supabase sudah diuji restore.
- [ ] VPS sudah bisa diakses, Docker siap, DNS TTL 300 detik.
- [ ] Stack VPS sudah jalan dan lolos smoke test dengan data hasil restore.
- [ ] Aplikasi web/mobile baru sudah dibuild dan siap didistribusikan.
- [ ] Kontak admin VPS & akses panel tersedia.
- [ ] Rencana rollback sudah dibaca.

**Saat cutover**

- [ ] Stop Railway (tidak ada write baru).
- [ ] Dump final Supabase.
- [ ] Restore ke VPS.
- [ ] Start backend VPS, cek `/health`.
- [ ] Smoke test login + order.
- [ ] Ganti DNS ke VPS.
- [ ] Cek dari jaringan luar (bukan dari server).
- [ ] Deploy web baru, distribusikan mobile baru.
- [ ] Pantau log 1–2 jam.

**Setelah cutover**

- [ ] Bandingkan jumlah baris & data terbaru.
- [ ] Pastikan scheduler berjalan (log job expire/reset bulletin).
- [ ] Pastikan tidak ada error CORS di browser.
- [ ] Pastikan backup harian pertama berhasil.
- [ ] Monitoring mengirim alert saat server dimatikan (uji).

---

## 9. Rollback

Karena Supabase dan Railway belum dihapus:

1. Kalau cutover gagal sebelum ada write baru di VPS: kembalikan DNS ke Railway,
   start Railway lagi. Data masih utuh di Supabase.
2. Kalau sudah ada write di VPS dan harus rollback: dump database VPS, restore ke
   Supabase, arahkan `DATABASE_URL` Railway kembali ke Supabase, lalu kembalikan DNS.
   Ini membutuhkan downtime tambahan; lakukan hanya kalau benar-benar perlu.
3. Simpan dump sebelum cutover dan dump setelah rollback di tempat aman.
4. Jangan hapus Supabase/Railway sampai masa observasi selesai.

---

## 10. Risiko & mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Aplikasi mobile lama masih menunjuk `sales-app-production-1872.up.railway.app` | Pengguna lama tidak bisa order setelah Railway dimatikan | Update semua perangkat sebelum shutdown, **atau** jalankan Railway sementara sebagai reverse proxy ke VPS selama transisi |
| `pg_dump` lewat pooler 6543 gagal | Dump tidak jadi | Pakai koneksi langsung/session pooler port 5432 |
| `SECRET_KEY` berubah | Semua user logout | Salin nilai lama, rotasi terpisah |
| Scheduler jalan ganda | Job expire/reset bulletin dobel | 1 worker, atau pisahkan container scheduler |
| VPS mati = backend + DB mati | Downtime total | Backup offsite + monitoring + snapshot; jika butuh HA, baru pertimbangkan managed DB |
| Backup tidak pernah diuji | Backup rusak saat dibutuhkan | Restore drill bulanan |
| Bandwidth "unmetered" ternyata fair use | Biaya membengkak | Konfirmasi tertulis ke provider sebelum bayar; monitor pemakaian |
| Postgres terbuka ke publik | Risiko keamanan | Jangan publish port 5432; UFW; cek dari luar |
| Import Excel besar kehabisan RAM | Proses gagal | 4 GB RAM + swap; batasi ukuran upload; monitor |
| Tidak ada rate limit login | Brute force | Tambahkan rate limit di reverse proxy/CrowdSec |
| Domain/DNS salah arah | API tidak bisa diakses | TTL rendah, uji `curl` dari luar, siapkan rollback DNS |

---

## 11. Estimasi waktu

| Tahap | Waktu aktif |
|---|---|
| Fase 0 — persiapan & backup | ±1 jam |
| Fase 1 — provision & hardening | ±1 jam |
| Fase 2 — stack produksi | ±2 jam |
| Fase 3 — migrasi & verifikasi | ±1 jam |
| Fase 4 — cutover & frontend | ±1 jam + propagasi DNS |
| Fase 5 — backup & monitoring | ±2 jam |
| **Total** | **±8 jam aktif**, bisa dipecah 2–3 hari |

Downtime saat cutover diperkirakan **15–30 menit** karena database hanya 31 MB.

---

## 12. Langkah pertama setelah rencana ini disetujui

1. 7 keputusan sudah dikonfirmasi di bagian 5. Domain diputuskan **beli `.my.id`
   sekarang**; sisa satu: nama domainnya.
2. File deployment sudah dibuat di `deploy/` (lihat `deploy/README.md`). Update
   `baseUrl` di tiga `config.dart` menunggu nama domain final.
3. Kamu beli domain `.my.id` + order VPS, lalu kirim nama domain dan akses SSH
   (atau jalankan Fase 1 sendiri dengan panduan).
4. Kita lakukan Fase 0–3 di VPS percobaan (staging boleh pakai alamat gratis),
   baru cutover di Fase 4 pada malam hari.
