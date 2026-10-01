import 'package:flutter/foundation.dart';
import '../../data/models/customer.dart';
import '../../data/models/order.dart';

/// Single source of truth untuk flow order (Step 1 → 2 → 3 + edit draft).
class DraftOrderProvider extends ChangeNotifier {
  String? customerId;
  String? customerName;
  String? customerAddress;
  Map<String, int> items = {}; // productId -> qty

  /// Diskon per item: productId -> ItemDiscount (3 layer stacked, sequential).
  /// Setiap item bisa punya sampai 3 layer diskon. Tiap layer bertipe
  /// 'PERCENT' (value 0-100) atau 'NOMINAL' (value dalam IDR per pcs).
  Map<String, ItemDiscount> discounts = {};

  String notes = '';
  String? editingOrderId;
  String? editingOriginalStatus; // 'DRAFT' atau 'PENDING' saat mulai edit — dipakai di submit flow

  /// Tipe order: 'REGULER' atau '4P'. Diset di Step 2 (pilih tipe), default REGULER.
  String orderType = 'REGULER';

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

  /// Set satu layer diskon untuk produk. [layer] harus 1, 2, atau 3.
  /// Value <= 0 akan menghapus layer tersebut (bukan menghapus produk).
  /// Kalau semua 3 layer kosong setelah update, entry produk dihapus dari map.
  void setDiscountLayer({
    required String productId,
    required int layer,
    required String type,
    required int value,
  }) {
    if (layer < 1 || layer > 3) {
      throw ArgumentError('layer harus 1, 2, atau 3 — dapat: $layer');
    }
    if (type != 'PERCENT' && type != 'NOMINAL') {
      throw ArgumentError(
          'discount type harus PERCENT atau NOMINAL, dapat: $type');
    }

    final existing = discounts[productId] ?? const ItemDiscount();
    DiscountLayer? newLayer;
    if (value <= 0) {
      newLayer = null;
    } else {
      int capped = value;
      if (type == 'PERCENT' && value > 100) {
        capped = 100;
      }
      if (type == 'NOMINAL') {
        // Cap ke raw_subtotal (harga × qty) — cap tertinggi yang mungkin.
        // Cap tambahan ke running residual setelah layer sebelumnya dilakukan
        // oleh kalkulasi (min()), bukan di sini.
        final harga = _priceCache[productId] ?? 0;
        final qty = items[productId] ?? 0;
        final max = harga * qty;
        capped = value > max ? max : value;
      }
      newLayer = DiscountLayer(type: type, value: capped);
    }

    final updated = existing.withLayer(layer, newLayer);
    if (updated.isEmpty) {
      discounts.remove(productId);
    } else {
      discounts[productId] = updated;
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

  /// Hitung chain 3 layer sequential untuk satu item.
  /// Return (final_subtotal, d1, d2, d3, total_discount).
  ({int subtotal, int d1, int d2, int d3, int total}) _applyItemLayers(
    int rawSubtotal,
    ItemDiscount? disc,
  ) {
    int s = rawSubtotal < 0 ? 0 : rawSubtotal;
    int d1 = 0, d2 = 0, d3 = 0;
    if (disc == null) return (subtotal: s, d1: 0, d2: 0, d3: 0, total: 0);

    if (disc.layer1 != null) {
      d1 = disc.layer1!.cutFrom(s);
      s -= d1;
    }
    if (disc.layer2 != null) {
      d2 = disc.layer2!.cutFrom(s);
      s -= d2;
    }
    if (disc.layer3 != null) {
      d3 = disc.layer3!.cutFrom(s);
      s -= d3;
    }
    return (subtotal: s, d1: d1, d2: d2, d3: d3, total: d1 + d2 + d3);
  }

  /// Total harga setelah 3-layer diskon sequential per-item.
  int get totalPrice {
    int total = 0;
    items.forEach((productId, qty) {
      final price = _priceCache[productId] ?? 0;
      final rawSubtotal = price * qty;
      final r = _applyItemLayers(rawSubtotal, discounts[productId]);
      total += r.subtotal;
    });
    return total;
  }

  /// Total potongan layer 1 (semua item).
  int get discountLayer1Total {
    int total = 0;
    items.forEach((productId, qty) {
      final price = _priceCache[productId] ?? 0;
      final r = _applyItemLayers(price * qty, discounts[productId]);
      total += r.d1;
    });
    return total;
  }

  int get discountLayer2Total {
    int total = 0;
    items.forEach((productId, qty) {
      final price = _priceCache[productId] ?? 0;
      final r = _applyItemLayers(price * qty, discounts[productId]);
      total += r.d2;
    });
    return total;
  }

  int get discountLayer3Total {
    int total = 0;
    items.forEach((productId, qty) {
      final price = _priceCache[productId] ?? 0;
      final r = _applyItemLayers(price * qty, discounts[productId]);
      total += r.d3;
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
    required Map<String, ItemDiscount> existingDiscounts,
    required String existingNotes,
    String? existingStatus,
    String existingOrderType = 'REGULER',
  }) {
    editingOrderId = orderId;
    editingOriginalStatus = existingStatus;
    orderType = existingOrderType;
    this.customerId = customerId;
    this.customerName = customerName;
    this.customerAddress = customerAddress;
    items = Map<String, int>.from(existingItems);
    discounts = Map<String, ItemDiscount>.from(existingDiscounts);
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
    editingOriginalStatus = null;
    orderType = 'REGULER';
    notifyListeners();
  }

  bool get hasCustomer => customerId != null;
  bool get hasItems => items.values.any((q) => q > 0);
  int get totalItems => items.values.fold(0, (a, b) => a + b);
  bool get isEditing => editingOrderId != null;
  bool get isEditingPending => isEditing && editingOriginalStatus == 'PENDING';
}

/// Satu layer diskon. Layer kosong = null di [ItemDiscount].
class DiscountLayer {
  final String type; // 'PERCENT' atau 'NOMINAL'
  final int value;

  const DiscountLayer({required this.type, required this.value});

  /// Potongan untuk layer ini dari running subtotal. NOMINAL di-cap ke running.
  int cutFrom(int running) {
    if (running <= 0) return 0;
    if (type == 'NOMINAL') {
      return value > running ? running : value;
    }
    return (running * value / 100).round();
  }

  Map<String, dynamic> toJsonFields(String typeKey, String percentKey, String nominalKey) {
    return {
      typeKey: type,
      percentKey: type == 'PERCENT' ? value : 0,
      nominalKey: type == 'NOMINAL' ? value : 0,
    };
  }
}

/// Kumpulan 3 layer diskon untuk satu item. Layer null = tidak ada diskon di layer tsb.
class ItemDiscount {
  final DiscountLayer? layer1;
  final DiscountLayer? layer2;
  final DiscountLayer? layer3;

  const ItemDiscount({this.layer1, this.layer2, this.layer3});

  bool get isEmpty =>
      layer1 == null && layer2 == null && layer3 == null;

  ItemDiscount withLayer(int layer, DiscountLayer? newLayer) {
    switch (layer) {
      case 1:
        return ItemDiscount(layer1: newLayer, layer2: layer2, layer3: layer3);
      case 2:
        return ItemDiscount(layer1: layer1, layer2: newLayer, layer3: layer3);
      case 3:
        return ItemDiscount(layer1: layer1, layer2: layer2, layer3: newLayer);
      default:
        throw ArgumentError('layer harus 1, 2, atau 3');
    }
  }

  /// Serialisasi untuk dikirim ke backend (9 field, cocok dengan Pydantic OrderItemCreate).
  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{};
    if (layer1 != null) {
      out.addAll(layer1!.toJsonFields('discount_type', 'discount_percent', 'discount_nominal'));
    } else {
      out.addAll({'discount_type': 'PERCENT', 'discount_percent': 0, 'discount_nominal': 0});
    }
    if (layer2 != null) {
      out.addAll(layer2!.toJsonFields('discount2_type', 'discount2_percent', 'discount2_nominal'));
    } else {
      out.addAll({'discount2_type': 'PERCENT', 'discount2_percent': 0, 'discount2_nominal': 0});
    }
    if (layer3 != null) {
      out.addAll(layer3!.toJsonFields('discount3_type', 'discount3_percent', 'discount3_nominal'));
    } else {
      out.addAll({'discount3_type': 'PERCENT', 'discount3_percent': 0, 'discount3_nominal': 0});
    }
    return out;
  }

  /// Build dari [OrderItem] (dipakai saat edit draft — rehydrate dari response).
  factory ItemDiscount.fromOrderItem(OrderItem item) {
    DiscountLayer? build(String type, int percent, int nominal) {
      if ((type == 'PERCENT' && percent > 0) ||
          (type == 'NOMINAL' && nominal > 0)) {
        return DiscountLayer(type: type, value: type == 'PERCENT' ? percent : nominal);
      }
      return null;
    }

    return ItemDiscount(
      layer1: build(item.discountType, item.discountPercent, item.discountNominal),
      layer2: build(item.discount2Type, item.discount2Percent, item.discount2Nominal),
      layer3: build(item.discount3Type, item.discount3Percent, item.discount3Nominal),
    );
  }
}
