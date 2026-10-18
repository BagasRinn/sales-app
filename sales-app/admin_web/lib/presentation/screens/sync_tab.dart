import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../core/design_system.dart';
import '../../core/datetime_utils.dart';
import '../../core/responsive.dart';
import '../../core/responsive_dialog.dart';
import '../providers/admin_provider.dart';
import '../../data/models/sync_result.dart';

class SyncTab extends StatefulWidget {
  const SyncTab({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  State<SyncTab> createState() => _SyncTabState();
}

class _SyncTabState extends State<SyncTab> {
  final _historyKey = GlobalKey<_ImportHistorySectionState>();
  final _errorsKey = GlobalKey<_SyncErrorsSectionState>();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final syncResult = provider.lastSyncResult;
    final isLoading = provider.isLoading;

    return LayoutBuilder(
      builder: (context, constraints) {
        final resp = Responsive.of(constraints.maxWidth);
        return SingleChildScrollView(
          padding: EdgeInsets.all(resp.contentPadding),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main import card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.infoBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child:
                            const Icon(Icons.upload_file, size: 32, color: AppColors.info),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Import Produk',
                              style: AppTextStyles.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Upload file .xlsx untuk import atau update data produk',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: (isLoading || widget.readOnly)
                          ? null
                          : () => _pickAndImport(context, provider),
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.folder_open),
                      label: Text(
                          isLoading ? 'Mengimport...' : 'Pilih File Excel (.xlsx)'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Customer Import Card
          _CustomerImportCard(
            historyKey: _historyKey,
            errorsKey: _errorsKey,
            readOnly: widget.readOnly,
          ),

          // Result cards
          if (syncResult != null) ...[
            const SizedBox(height: 32),
            const Text('Hasil Import Terakhir',
                style: AppTextStyles.headlineLarge),
            const SizedBox(height: 16),
            _SyncResultGrid(result: syncResult),
          ],

          const SizedBox(height: 32),
          // Import history
          const Text('Histori Import', style: AppTextStyles.headlineLarge),
          const SizedBox(height: 16),
          _ImportHistorySection(key: _historyKey),

          const SizedBox(height: 32),
          // Error history
          const Text('Riwayat Error', style: AppTextStyles.headlineLarge),
          const SizedBox(height: 16),
          _SyncErrorsSection(readOnly: widget.readOnly),
        ],
      ),
        );
      },
    );
  }

  Future<void> _pickAndImport(BuildContext context, AdminProvider provider) async {
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

    final success = await provider.importExcel(file.bytes!, file.name);
    if (success && context.mounted) {
      final result_ = provider.lastSyncResult;
      _historyKey.currentState?._refresh();
      _errorsKey.currentState?._refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(result_?.message ?? 'Import berhasil'),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Import gagal'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _SyncResultGrid extends StatelessWidget {
  final SyncResult result;

  const _SyncResultGrid({required this.result});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _ResultCard(
          title: 'Total Produk',
          value: '${result.totalProducts}',
          icon: Icons.inventory_2,
          color: AppColors.info,
        ),
        _ResultCard(
          title: 'Disisipkan (Baru)',
          value: '${result.inserted}',
          icon: Icons.add_circle,
          color: AppColors.success,
        ),
        _ResultCard(
          title: 'Diperbarui',
          value: '${result.updated}',
          icon: Icons.edit,
          color: AppColors.primaryLight,
        ),
        _ResultCard(
          title: 'Dilewati (Error)',
          value: '${result.skipped}',
          icon: Icons.skip_next,
          color: result.skipped > 0 ? AppColors.error : AppColors.textMuted,
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ResultCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      title,
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncErrorsSection extends StatefulWidget {
  const _SyncErrorsSection({this.readOnly = false});

  final bool readOnly;

  @override
  State<_SyncErrorsSection> createState() => _SyncErrorsSectionState();
}

class _SyncErrorsSectionState extends State<_SyncErrorsSection> {
  Future<List<SyncError>>? _errorsFuture;

  @override
  void initState() {
    super.initState();
    _loadErrors();
  }

  void _loadErrors() {
    _errorsFuture = context.read<AdminProvider>().getSyncErrors();
    setState(() {});
  }

  void _refresh() {
    _loadErrors();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SyncError>>(
      future: _errorsFuture,
      builder: (context, snapshot) {
        // First load (no prior data) — tampilkan spinner, jangan pesan
        // "tidak ada error" karena FutureBuilder ada di waiting state dengan
        // snapshot.data == null. Pesan kosong saat loading = misleading UX.
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Memuat riwayat error...',
                        style: AppTextStyles.bodyMedium),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 20, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gagal memuat riwayat error: ${snapshot.error}',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loadErrors,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          );
        }
        final errors = snapshot.data ?? [];
        final isEmpty = errors.isEmpty;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isEmpty ? Icons.check_circle : Icons.error_outline,
                      size: 20,
                      color: isEmpty ? AppColors.success : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEmpty
                            ? 'Tidak ada import bermasalah'
                            : '${errors.length} baris bermasalah dari '
                                '${errors.map((e) => e.fileName ?? '-').toSet().length} file',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
                if (!isEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showErrorsDialog(context, errors),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Lihat Detail'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.readOnly
                            ? null
                            : () => _clearErrors(context),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Bersihkan'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _clearErrors(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ResponsiveAlertDialog(
        title: const Text('Bersihkan Error?'),
        content: const Text(
          'Semua record error import akan dihapus dari database. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Bersihkan'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final provider = context.read<AdminProvider>();
      final success = await provider.clearImportErrors();
      if (context.mounted) {
        if (success) {
          _loadErrors();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(success ? 'Error berhasil dibersihkan' : 'Gagal membersihkan error'),
              ],
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showErrorsDialog(BuildContext context, List<SyncError> errors) async {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    await showDialog(
      context: context,
      builder: (ctx) => ResponsiveDialog(
        showCloseButton: true,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.errorBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          const Icon(Icons.error, color: AppColors.error, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Error Import',
                              style: AppTextStyles.headlineSmall),
                          Text(
                            'Baris yang dilewati saat proses import. Buka file asli dan perbaiki sesuai pesan di bawah.',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: errors.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.successBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle,
                                  size: 40, color: AppColors.success),
                            ),
                            const SizedBox(height: 16),
                            const Text('Tidak ada error',
                                style: AppTextStyles.headlineSmall),
                            const SizedBox(height: 4),
                            const Text(
                              'Semua baris berhasil diproses',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: errors.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _buildErrorTile(errors[i], dateFormat),
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildErrorTile(SyncError err, DateFormat dateFormat) {
    final isStore = err.isStoreImport;
    final tint = isStore ? AppColors.success : AppColors.info;
    final tintBg = isStore ? AppColors.successBg : AppColors.infoBg;
    final tintBorder = isStore ? AppColors.successBorder : AppColors.infoBorder;
    final typeLabel = isStore ? 'Toko' : 'Produk';

    DateTime? ts;
    if (err.timestamp != null) {
      ts = DateTime.tryParse(err.timestamp!)?.toWita();
    }
    final tsText = ts != null ? dateFormat.format(ts) : '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tintBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: tintBorder),
                ),
                child: Text(
                  typeLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: tint,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (err.fileName != null && err.fileName!.isNotEmpty)
                Expanded(
                  child: Text(
                    err.fileName!,
                    style: AppTextStyles.mono.copyWith(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              Text(
                tsText,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber,
                  size: 18, color: AppColors.error),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Baris ${err.row}',
                  style: AppTextStyles.mono.copyWith(
                    color: AppColors.error,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  err.reason,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          if (err.sku != null && err.sku!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Row(
                children: [
                  Text(
                    'SKU/Kode: ',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    err.sku!,
                    style: AppTextStyles.mono.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImportHistorySection extends StatefulWidget {
  const _ImportHistorySection({super.key});

  @override
  State<_ImportHistorySection> createState() => _ImportHistorySectionState();
}

class _ImportHistorySectionState extends State<_ImportHistorySection> {
  static const int _pageSize = 5;
  late Future<List<Map<String, dynamic>>> _logsFuture;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _logsFuture = context.read<AdminProvider>().getImportLogs();
  }

  void _refresh() {
    setState(() {
      _logsFuture = context.read<AdminProvider>().getImportLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _logsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final allLogs = snapshot.data ?? const <Map<String, dynamic>>[];
        final totalPages = allLogs.isEmpty
            ? 1
            : (allLogs.length / _pageSize).ceil();
        final page = _currentPage.clamp(1, totalPages);
        final start = (page - 1) * _pageSize;
        final end = (start + _pageSize).clamp(0, allLogs.length);
        final logs = allLogs.sublist(start, end);

        if (allLogs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 36, color: AppColors.textMuted.withValues(alpha: 0.4)),
                    const SizedBox(height: 8),
                    const Text('Belum ada histori import', style: AppTextStyles.bodyMedium),
                  ],
                ),
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (ctx, constraints) {
            final resp = Responsive.of(constraints.maxWidth);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    resp.isDesktop
                        ? _buildDesktopTable(logs)
                        : _buildMobileList(logs),
                    const SizedBox(height: 12),
                    _paginationBar(total: allLogs.length, page: page, totalPages: totalPages),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> logs) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: _FlexHeaderCell(label: 'Waktu')),
              Expanded(flex: 2, child: _FlexHeaderCell(label: 'User')),
              Expanded(flex: 1, child: _FlexHeaderCell(label: 'Baru', align: TextAlign.right)),
              Expanded(flex: 1, child: _FlexHeaderCell(label: 'Update', align: TextAlign.right)),
              Expanded(flex: 2, child: _FlexHeaderCell(label: 'Tipe', align: TextAlign.center)),
              Expanded(flex: 1, child: _FlexHeaderCell(label: 'Error', align: TextAlign.right)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ...logs.map((log) => _FlexImportLogRow(log: log, dateFormat: dateFormat)),
      ],
    );
  }

  Widget _buildMobileList(List<Map<String, dynamic>> logs) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    return Column(
      children: logs.map((log) => _ImportLogCard(log: log, dateFormat: dateFormat)).toList(),
    );
  }

  Widget _paginationBar({required int total, required int page, required int totalPages}) {
    final canPrev = page > 1;
    final canNext = page < totalPages;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total: $total histori',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: canPrev ? () => setState(() => _currentPage = page - 1) : null,
                child: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 8),
              Text(
                'Halaman $page dari $totalPages',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: canNext ? () => setState(() => _currentPage = page + 1) : null,
                child: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlexHeaderCell extends StatelessWidget {
  final String label;
  final TextAlign align;

  const _FlexHeaderCell({
    required this.label,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: align,
      style: AppTextStyles.bodySmall.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _FlexImportLogRow extends StatelessWidget {
  final Map<String, dynamic> log;
  final DateFormat dateFormat;

  const _FlexImportLogRow({required this.log, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final createdAt = log['created_at'] != null
        ? DateTime.tryParse(log['created_at'].toString())
        : null;
    final skipped = log['skipped'] as int? ?? 0;
    final type = log['import_type']?.toString() ?? 'PRODUCT';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: skipped > 0 ? AppColors.errorBg.withValues(alpha: 0.3) : null,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              createdAt != null ? dateFormat.format(createdAt.toWita()) : '-',
              style: AppTextStyles.mono.copyWith(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              log['nama']?.toString() ?? 'Admin',
              style: AppTextStyles.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${log['inserted'] ?? 0}',
              textAlign: TextAlign.right,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${log['updated'] ?? 0}',
              textAlign: TextAlign.right,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryLight),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: type == 'PRODUCT' ? AppColors.infoBg : AppColors.successBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  type == 'PRODUCT' ? 'Produk' : 'Toko',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: type == 'PRODUCT' ? AppColors.info : AppColors.success,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '$skipped',
              textAlign: TextAlign.right,
              style: AppTextStyles.bodySmall.copyWith(
                color: skipped > 0 ? AppColors.error : AppColors.textMuted,
                fontWeight: skipped > 0 ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportLogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final DateFormat dateFormat;

  const _ImportLogCard({required this.log, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final createdAt = log['created_at'] != null
        ? DateTime.tryParse(log['created_at'].toString())
        : null;
    final skipped = log['skipped'] as int? ?? 0;
    final type = log['import_type']?.toString() ?? 'PRODUCT';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: skipped > 0 ? AppColors.errorBg.withValues(alpha: 0.3) : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: skipped > 0 ? AppColors.error.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      createdAt != null ? dateFormat.format(createdAt.toWita()) : '-',
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      log['nama']?.toString() ?? 'Admin',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: type == 'PRODUCT' ? AppColors.infoBg : AppColors.successBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  type == 'PRODUCT' ? 'Produk' : 'Toko',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: type == 'PRODUCT' ? AppColors.info : AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Baru',
                  value: '${log['inserted'] ?? 0}',
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Update',
                  value: '${log['updated'] ?? 0}',
                  color: AppColors.primaryLight,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Error',
                  value: '$skipped',
                  color: skipped > 0 ? AppColors.error : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


class _CustomerImportCard extends StatefulWidget {
  final GlobalKey<_ImportHistorySectionState> historyKey;
  final GlobalKey<_SyncErrorsSectionState> errorsKey;
  final bool readOnly;

  const _CustomerImportCard({
    required this.historyKey,
    required this.errorsKey,
    this.readOnly = false,
  });

  @override
  State<_CustomerImportCard> createState() => _CustomerImportCardState();
}


class _CustomerImportCardState extends State<_CustomerImportCard> {
  bool _importing = false;

  GlobalKey<_ImportHistorySectionState> get _historyKey => widget.historyKey;
  GlobalKey<_SyncErrorsSectionState> get _errorsKey => widget.errorsKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.store, size: 32, color: AppColors.success),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Import Toko',
                          style: AppTextStyles.headlineMedium),
                      SizedBox(height: 4),
                      Text(
                        'Upload .xlsx untuk data toko',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: (_importing || widget.readOnly)
                    ? null
                    : () => _pickAndImport(context, context.read<AdminProvider>()),
                icon: _importing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.folder_open),
                label: Text(_importing
                    ? 'Mengimport...'
                    : 'Pilih File Excel Toko (.xlsx)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndImport(BuildContext context, AdminProvider provider) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Gagal membaca file'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _importing = true);
    final success = await provider.importCustomersExcel(file.bytes!, file.name);
    if (!mounted) return;
    setState(() => _importing = false);

    if (success) {
      _historyKey.currentState?._refresh();
      _errorsKey.currentState?._refresh();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(provider.lastSyncResult?.message ?? 'Import toko berhasil'),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Import toko gagal'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}


