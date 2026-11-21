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

  /// Tabel memakai widget `Table` langsung (bukan `DataTable`) supaya kolom
  /// Supplier bisa `FlexColumnWidth` — melebar sampai mentok tepi kanan
  /// container seperti kotak filter. Kolom angka tetap (px); di layar sempit
  /// tabel di-scroll horizontal dengan lebar minimum.
  static const _colWidthNum = 150.0;
  static const _colWidthSmall = 130.0;
  static const _colWidthSupplier = 220.0;
  static const _minTableWidth =
      _colWidthSupplier + _colWidthNum * 7 + _colWidthSmall;

  Widget _headerCell(String label, {bool endAlign = true}) => Align(
    alignment: endAlign ? Alignment.centerRight : Alignment.centerLeft,
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
    ),
  );

  Widget _cell(String text, {bool endAlign = true, bool bold = false}) => Align(
    alignment: endAlign ? Alignment.centerRight : Alignment.centerLeft,
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.bodySmall.copyWith(
        fontWeight: bold ? FontWeight.w600 : null,
      ),
    ),
  );

  TableCell _col(String label, {bool endAlign = true}) => TableCell(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: _headerCell(label, endAlign: endAlign),
    ),
  );

  Widget _table(InventoryTrackerResponse data) => Card(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final fits = constraints.maxWidth >= _minTableWidth;
        final table = Table(
          columnWidths: const {
            0: FlexColumnWidth(),
            1: FixedColumnWidth(_colWidthNum), // Stock
            2: FixedColumnWidth(_colWidthNum),
            3: FixedColumnWidth(_colWidthNum),
            4: FixedColumnWidth(_colWidthNum),
            5: FixedColumnWidth(_colWidthNum), // AP3M
            6: FixedColumnWidth(_colWidthNum), // Avg / Week
            7: FixedColumnWidth(_colWidthSmall), // Week of Inventory
            8: FixedColumnWidth(_colWidthNum), // bulan berjalan
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: const TableBorder(
            horizontalInside: BorderSide(color: AppColors.border),
          ),
          children: [
            TableRow(
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              children: [
                _col('Supplier', endAlign: false),
                _col('Stock'),
                ...data.previousMonths.map((m) => _col(m)),
                _col('AP3M'),
                _col('Avg / Week'),
                _col('Week of Inventory'),
                _col(data.month),
              ],
            ),
            ...data.rows.map(_row),
          ],
        );
        if (fits) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: _minTableWidth, child: table),
        );
      },
    ),
  );

  /// Overstock: Week of Inventory > 6 minggu → baris merah lembut.
  bool _isOverstock(InventoryTrackerRow row) => (row.weekOfInventory ?? 0) > 6;

  TableRow _row(InventoryTrackerRow row) {
    final overstock = _isOverstock(row);
    TableCell padded(Widget child) => TableCell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: child,
      ),
    );
    return TableRow(
      decoration: BoxDecoration(
        color: overstock ? AppColors.error.withValues(alpha: 0.12) : null,
      ),
      children: [
        padded(_cell(row.supplierName, endAlign: false)),
        padded(_cell(formatRupiah(row.stock))),
        ...row.previousSales.map((v) => padded(_cell(formatRupiah(v)))),
        padded(_cell(formatRupiah(row.ap3m))),
        padded(_cell(formatRupiah(row.averagePerWeek.round()))),
        padded(_cell(row.weekOfInventory?.toStringAsFixed(1) ?? '-')),
        padded(_cell(formatRupiah(row.salesCurrentMonth))),
      ],
    );
  }

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
