import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/theme.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final _api = ApiService();
  bool _loading = false;
  List _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/v1/plans');
      setState(() {
        _items = res['success'] == true && res['data'] is List ? res['data'] : [];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showForm({Map? existing}) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final description = TextEditingController(text: existing?['description']?.toString() ?? '');
    final price = TextEditingController(text: existing?['price']?.toString() ?? '');
    final priceYearly = TextEditingController(text: existing?['price_yearly']?.toString() ?? '');
    final trialDays = TextEditingController(text: existing?['trial_days']?.toString() ?? '14');
    final maxUsers = TextEditingController(text: existing?['max_users']?.toString() ?? '2');
    final maxProducts = TextEditingController(text: existing?['max_products']?.toString() ?? '100');
    final maxBranches = TextEditingController(text: existing?['max_branches']?.toString() ?? '1');
    final featuresCtrl = TextEditingController(
      text: existing?['features'] is List
          ? (existing!['features'] as List).join('\n')
          : '',
    );
    bool isActive = existing?['is_active'] ?? true;
    final isEdit = existing != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Paket' : 'Tambah Paket'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama *')),
                const SizedBox(height: 8),
                TextField(controller: description, decoration: const InputDecoration(labelText: 'Deskripsi'), maxLines: 2),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: price,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Harga/Bulan *', prefixText: 'Rp '),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: priceYearly,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Harga/Tahun', prefixText: 'Rp '),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: trialDays,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hari Trial'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: maxUsers,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Maks User *'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: maxProducts,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Maks Produk *'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: maxBranches,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Maks Cabang *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: featuresCtrl,
                  decoration: const InputDecoration(labelText: 'Fitur (satu per baris)', hintText: 'POS\nLaporan\nMulti cabang'),
                  maxLines: 3,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Paket Aktif', style: TextStyle(fontSize: 14)),
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

    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama paket wajib diisi'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final features = featuresCtrl.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final body = <String, dynamic>{
      'name': name.text.trim(),
      'description': description.text.trim(),
      'price': double.tryParse(price.text) ?? 0,
      'price_yearly': priceYearly.text.isNotEmpty ? (double.tryParse(priceYearly.text) ?? 0) : null,
      'trial_days': int.tryParse(trialDays.text) ?? 0,
      'max_users': int.tryParse(maxUsers.text) ?? 1,
      'max_products': int.tryParse(maxProducts.text) ?? 1,
      'max_branches': int.tryParse(maxBranches.text) ?? 1,
      'features': features,
      'is_active': isActive,
    };

    try {
      final res = isEdit
          ? await _api.put('/v1/plans/${existing['id']}', body: body)
          : await _api.post('/v1/plans', body: body);
      if (!mounted) return;
      if (res['success'] == true) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? 'Paket diperbarui' : 'Paket ditambahkan'), backgroundColor: AppColors.success),
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

  Future<void> _delete(Map p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Paket'),
        content: Text('Hapus paket "${p['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final res = await _api.delete('/v1/plans/${p['id']}');
      if (!mounted) return;
      if (res['success'] == true) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paket dihapus'), backgroundColor: AppColors.success),
        );
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
        title: const Text('Paket Langganan', style: TextStyle(fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, size: 22), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  ..._items.map((raw) {
                    final p = Map<String, dynamic>.from(raw as Map);
                    final features = p['features'] is List ? (p['features'] as List) : [];
                    final isActive = p['is_active'] ?? true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isActive ? AppColors.border : AppColors.dangerLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(p['name'] ?? '-', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isActive ? AppColors.success : AppColors.danger).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  isActive ? 'Aktif' : 'Nonaktif',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isActive ? AppColors.success : AppColors.danger),
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') _showForm(existing: p);
                                  if (v == 'delete') _delete(p);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: AppColors.danger))),
                                ],
                              ),
                            ],
                          ),
                          if ((p['description'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('${p['description']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(formatCurrency(double.tryParse('${p['price']}') ?? 0), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              const Text(' / bulan', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              if (p['price_yearly'] != null) ...[
                                const SizedBox(width: 8),
                                Text(formatCurrency(double.tryParse('${p['price_yearly']}') ?? 0), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const Text(' / tahun', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _badge(Icons.people_rounded, 'User: ${p['max_users'] ?? '-'}'),
                              _badge(Icons.inventory_2_rounded, 'Produk: ${p['max_products'] ?? '-'}'),
                              _badge(Icons.store_rounded, 'Cabang: ${p['max_branches'] ?? '-'}'),
                              if (p['trial_days'] != null && (p['trial_days'] as num) > 0)
                                _badge(Icons.hourglass_bottom_rounded, 'Trial ${p['trial_days']} hari'),
                              if (p['tenants_count'] != null) _badge(Icons.business_rounded, '${p['tenants_count']} tenant'),
                            ],
                          ),
                          if (features.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...features.map((f) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, size: 13, color: AppColors.success),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text('$f', style: const TextStyle(fontSize: 12))),
                                    ],
                                  ),
                                )),
                          ],
                        ],
                      ),
                    );
                  }),
                  if (_items.isEmpty && !_loading)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Belum ada paket'))),
                  const SizedBox(height: 72),
                ],
              ),
      ),
    );
  }

  Widget _badge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
