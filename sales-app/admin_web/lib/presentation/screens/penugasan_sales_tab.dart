import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_system.dart';
import '../../data/models/customer.dart';
import '../../data/models/sales_user.dart';
import '../../data/models/sales_assignment.dart';
import '../../data/models/user_item.dart';
import '../providers/admin_provider.dart';

/// Tab "Penugasan Sales" — manager/admin only.
/// 3 sub-view: "Per Area" (default), "Per Customer", "Per Sales".
/// Area-based assignment adalah default — manager tinggal pilih area → pilih sales
/// → semua customer di area itu otomatis ke-cover. Customer-level jadi override.
class PenugasanSalesTab extends StatefulWidget {
  const PenugasanSalesTab({super.key});

  @override
  State<PenugasanSalesTab> createState() => _PenugasanSalesTabState();
}

class _PenugasanSalesTabState extends State<PenugasanSalesTab> {
  int _subView = 0; // 0=Per Area, 1=Per Customer, 2=Per Sales
  final _searchController = TextEditingController();
  String _search = '';

  List<Customer> _allCustomers = [];
  List<SalesUser> _allSalesUsers = [];
  List<UserItem> _allUsers = [];
  List<Map<String, dynamic>> _areaAssignments = [];
  bool _loading = true;
  int? _customerTotal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final provider = context.read<AdminProvider>();
    try {
      final results = await Future.wait([
        provider.adminRepository.getCustomers(
          search: null, page: 0, limit: 500,
        ),
        provider.adminRepository.getCustomerCount(),
        provider.listSalesUsers(),
        provider.adminRepository.getUsers(role: 'SALES'),
        provider.getAreaAssignments(),
      ]);
      if (!mounted) return;
      setState(() {
        _allCustomers = results[0] as List<Customer>;
        _customerTotal = results[1] as int;
        _allSalesUsers = results[2] as List<SalesUser>;
        _allUsers = results[3] as List<UserItem>;
        _areaAssignments = results[4] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Customer> get _filteredCustomers {
    if (_search.isEmpty) return _allCustomers;
    final s = _search.toLowerCase();
    return _allCustomers.where((c) {
      return c.namaToko.toLowerCase().contains(s) ||
          (c.kode?.toLowerCase().contains(s) ?? false) ||
          (c.alamat?.toLowerCase().contains(s) ?? false) ||
          (c.kodeArea?.toLowerCase().contains(s) ?? false);
    }).toList();
  }

  List<UserItem> get _filteredSales {
    if (_search.isEmpty) return _allUsers;
    final s = _search.toLowerCase();
    return _allUsers.where((u) =>
      u.username.toLowerCase().contains(s) ||
      (u.nama?.toLowerCase().contains(s) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          color: AppColors.surface,
          child: Row(
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Per Area'), icon: Icon(Icons.map_outlined)),
                  ButtonSegment(value: 1, label: Text('Per Customer'), icon: Icon(Icons.store_outlined)),
                  ButtonSegment(value: 2, label: Text('Per Sales'), icon: Icon(Icons.person_outline)),
                ],
                selected: {_subView},
                onSelectionChanged: (s) => setState(() => _subView = s.first),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: _subView == 0
                        ? 'Cari area...'
                        : _subView == 1
                            ? 'Cari customer...'
                            : 'Cari sales...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _subView == 0
              ? _PerAreaView(
                  areas: _filteredAreaRows(),
                  onChanged: _loadAll,
                  allSalesUsers: _allSalesUsers,
                )
              : _subView == 1
                  ? _PerCustomerView(
                      customers: _filteredCustomers,
                      totalCount: _customerTotal ?? _allCustomers.length,
                      allSalesUsers: _allSalesUsers,
                      onChanged: _loadAll,
                    )
                  : _PerSalesView(
                      salesUsers: _filteredSales,
                      onChanged: _loadAll,
                    ),
        ),
      ],
    );
  }

  /// Convert API response + filter by search.
  List<_AreaRow> _filteredAreaRows() {
    final s = _search.toLowerCase();
    final rows = _areaAssignments
        .map((m) => _AreaRow(
              kodeArea: m['kode_area'] as String,
              sales: ((m['sales'] as List?) ?? [])
                  .map((e) => SalesAssignment.fromJson(e as Map<String, dynamic>))
                  .toList(),
            ))
        .toList();
    if (s.isEmpty) return rows;
    return rows.where((r) => r.kodeArea.toLowerCase().contains(s)).toList();
  }
}

class _AreaRow {
  final String kodeArea;
  final List<SalesAssignment> sales;
  _AreaRow({required this.kodeArea, required this.sales});
}

// ==================== Per Area sub-view ====================

class _PerAreaView extends StatelessWidget {
  final List<_AreaRow> areas;
  final List<SalesUser> allSalesUsers;
  final VoidCallback onChanged;

  const _PerAreaView({
    required this.areas,
    required this.allSalesUsers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (areas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                'Belum ada customer dengan kode_area. Import customer dengan kolom kode_area di Excel untuk memulai.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: areas.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${areas.length} area', style: AppTextStyles.bodySmall),
          );
        }
        final a = areas[i - 1];
        return _AreaAssignmentRow(
          area: a,
          allSalesUsers: allSalesUsers,
          onChanged: onChanged,
        );
      },
    );
  }
}

