import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system.dart';
import '../../providers/order_provider.dart';
import '../../providers/draft_order_provider.dart';
import '../../../data/models/order.dart';
import '../order_flow/order_flow_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final order = await context.read<OrderProvider>().getOrderDetail(widget.orderId);
    if (!mounted) return;
    setState(() {
      _order = order;
      _loading = false;
      _error = order == null
          ? context.read<OrderProvider>().errorMessage ?? 'Gagal memuat'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Order')),
      body: _loading
          ? const _OrderDetailSkeleton()
          : _order == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error ?? 'Order tidak ditemukan'),
                  ),
                )
              : _OrderDetailContent(order: _order!),
    );
  }
}

class _OrderDetailSkeleton extends StatefulWidget {
  const _OrderDetailSkeleton();

  @override
  State<_OrderDetailSkeleton> createState() => _OrderDetailSkeletonState();
}

class _OrderDetailSkeletonState extends State<_OrderDetailSkeleton>
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
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: _animation.value),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: _animation.value),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: _animation.value),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: _animation.value),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrderDetailContent extends StatelessWidget {
  final Order order;
  const _OrderDetailContent({required this.order});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _statusBgColor(order.status),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(_statusIcon(order.status), color: _statusFgColor(order.status)),
              const SizedBox(width: 8),
              Text(
                'Status: ${order.statusLabel}',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _statusFgColor(order.status),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Tanggal: ${dateFmt.format(order.createdAt.toLocal())}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 20),

        // Toko
        _sectionTitle('Toko'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.store_outlined, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.customerName ?? order.storeName ?? '—',
                      style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (order.storeAddress != null && order.storeAddress!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.storeAddress!,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Produk
        _sectionTitle('Produk (${order.totalQty})'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              for (var i = 0; i < (order.items?.length ?? 0); i++) ...[
                if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.items![i].namaBarang ?? order.items![i].productId,
                              style: AppTextStyles.bodyMedium,
                            ),
                            if (order.items![i].hasDiscount)
                              Text(
                                order.items![i].discountType == 'NOMINAL'
                                    ? 'Diskon Rp ${order.items![i].discountNominal}'
                                    : 'Diskon ${order.items![i].discountPercent}%',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.success,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text('× ${order.items![i].qty}',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(width: 12),
                      if (order.items![i].discountPercent > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currency.format(
                                  (order.items![i].hargaSatuan ?? 0) * order.items![i].qty),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            Text(
                              currency.format(order.items![i].subtotal),
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          currency.format(order.items![i].subtotal),
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Total
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: AppTextStyles.bodyLarge),
              Text(
                currency.format(order.totalPrice),
                style: AppTextStyles.headlineSmall.copyWith(color: AppColors.primaryLight),
              ),
            ],
          ),
        ),

        // Catatan
        if ((order.notes ?? '').isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle('Catatan'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Text(order.notes!, style: AppTextStyles.bodyMedium),
          ),
        ],

        const SizedBox(height: 24),

        // Actions
        if (order.canEdit)
          OutlinedButton.icon(
            onPressed: () {
              final items = <String, int>{};
              final discounts = <String, DiscountInfo>{};
              if (order.items != null) {
                for (final item in order.items!) {
                  items[item.productId] = item.qty;
                  if (item.discountType == 'NOMINAL' && item.discountNominal > 0) {
                    discounts[item.productId] = DiscountInfo.nominal(item.discountNominal);
                  } else if (item.discountPercent > 0) {
                    discounts[item.productId] = DiscountInfo.percent(item.discountPercent);
                  }
                }
              }
              context.read<DraftOrderProvider>().loadFromExisting(
                orderId: order.id,
                customerId: order.customerId ?? '',
                customerName: order.customerName ?? order.storeName ?? '',
                customerAddress: order.storeAddress,
                existingItems: items,
                existingDiscounts: discounts,
                existingNotes: order.notes ?? '',
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const OrderFlowScreen(),
                  fullscreenDialog: true,
                ),
              );
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit Draft'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          ),
      ],
    );
  }

  Widget _sectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'DRAFT': return AppColors.warningBg;
      case 'PENDING': return AppColors.infoBg;
      case 'APPROVED': return AppColors.successBg;
      case 'CANCELLED':
      case 'REJECTED': return AppColors.errorBg;
      default: return AppColors.borderLight;
    }
  }

  Color _statusFgColor(String status) {
    switch (status) {
      case 'DRAFT': return AppColors.warning;
      case 'PENDING': return AppColors.info;
      case 'APPROVED': return AppColors.success;
      case 'CANCELLED':
      case 'REJECTED': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'DRAFT': return Icons.edit_note;
      case 'PENDING': return Icons.hourglass_top;
      case 'APPROVED': return Icons.check_circle;
      case 'CANCELLED':
      case 'REJECTED': return Icons.cancel;
      default: return Icons.info_outline;
    }
  }
}
