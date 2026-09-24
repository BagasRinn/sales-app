import 'package:flutter/foundation.dart';
import '../../data/models/customer.dart';

/// Single source of truth untuk flow order (Step 1 → 2 → 3 + edit draft).
class DraftOrderProvider extends ChangeNotifier {
  String? customerId;
  String? customerName;
  String? customerAddress;
  Map<String, int> items = {}; // productId -> qty
  Map<String, int> discounts = {}; // productId -> discount_percent (0-100)
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

  void setDiscount(String productId, int percent) {
    final clamped = percent.clamp(0, 100);
    if (clamped == 0) {
      discounts.remove(productId);
    } else {
      discounts[productId] = clamped;
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
    required Map<String, int> existingDiscounts,
    required String existingNotes,
  }) {
    editingOrderId = orderId;
    this.customerId = customerId;
    this.customerName = customerName;
    this.customerAddress = customerAddress;
    items = Map<String, int>.from(existingItems);
    discounts = Map<String, int>.from(existingDiscounts);
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
      final diskon = discounts[productId] ?? 0;
      final hargaNet = (price * (100 - diskon) / 100).round();
      total += hargaNet * qty;
    });
    return total;
  }

  int get totalDiscount {
    int total = 0;
    items.forEach((productId, qty) {
      final price = _priceCache[productId] ?? 0;
      final diskon = discounts[productId] ?? 0;
      total += (price * diskon / 100).round() * qty;
    });
    return total;
  }
}
