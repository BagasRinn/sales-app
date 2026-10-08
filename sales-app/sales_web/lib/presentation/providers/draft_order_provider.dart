import 'package:flutter/foundation.dart';
import '../../data/models/customer.dart';
import '../../data/models/product.dart';
import '../../data/models/order.dart';

class OrderLine {
  final String id;
  final String productId;
  final String namaBarang;
  final int hargaSatuan;
  int qty;
  ItemDiscount discount;

  OrderLine({
    required this.id,
    required this.productId,
    required this.namaBarang,
    required this.hargaSatuan,
    this.qty = 1,
    ItemDiscount? discount,
  }) : discount = discount ?? ItemDiscount();

  int get hargaSetelahDiskon {
    int price = hargaSatuan;
    if (discount.layer1 != null) price -= discount.layer1!.cutFrom(price);
    if (discount.layer2 != null) price -= discount.layer2!.cutFrom(price);
    if (discount.layer3 != null) price -= discount.layer3!.cutFrom(price);
    return price < 0 ? 0 : price;
  }

  int get subtotal => hargaSetelahDiskon * qty;
}

class DiscountLayer {
  final String type; // 'PERCENT' or 'NOMINAL'
  final int value;

  DiscountLayer({required this.type, required this.value});

  int cutFrom(int price) {
    if (value <= 0) return 0;
    if (type == 'PERCENT') return (price * value / 100).round();
    return value > price ? price : value;
  }

  Map<String, dynamic> toJson() => {'type': type, 'value': value};
}

class ItemDiscount {
  DiscountLayer? layer1;
  DiscountLayer? layer2;
  DiscountLayer? layer3;

  ItemDiscount({this.layer1, this.layer2, this.layer3});

  bool get isEmpty => layer1 == null && layer2 == null && layer3 == null;

  ItemDiscount withLayer(int layer, String type, int value) {
    final dl = DiscountLayer(type: type, value: value);
    final copy = ItemDiscount(layer1: layer1, layer2: layer2, layer3: layer3);
    if (layer == 1) copy.layer1 = dl;
    if (layer == 2) copy.layer2 = dl;
    if (layer == 3) copy.layer3 = dl;
    return copy;
  }

  Map<String, dynamic> toJson() => {
    'layer1': layer1 != null ? {'type': layer1!.type, 'value': layer1!.value} : null,
    'layer2': layer2 != null ? {'type': layer2!.type, 'value': layer2!.value} : null,
    'layer3': layer3 != null ? {'type': layer3!.type, 'value': layer3!.value} : null,
  };
}

class DraftOrderProvider with ChangeNotifier {
  String? _customerId;
  String? _customerName;
  String? _customerAddress;
  List<OrderLine> _items = [];
  String? _notes;
  String _orderType = 'REGULER';
  String? _editingOrderId;

  String? get customerId => _customerId;
  String? get customerName => _customerName;
  String? get customerAddress => _customerAddress;
  List<OrderLine> get items => _items;
  String? get notes => _notes;
  String get orderType => _orderType;
  String? get editingOrderId => _editingOrderId;

  int get totalRaw => _items.fold(0, (sum, item) => sum + (item.hargaSatuan * item.qty));
  int get totalPrice => _items.fold(0, (sum, item) => sum + item.subtotal);
  int get totalDiscount => totalRaw - totalPrice;
  int get totalQty => _items.fold(0, (sum, item) => sum + item.qty);

  void setCustomer(Customer customer) {
    _customerId = customer.id;
    _customerName = customer.namaToko;
    _customerAddress = customer.alamat;
    notifyListeners();
  }

  void setCustomerDirect({required String id, required String namaToko}) {
    _customerId = id;
    _customerName = namaToko;
    _customerAddress = null;
    notifyListeners();
  }

  void setOrderType(String type) {
    _orderType = type;
    notifyListeners();
  }

  void setNotes(String? notes) {
    _notes = notes;
  }

  void addItem(Product product) {
    final existing = _items.where((i) => i.productId == product.id).toList();
    if (existing.isNotEmpty) {
      existing.first.qty++;
    } else {
      _items.add(OrderLine(
        id: '${product.id}_${DateTime.now().millisecondsSinceEpoch}',
        productId: product.id,
        namaBarang: product.namaBarang,
        hargaSatuan: product.harga,
        qty: 1,
      ));
    }
    notifyListeners();
  }

  void removeItem(String lineId) {
    _items.removeWhere((i) => i.id == lineId);
    notifyListeners();
  }

  void setQty(String lineId, int qty) {
    final item = _items.where((i) => i.id == lineId).toList();
    if (item.isNotEmpty) {
      if (qty <= 0) {
        _items.removeWhere((i) => i.id == lineId);
      } else {
        item.first.qty = qty;
      }
    }
    notifyListeners();
  }

  void setDiscount(String lineId, int layer, String type, int value) {
    final item = _items.where((i) => i.id == lineId).toList();
    if (item.isNotEmpty) {
      item.first.discount = item.first.discount.withLayer(layer, type, value);
    }
    notifyListeners();
  }

  void loadFromExisting(Order order) {
    _editingOrderId = order.id;
    _customerId = order.customerId;
    _customerName = order.customerName;
    _customerAddress = order.storeAddress;
    _orderType = order.orderType;
    _notes = order.notes;
    _items = order.items.map((item) {
      final line = OrderLine(
        id: '${item.productId}_${DateTime.now().millisecondsSinceEpoch}',
        productId: item.productId,
        namaBarang: item.namaBarang ?? '',
        hargaSatuan: item.hargaSatuan,
        qty: item.qty,
      );
      // Copy discount from order item
      line.discount = ItemDiscount(
        layer1: item.discount.layer1 != null
            ? DiscountLayer(
                type: item.discount.layer1!.type.name.toUpperCase(),
                value: item.discount.layer1!.value,
              )
            : null,
        layer2: item.discount.layer2 != null
            ? DiscountLayer(
                type: item.discount.layer2!.type.name.toUpperCase(),
                value: item.discount.layer2!.value,
              )
            : null,
        layer3: item.discount.layer3 != null
            ? DiscountLayer(
                type: item.discount.layer3!.type.name.toUpperCase(),
                value: item.discount.layer3!.value,
              )
            : null,
      );
      return line;
    }).toList();
    notifyListeners();
  }

  List<Map<String, dynamic>> buildItemsPayload() {
    return _items.map((item) => {
      'product_id': item.productId,
      'qty': item.qty,
      'discount': item.discount.toJson(),
    }).toList();
  }

  void reset() {
    _customerId = null;
    _customerName = null;
    _customerAddress = null;
    _items = [];
    _notes = null;
    _orderType = 'REGULER';
    _editingOrderId = null;
    notifyListeners();
  }
}
