import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../app_colors.dart';

/// Header yang menempel di tepi atas viewport scroll selama kontennya masih
/// memotong tepi atas, lalu terangkat keluar bersama kartu ketika bawah
/// kontennya melewati header.
///
/// Dirancang untuk kartu ranking di halaman yang menggulung dengan satu
/// [SingleChildScrollView]: [header] dan [child] tetap satu kesatuan kartu
/// (border kartu, lebar, dan grid cell tidak berubah), hanya posisi paint
/// [header] yang digeser mengikuti scroll. Dua kartu berdampingan tetap pin
/// independen di kolomnya masing-masing.
///
/// Tanpa leluhur [Scrollable] (mis. di test atau halaman statis), header
/// tampil statis di posisi normalnya.
class AppStickyHeader extends StatefulWidget {
  const AppStickyHeader({
    super.key,
    required this.header,
    required this.child,
  });

  /// Blok header (judul kartu + judul kolom) yang menempel saat scroll.
  /// Wajib punya background solid — saat pin, baris [child] menggulung
  /// di belakangnya.
  final Widget header;

  /// Badan konten yang menggulung di bawah [header].
  final Widget child;

  @override
  State<AppStickyHeader> createState() => _AppStickyHeaderState();
}

class _AppStickyHeaderState extends State<AppStickyHeader> {
  static final double _pinnedThreshold = 0.5;

  final GlobalKey _boxKey = GlobalKey();
  final GlobalKey _headerKey = GlobalKey();

  ScrollPosition? _position;
  double _translate = 0;
  double _headerHeight = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.removeListener(_handleScroll);
    _position = Scrollable.maybeOf(context)?.position;
    _position?.addListener(_handleScroll);
    // Sinkron setelah frame: ukur tinggi header dan posisi terhadap viewport.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync();
    });
  }

  @override
  void dispose() {
    _position?.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() => _sync();

  /// Hitung geseran paint header. 0 = posisi natural; >0 = header naik ke
  /// tepi atas viewport (pin); dibatasi tinggi konten dikurangi tinggi
  /// header agar header lepas tepat saat kartu selesai lewat.
  void _sync() {
    final box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
    final headerBox =
        _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null ||
        !box.attached ||
        headerBox == null ||
        !headerBox.attached ||
        !headerBox.hasSize) {
      return;
    }

    final headerHeight = headerBox.size.height;
    var translate = 0.0;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport is RenderBox) {
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      final maxTranslate =
          (box.size.height - headerHeight).clamp(0.0, double.infinity);
      translate = (-top).clamp(0.0, maxTranslate);
    }

    final changed =
        (headerHeight - _headerHeight).abs() > _pinnedThreshold ||
            (translate - _translate).abs() > _pinnedThreshold;
    if (!changed || !mounted) return;
    setState(() {
      _headerHeight = headerHeight;
      _translate = translate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _translate > _pinnedThreshold;
    return Stack(
      key: _boxKey,
      clipBehavior: Clip.none,
      children: [
        // Badan kartu. Reserve space setinggi header di atasnya supaya di
        // keadaan diam tidak ada baris tertutup header; widget [child]
        // dipertahankan identik antar rebuild sehingga scroll tick yang
        // memicu setState tidak merender ulang baris-baris di dalamnya.
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.only(top: _headerHeight),
            child: widget.child,
          ),
        ),
        // Header digambar terakhir (di atas badan) dan digeser secara paint
        // saja — layout baris tidak berubah saat pin.
        SizedBox(
          width: double.infinity,
          child: Transform.translate(
            offset: Offset(0, _translate),
            child: KeyedSubtree(
              key: _headerKey,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: pinned
                      ? const Border(
                          bottom: BorderSide(color: AppColors.border),
                        )
                      : null,
                  boxShadow: pinned
                      ? [
                          BoxShadow(
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.04,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: widget.header,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
