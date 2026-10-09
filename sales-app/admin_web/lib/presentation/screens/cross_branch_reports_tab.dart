import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/branch.dart';
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
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF2196F3),
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
              _buildSalesTab(),
              _buildStockTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalesTab() {
    if (_loadingSales) return const Center(child: CircularProgressIndicator());
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

  Widget _buildStockTab() {
    if (_loadingStock) return const Center(child: CircularProgressIndicator());
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Total Semua Cabang',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(spacing: 24, runSpacing: 8, children: [
              _buildStatChip('Approved', '$totalApproved', Colors.green),
              _buildStatChip('Pending', '$totalPending', Colors.orange),
              _buildStatChip('Omset', _formatRupiah(totalRevenue), Colors.blue),
              _buildStatChip('Customer', '$totalCustomers', Colors.purple),
              _buildStatChip('Sales', '$totalSales', Colors.teal),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesCard(BranchSalesSummary s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              BranchLabel.display(s.branch) ?? s.branch,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 20, runSpacing: 8, children: [
              _buildStatChip('Approved', '${s.approvedCount}', Colors.green),
              _buildStatChip('Omset', _formatRupiah(s.approvedRevenue), Colors.blue),
              _buildStatChip('Pending', '${s.pendingCount}', Colors.orange),
              _buildStatChip('Customer', '${s.customerCount}', Colors.purple),
              _buildStatChip('Sales', '${s.salesCount}', Colors.teal),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildStockCard(BranchStockSummary s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              BranchLabel.display(s.branch) ?? s.branch,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 20, runSpacing: 8, children: [
              _buildStatChip('SKU', '${s.skuCount}', Colors.blue),
              _buildStatChip('Nilai Stok', _formatRupiah(s.totalStockValue), Colors.indigo),
              _buildStatChip('Low Stock', '${s.lowStockCount}', s.lowStockCount > 0 ? Colors.red : Colors.grey),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
      ],
    );
  }

  Widget _buildEmpty(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
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
