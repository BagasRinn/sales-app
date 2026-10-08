import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Pesanan Saya'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
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
            color: Colors.white,
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
                fillColor: const Color(0xFFF4F7FB),
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
            color: Colors.white,
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
                      selectedColor: const Color(0xFFEFF6FF),
                      checkmarkColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF64748B),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
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
                    ? const Center(
                        child: Text(
                          'Belum ada pesanan',
                          style: TextStyle(color: Color(0xFF94A3B8)),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.customerName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(order.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(order.createdAt.toLocal()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${order.totalQty} item',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
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
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.orderType,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    )
                  else
                    const SizedBox(),
                  Text(
                    'Rp ${idr.format(order.totalPrice)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
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

  Widget _buildStatusChip(String status) {
    Color color;
    Color bg;
    String label;

    switch (status.toUpperCase()) {
      case 'PENDING':
        color = const Color(0xFF2563EB);
        bg = const Color(0xFFEFF6FF);
        label = 'Menunggu';
        break;
      case 'APPROVED':
        color = const Color(0xFF059669);
        bg = const Color(0xFFECFDF5);
        label = 'Disetujui';
        break;
      case 'REJECTED':
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFEF2F2);
        label = 'Ditolak';
        break;
      case 'CANCELLED':
        color = const Color(0xFF94A3B8);
        bg = const Color(0xFFF1F5F9);
        label = 'Dibatalkan';
        break;
      case 'DRAFT':
        color = const Color(0xFF94A3B8);
        bg = const Color(0xFFF1F5F9);
        label = 'Draft';
        break;
      default:
        color = const Color(0xFF94A3B8);
        bg = const Color(0xFFF1F5F9);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Order Detail Screen (simple version)
class OrderDetailScreen extends StatelessWidget {
  final dynamic order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final idr = NumberFormat('#,###', 'id');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
        backgroundColor: Colors.white,
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        _buildStatusChip(order.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (order.storeAddress != null)
                      Text(
                        order.storeAddress,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items
            const Text(
              'Item Pesanan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
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
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${item.qty}x Rp ${idr.format(item.hargaSatuan)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rp ${idr.format(item.subtotal)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Notes
            if (order.notes != null && order.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Catatan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(order.notes),
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Total
            Card(
              color: const Color(0xFFF8FAFC),
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
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                        if (order.totalDiscount > 0)
                          Text(
                            '- Rp ${idr.format(order.totalDiscount)}',
                            style: const TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      'Rp ${idr.format(order.totalPrice)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
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
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFDC2626)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _editOrder(context),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Pesanan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
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
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFDC2626)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _editOrder(context),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Draft'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
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
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
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
          const SnackBar(
            content: Text('Pesanan dibatalkan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membatalkan pesanan'),
            backgroundColor: Colors.red,
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
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
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
          const SnackBar(
            content: Text('Draft dihapus'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menghapus draft'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    Color bg;
    String label;

    switch (status.toUpperCase()) {
      case 'PENDING':
        color = const Color(0xFF2563EB);
        bg = const Color(0xFFEFF6FF);
        label = 'Menunggu';
        break;
      case 'APPROVED':
        color = const Color(0xFF059669);
        bg = const Color(0xFFECFDF5);
        label = 'Disetujui';
        break;
      case 'REJECTED':
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFEF2F2);
        label = 'Ditolak';
        break;
      case 'CANCELLED':
        color = const Color(0xFF94A3B8);
        bg = const Color(0xFFF1F5F9);
        label = 'Dibatalkan';
        break;
      case 'DRAFT':
        color = const Color(0xFF94A3B8);
        bg = const Color(0xFFF1F5F9);
        label = 'Draft';
        break;
      default:
        color = const Color(0xFF94A3B8);
        bg = const Color(0xFFF1F5F9);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
