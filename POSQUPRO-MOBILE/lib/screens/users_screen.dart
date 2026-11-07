import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/theme.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _api = ApiService();
  bool _loading = false;
  List _items = [];

  static const _roles = ['Admin', 'Cashier', 'Finance', 'Warehouse Manager'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/v1/users');
      setState(() {
        _items = res['data'] is List ? res['data'] : (res['data']?['data'] ?? []);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _roleOf(Map u) {
    final roles = u['roles'];
    if (roles is List && roles.isNotEmpty) {
      final first = roles.first;
      if (first is Map) return first['name']?.toString() ?? '';
      return first.toString();
    }
    return u['role']?.toString() ?? '';
  }

  Future<void> _showForm({Map? existing}) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final email = TextEditingController(text: existing?['email']?.toString() ?? '');
    final phone = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final password = TextEditingController();
    String role = _roles.contains(_roleOf(existing ?? {})) ? _roleOf(existing!) : 'Cashier';
    bool isActive = existing?['is_active'] ?? existing?['active'] ?? true;
    final isEdit = existing != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Pengguna' : 'Tambah Pengguna'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama *')),
                const SizedBox(height: 8),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email *')),
                const SizedBox(height: 8),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telepon')),
                const SizedBox(height: 8),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(labelText: isEdit ? 'Password baru (opsional)' : 'Password * (min 8)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role *'),
                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setDialogState(() => role = v ?? 'Cashier'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif', style: TextStyle(fontSize: 14)),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    if (name.text.trim().isEmpty || email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan email wajib diisi'), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (!isEdit && password.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password minimal 8 karakter'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final body = <String, dynamic>{
      'name': name.text.trim(),
      'email': email.text.trim(),
      'phone': phone.text.trim(),
      'is_active': isActive,
      'roles': [role],
    };
    if (password.text.isNotEmpty) body['password'] = password.text;

    try {
      final res = isEdit
          ? await _api.put('/v1/users/${existing['id']}', body: body)
          : await _api.post('/v1/users', body: body);
      if (!mounted) return;
      if (res['success'] == true) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? 'Pengguna diperbarui' : 'Pengguna ditambahkan'), backgroundColor: AppColors.success),
        );
      } else {
        final errors = res['errors'];
        String msg = res['message'] ?? 'Gagal menyimpan';
        if (errors is Map && errors.isNotEmpty) {
          msg = errors.values.expand((v) => v is List ? v : [v]).join('\n');
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _delete(Map u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Pengguna'),
        content: Text('Hapus "${u['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final res = await _api.delete('/v1/users/${u['id']}');
      if (!mounted) return;
      if (res['success'] == true) {
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal menghapus'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengguna', style: TextStyle(fontSize: 18)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, size: 22), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Tambah'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            ..._items.map((raw) {
              final u = Map<String, dynamic>.from(raw as Map);
              final role = _roleOf(u);
              final active = u['is_active'] ?? u['active'] ?? true;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primarySurface,
                    child: Text(
                      (u['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(u['name'] ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      if (active != true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(4)),
                          child: const Text('Nonaktif', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.danger)),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${u['email'] ?? ''}${role.isNotEmpty ? ' · $role' : ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _showForm(existing: u);
                      if (v == 'delete') _delete(u);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: AppColors.danger))),
                    ],
                  ),
                ),
              );
            }),
            if (!_loading && _items.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Tidak ada pengguna'))),
            const SizedBox(height: 72),
          ],
        ),
      ),
    );
  }
}
