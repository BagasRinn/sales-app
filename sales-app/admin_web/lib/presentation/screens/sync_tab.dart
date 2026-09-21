import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../providers/admin_provider.dart';
import '../../data/models/sync_result.dart';

class SyncTab extends StatelessWidget {
  const SyncTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final syncResult = provider.lastSyncResult;
    final isLoading = provider.isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main sync card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.infoBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child:
                            const Icon(Icons.cloud_sync, size: 32, color: AppColors.info),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sinkronisasi Google Sheets',
                              style: AppTextStyles.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tarik data stok terbaru dari spreadsheet ke sistem',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow(Icons.table_chart, 'Sumber', 'Google Sheets API'),
                        const SizedBox(height: 8),
                        _infoRow(Icons.storage, 'Metode', 'Bulk Upsert (< 5 detik)'),
                        const SizedBox(height: 8),
                        _infoRow(Icons.check_circle_outline, 'Akses',
                            'Service Account (Read-only)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final success = await provider.syncProducts();
                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle,
                                            color: Colors.white, size: 20),
                                        const SizedBox(width: 10),
                                        Text(syncResult?.message ??
                                            'Sinkronisasi berhasil'),
                                      ],
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            },
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.cloud_download),
                      label: Text(
                          isLoading ? 'Menyinkronkan...' : 'Jalankan Sinkronisasi'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Result cards
          if (syncResult != null) ...[
            const SizedBox(height: 32),
            const Text('Hasil Sinkronisasi Terakhir',
                style: AppTextStyles.headlineLarge),
            const SizedBox(height: 16),
            _SyncResultGrid(result: syncResult),
          ],

          const SizedBox(height: 32),
          // Error history
          const Text('Riwayat Error', style: AppTextStyles.headlineLarge),
          const SizedBox(height: 16),
          _SyncErrorsSection(),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text('$label:', style: AppTextStyles.bodySmall),
        const SizedBox(width: 6),
        Text(value,
            style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _SyncResultGrid extends StatelessWidget {
  final SyncResult result;

  const _SyncResultGrid({required this.result});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _ResultCard(
          title: 'Total Produk',
          value: '${result.totalProducts}',
          icon: Icons.inventory_2,
          color: AppColors.info,
        ),
        _ResultCard(
          title: 'Disisipkan (Baru)',
          value: '${result.inserted}',
          icon: Icons.add_circle,
          color: AppColors.success,
        ),
        _ResultCard(
          title: 'Diperbarui',
          value: '${result.updated}',
          icon: Icons.edit,
          color: AppColors.primaryLight,
        ),
        _ResultCard(
          title: 'Dilewati (Error)',
          value: '${result.skipped}',
          icon: Icons.skip_next,
          color: result.skipped > 0 ? AppColors.error : AppColors.textMuted,
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ResultCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      title,
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncErrorsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                size: 20, color: AppColors.textMuted),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Daftar baris yang dilewati saat sinkronisasi',
                  style: AppTextStyles.bodyMedium),
            ),
            OutlinedButton.icon(
              onPressed: () => _showErrorsDialog(context, provider),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Lihat Detail'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showErrorsDialog(
      BuildContext context, AdminProvider provider) async {
    final errors = await provider.getSyncErrors();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 560,
          height: 460,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.errorBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          const Icon(Icons.error, color: AppColors.error, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Error Sinkronisasi',
                              style: AppTextStyles.headlineSmall),
                          Text('Baris yang dilewati saat proses sync',
                              style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: errors.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.successBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle,
                                  size: 40, color: AppColors.success),
                            ),
                            const SizedBox(height: 16),
                            const Text('Tidak ada error',
                                style: AppTextStyles.headlineSmall),
                            const SizedBox(height: 4),
                            const Text(
                              'Semua baris berhasil diproses',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: errors.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) => Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.errorBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber,
                                  size: 18, color: AppColors.error),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Baris ${errors[i].row}',
                                  style: AppTextStyles.mono.copyWith(
                                    color: AppColors.error,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  errors[i].reason,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
