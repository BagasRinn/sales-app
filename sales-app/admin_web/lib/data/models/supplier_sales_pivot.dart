class SupplierSalesMetric {
  final int value;
  final int margin;
  final int qty;

  const SupplierSalesMetric({this.value = 0, this.margin = 0, this.qty = 0});

  factory SupplierSalesMetric.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return SupplierSalesMetric(
      value: (data['value'] as num?)?.toInt() ?? 0,
      margin: (data['margin'] as num?)?.toInt() ?? 0,
      qty: (data['qty'] as num?)?.toInt() ?? 0,
    );
  }

  int forMetric(String metric) => switch (metric) {
    'margin' => margin,
    'qty' => qty,
    _ => value,
  };
}

class SupplierSalesPivotColumn {
  final String name;
  final SupplierSalesMetric total;

  const SupplierSalesPivotColumn({required this.name, required this.total});

  factory SupplierSalesPivotColumn.fromJson(Map<String, dynamic> json) =>
      SupplierSalesPivotColumn(
        name: json['nama'] as String? ?? '-',
        total: SupplierSalesMetric.fromJson(
          json['total'] as Map<String, dynamic>?,
        ),
      );
}

class SupplierSalesPivotRow {
  final String supplier;
  final String channel;
  final Map<String, SupplierSalesMetric> cells;
  final SupplierSalesMetric total;

  const SupplierSalesPivotRow({
    required this.supplier,
    required this.channel,
    required this.cells,
    required this.total,
  });

  factory SupplierSalesPivotRow.fromJson(Map<String, dynamic> json) {
    final rawCells = json['cells'] as Map<String, dynamic>? ?? const {};
    return SupplierSalesPivotRow(
      supplier: json['supplier'] as String? ?? '-',
      channel: json['channel'] as String? ?? '-',
      cells: rawCells.map(
        (key, value) => MapEntry(
          key,
          SupplierSalesMetric.fromJson(value as Map<String, dynamic>?),
        ),
      ),
      total: SupplierSalesMetric.fromJson(
        json['total'] as Map<String, dynamic>?,
      ),
    );
  }
}

class SupplierSalesPivot {
  final List<SupplierSalesPivotColumn> columns;
  final List<SupplierSalesPivotRow> rows;
  final SupplierSalesMetric total;
  final DateTime from;
  final DateTime to;

  const SupplierSalesPivot({
    required this.columns,
    required this.rows,
    required this.total,
    required this.from,
    required this.to,
  });

  factory SupplierSalesPivot.fromJson(
    Map<String, dynamic> json,
  ) => SupplierSalesPivot(
    columns: (json['columns'] as List? ?? const [])
        .map(
          (e) => SupplierSalesPivotColumn.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
    rows: (json['rows'] as List? ?? const [])
        .map((e) => SupplierSalesPivotRow.fromJson(e as Map<String, dynamic>))
        .toList(),
    total: SupplierSalesMetric.fromJson(json['total'] as Map<String, dynamic>?),
    from: DateTime.tryParse(json['from'] as String? ?? '') ?? DateTime.now(),
    to: DateTime.tryParse(json['to'] as String? ?? '') ?? DateTime.now(),
  );
}
