import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system.dart';
import '../../providers/product_provider.dart';
import '../../providers/draft_order_provider.dart';

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({super.key});

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  final _searchController = TextEditingController();
  String _stockFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProductProvider>();
      if (provider.allProducts.isEmpty) {
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
    final provider = context.watch<ProductProvider>();
    final idr = NumberFormat('#,###', 'id');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Katalog Produk'),
      ),
      body: Column(
        children: [
          // Search
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                          provider.loadProducts();
                        },
                      )
                    : null,
              ),
              onSubmitted: (value) => provider.loadProducts(search: value),
            ),
          ),

          // Stock filter
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Semua', 'Tersedia', 'Stok Rendah', 'Habis'].map((filter) {
                  final isSelected = _stockFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _stockFilter = filter);
                      },
                      selectedColor: AppColors.infoBg,
                      checkmarkColor: AppColors.primaryLight,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Product list
          Expanded(
            child: provider.isLoading && provider.allProducts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.allProducts.isEmpty
                    ? Center(
                        child: Text(
                          'Produk tidak ditemukan',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : _buildProductList(provider, idr),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(ProductProvider provider, NumberFormat idr) {
    var products = provider.allProducts;

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      products = products.where((p) =>
          p.namaBarang.toLowerCase().contains(q) ||
          (p.kategori?.toLowerCase().contains(q) ?? false)).toList();
    }

    // Apply stock filter
    if (_stockFilter == 'Tersedia') {
      products = products.where((p) => p.stokTersedia > 5).toList();
    } else if (_stockFilter == 'Stok Rendah') {
      products = products.where((p) => p.stokTersedia > 0 && p.stokTersedia <= 5).toList();
    } else if (_stockFilter == 'Habis') {
      products = products.where((p) => p.stokTersedia <= 0).toList();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductCard(product: product, idr: idr);
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final dynamic product;
  final NumberFormat idr;

  const _ProductCard({required this.product, required this.idr});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showProductDetail(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.namaBarang,
                            style: AppTextStyles.labelLarge,
                          ),
                        ),
                        if (product.orderType == '4P')
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '4P',
                              style: AppTextStyles.labelMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${idr.format(product.harga)} / ${product.satuan ?? 'pcs'}',
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StockChip(available: product.stokTersedia),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: product.stokTersedia > 0
                    ? () {
                        context.read<DraftOrderProvider>().addItem(product);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.namaBarang} ditambahkan'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    : null,
                icon: Icon(
                  Icons.add_circle,
                  color: product.stokTersedia > 0
                      ? AppColors.primaryLight
                      : AppColors.textMuted,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductDetail(BuildContext context) {
    final idr = NumberFormat('#,###', 'id');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.namaBarang,
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 8),
            if (product.kategori != null)
              Text(
                'Kategori: ${product.kategori}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            if (product.namaSupplier != null)
              Text(
                'Supplier: ${product.namaSupplier}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                _InfoTile(
                  label: 'Harga',
                  value: 'Rp ${idr.format(product.harga)}',
                ),
                const SizedBox(width: 16),
                _InfoTile(
                  label: 'Satuan',
                  value: product.satuan ?? '-',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoTile(
                  label: 'Stok Sistem',
                  value: '${product.stokSistem}',
                ),
                const SizedBox(width: 16),
                _InfoTile(
                  label: 'Stok Booking',
                  value: '${product.stokBooking}',
                ),
                const SizedBox(width: 16),
                _InfoTile(
                  label: 'Stok Tersedia',
                  value: '${product.stokTersedia}',
                  highlight: true,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: product.stokTersedia > 0
                    ? () {
                        context.read<DraftOrderProvider>().addItem(product);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.namaBarang} ditambahkan'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Tambah ke Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoTile({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: highlight ? AppColors.infoBg : AppColors.borderLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: highlight ? AppColors.primaryLight : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
