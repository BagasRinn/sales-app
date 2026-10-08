import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bulletin_provider.dart';
import '../bulletin/bulletin_screen.dart';
import '../auth/change_password_dialog.dart';

class MiscScreen extends StatelessWidget {
  const MiscScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final bulletin = context.watch<BulletinProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lainnya'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      (auth.nama ?? auth.username ?? 'S')[0].toUpperCase(),
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.nama ?? '-',
                          style: AppTextStyles.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${auth.username ?? '-'}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.infoBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'SALES',
                            style: AppTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryLight,
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
          const SizedBox(height: 20),

          // Menu section
          Text(
            'MENU',
            style: AppTextStyles.labelMedium.copyWith(
              letterSpacing: 1,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          // Promo & Diskon
          _MenuCard(
            icon: Icons.local_offer_outlined,
            iconColor: AppColors.warning,
            badge: bulletin.unreadCount > 0 ? bulletin.unreadCount : null,
            title: 'Promo & Diskon',
            subtitle: 'Lihat promo dari admin',
            onTap: () {
              bulletin.loadBulletins(includeRead: true);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BulletinScreen(),
                ),
              );
            },
          ),

          // Ganti Password
          _MenuCard(
            icon: Icons.lock_outline,
            title: 'Ganti Password',
            subtitle: 'Ubah password login Anda',
            onTap: () => ChangePasswordDialog.show(context, auth),
          ),

          const SizedBox(height: 20),

          // Lainnya section
          Text(
            'LAINNYA',
            style: AppTextStyles.labelMedium.copyWith(
              letterSpacing: 1,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          _MenuCard(
            icon: Icons.help_outline,
            title: 'Bantuan',
            subtitle: 'Hubungi admin untuk bantuan',
            onTap: () => _showHelpDialog(context),
          ),
          _MenuCard(
            icon: Icons.info_outline,
            title: 'Tentang Aplikasi',
            subtitle: 'Versi 1.0.0',
            onTap: () => _showAboutDialog(context),
          ),

          const SizedBox(height: 20),

          // Logout
          _MenuCard(
            icon: Icons.logout,
            title: 'Keluar',
            subtitle: 'Logout dari aplikasi',
            isDestructive: true,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.help_outline,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(width: 12),
            Text('Bantuan', style: AppTextStyles.headlineSmall),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Untuk bantuan, hubungi admin di:'),
            const SizedBox(height: 12),
            const Text('Email: admin@practicalbeauty.com'),
            const SizedBox(height: 4),
            const Text('WhatsApp: -'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primaryLight),
            const SizedBox(width: 8),
            Text('Tentang Aplikasi', style: AppTextStyles.headlineSmall),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Web App',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text('Versi 1.0.0', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 8),
            Text(
              'Aplikasi manajemen pesanan sales untuk platform web.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.logout,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Text('Konfirmasi Keluar', style: AppTextStyles.headlineSmall),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari aplikasi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().logout();
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  final int? badge;

  const _MenuCard({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
    final bgColor = isDestructive ? AppColors.errorBg : AppColors.borderLight;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            if (badge != null)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          title,
          style: AppTextStyles.labelLarge.copyWith(color: color),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: color.withValues(alpha: 0.6),
                ),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right,
          color: color.withValues(alpha: 0.3),
        ),
        onTap: onTap,
      ),
    );
  }
}
