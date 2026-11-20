# WA Attendance Worker

Worker Node.js (Baileys) yang memantau grup WhatsApp dan meneruskan pesan
absensi kunjungan sales ke backend FastAPI.

## Format pesan

Pesan teks atau caption foto harus berisi tepat 3 segmen dipisahkan `#`:

```
KODE OUTLET#NAMA OUTLET#CHANNEL OUTLET
```

Contoh: `OUT-042#Toko Berkah Jaya#GT`. Pesan lain di grup diabaikan.

## Menjalankan lokal

```bash
cp .env.example .env
# isi FASTAPI_URL dan INTERNAL_API_KEY
npm install
npm start
```

Scan QR yang muncul di terminal (WhatsApp → Perangkat Tertaut). Sesi tersimpan
di `AUTH_DIR` sehingga restart tidak perlu scan ulang.

## Test

```bash
npm test
```

## Docker

```bash
docker build -t wa-worker .
docker run --rm -it \
  --env-file .env \
  -v "$PWD/auth_info_baileys:/app/auth_info_baileys" \
  wa-worker
```

Di stack produksi, service `wa-worker` sudah didefinisikan pada
`deploy/compose.prod.yaml` dengan volume `wa_auth`.
