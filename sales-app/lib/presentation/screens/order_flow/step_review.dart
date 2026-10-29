import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system.dart';
import '../../../core/design_system/widgets/app_components.dart';
import '../../../data/models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/draft_order_provider.dart';

class StepReview extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;
  const StepReview({
    super.key,
    required this.onBack,
    required this.onSaveDraft,
    required this.onSubmit,
  });

  @override
  State<StepReview> createState() => _StepReviewState();
}

class _StepReviewState extends State<StepReview> {
  late TextEditingController _notesController;
  final Map<String, Product> _fetchedProducts = {};

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(
      text: context.read<DraftOrderProvider>().notes,
    );
    _ensureProductData();
  }

  Future<void> _ensureProductData() async {
    final draft = context.read<DraftOrderProvider>();
    final productProvider = context.read<ProductProvider>();
    final prices = <String, int>{};

    for (final line in draft.items) {
      if (line.qty <= 0) continue;

      // Coba ambil dari productProvider (daftar aktif)
      final matches = productProvider.products.where(
        (p) => p.id == line.productId,
      );
      if (matches.isNotEmpty) {
        prices[line.productId] = matches.first.harga;
        continue;
      }

      // Tidak ada di daftar aktif, fetch dari backend
      final p = await productProvider.fetchProductById(line.productId);
      if (p != null && mounted) {
        setState(() => _fetchedProducts[p.id] = p);
        prices[p.id] = p.harga;
      }
    }

    if (prices.isNotEmpty && mounted) {
      context.read<DraftOrderProvider>().setPricingCache(prices);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<DraftOrderProvider>();
    final productProvider = context.watch<ProductProvider>();
    final allProducts = [
      ...productProvider.products,
      ..._fetchedProducts.values,
    ];
    final productMap = {for (final p in allProducts) p.id: p};
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              // Toko section
              _sectionTitle('Toko'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            draft.customerName ?? '-',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (draft.customerAddress != null &&
                              draft.customerAddress!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              draft.customerAddress!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onBack,
                      child: const Text('Ganti'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Produk section
              _sectionTitle('Produk (${draft.totalItems})'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < draft.items.length; i++)
                      if (draft.items[i].qty > 0) ...[
                        _LineRow(
                          line: draft.items[i],
                          product: productMap[draft.items[i].productId],
                        ),
                        if (i < draft.items.length - 1)
                          const Divider(height: 1, indent: 14, endIndent: 14),
                      ],
                    const Divider(height: 1, indent: 14, endIndent: 14),
                    InkWell(
                      onTap: widget.onBack,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tambah Produk',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Catatan
              _sectionTitle('Catatan (opsional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Tulis catatan untuk order ini...',
                  filled: true,
                  fillColor: AppColors.cardSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderLight),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                onChanged: (v) =>
                    context.read<DraftOrderProvider>().setNotes(v),
              ),
              const SizedBox(height: 20),

              // Total + Diskon
              _OrderTotalCard(draft: draft, currency: currency),
            ],
          ),
        ),

        // Sticky bottom buttons
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
                  child: OutlinedButton(
                    onPressed: widget.onSaveDraft,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Simpan Draft'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.onSubmit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Kirim Order'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Widget kartu total — hanya menampilkan ringkasan, tanpa input diskon.
/// Diskon diatur per-item di _ProductRow.
class _OrderTotalCard extends StatelessWidget {
  final DraftOrderProvider draft;
  final NumberFormat currency;

  const _OrderTotalCard({required this.draft, required this.currency});

  @override
  Widget build(BuildContext context) {
    final raw = draft.totalRaw;
    final l1 = draft.discountLayer1Total;
    final l2 = draft.discountLayer2Total;
    final l3 = draft.discountLayer3Total;
    final upTotal = draft.totalUpPrice;
    final orderUpPrice = draft.totalOrderUpPrice;
    final orderDiscount = draft.totalOrderDiscount;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Baris: Total item (sebelum diskon)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total (${draft.totalItems} item)',
                      style: AppTextStyles.bodyLarge,
                    ),
                    Text(
                      currency.format(raw),
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),

                // Breakdown per-layer diskon — tampil hanya yang > 0
                if (l1 > 0) ...[
                  const SizedBox(height: 4),
                  _discountRow('Diskon 1', l1),
                ],
                if (l2 > 0) ...[
                  const SizedBox(height: 4),
                  _discountRow('Diskon 2', l2),
                ],
                if (l3 > 0) ...[
                  const SizedBox(height: 4),
                  _discountRow('Diskon 3', l3),
                ],

                // Up Price — tampil hanya jika > 0
                if (upTotal > 0) ...[
                  const SizedBox(height: 4),
                  _upPriceRow('Up Price', upTotal),
                ],

                // Order-level (global) discount — tampil jika > 0
                if (orderDiscount > 0) ...[
                  const SizedBox(height: 4),
                  _discountRow('Diskon Order', orderDiscount),
                ],

                // Order-level (global) up price — tampil jika > 0
                if (orderUpPrice > 0) ...[
                  const SizedBox(height: 4),
                  _upPriceRow('Up Price Order', orderUpPrice),
                ],

                const Divider(height: 20),

                // Grand total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Grand Total',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      currency.format(draft.totalPrice),
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (draft.freeItemsCount > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Item gratis: ${draft.freeItemsCount}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _discountRow(String label, int amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
        ),
        Text(
          '- ${currency.format(amount)}',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _upPriceRow(String label, int amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
        ),
        Text(
          '+ ${currency.format(amount)}',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class SharedQtyStepper extends StatefulWidget {
  final int qty;
  final int max;
  final ValueChanged<int> onChanged;

  const SharedQtyStepper({
    super.key,
    required this.qty,
    required this.max,
    required this.onChanged,
  });

  @override
  State<SharedQtyStepper> createState() => SharedQtyStepperState();
}

class SharedQtyStepperState extends State<SharedQtyStepper> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.qty}');
  }

  @override
  void didUpdateWidget(SharedQtyStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.qty != widget.qty) {
      _controller.text = '${widget.qty}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String text) {
    final parsed = int.tryParse(text);
    if (parsed != null && parsed >= 1 && parsed <= widget.max) {
      widget.onChanged(parsed);
    }
    setState(() => _isEditing = false);
    if (!_isEditing) {
      _controller.text = '${widget.qty}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepBtn(
          icon: Icons.remove,
          onTap: widget.qty > 1
              ? () => widget.onChanged(widget.qty - 1)
              : () => widget.onChanged(0), // 0 = hapus
          isPrimary: false,
        ),
        SizedBox(
          width: 46,
          child: GestureDetector(
            onTap: () => setState(() {
              _isEditing = true;
              _controller.text = '${widget.qty}';
              _controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _controller.text.length,
              );
            }),
            child: _isEditing
                ? TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                      border: InputBorder.none,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: _commit,
                    onTapOutside: (_) => _commit(_controller.text),
                  )
                : Text(
                    '${widget.qty}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
        ),
        _stepBtn(
          icon: Icons.add,
          onTap: widget.qty < widget.max
              ? () => widget.onChanged(widget.qty + 1)
              : null,
          isPrimary: true,
        ),
      ],
    );
  }

  Widget _stepBtn({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isPrimary,
  }) {
    return Material(
      color: isPrimary
          ? (onTap != null
                ? AppColors.primaryLight
                : AppColors.primaryLight.withValues(alpha: 0.4))
          : AppColors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isPrimary
            ? BorderSide.none
            : BorderSide(
                color: onTap != null
                    ? AppColors.border
                    : AppColors.border.withValues(alpha: 0.4),
              ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 16,
            color: isPrimary
                ? Colors.white
                : (onTap != null ? AppColors.textPrimary : AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

/// ── _LineRow: layout baru 3-baris ──────────────────────────────────────────
class _LineRow extends StatelessWidget {
  final OrderLine line;
  final Product? product;
  const _LineRow({required this.line, required this.product});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final draft = context.watch<DraftOrderProvider>();
    final name = product?.namaBarang ?? line.productId;
    final price = product?.harga ?? draft.getPrice(line.productId);
    final rawSubtotal = price * line.qty;
    final disc = line.discount;
    final up = line.upPrice;
    final isFree = line.isFree;
    final available = product?.stokTersedia ?? 0;

    // Up Price applied first (per-piece × qty ditambahkan ke base)
    final upPerPiece = up?.perPiece(price) ?? 0;
    final upTotal = upPerPiece * line.qty;
    final base = rawSubtotal + upTotal;

    // Chain discount calculation
    int running = base;
    int d1 = 0, d2 = 0, d3 = 0;
    if (disc?.layer1 != null) {
      d1 = disc!.layer1!.cutFrom(running);
      running -= d1;
    }
    if (disc?.layer2 != null) {
      d2 = disc!.layer2!.cutFrom(running);
      running -= d2;
    }
    if (disc?.layer3 != null) {
      d3 = disc!.layer3!.cutFrom(running);
      running -= d3;
    }
    final subtotal = running;
    final totalCut = d1 + d2 + d3;

    return Opacity(
      opacity: isFree ? 0.6 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: nama + harga ────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isFree) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.success.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'GRATIS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (product?.id != null)
                        Text(
                          product!.id,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.format(subtotal),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: totalCut > 0
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (totalCut > 0)
                      Text(
                        currency.format(rawSubtotal),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Row 2: qty meta + stepper + aksi ──────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kiri: qty + diskon summary
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '× ${line.qty} · ${currency.format(price)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (disc != null && !disc.isEmpty) ...[
                        const SizedBox(height: 2),
                        _activeLayersSummary(disc, currency,
                            d1: d1, d2: d2, d3: d3),
                      ],
                      if (up != null && !up.isEmpty) ...[
                        const SizedBox(height: 2),
                        _upPriceChip(up, price, currency, upTotal: upTotal),
                      ],
                    ],
                  ),
                ),
                if (!isFree) ...[
                  SharedQtyStepper(
                    qty: line.qty,
                    max: available,
                    onChanged: (newQty) {
                      if (newQty == 0) {
                        draft.removeLine(line.id);
                      } else {
                        draft.setLineQty(line.id, newQty);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  _actionIconBtn(
                    icon: Icons.discount_outlined,
                    color: disc != null && !disc.isEmpty
                        ? AppColors.success
                        : AppColors.textSecondary,
                    onTap: () =>
                        _showDiscountSheet(context, line, product, currency),
                  ),
                  const SizedBox(width: 2),
                  _actionIconBtn(
                    icon: Icons.trending_up,
                    color: up != null && !up.isEmpty
                        ? AppColors.warning
                        : AppColors.textSecondary,
                    onTap: () =>
                        _showUpPriceSheet(context, line, product, price, currency),
                  ),
                  const SizedBox(width: 2),
                ],
                // Menu "Hapus" selalu visible, juga untuk barang gratis
                _PopupMenuBtn(
                  items: [
                    if (!isFree)
                      _PopupItem(
                        label: 'Barang Gratis',
                        icon: Icons.card_giftcard,
                        color: AppColors.success,
                        onTap: () => _showPromoGratisDialog(
                          context,
                          product?.namaBarang ?? line.productId,
                          draft,
                        ),
                      ),
                    _PopupItem(
                      label: 'Hapus',
                      icon: Icons.delete_outline,
                      color: AppColors.error,
                      onTap: () => draft.removeLine(line.id),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionIconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: color == AppColors.success ? color : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _activeLayersSummary(ItemDiscount disc, NumberFormat currency,
      {int d1 = 0, int d2 = 0, int d3 = 0}) {
    final parts = <String>[];
    for (final entry in [
      (1, disc.layer1, d1),
      (2, disc.layer2, d2),
      (3, disc.layer3, d3),
    ]) {
      final l = entry.$2;
      if (l == null) continue;
      final cut = entry.$3;
      if (cut <= 0) continue;
      final label = entry.$1 == 1
          ? 'Diskon 1'
          : entry.$1 == 2
              ? 'Diskon 2'
              : 'Diskon 3';
      if (l.type.toUpperCase() == 'PERCENT') {
        parts.add('$label: ${l.value}%');
      } else {
        parts.add('$label: -${currency.format(cut)}');
      }
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.success,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _upPriceChip(ItemUpPrice up, int hargaSatuan, NumberFormat currency,
      {int upTotal = 0}) {
    if (upTotal <= 0) return const SizedBox.shrink();
    return Text(
      'Up Price: +${currency.format(upTotal)}',
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.warning,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  void _showDiscountSheet(
    BuildContext context,
    OrderLine line,
    Product? product,
    NumberFormat currency,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _DiscountSheet(line: line, product: product, currency: currency),
    );
  }

  void _showUpPriceSheet(
    BuildContext context,
    OrderLine line,
    Product? product,
    int hargaSatuan,
    NumberFormat currency,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UpPriceSheet(
        line: line,
        product: product,
        hargaSatuan: hargaSatuan,
        currency: currency,
      ),
    );
  }

  void _showPromoGratisDialog(
    BuildContext context,
    String productName,
    DraftOrderProvider draft,
  ) {
    final qtyController = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Barang Gratis'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Produk: $productName', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'Item duplikat akan mendapat diskon 100% (GRATIS).',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Jumlah gratis (qty)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(qtyController.text) ?? 0;
              if (qty <= 0) return;
              final newLine = draft.addLine(line.productId, qty: qty);
              draft.setDiscountLayer(
                lineId: newLine.id,
                layer: 1,
                type: 'PERCENT',
                value: 100,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }
}

/// ── Bottom sheet diskon 3 layer ────────────────────────────────────────────
class _DiscountSheet extends StatefulWidget {
  final OrderLine line;
  final Product? product;
  final NumberFormat currency;

  const _DiscountSheet({
    required this.line,
    required this.product,
    required this.currency,
  });

  @override
  State<_DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends State<_DiscountSheet> {
  late String _type1, _type2, _type3;
  late TextEditingController _ctrl1, _ctrl2, _ctrl3;
  Product? _product;

  @override
  void initState() {
    super.initState();
    _type1 = widget.line.discount?.layer1?.type ?? 'PERCENT';
    _type2 = widget.line.discount?.layer2?.type ?? 'PERCENT';
    _type3 = widget.line.discount?.layer3?.type ?? 'PERCENT';
    _ctrl1 = TextEditingController(
      text: widget.line.discount?.layer1 != null ? '${widget.line.discount!.layer1!.value}' : '',
    );
    _ctrl2 = TextEditingController(
      text: widget.line.discount?.layer2 != null ? '${widget.line.discount!.layer2!.value}' : '',
    );
    _ctrl3 = TextEditingController(
      text: widget.line.discount?.layer3 != null ? '${widget.line.discount!.layer3!.value}' : '',
    );
    _product = widget.product;
    _fetchProduct();
  }

  Future<void> _fetchProduct() async {
    if (_product != null) return;
    final p = await context.read<ProductProvider>().fetchProductById(widget.line.productId);
    if (p != null && mounted) {
      setState(() => _product = p);
    }
  }

  int get _hargaSatuan =>
      _product?.harga ??
      widget.product?.harga ??
      context.read<DraftOrderProvider>().getPrice(widget.line.productId);

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    _ctrl3.dispose();
    super.dispose();
  }

  String _typeFor(int idx) {
    switch (idx) {
      case 1:
        return _type1;
      case 2:
        return _type2;
      case 3:
        return _type3;
    }
    return 'PERCENT';
  }

  TextEditingController _ctrlFor(int idx) {
    switch (idx) {
      case 1:
        return _ctrl1;
      case 2:
        return _ctrl2;
      case 3:
        return _ctrl3;
    }
    return _ctrl1;
  }

  void _setType(int idx, String t) {
    setState(() {
      switch (idx) {
        case 1:
          _type1 = t;
          break;
        case 2:
          _type2 = t;
          break;
        case 3:
          _type3 = t;
          break;
      }
    });
    _ctrlFor(idx).clear();
  }

  void _onSave() {
    final draft = context.read<DraftOrderProvider>();
    for (var idx = 1; idx <= 3; idx++) {
      final v = double.tryParse(_ctrlFor(idx).text.replaceAll(',', '.')) ?? 0.0;
      draft.setDiscountLayer(
        lineId: widget.line.id,
        layer: idx,
        type: _typeFor(idx),
        value: v,
      );
    }
    Navigator.pop(context);
  }

  void _onApplyToAll() {
    final draft = context.read<DraftOrderProvider>();
    final otherCount = draft.items.where((l) => l.id != widget.line.id).length;
    if (otherCount == 0) return;

    // 1. Simpan dulu ke item ini sendiri (ambil nilai terbaru dari input)
    for (var idx = 1; idx <= 3; idx++) {
      final v = double.tryParse(_ctrlFor(idx).text.replaceAll(',', '.')) ?? 0.0;
      draft.setDiscountLayer(
        lineId: widget.line.id,
        layer: idx,
        type: _typeFor(idx),
        value: v,
      );
    }

    // 2. Baru apply ke semua item LAIN (sudah pakai nilai baru)
    draft.applyDiscountToAll(widget.line.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Diskon diterapkan ke $otherCount item lainnya'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  int _calcPreview(int idx) {
    final v = double.tryParse(_ctrlFor(idx).text.replaceAll(',', '.')) ?? 0.0;
    if (v <= 0) return 0;
    final raw = _hargaSatuan * widget.line.qty;
    if (idx == 1) {
      return _typeFor(idx) == 'PERCENT' ? (raw * v / 100).round() : v.round();
    }
    // Layers 2 & 3 dihitung dari sisa setelah layer sebelumnya
    int running = raw;
    for (var i = 1; i < idx; i++) {
      final prevV =
          double.tryParse(_ctrlFor(i).text.replaceAll(',', '.')) ?? 0.0;
      if (prevV <= 0) continue;
      final cut = _typeFor(i) == 'PERCENT'
          ? (running * prevV / 100).round()
          : prevV.round();
      running -= cut;
    }
    return _typeFor(idx) == 'PERCENT' ? (running * v / 100).round() : v.round();
  }

  int get _subtotal {
    final raw = _hargaSatuan * widget.line.qty;
    int running = raw;
    for (var i = 1; i <= 3; i++) {
      running -= _calcPreview(i);
    }
    return running < 0 ? 0 : running;
  }

  @override
  Widget build(BuildContext context) {
    // Jangan menimpa _product hasil _fetchProduct(): produk dari server-side
    // search belum tentu ada di daftar aktif ProductProvider. Kalau ditimpa
    // dengan null, preview diskon & subtotal akan tampil 0.
    final name = _product?.namaBarang ??
        widget.product?.namaBarang ??
        widget.line.productId;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Diskon',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Text(
              name,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Layer cards
          for (var idx = 1; idx <= 3; idx++)
            _LayerCard(
              idx: idx,
              type: _typeFor(idx),
              controller: _ctrlFor(idx),
              preview: _calcPreview(idx),
              onTypeChanged: (t) => _setType(idx, t),
              onChanged: (_) => setState(() {}),
            ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          // Subtotal
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtotal',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  widget.currency.format(_subtotal),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          // Terapkan ke Semua Item
          Consumer<DraftOrderProvider>(
            builder: (context, draft, _) {
              final otherCount = draft.items
                  .where((l) => l.id != widget.line.id)
                  .length;
              if (otherCount == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _onApplyToAll,
                    icon: const Icon(Icons.done_all, size: 18),
                    label: Text('Terapkan ke Semua Item ($otherCount)'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ),
              );
            },
          ),
          // Tombol simpan
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _onSave,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Simpan'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerCard extends StatelessWidget {
  final int idx;
  final String type;
  final TextEditingController controller;
  final int preview;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onChanged;

  const _LayerCard({
    required this.idx,
    required this.type,
    required this.controller,
    required this.preview,
    required this.onTypeChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = controller.text.isEmpty;
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEmpty ? AppColors.border : (AppColors.border),
          style: isEmpty ? BorderStyle.solid : BorderStyle.solid,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DISKON $idx',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.05,
                ),
              ),
              if (!isEmpty)
                GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: Text(
                    'Hapus',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Type chips
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _chip(
                      '%',
                      type == 'PERCENT',
                      () => onTypeChanged('PERCENT'),
                    ),
                    _chip(
                      'Rp',
                      type == 'NOMINAL',
                      () => onTypeChanged('NOMINAL'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Input
              SizedBox(
                width: 80,
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    prefixText: type == 'NOMINAL' ? 'Rp ' : null,
                    suffixText: type == 'PERCENT' ? '%' : null,
                    hintText: '0',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                  ],
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 8),
              // Preview
              Expanded(
                child: Text(
                  preview > 0 ? '−${currency.format(preview)}' : '',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// ── Popup menu button ──────────────────────────────────────────────────────
class _PopupItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PopupItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _PopupMenuBtn extends StatelessWidget {
  final List<_PopupItem> items;
  const _PopupMenuBtn({required this.items});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.more_vert,
          size: 16,
          color: AppColors.textSecondary,
        ),
        tooltip: 'Menu',
        onSelected: (value) {
          final item = items[int.parse(value)];
          item.onTap();
        },
        itemBuilder: (context) => [
          for (var i = 0; i < items.length; i++)
            if (i > 0)
              PopupMenuItem(
                value: '$i',
                child: Row(
                  children: [
                    Icon(items[i].icon, size: 16, color: items[i].color),
                    const SizedBox(width: 8),
                    Text(
                      items[i].label,
                      style: TextStyle(color: items[i].color),
                    ),
                  ],
                ),
              )
            else
              PopupMenuItem(
                value: '$i',
                child: Row(
                  children: [
                    Icon(items[i].icon, size: 16, color: items[i].color),
                    const SizedBox(width: 8),
                    Text(
                      items[i].label,
                      style: TextStyle(color: items[i].color),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Bottom sheet untuk tambah line diskon/promo manual.
class _AddLineSheet extends StatefulWidget {
  final List<Product> products;
  final Map<String, Product> productMap;
  final void Function(String productId, int qty, ItemDiscount? discount) onAdd;

  const _AddLineSheet({
    required this.products,
    required this.productMap,
    required this.onAdd,
  });

  @override
  State<_AddLineSheet> createState() => _AddLineSheetState();
}

class _AddLineSheetState extends State<_AddLineSheet> {
  String? _selectedProductId;
  int _qty = 1;
  String _layer1Type = 'PERCENT';
  final _layer1Controller = TextEditingController();
  ItemDiscount? _buildDiscount() {
    final v =
        double.tryParse(_layer1Controller.text.replaceAll(',', '.')) ?? 0.0;
    if (v <= 0) return null;
    double capped = v;
    if (_layer1Type == 'PERCENT' && v > 100) capped = 100.0;
    return ItemDiscount(
      layer1: DiscountLayer(type: _layer1Type, value: capped),
    );
  }

  @override
  void dispose() {
    _layer1Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProduct = _selectedProductId != null
        ? widget.productMap[_selectedProductId]
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Tambah Line', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Produk',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            initialValue: _selectedProductId,
            items: widget.products
                .map(
                  (p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(p.namaBarang, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() {
              _selectedProductId = v;
              _qty = 1;
            }),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              const Text('Qty:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                icon: const Icon(Icons.remove),
              ),
              Text(
                '$_qty',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              IconButton(
                onPressed:
                    selectedProduct != null &&
                        _qty < selectedProduct.stokTersedia
                    ? () => setState(() => _qty++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),

          const Text(
            'Diskon Layer 1 (opsional):',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              AppChoiceChip(
                label: '%',
                selected: _layer1Type == 'PERCENT',
                onSelected: () => setState(() => _layer1Type = 'PERCENT'),
              ),
              const SizedBox(width: 4),
              AppChoiceChip(
                label: 'Rp',
                selected: _layer1Type == 'NOMINAL',
                onSelected: () => setState(() => _layer1Type = 'NOMINAL'),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _layer1Controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: _layer1Type == 'PERCENT' ? '0%' : 'Rp 0',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedProductId == null
                  ? null
                  : () {
                      final disc = _buildDiscount();
                      widget.onAdd(_selectedProductId!, _qty, disc);
                      Navigator.pop(context);
                    },
              child: const Text('Tambah Line'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet untuk set Up Price (1 layer, per-piece, type PERCENT atau NOMINAL).
class _UpPriceSheet extends StatefulWidget {
  final OrderLine line;
  final Product? product;
  final int hargaSatuan;
  final NumberFormat currency;

  const _UpPriceSheet({
    required this.line,
    required this.product,
    required this.hargaSatuan,
    required this.currency,
  });

  @override
  State<_UpPriceSheet> createState() => _UpPriceSheetState();
}

class _UpPriceSheetState extends State<_UpPriceSheet> {
  late String _type;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _type = widget.line.upPrice?.type.toUpperCase() ?? 'NOMINAL';
    final initial = _type == 'PERCENT'
        ? (widget.line.upPrice?.percent ?? 0)
        : (widget.line.upPrice?.nominal ?? 0).toDouble();
    _ctrl = TextEditingController(
      text: initial > 0
          ? (initial == initial.roundToDouble()
                ? '${initial.round()}'
                : '$initial')
          : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int get _valueInt {
    final raw = _ctrl.text.replaceAll(',', '.');
    return double.tryParse(raw)?.toInt() ?? 0;
  }

  double get _valueDouble {
    final raw = _ctrl.text.replaceAll(',', '.');
    return double.tryParse(raw) ?? 0.0;
  }

  int get _perPiece {
    if (_type == 'PERCENT') {
      return (widget.hargaSatuan * _valueDouble / 100).round();
    }
    return _valueInt;
  }

  int get _total => _perPiece * widget.line.qty;

  void _onSave() {
    final value = _type == 'PERCENT' ? _valueDouble : _valueInt.toDouble();
    context.read<DraftOrderProvider>().setUpPrice(
      lineId: widget.line.id,
      type: _type,
      value: value,
    );
    Navigator.pop(context);
  }

  void _onApplyToAll() {
    final draft = context.read<DraftOrderProvider>();
    final otherCount = draft.items.where((l) => l.id != widget.line.id).length;
    if (otherCount == 0) return;

    draft.applyUpPriceToAll(widget.line.id);

    final value = _type == 'PERCENT' ? _valueDouble : _valueInt.toDouble();
    context.read<DraftOrderProvider>().setUpPrice(
      lineId: widget.line.id,
      type: _type,
      value: value,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Up Price diterapkan ke $otherCount item lainnya'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.trending_up, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                const Text('Edit Up Price', style: AppTextStyles.headlineSmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Penambah per-piece (×${widget.line.qty}). Ditambahkan ke base sebelum diskon.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            // Type chip selector (% / Rp)
            Row(
              children: [
                _typeChip('Rp', _type == 'NOMINAL'),
                const SizedBox(width: 8),
                _typeChip('%', _type == 'PERCENT'),
              ],
            ),
            const SizedBox(height: 12),
            // Input
            TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              decoration: InputDecoration(
                labelText: _type == 'PERCENT'
                    ? 'Persen (%)'
                    : 'Nominal per-piece (Rp)',
                hintText: _type == 'PERCENT' ? 'Contoh: 10' : 'Contoh: 1000',
                prefixText: _type == 'PERCENT' ? null : 'Rp ',
                border: const OutlineInputBorder(),
                suffixIcon: _ctrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _ctrl.clear()),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            // Live preview
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Per-piece: ${widget.currency.format(_perPiece)}',
                    style: AppTextStyles.bodySmall,
                  ),
                  Text(
                    'Total: + ${widget.currency.format(_total)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Consumer<DraftOrderProvider>(
              builder: (context, draft, _) {
                final otherCount = draft.items
                    .where((l) => l.id != widget.line.id)
                    .length;
                if (otherCount == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _onApplyToAll,
                      icon: const Icon(Icons.done_all, size: 18),
                      label: Text('Terapkan ke Semua Item ($otherCount)'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                );
              },
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.warning,
                    ),
                    child: const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String label, bool selected) {
    return AppChoiceChip(
      label: label,
      selected: selected,
      onSelected: () =>
          setState(() => _type = label == '%' ? 'PERCENT' : 'NOMINAL'),
    );
  }
}
