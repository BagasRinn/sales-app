import 'package:flutter/material.dart';

import '../app_tokens.dart';
import 'app_button.dart';

/// Pagination standar: ringkasan di kiri, tombol Prev/Next di kanan.
/// `page` 1-based; widget tidak menyimpan state (tetap milik halaman).
class AppPagination extends StatelessWidget {
  final int page;
  final int totalPages;
  final bool hasPrev;
  final bool hasNext;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final String? summary;

  const AppPagination({
    super.key,
    required this.page,
    required this.totalPages,
    required this.hasPrev,
    required this.hasNext,
    this.onPrev,
    this.onNext,
    this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final label = summary ?? 'Halaman $page dari $totalPages';
    return LayoutBuilder(
      builder: (context, constraints) {
        final buttons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: 'Sebelumnya',
              variant: AppButtonVariant.outline,
              onPressed: hasPrev ? onPrev : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              label: 'Berikutnya',
              variant: AppButtonVariant.outline,
              onPressed: hasNext ? onNext : null,
            ),
          ],
        );

        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.sm),
              buttons,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.caption)),
            buttons,
          ],
        );
      },
    );
  }
}
