import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system.dart';
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
  final dynamic order;

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
                  if (order.orderType != null)
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
                    )
                  else
                    const SizedBox(),
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

// Order Detail Screen
class OrderDetailScreen extends StatelessWidget {
  final dynamic order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final idr = NumberFormat('#,###', 'id');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          order.storeName,
                          style: AppTextStyles.headlineMedium,
                        ),
                        const Spacer(),
                        OrderStatusChip(status: order.status),
                      ],
                    ),
                    if (order.storeAddress != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        order.storeAddress,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items
            Text(
              'Item Pesanan',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: 12),
            ...order.items.map<Widget>((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.namaBarang ?? 'Produk',
                              style: AppTextStyles.labelLarge,
                            ),
                            Text(
                              '${item.qty}x Rp ${idr.format(item.hargaSatuan)}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rp ${idr.format(item.subtotal)}',
                        style: AppTextStyles.labelLarge,
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Notes
            if (order.notes != null && order.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Catatan',
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(order.notes, style: AppTextStyles.bodyMedium),
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Total
            Card(
              color: AppColors.borderLight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order.totalQty} item',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (order.totalDiscount > 0)
                          Text(
                            '- Rp ${idr.format(order.totalDiscount)}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      'Rp ${idr.format(order.totalPrice)}',
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final status = order.status.toUpperCase();
    final isPending = status == 'PENDING';
    final isDraft = status == 'DRAFT';

    if (!isPending && !isDraft) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isPending) ...[
          OutlinedButton.icon(
            onPressed: () => _confirmCancel(context),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Batalkan Pesanan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _editOrder(context),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Pesanan'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
        if (isDraft) ...[
          OutlinedButton.icon(
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus Draft'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _editOrder(context),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Draft'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ],
    );
  }

  void _editOrder(BuildContext context) {
    context.read<DraftOrderProvider>().loadFromExisting(order);
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => OrderFlowScreen(existingOrder: order),
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pesanan?'),
        content: const Text('Pesanan ini akan dibatalkan dan tidak bisa dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cancelOrder(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(BuildContext context) async {
    final provider = context.read<OrderProvider>();
    final success = await provider.cancelOrder(order.id);
    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Pesanan dibatalkan'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gagal membatalkan pesanan'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Draft?'),
        content: const Text('Draft ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteOrder(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOrder(BuildContext context) async {
    final provider = context.read<OrderProvider>();
    final success = await provider.deleteOrder(order.id);
    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Draft dihapus'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gagal menghapus draft'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
