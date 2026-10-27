import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/branch.dart';
import '../../core/design_system.dart';
import '../../core/responsive.dart';
import '../../data/models/branch_report.dart';
import '../providers/admin_provider.dart';

class CrossBranchReportsTab extends StatefulWidget {
  const CrossBranchReportsTab({super.key});

  @override
  State<CrossBranchReportsTab> createState() => _CrossBranchReportsTabState();
}

class _CrossBranchReportsTabState extends State<CrossBranchReportsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<BranchSalesSummary> _salesSummaries = [];
  List<BranchStockSummary> _stockSummaries = [];
  bool _loadingSales = false;
  bool _loadingStock = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final repo = context.read<AdminProvider>().repository;
    setState(() => _error = null);

    // Load both in parallel
    setState(() => _loadingSales = true);
    setState(() => _loadingStock = true);

    try {
      final results = await Future.wait([
        repo.getCrossBranchSalesSummary().then((r) {
          if (mounted) setState(() => _loadingSales = false);
          return r;
        }).catchError((e) {
          if (mounted) {
            setState(() {
              _loadingSales = false;
              _error = 'Gagal memuat laporan penjualan: $e';
            });
          }
          return <BranchSalesSummary>[];
        }),
        repo.getCrossBranchStockSummary().then((r) {
          if (mounted) setState(() => _loadingStock = false);
          return r;
        }).catchError((e) {
          if (mounted) {
            setState(() {
              _loadingStock = false;
              _error = _error ?? 'Gagal memuat laporan stok: $e';
            });
          }
          return <BranchStockSummary>[];
        }),
      ]);
      if (mounted) {
        setState(() {
          _salesSummaries = results[0] as List<BranchSalesSummary>;
          _stockSummaries = results[1] as List<BranchStockSummary>;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resp = Responsive.of(constraints.maxWidth);
        return Column(
          children: [
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabController,
                // Hardcoded label/indicator colors dropped — AppTheme.lightTheme
                // provides them via ColorScheme.primary (AppColors.primaryLight).
                // Scrollable supaya tab "Penjualan/Stok" bisa discroll di
                // layar sempit (untuk konsistensi dengan tab Pesanan).
                isScrollable: resp.isCompact,
                tabs: const [
                  Tab(text: 'Penjualan'),
                  Tab(text: 'Stok'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSalesTab(resp),
                  _buildStockTab(resp),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSalesTab(Responsive resp) {
    if (_loadingSales) return _buildSkeleton();
    if (_salesSummaries.isEmpty) {
      return _buildEmpty('Belum ada data penjualan lintas cabang.');
    }
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loadingSales = true);
        try {
          final data = await context.read<AdminProvider>().repository
              .getCrossBranchSalesSummary();
          if (mounted) setState(() => _salesSummaries = data);
        } finally {
          if (mounted) setState(() => _loadingSales = false);
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTotalCard(),
            const SizedBox(height: 16),
            ..._salesSummaries.map((s) => _buildSalesCard(s)),
          ],
        ),
      ),
    );
  }

  Widget _buildStockTab(Responsive resp) {
    if (_loadingStock) return _buildSkeleton();
    if (_stockSummaries.isEmpty) {
      return _buildEmpty('Belum ada data stok lintas cabang.');
    }
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loadingStock = true);
        try {
          final data = await context.read<AdminProvider>().repository
              .getCrossBranchStockSummary();
          if (mounted) setState(() => _stockSummaries = data);
        } finally {
          if (mounted) setState(() => _loadingStock = false);
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _stockSummaries.map((s) => _buildStockCard(s)).toList(),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: AppSkeletonList(rows: 5),
    );
  }

  Widget _buildTotalCard() {
    final totalRevenue = _salesSummaries.fold<int>(
      0, (sum, s) => sum + s.approvedRevenue);
    final totalApproved = _salesSummaries.fold<int>(
      0, (sum, s) => sum + s.approvedCount);
    final totalPending = _salesSummaries.fold<int>(
      0, (sum, s) => sum + s.pendingCount);
    final totalCustomers = _salesSummaries.fold<int>(
      0, (sum, s) => sum + s.customerCount);
    final totalSales = _salesSummaries.fold<int>(
      0, (sum, s) => sum + s.salesCount);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Semua Cabang — Bulan Ini', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm + 4),
          Wrap(spacing: AppSpacing.lg, runSpacing: AppSpacing.sm, children: [
            _buildStatChip('Approved', '$totalApproved', AppColors.successText),
            _buildStatChip('Pending', '$totalPending', AppColors.warningText),
            _buildStatChip('Omset', _formatRupiah(totalRevenue), AppColors.infoText),
            _buildStatChip('Customer', '$totalCustomers', AppColors.textPrimary),
            _buildStatChip('Sales', '$totalSales', AppColors.textPrimary),
          ]),
        ],
      ),
    );
  }

  Widget _buildSalesCard(BranchSalesSummary s) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            BranchLabel.display(s.branch) ?? s.branch,
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.lg, runSpacing: AppSpacing.sm, children: [
            _buildStatChip('Approved', '${s.approvedCount}', AppColors.successText),
            _buildStatChip('Omset', _formatRupiah(s.approvedRevenue), AppColors.infoText),
            _buildStatChip('Pending', '${s.pendingCount}', AppColors.warningText),
            _buildStatChip('Customer', '${s.customerCount}', AppColors.textPrimary),
            _buildStatChip('Sales', '${s.salesCount}', AppColors.textPrimary),
          ]),
        ],
      ),
    );
  }

  Widget _buildStockCard(BranchStockSummary s) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            BranchLabel.display(s.branch) ?? s.branch,
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.lg, runSpacing: AppSpacing.sm, children: [
            _buildStatChip('SKU', '${s.skuCount}', AppColors.infoText),
            _buildStatChip(
              'Nilai Stok',
              _formatRupiah(s.totalStockValue),
              AppColors.textPrimary,
            ),
            _buildStatChip(
              'Low Stock',
              '${s.lowStockCount}',
              s.lowStockCount > 0
                  ? AppColors.dangerText
                  : AppColors.textSecondary,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.h3.copyWith(
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(String msg) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AppErrorState(message: _error!, onRetry: _loadData),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: AppEmptyState(
        icon: Icons.inbox_outlined,
        title: msg,
        action: AppButton(
          label: 'Muat ulang',
          icon: Icons.refresh,
          variant: AppButtonVariant.outline,
          onPressed: _loadData,
        ),
      ),
    );
  }

  String _formatRupiah(int value) {
    if (value >= 1000000) {
      return 'Rp ${(value / 1000000).toStringAsFixed(1)}jt';
    } else if (value >= 1000) {
      return 'Rp ${(value / 1000).toStringAsFixed(0)}rb';
    }
    return 'Rp $value';
  }
}
