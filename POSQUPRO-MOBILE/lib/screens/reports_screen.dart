import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/report_provider.dart';
import '../providers/transaction_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime? _from;
  DateTime? _to;
  String _tab = 'summary';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reports = context.read<ReportProvider>();
      reports.loadFinanceSummary();
      reports.loadSalesReport();
      reports.loadInventoryReport();
    });
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (picked == null) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    if (mounted) {
      context.read<ReportProvider>().loadSalesReport(
            from: _fmtDate(picked.start),
            to: _fmtDate(picked.end),
          );
    }
  }

  void _resetRange() {
    setState(() {
      _from = null;
      _to = null;
    });
    context.read<ReportProvider>().loadSalesReport();
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<ReportProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final summary = reports.financeSummary;
    final sales = reports.salesReport;
    final inventory = reports.inventoryReport;

    final totalRevenue = _num(summary?['total_revenue'] ?? summary?['revenue'] ?? 0);
    final totalProfit = _num(summary?['total_profit'] ?? summary?['profit'] ?? 0);
    final totalTransactions = (summary?['total_transactions'] ?? summary?['transactions'] ?? 0).toString();

    final todayTotal = txProvider.transactions
        .where((t) => t.type == 'sell' && t.createdAt != null && _isToday(t.createdAt!))
        .fold(0.0, (sum, t) => sum + t.total);

    final monthTotal = txProvider.transactions
        .where((t) => t.type == 'sell' && t.createdAt != null && _isThisMonth(t.createdAt!))
        .fold(0.0, (sum, t) => sum + t.total);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan', style: TextStyle(fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded, size: 22),
            tooltip: 'Pilih tanggal',
            onPressed: _pickRange,
          ),
          if (_from != null)
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 22),
              tooltip: 'Reset tanggal',
              onPressed: _resetRange,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final reports = context.read<ReportProvider>();
          await Future.wait([
            reports.loadFinanceSummary(),
            reports.loadSalesReport(
              from: _from != null ? _fmtDate(_from!) : null,
              to: _to != null ? _fmtDate(_to!) : null,
            ),
            reports.loadInventoryReport(),
          ]);
          await txProvider.loadTransactions(refresh: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_from != null && _to != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('${_fmtDate(_from!)} s/d ${_fmtDate(_to!)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      const Spacer(),
                      GestureDetector(onTap: _resetRange, child: const Icon(Icons.close_rounded, size: 16, color: AppColors.primary)),
                    ],
                  ),
                ),
              Row(
                children: [
                  _tabBtn('summary', 'Ringkasan'),
                  const SizedBox(width: 8),
                  _tabBtn('sales', 'Penjualan'),
                  const SizedBox(width: 8),
                  _tabBtn('inventory', 'Inventaris'),
                ],
              ),
              const SizedBox(height: 16),
              if (reports.isLoading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              if (!reports.isLoading && _tab == 'summary') ...[
                const Text('Ringkasan Keuangan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _SummaryCard(title: 'Total Pendapatan', value: formatCurrency(totalRevenue), color: AppColors.success)),
                    const SizedBox(width: 12),
                    Expanded(child: _SummaryCard(title: 'Total Laba', value: formatCurrency(totalProfit), color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _SummaryCard(title: 'Hari Ini', value: formatCurrency(todayTotal), color: AppColors.secondary)),
                    const SizedBox(width: 12),
                    Expanded(child: _SummaryCard(title: 'Bulan Ini', value: formatCurrency(monthTotal), color: AppColors.warning)),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Statistik', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                _StatRow(label: 'Total Transaksi', value: totalTransactions),
                _StatRow(label: 'Transaksi Tersinkron', value: '${txProvider.transactions.length}'),
                _StatRow(
                  label: 'Rata-rata per Transaksi',
                  value: int.tryParse(totalTransactions) != null && int.parse(totalTransactions) > 0
                      ? formatCurrency(totalRevenue / int.parse(totalTransactions))
                      : 'Rp 0',
                ),
              ],
              if (!reports.isLoading && _tab == 'sales') ...[
                if (sales == null)
                  const Text('Gagal memuat laporan penjualan', style: TextStyle(color: AppColors.danger))
                else ...[
                  Row(
                    children: [
                      Expanded(child: _SummaryCard(title: 'Pendapatan', value: formatCurrency(sales.totalRevenue), color: AppColors.success)),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryCard(title: 'Transaksi', value: '${sales.totalTransactions}', color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Penjualan Harian', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (sales.daily.isEmpty)
                    const Text('Tidak ada data', style: TextStyle(color: AppColors.textMuted, fontSize: 13))
                  else
                    ...sales.daily.map((d) => _StatRow(
                          label: '${d['date'] ?? '-'} (${d['count'] ?? 0} trx)',
                          value: formatCurrency(_num(d['total'])),
                        )),
                  const SizedBox(height: 16),
                  const Text('Produk Terlaris', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (sales.topProducts.isEmpty)
                    const Text('Tidak ada data', style: TextStyle(color: AppColors.textMuted, fontSize: 13))
                  else
                    ...sales.topProducts.map((p) => _StatRow(
                          label: '${p['product']?['name'] ?? 'Produk #${p['product_id']}'} (x${p['qty'] ?? 0})',
                          value: formatCurrency(_num(p['revenue'])),
                        )),
                ],
              ],
              if (!reports.isLoading && _tab == 'inventory') ...[
                if (inventory == null)
                  const Text('Gagal memuat laporan inventaris', style: TextStyle(color: AppColors.danger))
                else ...[
                  Row(
                    children: [
                      Expanded(child: _SummaryCard(title: 'Total Produk', value: '${inventory.totalProducts}', color: AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryCard(title: 'Nilai Stok (Beli)', value: formatCurrency(inventory.stockValue), color: AppColors.warning)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Stok Menipis', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (inventory.lowStock.isEmpty)
                    const Text('Semua stok aman', style: TextStyle(color: AppColors.success, fontSize: 13))
                  else
                    ...inventory.lowStock.map((p) => _StatRow(
                          label: '${p['name'] ?? '-'}',
                          value: '${p['stock'] ?? 0}/${p['min_stock'] ?? 0}',
                        )),
                  const SizedBox(height: 16),
                  const Text('Pergerakan Terakhir', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (inventory.movements.isEmpty)
                    const Text('Tidak ada data', style: TextStyle(color: AppColors.textMuted, fontSize: 13))
                  else
                    ...inventory.movements.take(10).map((m) => _StatRow(
                          label: '${m['product']?['name'] ?? m['product_id'] ?? '-'} (${m['type'] ?? m['movement_type'] ?? ''})',
                          value: '${m['quantity'] ?? m['qty'] ?? 0}',
                        )),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBtn(String value, String label) {
    final isSelected = _tab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
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
          Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
