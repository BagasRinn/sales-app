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
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminProvider>();
      if (provider.customerSubmissions.isEmpty) {
        provider.loadCustomerSubmissions();
      }
      _firstLoad = false;
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
    final total = submissions.length;
    final pending = provider.customerSubmissionsPendingCount;
    final approved = submissions.where((s) => s.status == 'APPROVED').length;
    final rejected = submissions.where((s) => s.status == 'REJECTED').length;

    if (_firstLoad && submissions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Stats row + Filter chips di satu tempat
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.borderLight)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Pengajuan Customer',
                    style: AppTextStyles.headlineMedium.copyWith(fontSize: 18),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$total total',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.inbox_outlined,
                      label: 'Semua',
                      count: total,
                      color: AppColors.textSecondary,
                      active: _filter == 'ALL',
                      onTap: () => _changeFilter('ALL'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.schedule,
                      label: 'Pending',
                      count: pending,
                      color: AppColors.warning,
                      active: _filter == 'PENDING',
                      onTap: () => _changeFilter('PENDING'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle_outline,
                      label: 'Disetujui',
                      count: approved,
                      color: AppColors.success,
                      active: _filter == 'APPROVED',
                      onTap: () => _changeFilter('APPROVED'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.cancel_outlined,
                      label: 'Ditolak',
                      count: rejected,
                      color: AppColors.error,
                      active: _filter == 'REJECTED',
                      onTap: () => _changeFilter('REJECTED'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: submissions.isEmpty
              ? _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? color.withValues(alpha: 0.08) : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? color.withValues(alpha: 0.5) : AppColors.borderLight,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? color : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: active ? color : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
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
          // Penting: route ini di-push di atas dashboard, BUKAN sebagai child
          // dari dashboard. Tanpa Provider.value, _SubmissionDetailScreen
          // (dan _showApproveDialog/_showRejectDialog di dalamnya) tidak bisa
          // akses AdminProvider — Provider scope hanya mencakup subtree
          // dashboard. Kita bungkus dengan ChangeNotifierProvider.value supaya
          // provider yang sama dipakai di route baru ini.
          final provider = context.read<AdminProvider>();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider<AdminProvider>.value(
                value: provider,
                child: _SubmissionDetailScreen(submission: s),
              ),
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
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada pengajuan',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Pengajuan customer baru dari sales akan muncul di sini.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderSection extends StatelessWidget {
  final SubmissionOrder order;
  const _OrderSection({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = _orderStatusColor(order.status);
    final isPending = order.status == 'PENDING';
    final isDraft = order.status == 'DRAFT';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Order Items',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Item list
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.namaBarang ?? item.productId,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Rp ${_fmtNumber(item.hargaSatuan)} x ${item.qty}',
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Rp ${_fmtNumber(item.subtotal)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            )),

            const Divider(height: 16),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL PESANAN',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Rp ${_fmtNumber(order.totalAmount ?? 0)}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),

            // Info banner
            if (isDraft) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.infoBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Order akan masuk tab Pesanan (status: PENDING) setelah Anda menyetujui pengajuan ini.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.info,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.successBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pengajuan disetujui. Order masuk tab Pesanan (PENDING). Review item di sana.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.success,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _orderStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return AppColors.success;
      case 'REJECTED':
      case 'CANCELLED':
        return AppColors.error;
      case 'PENDING':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
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
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _statusBg(s.status),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _statusFg(s.status).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(s.status), color: _statusFg(s.status), size: 20),
                const SizedBox(width: 8),
                Text(
                  s.statusLabel,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _statusFg(s.status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (s.reviewedByNama != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• oleh ${s.reviewedByNama}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _statusFg(s.status),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          _section('Identitas', [
            // Full-width title-ish fields
            _kvRow('Nama Langganan', s.namaLangganan),
            _kvGrid([
              MapEntry('Nomor ID / KTP', s.nomorIdKtp),
              MapEntry('Nama Kontak', s.namaKontakPemilik),
            ]),
            _kvRow('Alamat KTP', s.alamatKtp),
            _kvGrid([
              MapEntry('Telpon / HP', s.telponHp),
              MapEntry('Tipe Langganan', s.tipeLangganan),
            ]),
            _kvRow('Alamat Kirim', s.alamatKirim),
            _kvGrid([
              MapEntry('Propinsi', s.propinsi),
              MapEntry('Kecamatan', s.kecamatan),
            ]),
            _kvGrid([
              MapEntry('Kota', s.kota),
              MapEntry('Kelurahan', s.kelurahan),
            ]),
            _kvGrid([
              MapEntry('Area / Route', s.areaRoute),
              MapEntry('Kode Area', s.kodeArea),
            ]),
            _kvGrid([
              MapEntry('Nama Pasar', s.namaPasar),
              MapEntry('', null), // keep 2-col grid, empty right cell
            ]),
          ]),

          _section('Pembayaran', [
            _kvRow('Tipe Pembayaran', s.tipePembayaran),
            _kvGrid([
              MapEntry('Jangka Kredit', s.jangkaKreditHari != null ? '${s.jangkaKreditHari} hari' : null),
              MapEntry('Batas Kredit', s.batasKreditRupiah != null ? 'Rp ${_fmtNumber(s.batasKreditRupiah!)}' : null),
            ]),
          ]),

          _section('Channel & Salesman', [
            _kvGrid([
              MapEntry('Channel / Kategori', s.channelKategori),
              MapEntry('Key Account', s.keyAccountRefId),
            ]),
            _kvGrid([
              MapEntry('Cluster', s.clusterLangganan),
              MapEntry('Kode Salesman', s.kodeSalesman),
            ]),
            _kvRow('Nama Salesman', s.namaSalesman),
            _kvGrid([
              MapEntry('Siklus Kunjungan', s.siklusKunjungan),
              MapEntry('Hari Kunjungan', s.hariKunjungan),
            ]),
          ]),

          _section('Audit', [
            _kvGrid([
              MapEntry('Pengaju', s.salesNama ?? s.salesUsername),
              MapEntry('Tanggal Submit', _formatDate(s.createdAt)),
            ]),
            if (s.reviewedByNama != null)
              _kvGrid([
                MapEntry(
                  s.status == 'APPROVED' ? 'Disetujui oleh' : 'Ditolak oleh',
                  s.reviewedByNama,
                ),
                MapEntry('Tanggal Review', _formatDate(s.reviewedAt!)),
              ]),
            if (s.status == 'REJECTED' && s.rejectReason != null)
              _kvRow('Alasan Ditolak', s.rejectReason),
          ]),

          // After Audit section, before bottomNavigationBar:
          if (s.order != null)
            _OrderSection(order: s.order!),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Full-width single field. Label kecil muted di atas, value bold di bawah.
  Widget _kvRow(String label, String? value) {
    final v = (value == null || value.isEmpty) ? '—' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            v,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// 2-column grid. entries berisi MapEntry&lt;label, value&gt; — jumlah genap
  /// disarankan; kalau ganjil, kolom terakhir sisi kanan kosong.
  Widget _kvGrid(List<MapEntry<String, String?>> entries) {
    return LayoutBuilder(builder: (context, c) {
      final gap = 12.0;
      final w = (c.maxWidth - gap) / 2;
      final rows = <Widget>[];
      for (var i = 0; i < entries.length; i += 2) {
        final left = entries[i];
        final right = i + 1 < entries.length ? entries[i + 1] : null;
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: w, child: _kvCol(left.key, left.value)),
                SizedBox(width: gap),
                if (right != null)
                  SizedBox(width: w, child: _kvCol(right.key, right.value))
                else
                  SizedBox(width: w),
              ],
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      );
    });
  }

  Widget _kvCol(String label, String? value) {
    final v = (value == null || value.isEmpty || label.isEmpty) ? '—' : value;
    if (label.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          v,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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