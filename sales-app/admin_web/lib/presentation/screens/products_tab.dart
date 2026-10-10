import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/design_system.dart';
import '../providers/admin_provider.dart';
import '../../data/models/product.dart';

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  String _searchQuery = '';
  bool _initialized = false;
  final _searchController = TextEditingController();
  List<String> _supplierList = [];

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
        final supplier = await provider.getSupplierList();
        if (mounted) setState(() => _supplierList = supplier);
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
    final selectedSupplier = context.select<AdminProvider, String?>(
      (p) => p.selectedSupplier,
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
                      initialValue: selectedSupplier,
                      decoration: InputDecoration(
                        hintText: 'Supplier',
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
                            value: null, child: Text('Semua Supplier')),
                        ..._supplierList.map((s) => DropdownMenuItem(
                              value: s,
                              child:
                                  Text(s, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (v) => provider.setSupplierFilter(v),
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
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh stok',
                    onPressed: () => provider.loadProducts(),
                  ),
                ],
              ),
              if (selectedSupplier != null || selectedStatus != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    if (selectedSupplier != null)
                      _FilterChip(
                        label: selectedSupplier,
                        onClear: () => provider.setSupplierFilter(null),
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
        // Kolom: SKU | Nama | Kategori | Harga | Stok Sistem | Stok Booking | Stok Diterima | Stok Tersedia | Satuan | Supplier | Cabang | Aksi
        // fixedW tanpa aksi = [sku, ktgr, harga, stok, stok, stok, stok, sat, supp, cabang]
        const fixedW = [140.0, 120.0, 100.0, 100.0, 100.0, 100.0, 100.0, 70.0, 200.0, 130.0, 90.0];
        // Total fixed tanpa aksi
        const fixedTotal = 1340.0; // sum of first 10 items
        const aksiWidth = 90.0;
        final namaW = (availW - fixedTotal).clamp(150.0, 450.0);
        // totalW: exclude aksi column if readOnly
        final totalW = widget.readOnly
            ? namaW + fixedTotal
            : namaW + fixedTotal + aksiWidth;
        // Urutan col: [sku, nama, ktgr, harga, stok, stok, stok, stok, sat, supp, cabang, aksi]
        final colW = <double>[
          fixedW[0], // SKU
          namaW, // Nama
          fixedW[1], // Kategori
          fixedW[2], // Harga
          fixedW[3], // Stok Sistem
          fixedW[4], // Stok Booking
          fixedW[5], // Stok Diterima
          fixedW[6], // Stok Tersedia
          fixedW[7], // Satuan
          fixedW[8], // Supplier
          fixedW[9], // Cabang
        ];
        if (!widget.readOnly) colW.add(fixedW[10]); // Aksi

        // Horizontal scroll on outer so the wide table can scroll left-right.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalW,
            child: Column(
              children: [
                // Header (fixed height)
                _TableHeader(colW, totalW, readOnly: widget.readOnly),
                const Divider(height: 1),
                // Data rows — ListView with separator
                Expanded(
                  child: ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (ctx, idx) => const Divider(height: 1),
                    itemBuilder: (ctx, i) => _DataRow(products[i], colW, totalW,
                      onShowStock: (p) => _showStockDialog(context, p),
                      onShowEdit: (p) => _showEditDialog(context, p),
                      onConfirmDelete: (p) => _confirmDelete(context, p),
                      readOnly: widget.readOnly,
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
        child: SizedBox(
          width: 480,
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
                      _infoPill('Diterima',
                          '${product.stokDiterima}', AppColors.info),
                      const SizedBox(width: 8),
                      _infoPill('Tersedia',
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

  Future<void> _showEditDialog(BuildContext context, Product product) async {
    final kategoriCtl = TextEditingController(text: product.kategori ?? '');
    final satuanCtl = TextEditingController(text: product.satuan ?? '');
    final supplierCtl = TextEditingController(text: product.namaSupplier ?? '');
    String orderType = product.orderType;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SizedBox(
            width: 480,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
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
                          child: const Icon(Icons.edit_outlined,
                              color: AppColors.info),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Edit Produk',
                                  style: AppTextStyles.headlineSmall),
                              Text(
                                '${product.namaBarang} (SKU: ${product.id})',
                                style: AppTextStyles.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: kategoriCtl,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: satuanCtl,
                      decoration: const InputDecoration(
                        labelText: 'Satuan',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: supplierCtl,
                      decoration: const InputDecoration(
                        labelText: 'Supplier',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Tipe Order',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('REGULER'),
                            selected: orderType == 'REGULER',
                            onSelected: (sel) {
                              if (sel) setState(() => orderType = 'REGULER');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('4P'),
                            selected: orderType == '4P',
                            onSelected: (sel) {
                              if (sel) setState(() => orderType = '4P');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Simpan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (saved != true || !context.mounted) return;

    try {
      final updated = await context.read<AdminProvider>().adminRepository.updateProduct(
            product.id,
            kategori: kategoriCtl.text.trim().isEmpty
                ? null
                : kategoriCtl.text.trim(),
            satuan:
                satuanCtl.text.trim().isEmpty ? null : satuanCtl.text.trim(),
            namaSupplier: supplierCtl.text.trim().isEmpty
                ? null
                : supplierCtl.text.trim(),
            orderType: orderType,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Produk ${updated.id} diperbarui'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui produk: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
  final bool readOnly;
  const _TableHeader(this.colW, this.totalW, {this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    // Urutan: SKU | Nama | Kategori | Harga | Stok Sistem | Stok Booking | Stok Diterima | Stok Tersedia | Satuan | Supplier | Cabang | Aksi
    final labels = readOnly
        ? ['SKU', 'Nama', 'Kategori', 'Harga', 'Stok Sistem', 'Stok Booking', 'Stok Diterima', 'Stok Tersedia', 'Satuan', 'Supplier', 'Cabang']
        : ['SKU', 'Nama', 'Kategori', 'Harga', 'Stok Sistem', 'Stok Booking', 'Stok Diterima', 'Stok Tersedia', 'Satuan', 'Supplier', 'Cabang', 'Aksi'];
    final colsToRender = readOnly ? colW.length - 1 : colW.length;
    return SizedBox(
      width: totalW,
      child: Container(
        height: 48,
        color: AppColors.surface,
        child: Row(
          children: [
            for (int i = 0; i < colsToRender; i++)
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
  final void Function(Product) onShowEdit;
  final void Function(Product) onConfirmDelete;
  final bool readOnly;

  const _DataRow(this.product, this.colW, this.totalW,
      {required this.onShowStock,
      required this.onShowEdit,
      required this.onConfirmDelete,
      this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    final statusColor = stockStatusColor(stockStatusFromValue(product.stokTersedia));
    final fmtCurrency = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final isReadOnly = readOnly;

    final cells = <Widget>[
      // 0: SKU
      SizedBox(
        width: colW[0],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(product.id, style: AppTextStyles.mono.copyWith(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ),
      ),
      // 1: Nama
      SizedBox(
        width: colW[1],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(product.namaBarang, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600), maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ),
      ),
      // 2: Kategori
      SizedBox(
        width: colW[2],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(product.kategori ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ),
      ),
      // 3: Harga
      SizedBox(
        width: colW[3],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(fmtCurrency.format(product.harga), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
      // 4: Stok Sistem
      SizedBox(
        width: colW[4],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text('${product.stokSistem}', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: product.stokSistem < (product.stokBooking + product.stokDiterima) ? AppColors.error : null), maxLines: 2),
        ),
      ),
      // 5: Stok Booking
      SizedBox(
        width: colW[5],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text('${product.stokBooking}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13), maxLines: 2),
        ),
      ),
      // 6: Stok Diterima
      SizedBox(
        width: colW[6],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text('${product.stokDiterima}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13), maxLines: 2),
        ),
      ),
      // 7: Stok Tersedia
      SizedBox(
        width: colW[7],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text('${product.stokTersedia}', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: statusColor, fontWeight: FontWeight.w600), maxLines: 2),
        ),
      ),
      // 8: Satuan
      SizedBox(
        width: colW[8],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(product.satuan ?? '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13), maxLines: 2),
        ),
      ),
      // 9: Supplier
      SizedBox(
        width: colW[9],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(product.namaSupplier ?? '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
      ),
      // 10: Cabang
      SizedBox(
        width: colW[10],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(product.branchNama ?? product.branch ?? '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11), maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];

    // Aksi column hanya untuk non-readOnly
    if (!isReadOnly) {
      cells.add(
        SizedBox(
          width: colW[11],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => onShowStock(product),
                    child: const Text('Ubah'),
                  ),
                  TextButton(
                    onPressed: () => onShowEdit(product),
                    child: const Text('Edit'),
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
        ),
      );
    }

    return SizedBox(
      width: isReadOnly ? totalW - colW[11] : totalW,
      height: 60,
      child: Row(children: cells),
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
