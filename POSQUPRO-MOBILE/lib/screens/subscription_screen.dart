import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/browser_service.dart';
import '../core/theme.dart';
import '../models/subscription.dart';
import '../providers/subscription_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  static const _featureLabels = <String, String>{
    'pos': 'POS / Kasir',
    'products': 'Produk & Stok',
    'customers': 'Pelanggan',
    'suppliers': 'Supplier',
    'inventory': 'Inventory',
    'expenses': 'Pengeluaran',
    'users': 'Pengguna & RBAC',
    'reports': 'Laporan & Analitik',
    'purchase_orders': 'Purchase Order',
    'stock_counts': 'Stock Opname',
    'multi_branch': 'Multi Cabang & Gudang',
    'api_access': 'Akses API / Mobile',
    'priority_support': 'Priority Support',
  };

  static const _limitLabels = <String, (String, IconData)>{
    'users': ('Pengguna', Icons.people_alt_rounded),
    'products': ('Produk', Icons.inventory_2_rounded),
    'customers': ('Pelanggan', Icons.people_rounded),
    'branches': ('Cabang', Icons.store_rounded),
    'transactions_month': ('Transaksi bulan ini', Icons.receipt_long_rounded),
  };

  bool _yearly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadBilling();
    });
  }

  Future<void> _refresh() async {
    await context.read<SubscriptionProvider>().loadBilling();
  }

  Future<void> _checkout(BillingPlan plan) async {
    final provider = context.read<SubscriptionProvider>();
    final cycle = _yearly ? 'yearly' : 'monthly';
    final url = await provider.checkout(plan.id, cycle);
    if (!mounted) return;

    if (url == null || url.isEmpty) {
      _snack(provider.error ?? 'Gagal membuat pembayaran', error: true);
      return;
    }

    final opened = await BrowserService.open(url);
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pembayaran iPaymu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              opened
                  ? 'Halaman pembayaran dibuka di browser. Selesaikan pembayaran, paket aktif otomatis setelah callback iPaymu.'
                  : 'Buka tautan berikut di browser untuk menyelesaikan pembayaran:',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            SelectableText(url, style: const TextStyle(fontSize: 11, color: AppColors.info)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) _snack('Tautan pembayaran disalin');
            },
            child: const Text('Salin tautan'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    final overview = provider.billing;
    final snapshot = provider.subscription;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Langganan', style: TextStyle(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, size: 22), onPressed: _refresh),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: provider.isLoading && overview == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (snapshot != null) _statusCard(snapshot),
                  if (provider.error != null && overview == null) ...[
                    const SizedBox(height: 12),
                    _errorCard(provider.error!),
                  ],
                  if (snapshot != null) ...[
                    const SizedBox(height: 20),
                    const _SectionTitle('Pemakaian Paket'),
                    const SizedBox(height: 8),
                    _limitsCard(snapshot),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: _SectionTitle('Pilih Paket')),
                      if (overview != null)
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('Bulanan')),
                            ButtonSegment(value: true, label: Text('Tahunan')),
                          ],
                          selected: {_yearly},
                          onSelectionChanged: (value) => setState(() => _yearly = value.first),
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (overview == null)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Paket belum tersedia')))
                  else
                    ...overview.plans.map((plan) => _planCard(plan, overview)),
                  if (overview != null && overview.invoices.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _SectionTitle('Invoice Terakhir'),
                    const SizedBox(height: 8),
                    ...overview.invoices.map(_invoiceCard),
                  ],
                  const SizedBox(height: 24),
                  if (overview != null && !overview.ipaymuEnabled)
                    _infoCard(
                      'Pembayaran online belum dikonfigurasi di server. Hubungi administrator untuk aktivasi manual.',
                    ),
                ],
              ),
      ),
    );
  }

  Widget _statusCard(SubscriptionSnapshot snapshot) {
    final expired = snapshot.isExpired;
    final suspended = snapshot.status == 'suspended' || snapshot.status == 'inactive';
    final color = expired || suspended ? AppColors.danger : AppColors.primary;
    final title = expired
        ? 'Langganan berakhir'
        : suspended
            ? 'Akun ditangguhkan'
            : snapshot.isTrial
                ? 'Demo 30 Hari'
                : 'Paket Aktif';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: expired || suspended ? null : AppGradients.hero,
        color: expired || suspended ? AppColors.dangerLight : null,
        borderRadius: BorderRadius.circular(18),
        boxShadow: expired || suspended ? null : AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                expired || suspended ? Icons.error_outline_rounded : Icons.verified_rounded,
                color: expired || suspended ? color : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: expired || suspended ? color : Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (expired || suspended ? color : Colors.white).withValues(alpha: expired || suspended ? 0.12 : 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  snapshot.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: expired || suspended ? color : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            snapshot.planName ?? 'Belum ada paket',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: expired || suspended ? AppColors.textPrimary : Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            expired
                ? 'Masa aktif telah berakhir. Pilih paket di bawah untuk melanjutkan.'
                : snapshot.isTrial
                    ? 'Sisa ${snapshot.daysRemaining} hari demo. Semua fitur terbuka.'
                    : 'Aktif sampai ${_formatDate(snapshot.endsAt)} · ${snapshot.daysRemaining} hari lagi',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: expired || suspended ? AppColors.textSecondary : Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _limitsCard(SubscriptionSnapshot snapshot) {
    final limits = snapshot.limits;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          for (final entry in _limitLabels.entries)
            if (limits[entry.key] is Map) ...[
              _limitRow(
                entry.value.$1,
                entry.value.$2,
                Map<String, dynamic>.from(limits[entry.key] as Map),
              ),
              if (entry.key != _limitLabels.keys.last) const Divider(height: 18),
            ],
        ],
      ),
    );
  }

  Widget _limitRow(String label, IconData icon, Map<String, dynamic> row) {
    final unlimited = row['unlimited'] == true;
    final current = (row['current'] as num?)?.toInt() ?? 0;
    final max = (row['max'] as num?)?.toInt() ?? 0;
    final ok = row['ok'] != false;
    final value = unlimited ? '$current / Tak terbatas' : '$current / $max';

    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ok ? AppColors.textPrimary : AppColors.danger,
          ),
        ),
      ],
    );
  }

  Widget _planCard(BillingPlan plan, BillingOverview overview) {
    final price = _yearly && plan.priceYearly > 0 ? plan.priceYearly : plan.price;
    final isCurrent = plan.name == overview.subscription.planName;
    final canBuy = overview.ipaymuEnabled;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCurrent ? AppColors.primary : AppColors.borderLight, width: isCurrent ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(plan.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(999)),
                  child: const Text('Paket Anda', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.success)),
                ),
            ],
          ),
          if ((plan.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(plan.description!, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatCurrency(price), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
              Text(_yearly ? ' / tahun' : ' / bulan', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _badge('${plan.maxUsers <= 0 ? '∞' : plan.maxUsers} pengguna'),
              _badge('${plan.maxProducts <= 0 ? '∞' : plan.maxProducts} produk'),
              _badge('${plan.maxCustomers <= 0 ? '∞' : plan.maxCustomers} pelanggan'),
              _badge('${plan.maxBranches <= 0 ? '∞' : plan.maxBranches} cabang'),
              _badge('${plan.maxTransactions <= 0 ? '∞' : plan.maxTransactions} transaksi/bln'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: plan.features
                .map((f) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(_featureLabels[f] ?? f, style: const TextStyle(fontSize: 10.5)),
                      ],
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canBuy
                  ? () => _checkout(plan)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Bayar dengan iPaymu', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceCard(BillingInvoice invoice) {
    final paid = invoice.status == 'paid';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(
            paid ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 20,
            color: paid ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoice.invoiceNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(
                  '${invoice.planName ?? 'Paket'} · ${_formatDate(invoice.issuedAt)}',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatCurrency(invoice.total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text(invoice.status.toUpperCase(), style: TextStyle(fontSize: 9, color: paid ? AppColors.success : AppColors.warning)),
            ],
          ),
          if (!paid && (invoice.paymentUrl ?? '').isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded, size: 18),
              tooltip: 'Buka pembayaran',
              onPressed: () async {
                final url = invoice.paymentUrl!;
                final opened = await BrowserService.open(url);
                if (!opened && mounted) {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (mounted) _snack('Tautan pembayaran disalin');
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _badge(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      );

  Widget _infoCard(String message) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 17, color: AppColors.info),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 11.5, color: AppColors.info))),
          ],
        ),
      );

  Widget _errorCard(String message) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(12)),
        child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
      );

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final local = date.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2),
    );
  }
}
