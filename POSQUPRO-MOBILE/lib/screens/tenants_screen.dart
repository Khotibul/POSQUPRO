import 'package:flutter/material.dart';
import '../core/api_service.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
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
      final res = await _api.get('/v1/tenants');
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
      appBar: AppBar(title: const Text('Tenant')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            ..._items.map((t) => Card(child: ListTile(title: Text(t['name'] ?? '-'), subtitle: Text('${t['email'] ?? ''} | Status: ${t['status'] ?? '-'}'), trailing: Text(t['plan_id']?.toString() ?? '-')))),
            if (!_loading && _items.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Tidak ada tenant'))),
          ],
        ),
      ),
    );
  }
}
