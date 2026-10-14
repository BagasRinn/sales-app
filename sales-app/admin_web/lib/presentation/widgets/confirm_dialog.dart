import 'package:flutter/material.dart';

import '../../core/design_system.dart';
import '../../core/responsive.dart';
import '../../core/responsive_dialog.dart';
import 'responsive_bottom_sheet.dart';

/// Helpers untuk dialog konfirmasi dan info sederhana.
///
/// Pola pemanggilan identik dengan dialog native Flutter, tetapi adapter
/// otomatis memilih container yang sesuai dengan lebar viewport:
/// - **Compact** (< 600px): bottom sheet dari bawah layar (Material 3)
///   lewat [ResponsiveBottomSheet]. Lebih native di mobile, keyboard tidak
///   menutupi tombol karena sheet naik dari bawah.
/// - **Medium/Expanded** (>= 600px): centered [ResponsiveAlertDialog]
///   dengan title bar, content, dan row tombol di kanan bawah.
///
/// Pemakaian:
/// ```dart
/// final ok = await ConfirmDialog.show(
///   context: context,
///   title: 'Hapus Bulletin',
///   message: 'Bulletin yang dihapus tidak dapat dikembalikan.',
///   confirmLabel: 'Hapus',
///   isDestructive: true,
/// );
/// if (ok == true) { ... }
///
/// await InfoDialog.show(
///   context: context,
///   title: 'Berhasil',
///   message: 'Data telah disimpan.',
/// );
/// ```
class ConfirmDialog {
  ConfirmDialog._();

  /// Tampilkan dialog konfirmasi. Mengembalikan:
  /// - `true` bila user menekan tombol konfirmasi
  /// - `false` bila user menekan tombol batal
  /// - `null` bila ditutup tanpa pilihan (tap di luar, tombol close, dsb.)
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Konfirmasi',
    String? cancelLabel = 'Batal',
    bool isDestructive = false,
  }) async {
    final confirmBtn = _ConfirmButton(
      label: confirmLabel,
      isDestructive: isDestructive,
      onPressed: () => Navigator.of(context).pop(true),
    );
    final cancelBtn = _CancelButton(
      label: cancelLabel,
      onPressed: () => Navigator.of(context).pop(false),
    );
    // Pada compact, ResponsiveBottomSheet membungkus body di dalam
    // showModalBottomSheet — jadi urutan actions di sini menentukan urutan
    // tombol dari atas ke bawah di mobile (cancel di atas konfirmasi, sesuai
    // pedoman Material untuk destructive action).
    final compactActions = <Widget>[cancelBtn, confirmBtn];
    // Pada medium/expanded, ResponsiveAlertDialog merender actions dalam
    // Row end-aligned — jadi urutan di sini = urutan visual dari kiri ke
    // kanan (cancel dulu, confirm di kanan).
    final wideActions = <Widget>[cancelBtn, confirmBtn];

    return _showResponsive<bool>(
      context: context,
      title: Text(title),
      content: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      ),
      compactActions: compactActions,
      wideActions: wideActions,
    );
  }
}

/// Dialog info satu-tombol (OK) untuk notifikasi non-interaktif.
///
/// Pola sama dengan [ConfirmDialog]: bottom sheet di compact, alert dialog
/// di medium/expanded. Icon opsional ditampilkan di sebelah title; gunakan
/// untuk membedakan konteks (info, success, warning).
class InfoDialog {
  InfoDialog._();

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    String okLabel = 'OK',
    IconData? icon,
  }) async {
    final okBtn = _ConfirmButton(
      label: okLabel,
      isDestructive: false,
      onPressed: () => Navigator.of(context).pop(),
    );
    final compactActions = <Widget>[okBtn];
    final wideActions = <Widget>[okBtn];

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );

    await _showResponsive<void>(
      context: context,
      title: icon == null
          ? Text(title)
          : Row(
              children: [
                Icon(icon, size: 24, color: AppColors.primaryLight),
                const SizedBox(width: 12),
                Expanded(child: Text(title)),
              ],
            ),
      content: body,
      compactActions: compactActions,
      wideActions: wideActions,
    );
  }
}

// ─── Internal helpers ───────────────────────────────────────────────────────

/// Pilih container (bottom sheet vs alert dialog) berdasarkan lebar viewport
/// saat ini. Dipakai bersama oleh [ConfirmDialog] dan [InfoDialog] agar
/// breakpoint detection-nya konsisten.
Future<T?> _showResponsive<T>({
  required BuildContext context,
  required Widget title,
  required Widget content,
  required List<Widget> compactActions,
  required List<Widget> wideActions,
}) async {
  final width = _viewportWidth(context);
  if (width < Breakpoints.compactMax) {
    return ResponsiveBottomSheet.show<T>(
      context: context,
      title: title,
      child: content,
      actions: compactActions,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (_) => ResponsiveAlertDialog(
      title: DefaultTextStyle.merge(
        style: AppTextStyles.headlineSmall,
        child: title,
      ),
      content: content,
      actions: wideActions,
    ),
  );
}

/// Lebar viewport logical pixel. Pakai [View.of] (bukan [MediaQuery]) supaya
/// tidak terikat ke inset/padding keyboard — kita hanya butuh lebar layar
/// untuk memilih breakpoint.
double _viewportWidth(BuildContext context) {
  final view = View.of(context);
  if (view.physicalSize.width == 0) {
    // Fallback kalau view belum ter-attach (mis. test/headless). Pakai
    // MediaQuery sebagai cadangan.
    return MediaQuery.of(context).size.width;
  }
  return view.physicalSize.width / view.devicePixelRatio;
}

class _ConfirmButton extends StatelessWidget {
  final String label;
  final bool isDestructive;
  final VoidCallback onPressed;

  const _ConfirmButton({
    required this.label,
    required this.isDestructive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final style = isDestructive
        ? FilledButton.styleFrom(backgroundColor: AppColors.error)
        : null;
    return FilledButton(
      style: style,
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final String? label;
  final VoidCallback onPressed;

  const _CancelButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Pakai OutlinedButton (bukan TextButton) di posisi sekunder supaya tombol
    // tetap terlihat jelas sebagai opsi pembatal di kedua mode — di compact
    // tombol ditumpuk vertikal dengan tinggi minimum 44px.
    if (label == null) {
      return const SizedBox.shrink();
    }
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(label!),
    );
  }
}
