import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/design_system.dart';
import '../providers/admin_provider.dart';
import '../../data/models/product.dart';

String _fmt(int amount) =>
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final products = provider.products;
    final isLoading = provider.isLoading;

    final filtered = products.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.namaBarang.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.id.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari produk...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${filtered.length} produk',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Table
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
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
                  : _buildDataTable(context, filtered),
        ),
      ],
    );
  }

  Widget _buildDataTable(BuildContext context, List<Product> products) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 24,
          horizontalMargin: 20,
          headingRowHeight: 48,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 56,
          columns: const [
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Nama Barang')),
            DataColumn(label: Text('Harga')),
            DataColumn(label: Text('Stok Sistem')),
            DataColumn(label: Text('Stok Booking')),
            DataColumn(label: Text('Tersedia')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Aksi')),
          ],
          rows: products.map((p) {
            final needsReview = p.stokSistem < p.stokBooking;
            final status = stockStatusFromValue(p.stokTersedia);
            return DataRow(
              cells: [
                DataCell(Text(p.id, style: AppTextStyles.mono)),
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Text(
                      p.namaBarang,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
                DataCell(Text(_fmt(p.harga))),
                DataCell(
                  Text(
                    p.stokSistem.toString(),
                    style: AppTextStyles.labelLarge.copyWith(
                      color: needsReview ? AppColors.error : null,
                    ),
                  ),
                ),
                DataCell(Text(p.stokBooking.toString())),
                DataCell(
                  Text(
                    p.stokTersedia.toString(),
                    style: AppTextStyles.labelLarge.copyWith(
                      color: statusColor(status),
                    ),
                  ),
                ),
                DataCell(StockChip(available: p.stokTersedia)),
                DataCell(
                  SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: () => _showStockDialog(context, p),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Ubah'),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        textStyle: AppTextStyles.labelMedium,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
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
                        Text('Ubah Stok Sistem', style: AppTextStyles.headlineSmall),
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
