class AppConfig {
  /// Base URL API. Default ke server produksi, tapi bisa dioverride tanpa
  /// mengubah kode lewat --dart-define, contoh:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
  /// (10.0.2.2 = localhost mesin host dari Android emulator)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.madsalesapp.my.id/api/v1',
  );

  static const Duration requestTimeout = Duration(seconds: 30);

  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userRoleKey = 'user_role';
  static const String userIdKey = 'user_id';
  static const String userUsernameKey = 'user_username';
  static const String userNamaKey = 'user_nama';
}
