import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/branch.dart';
import '../../../core/design_system.dart';
import '../../../core/datetime_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_stats_provider.dart';
import '../../providers/order_provider.dart';
import '../orders/order_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final stats = context.watch<HomeStatsProvider>();
    final orders = context.watch<OrderProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await stats.refresh();
            await orders.loadRecentOrders();
          },
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          (auth.nama ?? auth.username ?? 'S')[0].toUpperCase(),
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.textOnPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Halo, ${auth.nama ?? auth.username ?? 'Sales'}',
                              style: AppTextStyles.headlineMedium,
                            ),
                            if (auth.branchNama != null || auth.branch != null)
                              Text(
                                auth.branchNama ?? BranchLabel.display(auth.branch) ?? '',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primaryLight,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Stats Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildStatsSection(stats),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Order Terbaru
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order Terbaru', style: AppTextStyles.headlineSmall),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Lihat Semua'),
                      ),
                    ],
                  ),
                ),
              ),

              // Recent Orders List
              if (orders.isLoading && orders.recentOrders.isEmpty)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              else if (orders.recentOrders.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'Belum ada order',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final order = orders.recentOrders[index];
                        return _buildOrderCard(context, order);
                      },
                      childCount: orders.recentOrders.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(HomeStatsProvider stats) {
    if (stats.isLoading && stats.stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final s = stats.stats;
    final idr = NumberFormat('#,###', 'id');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Omset Hari Ini',
                value: s != null ? 'Rp ${idr.format(s.omsetHariIni)}' : '-',
                icon: Icons.payments_outlined,
                color: AppColors.success,
                bgColor: AppColors.successBg,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Menunggu',
                value: s != null ? '${s.pendingCount}' : '-',
                icon: Icons.hourglass_empty,
                color: AppColors.info,
                bgColor: AppColors.infoBg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Target Bulanan',
                value: s?.targetValue != null
                    ? '${idr.format(s!.selesaiBulanIniTotal)} / ${idr.format(s.targetValue)}'
                    : '-',
                subtitle: s?.targetValue != null
                    ? (s!.targetType == 'ORDER_COUNT' ? 'order' : 'revenue')
                    : null,
                extra: s?.incentiveAmount != null && s!.incentiveAmount! > 0
                    ? '+ Rp ${idr.format(s.incentiveAmount)}'
                    : null,
                icon: Icons.track_changes_outlined,
                color: AppColors.info,
                bgColor: AppColors.infoBg,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Selesai Bulan Ini',
                value: s != null ? '${s.selesaiBulanIniCount}' : '-',
                subtitle: s != null
                    ? 'Rp ${idr.format(s.selesaiBulanIniTotal)}'
                    : null,
                icon: Icons.check_circle_outline,
                color: AppColors.success,
                bgColor: AppColors.successBg,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderCard(BuildContext context, dynamic order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(order: order),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.storeName,
                      style: AppTextStyles.labelLarge,
                    ),
                  ),
                  OrderStatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                witaFormat(order.createdAt, pattern: 'dd MMM yyyy, HH:mm'),
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${order.totalQty} item',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Rp ${NumberFormat('#,###', 'id').format(order.totalPrice)}',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.textPrimary,
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String? extra;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
    this.extra,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(color: color),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppTextStyles.bodySmall),
          ],
          if (extra != null) ...[
            const SizedBox(height: 4),
            Text(
              extra!,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
