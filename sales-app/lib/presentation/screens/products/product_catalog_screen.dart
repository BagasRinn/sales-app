import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system.dart';
import '../../../data/models/product.dart';
import '../../providers/product_provider.dart';

/// Katalog produk — read-only preview. Sales nggak bisa add dari sini,
/// itu lewat OrderFlowScreen → step_pick_products.
class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({super.key});

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProductProvider>();
      if (provider.products.isEmpty && !provider.isLoading) {
        provider.loadProducts();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CatalogHeader(
          searchController: _searchController,
          onSearchChanged: _onSearchChanged,
          onClearSearch: () {
            _searchController.clear();
            context.read<ProductProvider>().clearSearch();
            setState(() {});
          },
          onShowFilter: () => _showFilterBottomSheet(context),
        ),
        Expanded(child: _ProductList()),
      ],
    );
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (value.length >= 2 || value.isEmpty) {
        context.read<ProductProvider>().search(value);
      }
    });
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _FilterBottomSheet(),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onShowFilter;

  const _CatalogHeader({
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onShowFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            // Page title
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              color: AppColors.surface,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Katalog', style: AppTextStyles.headlineMedium),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: onShowFilter,
                        icon: Badge(
                          isLabelVisible: provider.hasActiveFilters,
                          label: Text(
                            '${(provider.statusFilter != ProductStatusFilter.all ? 1 : 0) + (provider.categoryFilter != null ? 1 : 0)}',
                            style: const TextStyle(fontSize: 9),
                          ),
                          child: const Icon(Icons.filter_list),
                        ),
                        tooltip: 'Filter',
                      ),
                      if (provider.hasActiveFilters)
                        IconButton(
                          onPressed: () => provider.clearFilters(),
                          icon: const Icon(Icons.filter_alt_off, size: 20),
                          color: AppColors.error,
                          tooltip: 'Reset Filter',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Search bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              color: AppColors.surface,
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Cari produk, SKU...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: onClearSearch,
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: onSearchChanged,
              ),
            ),
            // Status filter chips
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              color: AppColors.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StatusFilterChip(
                      label: 'Semua',
                      count: provider.countByStatusAll(ProductStatusFilter.all),
                      isSelected: provider.statusFilter == ProductStatusFilter.all,
                      onTap: () => provider.setStatusFilter(ProductStatusFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _StatusFilterChip(
                      label: 'Tersedia',
                      count: provider.countByStatusAll(ProductStatusFilter.available),
                      isSelected: provider.statusFilter == ProductStatusFilter.available,
                      onTap: () => provider.setStatusFilter(ProductStatusFilter.available),
                    ),
                    const SizedBox(width: 8),
                    _StatusFilterChip(
                      label: 'Stok Rendah',
                      count: provider.countByStatusAll(ProductStatusFilter.low),
                      isSelected: provider.statusFilter == ProductStatusFilter.low,
                      onTap: () => provider.setStatusFilter(ProductStatusFilter.low),
                    ),
                    const SizedBox(width: 8),
                    _StatusFilterChip(
                      label: 'Habis',
                      count: provider.countByStatusAll(ProductStatusFilter.outOfStock),
                      isSelected: provider.statusFilter == ProductStatusFilter.outOfStock,
                      onTap: () => provider.setStatusFilter(ProductStatusFilter.outOfStock),
                    ),
                  ],
                ),
              ),
            ),
            // Category filter dropdown
            if (provider.availableCategories.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                color: AppColors.surface,
                child: Row(
                  children: [
                    Expanded(
                      child: _CategoryDropdown(
                        categories: provider.availableCategories,
                        selectedCategory: provider.categoryFilter,
                        onChanged: (value) => provider.setCategoryFilter(value),
                      ),
                    ),
                    if (provider.categoryFilter != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => provider.setCategoryFilter(null),
                        icon: const Icon(Icons.clear, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.errorBg,
                          foregroundColor: AppColors.error,
                        ),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ),
            if (provider.availableCategories.isEmpty)
              const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primaryLight : AppColors.background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primaryLight : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown({
    required this.categories,
    required this.selectedCategory,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selectedCategory != null
              ? AppColors.primaryLight
              : AppColors.border,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCategory,
          hint: Row(
            children: [
              Icon(
                Icons.category_outlined,
                size: 18,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                'Filter Kategori',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                'Semua Kategori',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ...categories.map((cat) => DropdownMenuItem<String>(
                  value: cat,
                  child: Text(
                    cat,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ProductList extends StatefulWidget {
  @override
  State<_ProductList> createState() => _ProductListState();
}

class _ProductListState extends State<_ProductList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ProductProvider>().loadMoreProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.products.isEmpty) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: 8,
            itemBuilder: (context, index) => const _ProductSkeletonCard(),
          );
        }
        if (provider.errorMessage != null && provider.products.isEmpty) {
          return _ErrorState(
            message: provider.errorMessage!,
            onRetry: provider.loadProducts,
          );
        }
        if (provider.products.isEmpty) {
          return _EmptyState(searchQuery: provider.searchQuery);
        }
        return RefreshIndicator(
          onRefresh: provider.loadProducts,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            itemCount: provider.products.length + (provider.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= provider.products.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: _LoadingMoreSkeleton(),
                );
              }
              return _ProductCard(product: provider.products[index]);
            },
          ),
        );
      },
    );
  }
}

class _ProductSkeletonCard extends StatelessWidget {
  const _ProductSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            _SkeletonBox(width: 48, height: 48, borderRadius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(width: 150, height: 14),
                  const SizedBox(height: 6),
                  _SkeletonBox(width: 80, height: 10),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _SkeletonBox(width: 60, height: 18, borderRadius: 6),
                      const SizedBox(width: 8),
                      _SkeletonBox(width: 80, height: 12),
                    ],
                  ),
                ],
              ),
            ),
            _SkeletonBox(width: 70, height: 16),
          ],
        ),
      ),
    );
  }
}

