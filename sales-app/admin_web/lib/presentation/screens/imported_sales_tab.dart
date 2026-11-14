import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_system.dart';
import '../../core/responsive.dart';
import '../../data/models/branch_report.dart';
import '../../data/repositories/admin_repository.dart';
import '../providers/admin_provider.dart';
import '../widgets/analytics/sales_analytics_models.dart';
import '../widgets/analytics/sales_cards.dart';
import '../widgets/analytics/sales_charts.dart';
import '../widgets/import_progress.dart';

/// Data Penjualan: an analytics view over the imported Excel report.
///
/// Layout: hero (month revenue + daily sparkline) → division stats → rule-based
/// insights → daily trend + channel composition → product/sales/customer
/// rankings. All numbers come from one summary payload that the provider only
/// re-downloads when the cheap version probe reports a change.
class ImportedSalesTab extends StatefulWidget {
  const ImportedSalesTab({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  State<ImportedSalesTab> createState() => _ImportedSalesTabState();
}

class _ImportedSalesTabState extends State<ImportedSalesTab> {
  static const int _maxUploadBytes = 70 * 1024 * 1024;
  static const int _largeUploadWarningBytes = 20 * 1024 * 1024;

  late DateTime _month;
  bool _importing = false;
  bool _importingReturn = false;
  bool _importingTarget = false;
  Map<String, dynamic>? _dismissedImportResult;
  Map<String, dynamic>? _dismissedReturnImportResult;
  Map<String, dynamic>? _dismissedTargetImportResult;

  bool get _isImporting => _importing || _importingReturn || _importingTarget;

  @override
  void initState() {
    super.initState();
    _month = _initialMonth();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AdminProvider>();
      _loadSummary();
      if (provider.isGlobalManager && provider.branchOptions.isEmpty) {
        provider.loadBranchOptions();
      }
    });
  }

