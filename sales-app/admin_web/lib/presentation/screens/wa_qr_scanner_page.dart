import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/design_system.dart';
import '../../core/datetime_utils.dart';
import '../../data/models/wa_session_status.dart';
import '../providers/admin_provider.dart';

/// Halaman pairing WhatsApp: tampilkan QR code untuk scan lewat WhatsApp,
/// pantau status koneksi, dan tombol putuskan/scan ulang.
///
/// Hanya MANAGER global yang boleh mengakses (backend enforce via JWT).
class WaQrScannerPage extends StatefulWidget {
  const WaQrScannerPage({super.key});

  @override
  State<WaQrScannerPage> createState() => _WaQrScannerPageState();
}

class _WaQrScannerPageState extends State<WaQrScannerPage> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminProvider>().loadWaSession(forceRefresh: true);
      _startPoll();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPoll() {
    _pollTimer?.cancel();
    // Poll tiap 5 detik supaya QR baru muncul otomatis setelah logout/relink.
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      context.read<AdminProvider>().loadWaSession();
    });
  }

  void _refresh() {
    context.read<AdminProvider>().loadWaSession(forceRefresh: true);
  }

  Future<void> _logoutAndRelink() async {
    final provider = context.read<AdminProvider>();
    await provider.logoutWaSession();
    if (!mounted) return;
    // Setelah logout, mulai polling lebih sering untuk tangkap QR baru.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      provider.loadWaSession();
    });
  }

  Widget _buildStatusChip(WaSessionStatus? s) {
    if (s == null) {
      return const AppBadge(
        label: 'Memuat…',
        variant: AppBadgeVariant.neutral,
        compact: true,
      );
    }
    final (label, variant) = switch (s.status) {
      'waiting_qr' => ('Menunggu scan QR', AppBadgeVariant.warning),
      'connected' => ('Terhubung', AppBadgeVariant.success),
      'disconnected' => ('Terputus', AppBadgeVariant.warning),
      'logged_out' => ('Keluar (scan ulang)', AppBadgeVariant.danger),
      'logging_out' => ('Sedang diputuskan…', AppBadgeVariant.neutral),
      _ => ('Tidak diketahui', AppBadgeVariant.neutral),
    };
    return AppBadge(label: label, variant: variant, compact: true);
  }

  Widget _buildQrCode(WaSessionStatus? s) {
    final qr = s?.qr;
    if (qr == null || qr.isEmpty) {
      return const SizedBox.shrink();
    }

    // QR dari worker biasanya data URI atau teks mentah. Hapus prefix
    // data:image/png;base64, kalau ada agar QrImageView bisa decode.
    final qrData = qr.replaceFirst(RegExp(r'^data:image/[^;]+;base64,'), '');

    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: QrImageView(
        data: qrData,
        version: QrVersions.auto,
        size: 220.0,
        backgroundColor: Colors.white,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: AppColors.primary,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildContent(AdminProvider p, WaSessionStatus? s) {
    final phone = s?.phone;
    final name = s?.name;
    final updatedAt = s?.updatedAt;

    final statusLabel = switch (s?.status) {
      'waiting_qr' => 'WhatsApp menunggu Anda scan QR code di bawah ini.',
      'connected' =>
          'WhatsApp sudah terhubung sebagai ${s?.name ?? '-'}.',
      'disconnected' =>
          'Koneksi WhatsApp terputus. Klik "Muat ulang" untuk coba kembali.',
      'logged_out' =>
          'Sesi WhatsApp telah keluar. Klik "Scan ulang" untuk membuat QR baru.',
      'logging_out' => 'Sedang memutuskan sesi, harap tunggu…',
      _ => 'Memuat status WhatsApp…',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(statusLabel, style: AppTextStyles.bodyMuted),
        const SizedBox(height: AppSpacing.md),
        // Kartu status + nomor.
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _buildStatusChip(s),
                        if (s?.connected == true) ...[
                          const SizedBox(width: AppSpacing.sm),
                          AppBadge(
                            label: 'Aktif',
                            variant: AppBadgeVariant.success,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (phone != null && phone.isNotEmpty) ...[
                      Text('Nomor: ${s!.displayPhone}',
                          style: AppTextStyles.bodySmall),
                    ],
                    if (name != null && name.isNotEmpty) ...[
                      Text('Profil: $name', style: AppTextStyles.caption),
                    ],
                    if (updatedAt != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Terupdate: ${witaFormat(updatedAt,
                            pattern: 'dd MMM yyyy, HH:mm')}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // QR code (hanya saat menunggu scan).
        if (s?.isWaitingQr == true) ...[
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQrCode(s),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Buka WhatsApp → Perangkat Tertaut → "Tautkan perangkat"',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Lalu scan kode QR di atas.',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ] else if (s?.connected == true) ...[
          const Center(
            child: Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 48),
          ),
        ] else ...[
          const Center(
            child: Icon(Icons.sim_card, color: AppColors.textMuted, size: 48),
          ),
        ],
        const SizedBox(height: AppSpacing.md),

        // Tombol aksi.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppButton(
              label: 'Muat ulang',
              icon: Icons.refresh,
              variant: AppButtonVariant.outline,
              onPressed: p.waSessionLoading ? null : _refresh,
              isLoading: p.waSessionLoading,
            ),
            if (s?.connected == true || s?.isLoggedOut == true ||
                s?.status == 'disconnected') ...[
              AppButton(
                label: 'Putuskan & scan ulang',
                icon: Icons.sim_card,
                variant: AppButtonVariant.danger,
                onPressed: p.waSessionLoading ? null : _logoutAndRelink,
                isLoading: p.waSessionLoading,
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AdminProvider>();
    final s = p.waSession;
    final isLoading = p.waSessionLoading;
    final error = p.waSessionError;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppPageHeader(
          title: 'Pairing WhatsApp',
          subtitle: 'Scan QR untuk menautkan nomor WA ke absensi kunjungan',
          actions: [
            AppButton(
              label: 'Muat ulang',
              icon: Icons.refresh,
              variant: AppButtonVariant.outline,
              onPressed: isLoading ? null : _refresh,
              isLoading: isLoading,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (error != null && s == null)
          AppErrorState(
            message: error,
            onRetry: _refresh,
          )
        else
          _buildContent(p, s),
      ],
    );
  }
}
