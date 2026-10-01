class SalesTarget {
  final String? id;
  final String userId;
  final String period;
  final String targetType;
  final int targetValue;
  final int incentiveAmount;

  SalesTarget({
    this.id,
    required this.userId,
    required this.period,
    required this.targetType,
    required this.targetValue,
    required this.incentiveAmount,
  });

  factory SalesTarget.fromJson(Map<String, dynamic> json) {
    return SalesTarget(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      period: json['period'] as String,
      targetType: json['target_type'] as String,
      targetValue: json['target_value'] as int? ?? 0,
      incentiveAmount: json['incentive_amount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'period': period,
        'target_type': targetType,
        'target_value': targetValue,
        'incentive_amount': incentiveAmount,
      };

  SalesTarget copyWith({
    String? id,
    String? userId,
    String? period,
    String? targetType,
    int? targetValue,
    int? incentiveAmount,
  }) {
    return SalesTarget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      period: period ?? this.period,
      targetType: targetType ?? this.targetType,
      targetValue: targetValue ?? this.targetValue,
      incentiveAmount: incentiveAmount ?? this.incentiveAmount,
    );
  }

  bool get isOrderCount => targetType == 'ORDER_COUNT';
  bool get isRevenue => targetType == 'REVENUE';
}
