import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system.dart';
import '../../../core/datetime_utils.dart';
import '../../../data/models/customer_submission.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../core/api_service.dart';
import '../../providers/auth_provider.dart';

class CustomerSubmissionDetailScreen extends StatefulWidget {
  final CustomerSubmission submission;

  const CustomerSubmissionDetailScreen({super.key, required this.submission});

  @override
  State<CustomerSubmissionDetailScreen> createState() => _CustomerSubmissionDetailScreenState();
}

class _CustomerSubmissionDetailScreenState extends State<CustomerSubmissionDetailScreen> {
  late final CustomerRepository _repo;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _repo = CustomerRepository(context.read<ApiService>());
    _currentUsername = context.read<AuthProvider>().username;
  }

  Future<void> _onBatalPressed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batalkan Pengajuan'),
        content: Text('Batalkan pengajuan "${widget.submission.namaLangganan}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.cancelSubmission(widget.submission.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan berhasil dibatalkan')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    final canBatal = s.status == 'PENDING' &&
        s.salesUsername == _currentUsername;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Pengajuan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusBanner(submission: s),
          const SizedBox(height: 16),

          if (s.order != null) ...[
            _OrderSection(order: s.order!),
            const SizedBox(height: 16),
          ],

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
            _Row(label: 'Nama pasar', value: s.namaPasar),
            _Row(label: 'Jangka Kredit', value: s.jangkaKreditHari != null ? '${s.jangkaKreditHari} hari' : null),
            _Row(label: 'Batas Kredit', value: s.batasKreditRupiah != null ? 'Rp ${_fmtNumber(s.batasKreditRupiah!)}' : null),
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

          if (canBatal) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _onBatalPressed,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Batal Pengajuan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
            ),
          ],
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
    return witaFormat(dt, pattern: 'dd/MM/yyyy HH:mm');
  }
}

// ─── Status Banner ──────────────────────────────────────────────────────────────

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
      case 'APPROVED': return AppColors.success;
      case 'REJECTED': return AppColors.error;
      default: return AppColors.warning;
    }
  }

  IconData _icon(String status) {
    switch (status) {
      case 'APPROVED': return Icons.check_circle;
      case 'REJECTED': return Icons.cancel;
      default: return Icons.hourglass_top;
    }
  }
}

// ─── Order Section ────────────────────────────────────────────────────────────

class _OrderSection extends StatelessWidget {
  final SubmissionOrder order;
  const _OrderSection({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Pesanan',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Container(height: 1, color: AppColors.border),
          if (order.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Tidak ada item', style: AppTextStyles.bodySmall),
            )
          else
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.namaBarang ?? item.productId,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.qty}x Rp ${_fmtNumber(item.hargaSatuan)}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Rp ${_fmtNumber(item.subtotal)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (order.items.isNotEmpty) Container(height: 1, color: AppColors.border),
          if (order.totalAmount != null)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text('Total', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(
                    'Rp ${_fmtNumber(order.totalAmount!)}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),
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
}

// ─── Section Card ─────────────────────────────────────────────────────────────

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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
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

// ─── Row Widget ───────────────────────────────────────────────────────────────

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
            child: Text(v, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
