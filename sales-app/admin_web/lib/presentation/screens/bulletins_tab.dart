import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../providers/admin_provider.dart';
import '../../data/models/bulletin.dart';
import 'bulletin_pdf_picker_stub.dart'
    if (dart.library.html) 'bulletin_pdf_picker_web.dart' as picker;

/// Tab "Bulletin" — manager-only bulletin management.
class BulletinsTab extends StatefulWidget {
  const BulletinsTab({super.key});

  @override
  State<BulletinsTab> createState() => _BulletinsTabState();
}

class _BulletinsTabState extends State<BulletinsTab> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminProvider>();
      if (!_initialized) {
        _initialized = true;
        provider.loadBulletins(includeRead: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bulletins = context.select<AdminProvider, List<Bulletin>>(
      (p) => p.bulletins,
    );
    final isLoading = context.select<AdminProvider, bool>(
      (p) => p.bulletinsLoading,
    );

    if (isLoading && bulletins.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (bulletins.isEmpty) {
      return _EmptyState(onCreate: () => _showFormDialog(context, null));
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: bulletins.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            return _BulletinCard(
              bulletin: bulletins[i],
              onEdit: () => _showFormDialog(context, bulletins[i]),
              onDelete: () => _showDeleteDialog(context, bulletins[i]),
            );
          },
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: FloatingActionButton.extended(
            onPressed: () => _showFormDialog(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Buat Bulletin'),
          ),
        ),
      ],
    );
  }

  Future<void> _showFormDialog(BuildContext context, Bulletin? bulletin) async {
    final titleCtrl = TextEditingController(text: bulletin?.title ?? '');
    final descCtrl = TextEditingController(text: bulletin?.description ?? '');
    final pdfCtrl = TextEditingController(text: bulletin?.pdfUrl ?? '');
    final isEditing = bulletin != null;
    DateTime? selectedDate = bulletin?.expireAt;
    bool noExpiration = bulletin?.expireAt == null;
    bool uploading = false;
    String? uploadError;

    final provider = context.read<AdminProvider>();
    final scaffold = ScaffoldMessenger.of(context);

    Future<void> doUpload(StateSetter setDialogState) async {
      if (uploading) return;
      setDialogState(() {
        uploading = true;
        uploadError = null;
      });

      try {
        final picked = await picker.pickPdfFile();
        if (picked == null) {
          if (!mounted) return;
          setDialogState(() => uploading = false);
          return;
        }

        if (picked.bytes.isEmpty) {
          if (!mounted) return;
          setDialogState(() {
            uploadError = 'File kosong';
            uploading = false;
          });
          return;
        }
        if (picked.bytes.length > 10 * 1024 * 1024) {
          if (!mounted) return;
          setDialogState(() {
            uploadError = 'Ukuran maksimal 10MB';
            uploading = false;
          });
          return;
        }

        // Capture provider before await so we don't use context across gap
        final repo = provider.adminRepository;
        final url = await repo.uploadBulletinPdf(picked.bytes, picked.name);

        if (!mounted) return;
        pdfCtrl.text = url;
        setDialogState(() => uploading = false);
      } catch (e) {
        if (!mounted) return;
        setDialogState(() {
          uploadError = 'Upload gagal: $e';
          uploading = false;
        });
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(isEditing ? 'Edit Bulletin' : 'Buat Bulletin Baru'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Judul *',
                        hintText: 'Judul bulletin',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi',
                        hintText: 'Isi bulletin (opsional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // PDF URL dengan tombol upload di kanan (suffix icon)
                    TextField(
                      controller: pdfCtrl,
                      decoration: InputDecoration(
                        labelText: 'URL PDF',
                        hintText: 'Atau klik ikon di kanan untuk upload',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: uploading ? 'Mengupload...' : 'Upload PDF',
                          icon: uploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_file),
                          onPressed: uploading ? null : () => doUpload(setDialogState),
                        ),
                      ),
                    ),
                    if (uploadError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        uploadError!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Checkbox(
                          value: noExpiration,
                          onChanged: (v) {
                            setDialogState(() {
                              noExpiration = v ?? false;
                              if (noExpiration) selectedDate = null;
                            });
                          },
                        ),
                        const Text('Tanpa batas waktu'),
                        const Spacer(),
                        if (!noExpiration)
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                              );
                              if (picked != null) {
                                setDialogState(() => selectedDate = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              selectedDate != null
                                  ? _formatDate(selectedDate!)
                                  : 'Pilih Tanggal',
                            ),
                          ),
                      ],
                    ),
                    if (!noExpiration && selectedDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Berlaku sampai ${_formatDate(selectedDate!)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Judul wajib diisi')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: Text(isEditing ? 'Simpan' : 'Buat'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    bool success;
    if (isEditing) {
      success = await provider.updateBulletin(
        bulletin.id,
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        pdfUrl: pdfCtrl.text.trim().isEmpty ? null : pdfCtrl.text.trim(),
        expireAt: noExpiration ? null : selectedDate,
      );
    } else {
      success = await provider.createBulletin(
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        pdfUrl: pdfCtrl.text.trim().isEmpty ? null : pdfCtrl.text.trim(),
        expireAt: noExpiration ? null : selectedDate,
      );
    }

    if (!mounted) return;
    if (success) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Bulletin diperbarui.' : 'Bulletin dibuat.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Gagal: ${provider.errorMessage ?? "Unknown error"}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, Bulletin bulletin) async {
    final provider = context.read<AdminProvider>();
    final scaffold = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Bulletin'),
        content: Text(
          'Hapus bulletin "${bulletin.title}"? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await provider.deleteBulletin(bulletin.id);

    if (!mounted) return;
    if (success) {
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Bulletin dihapus.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Gagal: ${provider.errorMessage ?? "Unknown error"}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

class _BulletinCard extends StatelessWidget {
  final Bulletin bulletin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BulletinCard({
    required this.bulletin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isExpired = bulletin.expireAt != null && bulletin.expireAt!.isBefore(now);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: bulletin.pdfUrl != null && bulletin.pdfUrl!.isNotEmpty
            ? () => _openPdf(bulletin.pdfUrl!)
            : null,
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
                      bulletin.title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isExpired) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'Kedaluwarsa',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppColors.textSecondary,
                    tooltip: 'Edit',
                    onPressed: onEdit,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppColors.error,
                    tooltip: 'Hapus',
                    onPressed: onDelete,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              if (bulletin.description != null && bulletin.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  bulletin.description!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (bulletin.pdfUrl != null && bulletin.pdfUrl!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        bulletin.pdfUrl!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Dibuat ${_fmtDate(bulletin.createdAt)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  if (bulletin.expireAt != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      isExpired ? Icons.event_busy : Icons.event,
                      size: 12,
                      color: isExpired ? AppColors.error : AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isExpired
                          ? 'Kedaluwarsa ${_fmtDate(bulletin.expireAt!)}'
                          : 'Berlaku sampai ${_fmtDate(bulletin.expireAt!)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isExpired ? AppColors.error : AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPdf(String url) {}

  String _fmtDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.campaign_outlined, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('Belum ada bulletin', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Buat bulletin baru untuk ditampilkan ke seluruh sales.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Buat Bulletin'),
            ),
          ],
        ),
      ),
    );
  }
}
