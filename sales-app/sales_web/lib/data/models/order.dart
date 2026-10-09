enum DiscountType { percent, nominal }

class DiscountLayer {
  final DiscountType type;
  final int value;

  const DiscountLayer({required this.type, required this.value});

  int cutFrom(int price) {
    if (value <= 0) return 0;
    if (type == DiscountType.percent) {
      return (price * value / 100).round();
    } else {
      return value > price ? price : value;
    }
  }

  Map<String, dynamic> toJson() => {'type': type.name.toUpperCase(), 'value': value};

  factory DiscountLayer.fromJson(Map<String, dynamic> json) {
    return DiscountLayer(
      type: (json['type'] as String).toUpperCase() == 'NOMINAL'
          ? DiscountType.nominal
          : DiscountType.percent,
      value: json['value'] as int,
    );
  }
}

class ItemDiscount {
  DiscountLayer? layer1;
  DiscountLayer? layer2;
  DiscountLayer? layer3;

  ItemDiscount({this.layer1, this.layer2, this.layer3});

  bool get isEmpty => layer1 == null && layer2 == null && layer3 == null;

  ItemDiscount withLayer(int layer, DiscountType type, int value) {
    final dl = DiscountLayer(type: type, value: value);
    final copy = ItemDiscount(layer1: layer1, layer2: layer2, layer3: layer3);
    switch (layer) {
      case 1:
        copy.layer1 = dl;
        break;
      case 2:
        copy.layer2 = dl;
        break;
      case 3:
        copy.layer3 = dl;
        break;
    }
    return copy;
  }

  Map<String, dynamic> toJson() => {
    'layer1': layer1?.toJson(),
    'layer2': layer2?.toJson(),
    'layer3': layer3?.toJson(),
  };

  factory ItemDiscount.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ItemDiscount();
    return ItemDiscount(
      layer1: json['layer1'] != null ? DiscountLayer.fromJson(json['layer1']) : null,
      layer2: json['layer2'] != null ? DiscountLayer.fromJson(json['layer2']) : null,
      layer3: json['layer3'] != null ? DiscountLayer.fromJson(json['layer3']) : null,
    );
  }
}

class OrderItem {
  final String id;
  final String productId;
  final String? namaBarang;
  final int hargaSatuan;
  final int qty;
  final ItemDiscount discount;
  final int hargaSetelahDiskon;
  final int subtotal;

  OrderItem({
    required this.id,
    required this.productId,
    this.namaBarang,
    required this.hargaSatuan,
    required this.qty,
    required this.discount,
    required this.hargaSetelahDiskon,
    required this.subtotal,
  });

  int get nominalDiskon => (hargaSatuan - hargaSetelahDiskon) * qty;
  bool get hasDiscount => !discount.isEmpty;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Match the mobile app's OrderItem.fromJson (lib/data/models/order.dart):
    // every numeric field has a default, every string is nullable, so a single
    // sparse item never crashes the whole list parse.
    //
    // NOTE: the backend sends FLAT discount fields (discount_type, discount_percent,
    // discount2_percent, etc.) — NOT a nested `discount: {layer1: {...}}` object.
    // We read those flat fields directly and construct DiscountLayer objects.
    final hargaSatuan = json['harga_satuan'] as int? ?? 0;
    final qty = json['qty'] as int? ?? 1;
    final hargaSetelahDiskon =
        json['harga_setelah_diskon'] as int? ?? hargaSatuan;
    final subtotal = json['subtotal'] as int? ?? (hargaSetelahDiskon * qty);

    DiscountLayer? makeLayer(String typeKey, String percentKey, String nominalKey) {
      final typeVal = json[typeKey] as String?;
      if (typeVal == null) return null;
      if (typeVal.toUpperCase() == 'NOMINAL') {
        final nominal = json[nominalKey] as int? ?? 0;
        if (nominal <= 0) return null;
        return DiscountLayer(type: DiscountType.nominal, value: nominal);
      } else {
        final percent = (json[percentKey] as num?)?.toDouble() ?? 0;
        if (percent <= 0) return null;
        return DiscountLayer(type: DiscountType.percent, value: percent.toInt());
      }
    }

