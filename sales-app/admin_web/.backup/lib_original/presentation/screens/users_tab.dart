import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../../core/branch.dart';
import '../../core/responsive.dart';
import '../../core/responsive_dialog.dart';
import '../providers/admin_provider.dart';
import '../widgets/data_card.dart';
import '../../data/models/user_item.dart';

class UsersTab extends StatefulWidget {
  final bool readOnly;
  // Role/branch of the logged-in user. For SUPERVISOR, the branch dropdown
  // in the create/edit dialog is locked to currentBranch. For MANAGER/ADMIN
  // it's a functional dropdown across all branches.
  final String? currentRole;
  final String? currentBranch;
  final String? currentBranchNama;
  const UsersTab({
    super.key,
    this.readOnly = false,
    this.currentRole,
    this.currentBranch,
    this.currentBranchNama,
  });

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  String _searchQuery = '';
  bool _initialized = false;
  final _searchController = TextEditingController();
  String? _roleFilter;

  static const _headerHeight = 48.0;
  static const _rowHeight = 60.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminProvider>();
      if (!_initialized) {
        _initialized = true;
        provider.loadUsers();
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
    final allUsers = context.select<AdminProvider, List<UserItem>>((p) => p.users);
    final isLoading = context.select<AdminProvider, bool>((p) => p.isLoading);
    final provider = context.read<AdminProvider>();

    // Sort: by role first, then by name
    final users = List<UserItem>.from(allUsers)
      ..sort((a, b) {
        final roleCompare = a.role.compareTo(b.role);
        if (roleCompare != 0) return roleCompare;
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });

    return Column(
      children: [
        // Search bar + filter chips role
        Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Cari user (nama / username)...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                      provider.searchUsers('');
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
                            provider.searchUsers(v);
                          },
                        ),
                      ),
                      if (!widget.readOnly) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: !widget.readOnly
                              ? () => _openCreateDialog(context)
                              : null,
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Tambah'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _roleChip(null, 'Semua'),
                      _roleChip('ADMIN', 'Admin'),
                      _roleChip('SUPERVISOR', 'Supervisor'),
                      _roleChip('MANAGER', 'Manager'),
                      _roleChip('SALES', 'Sales'),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Table
            Expanded(
              child: isLoading && users.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : users.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline,
                                  size: 48,
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.4)),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty || _roleFilter != null
                                    ? 'User tidak ditemukan'
                                    : 'Belum ada user',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
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
        );
      }

  Widget _buildCardList(List<UserItem> users) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resp = Responsive.of(constraints.maxWidth);
        final columns = resp.isMobile ? 1 : resp.isTablet ? 2 : 3;
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
                        _BranchChip(label: u.branchNama!)
                      else if (u.branch != null && u.branch!.isNotEmpty)
                        _BranchChip(label: u.branch!),
                    ],
                    fields: [
                      DataField(label: 'USERNAME', value: u.username),
                      DataField(
                        label: 'STATUS',
                        valueWidget: _StatusBadge(active: u.isActive),
                      ),
                      if (u.branchNama != null || u.branch != null)
                        DataField(
                          label: 'CABANG',
                          value: u.branchNama ?? u.branch ?? '-',
                        ),
                    ],
                    actions: widget.readOnly
                        ? null
                        : [
                            FilledButton.icon(
                              onPressed: () => _openEditDialog(u),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                              ),
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

  Widget _buildTable(List<UserItem> users) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth;
        const roleW = 100.0;
        const statusW = 90.0;
        const aksiW = 90.0;
        final remaining = avail - roleW - statusW - aksiW;
        final namaW = remaining * 0.35;
        final usernameW = remaining * 0.25;
        final cabangW = remaining * 0.40;
        final colWidths = [namaW, usernameW, roleW, cabangW, statusW, aksiW];
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
    const labels = ['NAMA', 'USERNAME', 'ROLE', 'CABANG', 'STATUS', 'AKSI'];
    return SizedBox(
      width: totalW,
      child: Container(
        height: _headerHeight,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditDialog(UserItem user) {
    final provider = context.read<AdminProvider>();
    return showDialog(
      context: context,
      builder: (_) => _UserEditDialog(
        existing: user,
        provider: provider,
        currentRole: widget.currentRole,
        currentBranch: widget.currentBranch,
        currentBranchNama: widget.currentBranchNama,
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final provider = context.read<AdminProvider>();
    await showDialog(
      context: context,
      builder: (_) => _UserEditDialog(
        provider: provider,
        currentRole: widget.currentRole,
        currentBranch: widget.currentBranch,
        currentBranchNama: widget.currentBranchNama,
      ),
    );
  }

  Widget _buildRow(UserItem user, List<double> colWidths, double totalW) {
    final initial =
        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?';
    final color = switch (user.role) {
      'ADMIN' => AppColors.error,
      'SUPERVISOR' => AppColors.warning,
      'MANAGER' => AppColors.info,
      _ => AppColors.success,
    };

    return SizedBox(
      width: totalW,
      height: _rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: colWidths[0],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: AppTextStyles.bodyMedium
                              .copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '@${user.username}',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: colWidths[1],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                user.username,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: colWidths[2],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Center(child: _RoleBadge(role: user.role)),
            ),
          ),
          SizedBox(
            width: colWidths[3],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                user.branchNama ?? user.branch ?? '-',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: colWidths[4],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Center(child: _StatusBadge(active: user.isActive)),
            ),
          ),
          SizedBox(
            width: colWidths[5],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: widget.readOnly
                    ? const SizedBox()
                    : IconButton(
                        onPressed: () => _openEditDialog(user),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: AppColors.primaryLight,
                        tooltip: 'Edit user',
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String? role, String label) {
    final selected = _roleFilter == role;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _roleFilter = role);
        context.read<AdminProvider>().loadUsers(role: role ?? '');
      },
      selectedColor: AppColors.primaryLight.withValues(alpha: 0.15),
      backgroundColor: AppColors.background,
      side: BorderSide(
        color: selected ? AppColors.primaryLight : AppColors.border,
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.primaryLight : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
/// Chip kecil untuk label cabang pada card list. Memakai style mirip
/// _RoleBadge/_StatusBadge tapi dengan warna netral (info) karena branch
/// bukan indikator status.
class _BranchChip extends StatelessWidget {
  final String label;
  const _BranchChip({required this.label});

  @override
  Widget build(BuildContext context) {
    const color = AppColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      'ADMIN' => AppColors.error,
      'SUPERVISOR' => AppColors.warning,
      'MANAGER' => AppColors.info,
      _ => AppColors.success,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textMuted;
    final label = active ? 'Aktif' : 'Nonaktif';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _UserEditDialog extends StatefulWidget {
  final UserItem? existing;
  final AdminProvider provider;
  // Role/branch of the logged-in user. SUPERVISOR â†’ dropdown is locked to
  // currentBranch. MANAGER/ADMIN â†’ dropdown is functional across all branches.
  final String? currentRole;
  final String? currentBranch;
  final String? currentBranchNama;
  const _UserEditDialog({
    this.existing,
    required this.provider,
    this.currentRole,
    this.currentBranch,
    this.currentBranchNama,
  });

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  late TextEditingController _usernameC;
  late TextEditingController _passwordC;
  late TextEditingController _namaC;
  String _role = 'SALES';
  String? _branch;
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;
  bool get _isBranchLocked => widget.currentRole == 'SUPERVISOR';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _usernameC = TextEditingController(text: e?.username ?? '');
    _passwordC = TextEditingController();
    _namaC = TextEditingController(text: e?.nama ?? '');
    _role = e?.role ?? 'SALES';
    _isActive = e?.isActive ?? true;
    // Initial branch: existing user's branch wins; otherwise current user's
    // branch (forced for SUPERVISOR); otherwise null until the user picks.
    if (e?.branch != null && e!.branch!.isNotEmpty) {
      _branch = e.branch;
    } else if (_isBranchLocked && widget.currentBranch != null) {
      _branch = widget.currentBranch;
    }
  }

  @override
  void dispose() {
    _usernameC.dispose();
    _passwordC.dispose();
    _namaC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _usernameC.text.trim();
    final password = _passwordC.text;
    final nama = _namaC.text.trim();

    if (!_isEdit && (username.isEmpty || password.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Username dan password wajib diisi'),
            backgroundColor: AppColors.error),
      );
      return;
    }
    if (!_isEdit && password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password minimal 6 karakter'),
            backgroundColor: AppColors.error),
      );
      return;
    }
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Username wajib diisi'),
            backgroundColor: AppColors.error),
      );
      return;
    }
    if (_isEdit && password.isNotEmpty && password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password baru minimal 6 karakter'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _saving = true);
    bool ok = false;
    String? unexpectedError;
    // Pakai widget.provider (di-passing via constructor dari pemanggil showDialog)
    // â€” `context.read` di sini akan throw karena dialog hidup di navigator Overlay,
    // bukan descendant dari ChangeNotifierProvider di DashboardScreen.
    final provider = widget.provider;
    try {
      if (_isEdit) {
        final body = <String, dynamic>{
          'nama': nama.isEmpty ? null : nama,
          'role': _role,
          'is_active': _isActive,
          'branch': _branch,
        };
        if (password.isNotEmpty) body['password'] = password;
        ok = await provider.updateUser(widget.existing!.id, body);
      } else {
        ok = await provider.createUser(
          username: username,
          password: password,
          role: _role,
          nama: nama.isEmpty ? null : nama,
          branch: _branch,
        );
      }
    } catch (e) {
      // Tangkap exception yang lolos dari provider (mis. listener notifyListeners
      // melempar saat state berubah). Tanpa finally di bawah, _saving stuck true
      // dan spinner berputar selamanya meskipun operasi sudah selesai.
      ok = false;
      unexpectedError = e.toString();
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(_isEdit ? 'User berhasil diperbarui' : 'User berhasil dibuat'),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(unexpectedError ??
                provider.errorMessage ??
                'Gagal menyimpan'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveDialog(
      showCloseButton: true,
      child: Padding(
        padding: const EdgeInsets.all(24),
        // Bungkus Column dengan SingleChildScrollView agar form bisa di-scroll
        // saat keyboard mobile muncul dan konten melebihi tinggi viewport.
        child: SingleChildScrollView(
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
                    child: Icon(
                      _isEdit ? Icons.edit : Icons.person_add,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Edit User' : 'Tambah User',
                          style: AppTextStyles.headlineSmall,
                        ),
                        Text(
                          _isEdit
                              ? 'Update data user'
                              : 'Buat akun baru untuk admin/manager/sales',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _usernameC,
                decoration: InputDecoration(
                  labelText: 'Username *',
                  hintText: 'cth: budi.sales',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                enabled: !_isEdit,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordC,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _isEdit ? 'Password Baru (opsional)' : 'Password *',
                  hintText: _isEdit
                      ? 'Kosongkan jika tidak diubah'
                      : 'Min. 6 karakter',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _namaC,
                decoration: InputDecoration(
                  labelText: 'Nama',
                  hintText: 'cth: Budi Santoso',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                  DropdownMenuItem(value: 'SUPERVISOR', child: Text('Supervisor')),
                  DropdownMenuItem(value: 'MANAGER', child: Text('Manager')),
                  DropdownMenuItem(value: 'SALES', child: Text('Sales')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'SALES'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _branch,
                decoration: InputDecoration(
                  labelText: 'Cabang',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  helperText: _isBranchLocked
                      ? 'Supervisor hanya bisa membuat user di cabang sendiri'
                      : null,
                  suffixIcon: _isBranchLocked
                      ? const Icon(Icons.lock_outline, size: 18)
                      : null,
                ),
                items: BranchCode.all
                    .map((code) => DropdownMenuItem(
                          value: code,
                          child: Text(BranchLabel.display(code) ?? code),
                        ))
                    .toList(),
                onChanged: _isBranchLocked
                    ? null
                    : (v) => setState(() => _branch = v),
              ),
              const SizedBox(height: 12),
              if (_isEdit)
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('Aktif'),
                  subtitle: const Text(
                      'Nonaktifkan untuk blokir login tanpa menghapus data'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
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
                                  strokeWidth: 2, color: Colors.white),
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
