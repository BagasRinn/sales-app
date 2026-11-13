import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/design_system.dart';

/// Callback untuk mengambil snapshot progres import dari backend.
///
/// Null berarti job belum terdaftar di server (biasanya karena upload masih
/// berjalan atau file sedang dibaca sebelum reporter dibuat).
typedef ImportProgressFetcher =
    Future<Map<String, dynamic>?> Function(String jobId);

/// Sesi import yang diberikan ke [ImportProgressOverlay.run].
///
/// Pemanggil meneruskan [jobId] ke repository dan memasang [onSendProgress]
/// sebagai callback upload Dio, sehingga overlay bisa menampilkan persentase
/// upload sekaligus persentase pemrosesan dari backend.
class ImportProgressSession {
  ImportProgressSession._(this.jobId, this._controller);

  /// ID job yang dikirim ke backend lewat header `X-Import-Job-Id`.
  final String jobId;

  final ImportProgressController _controller;

  /// Cocok dipakai langsung sebagai `onSendProgress` milik Dio.
  void onSendProgress(int sent, int total) =>
      _controller.updateUpload(sent, total);
}

/// State progres import: gabungan persentase upload (0-10%) dan persentase
/// pemrosesan dari backend (10-100%).
class ImportProgressController extends ChangeNotifier {
  ImportProgressController({String? jobId}) : jobId = jobId ?? generateJobId();

  /// Mulai pemrosesan backend pada persentase ini. Upload file memakai
  /// rentang 0-[_uploadWeight]%, sisanya dipakai progres server.
  static const int _uploadWeight = 10;

  final String jobId;

  int _uploadSent = 0;
  int _uploadTotal = 0;
  bool _uploadStarted = false;
  bool _disposed = false;
  Map<String, dynamic>? _snapshot;

  /// Persentase upload terakhir (0-100), null bila belum ada laporan.
  int? get uploadPercent {
    if (!_uploadStarted || _uploadTotal <= 0) return null;
    final ratio = _uploadSent / _uploadTotal;
    return (ratio.clamp(0.0, 1.0) * 100).round();
  }

  /// Persentase dari backend (0-100) bila job sudah terdaftar.
  int? get backendPercent {
    final value = (_snapshot?['percent'] as num?)?.toInt();
    if (value == null) return null;
    return value.clamp(0, 100).toInt();
  }

  /// Apakah upload file sudah selesai terkirim.
  bool get uploadComplete {
    final percent = uploadPercent;
    return percent != null && percent >= 100;
  }

  /// Persentase yang ditampilkan. Null berarti progress belum terukur
  /// (indeterminate), mis. saat menunggu server membaca file.
  int? get percent {
    final upload = uploadPercent;
    final uploadContribution = upload == null
        ? null
        : (upload * _uploadWeight / 100).round();
    final backend = backendPercent;
    if (backend != null) {
      final scaled =
          _uploadWeight + (backend * (100 - _uploadWeight) / 100).round();
      final clamped = scaled.clamp(_uploadWeight, 100).toInt();
      if (uploadContribution == null) return clamped;
      return max(clamped, uploadContribution);
    }
    // Upload selesai tetapi backend belum melapor: bar indeterminate supaya
    // jelas bahwa server masih bekerja, bukan macet di 10%.
    if (uploadComplete) return null;
    return uploadContribution;
  }

  /// Label tahap yang sedang berjalan.
  String get stage {
    final snapshotStage = _snapshot?['stage'];
    if (snapshotStage is String && snapshotStage.trim().isNotEmpty) {
      return snapshotStage.trim();
    }
    final upload = uploadPercent;
    if (upload != null && upload < 100) {
      return 'Mengunggah file ke server ($upload%)...';
    }
    if (uploadComplete) {
      return 'File terkirim. Menunggu server memproses...';
    }
    return 'Menyiapkan import...';
  }

  /// True bila backend melaporkan import gagal.
  bool get failed => _snapshot?['success'] == false;

  void updateUpload(int sent, int total) {
    if (_disposed) return;
    _uploadStarted = true;
    _uploadSent = sent;
    _uploadTotal = total;
    notifyListeners();
  }

