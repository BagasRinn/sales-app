import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/design_system.dart';
import '../providers/admin_provider.dart';
import '../../data/models/order.dart';

String _fmt(int amount) =>
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);

class OrdersTab extends StatefulWidget {
  /// Kalau true, sembunyikan tombol Approve/Reject (untuk MANAGER).
  final bool readOnly;
  const OrdersTab({super.key, this.readOnly = false});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final isLoading = provider.isLoading;

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primaryLight,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: AppTextStyles.labelLarge,
            indicatorColor: AppColors.primaryLight,
            indicatorWeight: 3,
            dividerColor: AppColors.border,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Menunggu Persetujuan'),
                    if (provider.pendingOrders.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${provider.pendingOrders.length}',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Semua Pesanan'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPendingOrders(provider, isLoading),
              _buildAllOrders(provider, isLoading),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingOrders(AdminProvider provider, bool isLoading) {
    final orders = provider.pendingOrders;

    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.check_circle, size: 48, color: AppColors.success),
            ),
            const SizedBox(height: 20),
            const Text('Tidak ada pesanan menunggu', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Semua pesanan sudah diproses',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: orders.length,
      itemBuilder: (ctx, i) => _OrderCard(
        order: orders[i],
        onApprove: widget.readOnly ? null : () => _approveOrder(orders[i].id),
        onReject: widget.readOnly ? null : () => _rejectOrder(orders[i].id),
      ),
    );
  }

  Widget _buildAllOrders(AdminProvider provider, bool isLoading) {
    final orders = provider.allOrders;

    if (isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Row(
            children: [
              const Text('Filter: ', style: AppTextStyles.labelLarge),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _filterStatus,
                    hint: const Text('Semua'),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Semua')),
                      DropdownMenuItem(value: 'PENDING', child: Text('Menunggu')),
                      DropdownMenuItem(value: 'APPROVED', child: Text('Disetujui')),
                      DropdownMenuItem(value: 'REJECTED', child: Text('Ditolak')),
                      DropdownMenuItem(value: 'CANCELLED', child: Text('Dibatalkan')),
                      DropdownMenuItem(value: 'EXPIRED', child: Text('Kedaluwarsa')),
                    ],
                    onChanged: (v) {
                      setState(() => _filterStatus = v);
                      provider.loadAllOrders(status: v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${orders.length} pesanan',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? const Center(
                  child: Text('Tidak ada pesanan', style: AppTextStyles.bodyMedium))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: orders.length,
                  itemBuilder: (ctx, i) => _OrderCard(order: orders[i]),
                ),
        ),
      ],
    );
  }

  Future<void> _approveOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.check_circle, size: 40, color: AppColors.success),
                ),
                const SizedBox(height: 20),
                const Text('Setujui Pesanan?', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Stok sistem akan dikurangi sesuai jumlah pesanan.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Setujui'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );

    if (confirm == true && mounted) {
      final provider = context.read<AdminProvider>();
      final success = await provider.approveOrder(orderId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Text('Pesanan disetujui'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Gagal menyetujui pesanan'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    final confirm = await showDialog<bool>(
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
                  color: AppColors.errorBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cancel, size: 40, color: AppColors.error),
              ),
              const SizedBox(height: 20),
              const Text('Tolak Pesanan?', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Stok booking akan dikembalikan, stok sistem tidak berubah.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      child: const Text('Tolak'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true && mounted) {
      final provider = context.read<AdminProvider>();
      final success = await provider.rejectOrder(orderId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cancel, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Text('Pesanan ditolak'),
              ],
            ),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Gagal menolak pesanan'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _OrderCard({required this.order, this.onApprove, this.onReject});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final s = orderStatusFromString(order.status);
    final statusColor = s != null ? orderStatusColor(s) : AppColors.textMuted;
    final statusBgColor = s != null ? orderStatusBgColor(s) : AppColors.border;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusBgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.store, color: statusColor, size: 22),
        ),
        title: Text(
          order.storeName ?? 'Toko Tidak Diketahui',
          style: AppTextStyles.labelLarge,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #${order.id.substring(0, 8)}',
                style: AppTextStyles.mono,
              ),
              if (order.salesUsername != null || order.salesNama != null)
                Text(
                  'Sales: ${order.salesDisplayName}',
                  style: AppTextStyles.bodySmall,
                ),
              const SizedBox(height: 2),
              Text(
                '${order.items.length} item • ${currencyFormat.format(order.totalAmount)} • ${dateFormat.format(order.createdAt)}',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrderStatusChip(status: order.status),
            if (order.status == 'PENDING' && onApprove != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: IconButton(
                  icon: const Icon(Icons.check_circle, color: AppColors.success),
                  tooltip: 'Setujui',
                  onPressed: onApprove,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.successBg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 36,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: AppColors.error),
                  tooltip: 'Tolak',
                  onPressed: onReject,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.errorBg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            const Icon(Icons.expand_more, color: AppColors.textMuted),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                // Info toko
                if (order.storeName != null ||
                    order.storeContact != null ||
                    order.storeAddress != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.infoBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.store,
                                size: 16, color: AppColors.info),
                            const SizedBox(width: 6),
                            Text(
                              'Info Toko',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.info,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (order.storeName != null &&
                            order.storeName!.isNotEmpty)
                          _infoRow(Icons.business, 'Nama Toko', order.storeName!),
                        if (order.storeContact != null &&
                            order.storeContact!.isNotEmpty)
                          _infoRow(Icons.phone, 'Kontak', order.storeContact!),
                        if (order.storeAddress != null &&
                            order.storeAddress!.isNotEmpty)
                          _infoRow(
                              Icons.location_on, 'Alamat', order.storeAddress!),
                        if (order.salesUsername != null || order.salesNama != null)
                          _infoRow(Icons.person, 'Sales', order.salesDisplayName),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Detail item
                const Text('Detail Item:',
                    style: AppTextStyles.labelLarge),
                const SizedBox(height: 10),
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.namaBarang.isNotEmpty
                                      ? item.namaBarang
                                      : 'Produk ${item.productId}',
                                  style: AppTextStyles.bodyMedium,
                                ),
                                if (item.discountPercent > 0)
                                  Text(
                                    'Diskon ${item.discountPercent}%',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.success,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${item.qty}x ${currencyFormat.format(item.hargaSatuan)}',
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(width: 16),
                          if (item.discountPercent > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  currencyFormat.format(
                                      item.hargaSatuan * item.qty),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textMuted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(item.subtotal),
                                  style: AppTextStyles.labelLarge.copyWith(
                                    fontSize: 13,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            )
                          else
                            SizedBox(
                              width: 90,
                              child: Text(
                                currencyFormat.format(item.subtotal),
                                textAlign: TextAlign.right,
                                style: AppTextStyles.labelLarge
                                    .copyWith(fontSize: 13),
                              ),
                            ),
                        ],
                      ),
                    )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: AppTextStyles.headlineSmall),
                    Text(
                      _fmt(order.totalAmount),
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),
                if (order.totalDiscount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Diskon',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                      Text(
                        '- ${_fmt(order.totalDiscount)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.info),
          const SizedBox(width: 6),
          SizedBox(
            width: 72,
            child: Text('$label:',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
