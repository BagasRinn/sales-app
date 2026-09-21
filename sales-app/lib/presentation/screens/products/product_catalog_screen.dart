import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system.dart';
import '../../../data/models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({super.key});

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProductProvider>();
      if (provider.products.isEmpty) {
        provider.loadProducts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: AppColors.surface,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari produk...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        context.read<ProductProvider>().clearSearch();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (value) {
              setState(() {});
              if (value.length >= 2 || value.isEmpty) {
                context.read<ProductProvider>().search(value);
              }
            },
          ),
        ),
        // Product list
        Expanded(
          child: Consumer<ProductProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading && provider.products.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.errorMessage != null && provider.products.isEmpty) {
                return _ErrorState(
                  message: provider.errorMessage!,
                  onRetry: () => provider.loadProducts(),
                );
              }

              if (provider.products.isEmpty) {
                return _EmptyState(searchQuery: provider.searchQuery);
              }

              return RefreshIndicator(
                onRefresh: () => provider.loadProducts(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: provider.products.length,
                  itemBuilder: (context, index) {
                    return _ProductCard(product: provider.products[index]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

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
            Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty
                  ? 'Produk "$searchQuery" tidak ditemukan'
                  : 'Belum ada produk',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
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
    final fmtCurrency = context.read<ProductProvider>().formatCurrency;
    final cart = context.watch<CartProvider>();
    final inCart = cart.items.any((item) => item.productId == product.id);
    final available = product.stokTersedia;
    final status = stockStatusFromValue(available);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: name + stock chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.namaBarang,
                        style: AppTextStyles.headlineSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${product.id}',
                        style: AppTextStyles.mono,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                StockChip(available: available),
              ],
            ),
            const SizedBox(height: 16),
            // Divider
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 16),
            // Price + action row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fmtCurrency(product.harga),
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                    if (status == StockStatus.low)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 14, color: AppColors.warning),
                            const SizedBox(width: 4),
                            Text(
                              'Stok hampir habis',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                // Inline cart controls or add button
                if (inCart)
                  _InlineCartControls(
                    productId: product.id,
                    available: available,
                  )
                else
                  FilledButton.icon(
                    onPressed: status == StockStatus.outOfStock
                        ? null
                        : () {
                            cart.addProduct(product);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.namaBarang} ditambahkan'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Tambah'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

class _InlineCartControls extends StatelessWidget {
  final String productId;
  final int available;

  const _InlineCartControls({required this.productId, required this.available});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final item = cart.items.firstWhere((e) => e.productId == productId);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.infoBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: () => cart.decrementQty(productId),
            color: AppColors.primaryLight,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 36),
            alignment: Alignment.center,
            child: Text(
              '${item.qty}',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primaryLight,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: item.qty < available
                ? () => cart.incrementQty(productId, available)
                : null,
            color: AppColors.primaryLight,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }
}
