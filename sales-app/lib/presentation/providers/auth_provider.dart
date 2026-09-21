import 'package:flutter/foundation.dart';
import '../../data/repositories/auth_repository.dart';
import '../../core/api_exception.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepo;

  AuthState _state = AuthState.initial;
  String? _errorMessage;

  AuthProvider(this._authRepo);

  AuthState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;

  Future<String?> getToken() => _authRepo.getToken();

  Future<void> checkLoginStatus() async {
    try {
      final isLoggedIn = await _authRepo.isLoggedIn();
      _state = isLoggedIn ? AuthState.authenticated : AuthState.unauthenticated;
    } catch (e) {
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
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _state = AuthState.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = 'Koneksi gagal. Pastikan server berjalan.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepo.logout();
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  /// Force logout without API call — used when token expires or 401 received.
  void forceLogout([String? message]) {
    _authRepo.logoutSync();
    _state = AuthState.unauthenticated;
    _errorMessage = message;
    notifyListeners();
  }
}
