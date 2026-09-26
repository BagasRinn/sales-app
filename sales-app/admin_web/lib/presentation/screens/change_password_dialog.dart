import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/auth_storage.dart';
import '../../core/design_system.dart';
import '../../data/repositories/admin_repository.dart';
import 'login_screen.dart';

class ChangePasswordDialog extends StatefulWidget {
  final AdminRepository adminRepository;
  const ChangePasswordDialog({super.key, required this.adminRepository});

  static Future<void> show(BuildContext context, AdminRepository adminRepository) async {
    await showDialog(
      context: context,
      builder: (_) => ChangePasswordDialog(adminRepository: adminRepository),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _oldC = TextEditingController();
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _oldC.dispose();
    _newC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final oldP = _oldC.text;
    final newP = _newC.text;
    final confirmP = _confirmC.text;

    if (oldP.isEmpty || newP.isEmpty || confirmP.isEmpty) {
      _errSnack('Semua field wajib diisi');
      return;
    }
    if (newP.length < 6) {
      _errSnack('Password baru minimal 6 karakter');
      return;
    }
    if (newP != confirmP) {
      _errSnack('Password baru dan konfirmasi tidak sama');
      return;
    }

    setState(() => _saving = true);
    bool ok = false;
    String? errorMsg;
    try {
      await widget.adminRepository.changePassword(oldPassword: oldP, newPassword: newP);
      ok = true;
    } catch (e) {
      ok = false;
      errorMsg = e is ApiException ? e.message : e.toString();
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password berhasil diubah. Silakan login ulang.'),
          backgroundColor: AppColors.success,
        ),
      );
      // Clear stored tokens — sama pattern dengan logout di dashboard_screen.
      // Best-effort: kalau gagal, setOnUnauthorized callback di api_service
      // akan tetap menendang user ke login saat request berikutnya 401.
      await AuthStorage().clearTokens();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } else {
      _errSnack(errorMsg ?? 'Gagal mengganti password');
    }
  }

  void _errSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ganti Password',
                          style: AppTextStyles.headlineSmall,
                        ),
                        Text(
                          'Verifikasi password lama untuk konfirmasi',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _oldC,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password Lama *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newC,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password Baru *',
                  helperText: 'Minimal 6 karakter',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmC,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi Password Baru *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save, size: 18),
                      label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
