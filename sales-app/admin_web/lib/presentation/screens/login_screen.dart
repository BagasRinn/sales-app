import 'package:flutter/material.dart';
import '../../core/api_exception.dart';
import '../../core/auth_storage.dart';
import '../../core/design_system.dart';
import '../../core/responsive.dart';
import '../../data/repositories/api_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiService();
      final data = await api.post('/auth/login', body: {
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
      });

      if (data is! Map) {
        setState(() {
          _error = 'Respons server tidak valid';
          _isLoading = false;
        });
        return;
      }
      final accessToken = data['access_token'];
      final refreshToken = data['refresh_token'];
      final role = data['role']?.toString();

      if (accessToken == null || refreshToken == null) {
        setState(() {
          _error = 'Token tidak ditemukan dalam respons';
          _isLoading = false;
        });
        return;
      }

      // ADMIN, SUPERVISOR, and MANAGER (global) can login to admin web
      if (role != 'ADMIN' && role != 'SUPERVISOR' && role != 'MANAGER') {
        setState(() {
          _error = 'Hanya admin, supervisor, dan manager yang boleh mengakses dashboard ini.';
          _isLoading = false;
        });
        return;
      }

      final branch = data['branch']?.toString();
      final branchNama = data['branch_nama']?.toString();

      await AuthStorage().saveTokens(
        accessToken: accessToken.toString(),
        refreshToken: refreshToken.toString(),
        username: _usernameController.text.trim(),
        nama: data['nama']?.toString(),
        role: role,
        branch: branch,
        branchNama: branchNama,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            accessToken: accessToken.toString(),
            refreshToken: refreshToken.toString(),
            username: _usernameController.text.trim(),
            nama: data['nama']?.toString() ?? '',
            role: role ?? 'ADMIN',
            branch: branch,
            branchNama: branchNama,
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resp = Responsive.of(MediaQuery.of(context).size.width);
    final cardPadding = resp.isMobile ? 16.0 : 32.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo + brand
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Admin Dashboard', style: AppTextStyles.displayMedium),
                    const SizedBox(height: 4),
                    const Text(
                      'Sistem Manajemen Order Distribusi',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 40),

                    // Login card
                    AppCard(
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Masuk', style: AppTextStyles.h1),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Gunakan akun administrator Anda',
                            style: AppTextStyles.bodyMuted,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppInput(
                            controller: _usernameController,
                            label: 'Username',
                            prefixIcon: const Icon(Icons.person_outline, size: 18),
                            textInputAction: TextInputAction.next,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Username wajib diisi' : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppInput(
                            controller: _passwordController,
                            label: 'Password',
                            obscureText: _obscurePassword,
                            prefixIcon: const Icon(Icons.lock_outline, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _login(),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Password wajib diisi'
                                : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.dangerSoft,
                                borderRadius: AppRadius.md,
                                border: Border.all(
                                  color: AppColors.dangerText.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: AppColors.dangerText, size: 18),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.dangerText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            label: _isLoading ? 'Masuk…' : 'Masuk',
                            icon: Icons.login,
                            isLoading: _isLoading,
                            isFullWidth: true,
                            onPressed: _login,
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
    );
  }
}
