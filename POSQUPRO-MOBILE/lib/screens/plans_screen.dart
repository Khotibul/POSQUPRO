import 'package:flutter/material.dart';
import '../core/api_service.dart';

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
        _items = res['data'] is List ? res['data'] : (res['data']['data'] ?? []);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paket Langganan')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            ..._items.map((p) => Card(child: ListTile(title: Text(p['name'] ?? '-'), subtitle: Text(p['price']?.toString() ?? '0'), trailing: Text('max: ${p['max_users'] ?? '-'}')))),
            if (!_loading && _items.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Belum ada paket'))),
          ],
        ),
      ),
    );
  }
}
