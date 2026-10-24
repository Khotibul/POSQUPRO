import 'package:flutter/material.dart';
import '../core/api_service.dart';

class MasterDataScreen extends StatefulWidget {
  const MasterDataScreen({super.key});

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tab = TabController(length: 6, vsync: this);
  bool _loading = false;
  final Map<String, List> _data = {'cat': [], 'unit': [], 'tax': [], 'branch': [], 'warehouse': [], 'pm': []};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _load(String k, String path) async {
    try {
      final res = await _api.get(path);
      _data[k] = res['data'] is List ? res['data'] : (res['data']['data'] ?? []);
    } catch (_) {}
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _load('cat', '/v1/categories'),
      _load('unit', '/v1/unit-quantities'),
      _load('tax', '/v1/taxes'),
      _load('branch', '/v1/branches'),
      _load('warehouse', '/v1/warehouses'),
      _load('pm', '/v1/payment-methods'),
    ]);
    setState(() => _loading = false);
  }

  Widget _list(List items, String title) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
        ...items.map((i) => Card(child: ListTile(title: Text(i['name'] ?? i['code'] ?? '-'), subtitle: Text(i['description'] ?? i['email'] ?? '')))),
        if (!_loading && items.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Tidak ada $title'))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Data'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Kategori'),
            Tab(text: 'Satuan'),
            Tab(text: 'Pajak'),
            Tab(text: 'Cabang'),
            Tab(text: 'Gudang'),
            Tab(text: 'Metode Bayar'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: TabBarView(
          controller: _tab,
          children: [
            _list(_data['cat']!, 'Kategori'),
            _list(_data['unit']!, 'Satuan'),
            _list(_data['tax']!, 'Pajak'),
            _list(_data['branch']!, 'Cabang'),
            _list(_data['warehouse']!, 'Gudang'),
            _list(_data['pm']!, 'Metode Bayar'),
          ],
        ),
      ),
    );
  }
}
