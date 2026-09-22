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
    };
  }
}
