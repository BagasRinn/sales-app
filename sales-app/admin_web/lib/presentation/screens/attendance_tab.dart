import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_system.dart';
import '../../core/datetime_utils.dart';
import '../../core/responsive.dart';
import '../../core/responsive_dialog.dart';
import '../../data/models/sales_attendance.dart';
import '../providers/admin_provider.dart';

/// Halaman "Absensi Kunjungan" — daftar kunjungan outlet yang dikirim sales
/// ke grup WhatsApp dan diteruskan worker Baileys ke backend.
///
/// Filter tanggal dikirim ke server; pencarian teks dan filter status nomor
/// difilter di client dari hasil tanggal tersebut.
class AttendanceTab extends StatefulWidget {
  const AttendanceTab({super.key});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  bool? _registeredFilter;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        _initialized = true;
        context.read<AdminProvider>().loadAttendances();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = context.select<AdminProvider, List<SalesAttendance>>(
      (p) => p.attendances,
    );
    final isLoading = context.select<AdminProvider, bool>(
      (p) => p.attendancesLoading,
    );
    final error = context.select<AdminProvider, String?>(
      (p) => p.attendancesError,
    );
    final date = context.select<AdminProvider, DateTime?>(
      (p) => p.attendanceDate,
    );
    final provider = context.read<AdminProvider>();

