class AppConfig {
  // Base URL backend. Untuk switch local ↔ production, comment/uncomment
  // salah satu baris baseUrl di bawah. Yang tidak dipakai tetap disimpan
  // sebagai komentar supaya tidak perlu mengingat URL-nya saat switch.

  // [ACTIVE — LOCAL DEV] Backend jalan lokal, diakses dari Chrome di mesin yang sama
  static const String baseUrl = 'http://localhost:8000/api/v1';

  // [PRODUCTION] Deploy di Railway — uncomment & comment baris di atas untuk balik ke deploy
  // static const String baseUrl = 'https://practical-beauty-production-071a.up.railway.app/api/v1';
}
