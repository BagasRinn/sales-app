import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_session.dart';
import '../../core/branch.dart';
import '../../core/datetime_utils.dart';
import '../../core/design_system.dart';
import '../../core/jwt_utils.dart';
import '../../core/session_navigation.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/api_service.dart';
import '../providers/admin_provider.dart';
import 'orders_tab.dart';
import 'products_tab.dart';
import 'sync_tab.dart';
import 'stats_tab.dart';
import 'customer_submissions_tab.dart';
import 'customers_tab.dart';
import 'users_tab.dart';
import 'performance_tab.dart';
import 'penugasan_sales_tab.dart';
import 'bulletins_tab.dart';
import 'change_password_dialog.dart';
import 'cross_branch_reports_tab.dart';
import 'attendance_tab.dart';
import 'wa_qr_scanner_page.dart';
import 'suppliers_tab.dart';
import 'imported_sales_tab.dart';
import 'supplier_performance_pivot_tab.dart';
import 'inventory_tracker_tab.dart';
import 'user_presence_tab.dart';
import '../../core/config.dart';

/// Identitas halaman di dashboard Admin Web. Dipakai agar pemilihan halaman
/// tidak bergantung pada index numerik yang mudah bergeser saat menu
/// ditambah/disembunyikan.
enum _DashboardPage {
  dashboard,
  orders,
  customers,
  customerSubmissions,
  products,
  suppliers,
  sync,
  users,
  performance,
  supplierPerformance,
  inventoryTracker,
  inventoryTrackerSku,
  userPresence,
  penugasan,
  bulletins,
  importedSales,
  crossBranch,
  attendance,
  waSession,
}

class _NavSpec {
  final _DashboardPage page;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String group;

  const _NavSpec({
    required this.page,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.group,
  });
}

class DashboardScreen extends StatefulWidget {
  final String accessToken;
  final String username;
  final String nama;
  final String role;
  final String? branch;
  final String? branchNama;

  const DashboardScreen({
    super.key,
    required this.accessToken,
    required this.username,
    required this.nama,
    required this.role,
    this.branch,
    this.branchNama,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ApiService _apiService;
  late final AdminRepository _repo;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    // Access token dari sesi in-memory (hasil login / boot refresh). Header
    // Authorization dipasang AuthInterceptor per-request, jadi setelah silent
    // refresh semua request otomatis memakai token terbaru.
    _apiService.setTokens(access: widget.accessToken);
    _repo = AdminRepository(_apiService);
    _repo.setTokens(widget.accessToken);
    // Tidak ada yang perlu dipersist: refresh token ada di cookie httpOnly
    // server, access token + identitas cukup hidup di AuthSession (memori).
  }

  @override
  void dispose() {
    _repo.clearTokens();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminProvider(_repo),
      child: _DashboardContent(
        username: widget.username,
        nama: widget.nama,
        role: widget.role,
        branch: widget.branch,
        branchNama: widget.branchNama,
        apiService: _apiService,
      ),
    );
  }
}

class _DashboardContent extends StatefulWidget {
  final String username;
  final String nama;
  final String role;
  final String? branch;
  final String? branchNama;
  final ApiService apiService;

  const _DashboardContent({
    required this.username,
    required this.nama,
    required this.role,
    this.branch,
    this.branchNama,
    required this.apiService,
  });

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  int _ordersInitialTabIndex = 0;
  late final AdminProvider _adminProvider;
  late final ApiService _apiService;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Tidak ada idle auto-logout: dashboard boleh ditinggal berapa lama pun,
  // tab tetap terbuka. Kepertahanan sesi diurus cookie httpOnly 24 jam
  // sliding di server — hanya >24 jam tanpa aktivitas login yang memaksa
  // login ulang, dan tombol Logout yang benar-benar mengakhiri sesi.

  // Silent refresh: access token berumur 30 menit. Cek tiap 5 menit dan
  // refresh saat sisa umur < 6 menit, sehingga tidak ada request yang sempat
  // gagal 401 dan sesi user aktif tidak pernah terputus.
  static const Duration _refreshCheckInterval = Duration(minutes: 5);
  static const Duration _refreshBeforeExpiry = Duration(minutes: 6);

  Timer? _refreshTimer;

  bool get _isGlobalManager => widget.role == 'MANAGER';

