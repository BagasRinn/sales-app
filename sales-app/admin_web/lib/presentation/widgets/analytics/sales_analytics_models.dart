import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Categorical palette for charts. Kept local to the analytics widgets so the
/// rest of the admin design system stays navy/slate only.
/// Ordered so that adjacent entries are far apart on the hue wheel; multi-line
/// charts stay readable even when 8–10 series are drawn at once.
const List<Color> salesChartPalette = <Color>[
  Color(0xFF183558), // navy
  Color(0xFFF59E0B), // amber
  Color(0xFF10B981), // emerald
  Color(0xFF8B5CF6), // violet
  Color(0xFF0EA5E9), // sky
  Color(0xFFEF4444), // red
  Color(0xFF14B8A6), // teal
  Color(0xFFEC4899), // pink
  Color(0xFF65A30D), // lime
  Color(0xFF64748B), // slate
];

class SalesRankItem {
  final String code;
  final String label;
  final int qty;
  final int revenue;
  final int margin;
  final String? motherSku;
  final String? productKode;

  const SalesRankItem({
    required this.code,
    required this.label,
    required this.qty,
    required this.revenue,
    this.margin = 0,
    this.motherSku,
    this.productKode,
  });

  String get displayLabel {
    if (label.trim().isNotEmpty) return label.trim();
    if (code.trim().isNotEmpty) return code.trim();
    return 'Tidak diketahui';
  }

  String get targetKey =>
      normalizeSalesTargetName(label.trim().isNotEmpty ? label : code);
}

class SalesRankingEntry {
  const SalesRankingEntry({
    required this.label,
    required this.value,
    this.sortValue,
    this.detail,
    this.trailingDetail,
    this.showTarget = false,
    this.target,
    this.targetActual,
  });

  final String label;
  final int value;
  final int? sortValue;
  final String? detail;
  final String? trailingDetail;
  final bool showTarget;
  final int? target;
  final int? targetActual;
}

class SupplierReturnRankItem {
  final String supplier;
  final int revenue;
  final int margin;
  final int rowCount;
  final int supplierNetRevenue;

  const SupplierReturnRankItem({
    required this.supplier,
    required this.revenue,
    required this.margin,
    required this.rowCount,
    required this.supplierNetRevenue,
  });

  String get displayLabel =>
      supplier.trim().isEmpty ? 'Tidak diketahui' : supplier.trim();
}

String normalizeSalesTargetName(String value) => value
    .toUpperCase()
    .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

class SalesDayPoint {
  final DateTime date;
  final int revenue;
  final int qty;

  const SalesDayPoint({
    required this.date,
    required this.revenue,
    required this.qty,
  });
}

/// One line on the "Per Sales" trend chart. [revenueByDay] is aligned with
/// [SalesAnalytics.days] (same index = same date) and zero-filled.
class SalesTrendSeries {
  final String key;
  final String label;
  final int totalRevenue;
  final List<int> revenueByDay;

  const SalesTrendSeries({
    required this.key,
    required this.label,
    required this.totalRevenue,
    required this.revenueByDay,
  });
}

/// Everything the analytics screen derives from one summary payload.
class SalesAnalytics {
  final DateTime month;
  final DateTime? updatedAt;
  final int totalRevenue;
  final int totalQty;
  final int totalMargin;
  final int totalReturRevenue;
  final int totalReturMargin;
  final int returRows;
  final int totalRows;
  final int rangeMonths;
  final List<SalesRankItem> products;
  final List<SalesRankItem> sales;
  final List<SalesRankItem> customers;
  final List<SalesRankItem> channels;
  final List<SalesRankItem> divisi;
  final List<SalesRankItem> suppliers;
  final List<SupplierReturnRankItem> supplierRetur;
  final Map<String, int> salesTargets;
  final Map<String, int> supplierTargets;

  /// One point per calendar day in [month]; days without sales are zero-filled
  /// so the trend line keeps an even time axis.
  final List<SalesDayPoint> days;

