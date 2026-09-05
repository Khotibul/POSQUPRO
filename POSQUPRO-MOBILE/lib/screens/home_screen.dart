import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/transaction_provider.dart';
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
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
              Icon(icon, size: 24, color: isSelected ? AppColors.primary : AppColors.textMuted),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? AppColors.primary : AppColors.textMuted)),
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
          width: 56,
          height: 56,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, Color(0xFF818CF8)]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x406366F1), blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 28),
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

    final todayTotal = transactions.transactions
        .where((t) => t.type == 'sell' && t.createdAt != null && _isToday(t.createdAt!))
        .fold(0.0, (sum, t) => sum + t.total);

    final todayCount = transactions.transactions
        .where((t) => t.type == 'sell' && t.createdAt != null && _isToday(t.createdAt!))
        .length;

    final lowStockCount = products.products.where((p) => p.isLowStock).length;

    return CustomScrollView(
      slivers: [
        // AppBar
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF818CF8)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.store_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Halo, ${auth.user?.name ?? 'User'}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const Text('Selamat bekerja!', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: AppColors.success),
                          SizedBox(width: 6),
                          Text('Online', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Ringkasan Hari Ini', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ),

        // Stats Grid
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              StatCard(
                title: 'Penjualan Hari Ini',
                value: _formatCurrency(todayCount > 0 ? todayTotal : 0),
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

        // Quick Actions
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverToBoxAdapter(
            child: Text('Aksi Cepat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          sliver: SliverGrid.count(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
            children: [
              _QuickAction(icon: Icons.add_shopping_cart_rounded, label: 'Kasir', color: AppColors.primary, onTap: () => Navigator.pushNamed(context, '/pos')),
              _QuickAction(icon: Icons.inventory_2_rounded, label: 'Produk', color: AppColors.secondary, onTap: () => Navigator.pushNamed(context, '/products')),
              _QuickAction(icon: Icons.receipt_long_rounded, label: 'Riwayat', color: AppColors.warning, onTap: () {}),
            ],
          ),
        ),

        // Recent Transactions
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverToBoxAdapter(
            child: Text('Transaksi Terakhir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ),
        if (transactions.isLoading && transactions.transactions.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.all(24),
            sliver: Center(child: CircularProgressIndicator()),
          )
        else if (transactions.transactions.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: Center(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  const Text('Belum ada transaksi', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final t = transactions.transactions[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: t.type == 'sell' ? AppColors.success.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            t.type == 'sell' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            color: t.type == 'sell' ? AppColors.success : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.invoiceNumber ?? '#${t.id}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(
                                t.customerName ?? t.userName ?? '-',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(_formatCurrency(t.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
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

  String _formatCurrency(double amount) {
    if (amount == 0) return 'Rp 0';
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return 'Rp $formatted';
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
