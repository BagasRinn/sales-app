import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_tokens.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Kondisi kosong: ikon + judul + penjelasan + aksi opsional. Satu widget untuk
/// semua daftar supaya "tidak ada data" tidak lagi didesain ulang per tab.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: AppColors.textSubtle),
          const SizedBox(height: AppSpacing.sm + 4),
          Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              message!,
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Kondisi gagal muat data. Selalu tampil dengan tombol "Coba lagi".
class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 32, color: AppColors.danger),
          const SizedBox(height: AppSpacing.sm + 4),
          Text(
            message,
            style: AppTextStyles.bodyMuted,
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Coba lagi',
              icon: Icons.refresh,
              variant: AppButtonVariant.outline,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder loading berbentuk baris tabel (tanpa animasi, cukup 6 baris)
/// supaya tinggi konten tidak "melompat" seperti spinner di tengah kartu.
class AppSkeletonList extends StatelessWidget {
  final int rows;
  final double rowHeight;

  const AppSkeletonList({super.key, this.rows = 6, this.rowHeight = 18});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm + 4),
            Container(
              height: rowHeight,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadius.sm,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
