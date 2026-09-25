import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system.dart';
import '../../providers/home_stats_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/draft_order_provider.dart';
import '../orders/order_list_screen.dart';
import '../orders/order_detail_screen.dart';
import '../products/product_catalog_screen.dart';
import '../misc/misc_screen.dart';
import '../order_flow/order_flow_screen.dart';
import '../../../data/models/order.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      _BerandaTab(onNavigateToTab: switchToTab),
      const OrderListScreen(key: Key('orders')),
      const ProductCatalogScreen(key: Key('catalog')),
      const MiscScreen(key: Key('misc')),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      // Pakai loadRecentOrders (bukan loadOrders) supaya "Orderan Terbaru"
      // selalu fresh tanpa terikat filter Pesanan.
      context.read<OrderProvider>().loadRecentOrders();
      if (_currentIndex == 1) {
        context.read<OrderProvider>().refreshOrders();
      }
    }
  }

  void switchToTab(int index) {
    if (index >= 0 && index < 4) {
      final wasOrders = _currentIndex == 1;
      setState(() => _currentIndex = index);
      if (index == 1 && !wasOrders) {
        // Saat masuk tab Pesanan, reset list dengan filter aktif (default null)
        // supaya tampilan fresh dan tidak mewarisi data append dari sesi sebelumnya.
        context.read<OrderProvider>().refreshOrders();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pesanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Katalog',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Lainnya',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'order_fab',
        onPressed: _openOrderFlow,
        icon: const Icon(Icons.add),
        label: const Text('Order Baru'),
        backgroundColor: AppColors.primaryLight,
      ),
    );
  }

  void _openOrderFlow() {
    context.read<DraftOrderProvider>().reset();
    context.read<ProductProvider>().clearFilters();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OrderFlowScreen(),
        fullscreenDialog: true,
      ),
    ).then((_) {
      if (mounted) {
        // Refresh khusus Orderan Terbaru + list Pesanan dengan filter aktifnya,
        // supaya order baru langsung muncul di kedua tempat tanpa append kotor.
        final orderProvider = context.read<OrderProvider>();
        orderProvider.loadRecentOrders();
        orderProvider.refreshOrders();
      }
    });
  }
}

class _BerandaTab extends StatefulWidget {
  final ValueChanged<int> onNavigateToTab;
  const _BerandaTab({required this.onNavigateToTab});

  @override
  State<_BerandaTab> createState() => _BerandaTabState();
}

class _BerandaTabState extends State<_BerandaTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeStatsProvider>().load();
      // Pakai loadRecentOrders agar Orderan Terbaru tidak terikat
      // dengan filter Pesanan. List Pesanan di-spawn terpisah di
      // OrderListScreen.initState.
      context.read<OrderProvider>().loadRecentOrders();
      context.read<ProductProvider>().loadProducts();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<HomeStatsProvider>().refresh(),
      context.read<OrderProvider>().loadRecentOrders(),
      context.read<ProductProvider>().loadProducts(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Halo, Sales'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _StatsCards(),
            const SizedBox(height: 24),
            _RecentOrdersSection(
              onNavigateToPesanan: () => widget.onNavigateToTab(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCards extends StatelessWidget {
  const _StatsCards();

  @override
  Widget build(BuildContext context) {
    final statsProvider = context.watch<HomeStatsProvider>();
    final stats = statsProvider.stats;
    final loading = statsProvider.isLoading;

    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    if (loading && stats == null) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: const [
          _SkeletonCard(),
          _SkeletonCard(),
          _SkeletonCard(),
        ],
      );
    }

    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _StatCard(
              label: 'Omset Hari Ini',
              value: currency.format(stats?.omsetHariIni ?? 0),
              icon: Icons.payments_outlined,
              color: AppColors.success,
            ),
            _StatCard(
              label: 'Pending',
              value: '${stats?.pendingCount ?? 0}',
              subtitle: 'menunggu admin',
              icon: Icons.hourglass_top_outlined,
              color: AppColors.info,
            ),
            _StatCard(
              label: 'Selesai (Bulan)',
              value: '${stats?.selesaiBulanIniCount ?? 0}',
              subtitle: 'order',
              extraText: currency.format(stats?.selesaiBulanIniTotal ?? 0),
              icon: Icons.check_circle_outline,
              color: AppColors.primary,
            ),
          ],
        ),
        if (statsProvider.errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gagal memuat statistik',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.read<HomeStatsProvider>().refresh(),
                  child: Text(
                    'Coba lagi',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final String? extraText;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.extraText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (extraText != null) ...[
            const SizedBox(height: 4),
            Text(
              extraText!,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.border.withValues(alpha: _animation.value),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.border.withValues(alpha: _animation.value),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: 100,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: _animation.value),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 60,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: _animation.value * 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentOrdersSection extends StatelessWidget {
  final VoidCallback onNavigateToPesanan;
  const _RecentOrdersSection({required this.onNavigateToPesanan});

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    // Pakai recentOrders (bukan orders) supaya filter Pesanan tidak
    // mencemari tampilan Orderan Terbaru.
    final orders = orderProvider.recentOrders;
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFmt = DateFormat('dd MMM, HH:mm', 'id_ID');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Orderan Terbaru', style: AppTextStyles.headlineSmall),
            TextButton(
              onPressed: onNavigateToPesanan,
              child: const Text('Lihat semua →'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (orders.isEmpty && !orderProvider.isLoadingRecent)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 40, color: AppColors.textMuted),
                  SizedBox(height: 8),
                  Text('Belum ada orderan', style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                for (var i = 0; i < orders.length && i < 5; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  _RecentOrderTile(
                    order: orders[i],
                    currency: currency,
                    dateFmt: dateFmt,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  final Order order;
  final NumberFormat currency;
  final DateFormat dateFmt;

  const _RecentOrderTile({
    required this.order,
    required this.currency,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: order.id),
          ),
        ).then((_) {
          if (context.mounted) {
            // Status order bisa berubah (mis. admin approve) selama halaman
            // detail terbuka, jadi refresh keduanya saat kembali.
            context.read<OrderProvider>().loadRecentOrders();
            context.read<OrderProvider>().refreshOrders();
          }
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName ?? order.storeName ?? '—',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${currency.format(order.totalPrice)} · ${dateFmt.format(order.createdAt.toLocal())}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(status: order.status, label: order.statusLabel),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final String label;

  const _StatusChip({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'DRAFT':
        bg = AppColors.warningBg;
        fg = AppColors.warning;
        break;
      case 'PENDING':
        bg = AppColors.infoBg;
        fg = AppColors.info;
        break;
      case 'APPROVED':
        bg = AppColors.successBg;
        fg = AppColors.success;
        break;
      case 'CANCELLED':
      case 'REJECTED':
        bg = AppColors.errorBg;
        fg = AppColors.error;
        break;
      default:
        bg = AppColors.borderLight;
        fg = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
