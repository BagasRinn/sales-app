import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system.dart';
import '../../../core/design_system/widgets/app_components.dart';
import '../../providers/order_provider.dart';
import '../../providers/home_stats_provider.dart';
import '../../providers/draft_order_provider.dart';
import 'home_screen.dart';
import '../orders/order_list_screen.dart';
import '../products/product_catalog_screen.dart';
import '../misc/misc_screen.dart';
import '../order_flow/order_flow_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    context.read<HomeStatsProvider>().load();
    context.read<OrderProvider>().loadOrders();
    context.read<OrderProvider>().loadRecentOrders();
  }

  void _openOrderFlow() {
    context.read<DraftOrderProvider>().reset();
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const OrderFlowScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveShell(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        setState(() => _currentIndex = index);
      },
      destinations: const [
        AppNavigationItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: 'Beranda',
        ),
        AppNavigationItem(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'Pesanan',
        ),
        AppNavigationItem(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: 'Katalog',
        ),
        AppNavigationItem(
          icon: Icons.more_horiz,
          selectedIcon: Icons.more_horiz,
          label: 'Lainnya',
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openOrderFlow,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Order Baru'),
      ),
      child: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          OrderListScreen(),
          ProductCatalogScreen(),
          MiscScreen(),
        ],
      ),
    );
  }
}
