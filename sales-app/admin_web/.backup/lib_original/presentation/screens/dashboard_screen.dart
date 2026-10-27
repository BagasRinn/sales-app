import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_storage.dart';
import '../../core/branch.dart';
import '../../core/design_system.dart';
import '../../core/jwt_utils.dart';
import '../../core/navigator_key.dart';
import '../../core/responsive.dart';
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
    _apiService.setTokens(access: widget.accessToken, refresh: widget.refreshToken);
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
  late final AdminProvider _adminProvider;
  late final ApiService _apiService;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  //idle auto-logout
  static const Duration _idleTimeout = Duration(minutes: 15);
  static const Duration _idleCheckInterval = Duration(seconds: 30);

  DateTime _lastActivity = DateTime.now();
  Timer? _idleTimer;

  bool get _isGlobalManager => widget.role == 'MANAGER';

  List<_NavItem> get _navItems {
    final items = <_NavItem>[
      const _NavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard'),
      const _NavItem(icon: Icons.assignment_outlined, selectedIcon: Icons.assignment, label: 'Pesanan'),
      const _NavItem(icon: Icons.store_outlined, selectedIcon: Icons.store, label: 'Toko'),
      const _NavItem(icon: Icons.person_add_alt_1_outlined, selectedIcon: Icons.person_add_alt_1, label: 'Pengajuan Customer'),
      const _NavItem(icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2, label: 'Produk & Stok'),
      const _NavItem(icon: Icons.store_mall_directory_outlined, selectedIcon: Icons.store_mall_directory, label: 'Supplier'),
      const _NavItem(icon: Icons.sync_outlined, selectedIcon: Icons.sync, label: 'Sinkronisasi'),
    ];
    if (_isGlobalManager) {
      items.add(const _NavItem(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'User'));
      items.add(const _NavItem(icon: Icons.trending_up_outlined, selectedIcon: Icons.trending_up, label: 'Performa Sales'));
      items.add(const _NavItem(icon: Icons.assignment_ind_outlined, selectedIcon: Icons.assignment_ind, label: 'Penugasan Sales'));
      items.add(const _NavItem(icon: Icons.campaign_outlined, selectedIcon: Icons.campaign, label: 'Bulletin'));
      items.add(const _NavItem(icon: Icons.compare_arrows_outlined, selectedIcon: Icons.compare_arrows, label: 'Laporan Lintas Cabang'));
    } else if (widget.role == 'SUPERVISOR') {
      items.add(const _NavItem(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'User'));
      items.add(const _NavItem(icon: Icons.trending_up_outlined, selectedIcon: Icons.trending_up, label: 'Performa Sales'));
      items.add(const _NavItem(icon: Icons.assignment_ind_outlined, selectedIcon: Icons.assignment_ind, label: 'Penugasan Sales'));
      items.add(const _NavItem(icon: Icons.campaign_outlined, selectedIcon: Icons.campaign, label: 'Bulletin'));
    }
    return items;
  }

  List<String> get _titles {
    final titles = <String>[
      'Dashboard',
      'Pesanan',
      'Toko',
      'Pengajuan Customer',
      'Produk & Stok',
      'Supplier',
      'Sinkronisasi',
    ];
    if (_isGlobalManager) {
      titles.add('User');
      titles.add('Performa Sales');
      titles.add('Penugasan Sales');
      titles.add('Bulletin');
      titles.add('Laporan Lintas Cabang');
    } else if (widget.role == 'SUPERVISOR') {
      titles.add('User');
      titles.add('Performa Sales');
      titles.add('Penugasan Sales');
      titles.add('Bulletin');
    }
    return titles;
  }

  @override
  void initState() {
    super.initState();
    _adminProvider = context.read<AdminProvider>();
    _apiService = widget.apiService;
    WidgetsBinding.instance.addObserver(this);

    // Register 401 callback — redirect via navigatorKey supaya aman
    // dipanggil setelah widget dispose (context tidak boleh dipakai post-dispose).
    _apiService.setOnUnauthorized(_handleUnauthorized);

    // Check token expiry on startup — redirect to login if expired
    if (JwtUtils.isExpired(_apiService.accessToken)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await AuthStorage().clearTokens();
        if (!mounted) return;
        _pushLogin();
      });
      return;
    }

    // Set role di provider supaya loadAll() tahu endpoint mana yang boleh dipanggil.
    // loadAll + auto-refresh dijalankan SETELAH frame pertama selesai — supaya
    // notifyListeners tidak terjadi di tengah build phase (yang bisa trigger _dirty).
    _adminProvider.setUserRole(widget.role);
    _adminProvider.setUserBranch(widget.branch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _adminProvider.loadAll();

      if (widget.role == 'MANAGER' || widget.role == 'SUPERVISOR') {
        _adminProvider.loadSalesPerformanceDashboard();
      }
      // Idle timer baru mulai setelah load pertama selesai — supaya
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
    // dibersihkan — kalau user sedang di sub-screen (mis. detail pesanan),
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
    final items = _navItems;
    final leavingOrders = i != 1 &&
        _selectedIndex == 1 &&
        _selectedIndex < items.length &&
        items[_selectedIndex].label == 'Pesanan';
    if (leavingOrders) {
      // Clear badge when leaving orders tab
      context.read<AdminProvider>().clearNewPendingBadge();
    }
    setState(() => _selectedIndex = i);
    // Cancel any in-flight loadAll requests — user sudah pindah tab,
    // response dari tab lama tidak relevan.
    context.read<AdminProvider>().cancelInFlightLoads();
    // Tell provider tab aktif supaya auto-refresh hanya load data tab ini.
    context.read<AdminProvider>().setActiveTab(i);
  }

  Widget _buildBody() {
    final items = _navItems;
    final i = _selectedIndex.clamp(0, items.length - 1);
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

    // Indexes shared: 0=Dashboard, 1=Pesanan, 2=Toko,
    // 3=Pengajuan Customer, 4=Produk & Stok, 5=Supplier, 6=Sinkronisasi.
    // Global MANAGER: 7=User, 8=Performa Sales, 9=Penugasan Sales, 10=Bulletin, 11=Laporan Lintas.
    // ADMIN/SUPERVISOR: 7=User, 8=Bulletin.
    switch (i) {
      case 0:
        return StatsTab(role: widget.role);
      case 1:
        return OrdersTab(readOnly: orderReadOnly);
      case 2:
        return CustomersTab(readOnly: masterReadOnly);
      case 3:
        return CustomerSubmissionsTab(readOnly: masterReadOnly);
      case 4:
        return ProductsTab(readOnly: masterReadOnly);
      case 5:
        return const SuppliersTab();
      case 6:
        return SyncTab(readOnly: syncReadOnly);
      case 7:
        return UsersTab(
          readOnly: usersReadOnly,
          currentRole: widget.role,
          currentBranch: widget.branch,
          currentBranchNama: widget.branchNama,
        );
      case 8:
        return const PerformanceTab(); // MANAGER & SUPERVISOR
      case 9:
        return const PenugasanSalesTab(); // MANAGER & SUPERVISOR
      case 10:
        return BulletinsTab(readOnly: masterReadOnly); // MANAGER & SUPERVISOR
      case 11:
        if (_isGlobalManager) return const CrossBranchReportsTab();
        break;
    }
    return StatsTab(role: widget.role);
  }

  @override
  Widget build(BuildContext context) {
    // Listener (translucent) di paling luar: setiap pointer event di dashboard
    // dianggap aktivitas user. Tanpa throttle — Timer._checkIdle sudah jalan
    // setiap 30 detik, jadi tidak perlu debounce di sisi Listener.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordActivity(),
      // Track any pointer movement (touch scroll, mouse hover, drag). Tanpa
      // gate buttons != 0 supaya touch scroll di mobile ikut dihitung sebagai
      // aktivitas — kalau gate tetap, mobile user yang cuma scroll list
      // panjang akan ke-logout. Hover di desktop tetap aman karena pointer
      // event jarang firing saat idle (tidak ada device input aktif).
      onPointerMove: (_) => _recordActivity(),
      onPointerSignal: (_) => _recordActivity(), // wheel/trackpad
      child: LayoutBuilder(
        builder: (context, constraints) {
          final resp = Responsive.of(constraints.maxWidth);
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: AppColors.background,
            // Drawer hanya muncul saat compact (mobile/tablet). Desktop pakai
            // sidebar 240px yang di-render langsung di body.
            drawer: resp.isCompact ? _buildDrawer(context, resp) : null,
            body: Row(
              children: [
                if (resp.isDesktop) _buildSidebar(context),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(context, resp),
                      Expanded(child: _buildBody()),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Sidebar 240px — versi desktop, tidak berubah dari versi lama.
  Widget _buildSidebar(BuildContext context) {
    return SizedBox(
      width: 240,
      child: _NavPanel(
        items: _navItems,
        selectedIndex: _selectedIndex,
        hasNewPending: context.watch<AdminProvider>().hasNewPending,
        onTap: _onNavTap,
        userNama: widget.nama,
        username: widget.username,
        role: widget.role,
        branch: widget.branch,
        branchNama: widget.branchNama,
      ),
    );
  }

  /// Drawer untuk mode compact (mobile/tablet). Konten nav-nya sama dengan
  /// sidebar, dibungkus [Drawer] supaya Flutter yang handle gesture buka-tutup.
  Widget _buildDrawer(BuildContext context, Responsive resp) {
    // Lebar drawer: minimum dari 280px (target tap-friendly) dan 85% viewport.
    // Tanpa clamp, di layar 320px (iPhone SE 1st gen) drawer 280px menutupi
    // hampir semua layar — user cuma melihat 40px konten di belakangnya.
    final viewportWidth = MediaQuery.of(context).size.width;
    final drawerWidth = math.min(280.0, viewportWidth * 0.85);
    return Drawer(
      backgroundColor: AppColors.sidebarBg,
      // Tanpa elevation — sidebar polos supaya tidak ada shadow menumpuk.
      elevation: 0,
      child: SizedBox(
        width: drawerWidth,
        child: _NavPanel(
          items: _navItems,
          selectedIndex: _selectedIndex,
          hasNewPending: context.watch<AdminProvider>().hasNewPending,
          onTap: (i) {
            _onNavTap(i);
            // Tutup drawer setelah nav dipilih supaya konten kelihatan.
            Navigator.of(context).pop();
          },
          userNama: widget.nama,
          username: widget.username,
          role: widget.role,
          branch: widget.branch,
          branchNama: widget.branchNama,
        ),
      ),
    );
  }

  /// Top bar — judul tab + refresh. Mode compact menambah hamburger di kiri
  /// untuk membuka drawer.
  Widget _buildTopBar(BuildContext context, Responsive resp) {
    final showReadOnlyBadge =
        widget.role != 'ADMIN' &&
            _selectedIndex < _navItems.length &&
            _navItems[_selectedIndex].label == 'Pesanan';
    return Container(
      height: resp.topBarHeight,
      padding: EdgeInsets.symmetric(horizontal: resp.contentPadding),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          if (resp.isCompact)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                color: AppColors.textSecondary,
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _titles[_selectedIndex],
                    style: resp.isMobile
                        ? AppTextStyles.headlineSmall
                        : AppTextStyles.headlineMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showReadOnlyBadge)
                  Visibility(
                    // Di compact, title + badge berebut ruang sempit. Sembunyikan
                    // badge — refresh IconButton tetap ada di kanan. Info role
                    // masih tersedia di sidebar/drawer (User section).
                    visible: !resp.isCompact,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.infoBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.infoBorder),
                        ),
                        child: const Text(
                          'Read-only',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            color: AppColors.textSecondary,
            onPressed: () {
              context.read<AdminProvider>().refresh();
            },
          ),
        ],
      ),
    );
  }
}

