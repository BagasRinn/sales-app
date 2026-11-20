import 'package:admin_web/core/design_system.dart';
import 'package:admin_web/data/models/sales_attendance.dart';
import 'package:admin_web/data/repositories/admin_repository.dart';
import 'package:admin_web/data/repositories/api_service.dart';
import 'package:admin_web/presentation/providers/admin_provider.dart';
import 'package:admin_web/presentation/screens/attendance_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

class _FakeRepo extends AdminRepository {
  _FakeRepo() : super(ApiService());

  List<SalesAttendance> data = [];
  DateTime? lastDate;

  @override
  Future<List<SalesAttendance>> getSalesAttendances({
    DateTime? date,
    String? salesId,
    bool? isRegisteredSales,
    String? outletChannel,
    int limit = 500,
    int offset = 0,
  }) async {
    lastDate = date;
    return data;
  }
}

SalesAttendance _row({
  required String id,
  required String name,
  required String phone,
  required String outlet,
  bool registered = true,
  bool photo = true,
}) {
  return SalesAttendance(
    id: id,
    salesId: registered ? 'sales-$id' : null,
    salesName: name,
    senderPhone: phone,
    isRegisteredSales: registered,
    outletCode: outlet,
    outletName: 'Toko $outlet',
    outletChannel: 'GT',
    hasPhotoProof: photo,
    visitedAt: DateTime.utc(2026, 1, 2, 3, 4),
  );
}

Widget _harness(AdminProvider p) => MaterialApp(
  home: ChangeNotifierProvider<AdminProvider>.value(
    value: p,
    child: const Scaffold(body: AttendanceTab()),
  ),
);

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('renders summary and attendance rows', (tester) async {
    _setMobile(tester);
    final repo = _FakeRepo()
      ..data = [
        _row(id: '1', name: 'Budi', phone: '6281200001234', outlet: 'A'),
        _row(
          id: '2',
          name: 'Pak Sup',
          phone: '6281299998888',
          outlet: 'B',
          registered: false,
          photo: false,
        ),
      ];
    await tester.pumpWidget(_harness(AdminProvider(repo)));
    await tester.pumpAndSettle();

    expect(find.text('Absensi Kunjungan'), findsOneWidget);
    expect(find.text('Total Kunjungan'), findsOneWidget);
    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('Pak Sup'), findsOneWidget);
    expect(find.textContaining('Toko A'), findsOneWidget);
    expect(repo.lastDate, isNotNull);
  });

  testWidgets('search filters rows client-side', (tester) async {
    _setMobile(tester);
    final repo = _FakeRepo()
      ..data = [
        _row(id: '1', name: 'Budi', phone: '6281200001234', outlet: 'A'),
        _row(id: '2', name: 'Sari', phone: '6281277776666', outlet: 'B'),
      ];
    await tester.pumpWidget(_harness(AdminProvider(repo)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'toko b');
    await tester.pumpAndSettle();

    expect(find.text('Budi'), findsNothing);
    expect(find.text('Sari'), findsOneWidget);
  });

  testWidgets('registered status chip filters rows', (tester) async {
    _setMobile(tester);
    final repo = _FakeRepo()
      ..data = [
        _row(id: '1', name: 'Budi', phone: '6281200001234', outlet: 'A'),
        _row(
          id: '2',
          name: 'Pak Sup',
          phone: '6281299998888',
          outlet: 'B',
          registered: false,
        ),
      ];
    await tester.pumpWidget(_harness(AdminProvider(repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppChoiceChip, 'Tidak terdaftar'));
    await tester.pumpAndSettle();

    expect(find.text('Budi'), findsNothing);
    expect(find.text('Pak Sup'), findsOneWidget);
  });

  testWidgets('empty state when there is no attendance', (tester) async {
    _setMobile(tester);
    final repo = _FakeRepo();
    await tester.pumpWidget(_harness(AdminProvider(repo)));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada absensi'), findsOneWidget);
  });

  testWidgets('date change refetches with the new date', (tester) async {
    _setMobile(tester);
    final repo = _FakeRepo();
    final provider = AdminProvider(repo);
    await tester.pumpWidget(_harness(provider));
    await tester.pumpAndSettle();

    await provider.setAttendanceDate(DateTime(2026, 1, 5));
    await tester.pumpAndSettle();

    expect(repo.lastDate, DateTime(2026, 1, 5));
  });
}
