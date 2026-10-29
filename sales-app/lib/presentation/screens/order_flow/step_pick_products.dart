import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _lastLoadedType;
  final Map<String, TextEditingController> _qtyControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final draft = context.read<DraftOrderProvider>();
      final productProvider = context.read<ProductProvider>();

      _lastLoadedType = draft.orderType;

      // Load daftar supplier 4P (di-cache, hanya 1× per app session)
      await productProvider.loadSuppliers4p();

      if (!mounted) return;
      await productProvider.loadProducts(orderType: draft.orderType);

      if (!mounted) return;
      final products = productProvider.products;
      final cache = {for (final p in products) p.id: p.harga};
      context.read<DraftOrderProvider>().setPricingCache(cache);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Product> _filtered(List<Product> products) {
    if (_search.isEmpty) return products;
    final q = _search.toLowerCase();
    return products.where((p) {
      return p.namaBarang.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q) ||
          (p.namaSupplier?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  TextEditingController _getQtyController(String productId, int currentQty) {
    if (!_qtyControllers.containsKey(productId)) {
      _qtyControllers[productId] = TextEditingController(
        text: currentQty > 0 ? '$currentQty' : '',
      );
    } else {
      final c = _qtyControllers[productId]!;
      if (c.text.isEmpty && currentQty > 0) {
        c.text = '$currentQty';
      } else if (currentQty == 0 && c.text.isNotEmpty) {
        c.text = '';
      }
    }
    return _qtyControllers[productId]!;
  }

  void _onQtyChanged(String productId, String value, Product product) {
    final qty = int.tryParse(value) ?? 0;
    final draft = context.read<DraftOrderProvider>();
    final existing = draft.linesForProduct(productId);

    if (qty <= 0) {
      if (existing.isNotEmpty) {
        for (final line in existing) {
          draft.removeLine(line.id);
        }
      }
    } else {
      if (existing.isNotEmpty) {
        draft.setLineQty(existing.first.id, qty);
      } else {
        draft.addLine(productId, qty: qty);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<DraftOrderProvider>();
    final productProvider = context.watch<ProductProvider>();
    final products = _filtered(productProvider.products);

    // Kalau orderType berubah (user back ke step 2 & ganti tipe), re-fetch produk.
    if (_lastLoadedType != null && _lastLoadedType != draft.orderType) {
      _lastLoadedType = draft.orderType;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context
            .read<ProductProvider>()
            .loadProducts(orderType: draft.orderType);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tipe Order banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Icon(
                draft.orderType == '4P'
                    ? Icons.star_rounded
                    : Icons.store_rounded,
                size: 16,
                color: draft.orderType == '4P'
                    ? AppColors.warning
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Tipe: ${draft.orderType}',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
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
              hintText: 'Cari kode, nama, atau supplier...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.cardSurface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (v) {
              setState(() => _search = v);
              context.read<ProductProvider>().search(v);
            },
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
                        final product = products[i];
                        final qty = draft.totalQtyForProduct(product.id);
                        return _ProductRow(
                          product: product,
                          qty: qty,
                          qtyController: _getQtyController(product.id, qty),
                          onQtyChanged: (v) => _onQtyChanged(product.id, v, product),
                        );
                      },
                    ),
        ),

        // Sticky bottom bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
  final int qty;
  final TextEditingController qtyController;
  final ValueChanged<String> onQtyChanged;
  const _ProductRow({
    required this.product,
    required this.qty,
    required this.qtyController,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final supplier = product.namaSupplier;
    final is4pSupplier = supplier != null &&
        supplier.isNotEmpty &&
        productProvider.suppliers4p.any(
          (s) => s.toLowerCase() == supplier.toLowerCase(),
        );

    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.namaBarang,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (is4pSupplier) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.success),
                            ),
                            child: Text(
                              '4P',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ],
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
              _QtyStepper(
                controller: qtyController,
                currentQty: qty,
                available: product.stokTersedia,
                onChanged: onQtyChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 28,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        product.namaBarang,
                        style: AppTextStyles.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _detailRow('Kode Item', product.id),
                if (product.satuan != null && product.satuan!.isNotEmpty)
                  _detailRow('Satuan', product.satuan!),
                if (product.kategori != null && product.kategori!.isNotEmpty)
                  _detailRow('Kategori', product.kategori!),
                if (product.namaSupplier != null && product.namaSupplier!.isNotEmpty)
                  _detailRow('Supplier', product.namaSupplier!),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Harga', style: AppTextStyles.bodySmall),
                          const SizedBox(height: 4),
                          Text(
                            currency.format(product.harga),
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
                        Text(
                          '${product.stokTersedia}',
                          style: AppTextStyles.headlineMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: product.stokTersedia == 0
                                ? AppColors.error
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quantity Stepper (Stateless - controller managed by parent) ────────────────

class _QtyStepper extends StatelessWidget {
  final TextEditingController controller;
  final int currentQty;
  final int available;
  final ValueChanged<String> onChanged;

  const _QtyStepper({
    required this.controller,
    required this.currentQty,
    required this.available,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final qty = int.tryParse(controller.text) ?? currentQty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minus
        _StepperButton(
          icon: Icons.remove,
          onTap: qty > 0
              ? () {
                  final newQty = qty - 1;
                  controller.text = '$newQty';
                  onChanged('$newQty');
                }
              : null,
        ),
        // Qty input
        SizedBox(
          width: 52,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: qty > 0 ? AppColors.primaryLight : AppColors.textMuted,
              fontSize: 15,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              border: InputBorder.none,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onChanged,
          ),
        ),
        // Plus
        _StepperButton(
          icon: Icons.add,
          onTap: available > 0 && qty < available
              ? () {
                  final newQty = qty + 1;
                  controller.text = '$newQty';
                  onChanged('$newQty');
                }
              : null,
          primary: true,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = primary ? AppColors.primaryLight : AppColors.border;
    final isInactive = onTap == null;
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
                ? AppColors.textOnPrimary
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
