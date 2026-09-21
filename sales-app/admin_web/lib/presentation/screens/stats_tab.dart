import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/design_system.dart';
import '../providers/admin_provider.dart';

String _fmt(int amount) =>
    NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(amount);

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<AdminProvider>().stats;
    final pending = context.watch<AdminProvider>().pendingOrders;

    final totalOrders = stats['total_orders'] ?? 0;
    final pendingOrders = stats['pending_orders'] ?? 0;
    final approvedOrders = stats['approved_orders'] ?? 0;
    final rejectedOrders = stats['rejected_orders'] ?? 0;
    final totalProducts = stats['total_products'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ringkasan Sistem', style: AppTextStyles.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Pantau performa order dan status stok secara keseluruhan',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                title: 'Total Pesanan',
                value: '$totalOrders',
                icon: Icons.shopping_cart,
                color: AppColors.info,
              ),
              _StatCard(
                title: 'Menunggu Persetujuan',
                value: '$pendingOrders',
                icon: Icons.pending_actions,
                color: AppColors.warning,
              ),
              _StatCard(
                title: 'Disetujui',
                value: '$approvedOrders',
                icon: Icons.check_circle,
                color: AppColors.success,
              ),
              _StatCard(
                title: 'Ditolak',
                value: '$rejectedOrders',
                icon: Icons.cancel,
                color: AppColors.error,
              ),
              _StatCard(
                title: 'Total Produk',
                value: '$totalProducts',
                icon: Icons.inventory_2,
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              const Text('Pesanan Perlu Tindakan', style: AppTextStyles.headlineLarge),
              const SizedBox(width: 12),
              if (pending.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.warningBorder),
                  ),
                  child: Text(
                    '${pending.length}',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (pending.isNotEmpty)
            ...pending.take(5).map((order) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.store,
                                color: AppColors.warning, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.storeName ?? 'Toko Tidak Diketahui',
                                  style: AppTextStyles.labelLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Order #${order.id.substring(0, 8)} • ${order.items.length} item • Rp ${_fmt(order.totalAmount)}',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: AppColors.warningBorder),
                            ),
                            child: const Text(
                              'Menunggu',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ))
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle,
                          color: AppColors.success, size: 32),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Semua pesanan sudah diproses',
                            style: AppTextStyles.headlineSmall),
                        const SizedBox(height: 4),
                        const Text(
                          'Tidak ada pesanan yang menunggu persetujuan',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
