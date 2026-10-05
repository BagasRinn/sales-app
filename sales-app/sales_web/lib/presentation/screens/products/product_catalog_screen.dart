import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Katalog Produk'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Search
          Container(
            color: Colors.white,
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
            color: Colors.white,
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
                      selectedColor: const Color(0xFFEFF6FF),
                      checkmarkColor: const Color(0xFF2563EB),
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
                    ? const Center(
                        child: Text(
                          'Produk tidak ditemukan',
                          style: TextStyle(color: Color(0xFF94A3B8)),
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
    final stock = product.stokTersedia;
    final stockStatus = stock > 5
        ? 'available'
        : stock > 0
            ? 'low'
            : 'outOfStock';
    final stockColor = stockStatus == 'available'
        ? const Color(0xFF059669)
        : stockStatus == 'low'
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);
    final stockBg = stockStatus == 'available'
        ? const Color(0xFFECFDF5)
        : stockStatus == 'low'
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFFEF2F2);
    final stockLabel = stockStatus == 'available'
        ? 'Tersedia'
        : stockStatus == 'low'
            ? 'Stok Rendah'
            : 'Stok Habis';

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
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
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
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFFCD34D),
                              ),
                            ),
                            child: const Text(
                              '4P',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${idr.format(product.harga)} / ${product.satuan ?? 'pcs'}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: stockBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$stockLabel ($stock)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: stockColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: stock > 0
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
                  color: stock > 0
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF94A3B8),
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
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (product.kategori != null)
              Text(
                'Kategori: ${product.kategori}',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            if (product.namaSupplier != null)
              Text(
                'Supplier: ${product.namaSupplier}',
                style: const TextStyle(color: Color(0xFF64748B)),
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
          color: highlight ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: highlight ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
