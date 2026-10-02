import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system.dart';
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

  @override
  void initState() {
    super.initState();
    _notesController =
        TextEditingController(text: context.read<DraftOrderProvider>().notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<DraftOrderProvider>();
    final products = context.watch<ProductProvider>().products;
    final productMap = {for (final p in products) p.id: p};
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
                    for (final line in draft.items)
                      if (line.qty > 0)
                        _LineRow(
                          line: line,
                          product: productMap[line.productId],
                        ),
                    const Divider(height: 1, indent: 14, endIndent: 14),
                    InkWell(
                      onTap: widget.onBack,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add,
                                size: 16, color: AppColors.textSecondary),
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
                    InkWell(
                      onTap: () => _showAddLineSheet(context),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.library_add,
                                size: 16, color: AppColors.primaryLight),
                            const SizedBox(width: 6),
                            Text(
                              '+ Tambah Line',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.primaryLight,
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

  void _showAddLineSheet(BuildContext context) {
    final draft = context.read<DraftOrderProvider>();
    final products = context.read<ProductProvider>().products;
    final productMap = {for (final p in products) p.id: p};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddLineSheet(
        products: products,
        productMap: productMap,
        onAdd: (productId, qty, disc) {
          draft.addLine(productId, qty: qty, discount: disc);
        },
      ),
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
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.success,
          ),
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
}

class _LineRow extends StatefulWidget {
  final OrderLine line;
  final Product? product;
  const _LineRow({required this.line, required this.product});

  @override
  State<_LineRow> createState() => _LineRowState();
}

class _LineRowState extends State<_LineRow> {
  bool _showDiscount = false;
  String _layer1Type = 'PERCENT';
  String _layer2Type = 'PERCENT';
  String _layer3Type = 'PERCENT';
  final TextEditingController _layer1Controller = TextEditingController();
  final TextEditingController _layer2Controller = TextEditingController();
  final TextEditingController _layer3Controller = TextEditingController();

  @override
  void dispose() {
    _layer1Controller.dispose();
    _layer2Controller.dispose();
    _layer3Controller.dispose();
    super.dispose();
  }

  /// Sinkronkan controller + type chip dengan state diskon saat panel dibuka.
  void _syncFromState(ItemDiscount? disc) {
    _syncOne(1, disc?.layer1, _layer1Controller, (t) => _layer1Type = t);
    _syncOne(2, disc?.layer2, _layer2Controller, (t) => _layer2Type = t);
    _syncOne(3, disc?.layer3, _layer3Controller, (t) => _layer3Type = t);
  }

  void _syncOne(int idx, DiscountLayer? layer, TextEditingController ctrl,
      void Function(String) setType) {
    if (layer == null) {
      ctrl.text = '';
    } else {
      ctrl.text = '${layer.value}';
      setType(layer.type);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final draft = context.watch<DraftOrderProvider>();
    final name = widget.product?.namaBarang ?? widget.line.productId;
    final price = widget.product?.harga ?? 0;
    final rawSubtotal = price * widget.line.qty;

    final disc = widget.line.discount;

    // Hitung chain 3 layers untuk display subtotal item.
    int running = rawSubtotal;
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

    final isFree = widget.line.isFree;

    return Opacity(
      opacity: isFree ? 0.6 : 1.0,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: AppTextStyles.bodyMedium),
                          if (widget.line.isFree) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
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
                          const SizedBox(height: 2),
                          Text(
                            '× ${widget.line.qty} · ${currency.format(price)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (totalCut > 0) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currency.format(rawSubtotal),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          Text(
                            currency.format(subtotal),
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Text(
                        currency.format(subtotal),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        disc != null
                            ? Icons.edit_outlined
                            : Icons.discount_outlined,
                        size: 18,
                        color: disc != null
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      tooltip: disc != null ? 'Edit diskon' : 'Tambah diskon',
                      onPressed: () {
                        setState(() {
                          _showDiscount = !_showDiscount;
                          if (_showDiscount) _syncFromState(disc);
                        });
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                      tooltip: 'Menu',
                      onSelected: (value) {
                        if (value == 'duplicate') {
                          draft.addLine(
                            widget.line.productId,
                            qty: widget.line.qty,
                            discount: widget.line.discount,
                          );
                        } else if (value == 'delete') {
                          draft.removeLine(widget.line.id);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
                              SizedBox(width: 8),
                              Text('Duplikat line'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Hapus line', style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (disc != null && !disc.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _activeLayersSummary(disc, currency),
                  ),
              ],
            ),
          ),
          if (_showDiscount) ...[
            for (var entry in const [
              _LayerSpec(1, 'Diskon 1'),
              _LayerSpec(2, 'Diskon 2'),
              _LayerSpec(3, 'Diskon 3'),
            ])
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                child: _LayerInputRow(
                  spec: entry,
                  type: _typeFor(entry.idx),
                  controller: _ctrlFor(entry.idx),
                  currency: currency,
                  onTypeChanged: (newType) {
                    setState(() => _setTypeFor(entry.idx, newType));
                    _ctrlFor(entry.idx).clear();
                  },
                  onValueChanged: (parsed) {
                    draft.setDiscountLayer(
                      lineId: widget.line.id,
                      layer: entry.idx,
                      type: _typeFor(entry.idx),
                      value: parsed,
                    );
                  },
                  onClear: () {
                    draft.setDiscountLayer(
                      lineId: widget.line.id,
                      layer: entry.idx,
                      type: _typeFor(entry.idx),
                      value: 0,
                    );
                    _ctrlFor(entry.idx).clear();
                  },
                  hasValue: _hasValueFor(entry.idx, disc),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _typeFor(int idx) {
    switch (idx) {
      case 1:
        return _layer1Type;
      case 2:
        return _layer2Type;
      case 3:
        return _layer3Type;
    }
    return 'PERCENT';
  }

  void _setTypeFor(int idx, String t) {
    switch (idx) {
      case 1:
        _layer1Type = t;
        break;
      case 2:
        _layer2Type = t;
        break;
      case 3:
        _layer3Type = t;
        break;
    }
  }

  TextEditingController _ctrlFor(int idx) {
    switch (idx) {
      case 1:
        return _layer1Controller;
      case 2:
        return _layer2Controller;
      case 3:
        return _layer3Controller;
    }
    return _layer1Controller;
  }

  bool _hasValueFor(int idx, ItemDiscount? disc) {
    if (disc == null) return false;
    switch (idx) {
      case 1:
        return disc.layer1 != null;
      case 2:
        return disc.layer2 != null;
      case 3:
        return disc.layer3 != null;
    }
    return false;
  }

  Widget _activeLayersSummary(ItemDiscount disc, NumberFormat currency) {
    final parts = <String>[];
    for (final entry in [(1, disc.layer1), (2, disc.layer2), (3, disc.layer3)]) {
      final l = entry.$2;
      if (l == null) continue;
      final label = entry.$1 == 1
          ? 'Diskon 1'
          : entry.$1 == 2
              ? 'Diskon 2'
              : 'Diskon 3';
      if (l.type == 'NOMINAL') {
        parts.add('$label: Rp ${currency.format(l.value)}');
      } else {
        parts.add('$label: ${l.value}%');
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
}

class _LayerSpec {
  final int idx;
  final String label;
  const _LayerSpec(this.idx, this.label);
}

class _LayerInputRow extends StatelessWidget {
  final _LayerSpec spec;
  final String type;
  final TextEditingController controller;
  final NumberFormat currency;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<int> onValueChanged;
  final VoidCallback onClear;
  final bool hasValue;

  const _LayerInputRow({
    required this.spec,
    required this.type,
    required this.controller,
    required this.currency,
    required this.onTypeChanged,
    required this.onValueChanged,
    required this.onClear,
    required this.hasValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            spec.label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ChoiceChip(
          label: const Text('%'),
          selected: type == 'PERCENT',
          selectedColor: AppColors.primaryLight,
          labelStyle: TextStyle(
            color: type == 'PERCENT' ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
          ),
          onSelected: (sel) {
            if (!sel) return;
            onTypeChanged('PERCENT');
          },
        ),
        const SizedBox(width: 4),
        ChoiceChip(
          label: const Text('Rp'),
          selected: type == 'NOMINAL',
          selectedColor: AppColors.primaryLight,
          labelStyle: TextStyle(
            color: type == 'NOMINAL' ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
          ),
          onSelected: (sel) {
            if (!sel) return;
            onTypeChanged('NOMINAL');
          },
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 90,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              prefixText: type == 'NOMINAL' ? 'Rp ' : null,
              suffixText: type == 'PERCENT' ? '%' : null,
              hintText: '0',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) => onValueChanged(int.tryParse(v) ?? 0),
          ),
        ),
        const SizedBox(width: 4),
        if (hasValue)
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Hapus', style: TextStyle(fontSize: 11)),
          ),
      ],
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
    final v = int.tryParse(_layer1Controller.text) ?? 0;
    if (v <= 0) return null;
    int capped = v;
    if (_layer1Type == 'PERCENT' && v > 100) capped = 100;
    return ItemDiscount(layer1: DiscountLayer(type: _layer1Type, value: capped));
  }

  @override
  void dispose() {
    _layer1Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProduct = _selectedProductId != null ? widget.productMap[_selectedProductId] : null;

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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            initialValue: _selectedProductId,
            items: widget.products.map((p) => DropdownMenuItem(
              value: p.id,
              child: Text(p.namaBarang, overflow: TextOverflow.ellipsis),
            )).toList(),
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
              Text('$_qty', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              IconButton(
                onPressed: selectedProduct != null && _qty < selectedProduct.stokTersedia
                    ? () => setState(() => _qty++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),

          const Text('Diskon Layer 1 (opsional):', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('%'),
                selected: _layer1Type == 'PERCENT',
                onSelected: (sel) { if (sel) setState(() => _layer1Type = 'PERCENT'); },
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('Rp'),
                selected: _layer1Type == 'NOMINAL',
                onSelected: (sel) { if (sel) setState(() => _layer1Type = 'NOMINAL'); },
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _layer1Controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: _layer1Type == 'PERCENT' ? '0%' : 'Rp 0',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
