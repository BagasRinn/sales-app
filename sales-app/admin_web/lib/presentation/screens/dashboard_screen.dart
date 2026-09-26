import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_storage.dart';
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
import 'customers_tab.dart';
import 'users_tab.dart';

class DashboardScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;
  final String username;
  final String nama;
  final String role;

  const DashboardScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
    required this.username,
    required this.nama,
    required this.role,
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
        apiService: _apiService,
      ),
    );
  }
}

class _DashboardContent extends StatefulWidget {
  final String username;
  final String nama;
  final String role;
  final ApiService apiService;

  const _DashboardContent({
    required this.username,
    required this.nama,
    required this.role,
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

  // Track aktivitas user untuk idle auto-logout. Default 15 menit — standar
  // untuk aplikasi admin. Bisa diturunkan kalau perlu lebih ketat, atau
  // dinaikkan kalau admin sering monitor tanpa interaksi.
  static const Duration _idleTimeout = Duration(minutes: 15);
  static const Duration _idleCheckInterval = Duration(seconds: 30);

  DateTime _lastActivity = DateTime.now();
  Timer? _idleTimer;

  bool get _isAdmin => widget.role == 'ADMIN';
  bool get _isManager => widget.role == 'MANAGER';

  List<_NavItem> get _navItems {
    // Urutan tab konsisten untuk kedua role — MANAGER dapat Dashboard juga
    // (ringkasan read-only), tapi TIDAK dapat Produk & Stok / Sinkronisasi.
    final items = <_NavItem>[
      const _NavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard'),
      const _NavItem(icon: Icons.assignment_outlined, selectedIcon: Icons.assignment, label: 'Pesanan'),
      const _NavItem(icon: Icons.store_outlined, selectedIcon: Icons.store, label: 'Toko'),
    ];
    if (_isAdmin) {
      items.addAll([
        const _NavItem(icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2, label: 'Produk & Stok'),
        const _NavItem(icon: Icons.sync_outlined, selectedIcon: Icons.sync, label: 'Sinkronisasi'),
      ]);
    }
    if (_isManager) {
      items.add(const _NavItem(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'User'));
    }
    return items;
  }

  List<String> get _titles {
    final titles = <String>['Dashboard', 'Pesanan', 'Toko'];
    if (_isAdmin) {
      titles.addAll(['Produk & Stok', 'Sinkronisasi']);
    }
    if (_isManager) titles.add('User');
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _adminProvider.loadAll();
      _adminProvider.startAutoRefresh();
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
    _adminProvider.stopAutoRefresh();
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
  }

  Widget _buildBody() {
    final items = _navItems;
    final i = _selectedIndex.clamp(0, items.length - 1);

    if (_isManager) {
      // MANAGER: Dashboard, Pesanan (read-only), Toko, User
      switch (i) {
        case 0:
          return const StatsTab();
        case 1:
          return const OrdersTab(readOnly: true);
        case 2:
          return const CustomersTab();
        case 3:
          return const UsersTab();
      }
    }
    // ADMIN: Dashboard, Pesanan, Toko, Produk & Stok, Sinkronisasi
    switch (i) {
      case 0:
        return const StatsTab();
      case 1:
        return const OrdersTab();
      case 2:
        return const CustomersTab();
      case 3:
        return const ProductsTab();
      case 4:
        return const SyncTab();
    }
    return const StatsTab();
  }

  @override
  Widget build(BuildContext context) {
    // Listener (translucent) di paling luar: setiap pointer event di dashboard
    // dianggap aktivitas user. Tanpa throttle — Timer._checkIdle sudah jalan
    // setiap 30 detik, jadi tidak perlu debounce di sisi Listener.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordActivity(),
      onPointerMove: (event) {
        // Track drag, tapi jangan spam pada hover biasa.
        if (event.buttons != 0) _recordActivity();
      },
      onPointerSignal: (_) => _recordActivity(), // wheel/trackpad
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            color: AppColors.sidebarBg,
            child: Column(
              children: [
                // Sidebar header
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
                        child: const Icon(Icons.local_shipping, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
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
                              'Admin Panel',
                              style: TextStyle(
                                color: Colors.white70,
                                fontFamily: AppTextStyles.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
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
                  child: Consumer<AdminProvider>(
                    builder: (context, provider, _) => ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _navItems.length,
                    itemBuilder: (context, i) {
                      final item = _navItems[i];
                      final selected = _selectedIndex == i;
                      final showBadge = i == 1 && provider.hasNewPending;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _onNavTap(i),
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
                                    color: selected ? Colors.white : Colors.white60,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: TextStyle(
                                        color: selected ? Colors.white : Colors.white70,
                                        fontFamily: AppTextStyles.fontFamily,
                                        fontWeight:
                                            selected ? FontWeight.w700 : FontWeight.w500,
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
                            final display = widget.nama.isNotEmpty
                                ? widget.nama
                                : widget.username;
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
                              final display = widget.nama.isNotEmpty
                                  ? widget.nama
                                  : widget.username;
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
                              widget.role == 'MANAGER' ? 'Manager' : 'Administrator',
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
                        icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
                        tooltip: 'Keluar',
                        onPressed: () async {
                          await AuthStorage().clearTokens();
                          if (!mounted) return;
                          _pushLogin();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: const Border(
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _titles[_selectedIndex],
                        style: AppTextStyles.headlineMedium,
                      ),
                      if (widget.role == 'MANAGER' &&
                          _selectedIndex < _navItems.length &&
                          _navItems[_selectedIndex].label == 'Pesanan')
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh',
                        color: AppColors.textSecondary,
                        onPressed: () {
                          context.read<AdminProvider>().loadAll();
                        },
                      ),
                    ],
                  ),
                ),
                // Page body
                Expanded(child: _buildBody()),
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
