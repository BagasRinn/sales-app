class Order {
  final String id;
  final String salesId;
  final String status;
  final DateTime createdAt;
  final DateTime? expiredAt;
  final List<OrderItem> items;
  final String? salesUsername;
  final String? storeName;
  final String? storeContact;
  final String? storeAddress;

  Order({
    required this.id,
    required this.salesId,
    required this.status,
    required this.createdAt,
    this.expiredAt,
    required this.items,
    this.salesUsername,
    this.storeName,
    this.storeContact,
    this.storeAddress,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      salesId: json['sales_id'] ?? '',
      status: json['status'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      expiredAt: json['expired_at'] != null ? DateTime.tryParse(json['expired_at']) : null,
      items: (json['items'] as List?)?.map((e) => OrderItem.fromJson(e)).toList() ?? [],
      salesUsername: json['sales_username'],
      storeName: json['store_name'],
      storeContact: json['store_contact'],
      storeAddress: json['store_address'],
    );
  }

  int get totalItems => items.fold(0, (sum, item) => sum + item.qty);
  int get totalAmount => items.fold(0, (sum, item) => sum + (item.qty * item.hargaSatuan));

  String get statusLabel {
    switch (status) {
      case 'PENDING': return 'Menunggu';
      case 'APPROVED': return 'Disetujui';
      case 'REJECTED': return 'Ditolak';
      case 'EXPIRED': return 'Kedaluwarsa';
      case 'CANCELLED': return 'Dibatalkan';
      default: return status;
    }
  }
}

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String namaBarang;
  final int qty;
  final int hargaSatuan;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.namaBarang,
    required this.qty,
    required this.hargaSatuan,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? '',
      orderId: json['order_id'] ?? '',
      productId: json['product_id'] ?? '',
      namaBarang: json['nama_barang'] ?? json['product_name'] ?? '',
      qty: json['qty'] ?? 0,
      hargaSatuan: json['harga_satuan'] ?? json['harga'] ?? 0,
    );
  }
}