  /// Satu-satunya sumber daftar menu. Dipakai bersama oleh sidebar
  /// (`_navItems`) dan pemilihan halaman (`_buildBody`), supaya index menu
  /// selalu cocok dengan halaman yang ditampilkan — termasuk saat ada menu
  /// yang disembunyikan lewat feature flag.
  List<_NavSpec> _navSpecs() {
    const utama = 'Utama';
    const data = 'Data';
    const operasional = 'Operasional';
    const manajemen = 'Manajemen';
    return [
      // Data Penjualan tampil sebagai menu utama pertama dan memakai label
      // "Dashboard". Syarat tampilnya tetap sama: hanya non-ADMIN dan selama
      // feature flag aktif.
      if (widget.role != 'ADMIN' && AppConfig.enableImportedSales)
        const _NavSpec(
          page: _DashboardPage.importedSales,
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Dashboard',
          group: utama,
        ),
      if (widget.role != 'ADMIN')
        const _NavSpec(
          page: _DashboardPage.inventoryTracker,
          icon: Icons.inventory_outlined,
          selectedIcon: Icons.inventory,
          label: 'Stok By Supplier',
          group: utama,
        ),
      if (widget.role != 'ADMIN')
        const _NavSpec(
          page: _DashboardPage.inventoryTrackerSku,
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: 'Stok By SKU',
          group: utama,
        ),
      // Ringkasan sistem (stats) memakai label "Sales Order" supaya tidak
      // bentrok dengan menu Dashboard di atas.
      const _NavSpec(
        page: _DashboardPage.dashboard,
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        label: 'Sales Order',
        group: utama,
      ),
      const _NavSpec(
        page: _DashboardPage.orders,
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment,
        label: 'Pesanan',
        group: utama,
      ),
      const _NavSpec(
        page: _DashboardPage.customers,
        icon: Icons.store_outlined,
        selectedIcon: Icons.store,
        label: 'Toko',
        group: data,
      ),
      const _NavSpec(
        page: _DashboardPage.customerSubmissions,
        icon: Icons.person_add_alt_1_outlined,
        selectedIcon: Icons.person_add_alt_1,
        label: 'Pengajuan Customer',
        group: data,
      ),
      const _NavSpec(
        page: _DashboardPage.products,
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        label: 'Produk & Stok',
        group: data,
      ),
      const _NavSpec(
        page: _DashboardPage.suppliers,
        icon: Icons.store_mall_directory_outlined,
        selectedIcon: Icons.store_mall_directory,
        label: 'Supplier',
        group: data,
      ),
      const _NavSpec(
        page: _DashboardPage.sync,
        icon: Icons.sync_outlined,
        selectedIcon: Icons.sync,
        label: 'Sinkronisasi',
        group: operasional,
      ),
      const _NavSpec(
        page: _DashboardPage.attendance,
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check,
        label: 'Absensi Kunjungan',
        group: operasional,
      ),
      if (_isGlobalManager)
        const _NavSpec(
          page: _DashboardPage.waSession,
          icon: Icons.sim_card_outlined,
          selectedIcon: Icons.sim_card,
          label: 'Sesi WhatsApp',
          group: operasional,
        ),
      if (widget.role != 'ADMIN') ...[
        const _NavSpec(
          page: _DashboardPage.users,
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: 'User',
          group: manajemen,
        ),
        const _NavSpec(
          page: _DashboardPage.performance,
          icon: Icons.trending_up_outlined,
          selectedIcon: Icons.trending_up,
          label: 'Performa Sales',
          group: manajemen,
        ),
        const _NavSpec(
          page: _DashboardPage.supplierPerformance,
          icon: Icons.table_chart_outlined,
          selectedIcon: Icons.table_chart,
          label: 'Performa Supplier',
          group: manajemen,
        ),
        const _NavSpec(
          page: _DashboardPage.penugasan,
          icon: Icons.assignment_ind_outlined,
          selectedIcon: Icons.assignment_ind,
          label: 'Penugasan Sales',
          group: manajemen,
        ),
        const _NavSpec(
          page: _DashboardPage.bulletins,
          icon: Icons.campaign_outlined,
          selectedIcon: Icons.campaign,
          label: 'Bulletin',
          group: manajemen,
        ),
      // Presence supervisor: MANAGER memantau keaktifan supervisor dalam
      // monitoring kinerja cabang (endpoint di-gate 403 untuk role lain).
      if (_isGlobalManager)
        const _NavSpec(
          page: _DashboardPage.userPresence,
          icon: Icons.wifi_tethering_outlined,
          selectedIcon: Icons.wifi_tethering,
          label: 'Status Online',
          group: manajemen,
        ),
      ],
      if (_isGlobalManager)
        const _NavSpec(
          page: _DashboardPage.crossBranch,
          icon: Icons.compare_arrows_outlined,
          selectedIcon: Icons.compare_arrows,
          label: 'Laporan Lintas Cabang',
          group: manajemen,
        ),
    ];
  }

