import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system.dart';
import '../../../data/models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/draft_order_provider.dart';
import '../order_flow/order_flow_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final _scrollController = ScrollController();
  String? _selectedFilter;
  final _searchController = TextEditingController();

  final _filters = ['Semua', 'DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<OrderProvider>().loadMoreOrders();
    }
  }

  String _getFilterStatus(String filter) {
    if (filter == 'Semua') return '';
    return filter;
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pesanan Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => orders.loadOrders(
              status: _selectedFilter == 'Semua' ? null : _selectedFilter,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari toko atau customer...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          orders.loadOrders(
                            status: _selectedFilter == 'Semua' ? null : _selectedFilter,
                          );
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
              onSubmitted: (value) {
                orders.loadOrders(
                  status: _selectedFilter == 'Semua' ? null : _selectedFilter,
                  search: value.isEmpty ? null : value,
                );
              },
            ),
          ),

          // Filter chips
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = (_selectedFilter ?? 'Semua') == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedFilter = filter);
                        orders.loadOrders(
                          status: _getFilterStatus(filter),
                        );
                      },
                      selectedColor: AppColors.infoBg,
                      checkmarkColor: AppColors.primaryLight,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.primaryLight
                            : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Order list
          Expanded(
            child: orders.isLoading && orders.orders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : orders.orders.isEmpty
                    ? Center(
                        child: Text(
                          'Belum ada pesanan',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => orders.loadOrders(
                          status: _selectedFilter == 'Semua'
                              ? null
                              : _selectedFilter,
                        ),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: orders.orders.length + (orders.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == orders.orders.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _OrderCard(order: orders.orders[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id');
    final idr = NumberFormat('#,###', 'id');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showOrderDetail(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.storeName,
                          style: AppTextStyles.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.customerName,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OrderStatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(order.createdAt.toLocal()),
                    style: AppTextStyles.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${order.totalQty} item',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.orderType,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    'Rp ${idr.format(order.totalPrice)}',
                    style: AppTextStyles.headlineMedium.copyWith(
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

  void _showOrderDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(order: order),
      ),
    );
  }
}

// ─── Order Detail Screen ──────────────────────────────────────────────────────

class OrderDetailScreen extends StatelessWidget {
  final Order order;

  const OrderDetailScreen({super.key, required this.order});

  String _formatDiscounts(OrderItem item) {
    final parts = <String>[];
    for (var i = 0; i < 3; i++) {
      final layer = i == 0
          ? item.discount.layer1
          : i == 1
              ? item.discount.layer2
              : item.discount.layer3;
      if (layer == null) continue;
      if (layer.type.name.toUpperCase() == 'NOMINAL') {
        parts.add('Diskon ${i + 1}: Rp ${layer.value}');
      } else {
        parts.add('Diskon ${i + 1}: ${layer.value}%');
      }
    }
    return parts.join(' · ');
  }

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING':
        return AppColors.info;
      case 'APPROVED':
        return AppColors.success;
      case 'CANCELLED':
      case 'REJECTED':
        return AppColors.error;
      case 'DRAFT':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }

  Color _statusBg(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING':
        return AppColors.infoBg;
      case 'APPROVED':
        return AppColors.successBg;
      case 'CANCELLED':
      case 'REJECTED':
        return AppColors.errorBg;
      case 'DRAFT':
        return AppColors.warningBg;
      default:
        return AppColors.borderLight;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING':
        return Icons.hourglass_top;
      case 'APPROVED':
        return Icons.check_circle;
      case 'CANCELLED':
      case 'REJECTED':
        return Icons.cancel;
      case 'DRAFT':
        return Icons.edit_note;
      default:
        return Icons.info_outline;
    }
  }

  String _statusLabel(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING':
        return 'Menunggu';
      case 'APPROVED':
        return 'Disetujui';
      case 'REJECTED':
        return 'Ditolak';
      case 'CANCELLED':
        return 'Dibatalkan';
      case 'DRAFT':
        return 'Draft';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Order'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _statusBg(order.status),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(order.status), color: _statusColor(order.status)),
                const SizedBox(width: 8),
                Text(
                  'Status: ${_statusLabel(order.status)}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _statusColor(order.status),
                  ),
                ),
              ],
            ),
          ),

          // Reject reason
          if (order.rejectReason != null && order.rejectReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alasan penolakan: ${order.rejectReason}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Date + order type
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  'Tanggal: ${dateFmt.format(order.createdAt)}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    order.orderType,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Toko section
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
                        order.customerName.isNotEmpty ? order.customerName : order.storeName,
                        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if (order.storeAddress != null && order.storeAddress!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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

          // Produk section
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
                for (var i = 0; i < order.items.length; i++) ...[
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
                                order.items[i].namaBarang ?? order.items[i].productId,
                                style: AppTextStyles.bodyMedium,
                              ),
                              if (order.items[i].hasDiscount) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _formatDiscounts(order.items[i]),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          '× ${order.items[i].qty}',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        if (order.items[i].hasDiscount)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                idr.format(order.items[i].hargaSatuan * order.items[i].qty),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textMuted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              Text(
                                idr.format(order.items[i].subtotal),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            idr.format(order.items[i].subtotal),
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Item dibatalkan
          if (order.cancelledItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Item Dibatalkan (${order.cancelledItems.length})'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < order.cancelledItems.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.cancel, size: 16, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.cancelledItems[i].displayLabel,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                if (order.cancelledItems[i].reason.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      order.cancelledItems[i].reason,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '× ${order.cancelledItems[i].qty}',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Total bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.totalQty} item',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    if (order.totalDiscount > 0)
                      Text(
                        '- ${idr.format(order.totalDiscount)}',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success),
                      ),
                  ],
                ),
                Text(
                  idr.format(order.totalPrice),
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

          // Action buttons
          _buildActionButtons(context),
        ],
      ),
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

  Widget _buildActionButtons(BuildContext context) {
    if (!order.canEdit && !order.canDelete) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (order.canEdit)
          OutlinedButton.icon(
            onPressed: () => _editOrder(context),
            icon: Icon(
              order.isPending ? Icons.edit_outlined : Icons.edit_note,
              size: 18,
            ),
            label: Text(order.isPending ? 'Edit Order' : 'Edit Draft'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          ),
        if (order.canDelete) ...[
          if (order.canEdit) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(order.isPending ? 'Batalkan Order' : 'Hapus Order'),
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

  void _editOrder(BuildContext context) async {
    final draft = context.read<DraftOrderProvider>();
    final orderProvider = context.read<OrderProvider>();

    // Always fetch fresh order detail from server before editing.
    // List endpoint may return minimal items (especially for PENDING).
    final fresh = await orderProvider.getOrderDetail(order.id);
    if (fresh == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengambil data order'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    draft.loadFromExisting(fresh);
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => OrderFlowScreen(existingOrder: fresh),
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(order.isPending ? 'Batalkan Order?' : 'Hapus Draft?'),
        content: Text(order.isPending
            ? 'Order ini akan dibatalkan dan stok booking akan dilepas. Order yang dibatalkan tidak bisa di-edit lagi.'
            : 'Draft ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              order.isPending ? _cancelOrder(context) : _deleteOrder(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(order.isPending ? 'Batalkan' : 'Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(BuildContext context) async {
    final provider = context.read<OrderProvider>();
    final success = await provider.cancelOrder(order.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Order dibatalkan' : 'Gagal membatalkan'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
      if (success) Navigator.pop(context);
    }
  }

  Future<void> _deleteOrder(BuildContext context) async {
    final provider = context.read<OrderProvider>();
    final success = await provider.deleteOrder(order.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Draft dihapus' : 'Gagal menghapus'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
      if (success) Navigator.pop(context);
    }
  }
}
