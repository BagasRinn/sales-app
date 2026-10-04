import 'dart:async';
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

  // Search state
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  // Pagination state untuk tab Semua Pesanan.
  static const int _pageSize = 20;
  int _currentPage = 1; // 1-indexed

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyFilters();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
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
    final search = _searchController.text.trim().isEmpty
        ? null
        : _searchController.text.trim();
    provider.loadAllOrders(
      status: _filterStatus,
      search: search,
      dateFrom: range.from,
      dateTo: range.to,
      skip: (_currentPage - 1) * _pageSize,
      limit: _pageSize,
    );
    // Juga refresh tab "Menunggu Persetujuan" dengan search yang sama —
    // kalau tidak, list pending tidak ikut ter-filter waktu user ngetik di
    // search box (provider hanya re-fetch semua pesanan, bukan pending).
    provider.loadPendingOrders(search: search);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _applyFilters();
    });
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
          child: Column(
            children: [
              // Search field
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Cari nama toko atau sales...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primaryLight),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TabBar(
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
        onCancelItem: widget.readOnly ? null : (item) => _cancelItem(orders[i].id, item),
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
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Pesanan disetujui'),
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
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
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
                const Text('Tolak Pesanan', style: AppTextStyles.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  'Stok booking akan dikembalikan. Alasan opsional — akan ditampilkan ke sales.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Alasan penolakan (opsional)',
                    hintText: 'Contoh: Data tidak valid, duplikat order, dll.',
                    border: OutlineInputBorder(),
                  ),
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
      final reason = reasonController.text.trim();
      final success = await provider.rejectOrder(
        orderId,
        rejectReason: reason.isEmpty ? null : reason,
      );
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cancel, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Pesanan ditolak'),
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

  Future<void> _cancelItem(String orderId, OrderItem item) async {
    final result = await showDialog<_CancelItemResult>(
      context: context,
      builder: (_) => _CancelItemDialog(
        namaBarang: item.namaBarang.isNotEmpty
            ? item.namaBarang
            : 'Produk ${item.productId}',
        qty: item.qty,
      ),
    );
    if (result == null || !mounted) return;

    try {
      final provider = context.read<AdminProvider>();
      final success = await provider.cancelOrderItem(orderId, result.qty, result.reason, item.productId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item dibatalkan: ${result.qty}x — ${result.reason}'),
            backgroundColor: AppColors.error,
          ),
        );
        _applyFilters();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Gagal membatalkan item'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membatalkan item: $e'),
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
  final void Function(OrderItem item)? onCancelItem;

  const _OrderCard({
    required this.order,
    this.onApprove,
    this.onReject,
    this.onCancelItem,
  });

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

  void _onDiscountSaved(Order updated) {
    setState(() {
      _order = updated;
    });
  }

  Future<void> _openItemDiscountDialog(OrderItem item) async {
    final result = await showDialog<_DiscountEditResult>(
      context: context,
      builder: (_) => _DiscountEditDialog(
        namaBarang: item.namaBarang.isNotEmpty
            ? item.namaBarang
            : 'Produk ${item.productId}',
        maxNominal: item.hargaSatuan * item.qty,
        // Layer 1
        type1: item.discountType,
        value1: item.discountType == 'NOMINAL'
            ? item.discountNominal
            : item.discountPercent,
        // Layer 2
        type2: item.discount2Type,
        value2: item.discount2Type == 'NOMINAL'
            ? item.discount2Nominal
            : item.discount2Percent,
        // Layer 3
        type3: item.discount3Type,
        value3: item.discount3Type == 'NOMINAL'
            ? item.discount3Nominal
            : item.discount3Percent,
      ),
    );
    if (result == null || !mounted) return;

    try {
      final repo = context.read<AdminProvider>().adminRepository;
      final updated = await repo.updateOrderDiscounts(
        _order.id,
        items: [
          {
            'item_id': item.id,
            // Layer 1
            'discount_type': result.type1,
            'discount_percent': result.type1 == 'PERCENT' ? result.value1 : 0,
            'discount_nominal': result.type1 == 'NOMINAL' ? result.value1 : 0,
            // Layer 2
            'discount2_type': result.type2,
            'discount2_percent': result.type2 == 'PERCENT' ? result.value2 : 0,
            'discount2_nominal': result.type2 == 'NOMINAL' ? result.value2 : 0,
            // Layer 3
            'discount3_type': result.type3,
            'discount3_percent': result.type3 == 'PERCENT' ? result.value3 : 0,
            'discount3_nominal': result.type3 == 'NOMINAL' ? result.value3 : 0,
          }
        ],
      );
      _onDiscountSaved(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Diskon item diperbarui'),
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
    }
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
              if (_order.invoiceNumber != null && _order.invoiceNumber!.isNotEmpty)
                Text(
                  'Invoice: ${_order.invoiceNumber}',
                  style: AppTextStyles.mono.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
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
                        // Customer di master data: beda dari storeName kalau
                        // customer di-rename setelah order dibuat — berguna untuk
                        // audit. Skip kalau null atau sama persis dengan storeName
                        // supaya tidak duplicate.
                        if (_order.customerName != null &&
                            _order.customerName!.isNotEmpty &&
                            _order.customerName != _order.storeName)
                          _infoRow(Icons.contacts, 'Customer', _order.customerName!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Catatan dari sales (jika ada). Disembunyikan kalau null/kosong
                // supaya tidak menambah visual noise untuk order tanpa catatan.
                if (_order.notes != null && _order.notes!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.sticky_note_2_outlined,
                                size: 16, color: AppColors.warning),
                            const SizedBox(width: 6),
                            Text(
                              'Catatan dari Sales',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _order.notes!,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Alasan penolakan dari admin (saat order di-reject). Sales
                // bisa lihat ini di mobile; admin web juga supaya konsisten
                // dan tidak perlu buka app lain untuk audit.
                if (_order.status == 'REJECTED' &&
                    _order.rejectReason != null &&
                    _order.rejectReason!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.block, size: 16, color: AppColors.error),
                            const SizedBox(width: 6),
                            Text(
                              'Alasan Penolakan',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _order.rejectReason!,
                          style: AppTextStyles.bodyMedium,
                        ),
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
                  ],
                ),
                const SizedBox(height: 10),
                ..._order.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _OrderItemRow(
                        item: item,
                        currencyFormat: currencyFormat,
                        canEdit: _order.status == 'PENDING',
                        onEdit: () => _openItemDiscountDialog(item),
                        onCancel: widget.onCancelItem != null
                            ? () => widget.onCancelItem!(item)
                            : null,
                      ),
                    )),
                // Cancelled items
                if (_order.cancelledItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Item Dibatalkan:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._order.cancelledItems.map((ci) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.cancel, size: 14, color: AppColors.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${ci.displayLabel} × ${ci.qty}',
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  // Harga + subtotal (kalau backend menyuplai).
                                  // Null untuk legacy data yang dicancel sebelum
                                  // field ini ada.
                                  if (ci.hargaSatuan != null && ci.subtotal != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_fmt(ci.hargaSatuan!)} × ${ci.qty} = ${_fmt(ci.subtotal!)}',
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.errorBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ci.reason,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
                const Divider(),

                // Ringkasan harga
                _buildPriceSummary(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary() {
    final raw = _order.totalRaw;
    final amount = _order.totalAmount;
    final discount = _order.totalDiscount;
    final hasDiscount = discount > 0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal', style: AppTextStyles.bodyMedium),
            Text(_fmt(raw), style: AppTextStyles.bodyMedium),
          ],
        ),
        const SizedBox(height: 4),
        if (hasDiscount) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Diskon',
                style: AppTextStyles.bodySmall,
              ),
              Text(
                '- ${_fmt(discount)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total', style: AppTextStyles.headlineSmall),
            Text(
              _fmt(amount),
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.primaryLight,
              ),
            ),
          ],
        ),
      ],
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

