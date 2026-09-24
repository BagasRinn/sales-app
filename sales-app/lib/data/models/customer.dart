class Customer {
  final String id;
  final String? kode;
  final String namaToko;
  final String? alamat;

  Customer({
    required this.id,
    required this.namaToko,
    this.kode,
    this.alamat,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      kode: json['kode'] as String?,
      namaToko: json['nama_toko'] as String,
      alamat: json['alamat'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kode': kode,
      'nama_toko': namaToko,
      'alamat': alamat,
    };
  }
}