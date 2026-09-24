class Customer {
  final String id;
  final String? kode;
  final String namaToko;
  final String? alamat;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Customer({
    required this.id,
    required this.namaToko,
    this.kode,
    this.alamat,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      kode: json['kode'] as String?,
      namaToko: json['nama_toko'] as String,
      alamat: json['alamat'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kode': kode,
      'nama_toko': namaToko,
      'alamat': alamat,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}