/// Baris item di pesanan — display plus tombol edit diskon per item.
class _OrderItemRow extends StatelessWidget {
  final OrderItem item;
  final NumberFormat currencyFormat;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  const _OrderItemRow({
    required this.item,
    required this.currencyFormat,
    this.canEdit = false,
    this.onEdit,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final namaBarang = item.namaBarang.isNotEmpty
        ? item.namaBarang
        : 'Produk ${item.productId}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(namaBarang, style: AppTextStyles.bodyMedium),
                Text(
                  '× ${item.qty}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (item.hasDiscount)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _formatItemDiscounts(item),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            currencyFormat.format(item.hargaSatuan),
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(width: 8),
          if (canEdit && onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: Icon(
                item.hasDiscount ? Icons.edit_outlined : Icons.discount_outlined,
                size: 14,
                color: item.hasDiscount ? AppColors.success : AppColors.primaryLight,
              ),
              tooltip: item.hasDiscount ? 'Edit diskon' : 'Tambah diskon',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          if (canEdit && onCancel != null)
            IconButton(
              onPressed: onCancel,
              icon: const Icon(
                Icons.delete_outline,
                size: 14,
                color: AppColors.error,
              ),
              tooltip: 'Batalkan item',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          const SizedBox(width: 8),
          if (item.hasDiscount)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormat.format(item.hargaSatuan * item.qty),
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
                style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  /// Format ringkasan diskon 3 layer untuk 1 item.
  /// Contoh: "Diskon 1: 10% · Diskon 2: Rp 2.000 · Diskon 3: 5%"
  static String _formatItemDiscounts(OrderItem item) {
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
        parts.add('Diskon $i: Rp ${nominal.toString()}');
      } else if (type == 'PERCENT' && percent > 0) {
        parts.add('Diskon $i: $percent%');
      }
    }
    return parts.join(' · ');
  }
}

class _DiscountEditResult {
  // Layer 1
  final String type1;
  final int value1;
  // Layer 2
  final String type2;
  final int value2;
  // Layer 3
  final String type3;
  final int value3;

  _DiscountEditResult({
    required this.type1,
    required this.value1,
    required this.type2,
    required this.value2,
    required this.type3,
    required this.value3,
  });
}

class _DiscountEditDialog extends StatefulWidget {
  final String namaBarang;
  final int maxNominal; // harga × qty — untuk cap diskon NOMINAL Layer 1

  // Layer 1
  final String type1;
  final int value1;
  // Layer 2
  final String type2;
  final int value2;
  // Layer 3
  final String type3;
  final int value3;

  const _DiscountEditDialog({
    required this.namaBarang,
    required this.maxNominal,
    required this.type1,
    required this.value1,
    required this.type2,
    required this.value2,
    required this.type3,
    required this.value3,
  });

  @override
  State<_DiscountEditDialog> createState() => _DiscountEditDialogState();
}

class _DiscountEditDialogState extends State<_DiscountEditDialog> {
  late String _type1;
  late String _type2;
  late String _type3;
  late TextEditingController _ctrl1;
  late TextEditingController _ctrl2;
  late TextEditingController _ctrl3;

  @override
  void initState() {
    super.initState();
    _type1 = widget.type1;
    _type2 = widget.type2;
    _type3 = widget.type3;
    _ctrl1 = TextEditingController(
        text: widget.value1 > 0 ? widget.value1.toString() : '');
    _ctrl2 = TextEditingController(
        text: widget.value2 > 0 ? widget.value2.toString() : '');
    _ctrl3 = TextEditingController(
        text: widget.value3 > 0 ? widget.value3.toString() : '');
  }

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    _ctrl3.dispose();
    super.dispose();
  }

  /// Hitung running residual setelah layer N untuk validasi cap NOMINAL layer N+1.
  int _runningAfter(int uptoLayer) {
    int s = widget.maxNominal;
    final layers = [
      (_type1, _parseOr0(_ctrl1)),
      (_type2, _parseOr0(_ctrl2)),
      (_type3, _parseOr0(_ctrl3)),
    ];
    for (int i = 0; i < uptoLayer && i < 3; i++) {
      final (t, v) = layers[i];
      if (v <= 0) continue;
      if (t == 'NOMINAL') {
        s -= v > s ? s : v;
      } else if (t == 'PERCENT') {
        s -= (s * v / 100).round();
      }
    }
    return s < 0 ? 0 : s;
  }

  int _parseOr0(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  bool _validateAndSave() {
    final values = <int>[];
    final types = [_type1, _type2, _type3];
    final ctrls = [_ctrl1, _ctrl2, _ctrl3];

    for (int i = 0; i < 3; i++) {
      final v = _parseOr0(ctrls[i]);
      if (v < 0) {
        _snack('Layer ${i + 1}: nilai tidak valid');
        return false;
      }
      if (types[i] == 'PERCENT' && v > 100) {
        _snack('Layer ${i + 1}: persen tidak boleh lebih dari 100');
        return false;
      }
      if (types[i] == 'NOMINAL') {
        final running = _runningAfter(i);
        if (v > running) {
          _snack(
              'Layer ${i + 1}: nominal (Rp $v) melebihi sisa subtotal (Rp $running)');
          return false;
        }
      }
      values.add(v);
    }

    Navigator.of(context).pop(_DiscountEditResult(
      type1: types[0],
      value1: values[0],
      type2: types[1],
      value2: values[1],
      type3: types[2],
      value3: values[2],
    ));
    return true;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _switchType(int idx, String newType) {
    setState(() {
      switch (idx) {
        case 0:
          _type1 = newType;
          _ctrl1.clear();
          break;
        case 1:
          _type2 = newType;
          _ctrl2.clear();
          break;
        case 2:
          _type3 = newType;
          _ctrl3.clear();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Diskon: ${widget.namaBarang}',
        style: AppTextStyles.headlineSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subtotal: Rp ${widget.maxNominal}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'Layer diskon dipotong berurutan dari sisa subtotal.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              _LayerField(
                label: 'Diskon 1',
                type: _type1,
                controller: _ctrl1,
                maxRunning: widget.maxNominal,
                onTypeChanged: (t) => _switchType(0, t),
              ),
              const SizedBox(height: 12),
              _LayerField(
                label: 'Diskon 2',
                type: _type2,
                controller: _ctrl2,
                maxRunning: _runningAfter(1),
                onTypeChanged: (t) => _switchType(1, t),
              ),
              const SizedBox(height: 12),
              _LayerField(
                label: 'Diskon 3',
                type: _type3,
                controller: _ctrl3,
                maxRunning: _runningAfter(2),
                onTypeChanged: (t) => _switchType(2, t),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _validateAndSave,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _CancelItemResult {
  final int qty;
  final String reason;

  _CancelItemResult({required this.qty, required this.reason});
}

class _CancelItemDialog extends StatefulWidget {
  final String namaBarang;
  final int qty;

  const _CancelItemDialog({required this.namaBarang, required this.qty});

  @override
  State<_CancelItemDialog> createState() => _CancelItemDialogState();
}

class _CancelItemDialogState extends State<_CancelItemDialog> {
  late int _qty;
  late TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _qty = widget.qty;
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _qty > 0 && _reasonController.text.trim().length >= 3;

  void _submit() {
    if (!_isValid) return;
    Navigator.of(context).pop(_CancelItemResult(
      qty: _qty,
      reason: _reasonController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Batalkan Item'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.namaBarang,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Jumlah yang dibatalkan:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$_qty', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                IconButton(
                  onPressed: _qty < widget.qty ? () => setState(() => _qty++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Alasan pembatalan *:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                hintText: 'Contoh: Barang gudang rusak',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              'Minimal 3 karakter. Sales akan melihat alasan ini.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isValid ? _submit : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Batalkan Item'),
        ),
      ],
    );
  }
}

class _LayerField extends StatelessWidget {
  final String label;
  final String type;
  final TextEditingController controller;
  final int maxRunning;
  final ValueChanged<String> onTypeChanged;

  const _LayerField({
    required this.label,
    required this.type,
    required this.controller,
    required this.maxRunning,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
            ChoiceChip(
              label: const Text('%'),
              selected: type == 'PERCENT',
              onSelected: (sel) => sel ? onTypeChanged('PERCENT') : null,
            ),
            const SizedBox(width: 4),
            ChoiceChip(
              label: const Text('Rp'),
              selected: type == 'NOMINAL',
              onSelected: (sel) => sel ? onTypeChanged('NOMINAL') : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            isDense: true,
            hintText: '0',
            prefixText: type == 'NOMINAL' ? 'Rp ' : null,
            suffixText: type == 'PERCENT' ? '%' : null,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          type == 'PERCENT'
              ? 'Diterapkan ke sisa subtotal (maks 100%)'
              : 'Maks: Rp $maxRunning',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}
