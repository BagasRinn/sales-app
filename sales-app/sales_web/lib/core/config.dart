class AppConfig {
  /// Base URL API. Default ke server produksi, tapi bisa dioverride tanpa
  /// mengubah kode lewat --dart-define, contoh:
  ///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sales-app-production-1872.up.railway.app/api/v1',
  );
  static const Duration requestTimeout = Duration(seconds: 30);

  static const String tokenKey = 'access_token';
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userRoleKey = 'user_role';
  static const String userIdKey = 'user_id';
  static const String userUsernameKey = 'user_username';
  static const String userNamaKey = 'user_nama';
  static const String userBranchKey = 'user_branch';
  static const String userBranchNamaKey = 'user_branch_nama';
}