    return OrderItem(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      namaBarang: json['nama_barang'] as String?,
      qty: qty,
      hargaSatuan: hargaSatuan,
      discount: ItemDiscount(
        layer1: makeLayer('discount_type', 'discount_percent', 'discount_nominal'),
        layer2: makeLayer('discount2_type', 'discount2_percent', 'discount2_nominal'),
        layer3: makeLayer('discount3_type', 'discount3_percent', 'discount3_nominal'),
      ),
      hargaSetelahDiskon: hargaSetelahDiskon,
      subtotal: subtotal,
    );
  }
}

class CancelledItem {
  final String productId;
  final String namaBarang;
  final int qty;
  final int hargaSatuan;
  final int subtotal;
  final String reason;

  CancelledItem({
    required this.productId,
    required this.namaBarang,
    required this.qty,
    required this.hargaSatuan,
    required this.subtotal,
    required this.reason,
  });

  String get displayLabel => namaBarang.isNotEmpty ? namaBarang : 'Item dibatalkan';

  factory CancelledItem.fromJson(Map<String, dynamic> json) {
    return CancelledItem(
      productId: json['product_id'] as String,
      namaBarang: json['nama_barang'] as String? ?? '',
      qty: json['qty'] as int,
      hargaSatuan: json['harga_satuan'] as int,
      subtotal: json['subtotal'] as int,
      reason: json['reason'] as String? ?? '',
    );
  }
}

class Order {
  final String id;
  final String salesId;
  final String customerId;
  final String customerName;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final String storeName;
  final String? storeContact;
  final String? storeAddress;
  final String orderType;
  final List<OrderItem> items;
  final List<CancelledItem> cancelledItems;
  final String? rejectReason;
  final String? invoiceNumber;

  Order({
    required this.id,
    required this.salesId,
    required this.customerId,
    required this.customerName,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.storeName,
    this.storeContact,
    this.storeAddress,
    required this.orderType,
    required this.items,
    required this.cancelledItems,
    this.rejectReason,
    this.invoiceNumber,
  });

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'PENDING': return 'Menunggu';
      case 'APPROVED': return 'Disetujui';
      case 'REJECTED': return 'Ditolak';
      case 'CANCELLED': return 'Dibatalkan';
      case 'DRAFT': return 'Draft';
      default: return status;
    }
  }

  bool get canEdit => status == 'DRAFT' || status == 'PENDING';
  bool get canDelete => status == 'DRAFT' || status == 'PENDING';
  bool get isPending => status == 'PENDING';
  bool get isDraft => status == 'DRAFT';

  int get totalQty => items.fold(0, (sum, item) => sum + item.qty);

  int get totalPrice => items.fold(0, (sum, item) => sum + item.subtotal);

  int get totalDiscount {
    return items.fold(0, (sum, item) {
      int itemDiscount = (item.hargaSatuan * item.qty) - item.subtotal;
      return sum + itemDiscount;
    });
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      salesId: json['sales_id'] as String,
      customerId: json['customer_id'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? '',
      status: json['status'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      storeName: json['store_name'] as String? ?? '',
      storeContact: json['store_contact'] as String?,
      storeAddress: json['store_address'] as String?,
      orderType: json['order_type'] as String? ?? 'REGULER',
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      cancelledItems: (json['cancelled_items'] as List<dynamic>?)
          ?.map((e) => CancelledItem.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      rejectReason: json['reject_reason'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
    );
  }
}

class SalesStats {
  final int omsetHariIni;
  final int pendingCount;
  final int selesaiBulanIniCount;
  final int selesaiBulanIniTotal;
  final String? targetType;
  final int? targetValue;
  final int? incentiveAmount;
  final String? targetPeriod;

  SalesStats({
    required this.omsetHariIni,
    required this.pendingCount,
    required this.selesaiBulanIniCount,
    required this.selesaiBulanIniTotal,
    this.targetType,
    this.targetValue,
    this.incentiveAmount,
    this.targetPeriod,
  });

  factory SalesStats.fromJson(Map<String, dynamic> json) {
    return SalesStats(
      omsetHariIni: json['omset_hari_ini'] as int? ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
      selesaiBulanIniCount: json['selesai_bulan_ini_count'] as int? ?? 0,
      selesaiBulanIniTotal: json['selesai_bulan_ini_total'] as int? ?? 0,
      targetType: json['target_type'] as String?,
      targetValue: json['target_value'] as int?,
      incentiveAmount: json['incentive_amount'] as int?,
      targetPeriod: json['target_period'] as String?,
    );
  }
}
