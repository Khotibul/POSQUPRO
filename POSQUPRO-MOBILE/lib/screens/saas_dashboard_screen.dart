import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/theme.dart';

class SaasDashboardScreen extends StatefulWidget {
  const SaasDashboardScreen({super.key});

  @override
  State<SaasDashboardScreen> createState() => _SaasDashboardScreenState();
}

class _SaasDashboardScreenState extends State<SaasDashboardScreen> {
  final _api = ApiService();
  bool _loading = false;
  Map<String, dynamic> _stats = {};
  List _recentTenants = [];
  List _recentInvoices = [];
  List _planDistribution = [];
  List _revenueByMonth = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/v1/saas/dashboard');
      if (res['success'] == true && res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data']);
        setState(() {
          _stats = Map<String, dynamic>.from(data['stats'] ?? {});
          _recentTenants = (data['recent_tenants'] as List?) ?? [];
          _recentInvoices = (data['recent_invoices'] as List?) ?? [];
          _planDistribution = (data['plan_distribution'] as List?) ?? [];
          _revenueByMonth = (data['revenue_by_month'] as List?) ?? [];
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal memuat dashboard'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Widget _card(String title, dynamic val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          const Spacer(),
          Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            val == null ? '0' : (val is num ? formatCurrency(val.toDouble()) : val.toString()),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SaaS Dashboard', style: TextStyle(fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, size: 22), onPressed: _load)],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _stats.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    children: [
                      _card('Total Tenant', _stats['total_tenants'], Icons.business_rounded, AppColors.primary),
                      _card('Tenant Aktif', _stats['active_tenants'], Icons.check_circle_rounded, AppColors.success),
                      _card('Trial', _stats['trial_tenants'], Icons.hourglass_bottom_rounded, AppColors.secondary),
                      _card('Ditangguhkan', _stats['suspended_tenants'], Icons.block_rounded, AppColors.danger),
                      _card('Total Pengguna', _stats['total_users'], Icons.people_rounded, AppColors.primary),
                      _card('Pendapatan', _stats['total_revenue'], Icons.attach_money_rounded, AppColors.success),
                      _card('Bulan Ini', _stats['monthly_revenue'], Icons.calendar_month_rounded, AppColors.warning),
                      _card('Belum Dibayar', _stats['outstanding'], Icons.pending_rounded, AppColors.danger),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Akses Cepat'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _quickNav(context, 'Tenant', Icons.business_rounded, '/tenants'),
                      const SizedBox(width: 8),
                      _quickNav(context, 'Paket', Icons.card_membership_rounded, '/plans'),
                      const SizedBox(width: 8),
                      _quickNav(context, 'Tagihan', Icons.receipt_long_rounded, '/invoices'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_planDistribution.isNotEmpty) ...[
                    _sectionTitle('Distribusi Paket'),
                    const SizedBox(height: 8),
                    ..._planDistribution.map((p) {
                      final count = (p['tenants_count'] as num?)?.toInt() ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                        child: Row(
                          children: [
                            Expanded(child: Text('${p['name'] ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                            Text('$count tenant', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                  if (_revenueByMonth.isNotEmpty) ...[
                    _sectionTitle('Pendapatan 12 Bulan'),
                    const SizedBox(height: 8),
                    ..._revenueByMonth.map((m) => _row('${m['month'] ?? '-'} (${m['count'] ?? 0} inv)', formatCurrency(_num(m['revenue'])))),
                    const SizedBox(height: 12),
                  ],
                  if (_recentTenants.isNotEmpty) ...[
                    _sectionTitle('Tenant Terbaru'),
                    const SizedBox(height: 8),
                    ..._recentTenants.map((t) => _row(
                          '${t['name'] ?? '-'}',
                          '${t['status'] ?? '-'}${t['plan'] != null ? ' · ${t['plan']['name']}' : ''}',
                        )),
                    const SizedBox(height: 12),
                  ],
                  if (_recentInvoices.isNotEmpty) ...[
                    _sectionTitle('Invoice Terbaru'),
                    const SizedBox(height: 8),
                    ..._recentInvoices.take(8).map((i) => _row(
                          '${i['invoice_number'] ?? '#${i['id']}'}',
                          '${i['status'] ?? '-'} · ${formatCurrency(_num(i['total']))}',
                        )),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700));

  Widget _row(String left, String right) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Expanded(child: Text(left, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text(right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _quickNav(BuildContext context, String label, IconData icon, String route) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;
}
