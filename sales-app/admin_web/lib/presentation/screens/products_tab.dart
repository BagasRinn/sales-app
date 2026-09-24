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
      // Load kategori list for filter dropdown
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
    // Watch only the specific fields this tab needs — no cross-tab rebuilds
    final products = context.select<AdminProvider, List<Product>>(
      (p) => p.products,
    );
    final isLoading = context.select<AdminProvider, bool>(
      (p) => p.isLoading,
    );
    final productTotal = context.select<AdminProvider, int>(
      (p) => p.productTotal,
    );
    final productPage = context.select<AdminProvider, int>(
      (p) => p.productPage,
    );
    final totalPages = context.select<AdminProvider, int>(
      (p) => p.productTotalPages,
    );
    final hasPrev = context.select<AdminProvider, bool>(
      (p) => p.hasPrevProductPage,
    );
    final hasNext = context.select<AdminProvider, bool>(
      (p) => p.hasNextProductPage,
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
                  // Kategori filter
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
                        const DropdownMenuItem(value: null, child: Text('Semua Kategori')),
                        ..._kategoriList.map((k) => DropdownMenuItem(
                              value: k,
                              child: Text(k, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (v) => provider.setKategoriFilter(v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status filter
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
                        const DropdownMenuItem(value: null, child: Text('Semua Status')),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              // Active filter chips
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
                        label: _statusOptions
                            .firstWhere((s) => s['value'] == selectedStatus)['label']!,
                        onClear: () => provider.setStatusFilter(null),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // Table header
        _TableHeader(),
        const Divider(height: 1),
        // Table body — virtualized
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
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 1110, // sum of all column widths
                        child: ListView.builder(
                          itemCount: products.length,
                          itemBuilder: (ctx, index) =>
                              _ProductRow(product: products[index]),
                        ),
                      ),
                    ),
        ),
        // Pagination controls
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
                onPressed: hasPrev ? () => provider.prevProductPage() : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Halaman sebelumnya',
              ),
              const SizedBox(width: 8),
              Text(
                'Halaman ${productPage + 1} dari $totalPages',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: hasNext ? () => provider.nextProductPage() : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Halaman berikutnya',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1110,
          child: const Row(
            children: [
              _HeaderCell(label: 'SKU', width: 100),
              _HeaderCell(label: 'KATEGORI', width: 130),
              _HeaderCell(label: 'Nama Item', width: 240),
              _HeaderCell(label: 'Stok Sistem', width: 110),
              _HeaderCell(label: 'Satuan', width: 80),
              _HeaderCell(label: 'Stok Booking', width: 110),
              _HeaderCell(label: 'Stok Tersedia', width: 110),
              _HeaderCell(label: 'Status', width: 100),
              _HeaderCell(label: 'Aksi', width: 130),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final double width;
  const _HeaderCell({required this.label, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(child: Text(label, style: AppTextStyles.labelMedium)),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  const _ProductRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final needsReview = product.stokSistem < product.stokBooking;
    final status = stockStatusFromValue(product.stokTersedia);

    return Container(
      height: 60,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          _Cell(
            width: 100,
            child: Text(product.id,
                style: AppTextStyles.mono,
                overflow: TextOverflow.ellipsis),
          ),
          _Cell(
            width: 130,
            child: Text(product.kategori ?? '-',
                style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis),
          ),
          _Cell(
            width: 240,
            child: Text(product.namaBarang,
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 2),
          ),
          _Cell(
            width: 110,
            child: Text('${product.stokSistem}',
                style: AppTextStyles.labelLarge
                    .copyWith(color: needsReview ? AppColors.error : null)),
          ),
          _Cell(
            width: 80,
            child: Text(product.satuan ?? '-', style: AppTextStyles.bodySmall),
          ),
          _Cell(
            width: 110,
            child: Text('${product.stokBooking}',
                style: AppTextStyles.bodySmall),
          ),
          _Cell(
            width: 110,
            child: Text('${product.stokTersedia}',
                style:
                    AppTextStyles.labelLarge.copyWith(color: statusColor(status))),
          ),
          _Cell(width: 100, child: StockChip(available: product.stokTersedia)),
          _Cell(width: 130, child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showStockDialog(context, product),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Ubah'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: AppTextStyles.labelMedium,
                ),
              ),
              IconButton(
                onPressed: () => _confirmDelete(context, product),
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.error,
                tooltip: 'Hapus produk',
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ],
          )),
        ],
      ),
    );
  }

  Future<void> _showStockDialog(BuildContext context, Product product) async {
    final controller =
        TextEditingController(text: product.stokSistem.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      final success =
          await context.read<AdminProvider>().overrideStock(product.id, result);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          content: Text(
              context.read<AdminProvider>().errorMessage ?? 'Gagal menghapus produk'),
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

class _Cell extends StatelessWidget {
  final double width;
  final Widget child;
  const _Cell({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Align(alignment: Alignment.centerLeft, child: child),
    ));
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
