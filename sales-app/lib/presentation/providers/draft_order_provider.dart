import 'package:flutter/foundation.dart';
import '../../data/models/customer.dart';
import '../../data/models/order.dart';

/// Single source of truth untuk flow order (Step 1 → 2 → 3 + edit draft).
class DraftOrderProvider extends ChangeNotifier {
  String? customerId;
  String? customerName;
  String? customerAddress;

  /// Daftar line item — bisa ada multiple line untuk produk yang sama
  /// (untuk mencatat promo "beli X gratis Y" secara manual).
  List<OrderLine> items = [];

  String notes = '';
  String? editingOrderId;
  String? editingOriginalStatus;

  String orderType = 'REGULER';

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

  // -------------------------------------------------------------------------
  // Line-based API (new)
  // -------------------------------------------------------------------------

  /// Tambah satu line baru. Append ke akhir list.
  OrderLine addLine(String productId, {int qty = 1, ItemDiscount? discount}) {
    final line = OrderLine(
      id: _generateId(),
      productId: productId,
      qty: qty,
      discount: discount,
    );
    items = [...items, line];
    notifyListeners();
    return line;
  }

  /// Hapus line by id.
  void removeLine(String lineId) {
    items = items.where((l) => l.id != lineId).toList();
    notifyListeners();
  }

  /// Set qty untuk line by id. Kalau qty <= 0 → removeLine.
  void setLineQty(String lineId, int qty) {
    if (qty <= 0) {
      removeLine(lineId);
      return;
    }
    items = items.map((l) {
      if (l.id == lineId) {
        return l.copyWith(qty: qty);
      }
      return l;
    }).toList();
    notifyListeners();
  }

