import 'package:flutter/foundation.dart';
import '../../data/models/customer.dart';

/// Single source of truth untuk flow order (Step 1 → 2 → 3 + edit draft).
class DraftOrderProvider extends ChangeNotifier {
  String? customerId;
  String? customerName;
  String? customerAddress;
  Map<String, int> items = {}; // productId -> qty

  /// Diskon per produk. Map ini simpan DiscountInfo (bukan int) supaya
  /// bisa support persen ATAU nominal, dipilih per produk.
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
      discounts.remove(productId);
    } else {
      items[productId] = qty;
    }
    notifyListeners();
  }

  /// Set diskon per produk. [type] = 'PERCENT' (value 0-100) atau 'NOMINAL' (value dalam IDR).
  /// value <= 0 akan menghapus entry (artinya tidak ada diskon).
  void setDiscount({
    required String productId,
    required String type,
    required int value,
  }) {
    if (type != 'PERCENT' && type != 'NOMINAL') {
      throw ArgumentError('discount type harus PERCENT atau NOMINAL, dapat: $type');
    }
    if (value <= 0) {
      discounts.remove(productId);
    } else {
      if (type == 'PERCENT' && value > 100) {
        throw ArgumentError('discount percent tidak boleh > 100');
      }
      if (type == 'NOMINAL') {
        final harga = _priceCache[productId] ?? 0;
        if (value > harga) {
          throw ArgumentError('discount nominal tidak boleh > harga satuan ($harga)');
        }
      }
      discounts[productId] = DiscountInfo(type: type, value: value);
    }
    notifyListeners();
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

  int get totalPrice {
    int total = 0;
    items.forEach((productId, qty) {
      final price = _priceCache[productId] ?? 0;
      final info = discounts[productId];
      final hargaNet = info == null
          ? price
          : info.type == 'NOMINAL'
              ? (price - info.value).clamp(0, price)
              : (price * (100 - info.value) / 100).round();
      total += hargaNet * qty;
    });
    return total;
  }

  int get totalDiscount {
    int total = 0;
    items.forEach((productId, qty) {
      final price = _priceCache[productId] ?? 0;
      final info = discounts[productId];
      if (info == null) return;
      if (info.type == 'NOMINAL') {
        total += info.value * qty;
      } else {
        total += (price * info.value / 100).round() * qty;
      }
    });
    return total;
  }
}

class DiscountInfo {
  final String type; // 'PERCENT' atau 'NOMINAL'
  final int value;

  const DiscountInfo({required this.type, required this.value});

  Map<String, dynamic> toJson() => {
        'discount_type': type,
        if (type == 'PERCENT') 'discount_percent': value,
        if (type == 'NOMINAL') 'discount_nominal': value,
      };

  factory DiscountInfo.percent(int value) =>
      DiscountInfo(type: 'PERCENT', value: value);
  factory DiscountInfo.nominal(int value) =>
      DiscountInfo(type: 'NOMINAL', value: value);

  /// Backward compat untuk data lama yang hanya simpan percent sebagai int.
  factory DiscountInfo.fromPercentInt(int value) =>
      DiscountInfo(type: 'PERCENT', value: value);
}
