import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/design_system.dart';
import 'sales_analytics_models.dart';

// ---------------------------------------------------------------------------
// Trend chart (daily revenue)
// ---------------------------------------------------------------------------

/// Area/line chart of daily revenue with a hover tooltip.
///
/// Hand-rolled with [CustomPainter] so the analytics page does not pull a
/// charting dependency into the web bundle.
class SalesTrendChart extends StatefulWidget {
  const SalesTrendChart({super.key, required this.points, this.height = 240});

  final List<SalesDayPoint> points;
  final double height;

  @override
  State<SalesTrendChart> createState() => _SalesTrendChartState();
}

class _SalesTrendChartState extends State<SalesTrendChart> {
  static const double _padLeft = 54;
  static const double _padRight = 12;

  int? _hoverIndex;

  int? _indexForDx(double dx, double width) {
    final count = widget.points.length;
    if (count == 0) return null;
    final plotWidth = width - _padLeft - _padRight;
    if (plotWidth <= 0) return null;
    final t = ((dx - _padLeft) / plotWidth).clamp(0.0, 1.0);
    if (count == 1) return 0;
    return (t * (count - 1)).round().clamp(0, count - 1);
  }

  void _updateHover(double dx, double width) {
    final index = _indexForDx(dx, width);
    if (index != _hoverIndex) setState(() => _hoverIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return MouseRegion(
          onHover: (event) => _updateHover(event.localPosition.dx, width),
          onExit: (_) {
            if (_hoverIndex != null) setState(() => _hoverIndex = null);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                _updateHover(details.localPosition.dx, width),
            onHorizontalDragUpdate: (details) =>
                _updateHover(details.localPosition.dx, width),
            child: SizedBox(
              width: width,
              height: widget.height,
              child: CustomPaint(
                painter: _TrendPainter(
                  points: widget.points,
                  hoverIndex: _hoverIndex,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.points, required this.hoverIndex});

  final List<SalesDayPoint> points;
  final int? hoverIndex;

  static const double _padLeft = 54;
  static const double _padRight = 12;
  static const double _padTop = 14;
  static const double _padBottom = 26;

  static const Color _line = AppColors.primary;
  static const Color _tooltipBg = Color(0xFF0F172A);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final plot = Rect.fromLTRB(
      _padLeft,
      _padTop,
      size.width - _padRight,
      size.height - _padBottom,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final maxRevenue = points.fold<int>(0, (m, p) => math.max(m, p.revenue));
    final niceMax = _niceCeil(maxRevenue);

    _paintTrendAxes(canvas: canvas, plot: plot, niceMax: niceMax, days: points);

    if (maxRevenue == 0) {
      final tp = _text(
        'Belum ada penjualan pada periode ini',
        AppTextStyles.bodyMuted,
      );
      tp.paint(
        canvas,
        Offset(plot.center.dx - tp.width / 2, plot.center.dy - tp.height / 2),
      );
      return;
    }

    Offset pointAt(int index) {
      final t = points.length == 1 ? 0.5 : index / (points.length - 1);
      final x = plot.left + plot.width * t;
      final y = plot.bottom - plot.height * (points[index].revenue / niceMax);
      return Offset(x, y);
    }

    // Area fill.
    final area = Path()..moveTo(plot.left, plot.bottom);
    for (var i = 0; i < points.length; i++) {
      final p = pointAt(i);
      area.lineTo(p.dx, p.dy);
    }
    area
      ..lineTo(plot.right, plot.bottom)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_line.withValues(alpha: 0.22), _line.withValues(alpha: 0.02)],
      ).createShader(plot);
    canvas.drawPath(area, areaPaint);

    // Line.
    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < points.length; i++) {
      final p = pointAt(i);
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = _line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final hover = hoverIndex;
    if (hover != null && hover >= 0 && hover < points.length) {
      _paintHover(canvas, size, plot, pointAt(hover), points[hover]);
    }
  }

  void _paintHover(
    Canvas canvas,
    Size size,
    Rect plot,
    Offset point,
    SalesDayPoint data,
  ) {
    // Dashed guide line from the point to the baseline.
    final guidePaint = Paint()
      ..color = _line.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    var y = point.dy + dash;
    while (y < plot.bottom) {
      canvas.drawLine(
        Offset(point.dx, y),
        Offset(point.dx, math.min(y + dash, plot.bottom)),
        guidePaint,
      );
      y += dash + gap;
    }

    canvas.drawCircle(point, 6, Paint()..color = AppColors.surface);
    canvas.drawCircle(
      point,
      6,
      Paint()
        ..color = _line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );

    final title = _text(
      formatDateLong(data.date),
      AppTextStyles.caption.copyWith(
        color: AppColors.onPrimarySubtle,
        fontWeight: FontWeight.w600,
      ),
    );
    final revenue = _text(
      formatRupiah(data.revenue),
      AppTextStyles.h3.copyWith(color: Colors.white),
    );
    final qty = _text(
      '${formatInt(data.qty)} unit',
      AppTextStyles.caption.copyWith(color: AppColors.onPrimaryMuted),
    );

    const padding = 10.0;
    const gapY = 3.0;
    final boxWidth =
        [title.width, revenue.width, qty.width].reduce(math.max) + padding * 2;
    final boxHeight =
        title.height + revenue.height + qty.height + gapY * 2 + padding * 2;

    var left = point.dx - boxWidth / 2;
    left = left.clamp(4.0, size.width - boxWidth - 4);
    var top = point.dy - boxHeight - 12;
    if (top < 4) top = point.dy + 14;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, boxWidth, boxHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = _tooltipBg);

    var cursorY = top + padding;
    title.paint(canvas, Offset(left + padding, cursorY));
    cursorY += title.height + gapY;
    revenue.paint(canvas, Offset(left + padding, cursorY));
    cursorY += revenue.height + gapY;
    qty.paint(canvas, Offset(left + padding, cursorY));
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.hoverIndex != hoverIndex ||
      !identical(oldDelegate.points, points);
}

const Color _trendGridColor = Color(0xFFEEF2F7);
const Color _trendTooltipBg = Color(0xFF0F172A);

/// Horizontal grid + Y labels + X date labels shared by the total and
/// per-sales trend charts.
void _paintTrendAxes({
  required Canvas canvas,
  required Rect plot,
  required double niceMax,
  required List<SalesDayPoint> days,
}) {
  final gridPaint = Paint()
    ..color = _trendGridColor
    ..strokeWidth = 1;
  const segments = 4;

  for (var i = 0; i <= segments; i++) {
    final y = plot.bottom - plot.height * (i / segments);
    canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);

    final label = formatAxisRupiah(niceMax * i / segments);
    final tp = _text(
      label,
      AppTextStyles.caption.copyWith(
        fontSize: 10.5,
        color: AppColors.textMuted,
      ),
    );
    tp.paint(canvas, Offset(plot.left - tp.width - 8, y - tp.height / 2));
  }

  final count = days.length;
  final labelCount = count <= 8 ? count : 6;
  final indices = <int>{};
  for (var i = 0; i < labelCount; i++) {
    indices.add(
      labelCount == 1
          ? 0
          : (i * (count - 1) / (labelCount - 1)).round().clamp(0, count - 1),
    );
  }

  for (final index in indices) {
    final t = count == 1 ? 0.5 : index / (count - 1);
    final x = plot.left + plot.width * t;
    final tp = _text(
      formatDateShort(days[index].date),
      AppTextStyles.caption.copyWith(
        fontSize: 10.5,
        color: AppColors.textMuted,
      ),
    );
    final left = (x - tp.width / 2).clamp(0.0, plot.right - tp.width);
    tp.paint(canvas, Offset(left, plot.bottom + 8));
  }
}

double _niceCeil(int value) {
  if (value <= 0) return 1;
  final magnitude = math
      .pow(10, (math.log(value) / math.ln10).floor())
      .toDouble();
  final normalized = value / magnitude;
  final step = normalized <= 1
      ? 1.0
      : normalized <= 2
      ? 2.0
      : normalized <= 2.5
      ? 2.5
      : normalized <= 5
      ? 5.0
      : 10.0;
  return step * magnitude;
}

TextPainter _text(String text, TextStyle style, {double? maxWidth}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: maxWidth == null ? null : '…',
  )..layout(maxWidth: maxWidth ?? double.infinity);
  return painter;
}

// ---------------------------------------------------------------------------
// Multi-series trend chart (per sales)
// ---------------------------------------------------------------------------

class SalesMultiTrendChart extends StatefulWidget {
  const SalesMultiTrendChart({
    super.key,
    required this.series,
    required this.days,
    this.height = 250,
  });

