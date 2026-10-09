import '../../core/datetime_utils.dart';

class Order {
  final String id;
  final String salesId;
  final String status;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String? salesUsername;
  final String? salesNama;
  final String? storeName;
  final String? storeContact;
  final String? storeAddress;
  /// UUID customer di master data. Null kalau order dibuat tanpa customer
  /// (mis. legacy order, atau customer dihapus). Backend sudah suplai via
  /// `customer_id` di response — sebelumnya di-drop oleh client ini.
  final String? customerId;
  /// Snapshot nama customer dari tabel customers. Beda dengan [storeName]
  /// yang merupakan denormalized name per-order: kalau customer di-rename
  /// setelah order dibuat, [customerName] ikut update, [storeName] tidak.
  final String? customerName;
  final List<CancelledItem> cancelledItems;
  final String? rejectReason;
  final String? invoiceNumber;
  /// Catatan dari sales saat membuat pesanan (mis. "toko tutup jam 5").
  /// Backend sudah suplai via `notes` di response, tapi client ini belum parse
  /// sebelumnya — sekarang dipakai supaya tampil di order detail admin.
  final String? notes;
  final String? branch;
  final String? branchNama;

  Order({
    required this.id,
    required this.salesId,
    required this.status,
    required this.createdAt,
    required this.items,
    this.salesUsername,
    this.salesNama,
    this.storeName,
    this.storeContact,
    this.storeAddress,
    this.customerId,
    this.customerName,
    this.cancelledItems = const [],
    this.rejectReason,
    this.invoiceNumber,
    this.notes,
    this.branch,
    this.branchNama,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      salesId: json['sales_id'] ?? '',
      status: json['status'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '')?.toWita() ?? DateTime.now(),
      items: (json['items'] as List?)?.map((e) => OrderItem.fromJson(e)).toList() ?? [],
      salesUsername: json['sales_username'],
      salesNama: json['sales_nama'],
      storeName: json['store_name'],
      storeContact: json['store_contact'],
      storeAddress: json['store_address'],
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String?,
      cancelledItems: (json['cancelled_items'] as List?)
              ?.map((e) => CancelledItem.fromJson(e))
              .toList() ??
          [],
      rejectReason: json['reject_reason'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      notes: json['notes'] as String?,
      branch: json['branch'] as String?,
      branchNama: json['branch_nama'] as String?,
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
      case 'CANCELLED': return 'Dibatalkan';
      // EXPIRED dihapus: logika expiration sudah tidak dipakai (tidak ada
      // cron job yang set status ke EXPIRED), jadi status ini tidak akan
      // pernah muncul di data. Kalau backend masih kirim data lama berstatus
      // EXPIRED, fallback ke label raw.
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
  final double discountPercent;
  final int discountNominal;

  // --- Discount Layer 2 ---
  final String discount2Type;
  final double discount2Percent;
  final int discount2Nominal;

  // --- Discount Layer 3 ---
  final String discount3Type;
  final double discount3Percent;
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
    this.discountPercent = 0.0,
    this.discountNominal = 0,
    this.discount2Type = 'PERCENT',
    this.discount2Percent = 0.0,
    this.discount2Nominal = 0,
    this.discount3Type = 'PERCENT',
    this.discount3Percent = 0.0,
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
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0.0,
      discountNominal: json['discount_nominal'] as int? ?? 0,
      discount2Type: (json['discount2_type'] as String?) ?? 'PERCENT',
      discount2Percent: (json['discount2_percent'] as num?)?.toDouble() ?? 0.0,
      discount2Nominal: json['discount2_nominal'] as int? ?? 0,
      discount3Type: (json['discount3_type'] as String?) ?? 'PERCENT',
      discount3Percent: (json['discount3_percent'] as num?)?.toDouble() ?? 0.0,
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
  // Snapshot nama barang saat admin cancel — disuplai backend supaya UI
  // tidak harus lookup ke tabel products. Null kalau produk sudah dihapus.
  final String? namaBarang;
  final int qty;
  // Snapshot harga saat cancel — supaya admin bisa lihat impact finansial
  // dari item yang dibatalkan. Null kalau produk sudah dihapus setelah cancel.
  final int? hargaSatuan;
  final int? subtotal;
  final String reason;

  CancelledItem({
    required this.productId,
    this.namaBarang,
    required this.qty,
    this.hargaSatuan,
    this.subtotal,
    required this.reason,
  });

  factory CancelledItem.fromJson(Map<String, dynamic> json) {
    return CancelledItem(
      productId: json['product_id'] ?? '',
      namaBarang: json['nama_barang'] as String?,
      qty: json['qty'] ?? 0,
      hargaSatuan: json['harga_satuan'] as int?,
      subtotal: json['subtotal'] as int?,
      reason: json['reason'] ?? '',
    );
  }

  /// Tampilan human-readable — pakai snapshot nama kalau ada, fallback ke id.
  String get displayLabel {
    if (namaBarang != null && namaBarang!.isNotEmpty) return namaBarang!;
    return 'Produk $productId';
  }
}
