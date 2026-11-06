class AppConfig {
  /// Base URL API. Default ke server produksi, tapi bisa dioverride tanpa
  /// mengubah kode lewat --dart-define, contoh:
  ///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sales-app-production-1872.up.railway.app/api/v1',
  );

  /// Menu & halaman "Data Penjualan" (import laporan penjualan) disembunyikan
  /// sementara. Implementasinya TIDAK dihapus — cukup ubah flag ini menjadi
  /// `true` untuk memunculkannya kembali.
  ///
  /// Alasan: fitur ini masih dalam tahap penyempurnaan dan belum perlu
  /// ditampilkan ke pengguna Admin Web saat ini.
  static const bool enableImportedSales = false;
}
