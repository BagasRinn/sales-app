import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system.dart';
import '../../../data/models/customer_submission.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../core/api_service.dart';
import 'customer_submission_detail_screen.dart';

class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  List<CustomerSubmission>? _submissions;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final repo = CustomerRepository(api);
      final list = await repo.getMyCustomerSubmissions();
      if (!mounted) return;
      setState(() {
        _submissions = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Status Pengajuan Saya'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _submissions == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                'Gagal memuat data',
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }
    final list = _submissions ?? [];
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, size: 56, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text('Belum ada pengajuan', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Pengajuan customer baru yang kamu buat akan muncul di sini.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final s = list[i];
          return _SubmissionCard(submission: s);
        },
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final CustomerSubmission submission;
  const _SubmissionCard({required this.submission});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(submission.status);

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CustomerSubmissionDetailScreen(submission: submission),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: nama + status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      submission.namaLangganan,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      submission.statusLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              if (submission.alamatKirim != null && submission.alamatKirim!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  submission.alamatKirim!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              // Tanggal submit
              Row(
                children: [
                  Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Submit: ${_formatDate(submission.createdAt)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              // Review info
              if (submission.reviewedByNama != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.person, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${_reviewLabel(submission.status)} oleh ${submission.reviewedByNama} • ${_formatDate(submission.reviewedAt!)}',
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
              ],
              // Reject reason
              if (submission.status == 'REJECTED' && submission.rejectReason != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          submission.rejectReason!,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _reviewLabel(String status) {
    return status == 'APPROVED' ? 'Disetujui' : 'Ditolak';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED': return AppColors.success;
      case 'REJECTED': return AppColors.error;
      default: return AppColors.warning;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