  DateTime _initialMonth() {
    final stored = context.read<AdminProvider>().importedSalesMonth;
    final parsed = stored == null ? null : _parseMonth(stored);
    if (parsed != null) return parsed;
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  String get _monthKey =>
      '${_month.year.toString().padLeft(4, '0')}-'
      '${_month.month.toString().padLeft(2, '0')}';

  Future<void> _loadSummary({bool forceRefresh = false, int? limit}) async {
    // Ringkasan dashboard selalu satu bulan terpilih. Chip di toolbar adalah
    // pembanding (N bulan sebelumnya), bukan agregasi multi-bulan.
    await context.read<AdminProvider>().loadImportedSalesSummary(
      month: _monthKey,
      forceRefresh: forceRefresh,
      limit: limit,
      rangeMonths: 1,
    );
  }

  Future<void> _changeMonth(DateTime next) async {
    final normalized = DateTime(next.year, next.month);
    if (normalized == _month) return;
    setState(() => _month = normalized);
    await _loadSummary();
  }

  Future<void> _changeBranch(String? branch) async {
    final provider = context.read<AdminProvider>();
    if (provider.importedSalesBranchFilter == branch) return;
    provider.setImportedSalesBranchFilter(branch);
    await _loadSummary();
  }

  Future<void> _changeComparison(int months) async {
    await context.read<AdminProvider>().setImportedSalesComparisonMonths(
      months,
    );
  }

  String _comparisonLabel(int months) {
    final now = _month;
    final end = DateTime(now.year, now.month - 1);
    final start = DateTime(now.year, now.month - months);
    if (months == 1) return 'Bulan lalu (${formatMonthShort(end)})';
    return '$months Bulan Sebelumnya (${formatMonthShort(start)}–${formatMonthShort(end)})';
  }

  Future<void> _pickMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPickerDialog(initial: _month),
    );
    if (picked != null) await _changeMonth(picked);
  }

  Future<void> _pickAndImport(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.size > _maxUploadBytes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ukuran file maksimal 70 MB'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    if (file.size > _largeUploadWarningBytes && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'File besar sedang diproses. Import dapat memakan beberapa menit; jangan tutup halaman.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    }
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
    setState(() => _importing = true);
    final success = await ImportProgressOverlay.run<bool>(
      context,
      title: 'Mengimport Laporan Penjualan',
      fileName: file.name,
      fileSize: file.size,
      progressFetcher: provider.fetchImportProgress,
      task: (session) => provider.importSalesExcel(
        file.bytes!,
        file.name,
        jobId: session.jobId,
        onSendProgress: session.onSendProgress,
      ),
    );
    if (!context.mounted) return;
    setState(() => _importing = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import laporan penjualan berhasil'),
          backgroundColor: AppColors.success,
        ),
      );
      // Re-download only when the import actually changed data (versions
      // bumped). A pure re-import keeps the cached snapshot valid, so the
      // normal version probe can skip the summary GET.
      final versions = provider.salesImportResult?['versions'];
      final changed = versions is! List || versions.isNotEmpty;
      await _loadSummary(forceRefresh: changed);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Import gagal'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickAndImportReturns(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.size > 10 * 1024 * 1024) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ukuran file retur maksimal 10 MB'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    if (file.bytes == null || file.bytes!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membaca file retur'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final provider = context.read<AdminProvider>();
    setState(() => _importingReturn = true);
    final success = await ImportProgressOverlay.run<bool>(
      context,
      title: 'Mengimport Laporan Retur',
      fileName: file.name,
      fileSize: file.size,
      progressFetcher: provider.fetchImportProgress,
      task: (session) => provider.importSalesReturnsExcel(
        file.bytes!,
        file.name,
        jobId: session.jobId,
        onSendProgress: session.onSendProgress,
      ),
    );
    if (!context.mounted) return;
    setState(() => _importingReturn = false);
    if (success) {
      final versions = provider.salesReturnImportResult?['versions'];
      final changed = versions is! List || versions.isNotEmpty;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import retur berhasil'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadSummary(forceRefresh: changed);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Import retur gagal'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickAndImportTargets(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.size > 10 * 1024 * 1024) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ukuran file target maksimal 10 MB'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    if (file.bytes == null || file.bytes!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membaca file target'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final provider = context.read<AdminProvider>();
    setState(() => _importingTarget = true);
    final success = await ImportProgressOverlay.run<bool>(
      context,
      title: 'Mengimport Target Penjualan',
      fileName: file.name,
      fileSize: file.size,
      progressFetcher: provider.fetchImportProgress,
      task: (session) => provider.importSalesTargetsExcel(
        file.bytes!,
        file.name,
        jobId: session.jobId,
        onSendProgress: session.onSendProgress,
      ),
    );
    if (!context.mounted) return;
    setState(() => _importingTarget = false);
    if (success) {
      final importResult = provider.salesTargetImportResult;
      final inserted = (importResult?['inserted'] as num?)?.toInt() ?? 0;
      final updated = (importResult?['updated'] as num?)?.toInt() ?? 0;
      final skipped = (importResult?['skipped'] as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import target selesai: $inserted baru · $updated diperbarui · '
            '$skipped dilewati',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadSummary(forceRefresh: inserted + updated > 0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Import target gagal'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final summary = provider.importedSalesSummary;
    final isLoading = provider.importedSalesLoading;
    final errorMessage = provider.importedSalesError;
    final limit = provider.importedSalesLimit;
    final importResult = provider.salesImportResult;
    final returnImportResult = provider.salesReturnImportResult;
    final targetImportResult = provider.salesTargetImportResult;
    final comparisonMonths = provider.importedSalesComparisonMonths;

    // Never label old-month data with the newly selected month: only render
    // the summary when the payload actually belongs to the visible period.
    final summaryMonth = summary?['month']?.toString();
    final analytics =
        (summary != null &&
            summaryMonth == _monthKey &&
            ((summary['range_months'] as num?)?.toInt() ?? 1) == 1)
        ? SalesAnalytics.fromSummary(summary, _month)
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final resp = Responsive.of(constraints.maxWidth);
        return SingleChildScrollView(
          padding: EdgeInsets.all(resp.contentPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'Data Penjualan',
                subtitle:
                    'Analisis omzet, tren harian, kanal, dan performa dari laporan Excel.',
                actions: [
                  if (!widget.readOnly && provider.isGlobalManager) ...[
                    AppButton(
                      label: 'Hapus bulan',
                      icon: Icons.delete_outline,
                      variant: AppButtonVariant.danger,
                      onPressed: _isImporting
                          ? null
                          : () => _confirmDeleteMonth(context, provider),
                    ),
                    AppButton(
                      label: _importing ? 'Mengimport...' : 'Import Excel',
                      icon: Icons.upload_file,
                      variant: AppButtonVariant.secondary,
                      isLoading: _importing,
                      onPressed: _isImporting
                          ? null
                          : () => _pickAndImport(context),
                    ),
                    AppButton(
                      label: _importingTarget
                          ? 'Mengimport...'
                          : 'Import Target',
                      icon: Icons.flag_outlined,
                      variant: AppButtonVariant.outline,
                      isLoading: _importingTarget,
                      onPressed: _isImporting
                          ? null
                          : () => _pickAndImportTargets(context),
                    ),
                    AppButton(
                      label: 'Hapus retur',
                      icon: Icons.delete_sweep_outlined,
                      variant: AppButtonVariant.danger,
                      onPressed: _isImporting
                          ? null
                          : () => _confirmDeleteReturnsMonth(context, provider),
                    ),
                    AppButton(
                      label: _importingReturn
                          ? 'Mengimport...'
                          : 'Import Retur',
                      icon: Icons.assignment_return_outlined,
                      variant: AppButtonVariant.outline,
                      isLoading: _importingReturn,
                      onPressed: _isImporting
                          ? null
                          : () => _pickAndImportReturns(context),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _PeriodToolbar(
                month: _month,
                loading: isLoading,
                limit: limit,
                comparisonMonths: comparisonMonths,
                updatedAt: analytics?.updatedAt,
                rowCount: analytics?.totalRows,
                showBranchFilter: provider.isGlobalManager,
                branchOptions: provider.branchOptions,
                selectedBranch: provider.importedSalesBranchFilter,
                onBranchChanged: _changeBranch,
                onPrevious: () =>
                    _changeMonth(DateTime(_month.year, _month.month - 1)),
                onNext: () =>
                    _changeMonth(DateTime(_month.year, _month.month + 1)),
                onPick: _pickMonth,
                onRefresh: () => _loadSummary(forceRefresh: true),
                onLimitChanged: (value) => _loadSummary(limit: value),
                onComparisonChanged: _changeComparison,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ErrorCard(message: errorMessage),
              ],
              if (importResult != null &&
                  !identical(importResult, _dismissedImportResult)) ...[
                const SizedBox(height: AppSpacing.md),
                SalesImportBanner(
                  result: importResult,
                  onDismiss: () =>
                      setState(() => _dismissedImportResult = importResult),
                ),
              ],
              if (returnImportResult != null &&
                  !identical(
                    returnImportResult,
                    _dismissedReturnImportResult,
                  )) ...[
                const SizedBox(height: AppSpacing.md),
                SalesImportBanner(
                  result: returnImportResult,
                  onDismiss: () => setState(
                    () => _dismissedReturnImportResult = returnImportResult,
                  ),
                ),
              ],
              if (targetImportResult != null &&
                  !identical(
                    targetImportResult,
                    _dismissedTargetImportResult,
                  )) ...[
                const SizedBox(height: AppSpacing.md),
                _SalesTargetImportBanner(
                  result: targetImportResult,
                  onDismiss: () => setState(
                    () => _dismissedTargetImportResult = targetImportResult,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (analytics == null)
                isLoading
                    ? const _LoadingView()
                    : Column(
                        children: [
                          SalesEmptyStateCard(
                            title: 'Belum ada data ${formatMonthLong(_month)}',
                            message: errorMessage != null
                                ? 'Data gagal dimuat. Coba muat ulang periode ini.'
                                : 'Import laporan penjualan (.xlsx/.xls) untuk '
                                      'periode ini agar tren, kanal, dan ranking '
                                      'bisa dianalisis.',
                            action: widget.readOnly || !provider.isGlobalManager
                                ? null
                                : AppButton(
                                    label: 'Import Excel',
                                    icon: Icons.upload_file,
                                    onPressed: () => _pickAndImport(context),
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _SupplierReturnCard(
                            analytics: SalesAnalytics.fromSummary(
                              const <String, dynamic>{},
                              _month,
                            ),
                            limit: 10,
                            canImport:
                                !widget.readOnly && provider.isGlobalManager,
                            onImport: () => _pickAndImportReturns(context),
                          ),
                        ],
                      )
              else if (analytics.isEmpty)
                Column(
                  children: [
                    SalesEmptyStateCard(
                      title:
                          'Tidak ada penjualan di ${formatMonthLong(_month)}',
                      message:
                          'File untuk periode ini sudah diimport, tetapi belum ada '
                          'baris penjualan yang tercatat. Periksa kembali isi file '
                          'atau pilih periode lain.',
                      action: widget.readOnly || !provider.isGlobalManager
                          ? null
                          : AppButton(
                              label: 'Import ulang',
                              icon: Icons.upload_file,
                              variant: AppButtonVariant.outline,
                              onPressed: () => _pickAndImport(context),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SupplierReturnCard(
                      analytics: analytics,
                      limit: limit,
                      canImport: !widget.readOnly && provider.isGlobalManager,
                      onImport: () => _pickAndImportReturns(context),
                    ),
                  ],
                )
              else
                _AnalyticsBody(
                  analytics: analytics,
                  comparison: provider.importedSalesComparison != null
                      ? SalesComparison.fromMap(
                          provider.importedSalesComparison!,
                          months: comparisonMonths,
                        )
                      : null,
                  comparisonMonths: comparisonMonths,
                  comparisonDetail: provider.importedSalesComparisonDetail,
                  comparisonLabel: _comparisonLabel(comparisonMonths),
                  limit: limit,
                  allBranches:
                      provider.isGlobalManager &&
                      provider.importedSalesBranchFilter == null,
                  branchOptions: provider.branchOptions,
                  branchOptionsLoading: provider.branchOptionsLoading,
                  branchOptionsError: provider.branchOptionsError,
                  onRetryBranches: provider.loadBranchOptions,
                  repository: provider.repository,
                  month: _month,
                  canImportReturns:
                      !widget.readOnly && provider.isGlobalManager,
                  onImportReturns: () => _pickAndImportReturns(context),
                ),
              if (!widget.readOnly && provider.isGlobalManager) ...[
                const SizedBox(height: AppSpacing.lg),
                _ImportPanel(
                  importing: _isImporting,
                  onPick: () => _pickAndImport(context),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteMonth(
    BuildContext context,
    AdminProvider provider,
  ) async {
    try {
      final totals = await provider.getImportedSalesMonthTotals(_monthKey);
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _DeleteMonthDialog(
          month: _monthKey,
          scope: provider.importedSalesBranchFilter ?? 'Semua cabang',
          rows: totals['rows'] ?? 0,
          revenue: totals['revenue'] ?? 0,
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final branch = provider.importedSalesBranchFilter;
      final success = await provider.deleteImportedSalesMonth(
        month: _monthKey,
        branch: branch,
        allBranches: branch == null,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Data $_monthKey berhasil dihapus'
                : provider.errorMessage ?? 'Gagal menghapus data',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat jumlah data bulan: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirmDeleteReturnsMonth(
    BuildContext context,
    AdminProvider provider,
  ) async {
    try {
      final totals = await provider.getImportedSalesMonthTotals(_monthKey);
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _DeleteMonthDialog(
          month: _monthKey,
          scope: provider.importedSalesBranchFilter ?? 'Semua cabang',
          rows: totals['retur_rows'] ?? 0,
          revenue: totals['retur_revenue'] ?? 0,
          returns: true,
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final branch = provider.importedSalesBranchFilter;
      final success = await provider.deleteImportedSalesReturnsMonth(
        month: _monthKey,
        branch: branch,
        allBranches: branch == null,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Retur $_monthKey berhasil dihapus'
                : provider.errorMessage ?? 'Gagal menghapus retur',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat jumlah retur bulan: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _DeleteMonthDialog extends StatefulWidget {
  const _DeleteMonthDialog({
    required this.month,
    required this.scope,
    required this.rows,
    required this.revenue,
    this.returns = false,
  });

  final String month;
  final String scope;
  final int rows;
  final int revenue;
  final bool returns;

  @override
  State<_DeleteMonthDialog> createState() => _DeleteMonthDialogState();
}

class _DeleteMonthDialogState extends State<_DeleteMonthDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.returns ? 'Hapus retur penjualan' : 'Hapus data penjualan',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bulan: ${widget.month}'),
          Text('Cakupan: ${widget.scope}'),
          Text(
            '${widget.returns ? 'Baris retur' : 'Baris saat ini'}: '
            '${formatInt(widget.rows)}',
          ),
          Text(
            '${widget.returns ? 'Nilai retur' : 'Omzet saat ini'}: '
            '${formatRupiah(widget.revenue)}',
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Penghapusan permanen dan tidak dapat dibatalkan. Ketik bulan untuk melanjutkan.',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Ketik YYYY-MM',
              hintText: '2026-11',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        AppButton(
          label: 'Hapus permanen',
          icon: Icons.delete_outline,
          variant: AppButtonVariant.danger,
          onPressed: _controller.text.trim() == widget.month
              ? () => Navigator.of(context).pop(true)
              : null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({
    required this.analytics,
    required this.comparison,
    required this.comparisonMonths,
    required this.comparisonDetail,
    required this.comparisonLabel,
    required this.limit,
    required this.allBranches,
    required this.branchOptions,
    required this.branchOptionsLoading,
    required this.branchOptionsError,
    required this.onRetryBranches,
    required this.repository,
    required this.month,
    required this.canImportReturns,
    required this.onImportReturns,
  });

  final SalesAnalytics analytics;
  final SalesComparison? comparison;
  final int comparisonMonths;
  final Map<String, List<SalesRankItem>>? comparisonDetail;
  final String comparisonLabel;
  final int limit;
  final bool allBranches;
  final List<BranchOption> branchOptions;
  final bool branchOptionsLoading;
  final String? branchOptionsError;
  final VoidCallback onRetryBranches;
  final AdminRepository repository;
  final DateTime month;
  final bool canImportReturns;
  final VoidCallback onImportReturns;

  @override
  Widget build(BuildContext context) {
    final insights = buildSalesInsights(analytics);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SalesHeroCard(analytics: analytics, comparison: comparison),
        const SizedBox(height: AppSpacing.md),
        if (analytics.divisi.isEmpty)
          AppCard(
            title: 'Statistik Divisi',
            child: Text(
              'Belum ada data divisi untuk periode ini.',
              style: AppTextStyles.bodyMuted,
            ),
          )
        else
          AppResponsiveGrid(
            desktopCols: 4,
            tabletCols: 2,
            mobileCols: 1,
            children: [
              for (final (index, item) in analytics.divisi.indexed)
                AppStatCard(
                  title: item.displayLabel,
                  value: formatRupiah(item.revenue),
                  subtitle:
                      'Margin ${formatRupiah(item.margin)} · '
                      '${formatPercentPrecise(item.revenue == 0 ? 0 : item.margin / item.revenue)} margin\n'
                      '${formatPercentPrecise(analytics.totalRevenue == 0 ? 0 : item.revenue / analytics.totalRevenue)} kontribusi omzet',
                  icon: Icons.apartment_outlined,
                  accentColor:
                      salesChartPalette[index % salesChartPalette.length],
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        AppResponsiveGrid(
          desktopCols: 4,
          tabletCols: 2,
          mobileCols: 1,
          children: [
            for (final insight in insights) SalesInsightCard(insight: insight),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (allBranches)
          _AllBranchesAnalytics(
            branches: branchOptions,
            branchesLoading: branchOptionsLoading,
            branchesError: branchOptionsError,
            onRetryBranches: onRetryBranches,
            repository: repository,
            month: month,
            rangeMonths: analytics.rangeMonths,
          )
        else
          _SplitLayout(
            leftFlex: 3,
            rightFlex: 2,
            left: _TrendCard(analytics: analytics),
            right: AppCard(
              title: 'Partisipasi Sales',
              subtitle: 'Persentase kontribusi omzet setiap sales',
              child: _SalesParticipation(analytics: analytics),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        AppResponsiveGrid(
          desktopCols: 2,
          tabletCols: 1,
          mobileCols: 1,
          children: [
            _MetricRankingCard(
              title: 'Supplier Teratas',
              items: analytics.suppliers,
              totalRevenue: analytics.totalRevenue,
              totalMargin: analytics.totalMargin,
              limit: limit,
              targets: analytics.supplierTargets,
            ),
            _SupplierReturnCard(
              analytics: analytics,
              limit: limit,
              canImport: canImportReturns,
              onImport: onImportReturns,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Produk Teratas sendiri dalam satu baris penuh agar nama produk panjang terbaca.
        AppResponsiveGrid(
          desktopCols: 1,
          tabletCols: 1,
          mobileCols: 1,
          children: [
            _MetricRankingCard(
              title: 'Produk Teratas',
              items: analytics.products,
              totalRevenue: analytics.totalRevenue,
              totalMargin: analytics.totalMargin,
              limit: limit,
              comparisonItems: comparisonDetail?['product'],
              comparisonLabel: comparisonLabel,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Sales Teratas (tidak ada pembanding, sesuai keputusan)
        AppResponsiveGrid(
          desktopCols: 1,
          tabletCols: 1,
          mobileCols: 1,
          children: [
            _MetricRankingCard(
              title: 'Sales Teratas',
              items: analytics.sales,
              totalRevenue: analytics.totalRevenue,
              totalMargin: analytics.totalMargin,
              limit: limit,
              targets: analytics.salesTargets,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppResponsiveGrid(
          desktopCols: 1,
          tabletCols: 1,
          mobileCols: 1,
          children: [
            _MetricRankingCard(
              title: 'Pelanggan Teratas',
              items: analytics.customers,
              totalRevenue: analytics.totalRevenue,
              totalMargin: analytics.totalMargin,
              limit: limit,
              comparisonItems: comparisonDetail?['customer'],
              comparisonLabel: comparisonLabel,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppResponsiveGrid(
          desktopCols: 1,
          tabletCols: 1,
          mobileCols: 1,
          children: [
            _MetricRankingCard(
              title: 'Divisi Teratas',
              items: analytics.divisi,
              totalRevenue: analytics.totalRevenue,
              totalMargin: analytics.totalMargin,
              limit: limit,
              targets: analytics.divisiTargets,
              comparisonItems: comparisonDetail?['divisi'],
              comparisonLabel: comparisonLabel,
            ),
          ],
        ),
      ],
    );
  }
}

class _BranchSalesAnalytics {
  const _BranchSalesAnalytics({
    required this.branch,
    required this.revenue,
    required this.days,
  });

  final BranchOption branch;
  final int revenue;
  final List<SalesDayPoint> days;
}

class _AllBranchesAnalytics extends StatefulWidget {
  const _AllBranchesAnalytics({
    required this.branches,
    required this.branchesLoading,
    required this.branchesError,
    required this.onRetryBranches,
    required this.repository,
    required this.month,
    required this.rangeMonths,
  });

  final List<BranchOption> branches;
  final bool branchesLoading;
  final String? branchesError;
  final VoidCallback onRetryBranches;
  final AdminRepository repository;
  final DateTime month;
  final int rangeMonths;

  @override
  State<_AllBranchesAnalytics> createState() => _AllBranchesAnalyticsState();
}

class _AllBranchesAnalyticsState extends State<_AllBranchesAnalytics> {
  late Future<List<_BranchSalesAnalytics>> _branchData;
  bool _perBranch = false;
  bool _combined = false;

  @override
  void initState() {
    super.initState();
    _branchData = _loadBranchData();
  }

  @override
  void didUpdateWidget(covariant _AllBranchesAnalytics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month ||
        oldWidget.rangeMonths != widget.rangeMonths ||
        !_sameBranches(oldWidget.branches, widget.branches)) {
      _branchData = _loadBranchData();
    }
  }

  bool _sameBranches(List<BranchOption> a, List<BranchOption> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index].code != b[index].code || a[index].nama != b[index].nama) {
        return false;
      }
    }
    return true;
  }

  Future<List<_BranchSalesAnalytics>> _loadBranchData() async {
    final branches = widget.branches
        .where((branch) => branch.code.trim().isNotEmpty)
        .toList(growable: false);
    if (branches.isEmpty) return const [];

    final monthKey =
        '${widget.month.year.toString().padLeft(4, '0')}-'
        '${widget.month.month.toString().padLeft(2, '0')}';
    final data = await Future.wait(
      branches.map((branch) async {
        final summary = await widget.repository.getImportedSalesSummary(
          month: monthKey,
          rangeMonths: widget.rangeMonths,
          limit: 1,
          include: 'day',
          branch: branch.code,
        );
        final analytics = SalesAnalytics.fromSummary(summary, widget.month);
        return _BranchSalesAnalytics(
          branch: branch,
          revenue: analytics.totalRevenue,
          days: analytics.days,
        );
      }),
    );
    data.sort((a, b) {
      final byRevenue = b.revenue.compareTo(a.revenue);
      return byRevenue != 0
          ? byRevenue
          : a.branch.nama.compareTo(b.branch.nama);
    });
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_BranchSalesAnalytics>>(
      future: _branchData,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppCard(
            title: 'Analisis Cabang',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gagal memuat data cabang: ${snapshot.error}',
                  style: AppTextStyles.body.copyWith(color: AppColors.error),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _branchData = _loadBranchData();
                  }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi'),
                ),
              ],
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppCard(
            title: 'Analisis Cabang',
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final data = snapshot.data ?? const <_BranchSalesAnalytics>[];
        if (data.isEmpty) {
          if (widget.branches.isEmpty && widget.branchesError != null) {
            return AppCard(
              title: 'Analisis Cabang',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gagal memuat daftar cabang: ${widget.branchesError}',
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: widget.branchesLoading
                        ? null
                        : widget.onRetryBranches,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba lagi'),
                  ),
                ],
              ),
            );
          }
          return AppCard(
            title: 'Analisis Cabang',
            child: Text(
              widget.branchesLoading
                  ? 'Memuat daftar cabang...'
                  : 'Data cabang tidak tersedia untuk dianalisis.',
              style: AppTextStyles.bodyMuted,
            ),
          );
        }

        final days = _combinedBranchDays(data);
        final series = [
          for (final branch in data)
            SalesTrendSeries(
              key: branch.branch.code,
              label: branch.branch.nama,
              totalRevenue: branch.revenue,
              revenueByDay: [for (final point in branch.days) point.revenue],
            ),
        ];
        final participationItems = [
          for (final branch in data)
            if (branch.revenue != 0)
              SalesRankItem(
                code: branch.branch.code,
                label: branch.branch.nama,
                qty: 0,
                revenue: branch.revenue,
              ),
        ];

        return _SplitLayout(
          leftFlex: 3,
          rightFlex: 2,
          left: AppCard(
            title: 'Tren Omzet Harian per Cabang',
            subtitle: !_perBranch
                ? 'Omzet per hari · arahkan kursor untuk detail'
                : _combined
                ? 'Omzet harian semua cabang dalam satu grafik'
                : 'Tiap panel menampilkan tren omzet satu cabang',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppChoiceChip(
                  label: 'Total',
                  dense: true,
                  selected: !_perBranch,
                  onSelected: () => setState(() => _perBranch = false),
                ),
                const SizedBox(width: AppSpacing.xs),
                AppChoiceChip(
                  label: 'Per Cabang',
                  dense: true,
                  selected: _perBranch,
                  onSelected: () => setState(() => _perBranch = true),
                ),
              ],
            ),
            child: !_perBranch
                ? SalesTrendChart(points: days, height: 258)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_combined)
                        SalesMultiTrendChart(series: series, days: days)
                      else
                        SalesSmallMultiplesChart(series: series, days: days),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _combined
                                  ? 'Klik legenda untuk isolasi garis.'
                                  : 'Setiap panel mengikuti skala omzet cabangnya.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _combined = !_combined),
                            icon: Icon(
                              _combined
                                  ? Icons.grid_view_rounded
                                  : Icons.show_chart,
                              size: 16,
                            ),
                            label: Text(
                              _combined ? 'Tampilkan panel' : 'Garis gabungan',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: const Size(0, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          right: AppCard(
            title: 'Partisipasi Cabang',
            subtitle: 'Persentase kontribusi omzet setiap cabang',
            child: SalesParticipationChart(
              items: participationItems,
              emptyMessage: 'Belum ada omzet cabang untuk periode ini.',
            ),
          ),
        );
      },
    );
  }

  List<SalesDayPoint> _combinedBranchDays(
    List<_BranchSalesAnalytics> branches,
  ) {
    if (branches.isEmpty) return const [];
    final template = branches.first.days;
    return [
      for (var index = 0; index < template.length; index++)
        SalesDayPoint(
          date: template[index].date,
          revenue: branches.fold(
            0,
            (total, branch) => total + branch.days[index].revenue,
          ),
          qty: branches.fold(
            0,
            (total, branch) => total + branch.days[index].qty,
          ),
        ),
    ];
  }
}

class _TrendCard extends StatefulWidget {
  const _TrendCard({required this.analytics});

  final SalesAnalytics analytics;

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  bool _perSales = false;
  bool _combined = false;

  @override
  Widget build(BuildContext context) {
    final analytics = widget.analytics;
    final chips = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppChoiceChip(
          label: 'Total',
          dense: true,
          selected: !_perSales,
          onSelected: () => setState(() => _perSales = false),
        ),
        const SizedBox(width: AppSpacing.xs),
        AppChoiceChip(
          label: 'Per Sales',
          dense: true,
          selected: _perSales,
          onSelected: () => setState(() => _perSales = true),
        ),
      ],
    );

    final subtitle = !_perSales
        ? 'Omzet per hari · arahkan kursor untuk detail'
        : _combined
        ? 'Omzet harian semua sales dalam satu grafik'
        : 'Top ${analytics.salesSeries.length} sales · tiap panel punya skala sendiri';

    return AppCard(
      title: 'Tren Omzet Harian',
      subtitle: subtitle,
      trailing: chips,
      child: _perSales
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_combined)
                  SalesMultiTrendChart(
                    series: analytics.salesSeries,
                    days: analytics.days,
                    height: 250,
                  )
                else
                  SalesSmallMultiplesChart(
                    series: analytics.salesSeries,
                    days: analytics.days,
                  ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _combined
                            ? 'Klik legenda untuk isolasi garis.'
                            : 'Skala tiap panel mengikuti nilai tertinggi sales · hover untuk detail',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: () => setState(() => _combined = !_combined),
                      icon: Icon(
                        _combined ? Icons.grid_view_rounded : Icons.show_chart,
                        size: 16,
                      ),
                      label: Text(
                        _combined ? 'Tampilkan panel' : 'Garis gabungan',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : SalesTrendChart(points: analytics.days, height: 258),
    );
  }
}

class _SalesParticipation extends StatelessWidget {
  const _SalesParticipation({required this.analytics});

  final SalesAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return SalesParticipationChart(
      items: analytics.sales,
      emptyMessage: 'Belum ada data sales untuk periode ini.',
    );
  }
}

class _MetricRankingCard extends StatefulWidget {
  const _MetricRankingCard({
    required this.title,
    required this.items,
    required this.totalRevenue,
    required this.totalMargin,
    required this.limit,
    this.targets,
    this.comparisonItems,
    this.comparisonLabel,
  });

  final String title;
  final List<SalesRankItem> items;
  final int totalRevenue;
  final int totalMargin;
  final int limit;
  final Map<String, int>? targets;

  /// Items untuk periode pembanding (nilai sudah rata-rata per bulan).
  final List<SalesRankItem>? comparisonItems;
  final String? comparisonLabel; // mis. "3 Bulan Sebelumnya (Agu–Okt 2026)"

  @override
  State<_MetricRankingCard> createState() => _MetricRankingCardState();
}

class _MetricRankingCardState extends State<_MetricRankingCard> {
  bool _showMargin = false;

  List<SalesRankingEntry> _buildEntries(
    List<SalesRankItem> items,
    int totalValue,
    bool showTarget,
  ) {
    return items
        .map((item) {
          final value = _showMargin ? item.margin : item.revenue;
          final productDetails = [
            if (item.productKode?.isNotEmpty == true)
              'Kode ${item.productKode}',
            if (item.motherSku?.isNotEmpty == true)
              'Mother SKU ${item.motherSku}',
          ];
          final entryTarget = showTarget && widget.targets != null
              ? widget.targets![item.targetKey]
              : null;
          return SalesRankingEntry(
            label: item.displayLabel,
            value: value,
            sortValue: item.revenue,
            detail: productDetails.isEmpty ? null : productDetails.join(' · '),
            showTarget: showTarget,
            target: entryTarget,
            targetActual: item.revenue,
          );
        })
        .toList(growable: false);
  }

  /// Build entri periode lain mengikuti urutan [leftItems] (bulan kebelakang),
  /// sehingga baris kanan selaras dengan ranking periode kebelakang.
  /// Item yang tidak ada di data pembanding ditampilkan 0.
  List<SalesRankingEntry> _buildComparisonEntriesOrderedByLeft(
    List<SalesRankItem> comparisonItems,
    List<SalesRankItem> leftItems,
    int comparisonTotal,
  ) {
    final byKey = <String, SalesRankItem>{};
    for (final item in comparisonItems) {
      final key = item.code.isNotEmpty ? item.code : item.label;
      if (key.isNotEmpty) byKey[key] = item;
    }
    return List<SalesRankingEntry>.generate(leftItems.length, (index) {
      final leftItem = leftItems[index];
      final key = leftItem.code.isNotEmpty ? leftItem.code : leftItem.label;
      final rightItem = byKey[key];
      final value = rightItem == null
          ? 0
          : (_showMargin ? rightItem.margin : rightItem.revenue);
      final rightLabel = rightItem?.displayLabel ?? leftItem.displayLabel;
      return SalesRankingEntry(
        label: rightLabel,
        value: value,
        // sortValue menurun menurut indeks kiri agar SalesRankingList
        // tidak mengurutkan ulang kanan (tetap mengikuti kiri).
        sortValue: leftItems.length - index,
        showTarget: false,
        target: null,
        targetActual: rightItem?.revenue ?? 0,
      );
    }, growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final totalValue = _showMargin ? widget.totalMargin : widget.totalRevenue;
    final hasComparison =
        widget.comparisonItems != null && widget.comparisonItems!.isNotEmpty;

    if (!hasComparison) {
      return _buildSingleCard(totalValue);
    }

    final comparisonTotal = widget.comparisonItems!.fold<int>(
      0,
      (sum, item) => sum + (_showMargin ? item.margin : item.revenue),
    );
    // Ranking utama memakai periode bulan kebelakang. Bulan aktif hanya
    // mengikuti urutan entitas yang sudah ditentukan oleh periode tersebut.
    final leftEntries = _buildEntries(
      widget.comparisonItems!,
      comparisonTotal,
      false,
    );
    final rightEntries = _buildComparisonEntriesOrderedByLeft(
      widget.items,
      widget.comparisonItems!,
      totalValue,
    );

    return AppCard(
      title: widget.title,
      subtitle: 'Top ${widget.limit} berdasarkan omzet',
      trailing: Wrap(
        spacing: AppSpacing.xs,
        children: [
          AppChoiceChip(
            label: 'Omzet',
            dense: true,
            selected: !_showMargin,
            onSelected: () => setState(() => _showMargin = false),
          ),
          AppChoiceChip(
            label: 'Margin',
            dense: true,
            selected: _showMargin,
            onSelected: () => setState(() => _showMargin = true),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.comparisonLabel ?? 'Bulan sebelumnya',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.onPrimaryMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SalesRankingList(
                        entries: leftEntries,
                        maxItems: widget.limit,
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bulan ini',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.onPrimaryMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SalesRankingList(
                        entries: rightEntries,
                        maxItems: widget.limit,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleCard(int totalValue) {
    final entries = _buildEntries(
      widget.items,
      totalValue,
      widget.targets != null,
    );
    return AppCard(
      title: widget.title,
      subtitle: 'Top ${widget.limit} berdasarkan omzet',
      trailing: Wrap(
        spacing: AppSpacing.xs,
        children: [
          AppChoiceChip(
            label: 'Omzet',
            dense: true,
            selected: !_showMargin,
            onSelected: () => setState(() => _showMargin = false),
          ),
          AppChoiceChip(
            label: 'Margin',
            dense: true,
            selected: _showMargin,
            onSelected: () => setState(() => _showMargin = true),
          ),
        ],
      ),
      child: SalesRankingList(entries: entries, maxItems: widget.limit),
    );
  }
}

class _SupplierReturnCard extends StatefulWidget {
  const _SupplierReturnCard({
    required this.analytics,
    required this.limit,
    required this.canImport,
    required this.onImport,
  });

  final SalesAnalytics analytics;
  final int limit;
  final bool canImport;
  final VoidCallback onImport;

  @override
  State<_SupplierReturnCard> createState() => _SupplierReturnCardState();
}

class _SupplierReturnCardState extends State<_SupplierReturnCard> {
  bool _showMargin = false;

  @override
  Widget build(BuildContext context) {
    final analytics = widget.analytics;
    final supplierRanks = <String, int>{};
    for (final (index, item)
        in analytics.suppliers.take(widget.limit).indexed) {
      supplierRanks.putIfAbsent(
        normalizeSalesTargetName(item.displayLabel),
        () => index,
      );
    }

    final returns = analytics.supplierRetur.toList()
      ..sort((a, b) {
        final rankA = supplierRanks[normalizeSalesTargetName(a.displayLabel)];
        final rankB = supplierRanks[normalizeSalesTargetName(b.displayLabel)];
        if (rankA != null && rankB != null) return rankA.compareTo(rankB);
        if (rankA != null) return -1;
        if (rankB != null) return 1;
        final valueA = _showMargin ? a.margin : a.revenue;
        final valueB = _showMargin ? b.margin : b.revenue;
        final byValue = valueB.compareTo(valueA);
        return byValue != 0
            ? byValue
            : a.displayLabel.compareTo(b.displayLabel);
      });

    final entries = returns.indexed
        .map(
          (indexedItem) => SalesRankingEntry(
            label: indexedItem.$2.displayLabel,
            value: _showMargin ? indexedItem.$2.margin : indexedItem.$2.revenue,
            sortValue: returns.length - indexedItem.$1,
            detail:
                '${indexedItem.$2.rowCount} baris retur · '
                '${formatPercentPrecise(_supplierReturnRate(indexedItem.$2))} dari omzet supplier',
          ),
        )
        .toList(growable: false);

    return AppCard(
      title: 'Supplier Diretur',
      subtitle:
          'Top ${widget.limit} · urutan mengikuti Supplier Teratas; '
          'supplier lain berdasarkan ${_showMargin ? 'margin' : 'omzet'} retur',
      trailing: Wrap(
        spacing: AppSpacing.xs,
        children: [
          AppChoiceChip(
            label: 'Omzet',
            dense: true,
            selected: !_showMargin,
            onSelected: () => setState(() => _showMargin = false),
          ),
          AppChoiceChip(
            label: 'Margin',
            dense: true,
            selected: _showMargin,
            onSelected: () => setState(() => _showMargin = true),
          ),
        ],
      ),
      child: entries.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Belum ada retur periode ini'),
                if (widget.canImport) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Import Retur',
                    icon: Icons.assignment_return_outlined,
                    variant: AppButtonVariant.outline,
                    onPressed: widget.onImport,
                  ),
                ],
              ],
            )
          : SalesRankingList(
              entries: entries,
              maxItems: widget.limit,
              emptyMessage: 'Belum ada retur periode ini',
            ),
    );
  }

  double _supplierReturnRate(SupplierReturnRankItem item) {
    final grossRevenue = item.supplierNetRevenue + item.revenue;
    if (grossRevenue <= 0) return 0;
    return item.revenue / grossRevenue;
  }
}

// ---------------------------------------------------------------------------
// Toolbar
// ---------------------------------------------------------------------------

class _PeriodToolbar extends StatelessWidget {
  const _PeriodToolbar({
    required this.month,
    required this.loading,
    required this.limit,
    required this.comparisonMonths,
    required this.updatedAt,
    required this.rowCount,
    required this.showBranchFilter,
    required this.branchOptions,
    required this.selectedBranch,
    required this.onBranchChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    required this.onRefresh,
    required this.onLimitChanged,
    required this.onComparisonChanged,
  });

  final DateTime month;
  final bool loading;
  final int limit;
  final int comparisonMonths;
  final DateTime? updatedAt;
  final int? rowCount;
  final bool showBranchFilter;
  final List<BranchOption> branchOptions;
  final String? selectedBranch;
  final ValueChanged<String?> onBranchChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onRefresh;
  final ValueChanged<int> onLimitChanged;
  final ValueChanged<int> onComparisonChanged;

  @override
  Widget build(BuildContext context) {
    final monthSelector = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SquareIconButton(
          icon: Icons.chevron_left,
          tooltip: 'Bulan sebelumnya',
          onPressed: loading ? null : onPrevious,
        ),
        const SizedBox(width: AppSpacing.sm),
        Material(
          color: AppColors.surface,
          borderRadius: AppRadius.md,
          child: InkWell(
            onTap: loading ? null : onPick,
            borderRadius: AppRadius.md,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(formatMonthLong(month), style: AppTextStyles.h3),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _SquareIconButton(
          icon: Icons.chevron_right,
          tooltip: 'Bulan berikutnya',
          onPressed: loading ? null : onNext,
        ),
      ],
    );

    final scopeSelector = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showBranchFilter)
          _BranchSelector(
            options: branchOptions,
            selected: selectedBranch,
            enabled: !loading,
            onChanged: onBranchChanged,
          ),
        monthSelector,
      ],
    );

    final controls = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Pembanding:',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        for (final option in const [1, 3, 6, 12])
          AppChoiceChip(
            label: option == 1 ? 'Bulanan' : '$option Bulan',
            selected: comparisonMonths == option,
            onSelected: loading ? null : () => onComparisonChanged(option),
          ),
        AppChoiceChip(
          label: 'Top 10',
          selected: limit == 10,
          onSelected: loading ? null : () => onLimitChanged(10),
        ),
        AppChoiceChip(
          label: 'Top 50',
          selected: limit == 50,
          onSelected: loading ? null : () => onLimitChanged(50),
        ),
        AppButton(
          label: 'Muat ulang',
          icon: Icons.refresh,
          variant: AppButtonVariant.outline,
          isLoading: loading,
          onPressed: loading ? null : onRefresh,
        ),
      ],
    );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    scopeSelector,
                    const SizedBox(height: AppSpacing.md),
                    controls,
                  ],
                );
              }
              return Row(children: [scopeSelector, const Spacer(), controls]);
            },
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              Icon(
                updatedAt == null
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_done_outlined,
                size: 14,
                color: updatedAt == null
                    ? AppColors.textMuted
                    : AppColors.success,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  updatedAt == null
                      ? 'Belum ada data import untuk periode ini'
                      : 'Diperbarui ${formatDateTime(updatedAt!)}'
                            '${rowCount != null ? ' · ${formatInt(rowCount!)} baris transaksi' : ''}',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BranchSelector extends StatelessWidget {
  const _BranchSelector({
    required this.options,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final List<BranchOption> options;
  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = (selected == null || selected!.isEmpty) ? '' : selected!;
    final known = value.isEmpty || options.any((b) => b.code == value);

    return Tooltip(
      message: 'Filter cabang',
      child: Container(
        width: 220,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  isDense: true,
                  isExpanded: true,
                  borderRadius: AppRadius.md,
                  menuMaxHeight: 320,
                  iconSize: 18,
                  style: AppTextStyles.h3,
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text(
                        'Semua cabang',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Keep the current selection visible even if the branch
                    // list failed to load or the branch became inactive.
                    if (!known)
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ...options.map(
                      (b) => DropdownMenuItem(
                        value: b.code,
                        child: Text(
                          b.nama.isEmpty ? b.code : b.nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: enabled
                      ? (next) => onChanged(
                          next == null || next.isEmpty ? null : next,
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.md,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.md,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: AppRadius.md,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              icon,
              size: 20,
              color: onPressed == null
                  ? AppColors.textMuted
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small pieces
// ---------------------------------------------------------------------------

class _SplitLayout extends StatelessWidget {
  const _SplitLayout({
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              left,
              const SizedBox(height: AppSpacing.md),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: AppSpacing.md),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      },
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

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
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            SizedBox(height: AppSpacing.md),
            Text('Memuat data penjualan...', style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SalesTargetImportBanner extends StatelessWidget {
  const _SalesTargetImportBanner({
    required this.result,
    required this.onDismiss,
  });

  final Map<String, dynamic> result;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final success = result['success'] == true;
    final errors = (result['errors'] as List? ?? const [])
        .whereType<Map>()
        .toList(growable: false);
    final sheets = (result['sheets'] as List? ?? const [])
        .whereType<Map>()
        .toList(growable: false);
    final foreground = success ? AppColors.successText : AppColors.dangerText;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: success ? AppColors.successSoft : AppColors.errorBg,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: success ? AppColors.successBorder : AppColors.errorBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.error_outline,
            size: 20,
            color: foreground,
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Import target ${success ? 'selesai' : 'gagal'}: '
                  '${result['inserted'] ?? 0} baru · '
                  '${result['updated'] ?? 0} diperbarui · '
                  '${result['skipped'] ?? 0} dilewati.',
                  style: AppTextStyles.body.copyWith(color: foreground),
                ),
                for (final sheet in sheets)
                  Text(
                    '${sheet['sheet']}: ${sheet['rows'] ?? 0} baris · '
                    '${sheet['inserted'] ?? 0} baru · '
                    '${sheet['updated'] ?? 0} diperbarui · '
                    '${sheet['skipped'] ?? 0} dilewati',
                    style: AppTextStyles.caption.copyWith(color: foreground),
                  ),
                for (final error in errors.take(3))
                  Text(
                    '${error['sheet'] ?? 'Sheet'}, baris '
                    '${error['row'] ?? '?'}: ${error['reason'] ?? 'Tidak valid'}',
                    style: AppTextStyles.caption.copyWith(color: foreground),
                  ),
                if (errors.length > 3)
                  Text(
                    'Dan ${errors.length - 3} kesalahan lain. '
                    'Periksa format file target.',
                    style: AppTextStyles.caption.copyWith(color: foreground),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: foreground,
            tooltip: 'Tutup notifikasi',
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ImportPanel extends StatelessWidget {
  const _ImportPanel({required this.importing, required this.onPick});

  final bool importing;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final info = Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.upload_file,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Import laporan penjualan', style: AppTextStyles.h3),
                    const SizedBox(height: 2),
                    Text(
                      'Format .xlsx atau .xls. Data yang sama akan diperbarui, '
                      'bukan diduplikasi. Maksimal 70 MB; file besar dapat '
                      'memerlukan beberapa menit.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                info,
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: importing ? 'Mengimport...' : 'Pilih File Excel',
                  icon: Icons.folder_open,
                  isLoading: importing,
                  isFullWidth: true,
                  onPressed: importing ? null : onPick,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: AppSpacing.md),
              AppButton(
                label: importing ? 'Mengimport...' : 'Pilih File Excel',
                icon: Icons.folder_open,
                variant: AppButtonVariant.outline,
                isLoading: importing,
                onPressed: importing ? null : onPick,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month picker
// ---------------------------------------------------------------------------

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initial});

  final DateTime initial;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      title: Row(
        children: [
          const Expanded(child: Text('Pilih periode', style: AppTextStyles.h2)),
          IconButton(
            tooltip: 'Tahun sebelumnya',
            onPressed: () => setState(() => _year--),
            icon: const Icon(Icons.chevron_left, size: 20),
          ),
          Text('$_year', style: AppTextStyles.h3),
          IconButton(
            tooltip: 'Tahun berikutnya',
            onPressed: () => setState(() => _year++),
            icon: const Icon(Icons.chevron_right, size: 20),
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.9,
          children: [
            for (var month = 1; month <= 12; month++)
              _MonthCell(
                label: formatMonthLong(DateTime(_year, month)).split(' ').first,
                selected:
                    widget.initial.year == _year &&
                    widget.initial.month == month,
                onTap: () => Navigator.of(context).pop(DateTime(_year, month)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            final now = DateTime.now();
            Navigator.of(context).pop(DateTime(now.year, now.month));
          },
          child: const Text('Bulan ini'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceMuted,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DateTime? _parseMonth(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  if (year == null || month == null || month < 1 || month > 12) return null;
  return DateTime(year, month);
}
