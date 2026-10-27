import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/design_system.dart';
import '../../core/responsive.dart';
import '../providers/admin_provider.dart';

/// Tab "Data Penjualan": melihat & menganalisis data hasil import laporan
/// penjualan dari file Excel (admin_web import feature). Admin bisa upload file,
/// Supervisor/Manager bisa melihat analisis per bulan.
class ImportedSalesTab extends StatefulWidget {
  const ImportedSalesTab({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  State<ImportedSalesTab> createState() => _ImportedSalesTabState();
}

class _ImportedSalesTabState extends State<ImportedSalesTab> {
  final _monthController = TextEditingController();
  final bool _importing = false;

  @override
  void initState() {
    super.initState();
    _monthController.text = _currentMonth();
    _loadSummary();
  }

  String _currentMonth() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> _loadSummary() async {
    await context.read<AdminProvider>().loadImportedSalesSummary(
          month: _monthController.text.trim(),
        );
  }

  Future<void> _pickAndImport(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membaca file'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final provider = context.read<AdminProvider>();
    final success = await provider.importSalesExcel(file.bytes!, file.name);
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import laporan penjualan berhasil'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadSummary();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AdminProvider>().errorMessage ?? 'Import gagal'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final summary = provider.importedSalesSummary;
    final isLoading = provider.importedSalesLoading;
    final errorMessage = provider.importedSalesError;

    return LayoutBuilder(
      builder: (context, constraints) {
        final resp = Responsive.of(constraints.maxWidth);
        return SingleChildScrollView(
          padding: EdgeInsets.all(resp.contentPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(
                title: 'Data Penjualan',
                subtitle:
                    'Analisis data penjualan dari laporan file Excel yang di-import admin.',
              ),
              if (errorMessage != null) _ErrorCard(message: errorMessage),
              if (isLoading && summary == null) const _LoadingView(),
              if (summary != null) ...[
                _PeriodCard(
                  controller: _monthController,
                  readOnly: widget.readOnly,
                  onApply: _loadSummary,
                ),
                _StatsGrid(summary: summary),
                _BreakdownCard(
                  title: 'Rekap per Produk',
                  rows: _asMapList(summary['by_product']),
                  label: (r) =>
                      '${r['product_nama'] ?? ''} (${r['product_kode'] ?? ''})'.trim(),
                  value: (r) => '${_toInt(r['qty'])} x ${_toInt(r['revenue'])}',
                ),
                _BreakdownCard(
                  title: 'Rekap per Sales',
                  rows: _asMapList(summary['by_sales']),
                  label: (r) =>
                      '${r['sales_nama'] ?? ''} (${r['sales_kode'] ?? ''})'.trim(),
                  value: (r) => '${_toInt(r['qty'])} x ${_toInt(r['revenue'])}',
                ),
                _BreakdownCard(
                  title: 'Rekap per Pelanggan',
                  rows: _asMapList(summary['by_customer']),
                  label: (r) =>
                      '${r['customer_nama'] ?? ''} (${r['customer_kode'] ?? ''})'.trim(),
                  value: (r) => '${_toInt(r['qty'])} x ${_toInt(r['revenue'])}',
                ),
                _BreakdownCard(
                  title: 'Rekap per Channel',
                  rows: _asMapList(summary['by_channel']),
                  label: (r) => (r['channel'] ?? 'Tidak Diketahui').toString(),
                  value: (r) => '${_toInt(r['qty'])} x ${_toInt(r['revenue'])}',
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (!widget.readOnly) ...[
                const SizedBox(height: AppSpacing.lg),
                _ImportCard(onPick: () => _pickAndImport(context), importing: _importing),
                const SizedBox(height: AppSpacing.lg),
                if (provider.salesImportResult != null)
                  _ImportResultCard(result: provider.salesImportResult!),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.errorBg,
      borderColor: AppColors.errorBorder,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
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
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final TextEditingController controller;
  final bool readOnly;
  final VoidCallback onApply;

  const _PeriodCard({
    required this.controller,
    required this.readOnly,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Periode',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AppInput(
              label: 'Bulan',
              controller: controller,
              readOnly: readOnly,
              keyboardType: TextInputType.text,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppButton(
            label: 'Muat',
            icon: Icons.refresh,
            onPressed: onApply,
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _StatsGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final totalRevenue = _toInt(summary['total_revenue']);
    final totalQty = _toInt(summary['total_qty']);
    final rows = _toInt(summary['imported_rows']);

    return AppResponsiveGrid(
      desktopCols: 3,
      tabletCols: 2,
      mobileCols: 1,
      children: [
        AppStatCard(
          title: 'Total Penjualan',
          value: totalRevenue.toString(),
          icon: Icons.receipt_long_outlined,
        ),
        AppStatCard(
          title: 'Total Qty Terjual',
          value: totalQty.toString(),
          icon: Icons.inventory_2_outlined,
        ),
        AppStatCard(
          title: 'Baris Transaksi',
          value: rows.toString(),
          icon: Icons.table_rows_outlined,
        ),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> rows;
  final String Function(Map<String, dynamic>) label;
  final String Function(Map<String, dynamic>) value;

  const _BreakdownCard({
    required this.title,
    required this.rows,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: title,
      child: rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Belum ada data untuk periode ini.',
                style: AppTextStyles.bodyMuted,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in rows) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(label(r), style: AppTextStyles.body)),
                        const SizedBox(width: AppSpacing.sm + 4),
                        Flexible(
                          child: Text(
                            value(r),
                            textAlign: TextAlign.end,
                            style: AppTextStyles.h3.copyWith(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                ],
              ],
            ),
    );
  }
}

class _ImportCard extends StatelessWidget {
  final VoidCallback onPick;
  final bool importing;

  const _ImportCard({required this.onPick, required this.importing});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Import Laporan Penjualan',
      subtitle: 'Upload file .xlsx berisi laporan penjualan dari sistem utama.',
      child: AppButton(
        label: importing ? 'Mengimport...' : 'Pilih File Excel (.xlsx)',
        icon: Icons.folder_open,
        isLoading: importing,
        isFullWidth: true,
        onPressed: onPick,
      ),
    );
  }
}

class _ImportResultCard extends StatelessWidget {
  final Map<String, dynamic> result;

  const _ImportResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final success = result['success'] == true;
    final inserted = _toInt(result['inserted']);
    final skipped = _toInt(result['skipped']);
    final totalRows = _toInt(result['total_rows']);

    return AppCard(
      title: 'Hasil Import',
      child: Text(
        success
            ? 'Berhasil memproses $totalRows baris — $inserted disisipkan, $skipped dilewati.'
            : 'Proses import tidak selesai. Periksa error pada riwayat import.',
        style: AppTextStyles.body,
      ),
    );
  }
}

int _toInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

List<Map<String, dynamic>> _asMapList(dynamic v) {
  if (v is List) {
    return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return [];
}
