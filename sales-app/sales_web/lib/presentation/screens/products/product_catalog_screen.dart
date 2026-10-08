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
    final available = product.stokTersedia as int;
    final satuan = product.satuan as String? ?? 'unit';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showProductDetail(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product image placeholder
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
                      'SKU: ${product.productId}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StockChip(available: available),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'STOK $available $satuan',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (product.namaSupplier != null && (product.namaSupplier as String).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.business, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              product.namaSupplier,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Rp ${idr.format(product.harga)}',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryLight,
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
    final available = product.stokTersedia as int;

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
            // Header
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
                      const SizedBox(height: 2),
                      Text(
                        'SKU: ${product.productId}',
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
            // SKU
            _detailRow(Icons.qr_code, 'SKU', product.productId),
            if (product.satuan != null)
              _detailRow(Icons.scale_outlined, 'Satuan', product.satuan),
            if (product.kategori != null)
              _detailRow(Icons.category_outlined, 'Kategori', product.kategori),
            if (product.namaSupplier != null && (product.namaSupplier as String).isNotEmpty)
              _detailRow(Icons.business, 'Supplier', product.namaSupplier),
            const Divider(height: 24),
            // Harga + Stok row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Harga', style: AppTextStyles.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        'Rp ${idr.format(product.harga)}',
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
                        StockChip(available: available),
                        const SizedBox(width: 6),
                        Text(
                          '$available',
                          style: AppTextStyles.headlineMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: available == 0 ? AppColors.error : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: available > 0
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
