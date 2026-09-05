import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import 'transaction_detail_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transaksi', style: TextStyle(fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => provider.search(v),
              decoration: InputDecoration(
                hintText: 'Cari transaksi...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: AppColors.surface,
              ),
            ),
          ),
          Expanded(
            child: provider.isLoading && provider.transactions.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.transactions.isEmpty
                    ? const Center(child: Text('Belum ada transaksi', style: TextStyle(color: AppColors.textMuted)))
                    : RefreshIndicator(
                        onRefresh: () => provider.loadTransactions(refresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.transactions.length + (provider.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == provider.transactions.length) {
                              provider.loadTransactions();
                              return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                            }
                            final t = provider.transactions[index];
                            return _buildCard(context, t);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Transaction t) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: t))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: t.type == 'sell' ? AppColors.successLight : AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                t.type == 'sell' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: t.type == 'sell' ? AppColors.success : AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(t.invoiceNumber ?? '#${t.id}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: t.status == 'completed' ? AppColors.successLight : AppColors.warningLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(t.status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: t.status == 'completed' ? AppColors.success : AppColors.warning)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(t.customerName ?? t.userName ?? '-', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (t.createdAt != null) Text(formatDate(t.createdAt!), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatCurrency(t.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                Text('${t.items.length} item', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