class _AreaAssignmentRow extends StatefulWidget {
  final _AreaRow area;
  final List<SalesUser> allSalesUsers;
  final VoidCallback onChanged;

  const _AreaAssignmentRow({
    required this.area,
    required this.allSalesUsers,
    required this.onChanged,
  });

  @override
  State<_AreaAssignmentRow> createState() => _AreaAssignmentRowState();
}

class _AreaAssignmentRowState extends State<_AreaAssignmentRow> {
  Future<void> _openEditor() async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _MultiSelectSalesDialog(
        title: 'Sales untuk area ${widget.area.kodeArea}',
        subtitle: 'Sales yang ditugaskan akan cover semua customer di area ini.',
        allSalesUsers: widget.allSalesUsers,
        currentSelected: widget.area.sales.map((a) => a.salesId).toSet(),
      ),
    );
    if (selected == null || !mounted) return;
    try {
      await context.read<AdminProvider>().putAreaAssignment(
        widget.area.kodeArea,
        selected.toList(),
      );
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Penugasan area ${widget.area.kodeArea} disimpan'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAssignments = widget.area.sales.isNotEmpty;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _openEditor,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderLight),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.area.kodeArea,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.info, fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _openEditor,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Kelola'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (hasAssignments)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.area.sales
                      .map((a) => _AssignmentChip(label: a.displayLabel))
                      .toList(),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    'Belum di-assign (customer di area visible ke semua sales)',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted, fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentChip extends StatelessWidget {
  final String label;
  const _AssignmentChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.infoBorder),
      ),
      child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.info)),
    );
  }
}

// ==================== Per Customer sub-view ====================

class _PerCustomerView extends StatelessWidget {
  final List<Customer> customers;
  final int totalCount;
  final List<SalesUser> allSalesUsers;
  final VoidCallback onChanged;

  const _PerCustomerView({
    required this.customers,
    required this.totalCount,
    required this.allSalesUsers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.store_outlined, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text('Belum ada customer', style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: customers.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('$totalCount customer', style: AppTextStyles.bodySmall),
          );
        }
        final c = customers[i - 1];
        return _CustomerAssignmentRow(
          customer: c,
          allSalesUsers: allSalesUsers,
          onChanged: onChanged,
        );
      },
    );
  }
}

class _CustomerAssignmentRow extends StatefulWidget {
  final Customer customer;
  final List<SalesUser> allSalesUsers;
  final VoidCallback onChanged;

  const _CustomerAssignmentRow({
    required this.customer,
    required this.allSalesUsers,
    required this.onChanged,
  });

  @override
  State<_CustomerAssignmentRow> createState() => _CustomerAssignmentRowState();
}

