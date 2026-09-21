# Sales App — Project Magang

Aplikasi sales internal: mobile app (sales), admin web panel, dan backend API.

> Lihat [`PRD.md`](PRD.md) dan [`PRD-rev.md`](PRD-rev.md) untuk requirements lengkap.

## Struktur Repo

```
.
├── PRD.md / PRD-rev.md          # Dokumen requirements
└── sales-app/
    ├── lib/                     # Flutter mobile (sales)
    ├── android/  ios/           # Platform build files
    ├── admin_web/               # Flutter web (admin panel)
    │   └── lib/
    └── backend/                 # Python API backend
        ├── app/
        ├── requirements.txt
        └── .env                 # ⚠️ tidak di-push (lihat .gitignore)
```

## Komponen

| Komponen    | Stack        | Lokasi                          |
|-------------|--------------|---------------------------------|
| Mobile      | Flutter      | `sales-app/`                    |
| Admin Web   | Flutter Web  | `sales-app/admin_web/`          |
| Backend API | Python       | `sales-app/backend/`            |

## Quick Start (dev lokal)

### 1. Backend (Python)
```bash
cd sales-app/backend
python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env              # isi credentials (JANGAN commit .env)
python -m app                     # atau sesuaikan entrypoint
```

### 2. Admin Web (Flutter)
```bash
cd sales-app/admin_web
flutter pub get
flutter run -d chrome
```

### 3. Mobile (Flutter)
```bash
cd sales-app
flutter pub get
flutter run                       # pilih device Android/iOS
```

## Secrets & Credentials

⚠️ **Jangan pernah commit:**
- `sales-app/credentials.json` — service account key
- `sales-app/backend/.env` — environment variables
- File `*.pem`, `*.key`, `*.service-account.json`

Semua sudah masuk `.gitignore`. Kalau pernah terlanjur ke-push, **rotate credentials segera** dan hapus dari history Git (lihat `git filter-repo` / BFG).

## Catatan

- `pubspec.lock` **di-commit** agar build reproducible antar mesin.
- Folder `build/`, `.dart_tool/`, `venv/`, `__pycache__/` di-ignore.
