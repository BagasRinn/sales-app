import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../providers/admin_provider.dart';
import '../../data/models/product.dart';

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  String _searchQuery = '';
  bool _initialized = false;
  final _searchController = TextEditingController();
  List<String> _kategoriList = [];

  static const _statusOptions = [
    {'value': 'tersedia', 'label': 'Tersedia'},
    {'value': 'rendah', 'label': 'Stok Rendah'},
    {'value': 'habis', 'label': 'Stok Habis'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<AdminProvider>();
      if (!_initialized && provider.products.isEmpty) {
        _initialized = true;
        provider.loadProducts();
      }
      try {
        final kategori = await provider.getKategoriList();
        if (mounted) setState(() => _kategoriList = kategori);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = context.select<AdminProvider, List<Product>>(
      (p) => p.products,
    );
    final isLoading = context.select<AdminProvider, bool>(
      (p) => p.isLoading,
    );
    final productTotal = context.select<AdminProvider, int>(
      (p) => p.productTotal,
    );
    final selectedKategori = context.select<AdminProvider, String?>(
      (p) => p.selectedKategori,
    );
    final selectedStatus = context.select<AdminProvider, String?>(
      (p) => p.selectedStatus,
    );
    final provider = context.read<AdminProvider>();

    return Column(
      children: [
        // Search bar + filters
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
                        hintText: 'Cari produk...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                  provider.clearSearch();
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (v) {
                        setState(() => _searchQuery = v);
                        provider.searchProducts(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedKategori,
                      decoration: InputDecoration(
                        hintText: 'Kategori',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Semua Kategori')),
                        ..._kategoriList.map((k) => DropdownMenuItem(
                              value: k,
                              child:
                                  Text(k, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (v) => provider.setKategoriFilter(v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: InputDecoration(
                        hintText: 'Status',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Semua Status')),
                        ..._statusOptions.map((s) => DropdownMenuItem(
                              value: s['value'],
                              child: Text(s['label']!),
                            )),
                      ],
                      onChanged: (v) => provider.setStatusFilter(v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '$productTotal produk',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
              if (selectedKategori != null || selectedStatus != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    if (selectedKategori != null)
                      _FilterChip(
                        label: selectedKategori,
                        onClear: () => provider.setKategoriFilter(null),
                      ),
                    if (selectedStatus != null)
                      _FilterChip(
                        label: _statusOptions.firstWhere(
                            (s) => s['value'] == selectedStatus)['label']!,
                        onClear: () => provider.setStatusFilter(null),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // Table — ListView scrolls vertically, each row scrolls horizontally
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 48,
                              color: AppColors.textMuted.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Produk tidak ditemukan'
                                : 'Tidak ada produk',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : _buildTable(products),
        ),
        // Pagination
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
                onPressed: () => provider.prevProductPage(),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Halaman sebelumnya',
              ),
              const SizedBox(width: 8),
              Text(
                'Halaman ${context.select<AdminProvider, int>((p) => p.productPage) + 1} '
                'dari ${context.select<AdminProvider, int>((p) => p.productTotalPages)}',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => provider.nextProductPage(),
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Halaman berikutnya',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<Product> products) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availW = constraints.maxWidth;
        // Kolom: SKU | Nama | Kategori | Stok Sistem | Stok Booking | Stok Tersedia | Satuan | Aksi
        // fixedW = [sku, ktgr, stok, stok, stok, sat, aksi] (nama ambil sisa)
        const fixedW = [100.0, 140.0, 100.0, 100.0, 110.0, 70.0, 110.0];
        const fixedTotal = 730.0;
        final namaW = (availW - fixedTotal).clamp(150.0, 400.0);
        final totalW = namaW + fixedTotal;
        // Urutan col: [sku, nama, ktgr, stok, stok, stok, sat, aksi]
        final colW = <double>[fixedW[0], namaW, fixedW[1], fixedW[2], fixedW[3], fixedW[4], fixedW[5], fixedW[6]];

        // Horizontal scroll on outer so the wide table can scroll left-right.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalW,
            child: Column(
              children: [
                // Header (fixed height)
                _TableHeader(colW, totalW),
                const Divider(height: 1),
                // Data rows — ListView with separator
                Expanded(
                  child: ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (ctx, idx) => const Divider(height: 1),
                    itemBuilder: (ctx, i) => _DataRow(products[i], colW, totalW,
                      onShowStock: (p) => _showStockDialog(context, p),
                      onConfirmDelete: (p) => _confirmDelete(context, p),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showStockDialog(BuildContext context, Product product) async {
    final controller =
        TextEditingController(text: product.stokSistem.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit, color: AppColors.info),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ubah Stok Sistem',
                            style: AppTextStyles.headlineSmall),
                        Text('Manual override stok produk',
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.namaBarang, style: AppTextStyles.labelLarge),
                    const SizedBox(height: 4),
                    Text('SKU: ${product.id}', style: AppTextStyles.mono),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stok Sistem Baru',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _infoPill(
                        'Booking', '${product.stokBooking}', AppColors.info),
                    const SizedBox(width: 8),
                    _infoPill('Tersedia (lama)',
                        '${product.stokTersedia}', AppColors.warning),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final value = int.tryParse(controller.text);
                        if (value == null || value < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Masukkan angka yang valid')),
                          );
                          return;
                        }
                        Navigator.pop(ctx, value);
                      },
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && context.mounted) {
      final success = await context
          .read<AdminProvider>()
          .overrideStock(product.id, result);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('Stok ${product.id} diubah ke $result'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Produk'),
        content: Text(
          'Yakin ingin menghapus "${product.namaBarang}" (${product.id})?\n\nTindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success =
        await context.read<AdminProvider>().deleteProduct(product.id);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Produk "${product.namaBarang}" berhasil dihapus'),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AdminProvider>().errorMessage ??
              'Gagal menghapus produk'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _infoPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(label, style: AppTextStyles.bodySmall),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final List<double> colW;
  final double totalW;
  const _TableHeader(this.colW, this.totalW);

  @override
  Widget build(BuildContext context) {
    // Urutan: SKU | Nama | Kategori | Stok Sistem | Stok Booking | Stok Tersedia | Satuan | Aksi
    const labels = ['SKU', 'Nama', 'Kategori', 'Stok Sistem', 'Stok Booking', 'Stok Tersedia', 'Satuan', 'Aksi'];
    return SizedBox(
      width: totalW,
      child: Container(
        height: 48,
        color: AppColors.surface,
        child: Row(
          children: [
            for (int i = 0; i < labels.length; i++)
              SizedBox(
                width: colW[i],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Text(
                      labels[i],
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final Product product;
  final List<double> colW;
  final double totalW;
  final void Function(Product) onShowStock;
  final void Function(Product) onConfirmDelete;

  const _DataRow(this.product, this.colW, this.totalW,
      {required this.onShowStock, required this.onConfirmDelete});

  @override
  Widget build(BuildContext context) {
    final statusColor = stockStatusColor(stockStatusFromValue(product.stokTersedia));
    return SizedBox(
      width: totalW,
      height: 60,
      child: Row(
        children: [
          // SKU — colW[0]
          SizedBox(
            width: colW[0],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(product.id, style: AppTextStyles.mono.copyWith(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ),
          // Nama — colW[1], wrap text
          SizedBox(
            width: colW[1],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(product.namaBarang, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600), maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
          ),
          // Kategori — colW[2], wrap text
          SizedBox(
            width: colW[2],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(product.kategori ?? '-', maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
          ),
          // Stok Sistem — colW[3], center
          SizedBox(
            width: colW[3],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text('${product.stokSistem}', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: product.stokSistem < product.stokBooking ? AppColors.error : null), maxLines: 2),
            ),
          ),
          // Stok Booking — colW[4], center
          SizedBox(
            width: colW[4],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text('${product.stokBooking}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13), maxLines: 2),
            ),
          ),
          // Stok Tersedia — colW[5], center
          SizedBox(
            width: colW[5],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text('${product.stokTersedia}', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: statusColor, fontWeight: FontWeight.w600), maxLines: 2),
            ),
          ),
          // Satuan — colW[6], center
          SizedBox(
            width: colW[6],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(product.satuan ?? '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13), maxLines: 2),
            ),
          ),
          // Aksi — colW[7]
          SizedBox(
            width: colW[7],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => onShowStock(product),
                    child: const Text('Ubah'),
                  ),
                  IconButton(
                    onPressed: () => onConfirmDelete(product),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppColors.error,
                    tooltip: 'Hapus',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;
  const _FilterChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

Color stockStatusColor(String status) {
  switch (status) {
    case 'habis':
      return AppColors.error;
    case 'rendah':
      return AppColors.warning;
    default:
      return AppColors.success;
  }
}

String stockStatusFromValue(int stokTersedia) {
  if (stokTersedia <= 0) return 'habis';
  if (stokTersedia <= 5) return 'rendah';
  return 'tersedia';
}
