import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design_system.dart';
import '../../providers/bulletin_provider.dart';
import '../../../data/models/bulletin.dart';

class BulletinScreen extends StatefulWidget {
  const BulletinScreen({super.key});

  @override
  State<BulletinScreen> createState() => _BulletinScreenState();
}

class _BulletinScreenState extends State<BulletinScreen> {
  bool _showExpired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Selalu includeRead supaya user bisa lihat bulletin yang sudah lewat
      // (expired) maupun yang masih aktif.
      context.read<BulletinProvider>().loadBulletins(includeRead: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promo & Diskon'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context
                .read<BulletinProvider>()
                .loadBulletins(includeRead: true),
          ),
        ],
      ),
      body: Consumer<BulletinProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.bulletins.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal memuat promo',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        provider.loadBulletins(includeRead: true),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            );
          }

          // Filter: hanya tampilkan yang aktif + toggle untuk show expired.
          final now = DateTime.now();
          final active = provider.bulletins.where((b) {
            final isExpired =
                b.expireAt != null && b.expireAt!.isBefore(now);
            return _showExpired ? true : !isExpired;
          }).toList();

          return Column(
            children: [
              // Filter toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showExpired
                            ? 'Semua promo (termasuk yang sudah berakhir)'
                            : 'Promo yang sedang berlangsung',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Switch(
                      value: _showExpired,
                      onChanged: (v) => setState(() => _showExpired = v),
                    ),
                    Text(
                      _showExpired ? 'Semua' : 'Aktif',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: active.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.campaign_outlined,
                                size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 16),
                            Text(
                              _showExpired
                                  ? 'Belum ada promo'
                                  : 'Tidak ada promo aktif',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: active.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final bulletin = active[index];
                          return _BulletinCard(
                            bulletin: bulletin,
                            onTap: () => _showBulletinDetail(context, bulletin),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBulletinDetail(BuildContext context, Bulletin bulletin) {
    final dateFmt = DateFormat('dd MMMM yyyy', 'id_ID');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.campaign,
                          color: AppColors.primaryLight, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bulletin.title,
                            style: AppTextStyles.headlineSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFmt.format(bulletin.createdAt.toLocal()),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (bulletin.description != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    bulletin.description!,
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
                if (bulletin.expireAt != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule,
                            size: 16, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Text(
                          'Berlaku hingga ${dateFmt.format(bulletin.expireAt!.toLocal())}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (bulletin.pdfUrl != null) ...[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openPdf(bulletin.pdfUrl!),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Lihat PDF'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          // Dismiss best-effort: kalau network error, popup
                          // tetap harus ditutup supaya user tidak terjebak.
                          try {
                            await context
                                .read<BulletinProvider>()
                                .dismissBulletin(bulletin.id);
                          } catch (_) {
                            // Ignore — popup tetap ditutup.
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Tutup'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _BulletinCard extends StatelessWidget {
  final Bulletin bulletin;
  final VoidCallback onTap;

  const _BulletinCard({required this.bulletin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy', 'id_ID');
    final isExpired = bulletin.expireAt != null &&
        bulletin.expireAt!.isBefore(DateTime.now());

    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: bulletin.isRead
                  ? AppColors.borderLight
                  : AppColors.primaryLight.withValues(alpha: 0.4),
              width: bulletin.isRead ? 1 : 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (bulletin.isRead
                          ? AppColors.textMuted
                          : AppColors.primaryLight)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.campaign,
                  size: 20,
                  color: bulletin.isRead
                      ? AppColors.textMuted
                      : AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            bulletin.title,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: bulletin.isRead
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!bulletin.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (bulletin.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        bulletin.description!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          dateFmt.format(bulletin.createdAt.toLocal()),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (bulletin.expireAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '·',
                            style:
                                AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isExpired ? 'Berakhir' : 'Exp: ${dateFmt.format(bulletin.expireAt!.toLocal())}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isExpired
                                  ? AppColors.error
                                  : AppColors.textMuted,
                              fontWeight:
                                  isExpired ? FontWeight.w600 : null,
                            ),
                          ),
                        ],
                        if (bulletin.pdfUrl != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '·',
                            style:
                                AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.picture_as_pdf,
                              size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'PDF',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
