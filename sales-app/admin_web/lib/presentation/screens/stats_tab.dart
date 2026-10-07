import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/design_system.dart';
import '../../core/web_download.dart';
import '../../data/models/sales_performance.dart';
import '../providers/admin_provider.dart';

String _fmt(int amount) =>
    NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(amount);

class StatsTab extends StatefulWidget {
  final String role;

  const StatsTab({super.key, required this.role});

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
      _triggerBrowserDownload(Uint8List.fromList(bytes),
          'laporan-harian-$dateStr.xlsx');
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
      _triggerBrowserDownload(Uint8List.fromList(bytes),
          'laporan-periode-$startStr-sd-$endStr.xlsx');
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
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'Belum ada data performa sales.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: sales.map((s) => _SalesPerformanceCard(
        s: s,
        onTap: () => _openSalesDetail(provider, s),
      )).toList(),
    );
  }

  void _openSalesDetail(AdminProvider provider, SalesPerformanceDashboardItem s) {
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
          onClose: () {
            provider.clearSalesDetailOrders();
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

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
    final totalProducts = stats['total_products'] ?? 0;
    final totalCustomers = stats['total_customers'] ?? 0;
    // Produk di mana stok_sistem < (stok_booking + stok_diterima) — perlu audit segera.
    // Dilaporkan backend di /products/stats. Definisi predicate di-update
    // setelah revisi sistem stok (stok_diterima pisah dari stok_booking).
    final needsReview = stats['needs_review'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ringkasan Sistem', style: AppTextStyles.headlineLarge),
          const SizedBox(height: 8),
          const Text(
            'Pesanan hari ini, ringkasan data master, dan ambil laporan',
            style: AppTextStyles.bodyMedium,
          ),

          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.errorBg,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppColors.error, size: 20),
                      tooltip: 'Coba lagi',
                      onPressed: () => provider.loadAll(),
                    ),
                  ],
                ),
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
            const SizedBox(height: 20),
            // Section: order hari ini
            const Padding(
              padding: EdgeInsets.only(bottom: 12, left: 4),
              child: Text('Pesanan Hari Ini', style: AppTextStyles.labelLarge),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  title: 'Total Pesanan',
                  value: '$totalOrders',
                  icon: Icons.shopping_cart,
                  color: AppColors.info,
                ),
                _StatCard(
                  title: 'Menunggu Persetujuan',
                  value: '$pendingOrders',
                  icon: Icons.pending_actions,
                  color: AppColors.warning,
                ),
                _StatCard(
                  title: 'Disetujui',
                  value: '$approvedOrders',
                  icon: Icons.check_circle,
                  color: AppColors.success,
                ),
                _StatCard(
                  title: 'Ditolak',
                  value: '$rejectedOrders',
                  color: AppColors.error,
                  icon: Icons.cancel,
                ),
                _StatCard(
                  title: 'Dibatalkan',
                  value: '$cancelledOrders',
                  color: AppColors.textMuted,
                  icon: Icons.block,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Section: data master (total keseluruhan, bukan per hari)
            const Padding(
              padding: EdgeInsets.only(bottom: 12, left: 4),
              child: Text('Data Master', style: AppTextStyles.labelLarge),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  title: 'Total Produk',
                  value: '$totalProducts',
                  icon: Icons.inventory_2,
                  color: AppColors.primary,
                ),
                _StatCard(
                  title: 'Total Toko',
                  value: '$totalCustomers',
                  icon: Icons.store,
                  color: AppColors.info,
                ),
                _StatCard(
                  title: 'Produk Perlu Tinjau',
                  value: '$needsReview',
                  icon: Icons.report_problem_outlined,
                  // Warna bahaya kalau ada yang perlu ditinjau, netral kalau 0.
                  color: needsReview > 0 ? AppColors.error : AppColors.success,
                ),
              ],
            ),

            // MANAGER only: Performa Sales quick summary
            if (widget.role == 'MANAGER') ...[
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(bottom: 12, left: 4),
                child: Text('Performa Sales', style: AppTextStyles.labelLarge),
              ),
              _buildSalesPerformanceSection(provider),
            ],

            const SizedBox(height: 32),
            // Laporan
            const Text('Ambil Laporan', style: AppTextStyles.headlineLarge),
            const SizedBox(height: 16),
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
            const SizedBox(height: 36),
            Row(
              children: [
                const Text('Pesanan Perlu Tindakan', style: AppTextStyles.headlineLarge),
                const SizedBox(width: 12),
                if (pending.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.warningBorder),
                    ),
                    child: Text(
                      '${pending.length}',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (pending.isNotEmpty)
              ...pending.take(5).map((order) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.warningBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.store,
                                  color: AppColors.warning, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.storeName ?? 'Toko Tidak Diketahui',
                                    style: AppTextStyles.labelLarge,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Order #${order.id.substring(0, 8)} • ${order.items.length} item • Rp ${_fmt(order.totalAmount)}',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.warningBg,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: AppColors.warningBorder),
                              ),
                              child: const Text(
                                'Menunggu',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ))
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle,
                            color: AppColors.success, size: 32),
                      ),
                      const SizedBox(width: 20),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Semua pesanan sudah diproses',
                              style: AppTextStyles.headlineSmall),
                          SizedBox(height: 4),
                          Text(
                            'Tidak ada pesanan yang menunggu persetujuan',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.date_range,
                    color: AppColors.info,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Laporan Periode', style: AppTextStyles.headlineSmall),
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
                        horizontal: 14, vertical: 14),
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
                        horizontal: 14, vertical: 14),
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
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'APPROVED', child: Text('Disetujui')),
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
                FilledButton.icon(
                  onPressed: downloading ? null : onDownload,
                  icon: downloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: Text(
                    downloading ? 'Mengunduh...' : 'Download Periode',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.info,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Default: 30 hari ke belakang • Status default: Disetujui',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.today,
                    color: AppColors.info,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Laporan Harian', style: AppTextStyles.headlineSmall),
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
                        horizontal: 14, vertical: 14),
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
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'APPROVED', child: Text('Disetujui')),
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
                FilledButton.icon(
                  onPressed: downloading ? null : onDownload,
                  icon: downloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: Text(
                    downloading ? 'Mengunduh...' : 'Download Harian',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.info,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Status default: Disetujui',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesPerformanceCard extends StatelessWidget {
  final SalesPerformanceDashboardItem s;
  final VoidCallback onTap;

  const _SalesPerformanceCard({required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  s.displayName.isNotEmpty ? s.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusSection(
            label: 'Diterima',
            mtdCount: s.approvedMtdCount,
            mtdRevenue: s.approvedMtdRevenue,
            todayCount: s.approvedTodayCount,
            todayRevenue: s.approvedTodayRevenue,
            color: AppColors.success,
          ),
          const Divider(height: 20),
          _buildStatusSection(
            label: 'Pending',
            mtdCount: s.pendingMtdCount,
            mtdRevenue: s.pendingMtdRevenue,
            todayCount: s.pendingTodayCount,
            todayRevenue: s.pendingTodayRevenue,
            color: AppColors.warning,
          ),
          const Divider(height: 20),
          _buildStatusSection(
            label: 'Ditolak',
            mtdCount: s.rejectedMtdCount,
            mtdRevenue: s.rejectedMtdRevenue,
            todayCount: s.rejectedTodayCount,
            todayRevenue: s.rejectedTodayRevenue,
            color: AppColors.error,
          ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildStatusSection({
    required String label,
    required int mtdCount,
    required int mtdRevenue,
    required int todayCount,
    required int todayRevenue,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MTD', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    '$mtdCount order',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Rp ${_fmt(mtdRevenue)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hari ini', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    '$todayCount order',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Rp ${_fmt(todayRevenue)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ===== Popup detail order untuk sales performance card =====
class _SalesOverlayDialog extends StatelessWidget {
  final AdminProvider provider;
  final SalesPerformanceDashboardItem sales;
  final VoidCallback onClose;

  const _SalesOverlayDialog({
    required this.provider,
    required this.sales,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        elevation: 8,
        child: SizedBox(
          width: 800,
          height: 520,
          child: _SalesDetailDialogBody(
            provider: provider,
            sales: sales,
            onClose: onClose,
          ),
        ),
      ),
    );
  }
}

class _SalesDetailDialogBody extends StatefulWidget {
  final AdminProvider provider;
  final SalesPerformanceDashboardItem sales;
  final VoidCallback onClose;

  const _SalesDetailDialogBody({
    required this.provider,
    required this.sales,
    required this.onClose,
  });

  @override
  State<_SalesDetailDialogBody> createState() => _SalesDetailDialogBodyState();
}

class _SalesDetailDialogBodyState extends State<_SalesDetailDialogBody> {
  String? _statusFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _showStatusMenu = false;
  bool _showDateFromPicker = false;
  bool _showDateToPicker = false;

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }

  void _applyFilters() {
    widget.provider.loadSalesDetailOrders(
      salesId: widget.sales.userId,
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
      case 'APPROVED': return AppColors.success;
      case 'PENDING': return AppColors.warning;
      case 'REJECTED': return AppColors.error;
      case 'CANCELLED': return AppColors.textMuted;
      default: return AppColors.info;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED': return 'Diterima';
      case 'PENDING': return 'Pending';
      case 'REJECTED': return 'Ditolak';
      case 'CANCELLED': return 'Dibatalkan';
      default: return status;
    }
  }

  String _currentStatusLabel() {
    if (_statusFilter == null) return 'Semua';
    return _statusLabel(_statusFilter!);
  }

  void _selectStatus(String? v) {
    setState(() {
      _statusFilter = v;
      _showStatusMenu = false;
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
    final provider = context.watch<AdminProvider>();
    final orders = provider.salesDetailOrders;
    final loading = provider.salesDetailLoading;
    final error = provider.salesDetailError;

    final totalOrders = orders.length;
    final totalRevenue = orders.fold<int>(0, (sum, o) => sum + o.totalAmount);

    return GestureDetector(
      onTap: () {
        // Close any open picker menus
        setState(() {
          _showStatusMenu = false;
          _showDateFromPicker = false;
          _showDateToPicker = false;
        });
      },
      child: SizedBox(
        width: 800,
        height: 520,
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
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      widget.sales.displayName.isNotEmpty
                          ? widget.sales.displayName[0].toUpperCase()
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
                          widget.sales.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        Text(
                          '@${widget.sales.username}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            // Body: horizontal split
            Expanded(
              child: Row(
                children: [
                  // Left sidebar: summary + filters
                  Container(
                    width: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(right: BorderSide(color: AppColors.border)),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Summary
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Column(
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
                                ],
                              ),
                            ),
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
                            // Status filter button
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showStatusMenu = !_showStatusMenu;
                                  _showDateFromPicker = false;
                                  _showDateToPicker = false;
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      _currentStatusLabel(),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.arrow_drop_down, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Date from button
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showDateFromPicker = !_showDateFromPicker;
                                  _showDateToPicker = false;
                                  _showStatusMenu = false;
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 13, color: AppColors.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      _dateFrom != null ? _formatDate(_dateFrom!) : 'Dari tanggal',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Date to button
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showDateToPicker = !_showDateToPicker;
                                  _showDateFromPicker = false;
                                  _showStatusMenu = false;
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 13, color: AppColors.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      _dateTo != null ? _formatDate(_dateTo!) : 'Sampai tanggal',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_dateFrom != null || _dateTo != null) ...[
                              const SizedBox(height: 6),
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
                            ],
                          ],
                        ),
                        // Status dropdown menu (inline, not overlay)
                        if (_showStatusMenu)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(6),
                              color: AppColors.surface,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _statusMenuItem(null, 'Semua'),
                                    _statusMenuItem('APPROVED', 'Diterima'),
                                    _statusMenuItem('PENDING', 'Pending'),
                                    _statusMenuItem('REJECTED', 'Ditolak'),
                                    _statusMenuItem('CANCELLED', 'Dibatalkan'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        // Date from picker
                        if (_showDateFromPicker)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: _buildDatePicker(
                              initial: _dateFrom ?? DateTime.now().subtract(const Duration(days: 30)),
                              onSelect: _selectDateFrom,
                              onClose: () => setState(() => _showDateFromPicker = false),
                            ),
                          ),
                        // Date to picker
                        if (_showDateToPicker)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: _buildDatePicker(
                              initial: _dateTo ?? DateTime.now(),
                              onSelect: _selectDateTo,
                              onClose: () => setState(() => _showDateToPicker = false),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Right: order list
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : error != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline, color: AppColors.error, size: 36),
                                    const SizedBox(height: 8),
                                    Text(error, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: _applyFilters,
                                      child: const Text('Coba lagi'),
                                    ),
                                  ],
                                ),
                              )
                            : orders.isEmpty
                                ? const Center(
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
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: orders.length,
                                    itemBuilder: (ctx, i) {
                                      final order = orders[i];
                                      final statusColor = _statusColor(order.status);
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Row(
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
                                            Text(
                                              'Rp ${_fmt(order.totalAmount)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: statusColor.withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Text(
                                                _statusLabel(order.status),
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            ),
          ],
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
        color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
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
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  Expanded(
                    child: Text(
                      '${_monthName(focused.month)} ${focused.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),
            // Day headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: ['S', 'S', 'R', 'K', 'J', 'J', 'S']
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(d, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 4),
            // Days grid
            Builder(builder: (ctx) {
              final firstDay = DateTime(focused.year, focused.month, 1);
              final lastDay = DateTime(focused.year, focused.month + 1, 0);
              final startWeekday = firstDay.weekday % 7;
              final days = <Widget>[];
              for (int i = 0; i < startWeekday; i++) {
                days.add(const SizedBox());
              }
              for (int d = 1; d <= lastDay.day; d++) {
                final date = DateTime(focused.year, focused.month, d);
                final isSelected = _dateFrom != null && date.year == _dateFrom!.year && date.month == _dateFrom!.month && date.day == _dateFrom!.day;
                days.add(
                  GestureDetector(
                    onTap: () => onSelect(date),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
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
            }),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
                   'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return names[month - 1];
  }
}
