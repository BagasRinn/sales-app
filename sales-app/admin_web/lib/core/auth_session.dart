/// Sesi login admin web — in-memory, tanpa storage browser.
///
/// Keamanan: access token + identitas user TIDAK pernah disimpan di
/// localStorage (plugin secure_storage di web jatuh ke localStorage, yang
/// bisa dibaca JavaScript apa pun saat XSS). Refresh token kini hidup di
/// cookie httpOnly milik server — JS tidak pernah melihatnya. Setelah
/// reload tab, sesi dipulihkan lewat POST /auth/refresh (cookie terkirim
/// otomatis oleh browser), lihat `ApiService.refreshSession()`.
class AuthSession {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  String? accessToken;
  String username = 'admin';
  String nama = '';
  String role = 'ADMIN';
  String? branch;
  String? branchNama;

  bool get hasSession => accessToken != null && accessToken!.isNotEmpty;

  /// Isi sesi dari response `/auth/login` atau `/auth/refresh`.
  ///
  /// Keduanya mengembalikan identitas lengkap (username/nama/role/branch),
  /// jadi UI tidak butuh penyimpanan identitas terpisah.
  void applyLogin(
    Map<String, dynamic> data, {
    String? fallbackUsername,
  }) {
    accessToken = data['access_token']?.toString();
    username = (data['username']?.toString().isNotEmpty ?? false)
        ? data['username'].toString()
        : (fallbackUsername ?? username);
    nama = data['nama']?.toString() ?? '';
    role = data['role']?.toString() ?? role;
    branch = data['branch']?.toString();
    branchNama = data['branch_nama']?.toString();
  }

  void clear() {
    accessToken = null;
    username = 'admin';
    nama = '';
    role = 'ADMIN';
    branch = null;
    branchNama = null;
  }
}
