import 'package:flutter/material.dart';
import '../core/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _api = ApiService();
  bool _loading = false;
  List _registers = [];
  List _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.get('/v1/registers');
      final s = await _api.get('/v1/register-sessions');
      setState(() {
        _registers = r['data'] is List ? r['data'] : (r['data']['data'] ?? []);
        _sessions = s['data'] is List ? s['data'] : (s['data']['data'] ?? []);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    setState(() => _loading = false);
  }

  Future<void> _openSession() async {
    if (_registers.isEmpty) return;
    final reg = _registers.first;
    final ctrl = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Buka Kas'),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Modal Awal (opening_float)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Buka')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.post('/v1/register-sessions/open', body: {'register_id': reg['id'], 'opening_float': double.tryParse(ctrl.text) ?? 0});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _closeSession(dynamic session) async {
    final ctrl = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tutup Kas'),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Uang Aktual (actual_cash)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tutup')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.post('/v1/register-sessions/${session['id']}/close', body: {'actual_cash': double.tryParse(ctrl.text) ?? 0});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = _sessions.firstWhere((s) => s['status'] == 'open', orElse: () => null);
    return Scaffold(
      appBar: AppBar(title: const Text('Kas / Register')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Register', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(_registers.isEmpty ? '-' : (_registers.first['name'] ?? _registers.first['code'] ?? '-')),
                    const SizedBox(height: 12),
                    if (open == null)
                      FilledButton(onPressed: _openSession, child: const Text('Buka Kas'))
                    else
                      FilledButton(onPressed: () => _closeSession(open), child: const Text('Tutup Kas')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Riwayat Sesi', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            ..._sessions.map((s) => Card(child: ListTile(title: Text('Sesi #${s['id']}'), subtitle: Text('Status: ${s['status']} | Float: ${s['opening_float'] ?? 0}'), trailing: Text(s['opened_at']?.toString().substring(0,16) ?? '')))),
          ],
        ),
      ),
    );
  }
}
