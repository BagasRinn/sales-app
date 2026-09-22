import 'package:flutter/foundation.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/product.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList();

  int get totalItems => _items.values.fold(0, (sum, item) => sum + item.qty);

  int get totalHarga =>
      _items.values.fold(0, (sum, item) => sum + item.subtotal);

  bool get isEmpty => _items.isEmpty;

  void addProduct(Product product, {int qty = 1}) {
    if (_items.containsKey(product.id)) {
      final existing = _items[product.id]!;
      final maxAdd = product.stokTersedia - existing.qty;
      if (maxAdd > 0) {
        existing.qty += (qty > maxAdd ? maxAdd : qty);
      }
    } else {
      _items[product.id] = CartItem(
        productId: product.id,
        namaBarang: product.namaBarang,
        harga: product.harga,
        stokTersedia: product.stokTersedia,
        satuan: product.satuan,
        qty: qty > product.stokTersedia ? product.stokTersedia : qty,
      );
    }
    notifyListeners();
  }

  void removeProduct(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void updateQty(String productId, int qty) {
    if (!_items.containsKey(productId)) return;
    if (qty <= 0) {
      _items.remove(productId);
    } else {
      _items[productId]!.qty = qty;
    }
    notifyListeners();
  }

  void incrementQty(String productId, int maxAvailable) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.qty < maxAvailable) {
      _items[productId]!.qty++;
      notifyListeners();
    }
  }

  void decrementQty(String productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.qty > 1) {
      _items[productId]!.qty--;
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> toOrderItems() {
    return _items.values.map((item) => item.toOrderItem()).toList();
  }
}