  /// Daily revenue for the top sales people, aligned with [days]. Empty when
  /// the payload did not include `sales_day`.
  final List<SalesTrendSeries> salesSeries;

  const SalesAnalytics({
    required this.month,
    required this.updatedAt,
    required this.totalRevenue,
    required this.totalQty,
    required this.totalMargin,
    required this.totalReturRevenue,
    required this.totalReturMargin,
    required this.returRows,
    required this.totalRows,
    required this.rangeMonths,
    required this.products,
    required this.sales,
    required this.customers,
    required this.channels,
    required this.divisi,
    required this.suppliers,
    required this.supplierRetur,
    required this.salesTargets,
    required this.supplierTargets,
    required this.days,
    required this.salesSeries,
  });

  factory SalesAnalytics.fromSummary(
    Map<String, dynamic> summary,
    DateTime month,
  ) {
    final normalizedMonth = DateTime(month.year, month.month);
    final rangeMonths = _toInt(summary['range_months']).clamp(1, 12).toInt();
    final days = _fillDays(normalizedMonth, rangeMonths, summary['by_day']);

    return SalesAnalytics(
      month: normalizedMonth,
      updatedAt: _parseDateTime(summary['updated_at']),
      totalRevenue: _toInt(summary['total_revenue']),
      totalQty: _toInt(summary['total_qty']),
      totalMargin: _toInt(summary['total_margin']),
      totalReturRevenue: _toInt(summary['total_retur_revenue']),
      totalReturMargin: _toInt(summary['total_retur_margin']),
      returRows: _toInt(summary['total_retur_rows']),
      totalRows: _toInt(summary['imported_rows']),
      rangeMonths: rangeMonths,
      products: _rankList(
        summary['by_product'],
        'product_kode',
        'product_nama',
        product: true,
      ),
      sales: _rankList(summary['by_sales'], 'sales_kode', 'sales_nama'),
      customers: _rankList(
        summary['by_customer'],
        'customer_kode',
        'customer_nama',
      ),
      channels: _rankList(summary['by_channel'], 'channel', null),
      divisi: _rankList(summary['by_divisi'], 'divisi', null),
      suppliers: _rankList(summary['by_supplier'], 'supplier', null),
      supplierRetur: _supplierReturnList(summary['by_supplier_retur']),
      salesTargets: _targetMap(summary['sales_targets']),
      supplierTargets: _targetMap(summary['supplier_targets']),
      days: days,
      salesSeries: _salesSeries(summary['by_sales_day'], days),
    );
  }

  bool get isEmpty => totalRevenue == 0 && totalRows == 0 && returRows == 0;

  double get avgRevenuePerRow => totalRows == 0 ? 0 : totalRevenue / totalRows;

  double get avgQtyPerRow => totalRows == 0 ? 0 : totalQty / totalRows;

  double get marginPercent =>
      totalRevenue == 0 ? 0 : totalMargin / totalRevenue;

  int get totalSupplierTarget =>
      supplierTargets.values.fold(0, (total, target) => total + target);

  double? get supplierTargetAchievement =>
      totalSupplierTarget <= 0 ? null : totalRevenue / totalSupplierTarget;

  double get avgPricePerUnit => totalQty == 0 ? 0 : totalRevenue / totalQty;

  int get activeDays => days.where((day) => day.revenue > 0).length;

  SalesDayPoint? get peakDay {
    SalesDayPoint? peak;
    for (final day in days) {
      if (peak == null || day.revenue > peak.revenue) peak = day;
    }
    return peak;
  }

  SalesRankItem? get topProduct => products.isEmpty ? null : products.first;

  SalesRankItem? get topChannel => channels.isEmpty ? null : channels.first;

  SalesRankItem? get topDivisi => divisi.isEmpty ? null : divisi.first;

  double get topProductShare => _share(topProduct?.revenue ?? 0, totalRevenue);