  List<AppShellNavItem> _navItems({bool hasNewPending = false}) {
    return [
      for (final spec in _navSpecs())
        AppShellNavItem(
          icon: spec.icon,
          selectedIcon: spec.selectedIcon,
          label: spec.label,
          group: spec.group,
          showBadge: spec.page == _DashboardPage.orders && hasNewPending,
        ),
    ];
  }

  int _indexOfPage(_DashboardPage page) {
    final index = _navSpecs().indexWhere((spec) => spec.page == page);
    // Fallback ke menu pertama (Dashboard) kalau halaman tidak tersedia untuk
    // role ini — mencegah index -1.
    return index < 0 ? 0 : index;
  }

  /// Nomor tab yang dipakai `AdminProvider` untuk lazy load & cache.
  int _providerTabIndex(_DashboardPage page) {
    switch (page) {
      case _DashboardPage.dashboard:
        return 0;
      case _DashboardPage.orders:
        return 1;
      case _DashboardPage.customers:
        return 2;
      case _DashboardPage.customerSubmissions:
        return 3;
      case _DashboardPage.products:
        return 4;
      case _DashboardPage.suppliers:
        return 5;
      case _DashboardPage.sync:
        return 6;
      case _DashboardPage.users:
        return 7;
      case _DashboardPage.performance:
        return 8;
      case _DashboardPage.supplierPerformance:
        return 13;
      case _DashboardPage.inventoryTracker:
        return 16;
      case _DashboardPage.inventoryTrackerSku:
        return 17;
      case _DashboardPage.userPresence:
        return 18;
      case _DashboardPage.penugasan:
        return 9;
      case _DashboardPage.bulletins:
        return 10;
      case _DashboardPage.importedSales:
        return 11;
      case _DashboardPage.crossBranch:
        return 12;
      case _DashboardPage.attendance:
        return 14;
      case _DashboardPage.waSession:
        return 15;
    }
  }

