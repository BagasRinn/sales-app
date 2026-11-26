import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_system.dart';
import '../../core/datetime_utils.dart';
import '../../core/responsive.dart';
import '../../data/models/user_presence.dart';
import '../providers/admin_provider.dart';
import '../widgets/data_card.dart';

/// Status Online: pantauan presence user untuk MANAGER global.
///
/// Data dari `GET /users/presence` (tracking pasif `users.last_seen_at`).
/// Halaman mem-poll silent tiap 30 detik selama aktif; teks "terakhir
/// online" di-update tiap detik tanpa reload (murni re-render lokal).
class UserPresenceTab extends StatefulWidget {
  const UserPresenceTab({super.key});

  @override
  State<UserPresenceTab> createState() => _UserPresenceTabState();
}

class _UserPresenceTabState extends State<UserPresenceTab> {
  static const _pollInterval = Duration(seconds: 30);
  static const _headerHeight = 48.0;
  static const _rowHeight = 60.0;

  Timer? _pollTimer;
  Timer? _tickTimer;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _PresenceFilter _filter = _PresenceFilter.semua;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminProvider>().loadUserPresence();
    });
    // Poll silent: tidak menimpa loading/error sehingga UI tidak berkedip.
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      context.read<AdminProvider>().loadUserPresence(silent: true);
    });
    // Tick 1 detik hanya untuk relative time — murni re-render lokal.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presence = context.select<AdminProvider, UserPresenceResponse?>(
      (p) => p.userPresence,
    );
    final isLoading = context.select<AdminProvider, bool>(
      (p) => p.userPresenceLoading,
    );
    final error = context.select<AdminProvider, String?>(
      (p) => p.userPresenceError,
    );
    final provider = context.read<AdminProvider>();

    final users = _applyFilter(presence?.users ?? const []);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: AppFilterBar(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340, minWidth: 200),
                child: AppSearchField(
                  controller: _searchController,
                  hint: 'Cari user (nama / username)…',
                  onChanged: (v) => setState(() => _searchQuery = v),
                  onClear: () => setState(() => _searchQuery = ''),
                ),
              ),
              _filterChip(null, 'Semua'),
              _filterChip(_PresenceFilter.online, 'Online'),
              _filterChip(_PresenceFilter.offline, 'Offline'),
              AppButton(
                icon: Icons.refresh,
                label: 'Refresh',
                onPressed: isLoading
                    ? null
                    : () => provider.loadUserPresence(),
              ),
            ],
          ),
        ),
        if (error != null && presence == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _ErrorCard(message: error, onRetry: () => provider.loadUserPresence()),
          )
        else ...[
          _buildSummary(presence),
          Expanded(
            child: isLoading && presence == null
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: AppSkeletonList(),
                  )
                : users.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: AppEmptyState(
                      icon: Icons.wifi_tethering_off_outlined,
                      title: _searchQuery.isNotEmpty ||
                              _filter != _PresenceFilter.semua
                          ? 'User tidak ditemukan'
                          : 'Belum ada data presence',
                      message: _searchQuery.isNotEmpty ||
                              _filter != _PresenceFilter.semua
                          ? 'Ubah kata kunci atau filter.'
                          : 'Belum ada aktivitas user yang terdeteksi. '
                                'Data muncul setelah user login dan memakai aplikasi.',
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final resp = Responsive.of(constraints.maxWidth);
                      return resp.isMobile
                          ? _buildCardList(users)
                          : _buildTable(users);
                    },
                  ),
          ),
        ],
      ],
    );
  }

  List<UserPresenceItem> _applyFilter(List<UserPresenceItem> all) {
    final query = _searchQuery.trim().toLowerCase();
    return all.where((u) {
      if (_filter == _PresenceFilter.online && !u.isOnline) return false;
      if (_filter == _PresenceFilter.offline && u.isOnline) return false;
      if (query.isEmpty) return true;
      final nama = (u.nama ?? '').toLowerCase();
      return nama.contains(query) || u.username.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildSummary(UserPresenceResponse? presence) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _SummaryPill(
                label: 'Online',
                value: presence?.onlineCount ?? 0,
                color: AppColors.success,
                icon: Icons.circle,
              ),
              _SummaryPill(
                label: 'Offline',
                value: presence?.offlineCount ?? 0,
                color: AppColors.textSubtle,
                icon: Icons.circle_outlined,
              ),
              _SummaryPill(
                label: 'Total user aktif',
                value: presence?.totalUsers ?? 0,
                color: AppColors.primary,
                icon: Icons.people_outline,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _updatedAtLabel(presence, now),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSubtle,
            ),
          ),
        ],
      ),
    );
  }

  String _updatedAtLabel(UserPresenceResponse? presence, DateTime now) {
    final cacheTime = context.read<AdminProvider>().userPresenceCacheTime;
    if (cacheTime == null) return 'Memuat…';
    final seconds = now.difference(cacheTime).inSeconds;
    if (seconds < 5) return 'Baru diperbarui';
    return 'Diperbarui ${_relativeFromSeconds(seconds)}';
  }

  String _relativeFromSeconds(int seconds) {
    if (seconds < 60) return '$seconds detik lalu';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes menit lalu';
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours jam lalu';
    return '${hours ~/ 24} hari lalu';
  }

  Widget _filterChip(_PresenceFilter? value, String label) {
    final selected = value == _filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value ?? _PresenceFilter.semua),
      visualDensity: VisualDensity.compact,
    );
  }

  /// Waktu acuan perhitungan "X lalu": server_time dari backend supaya tidak
  /// terpengaruh clock skew device. Fallback ke jam device.
  DateTime _referenceNow(UserPresenceItem item) {
    final presence = context.read<AdminProvider>().userPresence;
    return presence?.serverTime ?? DateTime.now().toUtc();
  }

  String _lastSeenLabel(UserPresenceItem item) {
    final lastSeen = item.lastSeenAt;
    if (lastSeen == null) return 'Belum pernah online';
    final diff = _referenceNow(item).difference(lastSeen);
    final seconds = diff.inSeconds;
    if (seconds < 60) return 'Baru saja';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes menit lalu';
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours jam lalu';
    final days = hours ~/ 24;
    if (days < 7) return '$days hari lalu';
    // Lebih dari seminggu: tampil tanggal (pola formatter existing layar lain).
    return witaFormat(lastSeen, pattern: 'dd MMM yy HH:mm');
  }

  Widget _statusWidget(UserPresenceItem item) {
    if (item.lastSeenAt == null) {
      return const _PresenceDot(
        color: AppColors.textSubtle,
        label: 'Belum pernah online',
      );
    }
    if (item.isOnline) {
      return const _PresenceDot(color: AppColors.success, label: 'Online');
    }
    return const _PresenceDot(
      color: AppColors.textSubtle,
      label: 'Offline',
    );
  }

  Widget _buildCardList(List<UserPresenceItem> users) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resp = Responsive.of(constraints.maxWidth);
        final columns = resp.isMobile ? 1 : 2;
        const gap = 12.0;
        const hPadding = 12.0;
        final cardWidth =
            (constraints.maxWidth - 2 * hPadding - (columns - 1) * gap) /
            columns;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(hPadding, hPadding, hPadding, 16),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final u in users)
                SizedBox(
                  width: cardWidth,
                  child: DataCard(
                    title: u.displayName,
                    subtitle: '@${u.username}',
                    badges: [
                      _RoleBadge(role: u.role),
                      if (u.branchNama != null && u.branchNama!.isNotEmpty)
                        _BranchChip(label: u.branchNama!),
                    ],
                    fields: [
                      DataField(
                        label: 'STATUS',
                        valueWidget: _statusWidget(u),
                      ),
                      DataField(
                        label: 'TERAKHIR ONLINE',
                        value: _lastSeenLabel(u),
                      ),
                      if (u.branchNama != null || u.branch != null)
                        DataField(
                          label: 'CABANG',
                          value: u.branchNama ?? u.branch ?? '-',
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTable(List<UserPresenceItem> users) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth;
        const roleW = 130.0;
        const statusW = 170.0;
        const lastSeenW = 150.0;
        final remaining = avail - roleW - statusW - lastSeenW;
        final namaW = remaining * 0.38;
        final usernameW = remaining * 0.27;
        final cabangW = remaining * 0.35;
        final colWidths = [
          namaW,
          usernameW,
          roleW,
          cabangW,
          statusW,
          lastSeenW,
        ];
        final totalW = avail;

        return Column(
          children: [
            SizedBox(
              height: _headerHeight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: _buildHeader(colWidths, totalW),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    children: [
                      for (int i = 0; i < users.length; i++) ...[
                        _buildRow(users[i], colWidths, totalW),
                        if (i < users.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(List<double> colWidths, double totalW) {
    const labels = ['NAMA', 'USERNAME', 'ROLE', 'CABANG', 'STATUS', 'TERAKHIR ONLINE'];
    return SizedBox(
      width: totalW,
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            SizedBox(
              width: colWidths[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    labels[i],
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(UserPresenceItem u, List<double> colWidths, double totalW) {
    return SizedBox(
      height: _rowHeight,
      width: totalW,
      child: Row(
        children: [
          _cell(u.displayName, colWidths[0], bold: true),
          _cell('@${u.username}', colWidths[1]),
          SizedBox(
            width: colWidths[2],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _RoleBadge(role: u.role),
              ),
            ),
          ),
          _cell(u.branchNama ?? u.branch ?? '-', colWidths[3]),
          SizedBox(
            width: colWidths[4],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _statusWidget(u),
              ),
            ),
          ),
          _cell(_lastSeenLabel(u), colWidths[5]),
        ],
      ),
    );
  }

  Widget _cell(String text, double width, {bool bold = false}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bold
                ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)
                : AppTextStyles.bodyMedium,
          ),
        ),
      ),
    );
  }
}

enum _PresenceFilter { semua, online, offline }

class _PresenceDot extends StatelessWidget {
  final Color color;
  final String label;

  const _PresenceDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: color)),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: AppTextStyles.metric.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final variant = switch (role) {
      'ADMIN' => AppBadgeVariant.danger,
      'SUPERVISOR' => AppBadgeVariant.warning,
      'MANAGER' => AppBadgeVariant.info,
      _ => AppBadgeVariant.success,
    };
    return AppBadge(label: role, variant: variant, compact: true);
  }
}

class _BranchChip extends StatelessWidget {
  final String label;
  const _BranchChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return AppBadge(label: label, variant: AppBadgeVariant.info);
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 20, color: AppColors.dangerText),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.dangerText,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