  double get topChannelShare => _share(topChannel?.revenue ?? 0, totalRevenue);

  int get topFiveProductRevenue =>
      products.take(5).fold(0, (sum, item) => sum + item.revenue);

  double get topFiveProductShare => _share(topFiveProductRevenue, totalRevenue);

  int get topFiveCustomerRevenue =>
      customers.take(5).fold(0, (sum, item) => sum + item.revenue);

  double get topFiveCustomerShare =>
      _share(topFiveCustomerRevenue, totalRevenue);

  /// Revenue not covered by the returned top-N channel rows. Rendered as
  /// "Lainnya" so the donut always adds up to the month total.
  int get otherChannelRevenue {
    final covered = channels.fold(0, (sum, item) => sum + item.revenue);
    final rest = totalRevenue - covered;
    return rest > 0 ? rest : 0;
  }

  int get productCount => products.length;

  static double _share(int value, int total) =>
      total <= 0 ? 0 : (value / total).clamp(0, 1).toDouble();

  static List<SalesRankItem> _rankList(
    dynamic raw,
    String codeKey,
    String? labelKey, {
    bool product = false,
  }) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (row) => SalesRankItem(
            code: row[codeKey]?.toString().trim() ?? '',
            label: labelKey == null
                ? ''
                : row[labelKey]?.toString().trim() ?? '',
            qty: _toInt(row['qty']),
            revenue: _toInt(row['revenue']),
            margin: _toInt(row['margin']),
            motherSku: product ? row['mother_sku']?.toString() : null,
            productKode: product ? row['product_kode']?.toString() : null,
          ),
        )
        .toList(growable: false);
  }

  static List<SupplierReturnRankItem> _supplierReturnList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) {
          return SupplierReturnRankItem(
            supplier: row['supplier']?.toString().trim() ?? '',
            revenue: _toInt(row['revenue']),
            margin: _toInt(row['margin']),
            rowCount: _toInt(row['row_count']),
            supplierNetRevenue: _toInt(row['supplier_net_revenue']),
          );
        })
        .toList(growable: false);
  }

  static Map<String, int> _targetMap(dynamic raw) {
    if (raw is! List) return const {};
    final targets = <String, int>{};
    for (final entry in raw.whereType<Map>()) {
      final name =
          entry['name_key']?.toString() ??
          normalizeSalesTargetName(entry['name']?.toString() ?? '');
      if (name.isEmpty) continue;
      targets[name] = _toInt(entry['value']);
    }
    return Map.unmodifiable(targets);
  }

  static List<SalesDayPoint> _fillDays(
    DateTime month,
    int rangeMonths,
    dynamic raw,
  ) {
    final byDate = <String, SalesDayPoint>{};
    if (raw is List) {
      for (final entry in raw.whereType<Map>()) {
        final parsed = _parseDateTime(entry['date']);
        if (parsed == null) continue;
        final day = DateTime(parsed.year, parsed.month, parsed.day);
        byDate[_dayKey(day)] = SalesDayPoint(
          date: day,
          revenue: _toInt(entry['revenue']),
          qty: _toInt(entry['qty']),
        );
      }
    }

    final start = DateTime(month.year, month.month - rangeMonths + 1);
    final end = DateTime(month.year, month.month + 1);
    final daysCount = end.difference(start).inDays;
    return List<SalesDayPoint>.generate(daysCount, (index) {
      final date = start.add(Duration(days: index));
      return byDate[_dayKey(date)] ??
          SalesDayPoint(date: date, revenue: 0, qty: 0);
    }, growable: false);
  }

  static List<SalesTrendSeries> _salesSeries(
    dynamic raw,
    List<SalesDayPoint> days,
  ) {
    if (raw is! List) return const [];

    final dayIndex = <String, int>{
      for (var i = 0; i < days.length; i++) _dayKey(days[i].date): i,
    };

    final result = <SalesTrendSeries>[];
    for (final entry in raw.whereType<Map>()) {
      final kode = entry['sales_kode']?.toString().trim() ?? '';
      final nama = entry['sales_nama']?.toString().trim() ?? '';
      final label = nama.isNotEmpty
          ? nama
          : (kode.isNotEmpty ? kode : 'Tidak diketahui');

      final revenue = List<int>.filled(days.length, 0);
      final points = entry['points'];
      if (points is List) {
        for (final point in points.whereType<Map>()) {
          final parsed = _parseDateTime(point['date']);
          if (parsed == null) continue;
          final index =
              dayIndex[_dayKey(
                DateTime(parsed.year, parsed.month, parsed.day),
              )];
          if (index == null) continue;
          revenue[index] = _toInt(point['revenue']);
        }
      }

      result.add(
        SalesTrendSeries(
          key: kode.isNotEmpty ? kode : label,
          label: label,
          totalRevenue: _toInt(entry['revenue']),
          revenueByDay: List<int>.unmodifiable(revenue),
        ),
      );
    }
    return List<SalesTrendSeries>.unmodifiable(result);
  }

  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  return parsed?.toLocal();
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