  @override
  void initState() {
    super.initState();
    // Data timezone ikut chunk dashboard, jadi disiapkan di sini — sebelum
    // tab mana pun memformat tanggal.
    ensureTimezoneInitialized();
    _adminProvider = context.read<AdminProvider>();
    _apiService = widget.apiService;
    WidgetsBinding.instance.addObserver(this);

    // Register 401 callback â€” redirect via navigatorKey supaya aman
    // dipanggil setelah widget dispose (context tidak boleh dipakai post-dispose).
    _apiService.setOnUnauthorized(_handleUnauthorized);

    // Check token expiry on startup — redirect to login if expired.
    // Jalur normal: boot sudah silent-refresh sebelum dashboard tampil, jadi
    // ini hanya terjadi pada clock skew ekstrem / token rusak.
    if (JwtUtils.isExpired(_apiService.accessToken)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        AuthSession.instance.clear();
        if (!mounted) return;
        _pushLogin();
      });
      return;
    }

    // Set role di provider supaya loadAll() tahu endpoint mana yang boleh dipanggil.
    // loadAll + auto-refresh dijalankan SETELAH frame pertama selesai supaya
    // notifyListeners tidak terjadi di tengah build phase (yang bisa trigger _dirty).
    _adminProvider.setUserRole(widget.role);
    _adminProvider.setUserBranch(widget.branch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Sinkronkan tab aktif provider dengan halaman pertama yang tampil,
      // karena urutan menu (dan halaman default) tidak lagi sama dengan
      // nomor tab internal provider.
      final specs = _navSpecs();
      _adminProvider.setActiveTab(
        _providerTabIndex(
          specs[_selectedIndex.clamp(0, specs.length - 1)].page,
        ),
      );
      _adminProvider.loadAll();

      if (widget.role == 'MANAGER' || widget.role == 'SUPERVISOR') {
        _adminProvider.loadSalesPerformanceDashboard();
      }
      // Tidak ada idle timer — hanya silent refresh yang berjalan periodik.
      _refreshTimer = Timer.periodic(
        _refreshCheckInterval,
        (_) => _maybeSilentRefresh(),
      );
    });
  }

  void _handleUnauthorized() async {
    // Interceptor sudah mencoba silent refresh via cookie dan gagal — sesi
    // memang habis di server. Cukup bersihkan state lokal.
    AuthSession.instance.clear();
    if (!mounted) return;
    _pushLogin();
  }

  void _pushLogin() {
    // pushAndRemoveUntil (bukan pushReplacement) supaya SELURUH stack
    // dibersihkan â€” kalau user sedang di sub-screen (mis. detail pesanan),
    // sub-screen DAN DashboardScreen semuanya hilang, hanya layar login
    // yang tersisa. Detailnya ada di core/session_navigation.dart.
    showLoginScreen();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // Di web, lifecycle state dipakai untuk tab focus events
    // (inactive/hidden = tab di background, resumed = tab aktif).
    if (lifecycleState == AppLifecycleState.resumed) {
      // Tab kembali aktif: pastikan access token masih segar. (Tidak ada
      // idle tracking — user boleh meninggalkan tab selamanya.)
      // Timer di background tab di-throttle browser — pulihkan sesi langsung
      // saat tab aktif kembali dan token mendekati kedaluwarsa.
      _maybeSilentRefresh();
    }
  }

  /// Refresh sesi bila access token mendekati kedaluwarsa (sliding session).
  /// Cookie httpOnly terkirim otomatis; token baru menggantikan yang lama
  /// di AuthSession dan dipakai request berikutnya oleh AuthInterceptor.
  void _maybeSilentRefresh() {
    if (!mounted) return;
    final payload = JwtUtils.decodePayload(AuthSession.instance.accessToken);
    final exp = payload?['exp'];
    if (exp is! num) return;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    if (expiresAt.difference(DateTime.now()) <= _refreshBeforeExpiry) {
      _apiService.refreshSession();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _apiService.setOnUnauthorized(null);
    super.dispose();
  }

  void _onNavTap(int i) {
    final specs = _navSpecs();
    final leavingOrders =
        i != _indexOfPage(_DashboardPage.orders) &&
        _selectedIndex < specs.length &&
        specs[_selectedIndex].page == _DashboardPage.orders;
    if (leavingOrders) {
      // Clear badge when leaving orders tab
      context.read<AdminProvider>().clearNewPendingBadge();
    }
    setState(() => _selectedIndex = i);
    // Cancel any in-flight loadAll requests user sudah pindah tab,
    // response dari tab lama tidak relevan.
    context.read<AdminProvider>().cancelInFlightLoads();
    // Tell provider tab aktif supaya auto-refresh hanya load data tab ini.
    // Pakai nomor tab internal provider, bukan index sidebar.
    context.read<AdminProvider>().setActiveTab(
      _providerTabIndex(specs[i].page),
    );
  }

  Widget _buildBody() {
    final specs = _navSpecs();
    final i = _selectedIndex.clamp(0, specs.length - 1);
    // Permission BEDA per fitur — bukan satu flag global. Backend endpoint
    // masing-masing tab punya aturan sendiri, jadi UI harus match.
    //
    // Pesanan (orders):
    //   - POST /orders/{id}/approve pakai require_admin → hanya ADMIN write.
    //   - SUPERVISOR & MANAGER murni monitoring.
    // Master data (Toko, Pengajuan Customer, Produk, Bulletin, Sync):
    //   read-only untuk semua role (ADMIN/SUPERVISOR/MANAGER memantau).
    //   Create/edit di backend pakai require_supervisor_or_manager_global →
    //   ADMIN, SUPERVISOR & MANAGER boleh write.
    final orderReadOnly = widget.role != 'ADMIN';
    // Users tab: ADMIN, SUPERVISOR, MANAGER boleh add/edit user.
    final usersReadOnly = widget.role == 'SALES';
    // Master data (Toko, Pengajuan Customer, Produk, Bulletin): read-only untuk non-ADMIN.
    // Sync: ADMIN, SUPERVISOR, MANAGER boleh write (import Excel).
    final masterReadOnly = widget.role != 'ADMIN';
    final syncReadOnly = widget.role == 'SALES';

    // Halaman dipilih berdasarkan identitas menu (bukan index numerik),
    // sehingga urutan menu bisa berubah tanpa membuat tab yang salah terbuka.
    switch (specs[i].page) {
      case _DashboardPage.dashboard:
        return StatsTab(
          role: widget.role,
          onOpenOrdersTab: (initialTabIndex) {
            setState(() {
              _selectedIndex = _indexOfPage(_DashboardPage.orders);
              _ordersInitialTabIndex = initialTabIndex;
            });
            context.read<AdminProvider>().setActiveTab(
              _providerTabIndex(_DashboardPage.orders),
            );
          },
        );
      case _DashboardPage.orders:
        return OrdersTab(
          readOnly: orderReadOnly,
          initialTabIndex: _ordersInitialTabIndex,
        );
      case _DashboardPage.customers:
        return CustomersTab(readOnly: masterReadOnly);
      case _DashboardPage.customerSubmissions:
        return CustomerSubmissionsTab(readOnly: masterReadOnly);
      case _DashboardPage.products:
        return ProductsTab(readOnly: masterReadOnly);
      case _DashboardPage.suppliers:
        return const SuppliersTab();
      case _DashboardPage.sync:
        return SyncTab(readOnly: syncReadOnly);
      case _DashboardPage.users:
        return UsersTab(
          readOnly: usersReadOnly,
          currentRole: widget.role,
          currentBranch: widget.branch,
          currentBranchNama: widget.branchNama,
        );
      case _DashboardPage.performance:
        return const PerformanceTab(); // MANAGER & SUPERVISOR
      case _DashboardPage.supplierPerformance:
        return const SupplierPerformancePivotTab();
      case _DashboardPage.inventoryTracker:
        return const InventoryTrackerTab(
          key: ValueKey('inventory-tracker-supplier'),
        );
      case _DashboardPage.inventoryTrackerSku:
        return const InventoryTrackerTab(
          key: ValueKey('inventory-tracker-sku'),
          dimension: InventoryTrackerDimension.sku,
        );
      case _DashboardPage.userPresence:
        if (_isGlobalManager) return const UserPresenceTab();
        break;
      case _DashboardPage.penugasan:
        return const PenugasanSalesTab(); // MANAGER & SUPERVISOR
      case _DashboardPage.bulletins:
        return BulletinsTab(readOnly: masterReadOnly); // MANAGER & SUPERVISOR
      case _DashboardPage.importedSales:
        // Tidak bisa dibuka selama AppConfig.enableImportedSales = false.
        return ImportedSalesTab(
          readOnly: !_isGlobalManager,
        ); // MANAGER & SUPERVISOR
      case _DashboardPage.crossBranch:
        if (_isGlobalManager) return const CrossBranchReportsTab();
        break;
      case _DashboardPage.attendance:
        return const AttendanceTab();
      case _DashboardPage.waSession:
        if (_isGlobalManager) return const WaQrScannerPage();
        break;
    }
    return StatsTab(
      role: widget.role,
      onOpenOrdersTab: (initialTabIndex) {
        setState(() {
          _selectedIndex = _indexOfPage(_DashboardPage.orders);
          _ordersInitialTabIndex = initialTabIndex;
        });
        context.read<AdminProvider>().setActiveTab(
          _providerTabIndex(_DashboardPage.orders),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasNewPending = context.watch<AdminProvider>().hasNewPending;
    final navItems = _navItems(hasNewPending: hasNewPending);

    // Tidak ada lagi pelacakan aktivitas: Listener idle dulu dipasang di
    // sini untuk timer auto-logout, yang kini dihapus sepenuhnya.
    return AppShell(
      scaffoldKey: _scaffoldKey,
      title: navItems[_selectedIndex.clamp(0, navItems.length - 1)].label,
      titleTrailing: null,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => context.read<AdminProvider>().refresh(),
        ),
      ],
      brandTitle: widget.branchNama?.trim().isNotEmpty == true
          ? widget.branchNama!.trim()
          : BranchLabel.display(widget.branch) ?? 'Sales Order',
      brandSubtitle: widget.role == 'MANAGER'
          ? 'Global Manager'
          : widget.role == 'SUPERVISOR'
          ? 'Supervisor Cabang'
          : 'Admin Panel',
      items: navItems,
      selectedIndex: _selectedIndex.clamp(0, navItems.length - 1),
      onIndexSelected: _onNavTap,
      userName: widget.nama.isNotEmpty ? widget.nama : widget.username,
      roleLabel: widget.role == 'MANAGER' ? 'Manager' : 'Administrator',
      onChangePassword: () => ChangePasswordDialog.show(
        context,
        context.read<AdminProvider>().adminRepository,
      ),
      onLogout: () async {
        // Logout manual: hapus cookie sesi di server (best-effort) lalu
        // bersihkan sesi in-memory sebelum pindah ke layar login.
        await _apiService.logoutServer();
        AuthSession.instance.clear();
        if (!context.mounted) return;
        // Ganti seluruh stack lewat root navigator supaya drawer (kalau
        // terbuka) ikut ter-pop.
        showLoginScreen();
      },
      body: _buildBody(),
    );
  }
}
