import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system.dart';
import '../../../core/design_system/widgets/app_components.dart';
import '../../providers/order_provider.dart';
import '../../../data/models/order.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen>
    with WidgetsBindingObserver {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const _statusFilters = [
    _StatusFilter(label: 'Semua', status: null),
    _StatusFilter(label: 'Draft', status: 'DRAFT'),
    _StatusFilter(label: 'Menunggu', status: 'PENDING'),
    _StatusFilter(label: 'Disetujui', status: 'APPROVED'),
    _StatusFilter(label: 'Ditolak', status: 'REJECTED'),
  ];

  int _selectedFilterIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      // Pakai reset:true (bukan false) supaya list replace, bukan append.
      _refreshOrders(reset: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refreshOrders({bool reset = true}) {
    context.read<OrderProvider>().loadOrders(
      status: _statusFilters[_selectedFilterIndex].status,
      reset: reset,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<OrderProvider>().loadMoreOrders();
    }
  }

  Future<void> _refresh() async {
    context.read<OrderProvider>().loadOrders(
      status: _statusFilters[_selectedFilterIndex].status,
    );
  }

  void _selectFilter(int index) {
    setState(() => _selectedFilterIndex = index);
    context.read<OrderProvider>().loadOrders(
      status: _statusFilters[index].status,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nomor/order/toko...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.cardSurface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = '';
                          context.read<OrderProvider>().loadOrders(
                            status: _statusFilters[_selectedFilterIndex].status,
                            search: '',
                          );
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                _searchQuery = v;
                context.read<OrderProvider>().loadOrders(
                  status: _statusFilters[_selectedFilterIndex].status,
                  search: v,
                );
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _statusFilters[i];
                final selected = i == _selectedFilterIndex;
                return AppChoiceChip(
                  label: f.label,
                  selected: selected,
                  onSelected: () => _selectFilter(i),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    final orderProvider = context.watch<OrderProvider>();
    final orders = orderProvider.orders;
    final errorMessage = orderProvider.errorMessage;

    if (errorMessage != null && orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                'Gagal memuat pesanan',
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                errorMessage,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _refreshOrders(reset: true),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (orderProvider.isLoading && orders.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: 8,
        itemBuilder: (context, index) => const _OrderSkeletonTile(),
      );
    }

    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inbox_outlined,
                size: 64,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Tidak ditemukan'
                    : 'Belum ada pesanan',
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Coba kata kunci lain'
                    : 'Buat order pertama kamu dari tombol di bawah',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        itemCount: orders.length + (orderProvider.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i >= orders.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: _LoadingMoreSkeleton(),
            );
          }
          return _OrderTile(order: orders[i]);
        },
      ),
    );
  }

}

class _StatusFilter {
  final String label;
  final String? status;
  const _StatusFilter({required this.label, required this.status});
}

class _OrderTile extends StatelessWidget {
  final Order order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFmt = DateFormat('dd MMM, HH:mm', 'id_ID');

    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(orderId: order.id),
                ),
              )
              .then((_) {
                // Refresh setelah kembali dari detail — status order bisa
                // berubah (admin approve/reject) selama halaman detail terbuka.
                // refreshOrders() re-fetch dengan filter aktif saat ini (reset:true).
                if (context.mounted) {
                  context.read<OrderProvider>().refreshOrders();
                }
              });
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName ?? order.storeName ?? '—',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.totalQty} item · ${currency.format(order.totalPrice)} · ${dateFmt.format(order.createdAt)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OrderStatusChip(status: order.status, label: order.statusLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderSkeletonTile extends StatefulWidget {
  const _OrderSkeletonTile();

  @override
  State<_OrderSkeletonTile> createState() => _OrderSkeletonTileState();
}

class _OrderSkeletonTileState extends State<_OrderSkeletonTile>
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
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.6,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(
                          alpha: _animation.value,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 200,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(
                          alpha: _animation.value * 0.7,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: _animation.value),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoadingMoreSkeleton extends StatefulWidget {
  const _LoadingMoreSkeleton();

  @override
  State<_LoadingMoreSkeleton> createState() => _LoadingMoreSkeletonState();
}

class _LoadingMoreSkeletonState extends State<_LoadingMoreSkeleton>
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
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.6,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: _animation.value),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 100,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: _animation.value),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        );
      },
    );
  }
}
