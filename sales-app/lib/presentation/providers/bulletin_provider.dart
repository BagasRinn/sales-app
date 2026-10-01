import 'package:flutter/foundation.dart';
import '../../data/repositories/bulletin_repository.dart';
import '../../data/models/bulletin.dart';

class BulletinProvider extends ChangeNotifier {
  final BulletinRepository _repo;

  List<Bulletin> _bulletins = [];
  bool _loading = false;
  String? _error;

  BulletinProvider(this._repo);

  List<Bulletin> get bulletins => _bulletins;
  bool get loading => _loading;
  String? get error => _error;

  /// Bulletins belum di-dismiss (isRead == false)
  List<Bulletin> get unreadBulletins =>
      _bulletins.where((b) => !b.isRead).toList();

  bool get hasUnread => unreadBulletins.isNotEmpty;
  Bulletin? get latestUnread =>
      unreadBulletins.isNotEmpty ? unreadBulletins.first : null;

  Future<void> loadBulletins() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _bulletins = await _repo.getBulletins();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> dismissBulletin(String bulletinId) async {
    await _repo.dismissBulletin(bulletinId);
    final idx = _bulletins.indexWhere((b) => b.id == bulletinId);
    if (idx >= 0) {
      // Replace with read version
      final old = _bulletins[idx];
      _bulletins[idx] = Bulletin(
        id: old.id,
        title: old.title,
        description: old.description,
        pdfUrl: old.pdfUrl,
        expireAt: old.expireAt,
        createdAt: old.createdAt,
        isRead: true,
      );
      notifyListeners();
    }
  }
}
