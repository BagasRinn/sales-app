class AppConfig {
  // Base URL untuk backend API. Pilih sesuai target runtime.
  // Untuk switch local ↔ production, comment/uncomment baris baseUrl di bawah.
  // URL yang tidak dipakai tetap disimpan sebagai komentar untuk referensi.
  //
  //   Chrome (web) di mesin yang sama dengan backend → http://localhost:8000/api/v1
  //
  //   Android Emulator (AVD) → http://10.0.2.2:8000/api/v1
  //     (10.0.2.2 adalah alias emulator ke host laptop)
  //
  //   Physical Android/iOS device di WiFi sama → http://<PC-IP-LAN>:8000/api/v1
  //     (cek dengan `ipconfig` → IPv4 Address, mis. 192.168.x.x)

  // [ACTIVE — LOCAL DEV] Default Android Emulator. Ganti sesuai skenario di atas
  // kalau target runtimenya berbeda.
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

  // [PRODUCTION] Deploy di Railway — uncomment & comment baris di atas untuk balik ke deploy
  // static const String baseUrl = 'https://practical-beauty-production-071a.up.railway.app/api/v1';

  static const Duration requestTimeout = Duration(seconds: 30);

  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userRoleKey = 'user_role';
  static const String userIdKey = 'user_id';
}
