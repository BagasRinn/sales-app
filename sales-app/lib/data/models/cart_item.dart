class CartItem {
  final String productId;
  final String namaBarang;
  final int harga;
  final int stokTersedia;
  final String? satuan;
  int qty;

  CartItem({
    required this.productId,
    required this.namaBarang,
    required this.harga,
    required this.stokTersedia,
    this.satuan,
    required this.qty,
  });

  int get subtotal => harga * qty;

  Map<String, dynamic> toOrderItem() {
    return {
      'product_id': productId,
      'qty': qty,
    };
  }
}
