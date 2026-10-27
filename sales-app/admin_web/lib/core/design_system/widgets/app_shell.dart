import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_tokens.dart';

class AppShellNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool showBadge;

  /// Judul grup opsional. Sidebar desktop menampilkan satu label kecil setiap
  /// kali nilai ini berubah; rail/drawer mengabaikannya (item tetap urut).
  final String? group;

  const AppShellNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.showBadge = false,
    this.group,
  });
}

/// Navigasi adaptif: sidebar navy 256px (desktop), `NavigationRail` 72px
/// (tablet), dan `AppBar` putih + `Drawer` navy (mobile).
///
/// Widget ini hanya mengurus tampilan. State `selectedIndex`, callback
/// navigasi, dan aksi user tetap dimiliki halaman pemanggil.
class AppShell extends StatelessWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final Widget body;
  final String title;
  final Widget? titleTrailing;
  final List<Widget> actions;
  final String brandTitle;
  final String? brandSubtitle;
  final IconData brandIcon;
  final List<AppShellNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onIndexSelected;
  final String userName;
  final String roleLabel;
  final VoidCallback? onChangePassword;
  final VoidCallback? onLogout;

  const AppShell({
    super.key,
    this.scaffoldKey,
    required this.body,
    required this.title,
    this.titleTrailing,
    this.actions = const [],
    required this.brandTitle,
    this.brandSubtitle,
    this.brandIcon = Icons.local_shipping,
    required this.items,
    required this.selectedIndex,
    required this.onIndexSelected,
    required this.userName,
    required this.roleLabel,
    this.onChangePassword,
    this.onLogout,
  });

  static const double _sidebarWidth = 256;
  static const double _railWidth = 72;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 1024;
        final isTablet = width >= 600 && width < 1024;

        if (isDesktop) {
          return Scaffold(
            key: scaffoldKey,
            backgroundColor: AppColors.scaffoldBg,
            body: _DesktopFrame(
              brandTitle: brandTitle,
              brandSubtitle: brandSubtitle,
              brandIcon: brandIcon,
              items: items,
              selectedIndex: selectedIndex,
              onIndexSelected: onIndexSelected,
              userName: userName,
              roleLabel: roleLabel,
              onChangePassword: onChangePassword,
              onLogout: onLogout,
              title: title,
              titleTrailing: titleTrailing,
              actions: actions,
              body: body,
            ),
          );
        }

        if (isTablet) {
          return Scaffold(
            key: scaffoldKey,
            backgroundColor: AppColors.scaffoldBg,
            body: Row(
              children: [
                SizedBox(
                  width: _railWidth,
                  child: _RailPanel(
                    brandIcon: brandIcon,
                    items: items,
                    selectedIndex: selectedIndex,
                    onIndexSelected: onIndexSelected,
                    onChangePassword: onChangePassword,
                    onLogout: onLogout,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        title: title,
                        titleTrailing: titleTrailing,
                        actions: actions,
                      ),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          key: scaffoldKey,
          backgroundColor: AppColors.scaffoldBg,
          appBar: AppBar(
            title: Text(title),
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            actions: actions,
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1),
            ),
          ),
          drawer: Drawer(
            width: math.min(288.0, MediaQuery.sizeOf(context).width * 0.85),
            backgroundColor: AppColors.primary,
            elevation: 0,
            child: _SidebarPanel(
              brandTitle: brandTitle,
              brandSubtitle: brandSubtitle,
              brandIcon: brandIcon,
              items: items,
              selectedIndex: selectedIndex,
              onIndexSelected: onIndexSelected,
              userName: userName,
              roleLabel: roleLabel,
              onChangePassword: onChangePassword,
              onLogout: onLogout,
            ),
          ),
          body: body,
        );
      },
    );
  }
}

/// Frame desktop: sidebar bisa di-collapse jadi rail 72px (ikon + tooltip),
/// pilihan disimpan selama sesi supaya layar lebar bisa dipakai untuk data.
class _DesktopFrame extends StatefulWidget {
  final String brandTitle;
  final String? brandSubtitle;
  final IconData brandIcon;
  final List<AppShellNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onIndexSelected;
  final String userName;
  final String roleLabel;
  final VoidCallback? onChangePassword;
  final VoidCallback? onLogout;
  final String title;
  final Widget? titleTrailing;
  final List<Widget> actions;
  final Widget body;

