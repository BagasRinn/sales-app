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
                    for (final entry in draft.items.entries)
                      if (entry.value > 0)
                        _ProductRow(
                          product: productMap[entry.key],
                          qty: entry.value,
                          productId: entry.key,
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

              // Total
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total (${draft.totalItems} item)',
                          style: AppTextStyles.bodyLarge,
                        ),
                        Text(
                          currency.format(draft.totalPrice),
                          style: AppTextStyles.headlineSmall.copyWith(
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                    if (draft.totalDiscount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Hemat',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                          Text(
                            '- ${currency.format(draft.totalDiscount)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
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

class _ProductRow extends StatefulWidget {
  final Product? product;
  final int qty;
  final String productId;
  const _ProductRow({
    required this.product,
    required this.qty,
    required this.productId,
  });

  @override
  State<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<_ProductRow> {
  late TextEditingController _discountController;
  bool _showDiscount = false;
  // Track tipe diskon yang sedang dipilih. Default: PERCENT (backward compat).
  String _discountType = 'PERCENT';

  @override
  void initState() {
    super.initState();
    final draft = context.read<DraftOrderProvider>();
    final info = draft.discounts[widget.productId];
    if (info != null) {
      _discountType = info.type;
      _discountController =
          TextEditingController(text: info.value.toString());
    } else {
      _discountController = TextEditingController();
    }
  }

  @override
  void didUpdateWidget(covariant _ProductRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sinkronkan textfield kalau draft.discounts berubah dari luar (mis. tombol hapus).
    final draft = context.read<DraftOrderProvider>();
    final info = draft.discounts[widget.productId];
    if (info == null && _discountController.text.isNotEmpty) {
      _discountController.clear();
    } else if (info != null && _discountController.text != info.value.toString()) {
      _discountController.text = info.value.toString();
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  int _calcHargaNet(int price, DiscountInfo? info) {
    if (info == null) return price;
    if (info.type == 'NOMINAL') {
      return (price - info.value).clamp(0, price);
    }
    return (price * (100 - info.value) / 100).round();
  }

  Widget _buildPriceCell(
    DiscountInfo? info,
    int price,
    int qty,
    int subtotal,
    NumberFormat currency,
  ) {
    if (info != null) {
      final original = price * qty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            currency.format(original),
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
      );
    }
    return Text(
      currency.format(price * qty),
      style: AppTextStyles.bodyMedium.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<DraftOrderProvider>();
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final name = widget.product?.namaBarang ?? widget.productId;
    final price = widget.product?.harga ?? 0;
    final info = draft.discounts[widget.productId];
    final hargaNet = _calcHargaNet(price, info);
    final subtotal = hargaNet * widget.qty;
    final nominalDiskon = info == null ? 0 : (price - hargaNet) * widget.qty;

    return Padding(
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
                    const SizedBox(height: 2),
                    Text(
                      '× ${widget.qty} · ${currency.format(price)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildPriceCell(info, price, widget.qty, subtotal, currency),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.discount_outlined,
                    size: 18, color: AppColors.primaryLight),
                tooltip: 'Diskon',
                onPressed: () => setState(() => _showDiscount = !_showDiscount),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.error),
                tooltip: 'Hapus',
                onPressed: () {
                  draft.setQty(widget.productId, 0);
                  _discountController.clear();
                },
              ),
            ],
          ),
          if (_showDiscount)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Segmented control: Persen vs Nominal
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('% Persen'),
                        selected: _discountType == 'PERCENT',
                        selectedColor: AppColors.primaryLight,
                        side: BorderSide(
                          color: _discountType == 'PERCENT'
                              ? AppColors.primaryLight
                              : AppColors.border,
                          width: 1.5,
                        ),
                        labelStyle: TextStyle(
                          color: _discountType == 'PERCENT'
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: _discountType == 'PERCENT'
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        onSelected: (sel) {
                          if (!sel) return;
                          setState(() {
                            _discountType = 'PERCENT';
                            _discountController.clear();
                            if (info != null) {
                              draft.setDiscount(
                                productId: widget.productId,
                                type: 'PERCENT',
                                value: 0,
                              );
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Rp Nominal'),
                        selected: _discountType == 'NOMINAL',
                        selectedColor: AppColors.primaryLight,
                        side: BorderSide(
                          color: _discountType == 'NOMINAL'
                              ? AppColors.primaryLight
                              : AppColors.border,
                          width: 1.5,
                        ),
                        labelStyle: TextStyle(
                          color: _discountType == 'NOMINAL'
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: _discountType == 'NOMINAL'
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        onSelected: (sel) {
                          if (!sel) return;
                          setState(() {
                            _discountType = 'NOMINAL';
                            _discountController.clear();
                            if (info != null) {
                              draft.setDiscount(
                                productId: widget.productId,
                                type: 'NOMINAL',
                                value: 0,
                              );
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            prefixText: _discountType == 'NOMINAL' ? 'Rp ' : null,
                            suffixText: _discountType == 'PERCENT' ? '%' : null,
                            hintText: '0',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          style: AppTextStyles.bodyMedium,
                          onChanged: (v) {
                            final parsed = int.tryParse(v) ?? 0;
                            try {
                              draft.setDiscount(
                                productId: widget.productId,
                                type: _discountType,
                                value: parsed,
                              );
                              setState(() {});
                            } on ArgumentError {
                              // value di luar range — jangan apply, tapi jangan
                              // crash UI. User akan melihat hint error dari
                              // helper text di bawah input.
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (info != null)
                        Text(
                          'Hemat ${currency.format(nominalDiskon)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.success,
                          ),
                        )
                      else
                        Text(
                          _discountType == 'PERCENT'
                              ? 'Masukkan % diskon'
                              : 'Masukkan nominal (Rp)',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
