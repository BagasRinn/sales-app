import 'package:flutter/foundation.dart';
import '../../core/api_exception.dart';
import '../../../data/models/bulletin.dart';
import '../../data/repositories/bulletin_repository.dart';

class BulletinProvider with ChangeNotifier {
  final BulletinRepository _repo;

  List<Bulletin> _bulletins = [];
  bool _isLoading = false;
  String? _error;

  BulletinProvider(this._repo);

  List<Bulletin> get bulletins => _bulletins;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _bulletins.where((b) => !b.isRead).length;

  Future<void> loadBulletins({bool includeRead = true}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _bulletins = await _repo.getBulletins(includeRead: includeRead);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Gagal memuat promo.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String bulletinId) async {
    try {
      await _repo.markAsRead(bulletinId);
      final idx = _bulletins.indexWhere((b) => b.id == bulletinId);
      if (idx != -1) {
        _bulletins[idx] = Bulletin(
          id: _bulletins[idx].id,
          title: _bulletins[idx].title,
          description: _bulletins[idx].description,
          pdfUrl: _bulletins[idx].pdfUrl,
          expireAt: _bulletins[idx].expireAt,
          createdAt: _bulletins[idx].createdAt,
          isRead: true,
        );
        notifyListeners();
      }
    } catch (_) {}
  }
}
