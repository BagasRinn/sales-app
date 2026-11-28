import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_system.dart';
import '../../core/page_capture.dart';
import '../../core/responsive.dart';
import '../../data/models/inventory_tracker.dart';
import '../widgets/analytics/sales_analytics_models.dart';
import '../providers/admin_provider.dart';

enum InventoryTrackerDimension { supplier, sku }

class InventoryTrackerTab extends StatefulWidget {
  const InventoryTrackerTab({
    super.key,
    this.dimension = InventoryTrackerDimension.supplier,
  });

  final InventoryTrackerDimension dimension;

  @override
  State<InventoryTrackerTab> createState() => _InventoryTrackerTabState();
}

class _InventoryTrackerTabState extends State<InventoryTrackerTab> {
  late DateTime _month;
  String _branch = '';
  String _division = '';
  String _supplier = '';
  bool _initialized = false;
  // Lazy rendering: tabel hanya membangun sebagian baris per tahap supaya
  // halaman tetap lancar saat data ribuan (mis. Stok By SKU).
  int _visibleCount = 100;
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  // Tombol "Ambil Gambar": saat capture, semua baris yang lolos filter
  // dirender penuh, tabel dilepas dari scroll horizontal, lalu halaman
  // dirasterisasi jadi satu PNG dan diunduh.
  final GlobalKey _captureKey = GlobalKey();
  bool _capturing = false;
  // Tabel lebih lebar dari layar digulir horizontal di bagian body; offset
  // body disalin ke header sticky supaya judul kolom tetap sejajar isinya.
  final ScrollController _tableScrollController = ScrollController();
  final ScrollController _headerScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tableScrollController.addListener(_syncHeaderScroll);
    _headerScrollController.addListener(_syncBodyScroll);
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _tableScrollController.removeListener(_syncHeaderScroll);
    _headerScrollController.removeListener(_syncBodyScroll);
    _tableScrollController.dispose();
    _headerScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _syncHeaderScroll() =>
      _syncScroll(_tableScrollController, _headerScrollController);

  void _syncBodyScroll() =>
      _syncScroll(_headerScrollController, _tableScrollController);

  /// Salin offset [source] ke [target], dibatasi rentang target. Pergeseran
  /// di-skip kalau selisihnya nyaris nol supaya sinkronisasi dua arah tidak
  /// saling memicu terus.
  void _syncScroll(ScrollController source, ScrollController target) {
    if (!source.hasClients || !target.hasClients) return;
    final targetPosition = target.position;
    final value = source.offset.clamp(
      targetPosition.minScrollExtent,
      targetPosition.maxScrollExtent,
    );
    if ((targetPosition.pixels - value).abs() > 0.5) {
      target.jumpTo(value);
    }
  }

  bool get _isSku => widget.dimension == InventoryTrackerDimension.sku;
  String get _pageTitle => _isSku ? 'Stok By SKU' : 'Stok By Supplier';
  String get _firstColumnTitle => _isSku ? 'Mother SKU' : 'Supplier';
  String get _dimensionParam => _isSku ? 'sku' : 'supplier';

  String _monthLabel(String value) {
    final parts = value.split('-');
    if (parts.length != 2) return value;
    final parsed = DateTime.tryParse('${parts[0]}-${parts[1]}-01');
    return parsed == null ? value : formatMonthLong(parsed);
  }

  String get _monthKey =>
      '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}';

