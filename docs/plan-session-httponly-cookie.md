# Plan: Session Login admin_web dengan httpOnly Cookie

> Status: **Fase 1 (backend) dan Fase 2 (frontend) selesai** — Fase 3 dan 4 belum dimulai.
> Dibuat: 2026-11-25

## 1. Masalah saat ini

| Komponen | Implementasi sekarang | Masalah |
|---|---|---|
| Backend (`app/api/endpoints/auth.py`, `app/core/security.py`) | JWT access 30 menit + refresh 7 hari, dikirim via **body JSON** (`/auth/login`, `/auth/refresh`) | Refresh token terekspos ke JavaScript |
| admin_web (`lib/core/auth_storage.dart`) | `flutter_secure_storage` | Di Flutter Web plugin ini **jatuh ke `localStorage`** → XSS bisa baca & curi refresh token berumur 7 hari |
| `lib/core/auth_interceptor.dart` | 401 → redirect logout saja | Tidak ada silent refresh; user dipaksa login ulang setiap access token habis |
| Deploy (`deploy/Caddyfile`) | Caddy → API di subdomain; `CORS_ORIGINS` terpisah; `allow_credentials=True` sudah aktif | CORS cookie sudah siap, tinggal strategi `SameSite` |

## 2. Pola yang dipilih: refresh token di cookie httpOnly, access token di memori

```
Login ──► server set cookie httpOnly (refresh token, 7 hari, path=/api/v1/auth)
        └─► access token dikirim di response → disimpan di MEMORI saja (variabel Dart)

Reload page ──► app boot ──► POST /auth/refresh (cookie terkirim otomatis)
                           └─► access token baru → langsung dashboard, tanpa login

Tiap 5 menit ──► cek sisa umur token; bila ≤ 6 menit ──► silent refresh
                 (access 30 menit tidak pernah habis)
```

Alasan memilih pola ini (bukan semua token di cookie):

- Refresh token (aset paling berharga, umur 7 hari) **tidak pernah bisa dibaca JavaScript** karena httpOnly.
- Access token umur pendek (≤30 menit); tidak disimpan di storage mana pun sehingga tidak bisa dieksfiltrasi.
- Endpoint bisnis tetap memakai `Authorization: Bearer <access>` → **mobile app (sales app) tidak berubah sama sekali** karena backend dual-mode.

## 3. UX: tidak login ulang terus-terusan

1. **Silent refresh saat boot** — reload / tutup-buka tab tetap masuk.
2. **Sliding session** — setiap refresh sukses, cookie 7 hari di-renew → user rutin tidak pernah logout.
3. **Absolute cap** (opsional, Fase 4) — misal 30 hari sejak login asli, wajib re-login.
4. "Ingat saya" (opsional, Fase 4) — 7 hari vs session cookie.

## 4. Keputusan desain: `SameSite`

- **Skenario A — satu domain induk** (`app.domain.com` + `api.domain.com`): `SameSite=Lax` → CSRF praktis beres. Rekomendasi jangka panjang.
- **Skenario B — domain induk berbeda** (kondisi deploy sekarang): wajib `SameSite=None; Secure` + **validasi header `Origin`**. Cookie domain API tidak bisa dibaca JS di origin admin web (Firebase Hosting), jadi double-submit cookie tidak andal; `Origin` dikirim browser dan tidak bisa dipalsukan JS, lalu dicocokkan dengan `CORS_ORIGINS` (atau host API untuk deploy same-origin).
  - Catatan: browser yang memblokir third-party cookie (Safari/Firefox) dapat menolak cookie lintas-site ini. Untuk jaminan penuh di semua browser, jangka panjang pindahkan admin web ke subdomain domain yang sama dengan API (Skenario A) — mis. `admin.domain.com` + `api.domain.com`.

Konfigurasi via env: `COOKIE_SAMESITE` (default `none` saat production, `lax` saat dev), `COOKIE_SECURE` (default ikut `ENVIRONMENT`), `COOKIE_DOMAIN` (default host-only).

