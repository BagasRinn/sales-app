import 'package:flutter/material.dart';
import '../../core/design_system.dart';
import '../../core/responsive.dart';
import '../../core/responsive_dialog.dart';

/// Bottom sheet / modal yang beradaptasi dengan lebar viewport.
///
/// - Compact (< 600px): muncul sebagai [showModalBottomSheet] dari bawah layar,
///   dengan drag handle, radius atas 20, dan tinggi mengikuti konten
///   ([isScrollControlled] true). Tombol aksi disusun vertikal mengikuti pola
///   tap-target mobile.
/// - Tablet/Desktop (>= 600px): muncul sebagai [showDialog] berisi
///   [ResponsiveDialog] (sized box dengan maxWidth/maxHeight) agar layout
///   tetap konsisten dengan dialog lain di app.
///
/// Pemakaian tipikal:
/// ```dart
/// final ok = await ResponsiveBottomSheet.show<bool>(
///   context: context,
///   title: const Text('Konfirmasi'),
///   child: const Text('Yakin ingin menghapus data ini?'),
///   actions: [
///     TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
///     FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
///   ],
/// );
/// ```
class ResponsiveBottomSheet {
  ResponsiveBottomSheet._();

  /// Menampilkan bottom sheet (mobile/tablet kecil) atau modal (tablet/desktop).
  ///
  /// Mengembalikan nilai yang di-pop dari sheet/dialog, atau `null` bila
  /// ditutup tanpa nilai (tap di luar, drag handle ke bawah, atau tombol
  /// close). Pemanggil bertanggung jawab melakukan `Navigator.pop(context, ...)`
  /// di dalam [child] atau [actions].
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    Widget? title,
    List<Widget> actions = const [],
    bool isScrollControlled = true,
    double maxWidth = 640,
    double maxHeight = 520,
  }) async {
    // Pakai LayoutBuilder supaya breakpoint konsisten dengan [Responsive.of].
    // Di compact pakai bottom sheet, di >= 600 pakai dialog terpusat.
    final view = View.of(context);
    final width = view.physicalSize.width / view.devicePixelRatio;

    if (width < Breakpoints.compactMax) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) => _BottomSheetBody(
          title: title,
          actions: actions,
          child: child,
        ),
      );
    }

    return showDialog<T>(
      context: context,
      builder: (dialogContext) => ResponsiveDialog(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        child: _BottomSheetBody(
          title: title,
          actions: actions,
          child: child,
        ),
      ),
    );
  }
}

/// Body bersama yang dirender baik di dalam bottom sheet maupun di dalam
/// [ResponsiveDialog]. Pemisahan ini agar tinggi/struktur konsisten di dua
/// mode; perbedaan presentasi (sheet vs dialog) hanya di [_ResponsiveBottomSheet.show].
class _BottomSheetBody extends StatelessWidget {
  final Widget? title;
  final Widget child;
  final List<Widget> actions;

  const _BottomSheetBody({
    required this.title,
    required this.actions,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              // Title bar dengan tombol close di kanan — pola yang sama
              // dengan [ResponsiveAlertDialog] di mobile.
              Row(
                children: [
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: AppTextStyles.headlineSmall,
                      child: title!,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Flexible(child: child),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: actions[i],
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
