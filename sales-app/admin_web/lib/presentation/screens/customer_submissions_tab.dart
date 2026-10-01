import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../providers/admin_provider.dart';
import '../../data/models/customer_submission.dart';

/// Tab "Pengajuan Customer" — list submissions dengan filter chips (Semua/PENDING/APPROVED/REJECTED).
/// Tap card → detail screen dengan semua field + section Pengaju/Pengapprove + tombol Approve/Reject.
class CustomerSubmissionsTab extends StatefulWidget {
  const CustomerSubmissionsTab({super.key});

  @override
  State<CustomerSubmissionsTab> createState() => _CustomerSubmissionsTabState();
}

class _CustomerSubmissionsTabState extends State<CustomerSubmissionsTab> {
  String _filter = 'ALL'; // ALL | PENDING | APPROVED | REJECTED

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminProvider>();
      if (provider.customerSubmissions.isEmpty) {
        provider.loadCustomerSubmissions(); // default: semua status (log view)
      }
    });
  }

  void _changeFilter(String f) {
    setState(() => _filter = f);
    context.read<AdminProvider>().loadCustomerSubmissions(
          status: f == 'ALL' ? null : f,
        );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final submissions = provider.customerSubmissions;

    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip('Semua', 'ALL', provider.customerSubmissions.length),
              _filterChip(
                'Pending',
                'PENDING',
                provider.customerSubmissionsPendingCount,
              ),
              _filterChip(
                'Disetujui',
                'APPROVED',
                submissions.where((s) => s.status == 'APPROVED').length,
              ),
              _filterChip(
                'Ditolak',
                'REJECTED',
                submissions.where((s) => s.status == 'REJECTED').length,
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: submissions.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: submissions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    return _SubmissionCard(submission: submissions[i]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value, int count) {
    final selected = _filter == value;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => _changeFilter(value),
      selectedColor: AppColors.primaryLight,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final CustomerSubmission submission;
  const _SubmissionCard({required this.submission});

  @override
  Widget build(BuildContext context) {
    final s = submission;
    final color = _statusColor(s.status);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _SubmissionDetailScreen(submission: s),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.namaLangganan,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      s.statusLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              if (s.channelKategori != null && s.channelKategori!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  s.channelKategori!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Pengaju: ${s.salesNama ?? s.salesUsername ?? '-'}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(s.createdAt),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              if (s.reviewedByNama != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      s.status == 'APPROVED'
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      size: 12,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${s.status == 'APPROVED' ? 'Disetujui' : 'Ditolak'} oleh ${s.reviewedByNama} • ${_formatDate(s.reviewedAt!)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: color,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.assignment_outlined, size: 56, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('Belum ada pengajuan', style: AppTextStyles.headlineSmall),
            SizedBox(height: 4),
            Text(
              'Pengajuan customer baru dari sales akan muncul di sini.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Detail screen — show all form fields + audit info + Approve/Reject buttons (kalau PENDING).
class _SubmissionDetailScreen extends StatelessWidget {
  final CustomerSubmission submission;
  const _SubmissionDetailScreen({required this.submission});

  @override
  Widget build(BuildContext context) {
    final s = submission;
    final canApprove = s.status == 'PENDING';

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pengajuan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _statusBg(s.status),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _statusFg(s.status).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(s.status), color: _statusFg(s.status)),
                const SizedBox(width: 8),
                Text(
                  s.statusLabel,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: _statusFg(s.status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _section('Identitas', [
            _row('Nama Langganan', s.namaLangganan),
            _row('Nomor ID / KTP', s.nomorIdKtp),
            _row('Alamat KTP', s.alamatKtp),
            _row('Nama Kontak', s.namaKontakPemilik),
            _row('Telpon / HP', s.telponHp),
            _row('Alamat Kirim', s.alamatKirim),
            _row('Propinsi', s.propinsi),
            _row('Kecamatan', s.kecamatan),
            _row('Area / Route', s.areaRoute),
            _row('Tipe Langganan', s.tipeLangganan),
          ]),

          _section('Pembayaran', [
            _row('Tipe Pembayaran', s.tipePembayaran),
            _row('Nama Pasar', s.namaPasar),
            _row('Jangka Kredit', s.jangkaKreditHari != null ? '${s.jangkaKreditHari} hari' : null),
            _row('Batas Kredit', s.batasKreditRupiah != null ? 'Rp ${_fmtNumber(s.batasKreditRupiah!)}' : null),
          ]),

          _section('Channel & Salesman', [
            _row('Channel / Kategori', s.channelKategori),
            _row('Key Account', s.keyAccountRefId),
            _row('Cluster', s.clusterLangganan),
            _row('Kode & Nama Salesman', s.kodeNamaSalesman),
            _row('Siklus Kunjungan', s.siklusKunjungan),
          ]),

          _section('Audit', [
            _row('Pengaju', s.salesNama ?? s.salesUsername),
            _row('Tanggal Submit', _formatDate(s.createdAt)),
            if (s.reviewedByNama != null) ...[
              _row(
                s.status == 'APPROVED' ? 'Disetujui oleh' : 'Ditolak oleh',
                s.reviewedByNama,
              ),
              _row('Tanggal Review', _formatDate(s.reviewedAt!)),
            ],
            if (s.status == 'REJECTED' && s.rejectReason != null)
              _row('Alasan Ditolak', s.rejectReason),
          ]),
        ],
      ),
      bottomNavigationBar: canApprove
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(context, s),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Tolak'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _showApproveDialog(context, s),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Setujui'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _showApproveDialog(BuildContext context, CustomerSubmission s) async {
    final kodeCtl = TextEditingController();
    final namaCtl = TextEditingController(text: s.namaLangganan);
    final alamatCtl = TextEditingController(text: s.alamatKirim ?? '');

    final provider = context.read<AdminProvider>();
    final scaffold = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Setujui Pengajuan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer "${s.namaLangganan}" akan dibuat dengan kode di bawah.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: kodeCtl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Kode Langganan *',
                    hintText: 'C-0001',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: namaCtl,
                  decoration: InputDecoration(
                    labelText: 'Nama Toko (override)',
                    border: const OutlineInputBorder(),
                    helperText: 'Default: dari submission. Edit kalau perlu.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: alamatCtl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Alamat (override)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  if (kodeCtl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Kode wajib diisi')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Setujui'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    try {
      await provider.approveCustomerSubmission(
            s.id,
            kode: kodeCtl.text.trim(),
            namaToko: namaCtl.text.trim().isEmpty ? null : namaCtl.text.trim(),
            alamat: alamatCtl.text.trim().isEmpty ? null : alamatCtl.text.trim(),
          );
      if (!context.mounted) return;
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Pengajuan disetujui, customer baru terdaftar.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Gagal approve: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showRejectDialog(BuildContext context, CustomerSubmission s) async {
    final reasonCtl = TextEditingController();

    final provider = context.read<AdminProvider>();
    final scaffold = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Tolak Pengajuan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tolak pengajuan "${s.namaLangganan}"?',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Alasan penolakan (opsional, akan ditampilkan ke sales).',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtl,
                  maxLines: 3,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Misal: Data tidak valid, duplikat, dll.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tolak'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    try {
      await provider.rejectCustomerSubmission(
            s.id,
            rejectReason: reasonCtl.text.trim().isEmpty
                ? null
                : reasonCtl.text.trim(),
          );
      if (!context.mounted) return;
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Pengajuan ditolak.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Gagal reject: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
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

  Widget _row(String label, String? value) {
    final v = value == null || value.isEmpty ? '-' : value;
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
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color _statusFg(String status) {
    switch (status) {
      case 'APPROVED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Color _statusBg(String status) =>
      _statusFg(status).withValues(alpha: 0.10);

  IconData _statusIcon(String status) {
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