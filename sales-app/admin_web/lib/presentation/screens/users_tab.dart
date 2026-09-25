import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../providers/admin_provider.dart';
import '../../data/models/user_item.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

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
    final users = context.select<AdminProvider, List<UserItem>>((p) => p.users);
    final isLoading = context.select<AdminProvider, bool>((p) => p.isLoading);
    final provider = context.read<AdminProvider>();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          children: [
            // Search bar + role filter
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: Row(
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
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      initialValue: _roleFilter,
                      decoration: InputDecoration(
                        hintText: 'Role',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Semua Role')),
                        DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                        DropdownMenuItem(value: 'MANAGER', child: Text('Manager')),
                        DropdownMenuItem(value: 'SALES', child: Text('Sales')),
                      ],
                      onChanged: (v) {
                        setState(() => _roleFilter = v);
                        // Kirim '' (bukan null) untuk "Semua Role" karena loadUsers
                        // skip update kalau role=null — kalau tidak, state internal
                        // masih nyimpen role lama walaupun UI menampilkan "Semua Role".
                        provider.loadUsers(role: v ?? '');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _openCreateDialog(context),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Tambah'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const _TableHeader(),
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
                                  color:
                                      AppColors.textMuted.withValues(alpha: 0.4)),
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
                      : ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (ctx, index) =>
                              _UserRow(user: users[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const _UserEditDialog(),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppColors.surface,
      child: const Row(
        children: [
          _HeaderCell(label: 'NAMA', width: 200),
          _HeaderCell(label: 'USERNAME', width: 160),
          _HeaderCell(label: 'ROLE', width: 120),
          _HeaderCell(label: 'STATUS', width: 120),
          _HeaderCell(label: 'AKSI', width: 120),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final double width;
  const _HeaderCell({required this.label, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(
          child: Text(label, style: AppTextStyles.labelMedium),
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final UserItem user;
  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          _Cell(
            width: 200,
            child: Text(
              user.displayName,
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          _Cell(
            width: 160,
            child: Text(
              user.username,
              style: AppTextStyles.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _Cell(
            width: 120,
            child: _RoleBadge(role: user.role),
          ),
          _Cell(
            width: 120,
            child: _StatusBadge(active: user.isActive),
          ),
          _Cell(
            width: 120,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _openEditDialog(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.primaryLight,
                  tooltip: 'Edit user',
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.error,
                  tooltip: 'Hapus user',
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => _UserEditDialog(existing: user),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus User'),
        content: Text(
          'Yakin ingin menghapus user "${user.displayName}" (${user.username})?\n\n'
          'User akan di-soft-delete dan tidak bisa login lagi.',
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
    final success = await provider.deleteUser(user.id);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('User "${user.username}" berhasil dihapus'),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(provider.errorMessage ?? 'Gagal menghapus user'),
            backgroundColor: AppColors.error),
      );
    }
  }
}

class _Cell extends StatelessWidget {
  final double width;
  final Widget child;
  const _Cell({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(child: child),
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
  const _UserEditDialog({this.existing});

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
    final provider = context.read<AdminProvider>();
    bool ok;

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

    if (!mounted) return;
    setState(() => _saving = false);

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
            content: Text(provider.errorMessage ?? 'Gagal menyimpan'),
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
