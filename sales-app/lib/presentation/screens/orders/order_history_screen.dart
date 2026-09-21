import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/design_system.dart';
import '../../../data/models/order.dart';
import '../../providers/order_provider.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadMyOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          color: AppColors.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusFilterChip(
                  label: 'Semua',
                  status: null,
                  selected: _selectedStatus == null,
                  onSelected: () => _filter(null),
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Menunggu',
                  status: 'PENDING',
                  selected: _selectedStatus == 'PENDING',
                  onSelected: () => _filter('PENDING'),
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Disetujui',
                  status: 'APPROVED',
                  selected: _selectedStatus == 'APPROVED',
                  onSelected: () => _filter('APPROVED'),
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Ditolak',
                  status: 'REJECTED',
                  selected: _selectedStatus == 'REJECTED',
                  onSelected: () => _filter('REJECTED'),
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Dibatalkan',
                  status: 'CANCELLED',
                  selected: _selectedStatus == 'CANCELLED',
                  onSelected: () => _filter('CANCELLED'),
                ),
              ],
            ),
          ),
        ),
        // Order list
        Expanded(
          child: Consumer<OrderProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading && provider.orders.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.errorMessage != null && provider.orders.isEmpty) {
                return _ErrorState(
                  message: provider.errorMessage!,
                  onRetry: () => provider.loadMyOrders(),
                );
              }

              if (provider.orders.isEmpty) {
                return _EmptyState();
              }

              return RefreshIndicator(
                onRefresh: () => provider.loadMyOrders(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: provider.orders.length,
                  itemBuilder: (context, index) {
                    return _OrderCard(order: provider.orders[index]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _filter(String? status) {
    setState(() => _selectedStatus = status);
    context.read<OrderProvider>().loadMyOrders(status: status);
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final String? status;
  final bool selected;
  final VoidCallback onSelected;

  const _StatusFilterChip({
    required this.label,
    required this.status,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final statusEnum = orderStatusFromString(status);
    final color = statusEnum != null ? orderStatusColor(statusEnum) : AppColors.primaryLight;

    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off, size: 40, color: AppColors.error),
            ),
            const SizedBox(height: 20),
            const Text('Gagal memuat pesanan', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: AppColors.textMuted.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Belum ada pesanan', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Pesanan Anda akan muncul di sini setelah checkout',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  _OrderCard({required this.order});

  final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'APPROVED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      case 'EXPIRED':
        return Icons.access_time;
      case 'CANCELLED':
        return Icons.block;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = orderStatusFromString(order.status);
    final statusColor = s != null ? orderStatusColor(s) : AppColors.textMuted;
    final statusBgColor = s != null ? orderStatusBgColor(s) : AppColors.border;
    final provider = context.read<OrderProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: order ID + status chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.id.toString().substring(0, 8).toUpperCase()}',
                        style: AppTextStyles.monoLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(order.createdAt),
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getStatusIcon(order.status), size: 14, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        order.statusLabel,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Expiry warning for pending
            if (order.status == 'PENDING' && order.expiredAt != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warningBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kedaluwarsa: ${dateFormat.format(order.expiredAt!)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Cancel button for pending
            if (order.canCancel) ...[
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                padding: const EdgeInsets.only(top: 14),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: provider.isSubmitting
                        ? null
                        : () => _handleCancel(context, provider),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Batalkan Pesanan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleCancel(BuildContext context, OrderProvider provider) async {
    final confirmed = await showDialog<bool>(
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
                  color: AppColors.warningBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 36, color: AppColors.warning),
              ),
              const SizedBox(height: 16),
              const Text('Batalkan Pesanan?', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Order #${order.id.toString().substring(0, 8).toUpperCase()} akan dibatalkan. Stok yang ditahan akan dikembalikan.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Tidak'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      child: const Text('Ya, Batalkan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    await provider.cancelOrder(order.id);
    if (context.mounted && provider.successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(provider.successMessage!),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
