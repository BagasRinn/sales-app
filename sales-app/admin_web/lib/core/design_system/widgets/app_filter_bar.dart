import 'package:flutter/material.dart';

import '../app_tokens.dart';
import 'app_card.dart';
import 'app_input.dart';

/// Toolbar filter standar: satu kartu putih berisi kontrol filter (dropdown,
/// tanggal, search) dalam `Wrap` — otomatis 2 baris di layar sempit.
class AppFilterBar extends StatelessWidget {
  final List<Widget> children;

  const AppFilterBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

/// Search box dengan ikon + tombol bersihkan. `onChanged('')` ikut dipanggil
/// saat tombol bersihkan ditekan supaya filter halaman tetap sinkron.
class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Dipanggil setelah input dibersihkan — pakai ini kalau halaman punya
  /// handler clear khusus (mis. request langsung, tanpa debounce).
  final VoidCallback? onClear;

  const AppSearchField({
    super.key,
    required this.controller,
    this.hint = 'Cari…',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => AppInput(
        controller: controller,
        hint: hint,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: value.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, size: 16),
                tooltip: 'Bersihkan',
                onPressed: () {
                  controller.clear();
                  onClear?.call();
                  onChanged?.call('');
                },
                iconSize: 16,
              ),
      ),
    );
  }
}

/// Header kecil di dalam kartu: judul + aksi di kanan (mis. "3 produk").
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppTextStyles.h3),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: AppTextStyles.caption),
                ),
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.sm),
          Wrap(spacing: AppSpacing.sm, children: actions),
        ],
      ],
    );
  }
}
