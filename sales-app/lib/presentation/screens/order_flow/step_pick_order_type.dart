import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design_system.dart';
import '../../providers/draft_order_provider.dart';

/// Step 2 order flow — pilih tipe order (Reguler atau 4P).
/// Produk yang ditampilkan di step 3 akan ter-filter sesuai tipe yang dipilih.
class StepPickOrderType extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepPickOrderType({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<StepPickOrderType> createState() => _StepPickOrderTypeState();
}

class _StepPickOrderTypeState extends State<StepPickOrderType> {
  static const _options = ['REGULER', '4P'];

  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = context.read<DraftOrderProvider>().orderType;
  }

  void _select(String type) {
    setState(() => _selected = type);
    context.read<DraftOrderProvider>().orderType = type;
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _options.contains(_selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            'Pilih Tipe Order',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Tipe ini menentukan produk yang akan muncul di langkah berikutnya.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < _options.length; i++) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, i == _options.length - 1 ? 0 : 12),
            child: _OrderTypeCard(
              type: _options[i],
              isSelected: _selected == _options[i],
              onTap: () => _select(_options[i]),
            ),
          ),
        ],
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Kembali'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: hasSelection ? widget.onNext : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Lanjut'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderTypeCard extends StatelessWidget {
  final String type;
  final bool isSelected;
  final VoidCallback onTap;

  const _OrderTypeCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final description = type == 'REGULER'
        ? 'Order reguler untuk produk-produk biasa.'
        : 'Order khusus program 4P (promo / bundling).';

    return Material(
      color: isSelected ? AppColors.primaryLight : AppColors.cardSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryLight : AppColors.borderLight,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  type == '4P' ? Icons.star_rounded : Icons.store_rounded,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.9)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? Colors.white : AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