class _CustomerAssignmentRowState extends State<_CustomerAssignmentRow> {
  List<SalesAssignment> _assignments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<AdminProvider>();
    try {
      final result = await provider.getCustomerAssignments(widget.customer.id);
      if (!mounted) return;
      setState(() {
        _assignments = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openEditor() async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _MultiSelectSalesDialog(
        title: 'Override sales untuk ${widget.customer.namaToko}',
        subtitle:
            'Override per-customer. Kosongkan semua = kembali ke coverage area (${widget.customer.kodeArea ?? "tanpa area"}).',
        allSalesUsers: widget.allSalesUsers,
        currentSelected: _assignments.map((a) => a.salesId).toSet(),
      ),
    );
    if (selected == null || !mounted) return;
    try {
      final newList = await context.read<AdminProvider>().putCustomerAssignments(
        widget.customer.id,
        selected.toList(),
      );
      if (!mounted) return;
      setState(() => _assignments = newList);
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Override ${widget.customer.namaToko} disimpan'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _openEditor,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderLight),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.customer.namaToko,
                            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.customer.kode ?? '-'} • ${widget.customer.kodeArea ?? 'tanpa area'}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  TextButton.icon(
                    onPressed: _openEditor,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Override'),
                  ),
                ],
              ),
              if (_assignments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _assignments
                      .map((a) => _AssignmentChip(label: a.displayLabel))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== Per Sales sub-view ====================

class _PerSalesView extends StatelessWidget {
  final List<UserItem> salesUsers;
  final VoidCallback onChanged;

  const _PerSalesView({required this.salesUsers, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (salesUsers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text('Belum ada user sales', style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: salesUsers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final u = salesUsers[i];
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showCustomersDialog(context, u),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderLight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.displayName, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('@${u.username} • ${u.role}', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showCustomersDialog(context, u),
                    icon: const Icon(Icons.list_alt_outlined, size: 16),
                    label: const Text('Lihat Toko'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCustomersDialog(BuildContext context, UserItem u) {
    showDialog(
      context: context,
      builder: (_) => _SalesCustomersDialog(salesUser: u),
    );
  }
}

class _SalesCustomersDialog extends StatefulWidget {
  final UserItem salesUser;
  const _SalesCustomersDialog({required this.salesUser});

  @override
  State<_SalesCustomersDialog> createState() => _SalesCustomersDialogState();
}

class _SalesCustomersDialogState extends State<_SalesCustomersDialog> {
  List<Customer>? _customers;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final result = await context.read<AdminProvider>().getSalesCustomers(widget.salesUser.id);
      if (!mounted) return;
      setState(() {
        _customers = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Toko untuk ${widget.salesUser.displayName}',
                            style: AppTextStyles.headlineSmall),
                        Text('@${widget.salesUser.username}', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _customers == null || _customers!.isEmpty
                        ? Center(
                            child: Text(
                              'Sales ini belum cover toko manapun',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _customers!.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final c = _customers![i];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.store_outlined, size: 18),
                                title: Text(c.namaToko),
                                subtitle: Text('${c.kodeArea ?? "tanpa area"} • ${c.alamat ?? '-'}'),
                                trailing: c.kode == null ? null : Text(c.kode!),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== Multi-select dialog ====================

class _MultiSelectSalesDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<SalesUser> allSalesUsers;
  final Set<String> currentSelected;

  const _MultiSelectSalesDialog({
    required this.title,
    required this.subtitle,
    required this.allSalesUsers,
    required this.currentSelected,
  });

  @override
  State<_MultiSelectSalesDialog> createState() => _MultiSelectSalesDialogState();
}

class _MultiSelectSalesDialogState extends State<_MultiSelectSalesDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.currentSelected};
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.allSalesUsers;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: AppTextStyles.headlineSmall),
              const SizedBox(height: 4),
              Text(widget.subtitle,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Flexible(
                child: candidates.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Belum ada user sales. Buat dulu di tab User.',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: candidates.length,
                        itemBuilder: (context, i) {
                          final u = candidates[i];
                          final checked = _selected.contains(u.id);
                          return CheckboxListTile(
                            dense: true,
                            value: checked,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected.add(u.id);
                              } else {
                                _selected.remove(u.id);
                              }
                            }),
                            title: Text(u.displayName),
                            subtitle: Text('@${u.username}'),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text('Simpan'),
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
