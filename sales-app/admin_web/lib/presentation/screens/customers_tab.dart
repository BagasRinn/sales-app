import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../providers/admin_provider.dart';
import '../../data/models/customer.dart';
import '../../data/models/sales_user.dart';
import '../../data/models/sales_assignment.dart';

class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  String _searchQuery = '';
  bool _initialized = false;
  final _searchController = TextEditingController();

  static const _headerHeight = 48.0;
  static const _rowHeight = 60.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminProvider>();
      if (!_initialized && provider.customers.isEmpty) {
        _initialized = true;
        provider.loadCustomers();
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
    final customers = context.select<AdminProvider, List<Customer>>(
      (p) => p.customers,
    );
    final isLoading = context.select<AdminProvider, bool>((p) => p.isLoading);
    final total = context.select<AdminProvider, int>((p) => p.customerTotal);
    final page = context.select<AdminProvider, int>((p) => p.customerPage);
    final totalPages =
        context.select<AdminProvider, int>((p) => p.customerTotalPages);
    final hasPrev =
        context.select<AdminProvider, bool>((p) => p.hasPrevCustomerPage);
    final hasNext =
        context.select<AdminProvider, bool>((p) => p.hasNextCustomerPage);
    final provider = context.read<AdminProvider>();

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.surface,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari toko...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              provider.clearCustomerSearch();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) {
                    setState(() => _searchQuery = v);
                    provider.searchCustomers(v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '$total toko',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Table
        Expanded(
          child: isLoading && customers.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : customers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.store_outlined,
                              size: 48,
                              color:
                                  AppColors.textMuted.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Toko tidak ditemukan'
                                : 'Belum ada toko',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : _buildTable(customers),
        ),
        // Pagination
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: hasPrev ? () => provider.prevCustomerPage() : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Halaman sebelumnya',
              ),
              const SizedBox(width: 8),
              Text(
                'Halaman ${page + 1} dari ${totalPages == 0 ? 1 : totalPages}',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: hasNext ? () => provider.nextCustomerPage() : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Halaman berikutnya',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<Customer> customers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth;
        // Kode fixed, Nama flex, Alamat flex, Aksi fixed
        const kodeW = 110.0;
        const aksiW = 120.0;
        final remaining = avail - kodeW - aksiW;
        final namaW = remaining * 0.4;
        final alamatW = remaining * 0.6;
        final colWidths = [kodeW, namaW, alamatW, aksiW];
        final totalW = avail;

        return Column(
          children: [
            // Header
            SizedBox(
              height: _headerHeight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: _buildHeader(colWidths, totalW),
              ),
            ),
            const Divider(height: 1),
            // Rows
            Expanded(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    children: [
                      for (int i = 0; i < customers.length; i++) ...[
                        _buildRow(customers[i], colWidths, totalW),
                        if (i < customers.length - 1)
                          const Divider(height: 1),
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
    const labels = ['KODE', 'NAMA TOKO', 'ALAMAT', 'AKSI'];
    return SizedBox(
      width: totalW,
      child: Container(
        color: AppColors.surface,
        child: Row(
          children: [
            for (int i = 0; i < labels.length; i++)
              SizedBox(
                width: colWidths[i],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
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
      ),
    );
  }

  Widget _buildRow(Customer c, List<double> colWidths, double totalW) {
    return SizedBox(
      width: totalW,
      height: _rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: colWidths[0],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(c.kode ?? '-', style: AppTextStyles.mono.copyWith(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ),
          SizedBox(
            width: colWidths[1],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(c.namaToko, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500), maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
          ),
          SizedBox(
            width: colWidths[2],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(c.alamat ?? '-', style: AppTextStyles.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
          ),
          SizedBox(
            width: colWidths[3],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _openDetail(c),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    color: AppColors.primaryLight,
                    tooltip: 'Lihat / edit',
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(c),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppColors.error,
                    tooltip: 'Hapus toko',
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(Customer c) async {
    final provider = context.read<AdminProvider>();
    await showDialog(
      context: context,
      builder: (_) => _CustomerDetailDialog(
        customerId: c.id,
        provider: provider,
      ),
    );
  }

  Future<void> _confirmDelete(Customer c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Toko'),
        content: Text(
          'Yakin ingin menghapus "${c.namaToko}"?\n\n'
          'Toko akan di-soft-delete (bisa di-restore lewat import Excel).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final provider = context.read<AdminProvider>();
    final success = await provider.deleteCustomer(c.id);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Toko "${c.namaToko}" berhasil dihapus'),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              provider.errorMessage ?? 'Gagal menghapus toko'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _CustomerDetailDialog extends StatefulWidget {
  final String customerId;
  final AdminProvider provider;
  const _CustomerDetailDialog({required this.customerId, required this.provider});

  @override
  State<_CustomerDetailDialog> createState() => _CustomerDetailDialogState();
}

class _CustomerDetailDialogState extends State<_CustomerDetailDialog> {
  Customer? _customer;
  List<SalesUser> _allSales = [];
  bool _loadingDetail = true;
  bool _saving = false;
  String? _loadError;

  late TextEditingController _kodeC;
  late TextEditingController _namaC;
  late TextEditingController _alamatC;
  Set<String> _selectedSalesIds = {};

  @override
  void initState() {
    super.initState();
    _kodeC = TextEditingController();
    _namaC = TextEditingController();
    _alamatC = TextEditingController();
    _loadDetail();
  }

  @override
  void dispose() {
    _kodeC.dispose();
    _namaC.dispose();
    _alamatC.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loadingDetail = true;
      _loadError = null;
    });
    try {
      final provider = widget.provider;
      final results = await Future.wait([
        provider.getCustomerDetail(widget.customerId),
        provider.getCustomerAssignments(widget.customerId),
        provider.listSalesUsers(),
      ]);
      final c = results[0] as Customer;
      final assignments = results[1] as List<SalesAssignment>;
      final sales = results[2] as List<SalesUser>;

      if (!mounted) return;

      setState(() {
        _customer = c;
        _allSales = sales;
        _kodeC.text = c.kode ?? '';
        _namaC.text = c.namaToko;
        _alamatC.text = c.alamat ?? '';
        _selectedSalesIds = assignments.map((a) => a.salesId).toSet();
        _loadingDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDetail = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _save() async {
    if (_customer == null) return;
    if (_namaC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nama toko wajib diisi'),
            backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _saving = true);
    final provider = widget.provider;
    final body = {
      'nama_toko': _namaC.text.trim(),
      if (_kodeC.text.trim().isNotEmpty) 'kode': _kodeC.text.trim(),
      'alamat': _alamatC.text.trim().isEmpty ? null : _alamatC.text.trim(),
    };
    final okUpdate = await provider.updateCustomer(_customer!.id, body);
    if (!okUpdate) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(provider.errorMessage ?? 'Gagal menyimpan'),
            backgroundColor: AppColors.error),
      );
      return;
    }
    final okAssign = await provider.assignCustomerSales(
      _customer!.id,
      _selectedSalesIds.toList(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (okAssign) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Toko berhasil disimpan'),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(provider.errorMessage ?? 'Gagal menyimpan assignment'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 720,
        height: 620,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Expanded(
              child: _loadingDetail
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                      ? _buildError()
                      : _buildForm(),
            ),
            const Divider(height: 1),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.store, color: AppColors.success, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_customer?.namaToko ?? 'Detail Toko',
                    style: AppTextStyles.headlineSmall),
                Text(
                  _customer == null
                      ? 'Memuat...'
                      : 'ID: ${_customer!.id.substring(0, 8)}...',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    final short = (_loadError ?? '').split('\n').take(3).join('\n');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.error),
          const SizedBox(height: 12),
          const Text('Gagal memuat detail toko',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: 4),
          Flexible(
            child: SingleChildScrollView(
              child: Text(
                short,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loadDetail,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'Kode',
                  controller: _kodeC,
                  hint: 'cth: OUT001',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _Field(
                  label: 'Nama Toko *',
                  controller: _namaC,
                  hint: 'cth: Toko Maju Jaya',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Alamat',
            controller: _alamatC,
            hint: 'cth: Jl. Sudirman No. 12',
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Text('Sales yang Ditugaskan', style: AppTextStyles.labelLarge),
          const SizedBox(height: 4),
          Text(
            'Centang sales yang boleh mengambil order untuk toko ini.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 8),
          _buildSalesSelector(),
        ],
      ),
    );
  }

  Widget _buildSalesSelector() {
    if (_allSales.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'Belum ada user sales — buat user SALES dulu di menu user management.',
          style: AppTextStyles.bodySmall,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            for (final s in _allSales)
              CheckboxListTile(
                dense: true,
                value: _selectedSalesIds.contains(s.id),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedSalesIds.add(s.id);
                    } else {
                      _selectedSalesIds.remove(s.id);
                    }
                  });
                },
                title: Text(s.displayName, style: AppTextStyles.bodyMedium),
                subtitle: Text(s.role, style: AppTextStyles.bodySmall),
                controlAffinity: ListTileControlAffinity.leading,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save, size: 18),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}