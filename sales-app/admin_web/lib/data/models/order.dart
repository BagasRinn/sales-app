class Order {
  final String id;
  final String salesId;
  final String status;
  final DateTime createdAt;
  final DateTime? expiredAt;
  final List<OrderItem> items;
  final String? salesUsername;
  final String? salesNama;
  final String? storeName;
  final String? storeContact;
  final String? storeAddress;
  final List<CancelledItem> cancelledItems;
  final String? rejectReason;

  Order({
    required this.id,
    required this.salesId,
    required this.status,
    required this.createdAt,
    this.expiredAt,
    required this.items,
    this.salesUsername,
    this.salesNama,
    this.storeName,
    this.storeContact,
    this.storeAddress,
    this.cancelledItems = const [],
    this.rejectReason,
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
      salesNama: json['sales_nama'],
      storeName: json['store_name'],
      storeContact: json['store_contact'],
      storeAddress: json['store_address'],
      cancelledItems: (json['cancelled_items'] as List?)
              ?.map((e) => CancelledItem.fromJson(e))
              .toList() ??
          [],
      rejectReason: json['reject_reason'] as String?,
    );
  }

  String get salesDisplayName {
    if (salesNama != null && salesNama!.isNotEmpty) return salesNama!;
    if (salesUsername != null && salesUsername!.isNotEmpty) return salesUsername!;
    return '?';
  }

  int get totalItems => items.fold(0, (sum, item) => sum + item.qty);

  /// Total raw = jumlah harga semua item tanpa diskon order-level.
  int get totalRaw => items.fold(0, (sum, item) => sum + (item.hargaSatuan * item.qty));

  /// Total amount = jumlah subtotal setelah diskon (dari backend).
  int get totalAmount => items.fold(0, (sum, item) => sum + item.subtotal);

  /// Total diskon = selisih totalRaw dan totalAmount.
  int get totalDiscount => totalRaw - totalAmount;

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

  // --- Discount Layer 1 ---
  final String discountType;
  final int discountPercent;
  final int discountNominal;

  // --- Discount Layer 2 ---
  final String discount2Type;
  final int discount2Percent;
  final int discount2Nominal;

  // --- Discount Layer 3 ---
  final String discount3Type;
  final int discount3Percent;
  final int discount3Nominal;

  /// Harga per pcs setelah diskon — langsung dari backend (bukan dihitung client).
  /// Untuk NOMINAL: harga_satuan − (nominal / qty). Untuk PERCENT: sama.
  final int hargaSetelahDiskon;
  final int subtotal;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.namaBarang,
    required this.qty,
    required this.hargaSatuan,
    this.discountType = 'PERCENT',
    this.discountPercent = 0,
    this.discountNominal = 0,
    this.discount2Type = 'PERCENT',
    this.discount2Percent = 0,
    this.discount2Nominal = 0,
    this.discount3Type = 'PERCENT',
    this.discount3Percent = 0,
    this.discount3Nominal = 0,
    this.hargaSetelahDiskon = 0,
    this.subtotal = 0,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final hargaSatuan = json['harga_satuan'] as int? ?? 0;
    final qty = json['qty'] as int? ?? 1;
    final hargaStlhDiskon = json['harga_setelah_diskon'] as int? ?? hargaSatuan;
    final subtotal = json['subtotal'] as int? ?? (hargaStlhDiskon * qty);

    return OrderItem(
      id: json['id'] ?? '',
      orderId: json['order_id'] ?? '',
      productId: json['product_id'] ?? '',
      namaBarang: json['nama_barang'] ?? json['product_name'] ?? '',
      qty: qty,
      hargaSatuan: hargaSatuan,
      discountType: (json['discount_type'] as String?) ?? 'PERCENT',
      discountPercent: json['discount_percent'] as int? ?? 0,
      discountNominal: json['discount_nominal'] as int? ?? 0,
      discount2Type: (json['discount2_type'] as String?) ?? 'PERCENT',
      discount2Percent: json['discount2_percent'] as int? ?? 0,
      discount2Nominal: json['discount2_nominal'] as int? ?? 0,
      discount3Type: (json['discount3_type'] as String?) ?? 'PERCENT',
      discount3Percent: json['discount3_percent'] as int? ?? 0,
      discount3Nominal: json['discount3_nominal'] as int? ?? 0,
      hargaSetelahDiskon: hargaStlhDiskon,
      subtotal: subtotal,
    );
  }

  int get nominalDiskon => hargaSatuan * qty - subtotal;

  bool get hasDiscount => nominalDiskon > 0;
}

class CancelledItem {
  final String productId;
  final int qty;
  final String reason;

  CancelledItem({
    required this.productId,
    required this.qty,
    required this.reason,
  });

  factory CancelledItem.fromJson(Map<String, dynamic> json) {
    return CancelledItem(
      productId: json['product_id'] ?? '',
      qty: json['qty'] ?? 0,
      reason: json['reason'] ?? '',
    );
  }
}
