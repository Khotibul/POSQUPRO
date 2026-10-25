import 'package:flutter/material.dart';
import '../core/api_service.dart';

class SaasDashboardScreen extends StatefulWidget {
  const SaasDashboardScreen({super.key});

  @override
  State<SaasDashboardScreen> createState() => _SaasDashboardScreenState();
}

class _SaasDashboardScreenState extends State<SaasDashboardScreen> {
  final _api = ApiService();
  Map _stats = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.get('/v1/saas/dashboard');
      setState(() {
        _stats = res['data'] ?? res;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _card(String title, dynamic val, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(title),
            Text(val?.toString() ?? '0', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SaaS Dashboard')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _card('Total Tenant', _stats['total_tenants'], Icons.business),
            _card('Aktif', _stats['active_tenants'], Icons.check_circle),
            _card('Trial', _stats['trial_tenants'], Icons.hourglass_bottom),
            _card('Suspended', _stats['suspended_tenants'], Icons.block),
            _card('Total User', _stats['total_users'], Icons.people),
            _card('Revenue', _stats['total_revenue'], Icons.attach_money),
            _card('Bulan Ini', _stats['monthly_revenue'], Icons.calendar_month),
            _card('Outstanding', _stats['outstanding'], Icons.pending),
          ],
        ),
      ),
    );
  }
}