final NumberFormat _decimalFormat = NumberFormat.decimalPattern('id_ID');

String formatInt(int value) => _decimalFormat.format(value);

String formatRupiah(int value) => 'Rp ${_decimalFormat.format(value)}';

/// Compact rupiah for chart axes, bars and KPI cards: "Rp 2,72 M".
String formatCompactRupiah(num value) {
  final absolute = value.abs();
  if (absolute >= 1000000000000) {
    return 'Rp ${_compact(value / 1000000000000, 2)} T';
  }
  if (absolute >= 1000000000) {
    return 'Rp ${_compact(value / 1000000000, 2)} M';
  }
  if (absolute >= 1000000) {
    return 'Rp ${_compact(value / 1000000, 1)} jt';
  }
  if (absolute >= 1000) {
    return 'Rp ${_compact(value / 1000, 0)} rb';
  }
  return 'Rp ${value.round()}';
}

String formatPercent(double fraction) {
  if (fraction == 0) return '0%';
  final percent = fraction * 100;
  final decimals = percent.abs() >= 10 ? 1 : 2;
  return '${percent.toStringAsFixed(decimals).replaceAll('.', ',')}%';
}

String formatPercentPrecise(double fraction) =>
    '${(fraction * 100).toStringAsFixed(2).replaceAll('.', ',')}%';

String _compact(num value, int decimals) {
  final text = value.toStringAsFixed(decimals);
  return text.replaceAll('.', ',');
}

// ---------------------------------------------------------------------------
// Indonesian date labels (manual, so widgets never depend on intl locale data
// being initialised in tests / headless builds).
// ---------------------------------------------------------------------------

const List<String> _monthShortId = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

const List<String> _monthLongId = <String>[
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String formatMonthLong(DateTime date) =>
    '${_monthLongId[date.month - 1]} ${date.year}';

String formatMonthShort(DateTime date) =>
    '${_monthShortId[date.month - 1]} ${date.year}';

String formatDateShort(DateTime date) =>
    '${date.day} ${_monthShortId[date.month - 1]}';

String formatDateLong(DateTime date) =>
    '${date.day} ${_monthLongId[date.month - 1]} ${date.year}';

String formatDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${formatDateShort(date)} ${date.year} $hour:$minute';
}

/// Short axis label for rupiah values: `2,7 M`, `450 jt`, `12 rb`.
String formatAxisRupiah(num value) {
  final absolute = value.abs();
  if (absolute >= 1000000000000) {
    return '${_compact(value / 1000000000000, 1)} T';
  }
  if (absolute >= 1000000000) {
    return '${_compact(value / 1000000000, 1)} M';
  }
  if (absolute >= 1000000) {
    return '${_compact(value / 1000000, 0)} jt';
  }
  if (absolute >= 1000) {
    return '${_compact(value / 1000, 0)} rb';
  }
  return value.round().toString();
}
