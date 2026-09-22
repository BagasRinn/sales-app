import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/design_system.dart';
import '../../../data/models/cart_item.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'Rp ', decimalDigits: 0);

    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.border.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      size: 48,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Keranjang kosong',
                    style: AppTextStyles.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tambahkan produk dari katalog untuk memulai pesanan',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            // Cart items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: cart.items.length,
                itemBuilder: (context, index) {
                  final item = cart.items[index];
                  return _CartItemCard(
                    item: item,
                    currencyFormat: currencyFormat,
                  );
                },
              ),
            ),
            // Checkout footer
            Consumer<OrderProvider>(
              builder: (context, orderProvider, _) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        // Summary
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Pesanan', style: AppTextStyles.bodySmall),
                                const SizedBox(height: 2),
                                Text(
                                  currencyFormat.format(cart.totalHarga),
                                  style: AppTextStyles.headlineLarge.copyWith(
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.infoBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${cart.totalItems} item',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Error message
                        if (orderProvider.errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.errorBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.errorBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    orderProvider.errorMessage!,
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Checkout button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed:
                                orderProvider.isSubmitting ? null : () => _handleCheckout(context, cart),
                            icon: orderProvider.isSubmitting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send),
                            label: Text(
                                orderProvider.isSubmitting ? 'Mengirim...' : 'Pesan Sekarang'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCheckout(BuildContext context, CartProvider cart) async {
    final storeNameController = TextEditingController();
    final storeContactController = TextEditingController();
    final storeAddressController = TextEditingController();
    bool nameFilled = storeNameController.text.trim().isNotEmpty;

    storeNameController.addListener(() {
      nameFilled = storeNameController.text.trim().isNotEmpty;
    });

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.store, color: AppColors.info),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Info Toko', style: AppTextStyles.headlineSmall),
                          Text('Lengkapi informasi untuk pesanan ini',
                              style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: storeNameController,
                  onChanged: (_) => setDialogState(() {}),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nama Toko *',
                    prefixIcon: Icon(Icons.store),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: storeContactController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'No. HP / WhatsApp',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: storeAddressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Toko',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Pesanan', style: AppTextStyles.bodySmall),
                          Text(
                            NumberFormat.currency(symbol: 'Rp ', decimalDigits: 0)
                                .format(cart.totalHarga),
                            style: AppTextStyles.headlineSmall.copyWith(
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${cart.totalItems} item',
                        style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
                      flex: 2,
                      child: FilledButton(
                        onPressed: !nameFilled
                            ? null
                            : () => Navigator.pop(ctx, true),
                        child: const Text('Pesan Sekarang'),
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
    );

    if (confirmed != true || !context.mounted) return;

    final orderProvider = context.read<OrderProvider>();
    final success = await orderProvider.checkout(
      cart.toOrderItems(),
      storeName: storeNameController.text.trim(),
      storeContact: storeContactController.text.trim(),
      storeAddress: storeAddressController.text.trim(),
    );

    if (success && context.mounted) {
      cart.clear();
      await context.read<ProductProvider>().loadProducts();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Text('Pesanan berhasil dibuat!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final NumberFormat currencyFormat;

  const _CartItemCard({required this.item, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    final status = stockStatusFromValue(item.stokTersedia);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.namaBarang,
                    style: AppTextStyles.labelLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormat.format(item.harga),
                    style: AppTextStyles.bodyMedium,
                  ),
                  if (item.satuan != null)
                    Text(
                      'Satuan: ${item.satuan}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Subtotal: ${currencyFormat.format(item.subtotal)}',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Controls
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: status == StockStatus.outOfStock
                        ? AppColors.errorBg
                        : AppColors.infoBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: status == StockStatus.outOfStock
                          ? AppColors.errorBorder
                          : AppColors.infoBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: () =>
                            context.read<CartProvider>().decrementQty(item.productId),
                        color: AppColors.primaryLight,
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        padding: EdgeInsets.zero,
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 32),
                        alignment: Alignment.center,
                        child: Text(
                          '${item.qty}',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.primaryLight,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: item.qty < item.stokTersedia
                            ? () => context
                                .read<CartProvider>()
                                .incrementQty(item.productId, item.stokTersedia)
                            : null,
                        color: AppColors.primaryLight,
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.error,
                  onPressed: () =>
                      context.read<CartProvider>().removeProduct(item.productId),
                  tooltip: 'Hapus',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
