import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/design_system.dart';
import '../../core/web_download.dart';
import '../providers/admin_provider.dart';

String _fmt(int amount) =>
    NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(amount);

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  DateTime _selectedDate = DateTime.now();
  String _statusFilter = 'APPROVED';
  bool _downloading = false;

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

  /// Trigger download file di browser. dart:html cuma jalan di web — helper
  /// web_download.dart pakai conditional import jadi aman waktu build.
  void _triggerBrowserDownload(Uint8List bytes, String filename) {
    if (kIsWeb) {
      triggerBrowserDownload(bytes, filename);
    }
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
    final totalProducts = stats['total_products'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ringkasan Sistem', style: AppTextStyles.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Pantau performa order dan status stok secara keseluruhan',
            style: AppTextStyles.bodyMedium,
          ),

          // Error card — tampilkan kalau ada error
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
                        style: TextStyle(color: AppColors.error, fontSize: 13),
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

          // Loading overlay — skeleton placeholder
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
            _ReportDownloadCard(
              selectedDate: _selectedDate,
            statusFilter: _statusFilter,
            downloading: _downloading,
            onPickDate: _pickDate,
            onChangeStatus: (s) => setState(() => _statusFilter = s),
            onDownload: _downloadReport,
          ),
          const SizedBox(height: 28),
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
                icon: Icons.cancel,
                color: AppColors.error,
              ),
              _StatCard(
                title: 'Total Produk',
                value: '$totalProducts',
                icon: Icons.inventory_2,
                color: AppColors.primary,
              ),
            ],
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Semua pesanan sudah diproses',
                            style: AppTextStyles.headlineSmall),
                        const SizedBox(height: 4),
                        const Text(
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
    final todayLabel = DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.now());
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

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
                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.file_download_outlined,
                    color: AppColors.primaryLight,
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
                        'Export data order ke Excel per hari',
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
                    downloading
                        ? 'Mengunduh...'
                        : isToday
                            ? 'Download Laporan Hari Ini'
                            : 'Download Laporan $dateLabel',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tanggal sekarang: $todayLabel • Status default: Disetujui',
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
