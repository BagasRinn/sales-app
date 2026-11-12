class AppConfig {
  /// Base URL API. Default ke server produksi, tapi bisa dioverride tanpa
  /// mengubah kode lewat --dart-define, contoh:
  ///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.madsalesapp.my.id/api/v1',
  );

  /// Menu & halaman "Data Penjualan" (import laporan penjualan).
  ///
  /// Flag ini dinyalakan untuk tahap pengujian/revisi fitur. Set kembali ke
  /// `false` kalau menu perlu disembunyikan lagi dari pengguna Admin Web.
  static const bool enableImportedSales = true;
}
