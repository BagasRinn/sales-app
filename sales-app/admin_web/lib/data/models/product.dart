class Product {
  final String id;
  final String namaBarang;
  final int harga;
  final int stokSistem;
  final int stokBooking;
  final int stokTersedia;
  final String? kategori;
  final String? satuan;

  Product({
    required this.id,
    required this.namaBarang,
    required this.harga,
    required this.stokSistem,
    required this.stokBooking,
    required this.stokTersedia,
    this.kategori,
    this.satuan,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      namaBarang: json['nama_barang'] ?? '',
      harga: json['harga'] ?? 0,
      stokSistem: json['stok_sistem'] ?? 0,
      stokBooking: json['stok_booking'] ?? 0,
      stokTersedia: json['stok_tersedia'] ?? 0,
      kategori: json['kategori'] as String?,
      satuan: json['satuan'] as String?,
    );
  }
}
