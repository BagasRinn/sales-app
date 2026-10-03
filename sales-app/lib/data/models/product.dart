class Product {
  final String id;
  final String namaBarang;
  final int harga;
  final int stokSistem;
  final int stokBooking;
  // Qty APPROVED (barang sudah diterima). Backend (sesuai revisi sistem
  // stok) mengirim field ini; parser toleran supaya app versi lama tidak
  // crash kalau backend lupa kirim, default 0.
  final int stokDiterima;
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
    this.stokDiterima = 0,
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
      // Field stok toleran (default 0) supaya partial rollout aman —
      // app lama tidak crash kalau backend lupa kirim salah satu field.
      stokSistem: (json['stok_sistem'] as int?) ?? 0,
      stokBooking: (json['stok_booking'] as int?) ?? 0,
      stokDiterima: (json['stok_diterima'] as int?) ?? 0,
      stokTersedia: (json['stok_tersedia'] as int?) ?? 0,
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
      'stok_diterima': stokDiterima,
      'stok_tersedia': stokTersedia,
      'perlu_ditinjau': perluDitinjau,
      'kategori': kategori,
      'satuan': satuan,
      'nama_supplier': namaSupplier,
      'order_type': orderType,
    };
  }
}
