import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/transaction.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction transaction;
  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final t = transaction;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t.invoiceNumber ?? 'Detail', style: const TextStyle(fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.type == 'sell' ? AppColors.successLight : AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    t.type == 'sell' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: t.type == 'sell' ? AppColors.success : AppColors.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(formatCurrency(t.total), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: t.type == 'sell' ? AppColors.success : AppColors.primary)),
                  const SizedBox(height: 4),
                  Text(t.type == 'sell' ? 'Penjualan' : 'Pembelian', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _InfoCard(
              children: [
                _InfoRow(label: 'Invoice', value: t.invoiceNumber ?? '-'),
                _InfoRow(label: 'Status', value: t.status),
                _InfoRow(label: 'Pelanggan', value: t.customerName ?? t.userName ?? '-'),
                if (t.createdAt != null) _InfoRow(label: 'Tanggal', value: formatDate(t.createdAt!)),
                if (t.notes != null && t.notes!.isNotEmpty) _InfoRow(label: 'Catatan', value: t.notes!),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Item', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            ...t.items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.productName ?? 'Item #${item.productId}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('${item.quantity} x ${formatCurrency(item.unitPrice)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text(formatCurrency(item.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            )),
            const SizedBox(height: 16),
            _InfoCard(
              children: [
                _InfoRow(label: 'Subtotal', value: formatCurrency(t.subtotal)),
                _InfoRow(label: 'Diskon', value: '-${formatCurrency(t.discount)}'),
                _InfoRow(label: 'Pajak', value: formatCurrency(t.taxAmount)),
                const Divider(),
                _InfoRow(label: 'Total', value: formatCurrency(t.total), isBold: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _InfoRow({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
