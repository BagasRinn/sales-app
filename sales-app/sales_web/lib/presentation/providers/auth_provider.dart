import 'package:flutter/foundation.dart';
import '../../core/api_exception.dart';
import '../../core/api_service.dart';
import '../../data/repositories/auth_repository.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepo;
  final ApiService _api;

  AuthState _state = AuthState.initial;
  String? _username;
  String? _nama;
  String? _errorMessage;

  AuthProvider({
    required this._authRepo,
    required this._api,
  }) {
    _api.onTokenExpired = _onTokenExpired;
  }

  AuthState get state => _state;
  String? get username => _username;
  String? get nama => _nama;
  String? get branch => _authRepo.branch;
  String? get branchNama => _authRepo.branchNama;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;

  void _onTokenExpired() {
    forceLogout('Sesi login berakhir. Silakan masuk kembali.');
  }

  Future<void> checkLoginStatus() async {
    _state = AuthState.loading;
    notifyListeners();

    final restored = await _authRepo.tryRestoreSession();
    if (restored) {
      _username = _authRepo.username;
      _nama = _authRepo.nama;
      _state = AuthState.authenticated;
    } else {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepo.login(username, password);
      _username = username;
      _nama = _authRepo.nama;
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _state = AuthState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan koneksi. Silakan coba lagi.';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepo.logout();
    _username = null;
    _nama = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  void forceLogout([String? message]) {
    _authRepo.logoutSync();
    _errorMessage = message ?? 'Sesi login berakhir.';
    _username = null;
    _nama = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      await _authRepo.changePassword(currentPassword, newPassword);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Gagal mengubah password.';
      notifyListeners();
      return false;
    }
  }
}
