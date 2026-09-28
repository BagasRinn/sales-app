import 'package:flutter/foundation.dart';
import '../../data/models/customer.dart';

/// Single source of truth untuk flow order (Step 1 → 2 → 3 + edit draft).
class DraftOrderProvider extends ChangeNotifier {
  String? customerId;
  String? customerName;
  String? customerAddress;
  Map<String, int> items = {}; // productId -> qty

  /// Diskon di level order — berlaku untuk total seluruh item.
  /// satu diskon per order, bukan per produk.
  DiscountInfo? orderDiscount;

  String notes = '';
  String? editingOrderId;

  // Optional pricing cache: productId -> unit price. Diisi dari ProductProvider saat fetch.
  Map<String, int> _priceCache = {};

  void setPricingCache(Map<String, int> prices) {
    _priceCache = prices;
  }

  void setCustomer(Customer c) {
    customerId = c.id;
    customerName = c.namaToko;
    customerAddress = c.alamat;
    notifyListeners();
  }

  void setCustomerDirect({
    required String id,
    required String namaToko,
    String? alamat,
  }) {
    customerId = id;
    customerName = namaToko;
    customerAddress = alamat;
    notifyListeners();
  }

  void setQty(String productId, int qty) {
    if (qty <= 0) {
      items.remove(productId);
    } else {
      items[productId] = qty;
    }
    notifyListeners();
  }

  /// Set diskon untuk keseluruhan order.
  /// [type] = 'PERCENT' (value 0-100) atau 'NOMINAL' (value dalam IDR).
  /// value <= 0 akan menghapus diskon.
  void setOrderDiscount({
    required String type,
    required int value,
  }) {
    if (type != 'PERCENT' && type != 'NOMINAL') {
      throw ArgumentError(
          'discount type harus PERCENT atau NOMINAL, dapat: \$type');
    }
    if (value <= 0) {
      orderDiscount = null;
    } else {
      int capped = value;
      if (type == 'PERCENT' && value > 100) {
        capped = 100;
      }
      orderDiscount = DiscountInfo(type: type, value: capped);
    }
    notifyListeners();
  }

  /// Backward compat: setDiscount lama (per-item) sekarang tidak dipakai.
  /// Disimpan tapi tidak memengaruhi harga — tetap order-level.
  Map<String, DiscountInfo> discounts = {};

  @Deprecated('Tidak dipakai — diskon sekarang di level order')
  void setDiscount({
    required String productId,
    required String type,
    required int value,
  }) {
    // no-op: diskon sekarang di level order
  }

  void setNotes(String value) {
    notes = value;
    notifyListeners();
  }

  void loadFromExisting({
    required String orderId,
    required String customerId,
    required String customerName,
    required String? customerAddress,
    required Map<String, int> existingItems,
    required DiscountInfo? existingOrderDiscount,
    required String existingNotes,
  }) {
    editingOrderId = orderId;
    this.customerId = customerId;
    this.customerName = customerName;
    this.customerAddress = customerAddress;
    items = Map<String, int>.from(existingItems);
    orderDiscount = existingOrderDiscount;
    notes = existingNotes;
    notifyListeners();
  }

  void reset() {
    customerId = null;
    customerName = null;
    customerAddress = null;
    items = {};
    orderDiscount = null;
    discounts = {};
    notes = '';
    editingOrderId = null;
    notifyListeners();
  }

  bool get hasCustomer => customerId != null;
  bool get hasItems => items.values.any((q) => q > 0);
  int get totalItems => items.values.fold(0, (a, b) => a + b);
  bool get isEditing => editingOrderId != null;

  /// Total harga TANPA diskon — harga dasar semua item.
  int get totalRaw {
    int total = 0;
    items.forEach((productId, qty) {
      final price = _priceCache[productId] ?? 0;
      total += price * qty;
    });
    return total;
  }

  /// Total harga setelah diskon order-level (dihitung di backend).
  /// Client-side estimasi untuk tampilan.
  int get totalPrice {
    final raw = totalRaw;
    if (orderDiscount == null) return raw;
    if (orderDiscount!.type == 'NOMINAL') {
      return (raw - orderDiscount!.value).clamp(0, raw);
    }
    return (raw * (100 - orderDiscount!.value) / 100).round();
  }

  /// Estimasi hemat — selisih totalRaw dan totalPrice.
  int get totalDiscount {
    if (orderDiscount == null) return 0;
    return totalRaw - totalPrice;
  }
}

class DiscountInfo {
  final String type; // 'PERCENT' atau 'NOMINAL'
  final int value;

  const DiscountInfo({required this.type, required this.value});

  Map<String, dynamic> toJson() => {
        'discount_type': type,
        'discount_percent': type == 'PERCENT' ? value : 0,
        'discount_nominal': type == 'NOMINAL' ? value : 0,
      };

  factory DiscountInfo.percent(int value) =>
      DiscountInfo(type: 'PERCENT', value: value);
  factory DiscountInfo.nominal(int value) =>
      DiscountInfo(type: 'NOMINAL', value: value);

  factory DiscountInfo.fromPercentInt(int value) =>
      DiscountInfo(type: 'PERCENT', value: value);
}
