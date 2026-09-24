class OrderItem {
  final String id;
  final String productId;
  final String? namaBarang;
  final int qty;
  final int? hargaSatuan;
  final int discountPercent;

  OrderItem({
    required this.id,
    required this.productId,
    this.namaBarang,
    required this.qty,
    this.hargaSatuan,
    this.discountPercent = 0,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      namaBarang: json['nama_barang'] as String?,
      qty: json['qty'] as int,
      hargaSatuan: json['harga_satuan'] as int?,
      discountPercent: json['discount_percent'] as int? ?? 0,
    );
  }

  int get hargaSetelahDiskon {
    final harga = hargaSatuan ?? 0;
    return (harga * (100 - discountPercent) / 100).round();
  }

  int get subtotal => hargaSetelahDiskon * qty;

  int get nominalDiskon {
    final harga = hargaSatuan ?? 0;
    return (harga - hargaSetelahDiskon) * qty;
  }
}

class Order {
  final String id;
  final String salesId;
  final String? customerId;
  final String? customerName;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? expiredAt;
  final List<OrderItem>? items;
  final String? storeName;
  final String? storeContact;
  final String? storeAddress;

  Order({
    required this.id,
    required this.salesId,
    this.customerId,
    this.customerName,
    required this.status,
    this.notes,
    required this.createdAt,
    this.expiredAt,
    this.items,
    this.storeName,
    this.storeContact,
    this.storeAddress,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      salesId: json['sales_id'] as String,
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String?,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiredAt: json['expired_at'] != null
          ? DateTime.parse(json['expired_at'] as String)
          : null,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      storeName: json['store_name'] as String?,
      storeContact: json['store_contact'] as String?,
      storeAddress: json['store_address'] as String?,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'DRAFT':
        return 'Draft';
      case 'PENDING':
        return 'Dikirim';
      case 'APPROVED':
        return 'Diterima';
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

  bool get canEdit => status == 'DRAFT';
  bool get canDelete => status == 'DRAFT';

  int get totalQty {
    final list = items;
    if (list == null) return 0;
    return list.fold(0, (a, b) => a + b.qty);
  }

  int get totalPrice {
    final list = items;
    if (list == null) return 0;
    return list.fold(0, (a, b) => a + b.subtotal);
  }

  int get totalDiscount {
    final list = items;
    if (list == null) return 0;
    return list.fold(0, (a, b) => a + b.nominalDiskon);
  }
}
