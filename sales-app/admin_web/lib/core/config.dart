class AppConfig {
  // Base URL backend. Untuk switch local ↔ production, comment/uncomment
  // salah satu baris baseUrl di bawah. Yang tidak dipakai tetap disimpan
  // sebagai komentar supaya tidak perlu mengingat URL-nya saat switch.

  // [ACTIVE — PRODUCTION] Deploy di Railway
  static const String baseUrl = 'https://practical-beauty-production-071a.up.railway.app/api/v1';

  // [LOCAL DEV] Backend jalan lokal — comment baris di atas, uncomment ini
  // static const String baseUrl = 'http://localhost:8000/api/v1';
}
