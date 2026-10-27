import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/design_system.dart';
import '../../core/responsive.dart';
import '../../core/responsive_dialog.dart';
import '../../core/web_download.dart';
import '../../data/models/sales_performance.dart';
import '../../data/models/order.dart';
import '../providers/admin_provider.dart';

String _fmt(int amount) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: '',
  decimalDigits: 0,
).format(amount);

/// Group per-sales performance items by branch code.
/// Urutan key mengikuti urutan pertama kali branch muncul di list
/// (preserved order — penting untuk konsistensi UI di section
/// "Masing-masing Cabang" di mana user lihat branches dalam urutan yang
/// stabil antar render).
/// Items dengan branch null dikumpulkan di bucket "" (string kosong) supaya
/// tidak hilang saat iteration.
Map<String, List<SalesPerformanceDashboardItem>>
groupDashboardPerformanceByBranch(List<SalesPerformanceDashboardItem> items) {
  final result = <String, List<SalesPerformanceDashboardItem>>{};
  for (final item in items) {
    final key = item.branch ?? '';
    result.putIfAbsent(key, () => []).add(item);
  }
  return result;
}

/// Aggregate per-sales performance items into a single total item.
/// Dipakai oleh card "Total Semua Sales" di section Performa Cabang.
/// Returns null kalau list kosong (card disembunyikan di kasus ini).
SalesPerformanceDashboardItem? aggregateDashboardPerformance(
  List<SalesPerformanceDashboardItem> items,
) {
  if (items.isEmpty) return null;
  int approvedMtdCount = 0, approvedMtdRevenue = 0;
  int pendingMtdCount = 0, pendingMtdRevenue = 0;
  int rejectedMtdCount = 0, rejectedMtdRevenue = 0;
  int approvedTodayCount = 0, approvedTodayRevenue = 0;
  int pendingTodayCount = 0, pendingTodayRevenue = 0;
  int rejectedTodayCount = 0, rejectedTodayRevenue = 0;
  for (final s in items) {
    approvedMtdCount += s.approvedMtdCount;
    approvedMtdRevenue += s.approvedMtdRevenue;
    pendingMtdCount += s.pendingMtdCount;
    pendingMtdRevenue += s.pendingMtdRevenue;
    rejectedMtdCount += s.rejectedMtdCount;
    rejectedMtdRevenue += s.rejectedMtdRevenue;
    approvedTodayCount += s.approvedTodayCount;
    approvedTodayRevenue += s.approvedTodayRevenue;
    pendingTodayCount += s.pendingTodayCount;
    pendingTodayRevenue += s.pendingTodayRevenue;
    rejectedTodayCount += s.rejectedTodayCount;
    rejectedTodayRevenue += s.rejectedTodayRevenue;
  }
  return SalesPerformanceDashboardItem(
    userId: '',
    username: '',
    approvedMtdCount: approvedMtdCount,
    approvedMtdRevenue: approvedMtdRevenue,
    pendingMtdCount: pendingMtdCount,
    pendingMtdRevenue: pendingMtdRevenue,
    rejectedMtdCount: rejectedMtdCount,
    rejectedMtdRevenue: rejectedMtdRevenue,
    approvedTodayCount: approvedTodayCount,
    approvedTodayRevenue: approvedTodayRevenue,
    pendingTodayCount: pendingTodayCount,
    pendingTodayRevenue: pendingTodayRevenue,
    rejectedTodayCount: rejectedTodayCount,
    rejectedTodayRevenue: rejectedTodayRevenue,
  );
}

class StatsTab extends StatefulWidget {
  final String role;
  final void Function(int initialTabIndex)? onOpenOrdersTab;

