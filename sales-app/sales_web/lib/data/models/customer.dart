class Customer {
  final String id;
  final String? kode;
  final String namaToko;
  final String? alamat;
  final String? kodeArea;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Customer({
    required this.id,
    this.kode,
    required this.namaToko,
    this.alamat,
    this.kodeArea,
    this.createdAt,
    this.updatedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      kode: json['kode'] as String?,
      namaToko: (json['nama_toko'] ?? json['namaToko'] ?? json['nama']) as String? ?? '',
      alamat: json['alamat'] as String?,
      kodeArea: (json['kode_area'] ?? json['kodeArea']) as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }
}