/// Panel navigasi reusable — dipakai oleh sidebar (desktop) dan drawer
/// (mobile/tablet). Visual sama persis dengan sidebar lama supaya tidak ada
/// perubahan tampilan di desktop.
class _NavPanel extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final bool hasNewPending;
  final ValueChanged<int> onTap;
  final String userNama;
  final String username;
  final String role;
  final String? branch;
  final String? branchNama;

  const _NavPanel({
    required this.items,
    required this.selectedIndex,
    required this.hasNewPending,
    required this.onTap,
    required this.userNama,
    required this.username,
    required this.role,
    this.branch,
    this.branchNama,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.sidebarBg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_shipping,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sales Order',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: AppTextStyles.fontFamily,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          branchNama ??
                              BranchLabel.display(branch) ??
                              'Admin Panel',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: AppTextStyles.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            // Nav items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final selected = selectedIndex == i;
                  final showBadge = i == 1 && hasNewPending;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onTap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected ? item.selectedIcon : item.icon,
                                color:
                                    selected ? Colors.white : Colors.white60,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontFamily: AppTextStyles.fontFamily,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (showBadge) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF4757),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // User section
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Builder(builder: (_) {
                        final display =
                            userNama.isNotEmpty ? userNama : username;
                        return Text(
                          display.isNotEmpty
                              ? display[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(builder: (_) {
                          final display =
                              userNama.isNotEmpty ? userNama : username;
                          return Text(
                            display,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: AppTextStyles.fontFamily,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          );
                        }),
                        Text(
                          role == 'MANAGER' ? 'Manager' : 'Administrator',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontFamily: AppTextStyles.fontFamily,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock_outline,
                        color: Colors.white54, size: 20),
                    tooltip: 'Ganti password',
                    onPressed: () => ChangePasswordDialog.show(
                      context,
                      context.read<AdminProvider>().adminRepository,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout,
                        color: Colors.white54, size: 20),
                    tooltip: 'Keluar',
                    onPressed: () async {
                      await AuthStorage().clearTokens();
                      if (!context.mounted) return;
                      // Pakai rootNavigatorKey langsung supaya drawer (kalau
                      // terbuka) ikut ter-pop oleh pushAndRemoveUntil.
                      rootNavigatorKey.currentState?.pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
