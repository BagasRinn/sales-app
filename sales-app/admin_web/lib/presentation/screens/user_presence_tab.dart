import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_system.dart';
import '../../core/datetime_utils.dart';
import '../../core/responsive.dart';
import '../../data/models/user_presence.dart';
import '../providers/admin_provider.dart';

/// Status Online: pantauan presence SUPERVISOR untuk MANAGER global.
///
/// MANAGER memantau keaktifan supervisor dalam monitoring kinerja cabang,
/// jadi hanya user ber-role SUPERVISOR yang tampil (difilter di server).
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
    final onlineCount = presence?.onlineCount ?? 0;
    final total = presence?.totalUsers ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final resp = Responsive.of(constraints.maxWidth);
        return ListView(
          padding: EdgeInsets.fromLTRB(
            resp.contentPadding,
            resp.isMobile ? 12 : 20,
            resp.contentPadding,
            32,
          ),
          children: [
            AppPageHeader(
              title: 'Status Online',
              subtitle: '$onlineCount/$total supervisor online · '
                  '${_updatedAtLabel()}',
              actions: [
                AppButton(
                  label: 'Muat ulang',
                  icon: Icons.refresh,
                  variant: AppButtonVariant.outline,
                  onPressed: isLoading
                      ? null
                      : () => provider.loadUserPresence(),
                ),
              ],
            ),
            SizedBox(height: resp.sectionGap),
            _buildSummary(presence),
            SizedBox(height: resp.sectionGap),
            _buildFilters(),
            const SizedBox(height: AppSpacing.sm + 4),
            if (error != null && presence == null)
              AppErrorState(
                message: error,
                onRetry: () => provider.loadUserPresence(),
              )
            else if (isLoading && presence == null)
              const AppSkeletonList(rows: 6)
            else if (users.isEmpty)
              AppEmptyState(
                icon: Icons.wifi_tethering_off_outlined,
                title: _hasActiveFilter
                    ? 'Supervisor tidak ditemukan'
                    : 'Belum ada data presence',
                message: _hasActiveFilter
                    ? 'Ubah kata kunci atau filter.'
                    : 'Belum ada aktivitas supervisor yang terdeteksi. '
                          'Data muncul setelah supervisor login dan memakai '
                          'aplikasi.',
              )
            else
              _buildTable(users),
          ],
        );
      },
    );
  }

  bool get _hasActiveFilter =>
      _searchQuery.trim().isNotEmpty || _filter != _PresenceFilter.semua;

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
    return Wrap(
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
          label: 'Total supervisor',
          value: presence?.totalUsers ?? 0,
          color: AppColors.primary,
          icon: Icons.supervisor_account_outlined,
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return AppFilterBar(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340, minWidth: 200),
          child: AppSearchField(
            controller: _searchController,
            hint: 'Cari supervisor (nama / username)…',
            onChanged: (v) => setState(() => _searchQuery = v),
            onClear: () => setState(() => _searchQuery = ''),
          ),
        ),
        AppChoiceChip(
          label: 'Semua',
          dense: true,
          selected: _filter == _PresenceFilter.semua,
          onSelected: () => setState(() => _filter = _PresenceFilter.semua),
        ),
        AppChoiceChip(
          label: 'Online',
          dense: true,
          selected: _filter == _PresenceFilter.online,
          onSelected: () => setState(() => _filter = _PresenceFilter.online),
        ),
        AppChoiceChip(
          label: 'Offline',
          dense: true,
          selected: _filter == _PresenceFilter.offline,
          onSelected: () => setState(() => _filter = _PresenceFilter.offline),
        ),
      ],
    );
  }

  String _updatedAtLabel() {
    final cacheTime = context.read<AdminProvider>().userPresenceCacheTime;
    if (cacheTime == null) return 'memuat…';
    final seconds = DateTime.now().difference(cacheTime).inSeconds;
    if (seconds < 5) return 'baru diperbarui';
    return 'diperbarui ${_relativeFromSeconds(seconds)}';
  }

  String _relativeFromSeconds(int seconds) {
    if (seconds < 60) return '$seconds detik lalu';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes menit lalu';
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours jam lalu';
    return '${hours ~/ 24} hari lalu';
  }

  /// Waktu acuan perhitungan "X lalu": server_time dari backend supaya tidak
  /// terpengaruh clock skew device. Fallback ke jam device.
  DateTime _referenceNow() {
    final presence = context.read<AdminProvider>().userPresence;
    return presence?.serverTime ?? DateTime.now().toUtc();
  }

  String _lastSeenLabel(UserPresenceItem item) {
    final lastSeen = item.lastSeenAt;
    if (lastSeen == null) return 'Belum pernah online';
    final seconds = _referenceNow().difference(lastSeen).inSeconds;
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

  Widget _statusCell(UserPresenceItem item) {
    if (item.lastSeenAt == null) {
      return const _PresenceDot(
        color: AppColors.textSubtle,
        label: 'Belum pernah online',
      );
    }
    if (item.isOnline) {
      return const _PresenceDot(color: AppColors.success, label: 'Online');
    }
    return const _PresenceDot(color: AppColors.textSubtle, label: 'Offline');
  }

  Widget _roleBadge(String role) {
    final variant = switch (role) {
      'ADMIN' => AppBadgeVariant.danger,
      'SUPERVISOR' => AppBadgeVariant.warning,
      'MANAGER' => AppBadgeVariant.info,
      _ => AppBadgeVariant.success,
    };
    return AppBadge(label: role, variant: variant, compact: true);
  }

  Widget _buildTable(List<UserPresenceItem> users) {
    return AppAdaptiveDataView<UserPresenceItem>(
      rows: users,
      emptyText: 'Belum ada data presence.',
      mobileItemBuilder: (context, item) => _mobileCard(item),
      columns: [
        AppTableColumn<UserPresenceItem>(
          label: 'NAMA',
          width: 220,
          cell: (u) => Text(
            u.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        AppTableColumn<UserPresenceItem>(
          label: 'USERNAME',
          width: 160,
          cell: (u) => Text('@${u.username}', style: AppTextStyles.bodyMedium),
        ),
        AppTableColumn<UserPresenceItem>(
          label: 'ROLE',
          width: 120,
          cell: (u) => _roleBadge(u.role),
        ),
        AppTableColumn<UserPresenceItem>(
          label: 'CABANG',
          width: 160,
          cell: (u) => Text(
            u.branchNama ?? u.branch ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium,
          ),
        ),
        AppTableColumn<UserPresenceItem>(
          label: 'STATUS',
          width: 170,
          cell: _statusCell,
        ),
        AppTableColumn<UserPresenceItem>(
          label: 'TERAKHIR ONLINE',
          width: 150,
          cell: (u) => Text(_lastSeenLabel(u), style: AppTextStyles.bodyMedium),
        ),
      ],
    );
  }

  Widget _mobileCard(UserPresenceItem u) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  u.displayName,
                  style: AppTextStyles.h3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _statusCell(u),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            '@${u.username}',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm - 2,
            runSpacing: AppSpacing.xs + 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _roleBadge(u.role),
              if (u.branchNama != null && u.branchNama!.isNotEmpty)
                AppBadge(
                  label: u.branchNama!,
                  variant: AppBadgeVariant.info,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Terakhir online: ${_lastSeenLabel(u)}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
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