  void _load(AdminProvider provider) {
    provider.loadInventoryTracker(
      month: _monthKey,
      branch: provider.isManager && _branch.isNotEmpty ? _branch : null,
      division: _division.isNotEmpty ? _division : null,
      supplier: _isSku && _supplier.isNotEmpty ? _supplier : null,
      dimension: _dimensionParam,
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

  /// Render semua baris yang lolos filter, rasterisasi halaman jadi satu PNG
  /// (termasuk bagian di bawah lipatan layar), unduh, lalu kembalikan tabel ke
  /// mode hemat baris.
  Future<void> _capture(AdminProvider provider) async {
    final data = provider.inventoryTracker;
    if (data == null || _capturing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _capturing = true;
      _visibleCount = _filteredRows(data).length;
    });
    try {
      // Dua endOfFrame: pertama membangun ulang halaman dengan semua baris,
      // kedua memastikan frame tersebut benar-benar selesai dirasterisasi.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      await captureFullPage(
        boundaryKey: _captureKey,
        filename: 'stok-by-$_dimensionParam-$_monthKey.png',
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Gambar halaman berhasil diunduh.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil gambar: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
          _visibleCount = 100;
        });
      }
    }
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
      if (data != null &&
          data.dimension != _dimensionParam &&
          !provider.inventoryTrackerLoading) {
        // IndexedStack keeps both tracker pages alive. Reload immediately when
        // the shared provider currently contains the other dimension.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              !context.read<AdminProvider>().inventoryTrackerLoading) {
            _load(context.read<AdminProvider>());
          }
        });
      }
      final responsive = Responsive.of(MediaQuery.sizeOf(context).width);
      Widget page = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_pageTitle, style: AppTextStyles.headlineSmall),
          const SizedBox(height: 6),
          Text(
            _isSku
                ? 'Analisa nilai stok produk. Penjualan dan retur digabung menurut Mother SKU.'
                : 'Analisa nilai stok supplier berdasarkan penjualan tiga bulan sebelumnya.',
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
              _message('Snapshot GOOD AMOUNT bulan ini belum diimpor.', false),
            if (!data.salesHistoryAvailable)
              _message(
                'Belum ada riwayat penjualan pada tiga bulan sebelumnya.',
                false,
              ),
            _table(data),
          ],
        ],
      );
      if (_capturing) {
        // Selama capture konten dibungkus SizedBox selebar tabel minimum
        // (+16 longgar untuk margin Card) lalu diperkecil pas lebar halaman
        // oleh FittedBox, sehingga semua kolom masuk gambar meskipun layar
        // lebih sempit dari tabel.
        page = FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: SizedBox(width: _minTableWidth + 16, child: page),
        );
      }
      return SingleChildScrollView(
        padding: EdgeInsets.all(responsive.contentPadding),
        child: RepaintBoundary(key: _captureKey, child: page),
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
        if (_isSku)
          _selector(
            icon: Icons.local_shipping_outlined,
            tooltip: 'Filter supplier',
            width: 240,
            value: _supplier,
            items: [
              ('', 'Semua supplier'),
              ...?data?.suppliers.map((s) => (s, s)),
            ],
            loading: false,
            onChanged: (value) {
              setState(() => _supplier = value);
              _load(provider);
            },
          ),
        if (data != null &&
            data.rows.isNotEmpty &&
            !provider.inventoryTrackerLoading &&
            !_capturing)
          AppButton(
            label: 'Ambil Gambar',
            icon: Icons.photo_camera_outlined,
            variant: AppButtonVariant.outline,
            onPressed: () => _capture(provider),
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
        height: 34,
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
      height: 34,
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
      _card(_isSku ? 'Produk' : 'Supplier', '${data.supplierCount}'),
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
  static const _colWidthProduct = 360.0;
  static const _visibleStep = 200;

  double get _minTableWidth =>
      (_isSku ? _colWidthProduct : _colWidthSupplier) +
      _colWidthNum * 7 +
      _colWidthSmall;

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

  /// Baris setelah filter pencarian klien (huruf besar-kecil diabaikan).
  List<InventoryTrackerRow> _filteredRows(InventoryTrackerResponse data) {
    final query = _search.trim().toUpperCase();
    if (query.isEmpty) return data.rows;
    return data.rows
        .where((r) => r.name.toUpperCase().contains(query))
        .toList();
  }

  Widget _table(InventoryTrackerResponse data) {
    final filtered = _filteredRows(data);
    final visible = filtered.take(_visibleCount).toList();
    final hasMore = filtered.length > visible.length;

    final headerRow = TableRow(
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      children: [
        _col(_firstColumnTitle, endAlign: false),
        _col(_monthLabel(data.month)),
        _col('Stock'),
        ...data.previousMonths.map((m) => _col(_monthLabel(m))),
        _col('AP3M'),
        _col('Avg / Week'),
        _col('Week of Inventory'),
      ],
    );

    final bodyRows = visible.map(_row).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              height: 34,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() {
                  _search = v;
                  _visibleCount = 100;
                }),
                style: AppTextStyles.bodySmall,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Cari ${_firstColumnTitle.toLowerCase()}...',
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _search = '';
                              _visibleCount = 100;
                            });
                          },
                        ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.md,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.md,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            Text(
              'Menampilkan ${visible.length} dari ${filtered.length} baris',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          clipBehavior: Clip.none,
          child: AppStickyHeader(
            header: LayoutBuilder(
              builder: (context, constraints) {
                // Header dan body memakai lebar tabel yang sama. Saat layar
                // sempit body punya scroll horizontal sendiri, lalu listener
                // di controller menggeser header dengan offset yang sama
                // supaya judul kolom tetap sejajar dengan isinya.
                final tableWidth = constraints.maxWidth < _minTableWidth
                    ? _minTableWidth
                    : constraints.maxWidth;
                return ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    controller: _headerScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: tableWidth,
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(),
                          1: FixedColumnWidth(_colWidthNum),
                          2: FixedColumnWidth(_colWidthNum),
                          3: FixedColumnWidth(_colWidthNum),
                          4: FixedColumnWidth(_colWidthNum),
                          5: FixedColumnWidth(_colWidthNum),
                          6: FixedColumnWidth(_colWidthNum),
                          7: FixedColumnWidth(_colWidthNum),
                          8: FixedColumnWidth(_colWidthSmall),
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [headerRow],
                      ),
                    ),
                  ),
                );
              },
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fits =
                    _capturing || constraints.maxWidth >= _minTableWidth;
                final table = Table(
                  columnWidths: const {
                    0: FlexColumnWidth(),
                    1: FixedColumnWidth(_colWidthNum),
                    2: FixedColumnWidth(_colWidthNum),
                    3: FixedColumnWidth(_colWidthNum),
                    4: FixedColumnWidth(_colWidthNum),
                    5: FixedColumnWidth(_colWidthNum),
                    6: FixedColumnWidth(_colWidthNum),
                    7: FixedColumnWidth(_colWidthNum),
                    8: FixedColumnWidth(_colWidthSmall),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  border: const TableBorder(
                    horizontalInside: BorderSide(color: AppColors.border),
                  ),
                  children: bodyRows,
                );
                final content = fits
                    ? table
                    : SingleChildScrollView(
                        controller: _tableScrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(width: _minTableWidth, child: table),
                      );
                if (!hasMore) return content;
                return Column(
                  children: [
                    content,
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _visibleCount += _visibleStep),
                        icon: const Icon(Icons.expand_more, size: 18),
                        label: Text(
                          'Tampilkan $_visibleStep baris lagi '
                          '(${filtered.length - visible.length} tersisa)',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

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
        padded(
          Tooltip(
            message: row.name,
            waitDuration: const Duration(milliseconds: 350),
            child: _cell(row.name, endAlign: false),
          ),
        ),
        padded(_cell(formatRupiah(row.salesCurrentMonth))),
        padded(_cell(formatRupiah(row.stock))),
        ...row.previousSales.map((v) => padded(_cell(formatRupiah(v)))),
        padded(_cell(formatRupiah(row.ap3m))),
        padded(_cell(formatRupiah(row.averagePerWeek.round()))),
        padded(_cell(row.weekOfInventory?.toStringAsFixed(1) ?? '-')),
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    ),
  );
}
