import '../../core/datetime_utils.dart';

class Customer {
  final String id;
  final String? kode;
  final String namaToko;
  final String? alamat;
  /// Pengelompokan per area/rayon. Optional — null untuk customer yang
  /// belum punya kode_area. Sales mobile cuma baca displayName + area saja
  /// untuk info; sales tidak perlu tau sales lain yang di-assign ke customer.
  final String? kodeArea;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  Customer({
    required this.id,
    required this.namaToko,
    this.kode,
    this.alamat,
    this.kodeArea,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      kode: json['kode'] as String?,
      namaToko: json['nama_toko'] as String,
      alamat: json['alamat'] as String?,
      // Toleran: backend bisa kirim 'kode_area' (snake_case) atau 'kodeArea'
      // (camelCase, untuk serializer lain). Default null kalau tidak ada.
      kodeArea: (json['kode_area'] as String?) ?? (json['kodeArea'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toWita()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)?.toWita()
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)?.toWita()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kode': kode,
      'nama_toko': namaToko,
      'alamat': alamat,
      'kode_area': kodeArea,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}