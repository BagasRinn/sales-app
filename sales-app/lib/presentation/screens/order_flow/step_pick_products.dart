import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system.dart';
import '../../../data/models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/draft_order_provider.dart';

class StepPickProducts extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const StepPickProducts({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<StepPickProducts> createState() => _StepPickProductsState();
}

class _StepPickProductsState extends State<StepPickProducts> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts().then((_) {
        if (!mounted) return;
        final products = context.read<ProductProvider>().products;
        final cache = {for (final p in products) p.id: p.harga};
        context.read<DraftOrderProvider>().setPricingCache(cache);
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filtered(List<Product> products) {
    if (_search.isEmpty) return products;
    final q = _search.toLowerCase();
    return products.where((p) {
      return p.namaBarang.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<DraftOrderProvider>();
    final productProvider = context.watch<ProductProvider>();
    final products = _filtered(productProvider.products);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Customer header with "Ganti" button
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.store, size: 18, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  draft.customerName ?? '-',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onBack,
                child: const Text('Ganti'),
              ),
            ],
          ),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari produk...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.cardSurface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),

        // Product list
        Expanded(
          child: productProvider.isLoading && products.isEmpty
              ? ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: 8,
                  itemBuilder: (context, index) => const _ProductSkeletonRow(),
                )
              : products.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Produk tidak ditemukan',
                            style: AppTextStyles.bodyMedium),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        return _ProductRow(product: products[i]);
                      },
                    ),
        ),

        // Sticky bottom bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${draft.totalItems} item',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ).format(draft.totalPrice),
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: draft.hasItems ? widget.onNext : null,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Lanjut'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 44),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  const _ProductRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<DraftOrderProvider>();
    final qty = draft.items[product.id] ?? 0;
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 20, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.namaBarang,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${currency.format(product.harga)} · Stok: ${product.stokTersedia}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _QtyStepper(productId: product.id, qty: qty, available: product.stokTersedia),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final String productId;
  final int qty;
  final int available;
  const _QtyStepper({
    required this.productId,
    required this.qty,
    required this.available,
  });

  @override
  Widget build(BuildContext context) {
    final canIncrement = available > 0 && qty < available;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove,
          onTap: qty > 0
              ? () => context
                  .read<DraftOrderProvider>()
                  .setQty(productId, qty - 1)
              : null,
        ),
        SizedBox(
          width: 32,
          child: Center(
            child: Text(
              '$qty',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: qty > 0 ? AppColors.primaryLight : AppColors.textMuted,
              ),
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add,
          onTap: canIncrement
              ? () => context
                  .read<DraftOrderProvider>()
                  .setQty(productId, qty + 1)
              : null,
          primary: true,
          disabled: !canIncrement,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool disabled;
  const _StepperButton({
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = primary ? AppColors.primaryLight : AppColors.border;
    final isInactive = onTap == null || disabled;
    return Material(
      color: primary
          ? (isInactive ? color.withValues(alpha: 0.4) : color)
          : AppColors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: primary
            ? BorderSide.none
            : BorderSide(color: isInactive ? color.withValues(alpha: 0.4) : color),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 14,
            color: primary
                ? Colors.white
                : (isInactive ? AppColors.textMuted : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _ProductSkeletonRow extends StatefulWidget {
  const _ProductSkeletonRow();

  @override
  State<_ProductSkeletonRow> createState() => _ProductSkeletonRowState();
}

class _ProductSkeletonRowState extends State<_ProductSkeletonRow>
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
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: _animation.value),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: _animation.value),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 120,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: _animation.value * 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 80,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: _animation.value),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
