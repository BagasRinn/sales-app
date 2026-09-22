class AppConfig {
  // IMPORTANT: Use the correct address for your device type:
  //
  //   Android Emulator → http://10.0.2.2:8000/api/v1
  //     (10.0.2.2 is the emulator's alias for your laptop's localhost)
  //
  //   Physical Android Device → http://YOUR_PC_IP:8000/api/v1
  //     (find your PC IP with: ipconfig → look for "IPv4 Address", e.g. 192.168.x.x)
  //     Make sure your phone is on the SAME WiFi as your PC.
  //
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

  static const Duration requestTimeout = Duration(seconds: 30);

  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userRoleKey = 'user_role';
  static const String userIdKey = 'user_id';
}