    final rows = _applyFilters(all);
    final dateLabel = date == null
        ? 'semua tanggal'
        : witaFormat(date, pattern: 'dd MMM yyyy');

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
              title: 'Absensi Kunjungan',
              subtitle: '${rows.length} kunjungan · $dateLabel',
              actions: [
                AppButton(
                  label: 'Muat ulang',
                  icon: Icons.refresh,
                  variant: AppButtonVariant.outline,
                  onPressed: () => provider.loadAttendances(forceRefresh: true),
                ),
              ],
            ),
            SizedBox(height: resp.sectionGap),
            _buildSummary(rows),
            SizedBox(height: resp.sectionGap),
            _buildFilters(resp, date),
            const SizedBox(height: AppSpacing.sm + 4),
            if (error != null && all.isEmpty)
              AppErrorState(
                message: error,
                onRetry: () => provider.loadAttendances(forceRefresh: true),
              )
            else if (isLoading && all.isEmpty)
              const AppSkeletonList(rows: 6)
            else if (rows.isEmpty)
              AppEmptyState(
                icon: Icons.fact_check_outlined,
                title: _hasActiveFilter
                    ? 'Tidak ada absensi yang cocok'
                    : 'Belum ada absensi',
                message: _hasActiveFilter
                    ? 'Coba ubah kata kunci atau filter status nomor.'
                    : 'Belum ada kunjungan outlet yang tercatat untuk '
                          '$dateLabel.',
                action: AppButton(
                  label: 'Muat ulang',
                  icon: Icons.refresh,
                  variant: AppButtonVariant.outline,
                  onPressed: () => provider.loadAttendances(forceRefresh: true),
                ),
              )
            else
              _buildTable(rows),
          ],
        );
      },
    );
  }

  bool get _hasActiveFilter =>
      _search.trim().isNotEmpty || _registeredFilter != null;

  List<SalesAttendance> _applyFilters(List<SalesAttendance> all) {
    final query = _search.trim().toLowerCase();
    return all.where((a) {
      if (_registeredFilter != null &&
          a.isRegisteredSales != _registeredFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = [
        a.outletCode,
        a.outletName,
        a.outletChannel,
        a.salesName ?? '',
        a.senderPushName ?? '',
        a.senderPhone,
        a.displayPhone,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Widget _buildSummary(List<SalesAttendance> rows) {
    final registered = rows.where((a) => a.isRegisteredSales).length;
    final unregistered = rows.length - registered;
    final uniqueOutlets = rows.map((a) => a.outletCode).toSet().length;
    final uniqueSales = rows
        .map((a) => a.salesId ?? a.senderPhone)
        .toSet()
        .length;
    final withPhoto = rows.where((a) => a.hasPhotoProof).length;

    return AppResponsiveGrid(
      desktopCols: 4,
      tabletCols: 2,
      mobileCols: 1,
      children: [
        AppStatCard(
          title: 'Total Kunjungan',
          value: '${rows.length}',
          icon: Icons.fact_check_outlined,
          subtitle: '$withPhoto dengan bukti foto',
        ),
        AppStatCard(
          title: 'Sales Terdaftar',
          value: '$registered',
          icon: Icons.verified_user_outlined,
          accentColor: AppColors.success,
          subtitle: 'Nomor WA cocok dengan user SALES',
        ),
        AppStatCard(
          title: 'Tidak Terdaftar',
          value: '$unregistered',
          icon: Icons.person_search_outlined,
          accentColor: unregistered > 0 ? AppColors.warning : null,
          subtitle: 'Perlu verifikasi nomor pengirim',
        ),
        AppStatCard(
          title: 'Outlet Unik',
          value: '$uniqueOutlets',
          icon: Icons.storefront_outlined,
          subtitle: '$uniqueSales sales berbeda',
        ),
      ],
    );
  }

  Widget _buildFilters(Responsive resp, DateTime? date) {
    final provider = context.read<AdminProvider>();
    final isToday = date != null && _isSameDay(date, DateTime.now());

    return AppFilterBar(
      children: [
        SizedBox(
          width: resp.isMobile ? double.infinity : 300,
          child: AppSearchField(
            controller: _searchController,
            hint: 'Cari sales, outlet, atau channel…',
            onChanged: (value) => setState(() => _search = value),
            onClear: () => setState(() => _search = ''),
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppChoiceChip(
              label: 'Hari ini',
              icon: Icons.today_outlined,
              dense: true,
              selected: isToday,
              onSelected: () => provider.setAttendanceDate(DateTime.now()),
            ),
            AppChoiceChip(
              label: 'Semua tanggal',
              icon: Icons.date_range_outlined,
              dense: true,
              selected: date == null,
              onSelected: () => provider.setAttendanceDate(null),
            ),
            AppButton(
              label: 'Pilih tanggal',
              icon: Icons.calendar_month_outlined,
              variant: AppButtonVariant.outline,
              onPressed: _pickDate,
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppChoiceChip(
              label: 'Semua status',
              dense: true,
              selected: _registeredFilter == null,
              onSelected: () => setState(() => _registeredFilter = null),
            ),
            AppChoiceChip(
              label: 'Terdaftar',
              dense: true,
              selected: _registeredFilter == true,
              onSelected: () => setState(() => _registeredFilter = true),
            ),
            AppChoiceChip(
              label: 'Tidak terdaftar',
              dense: true,
              selected: _registeredFilter == false,
              onSelected: () => setState(() => _registeredFilter = false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTable(List<SalesAttendance> rows) {
    return AppAdaptiveDataView<SalesAttendance>(
      rows: rows,
      onRowTap: _showDetail,
      emptyText: 'Belum ada absensi.',
      mobileItemBuilder: (context, item) => _mobileCard(item),
      columns: [
        AppTableColumn<SalesAttendance>(
          label: 'WAKTU',
          width: 120,
          cell: (a) => _timeCell(a),
        ),
        AppTableColumn<SalesAttendance>(
          label: 'SALES',
          width: 200,
          cell: (a) => _salesCell(a),
        ),
        AppTableColumn<SalesAttendance>(
          label: 'OUTLET',
          width: 230,
          cell: (a) => _outletCell(a),
        ),
        AppTableColumn<SalesAttendance>(
          label: 'CHANNEL',
          width: 110,
          cell: (a) => AppBadge(
            label: a.outletChannel.isEmpty ? '-' : a.outletChannel,
            variant: AppBadgeVariant.info,
            compact: true,
          ),
        ),
        AppTableColumn<SalesAttendance>(
          label: 'BUKTI',
          width: 90,
          cell: (a) => AppBadge(
            label: a.hasPhotoProof ? 'Ada' : 'Tidak',
            icon: a.hasPhotoProof
                ? Icons.photo_camera_outlined
                : Icons.no_photography_outlined,
            variant: a.hasPhotoProof
                ? AppBadgeVariant.success
                : AppBadgeVariant.neutral,
            compact: true,
          ),
        ),
        AppTableColumn<SalesAttendance>(
          label: 'STATUS',
          width: 150,
          cell: (a) => AppBadge(
            label: a.isRegisteredSales ? 'Terdaftar' : 'Tidak terdaftar',
            variant: a.isRegisteredSales
                ? AppBadgeVariant.success
                : AppBadgeVariant.warning,
            compact: true,
          ),
        ),
      ],
    );
  }

  Widget _timeCell(SalesAttendance a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          witaFormat(a.visitedAt, pattern: 'dd MMM yyyy'),
          style: AppTextStyles.bodySmall,
        ),
        Text(
          witaFormat(a.visitedAt, pattern: 'HH:mm'),
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  Widget _salesCell(SalesAttendance a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          a.displayName,
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(a.displayPhone, style: AppTextStyles.caption),
      ],
    );
  }

  Widget _outletCell(SalesAttendance a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          a.outletName,
          style: AppTextStyles.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(a.outletCode, style: AppTextStyles.caption),
      ],
    );
  }

  Widget _mobileCard(SalesAttendance a) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => _showDetail(a),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  a.displayName,
                  style: AppTextStyles.h3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                witaFormat(a.visitedAt, pattern: 'HH:mm'),
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            '${a.outletName} · ${a.outletCode}',
            style: AppTextStyles.bodyMuted,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm - 2,
            runSpacing: AppSpacing.xs + 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppBadge(
                label: a.outletChannel.isEmpty ? '-' : a.outletChannel,
                variant: AppBadgeVariant.info,
                compact: true,
              ),
              AppBadge(
                label: a.isRegisteredSales ? 'Terdaftar' : 'Tidak terdaftar',
                variant: a.isRegisteredSales
                    ? AppBadgeVariant.success
                    : AppBadgeVariant.warning,
                compact: true,
              ),
              if (a.hasPhotoProof)
                const AppBadge(
                  label: 'Foto',
                  icon: Icons.photo_camera_outlined,
                  variant: AppBadgeVariant.success,
                  compact: true,
                ),
              Text(a.displayPhone, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final provider = context.read<AdminProvider>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.attendanceDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Pilih tanggal kunjungan',
    );
    if (picked != null) {
      await provider.setAttendanceDate(picked);
    }
  }

  Future<void> _showDetail(SalesAttendance a) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => ResponsiveAlertDialog(
        title: const Text('Detail Absensi'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Sales', a.displayName),
              _detailRow('Nomor pengirim', a.displayPhone),
              _detailRow('Push name', a.senderPushName ?? '-'),
              _detailRow('Outlet', '${a.outletName} (${a.outletCode})'),
              _detailRow('Channel', a.outletChannel),
              _detailRow(
                'Waktu kunjungan',
                witaFormat(a.visitedAt, pattern: 'dd MMM yyyy, HH:mm'),
              ),
              _detailRow('Bukti foto', a.hasPhotoProof ? 'Ada' : 'Tidak ada'),
              _detailRow(
                'Status nomor',
                a.isRegisteredSales ? 'Terdaftar' : 'Tidak terdaftar',
              ),
              _detailRow('Grup WhatsApp', a.waGroupId ?? '-'),
              _detailRow('ID pesan', a.waMessageId ?? '-'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: AppTextStyles.caption),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
