import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_tokens.dart';
import 'app_button.dart';

/// Snackbar standar. Teks putih di atas warna solid (kontras >= 7:1).
class AppSnack {
  AppSnack._();

  static void success(BuildContext context, String message) =>
      _show(context, message, Icons.check_circle_outline, AppColors.successText);

  static void error(BuildContext context, String message) =>
      _show(context, message, Icons.error_outline, AppColors.dangerText);

  static void info(BuildContext context, String message) =>
      _show(context, message, Icons.info_outline, AppColors.primary);

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    Color background,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          content: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.onPrimary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.body.copyWith(color: AppColors.onPrimary),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

/// Dialog konfirmasi seragam. `await` mengembalikan `true` bila user setuju.
class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDanger;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Ya',
    this.cancelLabel = 'Batal',
    this.isDanger = false,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Ya',
    String cancelLabel = 'Batal',
    bool isDanger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDanger: isDanger,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: AppTextStyles.h2),
      content: Text(message, style: AppTextStyles.bodyMuted),
      actions: [
        AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: confirmLabel,
          variant: isDanger ? AppButtonVariant.danger : AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