## 5. Perubahan backend (dual-mode)

1. `POST /auth/login` — body boleh membawa `client: "web"`. Untuk client web, server set cookie `admin_rt` (refresh JWT, `HttpOnly`) dan menolak peran selain ADMIN/SUPERVISOR/MANAGER; `refresh_token` **tidak** ikut di response body. Client lain (mobile) tidak menerima cookie dan tetap mendapat `refresh_token` di body. Origin request browser divalidasi.
2. `POST /auth/refresh` — baca token **dari cookie** dulu (wajib `Origin` sah), fallback ke body untuk mobile. **Rotasi**: selalu keluarkan refresh token baru + set cookie baru. Jika sumber cookie → refresh token baru TIDAK dikirim di body.
3. `POST /auth/logout` *(baru)* — hapus cookie sesi (origin divalidasi bila cookie ada).
4. `GET /auth/me` *(baru)* — identitas user (`username/nama/role/branch/branch_nama`) agar UI tidak menyimpan apa pun di storage.
5. `token_version` tetap berlaku: ganti password = semua sesi mati instan.

## 6. Perubahan admin_web (frontend)

1. Dio web adapter: `withCredentials = true` (cookie ikut setiap request ke API).
2. `AuthStorage` diganti penyimpanan **in-memory** (web-only) — tidak ada lagi localStorage.
3. Boot: coba silent refresh dulu → sukses = Dashboard, gagal = LoginScreen.
4. `AuthInterceptor`: 401 → coba refresh **sekali** (single-flight, antrikan + replay request yang gagal) → baru logout bila refresh juga 401.
5. Timer silent refresh tiap 5 menit; refresh dijalankan bila sisa umur access token ≤ 6 menit (sliding session).
6. Identitas user diambil dari response login / `GET /auth/me`.

## 7. Hardening keamanan

- **Fase 1 (rotasi dasar)**: refresh token baru setiap refresh — memperpendek window penyalahgunaan token bocor.
- **Fase 3**: tabel `sessions` (`user_id, token_hash, user_agent, expires_at, revoked`) → **reuse detection** (token lama dipakai lagi = pencurian → revoke seluruh sesi) + halaman "Perangkat aktif" untuk MANAGER.
- CSP header di Caddyfile (Fase 4) — XSS tetap risiko: httpOnly mencegah *pencurian token*, bukan eksekusi script; CSP mempersempit dampak.
- Cookie flags lengkap: `HttpOnly; Secure; SameSite=<env>; Path=/api/v1/auth; Max-Age=...`.

## 8. Fase implementasi

| Fase | Isi | Status |
|---|---|---|
| **1** | Backend: cookie dual-mode (`login`/`refresh`), `/logout`, `/me`, rotasi dasar, validasi `Origin` | ✅ |
| **2** | Frontend: `withCredentials`, token in-memory, boot refresh, refresh-on-401, timer refresh 5 menit | ✅ |
| **3** | Tabel `sessions` + reuse detection + halaman sesi aktif | belum |
| **4** | Audit CSRF lanjutan, CSP, absolute cap, "ingat saya" | belum |

## 9. Catatan migrasi

- Setelah deploy Fase 1+2: user yang sedang login diminta **login sekali** (sesi lama tidak punya cookie). Setelah itu tidak lagi.
- Mobile app tidak menyentuh perubahan apa pun (endpoint body-based tetap jalan).
- Tidak ada perubahan infra Caddy di Fase 1–2.

## 10. Env vars baru

| Var | Default | Keterangan |
|---|---|---|
| `COOKIE_SAMESITE` | `none` (prod) / `lax` (dev) | `lax`, `strict`, atau `none` |
| `COOKIE_SECURE` | ikut `ENVIRONMENT` | paksa `Secure` flag |
| `COOKIE_DOMAIN` | (kosong = host-only) | set bila cookie harus lintas subdomain |
| `COOKIE_PATH` | `/api/v1/auth` | scope cookie |
