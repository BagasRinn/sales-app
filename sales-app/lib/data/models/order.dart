class OrderItem {
  final String id;
  final String productId;
  final String? namaBarang;
  final int qty;
  final int? hargaSatuan;

  /// Tipe diskon: 'PERCENT' (default) atau 'NOMINAL' (dalam IDR).
  final String discountType;
  final int discountPercent;
  final int discountNominal;

  /// Harga per pcs setelah diskon — langsung dari backend (bukan dihitung client).
  /// Backend menghitung proporsional: diskon order di-distribusi ke tiap item
  /// berdasarkan proporsi harga item / total harga.
  final int hargaSetelahDiskon;

  /// Subtotal item = [hargaSetelahDiskon] × [qty].
  final int subtotal;

  OrderItem({
    required this.id,
    required this.productId,
    this.namaBarang,
    required this.qty,
    this.hargaSatuan,
    this.discountType = 'PERCENT',
    this.discountPercent = 0,
    this.discountNominal = 0,
    this.hargaSetelahDiskon = 0,
    this.subtotal = 0,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final hargaSatuan = json['harga_satuan'] as int? ?? 0;
    final qty = json['qty'] as int? ?? 1;
    final hargaStlhDiskon =
        json['harga_setelah_diskon'] as int? ?? hargaSatuan;
    final subtotal =
        json['subtotal'] as int? ?? (hargaStlhDiskon * qty);

    return OrderItem(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      namaBarang: json['nama_barang'] as String?,
      qty: qty,
      hargaSatuan: hargaSatuan,
      discountType: (json['discount_type'] as String?) ?? 'PERCENT',
      discountPercent: json['discount_percent'] as int? ?? 0,
      discountNominal: json['discount_nominal'] as int? ?? 0,
      hargaSetelahDiskon: hargaStlhDiskon,
      subtotal: subtotal,
    );
  }

  int get nominalDiskon => (hargaSatuan ?? 0) * qty - subtotal;

  /// True kalau ada diskon aktif (persen > 0 ATAU nominal > 0).
  bool get hasDiscount => nominalDiskon > 0;
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
  /// Diskon di level order — berlaku untuk total seluruh item.
  final String orderDiscountType; // 'PERCENT' atau 'NOMINAL'
  final int orderDiscountNominal; // jika NOMINAL = nominal IDR; jika PERCENT = % (0-100)

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
    this.orderDiscountType = 'PERCENT',
    this.orderDiscountNominal = 0,
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
      orderDiscountType:
          (json['order_discount_type'] as String?) ?? 'PERCENT',
      orderDiscountNominal: json['order_discount_nominal'] as int? ?? 0,
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
