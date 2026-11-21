import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_system.dart';
import '../../core/responsive.dart';
import '../../data/models/inventory_tracker.dart';
import '../widgets/analytics/sales_analytics_models.dart';
import '../providers/admin_provider.dart';

class InventoryTrackerTab extends StatefulWidget {
  const InventoryTrackerTab({super.key});

  @override
  State<InventoryTrackerTab> createState() => _InventoryTrackerTabState();
}

class _InventoryTrackerTabState extends State<InventoryTrackerTab> {
  late DateTime _month;
  String _branch = '';
  String _division = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  String get _monthKey =>
      '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}';

  void _load(AdminProvider provider) {
    provider.loadInventoryTracker(
      month: _monthKey,
      branch: provider.isManager && _branch.isNotEmpty ? _branch : null,
      division: _division.isNotEmpty ? _division : null,
    );
    if (provider.isManager && provider.branchOptions.isEmpty) {
      provider.loadBranchOptions();
    }
  }

  Future<void> _pickMonth(AdminProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Pilih bulan',
    );
    if (picked == null) return;
    setState(() => _month = DateTime(picked.year, picked.month, 1));
    _load(provider);
  }

  void _moveMonth(AdminProvider provider, int offset) {
    setState(() => _month = DateTime(_month.year, _month.month + offset, 1));
    _load(provider);
  }

  @override
  Widget build(BuildContext context) => Consumer<AdminProvider>(
    builder: (context, provider, _) {
      if (!_initialized) {
        _initialized = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _load(context.read<AdminProvider>());
        });
      }
      final data = provider.inventoryTracker;
      final responsive = Responsive.of(MediaQuery.sizeOf(context).width);
      return SingleChildScrollView(
        padding: EdgeInsets.all(responsive.contentPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stok By Supplier', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Analisa nilai stok supplier berdasarkan penjualan tiga bulan sebelumnya.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSubtle,
              ),
            ),
            const SizedBox(height: 18),
            _toolbar(context, provider, data),
            const SizedBox(height: AppSpacing.md),
            if (provider.inventoryTrackerLoading && data == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (provider.inventoryTrackerError != null && data == null)
              _message(provider.inventoryTrackerError!, true)
            else if (data == null || data.rows.isEmpty)
              _message('Belum ada data untuk periode/cabang ini.', false)
            else ...[
              _summary(data),
              const SizedBox(height: 18),
              if (!data.stockSnapshotAvailable)
                _message(
                  'Snapshot GOOD AMOUNT bulan ini belum diimpor.',
                  false,
                ),
              if (!data.salesHistoryAvailable)
                _message(
                  'Belum ada riwayat penjualan pada tiga bulan sebelumnya.',
                  false,
                ),
              _table(data),
            ],
          ],
        ),
      );
    },
  );

  //Toolbar and filters
  Widget _toolbar(
    BuildContext context,
    AdminProvider provider,
    InventoryTrackerResponse? data,
  ) => AppCard(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (provider.isManager)
          _selector(
            icon: Icons.account_balance_outlined,
            tooltip: 'Filter cabang',
            width: 194,
            value: _branch,
            items: [
              ('', 'Semua cabang'),
              ...provider.branchOptions.map((b) => (b.code, b.nama)),
            ],
            loading: provider.branchOptionsLoading,
            onChanged: (value) {
              setState(() => _branch = value);
              _load(provider);
            },
          ),
        _SquareIconButton(
          icon: Icons.chevron_left,
          tooltip: 'Bulan sebelumnya',
          onPressed: () => _moveMonth(provider, -1),
        ),
        _monthButton(provider),
        _SquareIconButton(
          icon: Icons.chevron_right,
          tooltip: 'Bulan berikutnya',
          onPressed: () => _moveMonth(provider, 1),
        ),
        _selector(
          icon: Icons.category_outlined,
          tooltip: 'Filter divisi',
          width: 194,
          value: _division,
          items: [('', 'Semua divisi'), ...?data?.divisions.map((d) => (d, d))],
          loading: false,
          onChanged: (value) {
            setState(() => _division = value);
            _load(provider);
          },
        ),
      ],
    ),
  );

  Widget _monthButton(AdminProvider provider) => Material(
    color: AppColors.surface,
    borderRadius: AppRadius.md,
    child: InkWell(
      onTap: () => _pickMonth(provider),
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
            Text(formatMonthLong(_month), style: AppTextStyles.h3),
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
  );

  Widget _selector({
    required IconData icon,
    required String tooltip,
    required double width,
    required String value,
    required List<(String, String)> items,
    required bool loading,
    required ValueChanged<String> onChanged,
  }) => Tooltip(
    message: tooltip,
    child: Container(
      width: width,
      height: 40,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.textSecondary,
          ),
          dropdownColor: AppColors.surface,
          items: [
            for (final (code, label) in items)
              DropdownMenuItem(
                value: code,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: loading ? null : (v) => onChanged(v ?? ''),
        ),
      ),
    ),
  );

  Widget _summary(InventoryTrackerResponse data) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _card('Total Stock', formatRupiah(data.totalStock)),
      _card('AP3M', formatRupiah(data.totalAp3m)),
      _card('Average / Week', formatRupiah(data.totalAveragePerWeek.round())),
      _card('Penjualan Bulan Ini', formatRupiah(data.totalSalesCurrentMonth)),
      _card('Supplier', '${data.supplierCount}'),
      _card('Overstock', '${data.overstockCount}'),
    ],
  );

  Widget _card(String label, String value) => SizedBox(
    width: 180,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.bodySmall),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// Kolom angka memakai lebar tetap (px) agar tabel stabil di semua ukuran
  /// layar; melebihi lebar card di-scroll horizontal. Kolom angka rata kanan.
  static const _colWidthNum = 150.0;
  static const _colWidthSmall = 130.0;
  static const _colWidthSupplier = 220.0;

  Widget _headerCell(
    String label, {
    double width = _colWidthNum,
    bool endAlign = true,
  }) => SizedBox(
    width: width,
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: endAlign ? TextAlign.end : TextAlign.start,
      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
    ),
  );

  Widget _cell(
    String text, {
    double width = _colWidthNum,
    bool endAlign = true,
    bool muted = false,
  }) => SizedBox(
    width: width,
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: endAlign ? TextAlign.end : TextAlign.start,
      style: AppTextStyles.bodySmall.copyWith(
        color: muted ? AppColors.textSubtle : AppColors.textPrimary,
      ),
    ),
  );

  Widget _table(InventoryTrackerResponse data) => Card(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        horizontalMargin: 16,
        columns: [
          DataColumn(
            label: _headerCell(
              'Supplier',
              width: _colWidthSupplier,
              endAlign: false,
            ),
          ),
          DataColumn(label: _headerCell('Stock')),
          ...data.previousMonths.map((m) => DataColumn(label: _headerCell(m))),
          DataColumn(label: _headerCell('AP3M')),
          DataColumn(label: _headerCell('Avg / Week')),
          DataColumn(
            label: _headerCell('Week of Inventory', width: _colWidthSmall),
          ),
          DataColumn(
            label: _headerCell(
              'Status',
              width: _colWidthSmall,
              endAlign: false,
            ),
          ),
          DataColumn(label: _headerCell(data.month)),
        ],
        rows: data.rows.map(_row).toList(),
      ),
    ),
  );

  DataRow _row(InventoryTrackerRow row) => DataRow(
    cells: [
      DataCell(
        _cell(row.supplierName, width: _colWidthSupplier, endAlign: false),
      ),
      DataCell(_cell(formatRupiah(row.stock))),
      ...row.previousSales.map((v) => DataCell(_cell(formatRupiah(v)))),
      DataCell(_cell(formatRupiah(row.ap3m))),
      DataCell(_cell(formatRupiah(row.averagePerWeek.round()))),
      DataCell(
        _cell(
          row.weekOfInventory?.toStringAsFixed(1) ?? '-',
          width: _colWidthSmall,
        ),
      ),
      DataCell(
        _cell(row.inventoryStatus, width: _colWidthSmall, endAlign: false),
      ),
      DataCell(_cell(formatRupiah(row.salesCurrentMonth))),
    ],
  );

  Widget _message(String text, bool error) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: error ? AppColors.error : AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text),
  );
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
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
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
      ),
    ),
  );
}
