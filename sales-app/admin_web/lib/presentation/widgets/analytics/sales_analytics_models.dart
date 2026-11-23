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

/// Kunci pencocokan ternormalisasi: huruf besar + spasi dirapatkan, agar
/// variasi kapital/spasi pada nama produk tidak mematahkan pencocokan.
String normalizeRankMatchKey(String value) =>
    value.trim().toUpperCase().split(RegExp(r'\s+')).join(' ');

/// Kandidat kunci pencocokan untuk satu item ranking, urut prioritas:
/// mother_sku (kunci grup produk di backend, stabil lintas cabang),
/// product_kode, lalu label ternormalisasi.
///
/// Nilai `product_kode` hasil agregasi GLOBAL di backend adalah `max()`
/// lintas cabang/bulan sehingga bisa berbeda antara payload ringkasan dan
/// payload pembanding; fallback kunci mencegah kolom pembanding Pareto
/// Product keliru menampilkan Rp 0 untuk produk yang datanya sebenarnya ada.
List<String> rankMatchKeys(SalesRankItem item) {
  final keys = <String>[];
  void add(String? value) {
    final normalized = normalizeRankMatchKey(value ?? '');
    if (normalized.isNotEmpty && !keys.contains(normalized)) {
      keys.add(normalized);
    }
  }

  add(item.motherSku);
  add(item.code);
  add(item.label);
  return keys;
}

/// Bangun indeks kunci -> item untuk pencocokan dua payload ranking.
/// Item pertama yang memiliki sebuah kunci menang (payload lebih awal
/// biasanya sudah diurutkan berdasarkan peringkat).
Map<String, SalesRankItem> buildRankMatchIndex(
  Iterable<SalesRankItem> items,
) {
  final byKey = <String, SalesRankItem>{};
  for (final item in items) {
    for (final key in rankMatchKeys(item)) {
      byKey.putIfAbsent(key, () => item);
    }
  }
  return byKey;
}

/// Cari item di [index] yang cocok dengan [item] lewat salah satu kuncinya.
SalesRankItem? matchRankItem(
  Map<String, SalesRankItem> index,
  SalesRankItem item,
) {
  for (final key in rankMatchKeys(item)) {
    final found = index[key];
    if (found != null) return found;
  }
  return null;
}

/// Satu baris ranking Value Good (produk/supplier/divisi).
class StockRankItem {
  final String key;
  final String label;
  final int goodAmount;

  const StockRankItem({
    required this.key,
    required this.label,
    required this.goodAmount,
  });

  String get displayLabel => label.trim().isEmpty ? key : label.trim();
}

/// Hasil GET /product-stocks/summary: total + top-N Value Good per dimensi.
/// Map `*ByKey` memetakan kunci ternormalisasi -> good_amount supaya kartu
/// ranking bisa mencocokkan item omzet dengan stok lewat `rankMatchKeys`
/// (mother_sku -> kode -> label), konsisten dengan perbaikan Pareto Product.
class ProductStockSummary {
  final String month;
  final String scope;
  final int totalGoodAmount;
  final int skuCount;
  final List<StockRankItem> products;
  final List<StockRankItem> suppliers;
  final List<StockRankItem> divisi;
  final Map<String, int> productByKey;
  final Map<String, int> supplierByKey;
  final Map<String, int> divisiByKey;

  const ProductStockSummary({
    required this.month,
    required this.scope,
    required this.totalGoodAmount,
    required this.skuCount,
    required this.products,
    required this.suppliers,
    required this.divisi,
    required this.productByKey,
    required this.supplierByKey,
    required this.divisiByKey,
  });

  bool get isEmpty => totalGoodAmount == 0 && products.isEmpty;

  static Map<String, int> _keyMap(Iterable<StockRankItem> items) {
    final map = <String, int>{};
    for (final item in items) {
      final key = normalizeRankMatchKey(item.key);
      if (key.isNotEmpty) map.putIfAbsent(key, () => item.goodAmount);
    }
    return Map.unmodifiable(map);
  }

  factory ProductStockSummary.fromMap(Map<String, dynamic> map) {
    List<StockRankItem> parseBucket(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (row) => StockRankItem(
              key: row['key']?.toString().trim() ?? '',
              label: row['label']?.toString().trim() ?? '',
              goodAmount: _toInt(row['good_amount']),
            ),
          )
          .toList(growable: false);
    }

    final products = parseBucket(map['by_product']);
    final suppliers = parseBucket(map['by_supplier']);
    final divisi = parseBucket(map['by_divisi']);
    return ProductStockSummary(
      month: map['month']?.toString() ?? '',
      scope: map['scope']?.toString() ?? '',
      totalGoodAmount: _toInt(map['total_good_amount']),
      skuCount: _toInt(map['sku_count']),
      products: products,
      suppliers: suppliers,
      divisi: divisi,
      productByKey: _keyMap(products),
      supplierByKey: _keyMap(suppliers),
      divisiByKey: _keyMap(divisi),
    );
  }
}

class SalesRankItem {
  final String code;
  final String label;
  final int qty;
  final int revenue;
  final int margin;
  final int activeOutlets;
  final String? motherSku;
  final String? productKode;

  const SalesRankItem({
    required this.code,
    required this.label,
    required this.qty,
    required this.revenue,
    this.margin = 0,
    this.activeOutlets = 0,
    this.motherSku,
    this.productKode,
  });

