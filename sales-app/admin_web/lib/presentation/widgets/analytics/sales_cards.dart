import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design_system.dart';
import 'sales_analytics_models.dart';

// ---------------------------------------------------------------------------
// Hero: month revenue + sparkline + supporting metrics
// ---------------------------------------------------------------------------

class SalesHeroCard extends StatelessWidget {
  const SalesHeroCard({super.key, required this.analytics, this.comparison});

  final SalesAnalytics analytics;
  final SalesComparison? comparison;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = analytics.days.length;
    final avgPerActiveDay = analytics.activeDays == 0
        ? 0
        : analytics.totalRevenue ~/ analytics.activeDays;
    final targetAchievement = analytics.supplierTargetAchievement;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(
              Icons.insights_outlined,
              size: 14,
              color: AppColors.onPrimaryMuted,
            ),
            const SizedBox(width: 6),
            Text(
              analytics.rangeMonths == 1
                  ? 'OMZET ${formatMonthLong(analytics.month).toUpperCase()}'
                  : 'OMZET ${analytics.rangeMonths} BULAN S.D. '
                        '${formatMonthLong(analytics.month).toUpperCase()}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onPrimaryMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatRupiah(analytics.totalRevenue),
            style: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Target global · ${formatRupiah(analytics.totalSupplierTarget)}',
          style: AppTextStyles.body.copyWith(color: AppColors.onPrimarySubtle),
        ),
        const SizedBox(height: 2),
        Text(
          targetAchievement == null
              ? 'Target supplier belum diatur'
              : 'Pencapaian target · ${formatPercentPrecise(targetAchievement)}',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.onPrimaryMuted,
          ),
        ),
        if (comparison != null && comparison!.hasBaseline) ...[
          const SizedBox(height: 10),
          _ComparisonBlock(analytics: analytics, comparison: comparison!),
        ],
      ],
    );

    final peak = analytics.peakDay;
    final sparkline = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 74,
          child: CustomPaint(
            painter: _SparklinePainter(
              values: analytics.days.map((day) => day.revenue).toList(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          peak != null && peak.revenue > 0
              ? 'Puncak ${formatDateShort(peak.date)} · '
                    '${formatCompactRupiah(peak.revenue)}'
              : 'Belum ada transaksi harian',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.onPrimaryMuted,
          ),
        ),
      ],
    );

    final metrics = <Widget>[
      _HeroMetric(
        label: 'Active Outlet',
        value: formatInt(analytics.activeOutlets),
      ),
      _HeroMetric(
        label: 'Effective Call',
        value: formatInt(analytics.effectiveCalls),
      ),
      _HeroMetric(
        label: 'Hari aktif',
        value: '${analytics.activeDays}/$daysInMonth',
      ),
      _HeroMetric(
        label: 'Rata-rata / hari aktif',
        value: formatCompactRupiah(avgPerActiveDay),
      ),
      _HeroMetric(
        label: 'Total margin',
        value: formatRupiah(analytics.totalMargin),
      ),
      _HeroMetric(
        label: 'Margin / omzet',
        value: formatPercent(analytics.marginPercent),
      ),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: AppRadius.xl,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
      ),
      child: Stack(
        children: [
          Positioned(right: -70, top: -90, child: _glow(200, 0.05)),
          Positioned(right: 130, bottom: -80, child: _glow(150, 0.04)),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 700;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: heading),
                          const SizedBox(width: AppSpacing.xl),
                          SizedBox(width: 250, child: sparkline),
                        ],
                      )
                    else ...[
                      heading,
                      const SizedBox(height: AppSpacing.md),
                      sparkline,
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.xl,
                      runSpacing: AppSpacing.md,
                      children: metrics,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.onPrimaryMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTextStyles.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Blok pembanding: rata-rata omzet N bulan sebelumnya + persentase bulan
/// ini menuju rata-rata itu. Angka ditampilkan penuh (tanpa disingkat ke M/jt).
class _ComparisonBlock extends StatelessWidget {
  const _ComparisonBlock({required this.analytics, required this.comparison});

  final SalesAnalytics analytics;
  final SalesComparison comparison;

  String _chipLabel(int months) {
    switch (months) {
      case 1:
        return 'Bulan lalu';
      case 3:
        return '3 bulan';
      case 6:
        return '6 bulan';
      case 12:
        return '12 bulan';
      default:
        return '$months bulan';
    }
  }

  String _monthRange() {
    if (comparison.monthly.isEmpty) return '';
    final first = comparison.monthly.first.month;
    final last = comparison.monthly.last.month;
    if (first == last) return first;
    return '$first – $last';
  }

  @override
  Widget build(BuildContext context) {
    final now = analytics.totalRevenue;
    final baseline = comparison.averageRevenue;
    final pct = baseline <= 0 ? 0.0 : now / baseline;
    final pctText = formatPercent(pct);
    final above = pct >= 1.0;

    final labelText =
        'Rata-rata ${_chipLabel(comparison.months)} (${_monthRange()})';
    final countText = comparison.monthsWithData < comparison.months
        ? ' (${comparison.monthsWithData}/${comparison.months} bulan berdata)'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$labelText$countText',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.onPrimaryMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              pctText,
              style: AppTextStyles.caption.copyWith(
                color: above ? Colors.greenAccent : AppColors.onPrimaryMuted,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.clamp(0, double.infinity);
            final fill = pct.clamp(0.0, 1.0) * width;
            return Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                if (fill > 0)
                  Container(
                    height: 6,
                    width: fill,
                    decoration: BoxDecoration(
                      color: above ? Colors.greenAccent : Colors.amberAccent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          formatRupiah(baseline),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.onPrimarySubtle,
            fontSize: 10,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values});

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;

    final maxValue = values.fold<int>(0, math.max);
    if (maxValue <= 0) return;

    const topPad = 6.0;
    final height = size.height - topPad;
    final count = values.length;

    Offset pointAt(int index) {
      final t = count == 1 ? 0.5 : index / (count - 1);
      final x = size.width * t;
      final y = topPad + height * (1 - values[index] / maxValue);
      return Offset(x, y);
    }

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < count; i++) {
      final p = pointAt(i);
      line.lineTo(p.dx, p.dy);
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final peakIndex = values.indexOf(maxValue);
    final peak = pointAt(peakIndex);
    canvas.drawCircle(peak, 3.2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      !identical(oldDelegate.values, values);
}

// ---------------------------------------------------------------------------
// Insight cards
// ---------------------------------------------------------------------------

enum SalesInsightTone { info, success, warning }

class SalesInsight {
  const SalesInsight({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String message;
  final SalesInsightTone tone;
}

/// Rule-based insights derived from the summary. No extra network calls: every
/// number here already arrived with the summary payload.
List<SalesInsight> buildSalesInsights(SalesAnalytics analytics) {
  final insights = <SalesInsight>[];

  final topProduct = analytics.topProduct;
  if (topProduct != null && analytics.totalRevenue > 0) {
    insights.add(
      SalesInsight(
        icon: Icons.inventory_2_outlined,
        title: 'Produk unggulan',
        message:
            '${topProduct.displayLabel} menyumbang '
            '${formatPercent(analytics.topProductShare)} omzet '
            '(${formatCompactRupiah(topProduct.revenue)}).',
        tone: SalesInsightTone.info,
      ),
    );
  }

  final peak = analytics.peakDay;
  if (peak != null && peak.revenue > 0) {
    final average = analytics.activeDays == 0
        ? 0.0
        : analytics.totalRevenue / analytics.activeDays;
    final ratio = average <= 0 ? 0.0 : peak.revenue / average;
    insights.add(
      SalesInsight(
        icon: Icons.bolt_outlined,
        title: 'Hari puncak',
        message:
            '${formatDateLong(peak.date)} mencatat '
            '${formatCompactRupiah(peak.revenue)} '
            '(${ratio.toStringAsFixed(1).replaceAll('.', ',')}x rata-rata harian).',
        tone: SalesInsightTone.success,
      ),
    );
  }

  final topDivisi = analytics.topDivisi;
  final topChannel = analytics.topChannel;
  if (topDivisi != null) {
    insights.add(
      SalesInsight(
        icon: Icons.hub_outlined,
        title: 'Divisi dominan',
        message:
            '${topDivisi.displayLabel} menyumbang '
            '${formatPercent(analytics.totalRevenue == 0 ? 0 : topDivisi.revenue / analytics.totalRevenue)} '
            'omzet pada periode ini.',
        tone: SalesInsightTone.info,
      ),
    );
  } else if (topChannel != null && analytics.topChannelShare > 0) {
    insights.add(
      SalesInsight(
        icon: Icons.hub_outlined,
        title: 'Kanal dominan',
        message:
            '${topChannel.displayLabel} menguasai '
            '${formatPercent(analytics.topChannelShare)} omzet pada periode ini.',
        tone: SalesInsightTone.info,
      ),
    );
  }

  if (analytics.days.length >= 14) {
    final recent = analytics.days.sublist(analytics.days.length - 7);
    final previous = analytics.days.sublist(
      analytics.days.length - 14,
      analytics.days.length - 7,
    );
    final recentSum = recent.fold<int>(0, (sum, day) => sum + day.revenue);
    final previousSum = previous.fold<int>(0, (sum, day) => sum + day.revenue);

    if (previousSum > 0) {
      final delta = (recentSum - previousSum) / previousSum;
      insights.add(
        SalesInsight(
          icon: delta >= 0 ? Icons.trending_up : Icons.trending_down,
          title: 'Momentum 7 hari',
          message:
              'Omzet 7 hari terakhir ${formatCompactRupiah(recentSum)}, '
              '${delta >= 0 ? 'naik' : 'turun'} '
              '${formatPercent(delta.abs())} dibanding 7 hari sebelumnya.',
          tone: delta >= 0
              ? SalesInsightTone.success
              : SalesInsightTone.warning,
        ),
      );
    }
  }

  if (insights.isEmpty) {
    insights.add(
      const SalesInsight(
        icon: Icons.info_outline,
        title: 'Belum ada insight',
        message: 'Import laporan penjualan untuk melihat analisis otomatis.',
        tone: SalesInsightTone.info,
      ),
    );
  }

  return insights;
}

class SalesInsightCard extends StatelessWidget {
  const SalesInsightCard({super.key, required this.insight});

  final SalesInsight insight;

  ({Color bg, Color border, Color fg}) get _tone {
    switch (insight.tone) {
      case SalesInsightTone.success:
        return (
          bg: AppColors.successSoft,
          border: AppColors.successBorder,
          fg: AppColors.successText,
        );
      case SalesInsightTone.warning:
        return (
          bg: AppColors.warningSoft,
          border: AppColors.warningBorder,
          fg: AppColors.warningText,
        );
      case SalesInsightTone.info:
        return (
          bg: AppColors.infoSoft,
          border: AppColors.infoBorder,
          fg: AppColors.infoText,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: AppRadius.lg,
        border: Border.all(color: tone.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tone.fg.withValues(alpha: 0.12),
              borderRadius: AppRadius.md,
            ),
            child: Icon(insight.icon, size: 18, color: tone.fg),
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  insight.title,
                  style: AppTextStyles.h3.copyWith(color: tone.fg),
                ),
                const SizedBox(height: 3),
                Text(
                  insight.message,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state + import result banner
// ---------------------------------------------------------------------------

class SalesEmptyStateCard extends StatelessWidget {
  const SalesEmptyStateCard({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.analytics_outlined,
              size: 30,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTextStyles.h2, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              message,
              style: AppTextStyles.bodyMuted.copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

class SalesImportBanner extends StatelessWidget {
  const SalesImportBanner({
    super.key,
    required this.result,
    required this.onDismiss,
  });

  final Map<String, dynamic> result;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final success = result['success'] == true;
    final total = _toInt(result['total_rows']);
    final inserted = _toInt(result['inserted']);
    final updated = _toInt(result['updated']);
    final skipped = _toInt(result['skipped']);
    final deleted = _toInt(result['deleted']);
    final missingMotherSku = _toInt(result['missing_mother_sku']);
    final unmatchedSuppliers = result['unmatched_suppliers'];
    final errors = result['errors'];
    final firstError = errors is List && errors.isNotEmpty
        ? Map<String, dynamic>.from(errors.first as Map)
        : null;

    final fg = success ? AppColors.successText : AppColors.dangerText;
    final bg = success ? AppColors.successSoft : AppColors.errorBg;
    final border = success ? AppColors.successBorder : AppColors.errorBorder;

    final isDelete = result.containsKey('deleted');
    final message = success
        ? isDelete
              ? 'Penghapusan selesai: $deleted baris dihapus.'
              : 'Import selesai: $total baris diproses · $inserted baru · '
                    '$updated diperbarui · $skipped dilewati.'
        : 'Import tidak selesai. '
              '${firstError != null ? 'Baris ${firstError['row']}: ${firstError['reason']}' : 'Periksa kembali format file.'}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.lg,
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.error_outline,
            size: 20,
            color: fg,
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: AppTextStyles.body.copyWith(color: fg)),
                if (success && !isDelete && missingMotherSku > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Peringatan: $missingMotherSku baris tidak memiliki Mother SKU; produk memakai Kode Item.',
                    style: AppTextStyles.caption.copyWith(color: fg),
                  ),
                ],
                if (success &&
                    unmatchedSuppliers is List &&
                    unmatchedSuppliers.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Supplier retur tidak ditemukan pada data penjualan: '
                    '${unmatchedSuppliers.join(', ')}',
                    style: AppTextStyles.caption.copyWith(color: fg),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: fg,
            tooltip: 'Tutup notifikasi',
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
