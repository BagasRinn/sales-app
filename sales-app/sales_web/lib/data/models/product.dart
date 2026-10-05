class Product {
  final String id;
  final String namaBarang;
  final int harga;
  final int stokSistem;
  final int stokBooking;
  final int stokDiterima;
  final int stokTersedia;
  final bool? perluDitinjau;
  final String? kategori;
  final String? satuan;
  final String? namaSupplier;
  final String orderType;

  Product({
    required this.id,
    required this.namaBarang,
    required this.harga,
    required this.stokSistem,
    required this.stokBooking,
    required this.stokDiterima,
    required this.stokTersedia,
    this.perluDitinjau,
    this.kategori,
    this.satuan,
    this.namaSupplier,
    this.orderType = 'REGULER',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final stokSistem = json['stok_sistem'] as int? ?? 0;
    final stokBooking = json['stok_booking'] as int? ?? 0;
    final stokDiterima = json['stok_diterima'] as int? ?? 0;

    return Product(
      id: json['id'] as String,
      namaBarang: json['nama_barang'] as String,
      harga: json['harga'] as int,
      stokSistem: stokSistem,
      stokBooking: stokBooking,
      stokDiterima: stokDiterima,
      stokTersedia: stokSistem - stokBooking + stokDiterima,
      perluDitinjau: json['perlu_ditinjau'] as bool?,
      kategori: json['kategori'] as String?,
      satuan: json['satuan'] as String?,
      namaSupplier: json['nama_supplier'] as String?,
      orderType: json['order_type'] as String? ?? 'REGULER',
    );
  }
}
