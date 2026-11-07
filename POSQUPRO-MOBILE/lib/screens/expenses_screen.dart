import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/theme.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _api = ApiService();
  bool _loading = false;
  List _items = [];

  static const _categories = [
    'Operasional',
    'Gaji',
    'Sewa',
    'Listrik & Air',
    'Transport',
    'Marketing',
    'Perawatan',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/v1/expenses');
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

  Future<void> _showForm({Map? existing}) async {
    final desc = TextEditingController(text: existing?['description']?.toString() ?? '');
    final amount = TextEditingController(text: existing?['amount']?.toString() ?? '');
    String category = existing?['category']?.toString() ?? _categories.first;
    final isEdit = existing != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Pengeluaran' : 'Tambah Pengeluaran'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _categories.contains(category) ? category : _categories.last,
                  decoration: const InputDecoration(labelText: 'Kategori *'),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? _categories.first),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: 'Deskripsi'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Jumlah *', prefixText: 'Rp '),
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

    final amt = (double.tryParse(amount.text) ?? 0).round();
    if (amt < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah minimal Rp 1'), backgroundColor: AppColors.danger),
      );
      return;
    }

    try {
      final body = {
        'category': category,
        'description': desc.text.trim(),
        'amount': amt,
      };
      final res = isEdit
          ? await _api.put('/v1/expenses/${existing['id']}', body: body)
          : await _api.post('/v1/expenses', body: body);
      if (!mounted) return;
      if (res['success'] == true) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? 'Pengeluaran diperbarui' : 'Pengeluaran ditambahkan'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal menyimpan'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _delete(Map e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Pengeluaran'),
        content: Text('Hapus "${e['description'] ?? e['category']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.delete('/v1/expenses/${e['id']}');
      _load();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err'), backgroundColor: AppColors.danger));
      }
    }
  }

  double get _total => _items.fold(0.0, (s, e) => s + ((e['amount'] as num?) ?? 0).toDouble());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengeluaran', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, size: 22), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: AppColors.danger, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Pengeluaran', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      Text(formatCurrency(_total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.danger)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            ..._items.map((raw) {
              final e = Map<String, dynamic>.from(raw as Map);
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
                    backgroundColor: AppColors.dangerLight,
                    child: const Icon(Icons.money_off_rounded, color: AppColors.danger, size: 18),
                  ),
                  title: Text(e['description'] ?? e['category'] ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${e['category'] ?? '-'} · ${e['created_at'] ?? ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatCurrency(((e['amount'] as num?) ?? 0).toDouble()), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.danger)),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _showForm(existing: e);
                          if (v == 'delete') _delete(e);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: AppColors.danger))),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (!_loading && _items.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Belum ada pengeluaran'))),
            const SizedBox(height: 72),
          ],
        ),
      ),
    );
  }
}
