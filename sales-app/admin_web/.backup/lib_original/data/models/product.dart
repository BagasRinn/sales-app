class Product {
  final String id;
  final String namaBarang;
  final int harga;
  final int stokSistem;
  final int stokBooking;
  // Qty yang sudah di-approve. Backend (sesuai revisi sistem stok) selalu
  // mengirim field ini; kalau backend lupa, parser toleran dan default 0.
  final int stokDiterima;
  final int stokTersedia;
  final String? kategori;
  final String? satuan;
  final String? namaSupplier;
  final String orderType;
  final String? branch;
  final String? branchNama;

  Product({
    required this.id,
    required this.namaBarang,
    required this.harga,
    required this.stokSistem,
    required this.stokBooking,
    required this.stokDiterima,
    required this.stokTersedia,
    this.kategori,
    this.satuan,
    this.namaSupplier,
    this.orderType = 'REGULER',
    this.branch,
    this.branchNama,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      namaBarang: json['nama_barang'] ?? '',
      harga: json['harga'] ?? 0,
      stokSistem: json['stok_sistem'] ?? 0,
      stokBooking: json['stok_booking'] ?? 0,
      stokDiterima: (json['stok_diterima'] as int?) ?? 0,
      stokTersedia: json['stok_tersedia'] ?? 0,
      kategori: json['kategori'] as String?,
      satuan: json['satuan'] as String?,
      namaSupplier: json['nama_supplier'] as String?,
      orderType: (json['order_type'] as String?) ?? 'REGULER',
      branch: json['branch'] as String?,
      branchNama: json['branch_nama'] as String?,
    );
  }
}
