class Product {
  final String id;
  final String namaBarang;
  final int harga;
  final int stokSistem;
  final int stokBooking;
  final int stokTersedia;
  final bool? perluDitinjau;
  final String? kategori;
  final String? satuan;
  final String? namaSupplier;

  /// Tipe order: 'REGULER' (default) atau '4P'. Filter produk di order flow.
  final String orderType;

  Product({
    required this.id,
    required this.namaBarang,
    required this.harga,
    required this.stokSistem,
    required this.stokBooking,
    required this.stokTersedia,
    this.perluDitinjau,
    this.kategori,
    this.satuan,
    this.namaSupplier,
    this.orderType = 'REGULER',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      namaBarang: json['nama_barang'] as String,
      harga: json['harga'] as int,
      stokSistem: json['stok_sistem'] as int,
      stokBooking: json['stok_booking'] as int,
      stokTersedia: json['stok_tersedia'] as int,
      perluDitinjau: json['perlu_ditinjau'] as bool?,
      kategori: json['kategori'] as String?,
      satuan: json['satuan'] as String?,
      namaSupplier: json['nama_supplier'] as String?,
      orderType: (json['order_type'] as String?) ?? 'REGULER',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama_barang': namaBarang,
      'harga': harga,
      'stok_sistem': stokSistem,
      'stok_booking': stokBooking,
      'stok_tersedia': stokTersedia,
      'perlu_ditinjau': perluDitinjau,
      'kategori': kategori,
      'satuan': satuan,
      'nama_supplier': namaSupplier,
      'order_type': orderType,
    };
  }
}