  void applySnapshot(Map<String, dynamic> snapshot) {
    if (_disposed) return;
    _snapshot = snapshot;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static String generateJobId() {
    final random = Random.secure();
    final suffix = List.generate(
      8,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'imp-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-$suffix';
  }
}

/// Overlay progres import Excel yang bisa dipakai ulang di semua alur import.
///
/// Persentase berasal dari dua sumber nyata:
/// 1. progres upload file dari Dio (`onSendProgress`), dan
/// 2. progres pemrosesan di server yang di-poll dari
///    `GET /api/v1/import-progress/{job_id}` tiap ±500 ms.
///
/// Selama backend belum melaporkan progres, bar bersifat indeterminate dengan
/// teks tahap yang jelas, sehingga tidak menampilkan angka palsu.
///
/// Pemakaian:
/// ```dart
/// final success = await ImportProgressOverlay.run<bool>(
///   context,
///   title: 'Mengimport Laporan Penjualan',
///   fileName: file.name,
///   fileSize: file.size,
///   progressFetcher: provider.fetchImportProgress,
///   task: (session) => provider.importSalesExcel(
///     file.bytes!,
///     file.name,
///     jobId: session.jobId,
///     onSendProgress: session.onSendProgress,
///   ),
/// );
/// ```
class ImportProgressOverlay extends StatefulWidget {
  const ImportProgressOverlay({
    super.key,
    required this.title,
    required this.controller,
    this.fileName,
    this.fileSize,
  });

  /// Judul proses, mis. "Mengimport Data Produk".
  final String title;

  /// Sumber progres yang di-poll dan di-update oleh upload.
  final ImportProgressController controller;

  /// Nama file yang sedang diimport (opsional).
  final String? fileName;

  /// Ukuran file dalam byte (opsional).
  final int? fileSize;

  static const int _largeFileThresholdBytes = 20 * 1024 * 1024;

  /// Jalankan [task] sambil menampilkan overlay progres.
  ///
  /// Overlay selalu dihapus setelah [task] selesai — baik sukses maupun gagal —
  /// sehingga error tetap bisa ditangani oleh pemanggil. Polling progres
  /// dihentikan pada saat yang sama.
  static Future<T> run<T>(
    BuildContext context, {
    required String title,
    required Future<T> Function(ImportProgressSession session) task,
    ImportProgressFetcher? progressFetcher,
    String? fileName,
    int? fileSize,
  }) async {
    final controller = ImportProgressController();
    final session = ImportProgressSession._(controller.jobId, controller);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return task(session);
    }

    final entry = OverlayEntry(
      builder: (_) => ImportProgressOverlay(
        title: title,
        controller: controller,
        fileName: fileName,
        fileSize: fileSize,
      ),
    );
    overlay.insert(entry);

    Timer? pollTimer;
    var polling = false;
    Future<void> poll() async {
      if (progressFetcher == null || polling) return;
      polling = true;
      try {
        final snapshot = await progressFetcher(controller.jobId);
        if (snapshot != null) controller.applySnapshot(snapshot);
      } catch (_) {
        // Abaikan gangguan sementara; poll berikutnya akan mencoba lagi.
      } finally {
        polling = false;
      }
    }

    if (progressFetcher != null) {
      unawaited(poll());
      pollTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => unawaited(poll()),
      );
    }

    try {
      return await task(session);
    } finally {
      pollTimer?.cancel();
      entry.remove();
      controller.dispose();
    }
  }

  @override
  State<ImportProgressOverlay> createState() => _ImportProgressOverlayState();
}

class _ImportProgressOverlayState extends State<ImportProgressOverlay> {
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isLargeFile =>
      (widget.fileSize ?? 0) > ImportProgressOverlay._largeFileThresholdBytes;

  String get _noticeText => _isLargeFile
      ? 'File cukup besar, proses dapat memakan beberapa menit. Jangan tutup '
            'atau refresh halaman ini.'
      : 'Jangan tutup atau refresh halaman ini sampai import selesai.';

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }

  String _formatElapsed(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    if (hours == 0) return '$mm:$ss';
    return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final percent = widget.controller.percent;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ModalBarrier(dismissible: false, color: Color(0x8A0F172A)),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Material(
                    color: AppColors.surface,
                    elevation: 16,
                    borderRadius: AppRadius.xl,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Semantics(
                        liveRegion: true,
                        label: widget.title,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: AppRadius.lg,
                                  ),
                                  child: const Icon(
                                    Icons.cloud_upload_outlined,
                                    color: AppColors.primary,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.title,
                                        style: AppTextStyles.h2,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Proses import berjalan di server',
                                        style: AppTextStyles.bodyMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (widget.fileName != null) ...[
                              const SizedBox(height: AppSpacing.lg),
                              _FileInfo(
                                fileName: widget.fileName!,
                                fileSizeLabel: widget.fileSize == null
                                    ? null
                                    : _formatBytes(widget.fileSize!),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.controller.stage,
                                    style: AppTextStyles.bodyMuted,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  percent == null ? '—' : '$percent%',
                                  semanticsLabel: percent == null
                                      ? 'Progres belum terukur'
                                      : 'Progres $percent persen',
                                  style: AppTextStyles.metric.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: widget.controller.failed
                                        ? AppColors.error
                                        : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ClipRRect(
                              borderRadius: AppRadius.sm,
                              child: LinearProgressIndicator(
                                value: percent == null ? null : percent / 100,
                                minHeight: 6,
                                backgroundColor: AppColors.surfaceMuted,
                                color: widget.controller.failed
                                    ? AppColors.error
                                    : AppColors.primary,
                                semanticsLabel: 'Progres import',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 4,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: AppRadius.sm,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.timer_outlined,
                                        size: 14,
                                        color: AppColors.textSubtle,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatElapsed(_elapsedSeconds),
                                        style: AppTextStyles.metric.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.infoSoft,
                                borderRadius: AppRadius.md,
                                border: Border.all(color: AppColors.infoBorder),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: AppColors.infoText,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      _noticeText,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.infoText,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FileInfo extends StatelessWidget {
  const _FileInfo({required this.fileName, this.fileSizeLabel});

  final String fileName;
  final String? fileSizeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: AppTextStyles.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (fileSizeLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(fileSizeLabel!, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
