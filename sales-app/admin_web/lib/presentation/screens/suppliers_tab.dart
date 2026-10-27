import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin_web/core/design_system.dart';
import 'package:admin_web/core/responsive.dart';
import 'package:admin_web/data/models/supplier.dart';
import 'package:admin_web/presentation/providers/admin_provider.dart';
import 'package:admin_web/presentation/widgets/data_card.dart';
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
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadSuppliers();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final loading = provider.suppliersLoading;
    final error = provider.suppliersError;
    final isManager = provider.userRole == 'MANAGER';
    final rows = provider.suppliers;

    return Column(
      children: [
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
                                  _searchDebounce?.cancel();
                                  _searchController.clear();
                                  setState(() => _search = '');
                                  provider.loadSuppliers(search: '', page: 0);
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (v) {
                        setState(() => _search = v);
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 400),
                          () {
                            setState(() => _search = v.trim());
                            provider.loadSuppliers(search: v.trim(), page: 0);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${provider.supplierTotal} supplier',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 400;
                  final filters = Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _chip('Semua', _activeFilter == null, () {
                        setState(() => _activeFilter = null);
                        provider.setSupplierActiveFilter(null);
                      }),
                      _chip('Aktif', _activeFilter == true, () {
                        setState(() => _activeFilter = true);
                        provider.setSupplierActiveFilter(true);
                      }),
                      _chip('Non-Aktif', _activeFilter == false, () {
                        setState(() => _activeFilter = false);
                        provider.setSupplierActiveFilter(false);
                      }),
                      if (isManager)
                        AppButton(
                          icon: Icons.add,
                          label: 'Buat Supplier',
                          onPressed: () => _onCreate(context),
                        ),
                    ],
                  );
                  return isNarrow ? filters : filters;
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: AppSkeletonList(),
                )
              : error != null
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AppErrorState(
                    message: error,
                    onRetry: () => provider.loadSuppliers(),
                  ),
                )
              : rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AppEmptyState(
                    icon: Icons.store_outlined,
                    title: _search.isNotEmpty
                        ? 'Supplier tidak ditemukan'
                        : 'Belum ada supplier',
                    message: _search.isNotEmpty
                        ? 'Tidak ada supplier yang cocok dengan "$_search".'
                        : 'Tambahkan supplier untuk mulai memetakan produk.',
                  ),
                )
              : LayoutBuilder(
                  builder: (ctx, c) {
                    final resp = Responsive.of(c.maxWidth);
                    return resp.isDesktop
                        ? _table(context, rows, isManager)
                        : _cardList(context, rows, isManager);
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: provider.hasPrevSupplierPage
                    ? provider.prevSupplierPage
                    : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Halaman sebelumnya',
              ),
              const SizedBox(width: 8),
              Text(
                'Halaman ${provider.supplierPage + 1} dari '
                '${provider.supplierTotalPages == 0 ? 1 : provider.supplierTotalPages}',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: provider.hasNextSupplierPage
                    ? provider.nextSupplierPage
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Halaman berikutnya',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return AppChoiceChip(
      label: label,
      selected: selected,
      dense: true,
      onSelected: onTap,
    );
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
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'STATUS',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'TIPE ORDER',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'JUMLAH PRODUK',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          if (isManager)
            SizedBox(
              width: 80,
              child: Center(
                child: Text(
                  'AKSI',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
        final columns = maxWidth >= 1024
            ? 3
            : maxWidth >= 768
            ? 2
            : 1;
        final hPadding = 16.0;
        final gap = 16.0;
        final cardWidth =
            (maxWidth - 2 * hPadding - (columns - 1) * gap) / columns;

        return SingleChildScrollView(
          padding: EdgeInsets.all(hPadding),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: rows
                .map(
                  (s) => SizedBox(
                    width: cardWidth,
                    child: _rowCard(context, s, isManager),
                  ),
                )
                .toList(),
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
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(flex: 1, child: Center(child: _statusBadge(s.isActive))),
          Expanded(flex: 1, child: Center(child: _orderTypeBadge(s.orderType))),
          Expanded(
            flex: 1,
            child: Center(
              child: Text('${s.productCount}', style: AppTextStyles.bodyMedium),
            ),
          ),
          if (isManager)
            SizedBox(
              width: 80,
              child: Center(
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  tooltip: 'Aksi',
                  itemBuilder: (ctx) => [
                    const PopupMenuItem<String>(
                      value: 'order_type',
                      height: 44,
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz, size: 18),
                          SizedBox(width: 8),
                          Text('Ubah Tipe Order'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'toggle',
                      height: 44,
                      child: Row(
                        children: [
                          Icon(
                            s.isActive ? Icons.toggle_off : Icons.toggle_on,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(s.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (action) {
                    if (action == 'order_type') {
                      _onEditOrderType(context, s);
                    } else if (action == 'toggle') {
                      _onToggle(context, s);
                    }
                  },
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
      fields: [DataField(label: 'Jumlah Produk', value: '${s.productCount}')],
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
    return AppBadge(
      label: isActive ? 'Aktif' : 'Non-Aktif',
      variant: isActive ? AppBadgeVariant.success : AppBadgeVariant.neutral,
    );
  }

  Widget _orderTypeBadge(String orderType) {
    return AppBadge(
      label: orderType,
      variant: orderType == '4P'
          ? AppBadgeVariant.info
          : AppBadgeVariant.neutral,
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
        AppSnack.success(
          context,
          'Supplier "${result.name}" (${result.orderType}) berhasil dibuat',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnack.error(context, 'Gagal membuat supplier: $e');
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
        AppSnack.error(context, 'Gagal mengubah status supplier: $e');
      }
    }
  }

  Future<void> _onEditOrderType(BuildContext context, Supplier s) async {
    final newType = await showSupplierEditOrderTypeDialog(context, supplier: s);
    if (newType == null || newType == s.orderType) return;
    if (!context.mounted) return;
    try {
      await context.read<AdminProvider>().updateSupplierOrderType(s, newType);
      if (context.mounted) {
        AppSnack.success(
          context,
          'Tipe order ${s.name}: ${s.orderType} → $newType '
          '(${s.productCount} produk ter-update)',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnack.error(context, 'Gagal mengubah tipe order: $e');
      }
    }
  }
}
