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

/// Quick presets + custom date range. Disimpan lokal di sini (bukan di
/// AdminProvider) supaya tidak tercampur dengan state global — ketika user
/// keluar dari tab ini, filter dianggap selesai dan direset.
enum _DatePreset { all, today, thisWeek, thisMonth, custom }

class _OrdersTabState extends State<OrdersTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _filterStatus;

  _DatePreset _datePreset = _DatePreset.all;
  DateTime? _customDateFrom;
  DateTime? _customDateTo;

  // Pagination state untuk tab Semua Pesanan.
  static const int _pageSize = 20;
  int _currentPage = 1; // 1-indexed

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Trigger explicit load untuk tab "Semua Pesanan" setelah frame pertama.
    // Sebelumnya data hanya datang dari DashboardScreen.initState yang
    // memanggil loadAll(). Kalau user navigasi ke tab ini sebelum
    // loadAll() selesai (atau kalau loadAll gagal), orders page kelihatan
    // kosong. Sekarang kita fetch independen — first frame dulu supaya
    // context siap, baru panggil _applyFilters.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyFilters();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  ({DateTime? from, DateTime? to}) _resolveDateRange() {
    final now = DateTime.now();
    switch (_datePreset) {
      case _DatePreset.all:
        return (from: null, to: null);
      case _DatePreset.today:
        final t = DateTime(now.year, now.month, now.day);
        return (from: t, to: t);
      case _DatePreset.thisWeek:
        // Week starts Monday
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: (now.weekday - 1)));
        return (from: start, to: now);
      case _DatePreset.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return (from: start, to: now);
      case _DatePreset.custom:
        return (from: _customDateFrom, to: _customDateTo);
    }
  }

  void _applyFilters({bool resetPage = true}) {
    final provider = context.read<AdminProvider>();
    final range = _resolveDateRange();
    if (resetPage) _currentPage = 1;
    provider.loadAllOrders(
      status: _filterStatus,
      dateFrom: range.from,
      dateTo: range.to,
      skip: (_currentPage - 1) * _pageSize,
      limit: _pageSize,
    );
  }

  void _goToPage(int page) {
    final provider = context.read<AdminProvider>();
    final totalPages = (provider.orderTotal / _pageSize).ceil().clamp(1, 1 << 30);
    if (page < 1 || page > totalPages) return;
    _currentPage = page;
    final range = _resolveDateRange();
    provider.loadAllOrders(
      status: _filterStatus,
      dateFrom: range.from,
      dateTo: range.to,
      skip: (_currentPage - 1) * _pageSize,
      limit: _pageSize,
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = (_customDateFrom != null && _customDateTo != null)
        ? DateTimeRange(start: _customDateFrom!, end: _customDateTo!)
        : DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: initial,
      helpText: 'Pilih rentang tanggal',
      // Wrap dengan Theme + ConstrainedBox untuk:
      // 1. Lebar & tinggi dibatasi (Material 3 side-by-side 2 bulan ≈ 600px)
      // 2. Rounded corner 20px, konsisten dengan AlertDialog project ini
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              constraints: const BoxConstraints(
                maxWidth: 620,
                maxHeight: 520,
              ),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 620,
              maxHeight: 520,
            ),
            child: child,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customDateFrom = picked.start;
        _customDateTo = picked.end;
        _datePreset = _DatePreset.custom;
      });
      _applyFilters();
    }
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
    final total = provider.orderTotal;
    final totalPages = total == 0 ? 1 : (total / _pageSize).ceil();
    final hasPrev = _currentPage > 1;
    final hasNext = _currentPage < totalPages;
    final startItem = total == 0 ? 0 : (_currentPage - 1) * _pageSize + 1;
    final endItem = startItem + orders.length - 1;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: status + counter
              Row(
                children: [
                  const Text('Status: ', style: AppTextStyles.labelLarge),
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
                          _applyFilters();
                        },
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    total == 0
                        ? '0 pesanan'
                        : '$total pesanan',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 2: date quick-filter chips + custom range
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _dateChip(_DatePreset.all, 'Semua'),
                  _dateChip(_DatePreset.today, 'Hari Ini'),
                  _dateChip(_DatePreset.thisWeek, 'Minggu Ini'),
                  _dateChip(_DatePreset.thisMonth, 'Bulan Ini'),
                  _dateChip(_DatePreset.custom, 'Pilih Tanggal'),
                ],
              ),
              if (_datePreset == _DatePreset.custom &&
                  _customDateFrom != null &&
                  _customDateTo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range,
                          size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        '${_formatDate(_customDateFrom!)} → ${_formatDate(_customDateTo!)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _pickCustomRange,
                        child: Text(
                          'Ubah',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48,
                              color: AppColors.textMuted
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada pesanan untuk filter ini',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: orders.length,
                      itemBuilder: (ctx, i) => _OrderCard(order: orders[i]),
                    ),
        ),
        // Pagination controls (sticky bottom)
        if (total > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    total == 0
                        ? '0 pesanan'
                        : 'Menampilkan $startItem-$endItem dari $total pesanan',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: hasPrev ? () => _goToPage(_currentPage - 1) : null,
                  icon: const Icon(Icons.chevron_left, size: 18),
                  label: const Text('Sebelumnya'),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$_currentPage / $totalPages',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: hasNext ? () => _goToPage(_currentPage + 1) : null,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  label: const Text('Selanjutnya'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dateChip(_DatePreset preset, String label) {
    final selected = _datePreset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) async {
        if (preset == _DatePreset.custom) {
          await _pickCustomRange();
          return;
        }
        setState(() => _datePreset = preset);
        _applyFilters();
      },
      selectedColor: AppColors.primaryLight,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      backgroundColor: AppColors.background,
      side: BorderSide(
        color: selected ? AppColors.primaryLight : AppColors.border,
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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

class _OrderCard extends StatefulWidget {
  final Order order;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _OrderCard({required this.order, this.onApprove, this.onReject});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  late Order _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  @override
  void didUpdateWidget(covariant _OrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order != widget.order) {
      _order = widget.order;
    }
  }

  void _onItemSaved(OrderItem updated) {
    final newItems = _order.items
        .map((i) => i.id == updated.id ? updated : i)
        .toList();
    setState(() {
      _order = Order(
        id: _order.id,
        salesId: _order.salesId,
        status: _order.status,
        createdAt: _order.createdAt,
        expiredAt: _order.expiredAt,
        items: newItems,
        salesUsername: _order.salesUsername,
        salesNama: _order.salesNama,
        storeName: _order.storeName,
        storeContact: _order.storeContact,
        storeAddress: _order.storeAddress,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final s = orderStatusFromString(_order.status);
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
          _order.storeName ?? 'Toko Tidak Diketahui',
          style: AppTextStyles.labelLarge,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #${_order.id.substring(0, 8)}',
                style: AppTextStyles.mono,
              ),
              if (_order.salesUsername != null || _order.salesNama != null)
                Text(
                  'Sales: ${_order.salesDisplayName}',
                  style: AppTextStyles.bodySmall,
                ),
              const SizedBox(height: 2),
              Text(
                '${_order.items.length} item • ${currencyFormat.format(_order.totalAmount)} • ${dateFormat.format(_order.createdAt)}',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrderStatusChip(status: _order.status),
            if (_order.status == 'PENDING' && widget.onApprove != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: IconButton(
                  icon: const Icon(Icons.check_circle, color: AppColors.success),
                  tooltip: 'Setujui',
                  onPressed: widget.onApprove,
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
                  onPressed: widget.onReject,
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
                if (_order.storeName != null ||
                    _order.storeContact != null ||
                    _order.storeAddress != null) ...[
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
                        if (_order.storeName != null &&
                            _order.storeName!.isNotEmpty)
                          _infoRow(Icons.business, 'Nama Toko', _order.storeName!),
                        if (_order.storeContact != null &&
                            _order.storeContact!.isNotEmpty)
                          _infoRow(Icons.phone, 'Kontak', _order.storeContact!),
                        if (_order.storeAddress != null &&
                            _order.storeAddress!.isNotEmpty)
                          _infoRow(
                              Icons.location_on, 'Alamat', _order.storeAddress!),
                        if (_order.salesUsername != null || _order.salesNama != null)
                          _infoRow(Icons.person, 'Sales', _order.salesDisplayName),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Detail item
                Row(
                  children: [
                    const Text('Detail Item:',
                        style: AppTextStyles.labelLarge),
                    const Spacer(),
                    if (_order.status == 'PENDING')
                      Text(
                        'Tap item untuk edit diskon',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._order.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _OrderItemRow(
                        item: item,
                        currencyFormat: currencyFormat,
                        editable: _order.status == 'PENDING',
                        orderId: _order.id,
                        onSaved: _onItemSaved,
                      ),
                    )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: AppTextStyles.headlineSmall),
                    Text(
                      _fmt(_order.totalAmount),
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),
                if (_order.totalDiscount > 0) ...[
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
                        '- ${_fmt(_order.totalDiscount)}',
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

/// Baris item di pesanan — bisa di-edit diskonnya kalau order masih PENDING.
class _OrderItemRow extends StatefulWidget {
  final OrderItem item;
  final NumberFormat currencyFormat;
  final bool editable;
  final String orderId;
  final ValueChanged<OrderItem> onSaved;

  const _OrderItemRow({
    required this.item,
    required this.currencyFormat,
    required this.editable,
    required this.orderId,
    required this.onSaved,
  });

  @override
  State<_OrderItemRow> createState() => _OrderItemRowState();
}

class _OrderItemRowState extends State<_OrderItemRow> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final currency = widget.currencyFormat;
    final namaBarang = item.namaBarang.isNotEmpty
        ? item.namaBarang
        : 'Produk ${item.productId}';

    return InkWell(
      onTap: widget.editable ? () => _openEditDialog() : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(namaBarang, style: AppTextStyles.bodyMedium),
                  if (item.hasDiscount)
                    Text(
                      item.discountType == 'NOMINAL'
                          ? 'Diskon Rp ${item.discountNominal}'
                          : 'Diskon ${item.discountPercent}%',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  if (widget.editable)
                    Text(
                      'Tap untuk edit diskon',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '${item.qty}x ${currency.format(item.hargaSatuan)}',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(width: 16),
            if (item.hasDiscount)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currency.format(item.hargaSatuan * item.qty),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    currency.format(item.subtotal),
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
                  currency.format(item.subtotal),
                  textAlign: TextAlign.right,
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
              ),
            if (widget.editable)
              IconButton(
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined, size: 16),
                tooltip: 'Edit diskon',
                onPressed: _saving ? null : _openEditDialog,
                color: AppColors.primaryLight,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditDialog() async {
    final result = await showDialog<_DiscountEditResult>(
      context: context,
      builder: (_) => _DiscountEditDialog(item: widget.item),
    );
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final repo = context.read<AdminProvider>().adminRepository;
      final updated = await repo.updateOrderDiscounts(widget.orderId, [
        {
          'item_id': widget.item.id,
          'discount_type': result.type,
          if (result.type == 'PERCENT') 'discount_percent': result.value,
          if (result.type == 'NOMINAL') 'discount_nominal': result.value,
        },
      ]);
      final newItem = updated.items.firstWhere(
        (i) => i.id == widget.item.id,
        orElse: () => widget.item,
      );
      widget.onSaved(newItem);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Diskon ${widget.item.namaBarang.isNotEmpty ? widget.item.namaBarang : "item"} diperbarui',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui diskon: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DiscountEditResult {
  final String type; // 'PERCENT' atau 'NOMINAL'
  final int value;
  _DiscountEditResult(this.type, this.value);
}

class _DiscountEditDialog extends StatefulWidget {
  final OrderItem item;
  const _DiscountEditDialog({required this.item});

  @override
  State<_DiscountEditDialog> createState() => _DiscountEditDialogState();
}

class _DiscountEditDialogState extends State<_DiscountEditDialog> {
  late String _type;
  late TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _type = widget.item.discountType;
    final initial = _type == 'NOMINAL'
        ? widget.item.discountNominal
        : widget.item.discountPercent;
    _valueController = TextEditingController(
      text: initial > 0 ? initial.toString() : '',
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _switchType(String newType) {
    setState(() {
      _type = newType;
      _valueController.clear();
    });
  }

  void _save() {
    final raw = _valueController.text.trim();
    final value = int.tryParse(raw) ?? 0;
    if (value <= 0) {
      Navigator.of(context).pop(_DiscountEditResult(_type, 0));
      return;
    }
    if (_type == 'PERCENT' && value > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Persen tidak boleh lebih dari 100')),
      );
      return;
    }
    if (_type == 'NOMINAL' && value > widget.item.hargaSatuan) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nominal tidak boleh lebih dari harga satuan (${widget.item.hargaSatuan})',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(_DiscountEditResult(_type, value));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        item.namaBarang.isNotEmpty ? item.namaBarang : 'Edit Diskon',
        style: AppTextStyles.headlineSmall,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Harga satuan: Rp ${item.hargaSatuan}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('% Persen'),
                  selected: _type == 'PERCENT',
                  onSelected: (sel) => sel ? _switchType('PERCENT') : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Rp Nominal'),
                  selected: _type == 'NOMINAL',
                  onSelected: (sel) => sel ? _switchType('NOMINAL') : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _valueController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: _type == 'PERCENT' ? 'Persen diskon' : 'Nominal diskon (Rp)',
              hintText: '0',
              prefixText: _type == 'NOMINAL' ? 'Rp ' : null,
              suffixText: _type == 'PERCENT' ? '%' : null,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_type == 'PERCENT' && item.discountPercent > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Saat ini: ${item.discountPercent}%',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ),
          if (_type == 'NOMINAL' && item.discountNominal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Saat ini: Rp ${item.discountNominal}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
