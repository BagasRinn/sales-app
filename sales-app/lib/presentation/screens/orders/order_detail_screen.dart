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

  /// Format ringkasan diskon 3 layer untuk 1 item.
  /// Contoh: "Diskon 1: 10% · Diskon 2: Rp 2.000 · Diskon 3: 5%"
  String _formatItemDiscounts(OrderItem item) {
    final parts = <String>[];
    for (var i = 1; i <= 3; i++) {
      String type;
      int percent;
      int nominal;
      switch (i) {
        case 1:
          type = item.discountType;
          percent = item.discountPercent;
          nominal = item.discountNominal;
          break;
        case 2:
          type = item.discount2Type;
          percent = item.discount2Percent;
          nominal = item.discount2Nominal;
          break;
        case 3:
          type = item.discount3Type;
          percent = item.discount3Percent;
          nominal = item.discount3Nominal;
          break;
        default:
          continue;
      }
      if (type == 'NOMINAL' && nominal > 0) {
        parts.add('Diskon $i: Rp $nominal');
      } else if (type == 'PERCENT' && percent > 0) {
        parts.add('Diskon $i: $percent%');
      }
    }
    return parts.join(' · ');
  }

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
          child: Row(
            children: [
              Text(
                'Tanggal: ${dateFmt.format(order.createdAt.toLocal())}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              _OrderTypeChip(orderType: order.orderType),
            ],
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
                                _formatItemDiscounts(order.items![i]),
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
            onPressed: () => _enterEditFlow(context, order),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(order.isPending ? 'Edit Order' : 'Edit Draft'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          ),
        if (order.canDelete) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => order.isPending
                ? _confirmAndCancel(context, order)
                : _confirmAndDelete(context, order),
            icon: Icon(
              order.isPending ? Icons.cancel_outlined : Icons.delete_outline,
              size: 18,
              color: AppColors.error,
            ),
            label: Text(
              order.isPending ? 'Batalkan Order' : 'Hapus Order',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ],
      ],
    );
  }

  void _enterEditFlow(BuildContext context, Order order) {
    // Convert OrderItem rows → List<OrderLine> for DraftOrderProvider.
    final lines = <OrderLine>[];
    int idx = 0;
    if (order.items != null) {
      for (final item in order.items!) {
        lines.add(OrderLine(
          id: 'rehydrated_${idx++}',
          productId: item.productId,
          qty: item.qty,
          discount: ItemDiscount.fromOrderItem(item),
        ));
      }
    }
    context.read<DraftOrderProvider>().loadFromExisting(
          orderId: order.id,
          customerId: order.customerId ?? '',
          customerName: order.customerName ?? order.storeName ?? '',
          customerAddress: order.storeAddress,
          existingLines: lines,
          existingNotes: order.notes ?? '',
          existingStatus: order.status,
          existingOrderType: order.orderType,
        );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OrderFlowScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Draft?'),
        content: const Text('Order ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final orderProvider = context.read<OrderProvider>();
    final success = await orderProvider.deleteOrder(order.id);
    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft dihapus'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orderProvider.errorMessage ?? 'Gagal menghapus'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirmAndCancel(BuildContext context, Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batalkan Order?'),
        content: const Text(
          'Order ini akan dibatalkan dan stok booking akan dilepas. '
          'Order yang dibatalkan tidak bisa di-edit lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final orderProvider = context.read<OrderProvider>();
    final success = await orderProvider.cancelOrder(order.id);
    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order dibatalkan'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orderProvider.errorMessage ?? 'Gagal membatalkan'),
          backgroundColor: AppColors.error,
        ),
      );
    }
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

class _OrderTypeChip extends StatelessWidget {
  final String orderType;
  const _OrderTypeChip({required this.orderType});

  @override
  Widget build(BuildContext context) {
    final is4P = orderType == '4P';
    final color = is4P ? AppColors.warning : AppColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        orderType,
        style: AppTextStyles.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}
