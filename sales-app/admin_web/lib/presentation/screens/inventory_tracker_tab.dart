import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
            Text('Stok Inventaris', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Analisa nilai stok supplier berdasarkan penjualan tiga bulan sebelumnya.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSubtle,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: () => _moveMonth(provider, -1),
                  child: const Icon(Icons.chevron_left),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickMonth(provider),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(DateFormat('MMMM yyyy', 'id_ID').format(_month)),
                ),
                OutlinedButton(
                  onPressed: () => _moveMonth(provider, 1),
                  child: const Icon(Icons.chevron_right),
                ),
                if (provider.isManager)
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _branch,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Cabang',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Semua cabang'),
                        ),
                        ...provider.branchOptions.map(
                          (b) => DropdownMenuItem(
                            value: b.code,
                            child: Text(
                              b.nama,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _branch = value ?? '');
                        _load(provider);
                      },
                    ),
                  ),
                const SizedBox(width: 220),
                if (data != null)
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _division,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Divisi',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Semua divisi'),
                        ),
                        ...data.divisions.map(
                          (division) => DropdownMenuItem(
                            value: division,
                            child: Text(
                              division,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _division = value ?? '');
                        _load(provider);
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
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

  Widget _table(InventoryTrackerResponse data) => Card(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Supplier')),
          const DataColumn(label: Text('Stock')),
          ...data.previousMonths.map((m) => DataColumn(label: Text(m))),
          const DataColumn(label: Text('AP3M')),
          const DataColumn(label: Text('Avg / Week')),
          const DataColumn(label: Text('Week of Inventory')),
          const DataColumn(label: Text('Status')),
          DataColumn(label: Text(data.month)),
        ],
        rows: data.rows.map(_row).toList(),
      ),
    ),
  );

  DataRow _row(InventoryTrackerRow row) => DataRow(
    cells: [
      DataCell(Text(row.supplierName)),
      DataCell(Text(formatRupiah(row.stock))),
      ...row.previousSales.map((v) => DataCell(Text(formatRupiah(v)))),
      DataCell(Text(formatRupiah(row.ap3m))),
      DataCell(Text(formatRupiah(row.averagePerWeek.round()))),
      DataCell(Text(row.weekOfInventory?.toStringAsFixed(1) ?? '-')),
      DataCell(Text(row.inventoryStatus)),
      DataCell(Text(formatRupiah(row.salesCurrentMonth))),
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
