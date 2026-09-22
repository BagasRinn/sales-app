class AppConfig {
  // IMPORTANT: Change this to your laptop's LAN IP when the admin web is accessed
  // from another device on the same network.
  // To find your IP: run `ipconfig` in cmd and look for "IPv4 Address".
  // For local development on the same machine
  static const String baseUrl = 'http://localhost:8000/api/v1';
}
