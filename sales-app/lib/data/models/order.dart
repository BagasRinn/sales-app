class OrderItem {
  final String id;
  final String productId;
  final int qty;

  OrderItem({
    required this.id,
    required this.productId,
    required this.qty,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      qty: json['qty'] as int,
    );
  }
}

class Order {
  final String id;
  final String salesId;
  final String status;
  final DateTime createdAt;
  final DateTime? expiredAt;
  final List<OrderItem>? items;

  Order({
    required this.id,
    required this.salesId,
    required this.status,
    required this.createdAt,
    this.expiredAt,
    this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      salesId: json['sales_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiredAt: json['expired_at'] != null
          ? DateTime.parse(json['expired_at'] as String)
          : null,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'PENDING':
        return 'Menunggu';
      case 'APPROVED':
        return 'Disetujui';
      case 'REJECTED':
        return 'Ditolak';
      case 'EXPIRED':
        return 'Kedaluwarsa';
      case 'CANCELLED':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  bool get canCancel => status == 'PENDING';
}
