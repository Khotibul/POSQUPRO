import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/local_database_provider.dart';

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
      context.read<LocalDatabaseProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    if (isDesktop) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          _buildSideNav(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const _DashboardTab();
      case 1:
        return const _PlaceholderTab(title: 'Produk', icon: Icons.inventory_2_rounded);
      case 2:
        return const _PlaceholderTab(title: 'Transaksi', icon: Icons.receipt_long_rounded);
      case 3:
        return const _PlaceholderTab(title: 'Lainnya', icon: Icons.settings_rounded);
      default:
        return const _DashboardTab();
    }
  }

  Widget _buildSideNav() {
    final items = [
      _NavItemData(0, Icons.dashboard_rounded, 'Beranda'),
      _NavItemData(1, Icons.inventory_2_rounded, 'Produk'),
      _NavItemData(2, Icons.receipt_long_rounded, 'Transaksi'),
      _NavItemData(3, Icons.settings_rounded, 'Lainnya'),
    ];

    return Container(
      width: 72,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF818CF8)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.store_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 24),
          ...items.map((item) => _buildSideNavItem(item)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/pos'),
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary, Color(0xFF818CF8)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideNavItem(_NavItemData item) {
    final isSelected = _currentIndex == item.index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = item.index),
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(item.icon, size: 22, color: isSelected ? AppColors.primary : AppColors.textMuted),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
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
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(10),
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
          width: 48,
          height: 48,
          margin: const EdgeInsets.only(bottom: 2),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, Color(0xFF818CF8)]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x406366F1), blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _NavItemData {
  final int index;
  final IconData icon;
  final String label;
  _NavItemData(this.index, this.icon, this.label);
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final db = context.watch<LocalDatabaseProvider>();
    final isDesktop = Responsive.isDesktop(context);
    final padding = Responsive.padding(context);

    final stats = db.stats;
    final productCount = stats['product_count'] ?? 0;
    final todayCount = stats['today_sales_count'] ?? 0;
    final todayTotal = stats['today_sales_total'] ?? 0;
    final lowStockCount = stats['low_stock_count'] ?? 0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(padding, 12, padding, 16),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF818CF8)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.store_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Halo, ${auth.user?.name ?? 'User'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const Text('Selamat bekerja!', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (db.isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 5, color: AppColors.success),
                        SizedBox(width: 4),
                        Text('DB OK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success)),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, size: 5, color: AppColors.danger),
                        const SizedBox(width: 4),
                        Text(db.error != null ? 'DB Error' : 'Connecting...', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.danger)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(padding),
          sliver: SliverGrid.count(
            crossAxisCount: isDesktop ? 4 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: isDesktop ? 1.8 : 1.6,
            children: [
              _StatCard(title: 'Penjualan Hari', value: formatCurrency(todayTotal.toDouble()), icon: Icons.trending_up_rounded, color: AppColors.success),
              _StatCard(title: 'Transaksi Hari', value: '$todayCount', icon: Icons.receipt_long_rounded, color: AppColors.primary),
              _StatCard(title: 'Total Produk', value: '$productCount', icon: Icons.inventory_2_rounded, color: AppColors.secondary),
              _StatCard(title: 'Stok Rendah', value: '$lowStockCount', icon: Icons.warning_amber_rounded, color: lowStockCount > 0 ? AppColors.warning : AppColors.success),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          sliver: const SliverToBoxAdapter(
            child: Text('Aksi Cepat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(padding, 8, padding, 16),
          sliver: SliverGrid.count(
            crossAxisCount: isDesktop ? 5 : 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: [
              _QuickAction(icon: Icons.add_shopping_cart_rounded, label: 'Kasir', color: AppColors.primary, onTap: () => Navigator.pushNamed(context, '/pos')),
              _QuickAction(icon: Icons.inventory_2_rounded, label: 'Produk', color: AppColors.secondary, onTap: () => Navigator.pushNamed(context, '/products')),
              _QuickAction(icon: Icons.people_rounded, label: 'Pelanggan', color: AppColors.success, onTap: () => Navigator.pushNamed(context, '/customers')),
              _QuickAction(icon: Icons.receipt_long_rounded, label: 'Riwayat', color: AppColors.warning, onTap: () => Navigator.pushNamed(context, '/transactions')),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          sliver: const SliverToBoxAdapter(
            child: Text('Data Terakhir dari Database', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
        if (db.isLoading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (db.transactions.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storage_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  const Text('Belum ada data', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 8, padding, 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final t = db.transactions[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.arrow_upward_rounded, color: AppColors.success, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.invoiceNumber ?? '#${t.id}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(t.customerName ?? t.userName ?? '-', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Text(formatCurrency(t.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  );
                },
                childCount: db.transactions.length > 10 ? 10 : db.transactions.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderTab({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
