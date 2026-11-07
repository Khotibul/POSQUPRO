import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/theme.dart';

class ParkedScreen extends StatefulWidget {
  const ParkedScreen({super.key});

  @override
  State<ParkedScreen> createState() => _ParkedScreenState();
}

class _ParkedScreenState extends State<ParkedScreen> {
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
      final res = await _api.get('/v1/parked-transactions');
      setState(() {
        _items = res['data'] is List ? res['data'] : (res['data']['data'] ?? []);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => _loading = false);
  }

  Future<void> _resume(dynamic item) async {
    if (!mounted) return;
    final id = item['id'];
    final items = (item['items'] as List?) ?? [];
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang kosong'), backgroundColor: AppColors.danger),
      );
      return;
    }
    // Pass full parked payload so POS can rebuild the cart without an extra fetch
    Navigator.pushReplacementNamed(context, '/pos', arguments: {
      'parkId': id,
      'items': items,
      'discount': item['discount'],
      'taxAmount': item['tax_amount'],
      'notes': item['notes'],
    });
  }

  Future<void> _delete(dynamic item) async {
    try {
      await _api.delete('/v1/parked-transactions/${item['id']}');
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi Ditahan')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            ..._items.map((p) => Card(
                  child: ListTile(
                    title: Text(p['invoice_number'] ?? p['notes'] ?? '#${p['id']}'),
                    subtitle: Text('Total: ${p['total'] ?? p['total_amount'] ?? 0} | ${p['created_at'] ?? ''}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => _resume(p), tooltip: 'Pulihkan'),
                        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(p), tooltip: 'Hapus'),
                      ],
                    ),
                  ),
                )),
            if (!_loading && _items.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Tidak ada transaksi tertahan'))),
          ],
        ),
      ),
    );
  }
}