  final List<SalesTrendSeries> series;
  final List<SalesDayPoint> days;
  final double height;

  @override
  State<SalesMultiTrendChart> createState() => _SalesMultiTrendChartState();
}

class _SalesMultiTrendChartState extends State<SalesMultiTrendChart> {
  static const double _padLeft = 54;
  static const double _padRight = 12;

  int? _hoverIndex;
  final Set<int> _hidden = <int>{};
  int? _highlighted;

  int? _indexForDx(double dx, double width) {
    final count = widget.days.length;
    if (count == 0) return null;
    final plotWidth = width - _padLeft - _padRight;
    if (plotWidth <= 0) return null;
    final t = ((dx - _padLeft) / plotWidth).clamp(0.0, 1.0);
    if (count == 1) return 0;
    return (t * (count - 1)).round().clamp(0, count - 1);
  }

  void _updateHover(double dx, double width) {
    final index = _indexForDx(dx, width);
    if (index != _hoverIndex) setState(() => _hoverIndex = index);
  }

  void _toggleSeries(int index) {
    setState(() {
      if (!_hidden.remove(index)) {
        _hidden.add(index);
      }
      if (_hidden.contains(index) && _highlighted == index) {
        _highlighted = null;
      }
    });
  }

  void _setHighlighted(int? index) {
    if (_highlighted == index) return;
    setState(() => _highlighted = index);
  }