  const _DesktopFrame({
    required this.brandTitle,
    this.brandSubtitle,
    required this.brandIcon,
    required this.items,
    required this.selectedIndex,
    required this.onIndexSelected,
    required this.userName,
    required this.roleLabel,
    this.onChangePassword,
    this.onLogout,
    required this.title,
    this.titleTrailing,
    this.actions = const [],
    required this.body,
  });

  @override
  State<_DesktopFrame> createState() => _DesktopFrameState();
}

class _DesktopFrameState extends State<_DesktopFrame> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: _collapsed ? AppShell._railWidth : AppShell._sidebarWidth,
          child: _collapsed
              ? _RailPanel(
                  brandIcon: widget.brandIcon,
                  items: widget.items,
                  selectedIndex: widget.selectedIndex,
                  onIndexSelected: widget.onIndexSelected,
                  onChangePassword: widget.onChangePassword,
                  onLogout: widget.onLogout,
                )
              : _SidebarPanel(
                  brandTitle: widget.brandTitle,
                  brandSubtitle: widget.brandSubtitle,
                  brandIcon: widget.brandIcon,
                  items: widget.items,
                  selectedIndex: widget.selectedIndex,
                  onIndexSelected: widget.onIndexSelected,
                  userName: widget.userName,
                  roleLabel: widget.roleLabel,
                  onChangePassword: widget.onChangePassword,
                  onLogout: widget.onLogout,
                ),
        ),
        Expanded(
          child: Column(
            children: [
              _TopBar(
                title: widget.title,
                titleTrailing: widget.titleTrailing,
                actions: [
                  ...widget.actions,
                  IconButton(
                    icon: Icon(
                      _collapsed ? Icons.unfold_more : Icons.unfold_less,
                    ),
                    tooltip: _collapsed ? 'Lebarkan sidebar' : 'Sempitkan sidebar',
                    onPressed: () =>
                        setState(() => _collapsed = !_collapsed),
                  ),
                ],
              ),
              Expanded(child: widget.body),
            ],
          ),
        ),
      ],
    );
  }
}

/// Top bar putih: judul tab + elemen opsional (badge) + aksi (mis. refresh).
class _TopBar extends StatelessWidget {
  final String title;
  final Widget? titleTrailing;
  final List<Widget> actions;

  const _TopBar({
    required this.title,
    this.titleTrailing,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: AppTextStyles.h1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (titleTrailing != null)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: titleTrailing,
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Sidebar navy penuh: brand, daftar nav, lalu identitas user + aksi akun.
class _SidebarPanel extends StatelessWidget {
  final String brandTitle;
  final String? brandSubtitle;
  final IconData brandIcon;
  final List<AppShellNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onIndexSelected;
  final String userName;
  final String roleLabel;
  final VoidCallback? onChangePassword;
  final VoidCallback? onLogout;

  const _SidebarPanel({
    required this.brandTitle,
    this.brandSubtitle,
    required this.brandIcon,
    required this.items,
    required this.selectedIndex,
    required this.onIndexSelected,
    required this.userName,
    required this.roleLabel,
    this.onChangePassword,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.onPrimaryFaint,
                      borderRadius: AppRadius.md,
                    ),
                    child: Icon(brandIcon, color: AppColors.onPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brandTitle,
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (brandSubtitle != null)
                          Text(
                            brandSubtitle!,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.onPrimaryMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.onPrimaryFaint, height: 1),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 4,
                ),
                children: _buildNavList(),
              ),
            ),
            const Divider(color: AppColors.onPrimaryFaint, height: 1),
            _UserFooter(
              userName: userName,
              roleLabel: roleLabel,
              onChangePassword: onChangePassword,
              onLogout: onLogout,
            ),
          ],
        ),
      ),
    );
  }

  /// Daftar nav dengan label grup: jarak 20px antar grup, label 10.5px uppercase.
  List<Widget> _buildNavList() {
    final children = <Widget>[];
    String? lastGroup;
    for (var i = 0; i < items.length; i++) {
      final group = items[i].group;
      if (group != null && group != lastGroup) {
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(
              10,
              lastGroup == null ? 0 : AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Text(
              group.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onPrimaryMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
          ),
        );
        lastGroup = group;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _SidebarTile(
            item: items[i],
            selected: i == selectedIndex,
            onTap: () => onIndexSelected(i),
          ),
        ),
      );
    }
    return children;
  }
}