  /// Set satu layer diskon untuk line by id. [layer] harus 1, 2, atau 3.
  void setDiscountLayer({
    required String lineId,
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

    final lineIndex = items.indexWhere((l) => l.id == lineId);
    if (lineIndex < 0) return;
    final line = items[lineIndex];

    final existing = line.discount ?? const ItemDiscount();
    DiscountLayer? newLayer;
    if (value <= 0) {
      newLayer = null;
    } else {
      int capped = value;
      if (type == 'PERCENT' && value > 100) {
        capped = 100;
      }
      if (type == 'NOMINAL') {
        final price = _priceCache[line.productId] ?? 0;
        final max = price * line.qty;
        capped = value > max ? max : value;
      }
      newLayer = DiscountLayer(type: type, value: capped);
    }

    final updated = existing.withLayer(layer, newLayer);
    final newDiscount = updated.isEmpty ? null : updated;
    items = [
      for (int i = 0; i < items.length; i++)
        if (i == lineIndex) line.copyWith(discount: newDiscount) else items[i],
    ];
    notifyListeners();
  }

  /// Lookup helpers.
  OrderLine? getLineById(String lineId) {
    for (final l in items) {
      if (l.id == lineId) return l;
    }
    return null;
  }

  /// Semua line untuk satu productId.
  List<OrderLine> linesForProduct(String productId) {
    return items.where((l) => l.productId == productId).toList();
  }

  /// Total qty untuk satu productId (semua line dijumlahkan).
  int totalQtyForProduct(String productId) {
    return linesForProduct(productId)
        .fold(0, (sum, l) => sum + l.qty);
  }

  // -------------------------------------------------------------------------
  // Legacy API — backward compat untuk caller yang masih pakai Map<productId, qty>
  // Dipakai step_pick_products & step_review saat belum di-convert.
  // Implementasi: beroperasi di line PERTAMA untuk produk tersebut.
  // -------------------------------------------------------------------------

  /// Legacy: set qty untuk produk (line pertama). qty=0 → removeLine(line pertama).
  void setQty(String productId, int qty) {
    final lines = linesForProduct(productId);
    if (lines.isEmpty) {
      if (qty > 0) {
        addLine(productId, qty: qty);
      }
      return;
    }
    final first = lines.first;
    setLineQty(first.id, qty);
  }

  /// Legacy: set layer diskon untuk produk (line pertama).
  void setDiscountLayerLegacy({
    required String productId,
    required int layer,
    required String type,
    required int value,
  }) {
    final lines = linesForProduct(productId);
    if (lines.isEmpty) return;
    setDiscountLayer(lineId: lines.first.id, layer: layer, type: type, value: value);
  }

  // -------------------------------------------------------------------------
  // Computed totals
  // -------------------------------------------------------------------------

  /// Total harga TANPA diskon — harga dasar semua item.
  int get totalRaw {
    int total = 0;
    for (final line in items) {
      final price = _priceCache[line.productId] ?? 0;
      total += price * line.qty;
    }
    return total;
  }

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

  /// Total harga setelah 3-layer diskon sequential per-line.
  int get totalPrice {
    int total = 0;
    for (final line in items) {
      final price = _priceCache[line.productId] ?? 0;
      final rawSubtotal = price * line.qty;
      final r = _applyItemLayers(rawSubtotal, line.discount);
      total += r.subtotal;
    }
    return total;
  }

  int get discountLayer1Total {
    int total = 0;
    for (final line in items) {
      final price = _priceCache[line.productId] ?? 0;
      final r = _applyItemLayers(price * line.qty, line.discount);
      total += r.d1;
    }
    return total;
  }

  int get discountLayer2Total {
    int total = 0;
    for (final line in items) {
      final price = _priceCache[line.productId] ?? 0;
      final r = _applyItemLayers(price * line.qty, line.discount);
      total += r.d2;
    }
    return total;
  }

  int get discountLayer3Total {
    int total = 0;
    for (final line in items) {
      final price = _priceCache[line.productId] ?? 0;
      final r = _applyItemLayers(price * line.qty, line.discount);
      total += r.d3;
    }
    return total;
  }

  /// Estimasi hemat — selisih totalRaw dan totalPrice.
  int get totalDiscount => totalRaw - totalPrice;

  /// Jumlah line yang adalah "GRATIS" (layer1 >= 100%).
  int get freeItemsCount {
    int count = 0;
    for (final line in items) {
      if (line.isFree) count += line.qty;
    }
    return count;
  }

  void setNotes(String value) {
    notes = value;
    notifyListeners();
  }

  /// Load dari existing order rows — rehydrate `List<OrderLine>`.
  void loadFromExisting({
    required String orderId,
    required String customerId,
    required String customerName,
    required String? customerAddress,
    required List<OrderLine> existingLines,
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
    items = List<OrderLine>.from(existingLines);
    notes = existingNotes;
    notifyListeners();
  }

  void reset() {
    customerId = null;
    customerName = null;
    customerAddress = null;
    items = [];
    notes = '';
    editingOrderId = null;
    editingOriginalStatus = null;
    orderType = 'REGULER';
    notifyListeners();
  }

  bool get hasCustomer => customerId != null;
  bool get hasItems => items.any((l) => l.qty > 0);
  int get totalItems => items.fold(0, (sum, l) => sum + l.qty);
  bool get isEditing => editingOrderId != null;
  bool get isEditingPending => isEditing && editingOriginalStatus == 'PENDING';

  // -------------------------------------------------------------------------
  // Submit helpers
  // -------------------------------------------------------------------------

  /// Bangun payload items untuk submit ke backend.
  /// Loop semua line, skip qty=0, build ItemDiscount.toJson per line.
  List<Map<String, dynamic>> buildItemsPayload() {
    final result = <Map<String, dynamic>>[];
    for (final line in items) {
      if (line.qty <= 0) continue;
      final base = <String, dynamic>{
        'product_id': line.productId,
        'qty': line.qty,
      };
      if (line.discount != null) {
        base.addAll(line.discount!.toJson());
      }
      result.add(base);
    }
    return result;
  }

  String _generateId() {
    // Gunakan timestamp + random sebagai simple ID
    return '${DateTime.now().microsecondsSinceEpoch}_${(1000 + (mathRandom() * 9000).toInt())}';
  }
}

double mathRandom() => (DateTime.now().microsecondsSinceEpoch % 1000) / 1000;

/// Satu baris item di cart. Boleh ada banyak baris untuk produk yang sama.
class OrderLine {
  final String id;         // client UUID, stabil across edits + rehydrate
  final String productId;
  int qty;
  ItemDiscount? discount;

  OrderLine({
    required this.id,
    required this.productId,
    required this.qty,
    this.discount,
  });

  /// Layer1 >= 100% PERCENT → label "GRATIS".
  bool get isFree {
    final l1 = discount?.layer1;
    return l1 != null && l1.type == 'PERCENT' && l1.value >= 100;
  }

  OrderLine copyWith({int? qty, ItemDiscount? discount, bool clearDiscount = false}) {
    return OrderLine(
      id: id,
      productId: productId,
      qty: qty ?? this.qty,
      discount: clearDiscount ? null : (discount ?? this.discount),
    );
  }
}

/// Satu layer diskon.
class DiscountLayer {
  final String type; // 'PERCENT' atau 'NOMINAL'
  final int value;

  const DiscountLayer({required this.type, required this.value});

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

/// Kumpulan 3 layer diskon untuk satu item.
class ItemDiscount {
  final DiscountLayer? layer1;
  final DiscountLayer? layer2;
  final DiscountLayer? layer3;

  const ItemDiscount({this.layer1, this.layer2, this.layer3});

  bool get isEmpty => layer1 == null && layer2 == null && layer3 == null;

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