  void _showAll() {
    if (_hidden.isEmpty) return;
    setState(() => _hidden.clear());
  }

  List<int> get _visibleIndices => <int>[
    for (var i = 0; i < widget.series.length; i++)
      if (!_hidden.contains(i)) i,
  ];

  @override
  Widget build(BuildContext context) {
    final hasData = widget.series.any((series) => series.totalRevenue > 0);
    if (widget.series.isEmpty || widget.days.isEmpty || !hasData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          'Belum ada data penjualan per sales untuk periode ini.',
          style: AppTextStyles.bodyMuted,
        ),
      );
    }

    final visible = _visibleIndices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (visible.isEmpty)
          SizedBox(
            height: widget.height,
            child: Center(
              child: Text(
                'Semua garis disembunyikan.\nKlik legenda untuk menampilkan kembali.',
                style: AppTextStyles.bodyMuted,
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return MouseRegion(
                onHover: (event) => _updateHover(event.localPosition.dx, width),
                onExit: (_) {
                  if (_hoverIndex != null) setState(() => _hoverIndex = null);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      _updateHover(details.localPosition.dx, width),
                  onHorizontalDragUpdate: (details) =>
                      _updateHover(details.localPosition.dx, width),
                  child: SizedBox(
                    width: width,
                    height: widget.height,
                    child: CustomPaint(
                      painter: _MultiTrendPainter(
                        days: widget.days,
                        series: widget.series,
                        hoverIndex: _hoverIndex,
                        hidden: _hidden,
                        highlighted: _highlighted,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: AppSpacing.sm + 2),
        _MultiTrendLegend(
          series: widget.series,
          hidden: _hidden,
          highlighted: _highlighted,
          onToggle: _toggleSeries,
          onHighlight: _setHighlighted,
          onShowAll: _showAll,
        ),
      ],
    );
  }
}

class _MultiTrendLegend extends StatelessWidget {
  const _MultiTrendLegend({
    required this.series,
    required this.hidden,
    required this.highlighted,
    required this.onToggle,
    required this.onHighlight,
    required this.onShowAll,
  });

  final List<SalesTrendSeries> series;
  final Set<int> hidden;
  final int? highlighted;
  final ValueChanged<int> onToggle;
  final ValueChanged<int?> onHighlight;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < series.length; i++)
          _LegendItem(
            label: series[i].label,
            color: salesChartPalette[i % salesChartPalette.length],
            hidden: hidden.contains(i),
            highlighted: highlighted == i,
            onTap: () => onToggle(i),
            onHover: (active) => onHighlight(active ? i : null),
          ),
        if (hidden.isNotEmpty)
          TextButton(
            onPressed: onShowAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              'Tampilkan semua',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.color,
    required this.hidden,
    required this.highlighted,
    required this.onTap,
    required this.onHover,
  });

  final String label;
  final Color color;
  final bool hidden;
  final bool highlighted;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: hidden ? 'Tampilkan $label' : 'Sembunyikan $label',
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: highlighted
                  ? color.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 3,
                  decoration: BoxDecoration(
                    color: hidden
                        ? AppColors.textMuted.withValues(alpha: 0.5)
                        : color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: hidden
                          ? AppColors.textMuted
                          : (highlighted
                                ? AppColors.textPrimary
                                : AppColors.textSecondary),
                      fontWeight: highlighted
                          ? FontWeight.w600
                          : FontWeight.w400,
                      decoration: hidden ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiTrendPainter extends CustomPainter {
  _MultiTrendPainter({
    required this.days,
    required this.series,
    required this.hoverIndex,
    required this.hidden,
    required this.highlighted,
  });

  final List<SalesDayPoint> days;
  final List<SalesTrendSeries> series;
  final int? hoverIndex;
  final Set<int> hidden;
  final int? highlighted;

  static const double _padLeft = 54;
  static const double _padRight = 12;
  static const double _padTop = 14;
  static const double _padBottom = 26;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty || series.isEmpty) return;

    final plot = Rect.fromLTRB(
      _padLeft,
      _padTop,
      size.width - _padRight,
      size.height - _padBottom,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    var maxRevenue = 0;
    for (final entry in series) {
      for (final value in entry.revenueByDay) {
        maxRevenue = math.max(maxRevenue, value);
      }
    }
    final niceMax = _niceCeil(maxRevenue);

    _paintTrendAxes(canvas: canvas, plot: plot, niceMax: niceMax, days: days);

    if (maxRevenue == 0) return;

    Offset pointAt(int index, int value) {
      final t = days.length == 1 ? 0.5 : index / (days.length - 1);
      final x = plot.left + plot.width * t;
      final y = plot.bottom - plot.height * (value / niceMax);
      return Offset(x, y);
    }

    for (var s = 0; s < series.length; s++) {
      if (hidden.contains(s)) continue;
      final values = series[s].revenueByDay;
      if (values.isEmpty) continue;
      final color = salesChartPalette[s % salesChartPalette.length];
      final dimmed = highlighted != null && highlighted != s;
      final paint = Paint()
        ..color = color.withValues(alpha: dimmed ? 0.14 : 1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlighted == s ? 2.4 : 1.8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final path = Path();
      for (var i = 0; i < days.length && i < values.length; i++) {
        final p = pointAt(i, values[i]);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, paint);
    }

    final hover = hoverIndex;
    if (hover != null && hover >= 0 && hover < days.length) {
      _paintHover(canvas, size, plot, hover, pointAt);
    }
  }

  void _paintHover(
    Canvas canvas,
    Size size,
    Rect plot,
    int index,
    Offset Function(int index, int value) pointAt,
  ) {
    final entries = <({Color color, String label, int revenue})>[];
    for (var s = 0; s < series.length; s++) {
      if (hidden.contains(s)) continue;
      final values = series[s].revenueByDay;
      if (index >= values.length) continue;
      final revenue = values[index];
      if (revenue <= 0) continue;
      entries.add((
        color: salesChartPalette[s % salesChartPalette.length],
        label: series[s].label,
        revenue: revenue,
      ));
    }
    entries.sort((a, b) => b.revenue.compareTo(a.revenue));

    final t = days.length == 1 ? 0.5 : index / (days.length - 1);
    final guideX = plot.left + plot.width * t;

    final guidePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    var y = plot.top + dash;
    while (y < plot.bottom) {
      canvas.drawLine(
        Offset(guideX, y),
        Offset(guideX, math.min(y + dash, plot.bottom)),
        guidePaint,
      );
      y += dash + gap;
    }

    for (final entry in entries) {
      final p = pointAt(index, entry.revenue);
      canvas.drawCircle(p, 5, Paint()..color = AppColors.surface);
      canvas.drawCircle(p, 5, Paint()..color = entry.color);
      canvas.drawCircle(p, 2.2, Paint()..color = AppColors.surface);
    }

    final header = _text(
      formatDateLong(days[index].date),
      AppTextStyles.caption.copyWith(
        color: AppColors.onPrimarySubtle,
        fontWeight: FontWeight.w600,
      ),
    );

    const padding = 10.0;
    const rowGap = 4.0;
    const labelMaxWidth = 150.0;

    final rows = <({TextPainter label, TextPainter value, Color color})>[];
    for (final entry in entries) {
      rows.add((
        label: _text(
          entry.label,
          AppTextStyles.caption.copyWith(color: AppColors.onPrimarySubtle),
          maxWidth: labelMaxWidth,
        ),
        value: _text(
          formatRupiah(entry.revenue),
          AppTextStyles.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        color: entry.color,
      ));
    }

    final emptyMessage = rows.isEmpty
        ? _text(
            'Tidak ada penjualan',
            AppTextStyles.caption.copyWith(color: AppColors.onPrimaryMuted),
          )
        : null;

    var contentWidth = header.width;
    if (emptyMessage != null) {
      contentWidth = math.max(contentWidth, emptyMessage.width);
    }
    for (final row in rows) {
      final rowWidth = 8 + 6 + row.label.width + 12 + row.value.width;
      contentWidth = math.max(contentWidth, rowWidth);
    }

    final rowHeight = rows.isEmpty
        ? (emptyMessage?.height ?? 0)
        : rows
              .map((r) => math.max(r.label.height, r.value.height))
              .reduce(math.max);
    final rowCount = rows.isEmpty ? 1 : rows.length;
    final boxWidth = contentWidth + padding * 2;
    final boxHeight =
        header.height +
        rowCount * rowHeight +
        (rowCount - 1) * rowGap +
        padding * 2;

    var left = guideX + 14;
    if (left + boxWidth > size.width - 4) {
      left = guideX - boxWidth - 14;
    }
    left = left.clamp(4.0, math.max(4.0, size.width - boxWidth - 4));
    var top = plot.top + 4;
    if (top + boxHeight > size.height - 4) {
      top = math.max(4.0, size.height - boxHeight - 4);
    }

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, boxWidth, boxHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = _trendTooltipBg);

    header.paint(canvas, Offset(left + padding, top + padding));
    var cursorY = top + padding + header.height + 4;
    if (emptyMessage != null) {
      emptyMessage.paint(canvas, Offset(left + padding, cursorY));
      return;
    }

    for (final row in rows) {
      canvas.drawCircle(
        Offset(left + padding + 4, cursorY + rowHeight / 2),
        3.5,
        Paint()..color = row.color,
      );
      row.label.paint(canvas, Offset(left + padding + 8 + 6, cursorY));
      row.value.paint(
        canvas,
        Offset(left + boxWidth - padding - row.value.width, cursorY),
      );
      cursorY += rowHeight + rowGap;
    }
  }

  @override
  bool shouldRepaint(covariant _MultiTrendPainter oldDelegate) =>
      oldDelegate.hoverIndex != hoverIndex ||
      oldDelegate.highlighted != highlighted ||
      !setEquals(oldDelegate.hidden, hidden) ||
      !identical(oldDelegate.days, days) ||
      !identical(oldDelegate.series, series);
}

// ---------------------------------------------------------------------------
// Small-multiples trend chart (one compact panel per sales)
// ---------------------------------------------------------------------------

/// Per-sales trend as a grid of compact panels.
///
/// A single multi-line chart becomes unreadable once six sales overlap, so the
/// per-sales view uses small multiples: each panel keeps its own Y scale and
/// shows its own hover detail. The combined line chart is still available via
/// a toggle in the card footer.
class SalesSmallMultiplesChart extends StatelessWidget {
  const SalesSmallMultiplesChart({
    super.key,
    required this.series,
    required this.days,
  });

  final List<SalesTrendSeries> series;
  final List<SalesDayPoint> days;

  static const double _gap = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final hasData = series.any((entry) => entry.totalRevenue > 0);
    if (series.isEmpty || days.isEmpty || !hasData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          'Belum ada data penjualan per sales untuk periode ini.',
          style: AppTextStyles.bodyMuted,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600
            ? 3
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        final panelWidth =
            ((constraints.maxWidth - _gap * (columns - 1)) / columns)
                .floorToDouble();

        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (var i = 0; i < series.length; i++)
              SizedBox(
                width: panelWidth,
                child: _SalesTrendPanel(
                  series: series[i],
                  days: days,
                  color: salesChartPalette[i % salesChartPalette.length],
                  rank: i + 1,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SalesTrendPanel extends StatefulWidget {
  const _SalesTrendPanel({
    required this.series,
    required this.days,
    required this.color,
    required this.rank,
  });

  final SalesTrendSeries series;
  final List<SalesDayPoint> days;
  final Color color;
  final int rank;

  @override
  State<_SalesTrendPanel> createState() => _SalesTrendPanelState();
}

class _SalesTrendPanelState extends State<_SalesTrendPanel> {
  int? _hoverIndex;

  void _updateHover(double dx, double width) {
    final count = widget.days.length;
    if (count == 0) return;
    final plotWidth =
        width - _MiniTrendPainter.padLeft - _MiniTrendPainter.padRight;
    if (plotWidth <= 0) return;
    final t = ((dx - _MiniTrendPainter.padLeft) / plotWidth).clamp(0.0, 1.0);
    final index = count == 1
        ? 0
        : (t * (count - 1)).round().clamp(0, count - 1);
    if (index != _hoverIndex) setState(() => _hoverIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final revenue = widget.series.revenueByDay;
    final activeDays = revenue.where((value) => value > 0).length;
    final hovered = _hoverIndex != null && _hoverIndex! < revenue.length
        ? _hoverIndex
        : null;
    final caption = hovered == null
        ? '$activeDays hari aktif'
        : '${formatDateShort(widget.days[hovered].date)} · '
              '${formatCompactRupiah(revenue[hovered])}';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted.withValues(alpha: 0.45),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Tooltip(
                  message: widget.series.label,
                  waitDuration: const Duration(milliseconds: 400),
                  child: Text(
                    '${widget.rank}. ${widget.series.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                formatCompactRupiah(widget.series.totalRevenue),
                style: AppTextStyles.h3.copyWith(fontSize: 13),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.caption.copyWith(
                    color: hovered == null
                        ? AppColors.textMuted
                        : AppColors.primary,
                    fontWeight: hovered == null
                        ? FontWeight.w500
                        : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 58,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return MouseRegion(
                  onHover: (event) =>
                      _updateHover(event.localPosition.dx, width),
                  onExit: (_) {
                    if (_hoverIndex != null) {
                      setState(() => _hoverIndex = null);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) =>
                        _updateHover(details.localPosition.dx, width),
                    onHorizontalDragUpdate: (details) =>
                        _updateHover(details.localPosition.dx, width),
                    child: CustomPaint(
                      painter: _MiniTrendPainter(
                        values: revenue,
                        days: widget.days,
                        color: widget.color,
                        hoverIndex: hovered,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTrendPainter extends CustomPainter {
  _MiniTrendPainter({
    required this.values,
    required this.days,
    required this.color,
    required this.hoverIndex,
  });

  final List<int> values;
  final List<SalesDayPoint> days;
  final Color color;
  final int? hoverIndex;

  static const double padLeft = 34;
  static const double padRight = 4;
  static const double padTop = 4;
  static const double padBottom = 14;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || days.isEmpty) return;

    final plot = Rect.fromLTRB(
      padLeft,
      padTop,
      size.width - padRight,
      size.height - padBottom,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final maxValue = values.fold<int>(0, math.max);
    final niceMax = _niceCeil(maxValue);

    final gridPaint = Paint()
      ..color = _trendGridColor
      ..strokeWidth = 1;
    for (final fraction in <double>[0, 0.5, 1]) {
      final y = plot.bottom - plot.height * fraction;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }

    final axisStyle = AppTextStyles.caption.copyWith(
      fontSize: 9.5,
      color: AppColors.textMuted,
    );
    final topLabel = _text(formatAxisRupiah(niceMax), axisStyle);
    topLabel.paint(
      canvas,
      Offset(plot.left - topLabel.width - 4, plot.top - 1),
    );
    final zeroLabel = _text('0', axisStyle);
    zeroLabel.paint(
      canvas,
      Offset(plot.left - zeroLabel.width - 4, plot.bottom - 11),
    );

    final count = days.length;
    final labelIndices = count == 1
        ? <int>{0}
        : <int>{0, (count - 1) ~/ 2, count - 1};
    for (final index in labelIndices) {
      final t = count == 1 ? 0.5 : index / (count - 1);
      final x = plot.left + plot.width * t;
      final tp = _text(formatDateShort(days[index].date), axisStyle);
      final left = (x - tp.width / 2).clamp(0.0, plot.right - tp.width);
      tp.paint(canvas, Offset(left, plot.bottom + 2));
    }

    if (maxValue <= 0) return;

    Offset pointAt(int index) {
      final t = count == 1 ? 0.5 : index / (count - 1);
      final x = plot.left + plot.width * t;
      final y =
          plot.bottom -
          plot.height * (values[index].clamp(0, niceMax) / niceMax);
      return Offset(x, y);
    }

    final area = Path()..moveTo(plot.left, plot.bottom);
    for (var i = 0; i < values.length && i < count; i++) {
      final point = pointAt(i);
      area.lineTo(point.dx, point.dy);
    }
    area
      ..lineTo(plot.right, plot.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.01),
          ],
        ).createShader(plot),
    );

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < values.length && i < count; i++) {
      final point = pointAt(i);
      line.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final hover = hoverIndex;
    if (hover != null && hover >= 0 && hover < values.length && hover < count) {
      final point = pointAt(hover);
      canvas.drawLine(
        Offset(point.dx, plot.top),
        Offset(point.dx, plot.bottom),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(point, 3.6, Paint()..color = AppColors.surface);
      canvas.drawCircle(
        point,
        3.6,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniTrendPainter oldDelegate) =>
      oldDelegate.hoverIndex != hoverIndex ||
      oldDelegate.color != color ||
      !identical(oldDelegate.values, values) ||
      !identical(oldDelegate.days, days);
}

// ---------------------------------------------------------------------------
// Donut chart (channel composition)
// ---------------------------------------------------------------------------

class SalesDonutSlice {
  const SalesDonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class SalesDonutChart extends StatelessWidget {
  const SalesDonutChart({
    super.key,
    required this.slices,
    this.size = 168,
    this.centerCaption = 'Omzet',
  });

  final List<SalesDonutSlice> slices;
  final double size;
  final String centerCaption;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.value);
    final compact = size < 160;

    final chart = SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _DonutPainter(slices: slices)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatCompactRupiah(total),
                  style: AppTextStyles.h2.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(centerCaption, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );

    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < slices.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _DonutLegendRow(slice: slices[i], total: total),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (compact || constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: chart),
              const SizedBox(height: AppSpacing.md),
              legend,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            chart,
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _DonutLegendRow extends StatelessWidget {
  const _DonutLegendRow({required this.slice, required this.total});

  final SalesDonutSlice slice;
  final int total;

  @override
  Widget build(BuildContext context) {
    final share = total <= 0 ? 0.0 : slice.value / total;
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                slice.label,
                style: AppTextStyles.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                formatCompactRupiah(slice.value),
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          formatPercent(share),
          style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices});

  final List<SalesDonutSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.value);
    final strokeWidth = size.shortestSide * 0.16;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );

    canvas.drawCircle(
      rect.center,
      radius,
      Paint()
        ..color = AppColors.surfaceMuted
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (total <= 0) return;

    final gap = slices.length > 1 ? 0.04 : 0.0;
    var start = -math.pi / 2;

    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final fraction = slice.value / total;
      final sweep = math.max(fraction * math.pi * 2 - gap, 0.004);
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
      start += fraction * math.pi * 2;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      !identical(oldDelegate.slices, slices);
}

// ---------------------------------------------------------------------------
// Sales participation chart
// ---------------------------------------------------------------------------

class SalesPieSlice {
  const SalesPieSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class SalesParticipationChart extends StatelessWidget {
  const SalesParticipationChart({
    super.key,
    required this.items,
    this.emptyMessage = 'Belum ada data sales untuk periode ini.',
  });

  final List<SalesRankItem> items;
  final String emptyMessage;

  List<SalesPieSlice> _buildSlices() {
    final ranked = items.toList()
      ..sort((a, b) {
        final byAmount = b.revenue.abs().compareTo(a.revenue.abs());
        return byAmount != 0
            ? byAmount
            : a.displayLabel.compareTo(b.displayLabel);
      });
    return [
      for (final (index, item) in ranked.indexed)
        SalesPieSlice(
          label: item.displayLabel,
          value: item.revenue,
          color: salesChartPalette[index % salesChartPalette.length],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(emptyMessage, style: AppTextStyles.bodyMuted),
      );
    }

    final slices = _buildSlices();
    final totalRevenue = slices.fold<int>(
      0,
      (total, slice) => total + slice.value.abs(),
    );
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < slices.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _SalesPieLegendRow(slice: slices[i], total: totalRevenue),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 420) {
              return Column(
                children: [
                  _SalesPie(slices: slices, size: 172),
                  const SizedBox(height: AppSpacing.md),
                  legend,
                ],
              );
            }
            return Row(
              children: [
                _SalesPie(slices: slices, size: 150),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: legend),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SalesPie extends StatelessWidget {
  const _SalesPie({required this.slices, required this.size});

  final List<SalesPieSlice> slices;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _SalesPiePainter(slices: slices)),
  );
}

class _SalesPieLegendRow extends StatelessWidget {
  const _SalesPieLegendRow({required this.slice, required this.total});

  final SalesPieSlice slice;
  final int total;

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : slice.value.abs() / total;
    return Semantics(
      label: '${slice.label}, ${formatPercentPrecise(share)}',
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              slice.label,
              style: AppTextStyles.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            formatPercentPrecise(share),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesPiePainter extends CustomPainter {
  _SalesPiePainter({required this.slices});

  final List<SalesPieSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.value.abs());
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gap = slices.length > 1 ? 0.025 : 0.0;
    var start = -math.pi / 2;

    for (final slice in slices) {
      final magnitude = slice.value.abs();
      if (magnitude == 0) continue;
      final fraction = magnitude / total;
      final sweep = math.max(fraction * math.pi * 2 - gap, 0.004);
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()
          ..color = slice.color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      start += fraction * math.pi * 2;
    }
  }

  @override
  bool shouldRepaint(covariant _SalesPiePainter oldDelegate) =>
      !identical(oldDelegate.slices, slices);
}

// ---------------------------------------------------------------------------
// Ranking list (products / sales / customers)
// ---------------------------------------------------------------------------

String _targetPercentLabel(double progress) => formatPercentPrecise(progress);

class SalesRankingList extends StatelessWidget {
  const SalesRankingList({
    super.key,
    required this.entries,
    this.maxItems = 10,
    this.emptyMessage = 'Belum ada data untuk periode ini.',
  });

  final List<SalesRankingEntry> entries;
  final int maxItems;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(emptyMessage, style: AppTextStyles.bodyMuted),
      );
    }

    final displayed = entries.toList()
      ..sort((a, b) {
        final byValue = (b.sortValue ?? b.value).compareTo(
          a.sortValue ?? a.value,
        );
        return byValue != 0 ? byValue : a.label.compareTo(b.label);
      });
    final rows = displayed.take(maxItems).toList(growable: false);
    final maxValue = rows.fold<int>(
      0,
      (maximum, entry) => math.max(maximum, entry.value.abs()),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          _SalesRankingRow(rank: i + 1, entry: rows[i], maxValue: maxValue),
        ],
      ],
    );
  }
}

class _SalesRankingRow extends StatelessWidget {
  const _SalesRankingRow({
    required this.rank,
    required this.entry,
    required this.maxValue,
  });

  final int rank;
  final SalesRankingEntry entry;
  final int maxValue;

  Color _targetBarColor(double progress) {
    if (progress < 0.8) return AppColors.danger;
    if (progress < 1) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue <= 0 ? 0.0 : entry.value.abs() / maxValue;
    final isTop = rank <= 3;
    final targetProgress =
        entry.target == null || entry.target! <= 0 || entry.targetActual == null
        ? null
        : entry.targetActual! / entry.target!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isTop ? AppColors.primarySoft : AppColors.surfaceMuted,
            borderRadius: AppRadius.sm,
          ),
          child: Text(
            '$rank',
            style: AppTextStyles.caption.copyWith(
              color: isTop ? AppColors.primary : AppColors.textSubtle,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.label,
                      style: AppTextStyles.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    formatRupiah(entry.value),
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: AppRadius.sm,
                child: Stack(
                  children: [
                    const SizedBox(
                      height: 5,
                      width: double.infinity,
                      child: ColoredBox(color: AppColors.surfaceMuted),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction.clamp(0.0, 1.0),
                      child: const SizedBox(
                        height: 5,
                        child: ColoredBox(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.showTarget) ...[
                const SizedBox(height: AppSpacing.sm),
                if (entry.target == null)
                  Text(
                    'Target belum di-set',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else if (entry.target! <= 0)
                  Text(
                    'Target Rp 0 · progres tidak dapat dihitung',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else if (targetProgress == null)
                  Text(
                    'Progres tidak dapat dihitung',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else ...[
                  Semantics(
                    label: 'Progress target omzet',
                    value: _targetPercentLabel(targetProgress),
                    container: true,
                    excludeSemantics: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Stack(
                        children: [
                          const SizedBox(
                            height: 3,
                            width: double.infinity,
                            child: ColoredBox(color: AppColors.surfaceMuted),
                          ),
                          FractionallySizedBox(
                            widthFactor: targetProgress.clamp(0.0, 1.0),
                            child: SizedBox(
                              height: 3,
                              child: ColoredBox(
                                color: _targetBarColor(targetProgress),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: targetProgress >= 1
                              ? AppColors.successSoft
                              : targetProgress >= 0.8
                              ? AppColors.warningSoft
                              : AppColors.dangerSoft,
                          borderRadius: AppRadius.sm,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 3,
                          ),
                          child: Text(
                            _targetPercentLabel(targetProgress),
                            style: AppTextStyles.caption.copyWith(
                              color: targetProgress >= 1
                                  ? AppColors.successText
                                  : targetProgress >= 0.8
                                  ? AppColors.warningText
                                  : AppColors.dangerText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'dari target · ${formatRupiah(entry.targetActual!)} / '
                          '${formatRupiah(entry.target!)}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 4),
              if (entry.detail != null || entry.trailingDetail != null)
                Row(
                  children: [
                    if (entry.detail != null)
                      Expanded(
                        child: Text(
                          entry.detail!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                    if (entry.trailingDetail != null)
                      Text(
                        entry.trailingDetail!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
