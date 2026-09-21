import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../products/product_catalog_screen.dart';
import '../cart/cart_screen.dart';
import '../orders/order_history_screen.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const <Widget>[
    ProductCatalogScreen(key: Key('catalog')),
    CartScreen(key: Key('cart')),
    OrderHistoryScreen(key: Key('orders')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cart, _) {
          return NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Katalog',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: cart.totalItems > 0,
                  label: Text(
                    '${cart.totalItems}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: AppColors.primaryLight,
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: cart.totalItems > 0,
                  label: Text(
                    '${cart.totalItems}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: AppColors.primaryLight,
                  child: const Icon(Icons.shopping_cart),
                ),
                label: 'Keranjang',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Pesanan',
              ),
            ],
          );
        },
      ),
    );
  }

  final _titles = const ['Katalog Produk', 'Keranjang', 'Riwayat Pesanan'];

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, size: 32, color: AppColors.info),
              ),
              const SizedBox(height: 16),
              const Text('Konfirmasi Keluar', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Apakah Anda yakin ingin keluar dari aplikasi?',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await context.read<AuthProvider>().logout();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        } 
                      },
                      child: const Text('Keluar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