  const StatsTab({super.key, required this.role, this.onOpenOrdersTab});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  DateTime _selectedDate = DateTime.now();
  DateTime _periodStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _periodEnd = DateTime.now();
  String _statusFilter = 'APPROVED';
  bool _downloading = false;
  bool _downloadingPeriod = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Pilih tanggal laporan',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      // Load stats untuk tanggal yang dipilih
      if (mounted) context.read<AdminProvider>().loadAll(date: picked);
    }
  }

  Future<void> _downloadReport() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download hanya tersedia di web')),
      );
      return;
    }
    setState(() => _downloading = true);
    try {
      final repo = context.read<AdminProvider>().adminRepository;
      final bytes = await repo.downloadDailyReport(
        date: _selectedDate,
        statuses: [_statusFilter],
      );
      if (bytes.isEmpty) {
        throw Exception('File kosong — tidak ada data untuk tanggal ini');
      }
      final dateStr =
          '${_selectedDate.year.toString().padLeft(4, '0')}-'
          '${_selectedDate.month.toString().padLeft(2, '0')}-'
          '${_selectedDate.day.toString().padLeft(2, '0')}';
      _triggerBrowserDownload(
        Uint8List.fromList(bytes),
        'laporan-harian-$dateStr.xlsx',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('Laporan $dateStr berhasil diunduh'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh laporan: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _pickPeriodStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodStart,
      firstDate: DateTime(2020),
      lastDate: _periodEnd,
      helpText: 'Pilih tanggal mulai',
    );
    if (picked != null) {
      setState(() => _periodStart = picked);
    }
  }

  Future<void> _pickPeriodEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodEnd,
      firstDate: _periodStart,
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Pilih tanggal akhir',
    );
    if (picked != null) {
      setState(() => _periodEnd = picked);
    }
  }

  Future<void> _downloadPeriodReport() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download hanya tersedia di web')),
      );
      return;
    }
    if (_periodEnd.isBefore(_periodStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal akhir harus setelah tanggal mulai'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _downloadingPeriod = true);
    try {
      final repo = context.read<AdminProvider>().adminRepository;
      final bytes = await repo.downloadPeriodReport(
        startDate: _periodStart,
        endDate: _periodEnd,
        statuses: [_statusFilter],
      );
      if (bytes.isEmpty) {
        throw Exception('File kosong — tidak ada data untuk periode ini');
      }
      final startStr =
          '${_periodStart.year.toString().padLeft(4, '0')}-'
          '${_periodStart.month.toString().padLeft(2, '0')}-'
          '${_periodStart.day.toString().padLeft(2, '0')}';
      final endStr =
          '${_periodEnd.year.toString().padLeft(4, '0')}-'
          '${_periodEnd.month.toString().padLeft(2, '0')}-'
          '${_periodEnd.day.toString().padLeft(2, '0')}';
      _triggerBrowserDownload(
        Uint8List.fromList(bytes),
        'laporan-periode-$startStr-sd-$endStr.xlsx',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('Laporan $startStr sd $endStr berhasil diunduh'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh laporan: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingPeriod = false);
    }
  }

  void _triggerBrowserDownload(Uint8List bytes, String filename) {
    if (kIsWeb) {
      triggerBrowserDownload(bytes, filename);
    }
  }

  Widget _buildBranchPerformanceSection(AdminProvider provider) {
    final loading = provider.dashboardPerformanceLoading;
    final sales = provider.dashboardPerformance;

    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (sales.isEmpty) {
      // Tanpa data sales, tidak ada yang bisa diagregasi — section kosong
      // supaya tidak misleading.
      return const AppCard(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            'Belum ada data performa cabang.',
            style: AppTextStyles.bodyMuted,
          ),
        ),
      );
    }

    final aggregate = aggregateDashboardPerformance(sales)!;
    return _BranchPerformanceCard(
      total: aggregate,
      onTapSection: (status) =>
          _openTotalDetail(provider, initialStatus: status),
    );
  }

  /// Section "Masing-masing Cabang" — MANAGER only. Satu card per branch,
  /// masing-masing = aggregate sales di branch tsb. Klik → popup per-branch.
  /// Untuk SUPERVISOR/ADMIN, section ini kosong (mereka cuma punya 1 branch
  /// yang sudah terwakili oleh Performa Cabang di atas).
  Widget _buildPerBranchSection(AdminProvider provider) {
    final loading = provider.dashboardPerformanceLoading;
    final sales = provider.dashboardPerformance;

    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (sales.isEmpty) {
      return const SizedBox.shrink();
    }

    final groups = groupDashboardPerformanceByBranch(sales);
    // Skip branch kosong (item dengan branch null) untuk section ini — bukan
    // branch yang valid untuk di-tampilkan.
    final branchEntries = groups.entries
        .where((e) => e.key.isNotEmpty)
        .toList();
    if (branchEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: branchEntries.map((entry) {
        final aggregate = aggregateDashboardPerformance(entry.value)!;
        return ConstrainedBox(
          // Fixed 420px bikin overflow di mobile; batasi atas saja.
          constraints: const BoxConstraints(maxWidth: 420),
          child: _BranchPerformanceCard(
            total: aggregate,
            title: 'Cabang ${entry.key}',
            subtitle: 'Total ${entry.value.length} sales di cabang ini',
            headerIcon: Icons.business_outlined,
            headerIconColor: AppColors.info,
            fullWidth: false,
            onTapSection: (status) =>
                _openBranchDetail(provider, entry.key, initialStatus: status),
          ),
        );
      }).toList(),
    );
  }

  void _openTotalDetail(AdminProvider provider, {String? initialStatus}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: _SalesOverlayDialog(
          provider: provider,
          // sales: null, branch: null → mode "Total Semua Sales" (popup
          // expose filter per sales & per branch di sidebar).
          initialStatus: initialStatus,
          onClose: () {
            provider.clearSalesDetailOrders();
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  void _openBranchDetail(
    AdminProvider provider,
    String branch, {
    String? initialStatus,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: _SalesOverlayDialog(
          provider: provider,
          sales: null,
          branch: branch,
          initialStatus: initialStatus,
          onClose: () {
            provider.clearSalesDetailOrders();
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  Widget _buildSalesPerformanceSection(AdminProvider provider) {
    final loading = provider.dashboardPerformanceLoading;
    final sales = provider.dashboardPerformance;

    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (sales.isEmpty) {
      return const AppCard(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            'Belum ada data performa sales.',
            style: AppTextStyles.bodyMuted,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: sales
          .map(
            (s) => _SalesPerformanceCard(
              s: s,
              onTapSection: (status) =>
                  _openSalesDetail(provider, s, initialStatus: status),
            ),
          )
          .toList(),
    );
  }

  void _openSalesDetail(
    AdminProvider provider,
    SalesPerformanceDashboardItem s, {
    String? initialStatus,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: _SalesOverlayDialog(
          provider: provider,
          sales: s,
          initialStatus: initialStatus,
          onClose: () {
            provider.clearSalesDetailOrders();
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  /// Judul sub-section di dalam halaman (bukan level halaman).
  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
    child: Text(text, style: AppTextStyles.h2),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final stats = provider.stats;
    final pending = provider.pendingOrders;
    final isLoading = provider.isLoading;
    final errorMessage = provider.errorMessage;

    final totalOrders = stats['total_orders'] ?? 0;
    final pendingOrders = stats['pending_orders'] ?? 0;
    final approvedOrders = stats['approved_orders'] ?? 0;
    final rejectedOrders = stats['rejected_orders'] ?? 0;
    final cancelledOrders = stats['cancelled_orders'] ?? 0;
    final draftOrders = stats['draft_orders'] ?? 0;
    final totalProducts = stats['total_products'] ?? 0;
    final totalCustomers = stats['total_customers'] ?? 0;
    // Produk di mana stok_sistem < (stok_booking + stok_diterima) — perlu audit segera.
    // Dilaporkan backend di /products/stats. Definisi predicate di-update
    // setelah revisi sistem stok (stok_diterima pisah dari stok_booking).
    final needsReview = stats['needs_review'] ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final resp = Responsive.of(constraints.maxWidth);
        return SingleChildScrollView(
          padding: EdgeInsets.all(resp.contentPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(
                title: 'Ringkasan Sistem',
                subtitle:
                    'Pesanan hari ini, ringkasan data master, dan ambil laporan',
              ),

              if (errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  color: AppColors.errorBg,
                  borderColor: AppColors.errorBorder,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm + 4),
                      Expanded(
                        child: Text(
                          errorMessage,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.refresh,
                          color: AppColors.error,
                          size: 20,
                        ),
                        tooltip: 'Coba lagi',
                        onPressed: () => provider.loadAll(),
                      ),
                    ],
                  ),
                ),
              ],

              if (isLoading && stats.isEmpty && pending.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Memuat data...', style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: AppSpacing.lg - 4),
                // Section: order hari ini
                _sectionLabel('Pesanan Hari Ini'),
                AppResponsiveGrid(
                  desktopCols: 5,
                  tabletCols: 3,
                  mobileCols: 2,
                  children: [
                    AppStatCard(
                      title: 'Total Pesanan',
                      value: '$totalOrders',
                      icon: Icons.shopping_cart,
                    ),
                    AppStatCard(
                      title: 'Menunggu Persetujuan',
                      value: '$pendingOrders',
                      icon: Icons.pending_actions,
                    ),
                    AppStatCard(
                      title: 'Disetujui',
                      value: '$approvedOrders',
                      icon: Icons.check_circle,
                    ),
                    AppStatCard(
                      title: 'Ditolak',
                      value: '$rejectedOrders',
                      icon: Icons.cancel,
                    ),
                    AppStatCard(
                      title: 'Dibatalkan',
                      value: '$cancelledOrders',
                      icon: Icons.block,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // Section: data master (total keseluruhan, bukan per hari)
                _sectionLabel('Data Master'),
                AppResponsiveGrid(
                  desktopCols: 4,
                  tabletCols: 2,
                  mobileCols: 2,
                  children: [
                    AppStatCard(
                      title: 'Total Produk',
                      value: '$totalProducts',
                      icon: Icons.inventory_2,
                    ),
                    AppStatCard(
                      title: 'Total Toko',
                      value: '$totalCustomers',
                      icon: Icons.store,
                    ),
                    AppStatCard(
                      title: 'Draft Pesanan',
                      value: '$draftOrders',
                      icon: Icons.drafts_outlined,
                    ),
                    AppStatCard(
                      title: 'Produk Perlu Tinjau',
                      value: '$needsReview',
                      icon: Icons.report_problem_outlined,
                      // Warna bahaya kalau ada yang perlu ditinjau, netral kalau 0.
                      accentColor: needsReview > 0
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ],
                ),

                // MANAGER & SUPERVISOR: ringkasan performa
                if (widget.role == 'MANAGER' ||
                    widget.role == 'SUPERVISOR') ...[
                  const SizedBox(height: AppSpacing.lg),
                  _sectionLabel('Total Semua Cabang'),
                  _buildBranchPerformanceSection(provider),
                  // MANAGER (global) saja — lihat per-cabang karena lihat semua
                  // branch. SUPERVISOR cuma 1 branch jadi tidak ada gunanya.
                  if (widget.role == 'MANAGER') ...[
                    const SizedBox(height: AppSpacing.lg - 4),
                    _sectionLabel('Masing-masing Cabang'),
                    _buildPerBranchSection(provider),
                  ],
                  const SizedBox(height: AppSpacing.lg - 4),
                  _sectionLabel('Performa Sales'),
                  _buildSalesPerformanceSection(provider),
                ],

                const SizedBox(height: AppSpacing.xl),
                // Laporan
                Text('Ambil Laporan', style: AppTextStyles.h1),
                const SizedBox(height: AppSpacing.md),
                _ReportDownloadCard(
                  selectedDate: _selectedDate,
                  statusFilter: _statusFilter,
                  downloading: _downloading,
                  onPickDate: _pickDate,
                  onChangeStatus: (s) => setState(() => _statusFilter = s),
                  onDownload: _downloadReport,
                ),
                const SizedBox(height: 16),
                _PeriodReportCard(
                  periodStart: _periodStart,
                  periodEnd: _periodEnd,
                  statusFilter: _statusFilter,
                  downloading: _downloadingPeriod,
                  onPickStart: _pickPeriodStart,
                  onPickEnd: _pickPeriodEnd,
                  onChangeStatus: (s) => setState(() => _statusFilter = s),
                  onDownload: _downloadPeriodReport,
                ),
                // Hide "Pesanan Perlu Tindakan" for SUPERVISOR — they focus on monitoring, not order actions
                if (widget.role != 'SUPERVISOR') ...[
                  const SizedBox(height: AppSpacing.xl + 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pesanan Perlu Tindakan',
                          style: AppTextStyles.h1,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (pending.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.sm + 4),
                        AppBadge(
                          label: '${pending.length}',
                          variant: AppBadgeVariant.warning,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (pending.isNotEmpty)
                    ...pending
                        .take(5)
                        .map(
                          (order) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: AppCard(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.warningSoft,
                                      borderRadius: AppRadius.md,
                                    ),
                                    child: const Icon(
                                      Icons.store,
                                      color: AppColors.warning,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md - 2),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order.storeName ??
                                              'Toko Tidak Diketahui',
                                          style: AppTextStyles.labelLarge,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Order #${order.id.substring(0, 8)} • ${order.items.length} item • Rp ${_fmt(order.totalAmount)}',
                                          style: AppTextStyles.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  const AppBadge(
                                    label: 'Menunggu',
                                    variant: AppBadgeVariant.warning,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                  else
                    const AppCard(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.successSoft,
                            child: Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                              size: 28,
                            ),
                          ),
                          SizedBox(width: AppSpacing.md + 4),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Semua pesanan sudah diproses',
                                  style: AppTextStyles.h2,
                                ),
                                SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Tidak ada pesanan yang menunggu persetujuan',
                                  style: AppTextStyles.bodyMuted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PeriodReportCard extends StatelessWidget {
  final DateTime periodStart;
  final DateTime periodEnd;
  final String statusFilter;
  final bool downloading;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final ValueChanged<String> onChangeStatus;
  final VoidCallback onDownload;

  const _PeriodReportCard({
    required this.periodStart,
    required this.periodEnd,
    required this.statusFilter,
    required this.downloading,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onChangeStatus,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final startLabel = DateFormat('dd MMM yyyy', 'id_ID').format(periodStart);
    final endLabel = DateFormat('dd MMM yyyy', 'id_ID').format(periodEnd);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.date_range,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Laporan Periode', style: AppTextStyles.h2),
                    SizedBox(height: 2),
                    Text(
                      'Export data order ke Excel berdasarkan rentang tanggal',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: downloading ? null : onPickStart,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(startLabel),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('—', style: AppTextStyles.bodyMedium),
              ),
              OutlinedButton.icon(
                onPressed: downloading ? null : onPickEnd,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(endLabel),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: statusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'APPROVED',
                      child: Text('Disetujui'),
                    ),
                    DropdownMenuItem(value: 'PENDING', child: Text('Menunggu')),
                    DropdownMenuItem(value: 'REJECTED', child: Text('Ditolak')),
                    DropdownMenuItem(
                      value: 'APPROVED,PENDING,REJECTED',
                      child: Text('Semua Status'),
                    ),
                  ],
                  onChanged: downloading
                      ? null
                      : (v) {
                          if (v != null) onChangeStatus(v);
                        },
                ),
              ),
              AppButton(
                label: downloading ? 'Mengunduh...' : 'Download Periode',
                icon: Icons.download,
                isLoading: downloading,
                onPressed: onDownload,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Default: 30 hari ke belakang • Status default: Disetujui',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ReportDownloadCard extends StatelessWidget {
  final DateTime selectedDate;
  final String statusFilter;
  final bool downloading;
  final VoidCallback onPickDate;
  final ValueChanged<String> onChangeStatus;
  final VoidCallback onDownload;

  const _ReportDownloadCard({
    required this.selectedDate,
    required this.statusFilter,
    required this.downloading,
    required this.onPickDate,
    required this.onChangeStatus,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd MMM yyyy', 'id_ID').format(selectedDate);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.today,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Laporan Harian', style: AppTextStyles.h2),
                    SizedBox(height: 2),
                    Text(
                      'Export data order per hari ke format Excel',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: downloading ? null : onPickDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(dateLabel),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: statusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'APPROVED',
                      child: Text('Disetujui'),
                    ),
                    DropdownMenuItem(value: 'PENDING', child: Text('Menunggu')),
                    DropdownMenuItem(value: 'REJECTED', child: Text('Ditolak')),
                    DropdownMenuItem(
                      value: 'APPROVED,PENDING,REJECTED',
                      child: Text('Semua Status'),
                    ),
                  ],
                  onChanged: downloading
                      ? null
                      : (v) {
                          if (v != null) onChangeStatus(v);
                        },
                ),
              ),
              AppButton(
                label: downloading ? 'Mengunduh...' : 'Download Harian',
                icon: Icons.download,
                isLoading: downloading,
                onPressed: onDownload,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Status default: Disetujui',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SalesPerformanceCard extends StatelessWidget {
  final SalesPerformanceDashboardItem s;

  /// Callback untuk klik pada bagian card. Status null = "Semua"
  /// (klik nama atau area kosong), 'APPROVED'/'PENDING'/'REJECTED' = klik
  /// section status yang sesuai di card.
  final ValueChanged<String?> onTapSection;

  const _SalesPerformanceCard({required this.s, required this.onTapSection});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ConstrainedBox(
        // Fixed 340px bikin overflow di mobile; batasi atas saja.
        constraints: const BoxConstraints(maxWidth: 340),
        child: AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name row — klik → "Semua" (no status filter)
              GestureDetector(
                onTap: () => onTapSection(null),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          s.displayName.isNotEmpty
                              ? s.displayName[0].toUpperCase()
                              : '?',
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.displayName,
                          style: AppTextStyles.h2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Disetujui — klik → APPROVED
              GestureDetector(
                onTap: () => onTapSection('APPROVED'),
                behavior: HitTestBehavior.opaque,
                child: _StatusBreakdown(
                  label: 'Disetujui',
                  mtdCount: s.approvedMtdCount,
                  mtdRevenue: s.approvedMtdRevenue,
                  todayCount: s.approvedTodayCount,
                  todayRevenue: s.approvedTodayRevenue,
                  color: AppColors.success,
                ),
              ),
              const Divider(height: 22),
              // Menunggu — klik → PENDING
              GestureDetector(
                onTap: () => onTapSection('PENDING'),
                behavior: HitTestBehavior.opaque,
                child: _StatusBreakdown(
                  label: 'Menunggu',
                  mtdCount: s.pendingMtdCount,
                  mtdRevenue: s.pendingMtdRevenue,
                  todayCount: s.pendingTodayCount,
                  todayRevenue: s.pendingTodayRevenue,
                  color: AppColors.warning,
                ),
              ),
              const Divider(height: 22),
              // Ditolak — klik → REJECTED
              GestureDetector(
                onTap: () => onTapSection('REJECTED'),
                behavior: HitTestBehavior.opaque,
                child: _StatusBreakdown(
                  label: 'Ditolak',
                  mtdCount: s.rejectedMtdCount,
                  mtdRevenue: s.rejectedMtdRevenue,
                  todayCount: s.rejectedTodayCount,
                  todayRevenue: s.rejectedTodayRevenue,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Card untuk "Performa Cabang" / "Masing-masing Cabang" =====
// Bentuknya mengikuti _SalesPerformanceCard tapi:
//   - Lebar membentang 1 baris (Wrap / ListView akan full-width) secara default
//   - Tanpa avatar individu — pakai icon grup / business (branch)
//   - Judul & subjudul configurable
//   - Klik membuka popup dengan filter per sales / per branch
class _BranchPerformanceCard extends StatelessWidget {
  final SalesPerformanceDashboardItem total;

  /// Sama semantics dengan _SalesPerformanceCard: null = semua status.
  final ValueChanged<String?> onTapSection;
  final String title;
  final String subtitle;

  /// Icon untuk header. Default = grup (untuk total semua cabang / sales).
  /// Untuk per-branch, override jadi business_outlined.
  final IconData headerIcon;
  final Color headerIconColor;

  /// true = card full-width 1 baris (untuk Total Semua Cabang).
  /// false = card size ke konten / parent constraint (untuk per-branch card
  /// di dalam Wrap, biar bisa side-by-side).
  final bool fullWidth;

  const _BranchPerformanceCard({
    required this.total,
    required this.onTapSection,
    this.title = 'Total Semua Sales',
    this.subtitle = 'Agregat seluruh sales di branch ini',
    this.headerIcon = Icons.groups_outlined,
    this.headerIconColor = AppColors.primary,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            final statusSections = <Widget>[
              _StatusBreakdown(
                label: 'Disetujui',
                mtdCount: total.approvedMtdCount,
                mtdRevenue: total.approvedMtdRevenue,
                todayCount: total.approvedTodayCount,
                todayRevenue: total.approvedTodayRevenue,
                color: AppColors.success,
                onTap: () => onTapSection('APPROVED'),
              ),
              _StatusBreakdown(
                label: 'Menunggu',
                mtdCount: total.pendingMtdCount,
                mtdRevenue: total.pendingMtdRevenue,
                todayCount: total.pendingTodayCount,
                todayRevenue: total.pendingTodayRevenue,
                color: AppColors.warning,
                onTap: () => onTapSection('PENDING'),
              ),
              _StatusBreakdown(
                label: 'Ditolak',
                mtdCount: total.rejectedMtdCount,
                mtdRevenue: total.rejectedMtdRevenue,
                todayCount: total.rejectedTodayCount,
                todayRevenue: total.rejectedTodayRevenue,
                color: AppColors.error,
                onTap: () => onTapSection('REJECTED'),
              ),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header — icon + judul + total
                GestureDetector(
                  onTap: () => onTapSection(null),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: headerIconColor.withValues(alpha: 0.1),
                            borderRadius: AppRadius.md,
                          ),
                          child: Icon(
                            headerIcon,
                            color: headerIconColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppTextStyles.h3.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                subtitle,
                                style: AppTextStyles.caption,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Status breakdown — full row di desktop, stack di mobile
                if (isNarrow)
                  Column(
                    children: [
                      for (int i = 0; i < statusSections.length; i++) ...[
                        statusSections[i],
                        if (i < statusSections.length - 1)
                          const Divider(height: 20),
                      ],
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < statusSections.length; i++) ...[
                        Expanded(child: statusSections[i]),
                        if (i < statusSections.length - 1)
                          Container(
                            width: 1,
                            height: 60,
                            color: AppColors.border,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                      ],
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Satu blok status (Disetujui/Menunggu/Ditolak): dot + label + MTD + hari ini.
/// Dipakai _SalesPerformanceCard & _BranchPerformanceCard.
class _StatusBreakdown extends StatelessWidget {
  final String label;
  final int mtdCount;
  final int mtdRevenue;
  final int todayCount;
  final int todayRevenue;
  final Color color;
  final VoidCallback? onTap;

  const _StatusBreakdown({
    required this.label,
    required this.mtdCount,
    required this.mtdRevenue,
    required this.todayCount,
    required this.todayRevenue,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _column('MTD', mtdCount, mtdRevenue)),
            const SizedBox(width: 10),
            Expanded(child: _column('Hari ini', todayCount, todayRevenue)),
          ],
        ),
      ],
    );

    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }

  Widget _column(String heading, int count, int revenue) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(heading, style: AppTextStyles.caption),
      const SizedBox(height: 3),
      Text(
        '$count order',
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
      ),
      Text(
        'Rp ${_fmt(revenue)}',
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
      ),
    ],
  );
}

// ===== Popup detail order untuk sales performance card =====
// Dua mode pre-filter:
//   - sales: !null → mode per-sales (sales filter hidden di sidebar)
//   - branch: !null → mode per-branch (branch filter hidden di sidebar)
// Keduanya null → mode "Total Semua Cabang" (kedua filter visible).
class _SalesOverlayDialog extends StatelessWidget {
  final AdminProvider provider;
  final SalesPerformanceDashboardItem? sales;
  final String? branch;
  final VoidCallback onClose;
  final String? initialStatus;

  const _SalesOverlayDialog({
    required this.provider,
    this.sales,
    this.branch,
    required this.onClose,
    this.initialStatus,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveDialog(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final resp = Responsive.of(constraints.maxWidth);
          return _SalesDetailDialogBody(
            provider: provider,
            sales: sales,
            branch: branch,
            onClose: onClose,
            initialStatus: initialStatus,
            compact: resp.isMobile,
          );
        },
      ),
    );
  }
}

class _SalesDetailDialogBody extends StatefulWidget {
  final AdminProvider provider;

  /// Null = mode "Total Semua Sales" (popup dari card Performa Cabang).
  /// Saat null, user bisa filter per sales via dropdown di sidebar.
  final SalesPerformanceDashboardItem? sales;

  /// Null = no branch pre-filter. Saat di-set (mode per-branch dari
  /// "Masing-masing Cabang" card), orders di-filter ke branch tsb dan
  /// dropdown Branch di sidebar di-hide.
  final String? branch;
  final VoidCallback onClose;

  /// Status pre-applied saat dialog pertama dibuka. Null = tampilkan semua
  /// status ("Semua"). Dipakai untuk deep-link dari klik salah satu section
  /// di dashboard card (Disetujui/Menunggu/Ditolak → APPROVED/PENDING/REJECTED).
  final String? initialStatus;

  /// true = layout mobile (sidebar stack di atas, full-width).
  /// false = layout desktop (sidebar 220px di kiri, orders di kanan).
  final bool compact;

  const _SalesDetailDialogBody({
    required this.provider,
    this.sales,
    this.branch,
    required this.onClose,
    this.initialStatus,
    this.compact = false,
  });

  @override
  State<_SalesDetailDialogBody> createState() => _SalesDetailDialogBodyState();
}

class _SalesDetailDialogBodyState extends State<_SalesDetailDialogBody> {
  String? _statusFilter;
  String? _salesFilter; // null = "Semua Sales"; only used in total/branch mode
  String? _branchFilter; // null = "Semua Cabang"; only used in total/sales mode
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _showStatusMenu = false;
  bool _showSalesMenu = false;
  bool _showBranchMenu = false;
  bool _showDateFromPicker = false;
  bool _showDateToPicker = false;
  String? _expandedOrderId;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatus;
    // Default = bulan berjalan (sama dengan periode card MTD di dashboard),
    // supaya angka popup match dengan card. User tetap bisa ubah/hapus.
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = DateTime(now.year, now.month, now.day);
    widget.provider.addListener(_onProviderUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilters();
    });
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _onProviderUpdate() {
    if (mounted) setState(() {});
  }

  void _applyFilters() {
    // Prioritas: widget.sales / widget.branch (mode drill-down) > filter
    // user (mode total / per-axis). Saat widget.sales != null, salesId
    // dipaksa ke sales tsb; saat widget.branch != null, branch dipaksa
    // ke branch tsb.
    final String? effectiveSalesId = widget.sales != null
        ? widget.sales!.userId
        : _salesFilter;
    final String? effectiveBranch = widget.branch ?? _branchFilter;
    widget.provider.loadSalesDetailOrders(
      salesId: effectiveSalesId,
      branch: effectiveBranch,
      status: _statusFilter,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return AppColors.success;
      case 'PENDING':
        return AppColors.warning;
      case 'REJECTED':
        return AppColors.error;
      case 'CANCELLED':
        return AppColors.textMuted;
      default:
        return AppColors.info;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return 'Disetujui';
      case 'PENDING':
        return 'Menunggu';
      case 'REJECTED':
        return 'Ditolak';
      case 'CANCELLED':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  String _currentStatusLabel() {
    if (_statusFilter == null) return 'Semua';
    return _statusLabel(_statusFilter!);
  }

  String _currentSalesLabel(List<SalesPerformanceDashboardItem> salesList) {
    if (_salesFilter == null) return 'Semua Sales';
    final match = salesList.where((s) => s.userId == _salesFilter).toList();
    if (match.isEmpty) return 'Semua Sales';
    return match.first.displayName;
  }

  String _currentBranchLabel(List<SalesPerformanceDashboardItem> branchList) {
    if (_branchFilter == null) return 'Semua Cabang';
    return _branchFilter!;
  }

  void _selectStatus(String? v) {
    setState(() {
      _statusFilter = v;
      _showStatusMenu = false;
    });
    _applyFilters();
  }

  void _selectSales(String? v) {
    setState(() {
      _salesFilter = v;
      _showSalesMenu = false;
    });
    _applyFilters();
  }

  void _selectBranch(String? v) {
    setState(() {
      _branchFilter = v;
      _showBranchMenu = false;
    });
    _applyFilters();
  }

  void _selectDateFrom(DateTime d) {
    setState(() {
      _dateFrom = d;
      _showDateFromPicker = false;
    });
    _applyFilters();
  }

  void _selectDateTo(DateTime d) {
    setState(() {
      _dateTo = d;
      _showDateToPicker = false;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final orders = provider.salesDetailOrders;
    final loading = provider.salesDetailLoading;
    final error = provider.salesDetailError;

    // Total dari server = seluruh hasil filter (bukan cuma [limit] row yang
    // dikirim), jadi sama dengan angka card MTD.
    final totalOrders = provider.salesDetailTotalOrders;
    final totalRevenue = provider.salesDetailTotalRevenue;
    final totalDiscount = provider.salesDetailTotalDiscount;
    final totalUpPrice = provider.salesDetailTotalUpPrice;

    final salesList = widget.sales == null
        ? provider.dashboardPerformance
        : const <SalesPerformanceDashboardItem>[];
    final branchList = widget.branch == null
        ? provider.dashboardPerformance
        : const <SalesPerformanceDashboardItem>[];

    return GestureDetector(
      onTap: () {
        // Close any open picker menus
        setState(() {
          _showStatusMenu = false;
          _showSalesMenu = false;
          _showBranchMenu = false;
          _showDateFromPicker = false;
          _showDateToPicker = false;
        });
      },
      child: SizedBox(
        width: 960,
        height: 600,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  if (widget.sales != null) ...[
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        widget.sales!.displayName.isNotEmpty
                            ? widget.sales!.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.sales!.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '@${widget.sales!.username}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (widget.branch != null) ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.business_outlined,
                        color: AppColors.info,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cabang ${widget.branch}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Pesanan dari seluruh sales di cabang ini',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.groups_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Semua Sales',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Pesanan dari seluruh sales di branch ini',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            // Body: horizontal split
            Expanded(
              child: widget.compact
                  ? Column(
                      children: [
                        _buildCompactSidebar(
                          totalOrders: totalOrders,
                          totalRevenue: totalRevenue,
                          totalDiscount: totalDiscount,
                          totalUpPrice: totalUpPrice,
                          salesList: salesList,
                          branchList: branchList,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        Expanded(
                          child: _buildOrderList(orders, loading, error),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        _buildDesktopSidebar(
                          totalOrders: totalOrders,
                          totalRevenue: totalRevenue,
                          totalDiscount: totalDiscount,
                          totalUpPrice: totalUpPrice,
                          salesList: salesList,
                          branchList: branchList,
                        ),
                        Expanded(
                          child: _buildOrderList(orders, loading, error),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Helpers: sidebar (summary + filters) =====
  //
  // Pakai 2 varian:
  // - _buildDesktopSidebar: lebar tetap 240px, border kanan, konten scroll vertikal.
  // - _buildCompactSidebar: full-width di top, scroll horizontal untuk filter chips,
  //   tinggi dibatasi supaya tidak makan ruang order list.
  //
  // Keduanya share inner content (summary box + filter buttons) yang dibungkus
  // helper _buildSidebarInner — supaya tidak duplikasi.
  Widget _buildDesktopSidebar({
    required int totalOrders,
    required int totalRevenue,
    required int totalDiscount,
    required int totalUpPrice,
    required List<SalesPerformanceDashboardItem> salesList,
    required List<SalesPerformanceDashboardItem> branchList,
  }) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        child: _buildSidebarInner(
          totalOrders: totalOrders,
          totalRevenue: totalRevenue,
          totalDiscount: totalDiscount,
          totalUpPrice: totalUpPrice,
          salesList: salesList,
          branchList: branchList,
        ),
      ),
    );
  }

  Widget _buildCompactSidebar({
    required int totalOrders,
    required int totalRevenue,
    required int totalDiscount,
    required int totalUpPrice,
    required List<SalesPerformanceDashboardItem> salesList,
    required List<SalesPerformanceDashboardItem> branchList,
  }) {
    // Kompak: summary box di atas (3 angka horizontal), filter chips di bawah.
    // Tinggi dibatasi max 200px supaya area order list dapat ruang.
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: AppColors.surface,
      child: _buildSidebarInner(
        totalOrders: totalOrders,
        totalRevenue: totalRevenue,
        totalDiscount: totalDiscount,
        totalUpPrice: totalUpPrice,
        salesList: salesList,
        branchList: branchList,
        compact: true,
      ),
    );
  }

  Widget _buildSidebarInner({
    required int totalOrders,
    required int totalRevenue,
    required int totalDiscount,
    required int totalUpPrice,
    required List<SalesPerformanceDashboardItem> salesList,
    required List<SalesPerformanceDashboardItem> branchList,
    bool compact = false,
  }) {
    final summaryBox = Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: compact
          ? Row(
              children: [
                _buildSummaryStat(
                  label: 'Order',
                  value: '$totalOrders',
                  color: AppColors.primary,
                  isLarge: true,
                ),
                const SizedBox(width: 12),
                _buildSummaryStat(
                  label: 'Revenue',
                  value: 'Rp ${_fmt(totalRevenue)}',
                  color: AppColors.primary,
                  isLarge: true,
                ),
                if (totalUpPrice > 0) ...[
                  const SizedBox(width: 12),
                  _buildSummaryStat(
                    label: 'Up Price',
                    value: '+Rp ${_fmt(totalUpPrice)}',
                    color: AppColors.warning,
                  ),
                ],
                if (totalDiscount > 0) ...[
                  const SizedBox(width: 12),
                  _buildSummaryStat(
                    label: 'Diskon',
                    value: '-Rp ${_fmt(totalDiscount)}',
                    color: AppColors.success,
                  ),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Order',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                Text(
                  '$totalOrders',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Total Revenue',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                Text(
                  'Rp ${_fmt(totalRevenue)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
                if (totalDiscount > 0) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Total Diskon',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  Text(
                    '-Rp ${_fmt(totalDiscount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.success,
                    ),
                  ),
                ],
                if (totalUpPrice > 0) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Total Up Price',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  Text(
                    '+Rp ${_fmt(totalUpPrice)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ],
            ),
    );

    final filterButtons = <Widget>[
      _buildFilterDropdown(
        label: _currentStatusLabel(),
        onTap: () {
          setState(() {
            _showStatusMenu = !_showStatusMenu;
            _showSalesMenu = false;
            _showBranchMenu = false;
            _showDateFromPicker = false;
            _showDateToPicker = false;
          });
        },
      ),
      if (widget.sales == null)
        _buildFilterDropdown(
          label: _currentSalesLabel(salesList),
          onTap: () {
            setState(() {
              _showSalesMenu = !_showSalesMenu;
              _showStatusMenu = false;
              _showBranchMenu = false;
              _showDateFromPicker = false;
              _showDateToPicker = false;
            });
          },
        ),
      if (widget.branch == null)
        _buildFilterDropdown(
          label: _currentBranchLabel(branchList),
          onTap: () {
            setState(() {
              _showBranchMenu = !_showBranchMenu;
              _showStatusMenu = false;
              _showSalesMenu = false;
              _showDateFromPicker = false;
              _showDateToPicker = false;
            });
          },
        ),
      _buildFilterDropdown(
        label: _dateFrom != null ? _formatDate(_dateFrom!) : 'Dari tanggal',
        leadingIcon: Icons.calendar_today,
        onTap: () {
          setState(() {
            _showDateFromPicker = !_showDateFromPicker;
            _showDateToPicker = false;
            _showStatusMenu = false;
            _showSalesMenu = false;
            _showBranchMenu = false;
          });
        },
      ),
      _buildFilterDropdown(
        label: _dateTo != null ? _formatDate(_dateTo!) : 'Sampai tanggal',
        leadingIcon: Icons.calendar_today,
        onTap: () {
          setState(() {
            _showDateToPicker = !_showDateToPicker;
            _showDateFromPicker = false;
            _showStatusMenu = false;
            _showSalesMenu = false;
            _showBranchMenu = false;
          });
        },
      ),
      if (_dateFrom != null || _dateTo != null)
        GestureDetector(
          onTap: () {
            setState(() {
              _dateFrom = null;
              _dateTo = null;
            });
            _applyFilters();
          },
          child: const Text(
            'Reset tanggal',
            style: TextStyle(fontSize: 11, color: AppColors.info),
          ),
        ),
    ];

    if (compact) {
      // Compact: summary + filter chips horizontal scroll, dengan overlay
      // menus yang diposisikan relatif ke Stack.
      return Stack(
        clipBehavior: Clip.none,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                summaryBox,
                const SizedBox(width: 10),
                ...filterButtons.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: b,
                  ),
                ),
              ],
            ),
          ),
          // Dropdown overlays (sama dengan desktop)
          if (_showStatusMenu)
            _buildOverlayMenu(
              children: [
                _statusMenuItem(null, 'Semua'),
                _statusMenuItem('APPROVED', 'Disetujui'),
                _statusMenuItem('PENDING', 'Menunggu'),
                _statusMenuItem('REJECTED', 'Ditolak'),
                _statusMenuItem('CANCELLED', 'Dibatalkan'),
              ],
            ),
          if (_showSalesMenu)
            _buildOverlayMenu(
              maxHeight: 280,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _salesMenuItem(null, 'Semua Sales'),
                    ...salesList.map(
                      (s) => _salesMenuItem(s.userId, s.displayName),
                    ),
                  ],
                ),
              ),
            ),
          if (_showBranchMenu)
            _buildOverlayMenu(
              maxHeight: 240,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _branchMenuItems(branchList),
                ),
              ),
            ),
          if (_showDateFromPicker)
            _buildDatePicker(
              initial:
                  _dateFrom ??
                  DateTime.now().subtract(const Duration(days: 30)),
              onSelect: _selectDateFrom,
              onClose: () => setState(() => _showDateFromPicker = false),
            ),
          if (_showDateToPicker)
            _buildDatePicker(
              initial: _dateTo ?? DateTime.now(),
              onSelect: _selectDateTo,
              onClose: () => setState(() => _showDateToPicker = false),
            ),
        ],
      );
    }

    // Desktop: stacked vertically dengan menu overlay relatif ke summary box.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            summaryBox,
            const SizedBox(height: 16),
            const Text(
              'Filter',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < filterButtons.length; i++) ...[
              filterButtons[i],
              if (i < filterButtons.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
        if (_showStatusMenu)
          _buildOverlayMenu(
            top: 100, // approx. di bawah summary box
            children: [
              _statusMenuItem(null, 'Semua'),
              _statusMenuItem('APPROVED', 'Disetujui'),
              _statusMenuItem('PENDING', 'Menunggu'),
              _statusMenuItem('REJECTED', 'Ditolak'),
              _statusMenuItem('CANCELLED', 'Dibatalkan'),
            ],
          ),
        if (_showSalesMenu)
          _buildOverlayMenu(
            top: 100,
            maxHeight: 280,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _salesMenuItem(null, 'Semua Sales'),
                  ...salesList.map(
                    (s) => _salesMenuItem(s.userId, s.displayName),
                  ),
                ],
              ),
            ),
          ),
        if (_showBranchMenu)
          _buildOverlayMenu(
            top: 100,
            maxHeight: 240,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _branchMenuItems(branchList),
              ),
            ),
          ),
        if (_showDateFromPicker)
          _buildDatePicker(
            initial:
                _dateFrom ?? DateTime.now().subtract(const Duration(days: 30)),
            onSelect: _selectDateFrom,
            onClose: () => setState(() => _showDateFromPicker = false),
          ),
        if (_showDateToPicker)
          _buildDatePicker(
            initial: _dateTo ?? DateTime.now(),
            onSelect: _selectDateTo,
            onClose: () => setState(() => _showDateToPicker = false),
          ),
      ],
    );
  }

  Widget _buildSummaryStat({
    required String label,
    required String value,
    required Color color,
    bool isLarge = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: isLarge ? 13 : 12,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required VoidCallback onTap,
    IconData? leadingIcon,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 140, // fixed width di compact untuk scroll horizontal
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayMenu({
    double? top,
    double? maxHeight,
    List<Widget> children = const [],
    Widget? child,
  }) {
    return Positioned(
      top: top ?? 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(6),
        color: AppColors.surface,
        child: Container(
          constraints: maxHeight != null
              ? BoxConstraints(maxHeight: maxHeight)
              : null,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child:
              child ??
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
        ),
      ),
    );
  }

  // ===== Order list (loading/error/empty/list) =====
  Widget _buildOrderList(List<Order> orders, bool loading, String? error) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 36),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _applyFilters,
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }
    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, color: AppColors.textMuted, size: 36),
            SizedBox(height: 8),
            Text(
              'Tidak ada pesanan.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (ctx, i) =>
          _buildOrderCard(orders[i], compact: widget.compact),
    );
  }

  Widget _buildOrderCard(Order order, {bool compact = false}) {
    final statusColor = _statusColor(order.status);
    final isExpanded = _expandedOrderId == order.id;
    final amountBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Rp ${_fmt(order.totalAmount)}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.primary,
          ),
        ),
        if (order.totalDiscount > 0)
          Text(
            '-Rp ${_fmt(order.totalDiscount)}',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (order.totalUpPrice > 0)
          Text(
            '+Rp ${_fmt(order.totalUpPrice)}',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
    final statusBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        _statusLabel(order.status),
        style: TextStyle(
          color: statusColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final expandIcon = Icon(
      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
      size: 18,
      color: isExpanded ? AppColors.primary : AppColors.textMuted,
    );

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _expandedOrderId = isExpanded ? null : order.id;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isExpanded
                  ? AppColors.primary.withValues(alpha: 0.04)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isExpanded
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.border,
              ),
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Baris 1: nama toko + status + arrow
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.storeName ?? 'Toko Tidak Diketahui',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          statusBadge,
                          const SizedBox(width: 4),
                          expandIcon,
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Baris 2: meta info (id, items, date) — wrap kalau sempit
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '#${order.id.substring(0, 8)}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 11,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${order.items.length} item',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 11,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _formatDate(order.createdAt),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Baris 3: amount + discount + upPrice (right-aligned)
                      Align(
                        alignment: Alignment.centerRight,
                        child: amountBlock,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.storeName ?? 'Toko Tidak Diketahui',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '#${order.id.substring(0, 8)}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 11,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${order.items.length} item',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 11,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  _formatDate(order.createdAt),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      amountBlock,
                      const SizedBox(width: 8),
                      statusBadge,
                      const SizedBox(width: 6),
                      expandIcon,
                    ],
                  ),
          ),
        ),
        if (isExpanded) _buildOrderExpandedDetail(order, compact: compact),
      ],
    );
  }

  Widget _buildOrderExpandedDetail(Order order, {bool compact = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order.customerName != null)
            _detailRow('Customer', order.customerName!),
          if (order.storeContact != null)
            _detailRow('Kontak', order.storeContact!),
          if (order.storeAddress != null)
            _detailRow('Alamat', order.storeAddress!),
          if (order.invoiceNumber != null)
            _detailRow('Invoice', order.invoiceNumber!),
          if (order.notes != null && order.notes!.isNotEmpty)
            _detailRow('Catatan', order.notes!),
          if (order.rejectReason != null && order.rejectReason!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Alasan Penolakan',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.rejectReason!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          const Text(
            'Item Pesanan',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          // Items table — di compact mode (mobile), wrap dengan horizontal
          // scroll supaya kolom tabel tidak overflow layar sempit.
          // Lebar minimum table: 100 (produk flex:2) + 50 + 70 + 75 + 75 + 80
          // + 16 padding = 466px. Layar 360-414px harus scroll horizontal.
          _buildItemTable(order, compact: compact),
        ],
      ),
    );
  }

  /// Render item table (header + items + cancelled items) di dalam
  /// horizontal scroll kalau compact, atau pas-lebar kalau desktop.
  Widget _buildItemTable(Order order, {bool compact = false}) {
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Produk',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              'Qty',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              'Harga',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          SizedBox(
            width: 75,
            child: Text(
              'Diskon',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          SizedBox(
            width: 75,
            child: Text(
              'Up Price',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              'Subtotal',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
    final rows = <Widget>[
      header,
      const SizedBox(height: 4),
      ...order.items.map((item) => _itemRow(item)),
      if (order.cancelledItems.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text(
          'Item Dibatalkan',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: 4),
        ...order.cancelledItems.map((ci) => _cancelledItemRow(ci)),
      ],
    ];
    if (!compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      );
    }
    // Compact: inner Column dibungkus lebar pasti 466px, di-scroll horizontal.
    // Wajib SizedBox (bukan ConstrainedBox minWidth): Expanded di dalam Row
    // butuh width bounded, minWidth-only bikin constraint maxWidth = infinity.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 466,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        ),
      ),
    );
  }

  Widget _statusMenuItem(String? value, String label) {
    final isSelected = _statusFilter == value;
    return GestureDetector(
      onTap: () => _selectStatus(value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.primary : null,
          ),
        ),
      ),
    );
  }

  Widget _salesMenuItem(String? value, String label) {
    final isSelected = _salesFilter == value;
    return GestureDetector(
      onTap: () => _selectSales(value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.primary : null,
          ),
        ),
      ),
    );
  }

  /// Bangun list menu item untuk Branch dropdown. Extract unique branch codes
  /// dari items (preserve first-seen order). Item dengan branch null
  /// ditampilkan sebagai "Tanpa branch".
  List<Widget> _branchMenuItems(List<SalesPerformanceDashboardItem> items) {
    final branches = <String>[];
    final seen = <String>{};
    for (final s in items) {
      final key = s.branch ?? '';
      if (!seen.contains(key)) {
        seen.add(key);
        branches.add(key);
      }
    }
    return [
      _branchMenuItem(null, 'Semua Cabang'),
      ...branches.map(
        (b) => _branchMenuItem(b, b.isEmpty ? 'Tanpa branch' : b),
      ),
    ];
  }

  Widget _branchMenuItem(String? value, String label) {
    final isSelected = _branchFilter == value;
    return GestureDetector(
      onTap: () => _selectBranch(value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.primary : null,
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required DateTime initial,
    required void Function(DateTime) onSelect,
    required VoidCallback onClose,
  }) {
    DateTime focused = initial;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: AppColors.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Month navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 18),
                    onPressed: () {
                      setState(() {
                        focused = DateTime(focused.year, focused.month - 1);
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${_monthName(focused.month)} ${focused.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    onPressed: () {
                      setState(() {
                        focused = DateTime(focused.year, focused.month + 1);
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
            ),
            // Day headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: ['S', 'S', 'R', 'K', 'J', 'J', 'S']
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 4),
            // Days grid
            Builder(
              builder: (ctx) {
                final firstDay = DateTime(focused.year, focused.month, 1);
                final lastDay = DateTime(focused.year, focused.month + 1, 0);
                final startWeekday = firstDay.weekday % 7;
                final days = <Widget>[];
                for (int i = 0; i < startWeekday; i++) {
                  days.add(const SizedBox());
                }
                for (int d = 1; d <= lastDay.day; d++) {
                  final date = DateTime(focused.year, focused.month, d);
                  final isSelected =
                      _dateFrom != null &&
                      date.year == _dateFrom!.year &&
                      date.month == _dateFrom!.month &&
                      date.day == _dateFrom!.day;
                  days.add(
                    GestureDetector(
                      onTap: () => onSelect(date),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$d',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? Colors.white : null,
                            fontWeight: isSelected ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    children: days,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return names[month - 1];
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(OrderItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: item.isFree
          ? BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.namaBarang,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.isFree) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'GRATIS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              '${item.qty}',
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 70,
            child: item.isFree
                ? Text(
                    'Rp ${_fmt(item.hargaSatuan)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      decoration: TextDecoration.lineThrough,
                    ),
                  )
                : Text(
                    'Rp ${_fmt(item.hargaSatuan)}',
                    style: const TextStyle(fontSize: 11),
                  ),
          ),
          SizedBox(
            width: 75,
            child: item.isFree
                ? Text(
                    '-Rp ${_fmt(item.nominalDiskon)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  )
                : item.hasDiscount
                ? Text(
                    '-Rp ${_fmt(item.nominalDiskon)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  )
                : const Text(
                    '—',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    textAlign: TextAlign.right,
                  ),
          ),
          SizedBox(
            width: 75,
            child: item.hasUpPrice
                ? Text(
                    '+Rp ${_fmt(item.nominalUpPrice)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  )
                : const Text(
                    '—',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    textAlign: TextAlign.right,
                  ),
          ),
          SizedBox(
            width: 80,
            child: item.isFree
                ? const Text(
                    'Rp 0',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.right,
                  )
                : Text(
                    'Rp ${_fmt(item.subtotal)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _cancelledItemRow(CancelledItem ci) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined, size: 12, color: AppColors.error),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Text(
              ci.namaBarang ?? ci.productId,
              style: const TextStyle(fontSize: 11, color: AppColors.error),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              '${ci.qty}',
              style: const TextStyle(fontSize: 11, color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              'Rp ${_fmt(ci.hargaSatuan ?? 0)}',
              style: const TextStyle(fontSize: 11, color: AppColors.error),
            ),
          ),
          const SizedBox(width: 75),
          const SizedBox(width: 75),
          SizedBox(
            width: 80,
            child: Text(
              'Rp ${_fmt(ci.subtotal ?? 0)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
