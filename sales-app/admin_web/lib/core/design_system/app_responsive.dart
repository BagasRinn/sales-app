import 'package:flutter/material.dart';

/// Breakpoint: mobile `< 600`, tablet `600–1023`, desktop `>= 1024`.
///
/// Semua layout adaptif memakai helper ini; jangan hardcode angka breakpoint
/// di halaman.
class AppResponsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const AppResponsive({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 600 && w < 1024;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1024;

  static EdgeInsets pagePadding(BuildContext context) {
    if (isDesktop(context)) return const EdgeInsets.all(24.0);
    if (isTablet(context)) return const EdgeInsets.all(16.0);
    return const EdgeInsets.all(12.0);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1024) return desktop;
    if (width >= 600) return tablet ?? desktop;
    return mobile;
  }
}

/// Grid adaptif bebas overflow (Wrap + LayoutBuilder, bukan GridView yang
/// butuh `childAspectRatio` kaku).
class AppResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int desktopCols;
  final int tabletCols;
  final int mobileCols;
  final double spacing;

  const AppResponsiveGrid({
    super.key,
    required this.children,
    this.desktopCols = 4,
    this.tabletCols = 2,
    this.mobileCols = 1,
    this.spacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Breakpoint sama dengan `Responsive` (600/1024) — satu bahasa layout.
        final int cols = width >= 1024
            ? desktopCols
            : (width >= 600 ? tabletCols : mobileCols);
        final double itemWidth =
            ((width - (spacing * (cols - 1))) / cols).clamp(120.0, width);

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}
