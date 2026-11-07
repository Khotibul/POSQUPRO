import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/theme.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  final _api = ApiService();
  bool _loading = false;
  List _items = [];
  List _plans = [];
  String? _statusFilter;
  int _page = 1;
  bool _hasMore = true;

  static const _statuses = ['active', 'trial', 'suspended', 'inactive'];

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final res = await _api.get('/v1/plans');
      if (res['success'] == true && res['data'] is List) {
        setState(() => _plans = res['data']);
      }
    } catch (_) {}
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }
    if (!_hasMore && !refresh) return;
    setState(() => _loading = true);
    try {
      final res = await _api.get('/v1/tenants', queryParams: {
        'page': '$_page',
        if (_statusFilter != null) 'status': _statusFilter!,
      });
      if (res['success'] == true) {
        final data = res['data'];
        final list = data is List ? data : (data?['data'] ?? []);
        setState(() {
          if (refresh) {
            _items = list;
          } else {
            _items = [..._items, ...list];
          }
          final meta = data is Map ? (data['meta']?['last_page'] ?? data['last_page']) : null;
          if (meta != null) {
            _hasMore = _page < (meta as num).toInt();
          } else {
            _hasMore = list.length >= 15;
          }
          _page++;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal memuat tenant'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _statusLabel(String? s) => switch (s) {
        'active' => 'Aktif',
        'trial' => 'Trial',
        'suspended' => 'Ditangguhkan',
        'inactive' => 'Nonaktif',
        _ => s ?? '-',
      };

  Color _statusColor(String? s) => switch (s) {
        'active' => AppColors.success,
        'trial' => AppColors.secondary,
        'suspended' => AppColors.danger,
        _ => AppColors.textMuted,
      };

  String _planName(dynamic t) {
    final plan = t['plan'];
    if (plan is Map) return plan['name']?.toString() ?? '-';
    return '-';
  }

  Future<void> _showForm({Map? existing}) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final email = TextEditingController(text: existing?['email']?.toString() ?? '');
    final phone = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final ownerName = TextEditingController();
    final ownerEmail = TextEditingController();
    final ownerPassword = TextEditingController();
    int? planId = existing?['plan_id'];
    String status = existing?['status']?.toString() ?? 'trial';
    final isEdit = existing != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Tenant' : 'Tambah Tenant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama Tenant *')),
                const SizedBox(height: 8),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 8),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telepon')),
                if (_plans.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: planId,
                    decoration: const InputDecoration(labelText: 'Paket'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('- Tanpa paket -')),
                      ..._plans.map((p) => DropdownMenuItem(value: p['id'] as int, child: Text('${p['name']}', style: const TextStyle(fontSize: 13)))),
                    ],
                    onChanged: (v) => setDialogState(() => planId = v),
                  ),
                ],
                if (isEdit) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status *'),
                    items: _statuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(_statusLabel(s))))
                        .toList(),
                    onChanged: (v) => setDialogState(() => status = v ?? 'trial'),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Akun Admin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: ownerName, decoration: const InputDecoration(labelText: 'Nama Admin')),
                  const SizedBox(height: 8),
                  TextField(controller: ownerEmail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Admin')),
                  const SizedBox(height: 8),
                  TextField(controller: ownerPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Password Admin (min 8, kosongkan = otomatis)')),
                ],
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

    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama tenant wajib diisi'), backgroundColor: AppColors.danger),
      );
      return;
    }

    try {
      final body = <String, dynamic>{
        'name': name.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'plan_id': planId,
        if (isEdit) 'status': status,
        if (!isEdit) ...{
          'owner_name': ownerName.text.trim(),
          'owner_email': ownerEmail.text.trim(),
          if (ownerPassword.text.isNotEmpty) 'owner_password': ownerPassword.text.trim(),
        },
      };
      final res = isEdit
          ? await _api.put('/v1/tenants/${existing['id']}', body: body)
          : await _api.post('/v1/tenants', body: body);
      if (!mounted) return;
      if (res['success'] == true) {
        _load(refresh: true);
        String extra = '';
        if (!isEdit && res['data'] is Map && res['data']['owner_password'] != null) {
          extra = '\nPassword admin: ${res['data']['owner_password']}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? 'Tenant diperbarui' : 'Tenant dibuat.$extra'), backgroundColor: AppColors.success),
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

  Future<void> _detail(Map t) async {
    try {
      final res = await _api.get('/v1/tenants/${t['id']}');
      if (!mounted) return;
      if (res['success'] != true || res['data'] is! Map) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal memuat detail'), backgroundColor: AppColors.danger),
        );
        return;
      }
      final data = Map<String, dynamic>.from(res['data']);
      final tenant = Map<String, dynamic>.from(data['tenant'] ?? t);
      final invoices = (data['invoices'] as List?) ?? [];

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tenant['name'] ?? 'Detail Tenant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Status', _statusLabel(tenant['status'])),
                _kv('Email', '${tenant['email'] ?? '-'}'),
                _kv('Telepon', '${tenant['phone'] ?? '-'}'),
                _kv('Kota', '${tenant['city'] ?? '-'}'),
                _kv('Paket', _planName(tenant)),
                _kv('Owner', '${tenant['owner']?['name'] ?? '-'}'),
                _kv('Trial s/d', '${tenant['trial_ends_at'] ?? '-'}'),
                if (tenant['suspension_reason'] != null) _kv('Alasan', '${tenant['suspension_reason']}'),
                const SizedBox(height: 8),
                const Text('Invoice', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (invoices.isEmpty)
                  const Text('Belum ada invoice', style: TextStyle(fontSize: 12, color: AppColors.textMuted))
                else
                  ...invoices.take(5).map((i) => Text(
                        '${i['invoice_number'] ?? '#${i['id']}'} · ${i['status'] ?? '-'}',
                        style: const TextStyle(fontSize: 12),
                      )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 90, child: Text(k, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
            Expanded(child: Text(v, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );

  Future<void> _toggleSuspend(Map t) async {
    final isSuspended = t['status'] == 'suspended';
    if (!isSuspended) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Tangguhkan Tenant'),
          content: Text('Tangguhkan "${t['name']}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tangguhkan', style: TextStyle(color: AppColors.danger))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    try {
      final res = await _api.post('/v1/tenants/${t['id']}/${isSuspended ? 'activate' : 'suspend'}');
      if (!mounted) return;
      if (res['success'] == true) {
        _load(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isSuspended ? 'Tenant diaktifkan' : 'Tenant ditangguhkan'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _delete(Map t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Tenant'),
        content: Text('Hapus "${t['name']}"? Semua data tenant ini ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.delete('/v1/tenants/${t['id']}');
      _load(refresh: true);
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
        title: const Text('Tenant', style: TextStyle(fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, size: 22), onPressed: () => _load(refresh: true))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              children: [
                _filterChip(null, 'Semua'),
                ..._statuses.map((s) => _filterChip(s, _statusLabel(s))),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: _loading && _items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: _items.length + (_hasMore && _items.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _items.length) {
                          _load();
                          return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)));
                        }
                        final t = Map<String, dynamic>.from(_items[index] as Map);
                        final status = t['status']?.toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            onTap: () => _detail(t),
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(status).withValues(alpha: 0.14),
                              child: Text(
                                (t['name'] ?? 'T').toString().substring(0, 1).toUpperCase(),
                                style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(t['name'] ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                                  child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor(status))),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              '${t['email'] ?? '-'} · ${_planName(t)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                switch (v) {
                                  case 'edit':
                                    _showForm(existing: t);
                                  case 'toggle':
                                    _toggleSuspend(t);
                                  case 'delete':
                                    _delete(t);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(status == 'suspended' ? 'Aktifkan' : 'Tangguhkan'),
                                ),
                                const PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: AppColors.danger))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String? value, String label) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textSecondary)),
        selected: isSelected,
        onSelected: (_) => setState(() => _statusFilter = value),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
