import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_storage.dart';
import '../../core/branch.dart';
import '../../core/design_system.dart';
import '../../core/jwt_utils.dart';
import '../../core/navigator_key.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/api_service.dart';
import '../providers/admin_provider.dart';
import 'login_screen.dart';
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
import 'suppliers_tab.dart';
import 'imported_sales_tab.dart';
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
  penugasan,
  bulletins,
  importedSales,
  crossBranch,
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
  final String refreshToken;
  final String username;
  final String nama;
  final String role;
  final String? branch;
  final String? branchNama;

  const DashboardScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
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
    _apiService.setTokens(
      access: widget.accessToken,
      refresh: widget.refreshToken,
    );
    _repo = AdminRepository(_apiService);
    _repo.setTokens(widget.accessToken, widget.refreshToken);
    AuthStorage().saveTokens(
      accessToken: widget.accessToken,
      refreshToken: widget.refreshToken,
      username: widget.username,
      nama: widget.nama.isEmpty ? null : widget.nama,
      role: widget.role,
      branch: widget.branch,
      branchNama: widget.branchNama,
    );
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

  //idle auto-logout
  static const Duration _idleTimeout = Duration(minutes: 15);
  static const Duration _idleCheckInterval = Duration(seconds: 30);

  DateTime _lastActivity = DateTime.now();
  Timer? _idleTimer;

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
      const _NavSpec(
        page: _DashboardPage.dashboard,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: 'Dashboard',
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
        // Disembunyikan sementara lewat AppConfig.enableImportedSales.
        // Halaman & provider-nya tetap ada, hanya tidak ditampilkan.
        if (AppConfig.enableImportedSales)
          const _NavSpec(
            page: _DashboardPage.importedSales,
            icon: Icons.analytics_outlined,
            selectedIcon: Icons.analytics,
            label: 'Data Penjualan',
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

  @override
  void initState() {
    super.initState();
    _adminProvider = context.read<AdminProvider>();
    _apiService = widget.apiService;
    WidgetsBinding.instance.addObserver(this);

    // Register 401 callback â€” redirect via navigatorKey supaya aman
    // dipanggil setelah widget dispose (context tidak boleh dipakai post-dispose).
    _apiService.setOnUnauthorized(_handleUnauthorized);

    // Check token expiry on startup â€” redirect to login if expired
    if (JwtUtils.isExpired(_apiService.accessToken)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await AuthStorage().clearTokens();
        if (!mounted) return;
        _pushLogin();
      });
      return;
    }

    // Set role di provider supaya loadAll() tahu endpoint mana yang boleh dipanggil.
    // loadAll + auto-refresh dijalankan SETELAH frame pertama selesai â€” supaya
    // notifyListeners tidak terjadi di tengah build phase (yang bisa trigger _dirty).
    _adminProvider.setUserRole(widget.role);
    _adminProvider.setUserBranch(widget.branch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _adminProvider.loadAll();

      if (widget.role == 'MANAGER' || widget.role == 'SUPERVISOR') {
        _adminProvider.loadSalesPerformanceDashboard();
      }
      // Idle timer baru mulai setelah load pertama selesai â€” supaya
      // activity "load" dari internal tidak dihitung interaksi user.
      _lastActivity = DateTime.now();
      _idleTimer = Timer.periodic(_idleCheckInterval, (_) => _checkIdle());
    });
  }

  void _handleUnauthorized() async {
    await AuthStorage().clearTokens();
    if (!mounted) return;
    _pushLogin();
  }

  void _pushLogin() {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    // pushAndRemoveUntil (bukan pushReplacement) supaya SELURUH stack
    // dibersihkan â€” kalau user sedang di sub-screen (mis. detail pesanan),
    // sub-screen DAN DashboardScreen semuanya hilang, hanya LoginScreen
    // yang tersisa.
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // Di web, lifecycle state dipakai untuk tab focus events
    // (inactive/hidden = tab di background, resumed = tab aktif).
    if (lifecycleState == AppLifecycleState.resumed) {
      _recordActivity();
    }
  }

  void _recordActivity() {
    _lastActivity = DateTime.now();
  }

  void _checkIdle() {
    if (!mounted) return;
    final idle = DateTime.now().difference(_lastActivity);
    if (idle > _idleTimeout) {
      _idleTimer?.cancel();
      AuthStorage().clearTokens();
      _pushLogin();
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
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
    // Cancel any in-flight loadAll requests â€” user sudah pindah tab,
    // response dari tab lama tidak relevan.
    context.read<AdminProvider>().cancelInFlightLoads();
    // Tell provider tab aktif supaya auto-refresh hanya load data tab ini.
    context.read<AdminProvider>().setActiveTab(i);
  }

  Widget _buildBody() {
    final specs = _navSpecs();
    final i = _selectedIndex.clamp(0, specs.length - 1);
    // Permission BEDA per fitur â€” bukan satu flag global. Backend endpoint
    // masing-masing tab punya aturan sendiri, jadi UI harus match.
    //
    // Pesanan (orders):
    //   - POST /orders/{id}/approve pakai require_admin â†’ hanya ADMIN write.
    //   - SUPERVISOR & MANAGER murni monitoring.
    // Master data (Toko, Pengajuan Customer, Produk, Bulletin, Sync):
    //   read-only untuk semua role (ADMIN/SUPERVISOR/MANAGER memantau).
    //   Create/edit di backend pakai require_supervisor_or_manager_global â†’
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
              _indexOfPage(_DashboardPage.orders),
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
    }
    return StatsTab(
      role: widget.role,
      onOpenOrdersTab: (initialTabIndex) {
        setState(() {
          _selectedIndex = _indexOfPage(_DashboardPage.orders);
          _ordersInitialTabIndex = initialTabIndex;
        });
        context.read<AdminProvider>().setActiveTab(
          _indexOfPage(_DashboardPage.orders),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasNewPending = context.watch<AdminProvider>().hasNewPending;
    final navItems = _navItems(hasNewPending: hasNewPending);

    // Listener (translucent) di paling luar: setiap pointer event di dashboard
    // dianggap aktivitas user. Tanpa throttle â€” Timer._checkIdle sudah jalan
    // setiap 30 detik, jadi tidak perlu debounce di sisi Listener.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordActivity(),
      // Track any pointer movement (touch scroll, mouse hover, drag). Tanpa
      // gate buttons != 0 supaya touch scroll di mobile ikut dihitung sebagai
      // aktivitas â€” kalau gate tetap, mobile user yang cuma scroll list
      // panjang akan ke-logout. Hover di desktop tetap aman karena pointer
      // event jarang firing saat idle (tidak ada device input aktif).
      onPointerMove: (_) => _recordActivity(),
      onPointerSignal: (_) => _recordActivity(), // wheel/trackpad
      child: AppShell(
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
          await AuthStorage().clearTokens();
          if (!context.mounted) return;
          // Pakai rootNavigatorKey langsung supaya drawer (kalau terbuka)
          // ikut ter-pop oleh pushAndRemoveUntil.
          rootNavigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        },
        body: _buildBody(),
      ),
    );
  }
}
