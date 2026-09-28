import 'package:flutter/foundation.dart';
import '../../data/models/customer.dart';

/// Single source of truth untuk flow order (Step 1 → 2 → 3 + edit draft).
class DraftOrderProvider extends ChangeNotifier {
  String? customerId;
  String? customerName;
  String? customerAddress;
  Map<String, int> items = {}; // productId -> qty

  /// Diskon per item: productId -> DiscountInfo.
  /// Setiap item bisa punya diskon berbeda (persen atau nominal per pcs).
  Map<String, DiscountInfo> discounts = {};

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

  /// Set diskon untuk satu produk.
  /// [type] = 'PERCENT' (value 0-100) atau 'NOMINAL' (value dalam IDR per pcs).
  /// value <= 0 akan menghapus diskon untuk produk ini.
  void setDiscount({
    required String productId,
    required String type,
    required int value,
  }) {
    if (type != 'PERCENT' && type != 'NOMINAL') {
      throw ArgumentError(
          'discount type harus PERCENT atau NOMINAL, dapat: $type');
    }
    if (value <= 0) {
      discounts.remove(productId);
    } else {
      int capped = value;
      if (type == 'PERCENT' && value > 100) {
        capped = 100;
      }
      // For NOMINAL, cap at harga satuan
      if (type == 'NOMINAL') {
        final harga = _priceCache[productId] ?? 0;
        capped = value > harga ? harga : value;
      }
      discounts[productId] = DiscountInfo(type: type, value: capped);
    }
    notifyListeners();
  }

  /// Total harga TANPA diskon — harga dasar semua item.
  int get totalRaw {
    int total = 0;
    items.forEach((productId, qty) {
      final price = _priceCache[productId] ?? 0;
      total += price * qty;
    });
    return total;
  }

  /// Total harga setelah diskon per-item.
  /// Formula: setiap item = (harga * qty) - diskon_nominal_per_item
  /// Diskon nominal: dikurangi dari harga satuan, baru dikali qty
  /// Diskon persen: % dari subtotal item, baru dikali qty
  int get totalPrice {
    int total = 0;
    items.forEach((productId, qty) {
      final price = _priceCache[productId] ?? 0;
      final rawSubtotal = price * qty;
      final disc = discounts[productId];
      if (disc == null) {
        total += rawSubtotal;
      } else if (disc.type == 'NOMINAL') {
        // Diskon nominal per pcs: (harga - nominal) * qty
        final hargaStlh = (price - disc.value).clamp(0, price).toInt();
        total += hargaStlh * qty;
      } else {
        // Diskon persen: subtotal - %
        final nominalDiskon = (rawSubtotal * disc.value / 100).round();
        total += rawSubtotal - nominalDiskon;
      }
    });
    return total;
  }

  /// Estimasi hemat — selisih totalRaw dan totalPrice.
  int get totalDiscount => totalRaw - totalPrice;

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
    required Map<String, DiscountInfo> existingDiscounts,
    required String existingNotes,
  }) {
    editingOrderId = orderId;
    this.customerId = customerId;
    this.customerName = customerName;
    this.customerAddress = customerAddress;
    items = Map<String, int>.from(existingItems);
    discounts = Map<String, DiscountInfo>.from(existingDiscounts);
    notes = existingNotes;
    notifyListeners();
  }

  void reset() {
    customerId = null;
    customerName = null;
    customerAddress = null;
    items = {};
    discounts = {};
    notes = '';
    editingOrderId = null;
    notifyListeners();
  }

  bool get hasCustomer => customerId != null;
  bool get hasItems => items.values.any((q) => q > 0);
  int get totalItems => items.values.fold(0, (a, b) => a + b);
  bool get isEditing => editingOrderId != null;
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
