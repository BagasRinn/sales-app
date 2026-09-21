import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_storage.dart';
import '../../core/design_system.dart';
import '../../core/jwt_utils.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/api_service.dart';
import '../providers/admin_provider.dart';
import 'login_screen.dart';
import 'orders_tab.dart';
import 'products_tab.dart';
import 'sync_tab.dart';
import 'stats_tab.dart';

class DashboardScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;
  final String username;

  const DashboardScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
    required this.username,
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
      create: (_) => AdminProvider(_repo)..loadAll(),
      child: _DashboardContent(username: widget.username, apiService: _apiService),
    );
  }
}

class _DashboardContent extends StatefulWidget {
  final String username;
  final ApiService apiService;

  const _DashboardContent({required this.username, required this.apiService});

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  int _selectedIndex = 0;
  late final AdminProvider _adminProvider;
  late final ApiService _apiService;

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard'),
    _NavItem(icon: Icons.assignment_outlined, selectedIcon: Icons.assignment, label: 'Pesanan'),
    _NavItem(icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2, label: 'Produk & Stok'),
    _NavItem(icon: Icons.sync_outlined, selectedIcon: Icons.sync, label: 'Sinkronisasi'),
  ];

  static const _titles = ['Dashboard', 'Pesanan', 'Produk & Stok', 'Sinkronisasi'];

  @override
  void initState() {
    super.initState();
    _adminProvider = context.read<AdminProvider>();
    _apiService = widget.apiService;

    // Register 401 callback — redirects to login
    _apiService.setOnUnauthorized(() async {
      await AuthStorage().clearTokens();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });

    // Check token expiry on startup — redirect to login if expired
    if (JwtUtils.isExpired(_apiService.accessToken)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await AuthStorage().clearTokens();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      });
      return;
    }

    // Start auto-refresh every 30 seconds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adminProvider.startAutoRefresh();
    });
  }

  @override
  void dispose() {
    _adminProvider.stopAutoRefresh();
    super.dispose();
  }

  void _onNavTap(int i) {
    if (_selectedIndex == 1 && i != 1) {
      // Clear badge when leaving orders tab
      context.read<AdminProvider>().clearNewPendingBadge();
    }
    setState(() => _selectedIndex = i);
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const StatsTab();
      case 1:
        return const OrdersTab();
      case 2:
        return const ProductsTab();
      case 3:
        return const SyncTab();
      default:
        return const StatsTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          child: Text(
                            widget.username.isNotEmpty
                                ? widget.username[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: AppTextStyles.fontFamily,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Administrator',
                              style: TextStyle(
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
                          final nav = Navigator.of(context);
                          await AuthStorage().clearTokens();
                          if (!mounted) return;
                          nav.pushReplacement(
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                          );
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
