import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/data/models/supplier.dart';
import 'package:admin_web/data/repositories/api_service.dart';
import 'package:admin_web/data/repositories/admin_repository.dart';
import 'package:admin_web/presentation/providers/admin_provider.dart';

class _FakeAdminRepository extends AdminRepository {
  _FakeAdminRepository() : super(ApiService());

  List<Supplier> suppliers = [];
  Exception? failWith;

  @override
  Future<List<Supplier>> getSuppliers({bool? active}) async {
    if (failWith != null) throw failWith!;
    return suppliers;
  }

  @override
  Future<Supplier> createSupplier(String name, {String orderType = 'REGULER'}) async {
    final s = Supplier(name: name, isActive: true, orderType: orderType);
    suppliers.add(s);
    return s;
  }

  @override
  Future<Supplier> updateSupplierActive(String name, bool isActive) async {
    final idx = suppliers.indexWhere((s) => s.name == name);
    if (idx < 0) throw Exception('not found');
    final updated = Supplier(
      name: suppliers[idx].name,
      isActive: isActive,
      productCount: suppliers[idx].productCount,
    );
    suppliers[idx] = updated;
    return updated;
  }
}

void main() {
  test('loadSuppliers populates the list', () async {
    final repo = _FakeAdminRepository();
    repo.suppliers = [
      const Supplier(name: 'A', isActive: true, productCount: 3),
      const Supplier(name: 'B', isActive: false, productCount: 0),
    ];
    final p = AdminProvider(repo);
    await p.loadSuppliers();
    expect(p.suppliers.length, 2);
    expect(p.suppliersLoading, isFalse);
  });

  test('createSupplier adds a row and refreshes', () async {
    final repo = _FakeAdminRepository();
    final p = AdminProvider(repo);
    await p.createSupplier('Test');
    expect(repo.suppliers.length, 1);
    expect(repo.suppliers.first.name, 'Test');
  });

  test('toggleSupplierActive flips isActive and refreshes', () async {
    final repo = _FakeAdminRepository();
    repo.suppliers = [const Supplier(name: 'A', isActive: true, productCount: 0)];
    final p = AdminProvider(repo);
    await p.loadSuppliers();
    await p.toggleSupplierActive(p.suppliers.first);
    expect(repo.suppliers.first.isActive, isFalse);
  });
}
