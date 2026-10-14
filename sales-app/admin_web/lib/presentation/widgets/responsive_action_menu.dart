import 'package:flutter/material.dart';
import 'package:admin_web/core/design_system.dart';
import 'package:admin_web/core/responsive.dart';

/// Satu entri di dalam [ResponsiveActionMenu].
///
/// Pakai [destructive] untuk aksi hapus/tolak — ikon dan label diwarnai
/// dengan [AppColors.error] supaya maksud destruktif terlihat sekilas.
class MenuAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  const MenuAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });
}

/// Overflow menu bergaya kebab yang adaptif terhadap viewport.
///
/// - [compact] = true (default): trigger kebab 44x44 di semua ukuran layar.
///   Cocok untuk kartu mobile, kolom aksi tabel yang sempit, atau baris
///   daftar yang rapat.
/// - [compact] = false: pada tablet/desktop, dua aksi pertama dipromosikan
///   menjadi IconButton inline (lebih cepat tanpa tap tambahan) dan sisanya
///   tetap masuk ke kebab. Pada mobile tetap kebab karena ruang horizontal
///   tidak cukup.
///
/// Trigger menghormati tap-target Material minimum 44dp agar tetap mudah
/// disentuh di perangkat touch.
class ResponsiveActionMenu extends StatelessWidget {
  final List<MenuAction> actions;
  final String? tooltip;
  final Widget? icon;
  final bool compact;

  const ResponsiveActionMenu({
    super.key,
    required this.actions,
    this.tooltip,
    this.icon,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final resp = Responsive.of(constraints.maxWidth);

        if (compact || resp.isMobile) {
          return _kebab();
        }

        return _splitLayout(resp);
      },
    );
  }

  Widget _kebab() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: PopupMenuButton<MenuAction>(
        tooltip: tooltip,
        icon: icon ?? const Icon(Icons.more_vert, size: 20),
        itemBuilder: (ctx) => [
          for (final action in actions)
            PopupMenuItem<MenuAction>(
              value: action,
              height: 44,
              child: _MenuActionRow(action: action),
            ),
        ],
        onSelected: (action) => action.onTap(),
      ),
    );
  }

  Widget _splitLayout(Responsive resp) {
    // Promote the first 2 actions to inline icon buttons; remainder stays
    // in the kebab so the row doesn't grow unbounded on wide tables.
    const inlineCount = 2;
    final inline = actions.take(inlineCount).toList();
    final overflow = actions.skip(inlineCount).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in inline) ...[
          _InlineActionButton(action: action, tooltip: action.label),
          SizedBox(width: resp.gap * 0.5),
        ],
        if (overflow.isNotEmpty)
          ResponsiveActionMenu(
            actions: overflow,
            tooltip: tooltip,
            icon: icon,
            compact: true,
          ),
      ],
    );
  }
}

/// Row inside a [PopupMenuItem]: icon + 8px gap + label. Destructive
/// actions color both the icon and label with [AppColors.error].
class _MenuActionRow extends StatelessWidget {
  final MenuAction action;
  const _MenuActionRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final color = action.destructive ? AppColors.error : AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(action.icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(action.label, style: AppTextStyles.bodyMedium.copyWith(color: color)),
      ],
    );
  }
}

/// Inline icon-button variant used when [ResponsiveActionMenu.compact] is
/// false on tablet/desktop. Same 44dp minimum tap target as the kebab.
class _InlineActionButton extends StatelessWidget {
  final MenuAction action;
  final String tooltip;
  const _InlineActionButton({required this.action, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    final color = action.destructive ? AppColors.error : AppColors.textSecondary;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(action.icon, size: 20, color: color),
        onPressed: action.onTap,
      ),
    );
  }
}
