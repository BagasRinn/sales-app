import '../../core/datetime_utils.dart';

class CustomerSubmission {
  final String id;
  final String salesId;
  final String? salesNama;
  final String? salesUsername;
  final String status; // PENDING | APPROVED | REJECTED
  final String? rejectReason;
  final String? approvedCustomerId;
  /// Customer ID yang langsung dibuat saat submission dengan bareng_order=True.
  final String? barengCustomerId;
  final String? reviewedBy;
  final String? reviewedByNama;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Form fields
  final String namaLangganan;
  final String? nomorIdKtp;
  final String? alamatKtp;
  final String? namaKontakPemilik;
  final String? telponHp;
  final String? alamatKirim;
  final String? propinsi;
  final String? kecamatan;
  final String? kota;
  final String? kelurahan;
  final String? areaRoute;
  final String? tipeLangganan;
  final String? tipePembayaran;
  final String? namaPasar;
  final int? jangkaKreditHari;
  final int? batasKreditRupiah;
  final String? channelKategori;
  final String? keyAccountRefId;
  final String? clusterLangganan;
  final String? kodeSalesman;
  final String? namaSalesman;
  final String? siklusKunjungan;
  final String? hariKunjungan;

  CustomerSubmission({
    required this.id,
    required this.salesId,
    this.salesNama,
    this.salesUsername,
    required this.status,
    this.rejectReason,
    this.approvedCustomerId,
    this.barengCustomerId,
    this.reviewedBy,
    this.reviewedByNama,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.namaLangganan,
    this.nomorIdKtp,
    this.alamatKtp,
    this.namaKontakPemilik,
    this.telponHp,
    this.alamatKirim,
    this.propinsi,
    this.kecamatan,
    this.kota,
    this.kelurahan,
    this.areaRoute,
    this.tipeLangganan,
    this.tipePembayaran,
    this.namaPasar,
    this.jangkaKreditHari,
    this.batasKreditRupiah,
    this.channelKategori,
    this.keyAccountRefId,
    this.clusterLangganan,
    this.kodeSalesman,
    this.namaSalesman,
    this.siklusKunjungan,
    this.hariKunjungan,
  });

  factory CustomerSubmission.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(String? s) =>
        s == null ? null : DateTime.parse(s).toWita();
    return CustomerSubmission(
      id: json['id'] as String,
      salesId: json['sales_id'] as String,
      salesNama: json['sales_nama'] as String?,
      salesUsername: json['sales_username'] as String?,
      status: json['status'] as String,
      rejectReason: json['reject_reason'] as String?,
      approvedCustomerId: json['approved_customer_id'] as String?,
      barengCustomerId: json['bareng_customer_id'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedByNama: json['reviewed_by_nama'] as String?,
      reviewedAt: parseDt(json['reviewed_at'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String).toWita(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toWita(),
      namaLangganan: json['nama_langganan'] as String,
      nomorIdKtp: json['nomor_id_ktp'] as String?,
      alamatKtp: json['alamat_ktp'] as String?,
      namaKontakPemilik: json['nama_kontak_pemilik'] as String?,
      telponHp: json['telpon_hp'] as String?,
      alamatKirim: json['alamat_kirim'] as String?,
      propinsi: json['propinsi'] as String?,
      kecamatan: json['kecamatan'] as String?,
      kota: json['kota'] as String?,
      kelurahan: json['kelurahan'] as String?,
      areaRoute: json['area_route'] as String?,
      tipeLangganan: json['tipe_langganan'] as String?,
      tipePembayaran: json['tipe_pembayaran'] as String?,
      namaPasar: json['nama_pasar'] as String?,
      jangkaKreditHari: json['jangka_kredit_hari'] as int?,
      batasKreditRupiah: json['batas_kredit_rupiah'] as int?,
      channelKategori: json['channel_kategori'] as String?,
      keyAccountRefId: json['key_account_ref_id'] as String?,
      clusterLangganan: json['cluster_langganan'] as String?,
      kodeSalesman: json['kode_salesman'] as String?,
      namaSalesman: json['nama_salesman'] as String?,
      siklusKunjungan: json['siklus_kunjungan'] as String?,
      hariKunjungan: json['hari_kunjungan'] as String?,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'PENDING':
        return 'Menunggu';
      case 'APPROVED':
        return 'Disetujui';
      case 'REJECTED':
        return 'Ditolak';
      default:
        return status;
    }
  }
}