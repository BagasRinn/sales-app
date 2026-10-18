class Supplier {
  final String name;
  final bool isActive;
  final String orderType;
  final int productCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Supplier({
    required this.name,
    required this.isActive,
    this.orderType = 'REGULER',
    this.productCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        name: json['name'] as String,
        isActive: json['is_active'] as bool? ?? true,
        orderType: json['order_type'] as String? ?? 'REGULER',
        productCount: (json['product_count'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'is_active': isActive,
        'order_type': orderType,
        'product_count': productCount,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}
