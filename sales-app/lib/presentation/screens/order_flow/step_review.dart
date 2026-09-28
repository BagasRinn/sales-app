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

/// Widget kartu total + input diskon level order.
/// Diskon ditampilkan/setelah total harga, bukan per item.
class _OrderTotalCard extends StatefulWidget {
  final DraftOrderProvider draft;
  final NumberFormat currency;

  const _OrderTotalCard({required this.draft, required this.currency});

  @override
  State<_OrderTotalCard> createState() => _OrderTotalCardState();
}

class _OrderTotalCardState extends State<_OrderTotalCard> {
  late TextEditingController _discountController;
  String _discountType = 'PERCENT';
  bool _showDiscountInput = false;

  @override
  void initState() {
    super.initState();
    final od = widget.draft.orderDiscount;
    if (od != null) {
      _discountType = od.type;
      _discountController =
          TextEditingController(text: od.value.toString());
    } else {
      _discountController = TextEditingController();
    }
  }

  @override
  void didUpdateWidget(covariant _OrderTotalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final od = widget.draft.orderDiscount;
    if (od == null && _discountController.text.isNotEmpty) {
      // diskon dihapus dari luar
      _discountController.clear();
    } else if (od != null) {
      if (_discountController.text != od.value.toString()) {
        _discountController.text = od.value.toString();
      }
      if (_discountType != od.type) {
        setState(() => _discountType = od.type);
      }
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final hasDiscount = draft.orderDiscount != null;
    final raw = draft.totalRaw;

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
                // Baris: Total item
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total (${draft.totalItems} item)',
                      style: AppTextStyles.bodyLarge,
                    ),
                    Text(
                      widget.currency.format(raw),
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),

                // Baris: Diskon
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Diskon',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (hasDiscount) ...[
                      Text(
                        _discountType == 'NOMINAL'
                            ? '- ${widget.currency.format(draft.orderDiscount!.value)}'
                            : '- ${draft.orderDiscount!.value}%',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else
                      Text(
                        '-',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        hasDiscount
                            ? Icons.edit_outlined
                            : Icons.discount_outlined,
                        size: 18,
                        color: AppColors.primaryLight,
                      ),
                      tooltip: 'Tambah/diskon',
                      onPressed: () =>
                          setState(() => _showDiscountInput = !_showDiscountInput),
                    ),
                  ],
                ),

                if (hasDiscount) ...[
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
                        widget.currency.format(draft.totalDiscount),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
                      widget.currency.format(draft.totalPrice),
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Input diskon (expandable)
          if (_showDiscountInput) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tipe Diskon',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
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
                            draft.setOrderDiscount(type: 'PERCENT', value: 0);
                          });
                        },
                      ),
                      const SizedBox(width: 8),
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
                            draft.setOrderDiscount(type: 'NOMINAL', value: 0);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
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
                            draft.setOrderDiscount(
                              type: _discountType,
                              value: parsed,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (draft.orderDiscount != null)
                        Text(
                          'Hemat ${widget.currency.format(draft.totalDiscount)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product? product;
  final int qty;
  final String productId;
  const _ProductRow({
    required this.product,
    required this.qty,
    required this.productId,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final draft = context.watch<DraftOrderProvider>();
    final name = product?.namaBarang ?? productId;
    final price = product?.harga ?? 0;
    final subtotal = price * qty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  '× $qty · ${currency.format(price)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            currency.format(subtotal),
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.error),
            tooltip: 'Hapus',
            onPressed: () => draft.setQty(productId, 0),
          ),
        ],
      ),
    );
  }
}
