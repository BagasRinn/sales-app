import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../providers/admin_provider.dart';
import '../../data/models/user_item.dart';

class UsersTab extends StatefulWidget {
  final bool readOnly;
  const UsersTab({super.key, this.readOnly = false});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  String _searchQuery = '';
  bool _initialized = false;
  final _searchController = TextEditingController();
  String? _roleFilter;

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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          children: [
            // Search bar + filter chips role. Chips menggantikan dropdown
            // — lebih visual dan satu tap, terutama untuk layar sempit.
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
            // Pola sama dengan customers_tab: header punya tinggi tetap
            // (48), baris pakai nested vertical+horizontal scroll. Pakai pola
            // ini (bukan Expanded di dalam SingleChildScrollView horizontal)
            // supaya ListView di-expand dengan benar — kalau Column berisi
            // Expanded dibungkus SingleChildScrollView horizontal, tinggi
            // Column jadi 0 karena Expanded tidak punya referensi tinggi.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 800),
                        child: _TableHeader(readOnly: widget.readOnly),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
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
                            : SingleChildScrollView(
                                // Outer: vertical scroll untuk banyak user.
                                child: SingleChildScrollView(
                                  // Inner: horizontal scroll pada layar sempit.
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(minWidth: 800),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (int i = 0;
                                            i < users.length;
                                            i++) ...[
                                          _UserRow(
                                              user: users[i],
                                              readOnly: widget.readOnly,
                                              isEven: i.isEven),
                                          const Divider(height: 1),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Future<void> _openCreateDialog(BuildContext context) async {
    final provider = context.read<AdminProvider>();
    await showDialog(
      context: context,
      builder: (_) => _UserEditDialog(provider: provider),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final bool readOnly;
  const _TableHeader({this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.borderLight,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          // NAMA (flex)
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('NAMA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    )),
              ),
            ),
          ),
          _hCell('USERNAME', 150),
          _hCell('ROLE', 110),
          _hCell('CABANG', 170),
          _hCell('STATUS', 100),
          if (!readOnly) _hCell('AKSI', 70),
        ],
      ),
    );
  }

  Widget _hCell(String label, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              )),
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final UserItem user;
  final bool readOnly;
  final bool isEven;
  const _UserRow({
    required this.user,
    this.readOnly = false,
    this.isEven = true,
  });

  @override
  Widget build(BuildContext context) {
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : '?';
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: isEven
            ? AppColors.surface
            : AppColors.borderLight.withValues(alpha: 0.4),
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // NAMA: avatar + nama + username sebagai sub-text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _avatarColor(user.role).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: _avatarColor(user.role),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${user.username}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _bodyCell(150, align: Alignment.centerLeft, child: Text(
            user.username,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
          )),
          _bodyCell(150, child: _RoleBadge(role: user.role)),
          _bodyCell(170, align: Alignment.centerLeft, child: Text(
            user.branchNama ?? user.branch ?? '-',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          )),
          _bodyCell(100, child: _StatusBadge(active: user.isActive)),
          if (!readOnly)
            SizedBox(
              width: 70,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: IconButton(
                    onPressed: () => _openEditDialog(context),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppColors.primaryLight,
                    tooltip: 'Edit user',
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bodyCell(double width, {required Widget child, Alignment align = Alignment.center}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Align(alignment: align, child: child),
      ),
    );
  }

  Color _avatarColor(String role) {
    return switch (role) {
      'ADMIN' => AppColors.error,
      'SUPERVISOR' => AppColors.warning,
      'MANAGER' => AppColors.info,
      _ => AppColors.success,
    };
  }

  Future<void> _openEditDialog(BuildContext context) async {
    final provider = context.read<AdminProvider>();
    await showDialog(
      context: context,
      builder: (_) => _UserEditDialog(existing: user, provider: provider),
    );
  }

  // _confirmDelete dihapus — nonaktifkan user cukup lewat toggle is_active
  // di dialog edit. Tidak ada 2 fitur dengan tujuan yang sama.
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
  const _UserEditDialog({this.existing, required this.provider});

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  late TextEditingController _usernameC;
  late TextEditingController _passwordC;
  late TextEditingController _namaC;
  String _role = 'SALES';
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _usernameC = TextEditingController(text: e?.username ?? '');
    _passwordC = TextEditingController();
    _namaC = TextEditingController(text: e?.nama ?? '');
    _role = e?.role ?? 'SALES';
    _isActive = e?.isActive ?? true;
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
    // — `context.read` di sini akan throw karena dialog hidup di navigator Overlay,
    // bukan descendant dari ChangeNotifierProvider di DashboardScreen.
    final provider = widget.provider;
    try {
      if (_isEdit) {
        final body = <String, dynamic>{
          'nama': nama.isEmpty ? null : nama,
          'role': _role,
          'is_active': _isActive,
        };
        if (password.isNotEmpty) body['password'] = password;
        ok = await provider.updateUser(widget.existing!.id, body);
      } else {
        ok = await provider.createUser(
          username: username,
          password: password,
          role: _role,
          nama: nama.isEmpty ? null : nama,
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(24),
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
