import '../../core/datetime_utils.dart';

class Customer {
  final String id;
  final String? kode;
  final String namaToko;
  final String? alamat;
  /// Pengelompokan customer per area/rayon. Optional — null untuk legacy.
  final String? kodeArea;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? branch;
  final String? branchNama;

  Customer({
    required this.id,
    required this.namaToko,
    this.kode,
    this.alamat,
    this.kodeArea,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.branch,
    this.branchNama,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      kode: json['kode'] as String?,
      namaToko: json['nama_toko'] as String,
      alamat: json['alamat'] as String?,
      // Toleran: backend bisa kirim 'kode_area' (snake_case) atau 'kodeArea'
      // (camelCase, kalau pernah pakai serializer lain).
      kodeArea: (json['kode_area'] as String?) ?? (json['kodeArea'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String).toWita(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toWita(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String).toWita()
          : null,
      branch: json['branch'] as String?,
      branchNama: json['branch_nama'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kode': kode,
      'nama_toko': namaToko,
      'alamat': alamat,
      'kode_area': kodeArea,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'branch': branch,
      'branch_nama': branchNama,
    };
  }
}
