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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadFinanceSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<ReportProvider>();
    final txProvider = context.watch<TransactionProvider>();

    final totalRevenue = reports.financeSummary?.totalRevenue ?? 0;
    final totalProfit = reports.financeSummary?.totalProfit ?? 0;
    final totalTransactions = reports.financeSummary?.totalTransactions ?? 0;

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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            _StatRow(label: 'Total Transaksi', value: '$totalTransactions'),
            _StatRow(label: 'Total Transaksi (Mobile)', value: '${txProvider.transactions.length}'),
            _StatRow(label: 'Rata-rata per Transaksi', value: totalTransactions > 0 ? formatCurrency(totalRevenue / totalTransactions) : 'Rp 0'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  reports.loadFinanceSummary();
                  txProvider.loadTransactions(refresh: true);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