class _SidebarTile extends StatelessWidget {
  final AppShellNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.md,
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: onTap,
        child: Semantics(
          selected: selected,
          button: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryLight : Colors.transparent,
              borderRadius: AppRadius.md,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.onPrimarySubtle,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTextStyles.body.copyWith(
                      color: selected
                          ? AppColors.onPrimary
                          : AppColors.onPrimaryMuted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.showBadge) ...[
                  const SizedBox(width: 6),
                  const _BadgeDot(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tablet: rail sempit 72px, label disembunyikan (tooltip tetap tersedia
/// lewat label aksesibilitas bawaan `NavigationRailDestination`).
class _RailPanel extends StatelessWidget {
  final IconData brandIcon;
  final List<AppShellNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onIndexSelected;
  final VoidCallback? onChangePassword;
  final VoidCallback? onLogout;

  const _RailPanel({
    required this.brandIcon,
    required this.items,
    required this.selectedIndex,
    required this.onIndexSelected,
    this.onChangePassword,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: AppRadius.md,
              ),
              child: Icon(brandIcon, color: AppColors.onPrimary, size: 22),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onIndexSelected,
                backgroundColor: AppColors.primary,
                labelType: NavigationRailLabelType.none,
                groupAlignment: -1,
                minWidth: 72,
                indicatorColor: AppColors.primaryLight,
                indicatorShape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.md,
                ),
                selectedIconTheme: const IconThemeData(
                  color: AppColors.onPrimary,
                ),
                unselectedIconTheme: const IconThemeData(
                color: AppColors.onPrimarySubtle,
              ),
                destinations: [
                  for (final item in items)
                    NavigationRailDestination(
                      icon: _BadgedIcon(icon: item.icon, show: item.showBadge),
                      selectedIcon: _BadgedIcon(
                        icon: item.selectedIcon,
                        show: item.showBadge,
                      ),
                      label: Text(item.label),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.lock_outline,
                  color: AppColors.onPrimaryMuted, size: 20),
              tooltip: 'Ganti password',
              onPressed: onChangePassword,
            ),
            IconButton(
              icon: const Icon(Icons.logout,
                  color: AppColors.onPrimaryMuted, size: 20),
              tooltip: 'Keluar',
              onPressed: onLogout,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}


/// Identitas user + aksi akun di kaki sidebar.
class _UserFooter extends StatelessWidget {
  final String userName;
  final String roleLabel;
  final VoidCallback? onChangePassword;
  final VoidCallback? onLogout;

  const _UserFooter({
    required this.userName,
    required this.roleLabel,
    this.onChangePassword,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final display = userName.isEmpty ? 'Admin' : userName;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: AppRadius.md,
            ),
            alignment: Alignment.center,
            child: Text(
              display[0].toUpperCase(),
              style: AppTextStyles.h2.copyWith(color: AppColors.onPrimary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  roleLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.onPrimaryMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onChangePassword != null)
            IconButton(
              icon: const Icon(Icons.lock_outline,
                  color: AppColors.onPrimaryMuted, size: 20),
              tooltip: 'Ganti password',
              onPressed: onChangePassword,
            ),
          if (onLogout != null)
            IconButton(
              icon: const Icon(Icons.logout,
                  color: AppColors.onPrimaryMuted, size: 20),
              tooltip: 'Keluar',
              onPressed: onLogout,
            ),
        ],
      ),
    );
  }
}

class _BadgeDot extends StatelessWidget {
  const _BadgeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.danger,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  final IconData icon;
  final bool show;

  const _BadgedIcon({required this.icon, required this.show});

  @override
  Widget build(BuildContext context) {
    if (!show) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        const Positioned(right: -2, top: -1, child: _BadgeDot()),
      ],
    );
  }
}

