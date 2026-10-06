import 'package:flutter/material.dart';

import '../../../core/design_system.dart';
import '../../../data/models/customer_submission.dart';

/// Read-only detail submission. Dipakai sales buat lihat status + alasan reject.
class CustomerSubmissionDetailScreen extends StatelessWidget {
  final CustomerSubmission submission;

  const CustomerSubmissionDetailScreen({super.key, required this.submission});

  @override
  Widget build(BuildContext context) {
    final s = submission;
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pengajuan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusBanner(submission: s),
          const SizedBox(height: 16),
          _SectionCard(title: 'Identitas', children: [
            _Row(label: 'Nama Langganan', value: s.namaLangganan),
            _Row(label: 'Nomor ID / KTP', value: s.nomorIdKtp),
            _Row(label: 'Alamat KTP', value: s.alamatKtp),
            _Row(label: 'Nama Kontak', value: s.namaKontakPemilik),
            _Row(label: 'Telpon / HP', value: s.telponHp),
            _Row(label: 'Alamat Kirim', value: s.alamatKirim),
            _Row(label: 'Propinsi', value: s.propinsi),
            _Row(label: 'Kecamatan', value: s.kecamatan),
            _Row(label: 'Kota', value: s.kota),
            _Row(label: 'Kelurahan', value: s.kelurahan),
            _Row(label: 'Area / Route', value: s.areaRoute),
            _Row(label: 'Tipe Langganan', value: s.tipeLangganan),
          ]),
          _SectionCard(title: 'Pembayaran', children: [
            _Row(label: 'Tipe Pembayaran', value: s.tipePembayaran),
            _Row(label: 'Nama Pasar', value: s.namaPasar),
            _Row(
              label: 'Jangka Kredit',
              value: s.jangkaKreditHari != null ? '${s.jangkaKreditHari} hari' : null,
            ),
            _Row(
              label: 'Batas Kredit',
              value: s.batasKreditRupiah != null
                  ? 'Rp ${_fmtNumber(s.batasKreditRupiah!)}'
                  : null,
            ),
          ]),
          _SectionCard(title: 'Channel & Salesman', children: [
            _Row(label: 'Channel / Kategori', value: s.channelKategori),
            _Row(label: 'Key Account (REF ID)', value: s.keyAccountRefId),
            _Row(label: 'Cluster', value: s.clusterLangganan),
            _Row(label: 'Kode Salesman', value: s.kodeSalesman),
            _Row(label: 'Nama Salesman', value: s.namaSalesman),
            _Row(label: 'Siklus Kunjungan', value: s.siklusKunjungan),
            _Row(label: 'Hari Kunjungan', value: s.hariKunjungan),
          ]),
          _SectionCard(title: 'Audit', children: [
            _Row(label: 'Diajukan oleh', value: s.salesNama ?? s.salesUsername),
            _Row(label: 'Tanggal Submit', value: _formatDate(s.createdAt)),
            if (s.reviewedByNama != null) ...[
              _Row(
                label: s.status == 'APPROVED' ? 'Disetujui oleh' : 'Ditolak oleh',
                value: s.reviewedByNama,
              ),
              _Row(label: 'Tanggal Review', value: _formatDate(s.reviewedAt!)),
            ],
            if (s.status == 'REJECTED' && s.rejectReason != null)
              _Row(label: 'Alasan Ditolak', value: s.rejectReason),
          ]),
        ],
      ),
    );
  }

  String _fmtNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBanner extends StatelessWidget {
  final CustomerSubmission submission;
  const _StatusBanner({required this.submission});

  @override
  Widget build(BuildContext context) {
    final color = _color(submission.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(_icon(submission.status), color: color, size: 22),
          const SizedBox(width: 10),
          Text(
            submission.statusLabel,
            style: AppTextStyles.bodyLarge.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _color(String status) {
    switch (status) {
      case 'APPROVED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  IconData _icon(String status) {
    switch (status) {
      case 'APPROVED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      default:
        return Icons.hourglass_top;
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value == null || value!.isEmpty ? '-' : value!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