class _LoadingMoreSkeleton extends StatelessWidget {
  const _LoadingMoreSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SkeletonBox(width: 20, height: 20, borderRadius: 10),
        const SizedBox(width: 12),
        _SkeletonBox(width: 100, height: 14),
      ],
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off, size: 40, color: AppColors.error),
            ),
            const SizedBox(height: 20),
            const Text('Gagal memuat produk', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String searchQuery;
  const _EmptyState({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 56,
                color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty
                  ? 'Produk "$searchQuery" tidak ditemukan'
                  : 'Belum ada produk',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final fmtCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final available = product.stokTersedia;
    final status = stockStatusFromValue(available);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDetail(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 22,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.namaBarang,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SKU: ${product.id}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _StockStatusChip(status: status),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'STOK $available ${product.satuan ?? "unit"}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  fmtCurrency.format(product.harga),
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final fmtCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final available = product.stokTersedia;
    final status = stockStatusFromValue(available);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header dengan icon + nama
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 28,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.namaBarang,
                          style: AppTextStyles.headlineSmall,
                        ),
                        Text(
                          'SKU: ${product.id}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _detailRow(Icons.qr_code, 'SKU', product.id),
              if (product.satuan != null)
                _detailRow(Icons.scale_outlined, 'Satuan', product.satuan!),
              if (product.kategori != null)
                _detailRow(Icons.category_outlined, 'Kategori', product.kategori!),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Harga', style: AppTextStyles.bodySmall),
                        const SizedBox(height: 4),
                        Text(
                          fmtCurrency.format(product.harga),
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Stok', style: AppTextStyles.bodySmall),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StockStatusChip(status: status),
                          const SizedBox(width: 6),
                          Text(
                            '$available',
                            style: AppTextStyles.headlineMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: available == 0
                                  ? AppColors.error
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Text('$label: ', style: AppTextStyles.bodySmall),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBottomSheet extends StatelessWidget {
  const _FilterBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Produk',
                    style: AppTextStyles.headlineSmall,
                  ),
                  if (provider.hasActiveFilters)
                    TextButton(
                      onPressed: () {
                        provider.clearFilters();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Hapus Semua',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // Status filter section
              const Text(
                'Status Stok',
                style: AppTextStyles.labelLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'Semua',
                    isSelected: provider.statusFilter == ProductStatusFilter.all,
                    onTap: () => provider.setStatusFilter(ProductStatusFilter.all),
                  ),
                  _FilterChip(
                    label: 'Tersedia',
                    isSelected: provider.statusFilter == ProductStatusFilter.available,
                    onTap: () => provider.setStatusFilter(ProductStatusFilter.available),
                  ),
                  _FilterChip(
                    label: 'Stok Rendah',
                    isSelected: provider.statusFilter == ProductStatusFilter.low,
                    onTap: () => provider.setStatusFilter(ProductStatusFilter.low),
                  ),
                  _FilterChip(
                    label: 'Habis',
                    isSelected: provider.statusFilter == ProductStatusFilter.outOfStock,
                    onTap: () => provider.setStatusFilter(ProductStatusFilter.outOfStock),
                  ),
                ],
              ),
              if (provider.availableCategories.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Kategori',
                  style: AppTextStyles.labelLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'Semua',
                      isSelected: provider.categoryFilter == null,
                      onTap: () => provider.setCategoryFilter(null),
                    ),
                    ...provider.availableCategories.map((cat) => _FilterChip(
                          label: cat,
                          isSelected: provider.categoryFilter == cat,
                          onTap: () => provider.setCategoryFilter(cat),
                        )),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    provider.hasActiveFilters
                        ? 'Tampilkan ${provider.productCount} Produk'
                        : 'Tampilkan Semua',
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primaryLight : AppColors.background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primaryLight : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StockStatusChip extends StatelessWidget {
  final StockStatus status;
  const _StockStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      StockStatus.available => AppColors.success,
      StockStatus.low => AppColors.warning,
      StockStatus.outOfStock => AppColors.error,
    };
    final label = switch (status) {
      StockStatus.available => 'Tersedia',
      StockStatus.low => 'Stok Rendah',
      StockStatus.outOfStock => 'Habis',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
