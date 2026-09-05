import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/report_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/stat_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts(refresh: true);
      context.read<ProductProvider>().loadCategories();
      context.read<TransactionProvider>().loadTransactions(refresh: true);
      context.read<ReportProvider>().loadFinanceSummary();
      context.read<SettingsProvider>().loadPublicSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _DashboardTab(),
          _ProductsTab(),
          _TransactionsTab(),
          _SettingsTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, 'Beranda'),
                _buildNavItem(1, Icons.inventory_2_rounded, 'Produk'),
                _buildNavCenterButton(),
                _buildNavItem(2, Icons.receipt_long_rounded, 'Transaksi'),
                _buildNavItem(3, Icons.settings_rounded, 'Lainnya'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: isSelected ? AppColors.primary : AppColors.textMuted),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? AppColors.primary : AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavCenterButton() {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed('/pos'),
        child: Container(
          width: 52,
          height: 52,
          margin: const EdgeInsets.only(bottom: 2),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, Color(0xFF818CF8)]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x406366F1), blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final products = context.watch<ProductProvider>();
    final transactions = context.watch<TransactionProvider>();
    context.watch<ReportProvider>();

    final todayTotal = transactions.transactions
        .where((t) => t.type == 'sell' && t.createdAt != null && _isToday(t.createdAt!))
        .fold(0.0, (sum, t) => sum + t.total);

    final todayCount = transactions.transactions
        .where((t) => t.type == 'sell' && t.createdAt != null && _isToday(t.createdAt!))
        .length;

    final lowStockCount = products.products.where((p) => p.isLowStock).length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF818CF8)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.store_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Halo, ${auth.user?.name ?? 'User'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          Text('Selamat bekerja!', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 6, color: AppColors.success),
                          SizedBox(width: 4),
                          Text('Online', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              StatCard(
                title: 'Penjualan Hari',
                value: formatCurrency(todayTotal),
                icon: Icons.trending_up_rounded,
                color: AppColors.success,
              ),
              StatCard(
                title: 'Transaksi',
                value: '$todayCount',
                icon: Icons.receipt_long_rounded,
                color: AppColors.primary,
              ),
              StatCard(
                title: 'Total Produk',
                value: '${products.products.length}',
                icon: Icons.inventory_2_rounded,
                color: AppColors.secondary,
              ),
              StatCard(
                title: 'Stok Menipis',
                value: '$lowStockCount',
                icon: Icons.warning_amber_rounded,
                color: lowStockCount > 0 ? AppColors.warning : AppColors.success,
              ),
            ],
          ),
        ),

        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: Text('Aksi Cepat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          sliver: SliverGrid.count(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.9,
            children: [
              _QuickAction(icon: Icons.add_shopping_cart_rounded, label: 'Kasir', color: AppColors.primary, onTap: () => Navigator.pushNamed(context, '/pos')),
              _QuickAction(icon: Icons.inventory_2_rounded, label: 'Produk', color: AppColors.secondary, onTap: () => Navigator.pushNamed(context, '/products')),
              _QuickAction(icon: Icons.people_rounded, label: 'Pelanggan', color: AppColors.success, onTap: () => Navigator.pushNamed(context, '/customers')),
              _QuickAction(icon: Icons.receipt_long_rounded, label: 'Riwayat', color: AppColors.warning, onTap: () => Navigator.pushNamed(context, '/transactions')),
            ],
          ),
        ),

        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: Text('Transaksi Terakhir', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ),
        if (transactions.isLoading && transactions.transactions.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (transactions.transactions.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: const Center(child: Text('Belum ada transaksi', style: TextStyle(color: AppColors.textMuted))),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final t = transactions.transactions[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: t.type == 'sell' ? AppColors.successLight : AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(8),
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
                              Text(t.invoiceNumber ?? '#${t.id}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(t.customerName ?? t.userName ?? '-', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Text(formatCurrency(t.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                      ],
                    ),
                  );
                },
                childCount: transactions.transactions.length > 5 ? 5 : transactions.transactions.length,
              ),
            ),
          ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ProductsTab extends StatelessWidget {
  const _ProductsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Produk'));
  }
}

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Transaksi'));
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Pengaturan'));
  }
}
