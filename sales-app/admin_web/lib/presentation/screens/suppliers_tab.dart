import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin_web/core/design_system.dart';
import 'package:admin_web/core/responsive.dart';
import 'package:admin_web/data/models/supplier.dart';
import 'package:admin_web/presentation/providers/admin_provider.dart';
import 'package:admin_web/presentation/widgets/data_card.dart';
import 'package:admin_web/presentation/widgets/error_state.dart';
import 'package:admin_web/presentation/widgets/loading_state.dart';
import 'package:admin_web/presentation/widgets/responsive_action_menu.dart';
import 'package:admin_web/presentation/widgets/supplier_create_dialog.dart';
import 'package:admin_web/presentation/widgets/supplier_edit_order_type_dialog.dart';
import 'package:admin_web/presentation/widgets/supplier_toggle_dialog.dart';

class SuppliersTab extends StatefulWidget {
  const SuppliersTab({super.key});

  @override
  State<SuppliersTab> createState() => _SuppliersTabState();
}

class _SuppliersTabState extends State<SuppliersTab> {
  bool? _activeFilter; // null = semua
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadSuppliers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final loading = provider.suppliersLoading;
    final error = provider.suppliersError;
    final isManager = provider.userRole == 'MANAGER';
    final allRows = provider.suppliers;
    final rows = allRows.where((s) {
      if (_activeFilter != null && s.isActive != _activeFilter!) return false;
      if (_search.isNotEmpty && !s.name.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Search bar + counter pill
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari supplier...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _search = '');
                                },
                              )
                            : null,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Counter pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${allRows.length} supplier',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Filter chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _chip('Semua', _activeFilter == null, () => setState(() => _activeFilter = null)),
                  _chip('Aktif', _activeFilter == true, () => setState(() => _activeFilter = true)),
                  _chip('Non-Aktif', _activeFilter == false, () => setState(() => _activeFilter = false)),
                  if (isManager)
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Buat Supplier Baru'),
                      onPressed: () => _onCreate(context),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const LoadingState()
              : error != null
                  ? ErrorState(
                      message: error,
                      onRetry: () => provider.loadSuppliers(),
                    )
                  : rows.isEmpty
                      ? _buildEmptyState()
                      : LayoutBuilder(
                          builder: (ctx, c) {
                            final resp = Responsive.of(c.maxWidth);
                            return resp.isDesktop
                                ? _table(context, rows, isManager)
                                : _cardList(context, rows, isManager);
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_outlined,
            size: 48,
            color: AppColors.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            _search.isNotEmpty
                ? 'Tidak ada supplier yang cocok dengan pencarian "$_search"'
                : 'Belum ada supplier yang terdaftar',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
  }

  Widget _table(BuildContext context, List<Supplier> rows, bool isManager) {
    return Column(
      children: [
        _tableHeader(isManager),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (ctx, i) => _row(ctx, rows[i], isManager),
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(bool isManager) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: Text(
                'NAMA SUPPLIER',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'STATUS',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'TIPE ORDER',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'JUMLAH PRODUK',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
          if (isManager)
            SizedBox(
              width: 80,
              child: Center(
                child: Text(
                  'AKSI',
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardList(BuildContext context, List<Supplier> rows, bool isManager) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth >= 1024 ? 3 : maxWidth >= 768 ? 2 : 1;
        final hPadding = 16.0;
        final gap = 16.0;
        final cardWidth = (maxWidth - 2 * hPadding - (columns - 1) * gap) / columns;

        return SingleChildScrollView(
          padding: EdgeInsets.all(hPadding),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: rows.map((s) => SizedBox(
              width: cardWidth,
              child: _rowCard(context, s, isManager),
            )).toList(),
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, Supplier s, bool isManager) {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                s.name,
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(child: _statusBadge(s.isActive)),
          ),
          Expanded(
            flex: 1,
            child: Center(child: _orderTypeBadge(s.orderType)),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                '${s.productCount}',
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ),
          if (isManager)
            SizedBox(
              width: 80,
              child: Center(
                child: IconButton(
                  icon: Icon(
                    s.isActive ? Icons.toggle_off_outlined : Icons.toggle_on_outlined,
                    size: 20,
                  ),
                  tooltip: s.isActive ? 'Nonaktifkan' : 'Aktifkan',
                  onPressed: () => _onToggle(context, s),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rowCard(BuildContext context, Supplier s, bool isManager) {
    return DataCard(
      title: s.name,
      badges: [_statusBadge(s.isActive), _orderTypeBadge(s.orderType)],
      fields: [
        DataField(label: 'Jumlah Produk', value: '${s.productCount}'),
      ],
      actions: isManager
          ? [
              ResponsiveActionMenu(
                actions: [
                  MenuAction(
                    label: 'Ubah Tipe Order',
                    icon: Icons.swap_horiz,
                    onTap: () => _onEditOrderType(context, s),
                  ),
                  MenuAction(
                    label: s.isActive ? 'Nonaktifkan' : 'Aktifkan',
                    icon: s.isActive ? Icons.toggle_off : Icons.toggle_on,
                    onTap: () => _onToggle(context, s),
                  ),
                ],
              ),
            ]
          : null,
    );
  }

  Widget _statusBadge(bool isActive) {
    final c = isActive ? AppColors.success : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Non-Aktif',
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _orderTypeBadge(String orderType) {
    final is4P = orderType == '4P';
    final c = is4P ? AppColors.info : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        orderType,
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _onCreate(BuildContext context) async {
    final result = await showSupplierCreateDialog(context);
    if (result == null) return;
    if (!context.mounted) return;
    try {
      await context.read<AdminProvider>().createSupplier(
            result.name,
            orderType: result.orderType,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Supplier "${result.name}" (${result.orderType}) berhasil dibuat',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat supplier: $e')),
        );
      }
    }
  }

  Future<void> _onToggle(BuildContext context, Supplier s) async {
    final ok = await showSupplierToggleDialog(context, supplier: s);
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      await context.read<AdminProvider>().toggleSupplierActive(s);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah status supplier: $e')),
        );
      }
    }
  }

  Future<void> _onEditOrderType(BuildContext context, Supplier s) async {
    final newType = await showSupplierEditOrderTypeDialog(
      context,
      supplier: s,
    );
    if (newType == null || newType == s.orderType) return;
    if (!context.mounted) return;
    try {
      await context.read<AdminProvider>().updateSupplierOrderType(s, newType);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tipe order ${s.name}: ${s.orderType} → $newType '
              '(${s.productCount} produk ter-update)',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah tipe order: $e')),
        );
      }
    }
  }
}
