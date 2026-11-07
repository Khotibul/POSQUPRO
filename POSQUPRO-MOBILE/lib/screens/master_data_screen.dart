import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/theme.dart';

class MasterDataScreen extends StatefulWidget {
  const MasterDataScreen({super.key});

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tab = TabController(length: 3, vsync: this);
  bool _loading = false;
  final Map<String, List> _data = {'cat': [], 'unit': [], 'tax': []};

  static const _paths = {
    'cat': '/v1/categories',
    'unit': '/v1/unit-quantities',
    'tax': '/v1/taxes',
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load(String k) async {
    try {
      final res = await _api.get(_paths[k]!);
      final data = res['data'];
      _data[k] = data is List ? data : (data?['data'] ?? []);
    } catch (_) {}
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_load('cat'), _load('unit'), _load('tax')]);
    if (mounted) setState(() => _loading = false);
  }

  String _tabKey() => ['cat', 'unit', 'tax'][_tab.index];

  Future<void> _showForm({Map? existing}) async {
    final k = _tabKey();
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final description = TextEditingController(text: existing?['description']?.toString() ?? '');
    final symbol = TextEditingController(text: existing?['symbol']?.toString() ?? '');
    final rate = TextEditingController(text: existing?['rate']?.toString() ?? '');
    final isEdit = existing != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${isEdit ? 'Edit' : 'Tambah'} ${_titleFor(k)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama *')),
              if (k == 'unit') ...[
                const SizedBox(height: 8),
                TextField(controller: symbol, decoration: const InputDecoration(labelText: 'Simbol * (cth: pcs, kg)')),
              ],
              if (k == 'tax') ...[
                const SizedBox(height: 8),
                TextField(controller: rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tarif * (%)')),
              ],
              if (k == 'cat') ...[
                const SizedBox(height: 8),
                TextField(controller: description, decoration: const InputDecoration(labelText: 'Deskripsi'), maxLines: 2),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final body = <String, dynamic>{'name': name.text.trim()};
    if (k == 'unit') body['symbol'] = symbol.text.trim();
    if (k == 'tax') body['rate'] = double.tryParse(rate.text) ?? 0;
    if (k == 'cat' && description.text.isNotEmpty) body['description'] = description.text.trim();
    if (name.text.trim().isEmpty) return;

    try {
      final path = _paths[k]!;
      final res = isEdit
          ? await _api.put('$path/${existing['id']}', body: body)
          : await _api.post(path, body: body);
      if (!mounted) return;
      if (res['success'] == true) {
        _load(k);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_titleFor(k)} ${isEdit ? 'diperbarui' : 'ditambahkan'}'), backgroundColor: AppColors.success),
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

  Future<void> _delete(Map item) async {
    final k = _tabKey();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Hapus ${_titleFor(k)}'),
        content: Text('Hapus "${item['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.delete('${_paths[k]}/${item['id']}');
      _load(k);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  String _titleFor(String k) => switch (k) {
        'cat' => 'Kategori',
        'unit' => 'Satuan',
        _ => 'Pajak',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Master Data', style: TextStyle(fontSize: 18)),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Kategori'),
            Tab(text: 'Satuan'),
            Tab(text: 'Pajak'),
          ],
          onTap: (_) => setState(() {}),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: TabBarView(
          controller: _tab,
          children: [
            _list(_data['cat']!, 'cat'),
            _list(_data['unit']!, 'unit'),
            _list(_data['tax']!, 'tax'),
          ],
        ),
      ),
    );
  }

  Widget _list(List items, String k) {
    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...items.map((raw) {
          final i = Map<String, dynamic>.from(raw as Map);
          final subtitle = switch (k) {
            'unit' => 'Simbol: ${i['symbol'] ?? '-'}',
            'tax' => 'Tarif: ${i['rate'] ?? 0}%',
            _ => (i['description'] ?? '').toString(),
          };
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
                child: Icon(
                  k == 'cat' ? Icons.category_rounded : k == 'unit' ? Icons.straighten_rounded : Icons.percent_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              title: Text(i['name'] ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _showForm(existing: i);
                  if (v == 'delete') _delete(i);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: AppColors.danger))),
                ],
              ),
            ),
          );
        }),
        if (items.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Tidak ada ${_titleFor(k)}'))),
        const SizedBox(height: 72),
      ],
    );
  }
}