  String get displayLabel {
    if (label.trim().isNotEmpty) return label.trim();
    if (code.trim().isNotEmpty) return code.trim();
    return 'Tidak diketahui';
  }

  /// Label stabil lintas cabang untuk ranking Pareto Product.
  /// Jangan gunakan nama item sebagai fallback karena nilainya bisa berbeda
  /// antar cabang; jika tidak tersedia, jangan ganti dengan nama item/kode.
  String get displayMotherSku {
    if (motherSku?.trim().isNotEmpty == true) return motherSku!.trim();
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
    this.valueStok,
  });

  final String label;
  final int value;
  final int? sortValue;
  final String? detail;
  final String? trailingDetail;
  final bool showTarget;
  final int? target;
  final int? targetActual;

  /// Snapshot stok (GOOD AMOUNT) item ini. Bila baris punya Target, nilainya
  /// tampil sebaris dengan status/persen target; bila tidak, ia memimpin
  /// tumpukan footer (Value Stok → detail → persen).
  final int? valueStok;
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
  final int effectiveCalls;
  final int activeOutlets;
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
  final Map<String, int> divisiTargets;

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
    required this.effectiveCalls,
    required this.activeOutlets,
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
    required this.divisiTargets,
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
      effectiveCalls: _toInt(summary['effective_calls']),
      activeOutlets: _toInt(summary['active_outlets']),
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
      divisiTargets: _targetMap(summary['divisi_targets']),
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
            activeOutlets: _toInt(row['active_outlets']),
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

/// Payload pembanding: net omzet per bulan untuk N bulan *sebelum* bulan
/// terpilih. Digunakan chip pembanding (1/3/6/12 bulan) di dashboard.
class SalesComparison {
  final String month; // bulan terpilih, YYYY-MM
  final int months; // jumlah bulan pembanding yang diminta (1/3/6/12)
  final int monthsWithData; // berapa bulan yang actually punya data
  final int totalRevenue; // jumlah net omzet bulan berdata
  final int averageRevenue; // mean (integer) = totalRevenue ~/ monthsWithData
  final List<ComparisonMonth> monthly;

  /// Detail dimensi untuk pembanding (produk / pelanggan / divisi). Setiap
  /// item sudah dalam bentuk rata-rata per bulan (net omzet ÷ bulan berdata).
  final List<SalesRankItem> byProduct;
  final List<SalesRankItem> byCustomer;
  final List<SalesRankItem> byDivisi;

  const SalesComparison({
    required this.month,
    required this.months,
    required this.monthsWithData,
    required this.totalRevenue,
    required this.averageRevenue,
    required this.monthly,
    this.byProduct = const [],
    this.byCustomer = const [],
    this.byDivisi = const [],
  });

  factory SalesComparison.fromMap(Map<String, dynamic> m, {int months = 1}) {
    final monthly = (m['monthly'] as List? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .map((e) => ComparisonMonth.fromMap(e))
        .toList(growable: false);
    return SalesComparison(
      month: m['month']?.toString() ?? '',
      months: months,
      monthsWithData: (m['months_with_data'] as num?)?.toInt() ?? 0,
      totalRevenue: (m['total_revenue'] as num?)?.toInt() ?? 0,
      averageRevenue: (m['average_revenue'] as num?)?.toInt() ?? 0,
      monthly: monthly,
      byProduct: _rankListFromComparison(
        m['by_product'],
        'product_kode',
        'product_nama',
        product: true,
      ),
      byCustomer: _rankListFromComparison(
        m['by_customer'],
        'customer_kode',
        'customer_nama',
      ),
      byDivisi: _rankListFromComparison(m['by_divisi'], 'divisi', null),
    );
  }

  /// Apakah ada setidaknya satu bulan pembanding yang punya data.
  bool get hasBaseline => monthsWithData > 0 && averageRevenue > 0;

  static List<SalesRankItem> _rankListFromComparison(
    dynamic raw,
    String codeKey,
    String? labelKey, {
    bool product = false,
  }) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .map(
          (row) => SalesRankItem(
            code: row[codeKey]?.toString().trim() ?? '',
            label: labelKey == null
                ? ''
                : row[labelKey]?.toString().trim() ?? '',
            qty: _toInt(row['qty']),
            revenue: _toInt(row['average_revenue'] ?? row['revenue']),
            margin: _toInt(row['average_margin'] ?? row['margin']),
            motherSku: product ? row['mother_sku']?.toString() : null,
            productKode: product ? row['product_kode']?.toString() : null,
          ),
        )
        .toList(growable: false);
  }
}

class ComparisonMonth {
  final String month;
  final int grossRevenue;
  final int returRevenue;
  final int netRevenue;
  final int rows;

  const ComparisonMonth({
    required this.month,
    required this.grossRevenue,
    required this.returRevenue,
    required this.netRevenue,
    required this.rows,
  });

  factory ComparisonMonth.fromMap(Map<String, dynamic> m) => ComparisonMonth(
    month: m['month']?.toString() ?? '',
    grossRevenue: (m['gross_revenue'] as num?)?.toInt() ?? 0,
    returRevenue: (m['retur_revenue'] as num?)?.toInt() ?? 0,
    netRevenue: (m['net_revenue'] as num?)?.toInt() ?? 0,
    rows: (m['rows'] as num?)?.toInt() ?? 0,
  );

  /// Bulan ini ikut dihitung ke rata-rata (punya data nyata).
  bool get countsTowardAverage => netRevenue > 0 || rows > 0;
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
