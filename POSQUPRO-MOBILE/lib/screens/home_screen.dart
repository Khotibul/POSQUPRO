import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/local_database_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/pressable.dart';
import 'products_screen.dart';
import 'transactions_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _Action {
  final IconData icon;
  final String label;
  final String route;
  final List<Color> colors;

  const _Action(this.icon, this.label, this.route, this.colors);
}

const _primaryActions = <_Action>[
  _Action(Icons.add_shopping_cart_rounded, 'Kasir', '/pos', [Color(0xFF14685B), Color(0xFF0B3F39)]),
  _Action(Icons.inventory_2_rounded, 'Produk', '/products', [Color(0xFF3D6E8F), Color(0xFF274B63)]),
  _Action(Icons.people_rounded, 'Pelanggan', '/customers', [Color(0xFFB08D57), Color(0xFF8A6C3E)]),
  _Action(Icons.receipt_long_rounded, 'Riwayat', '/transactions', [Color(0xFF7A6A9B), Color(0xFF54466F)]),
  _Action(Icons.point_of_sale_rounded, 'Kas & Shift', '/register', [Color(0xFF2F8F7B), Color(0xFF1B6255)]),
  _Action(Icons.pause_circle_outline_rounded, 'Ditahan', '/parked', [Color(0xFF8D9A95), Color(0xFF5B6A65)]),
  _Action(Icons.assessment_rounded, 'Laporan', '/reports', [Color(0xFFC08A2E), Color(0xFF8F651F)]),
  _Action(Icons.grid_view_rounded, 'Semua Menu', '__all__', [Color(0xFF3B4A55), Color(0xFF1F2A31)]),
];

const _allActions = <_Action>[
  ..._primaryActions,
  _Action(Icons.money_off_rounded, 'Pengeluaran', '/expenses', [Color(0xFFB8463B), Color(0xFF8A2F27)]),
  _Action(Icons.shopping_bag_rounded, 'Purchase Order', '/purchase-orders', [Color(0xFF2F7F8F), Color(0xFF1C5965)]),
  _Action(Icons.fact_check_rounded, 'Stock Count', '/stock-counts', [Color(0xFF6B8E4E), Color(0xFF486532)]),
  _Action(Icons.category_rounded, 'Master Data', '/master-data', [Color(0xFF6366A8), Color(0xFF41437A)]),
  _Action(Icons.settings_rounded, 'Pengaturan', '/settings', [Color(0xFF64748B), Color(0xFF3F4C5C)]),
  _Action(Icons.people_alt_rounded, 'Pengguna', '/users', [Color(0xFFB07A3E), Color(0xFF7F5324)]),
  _Action(Icons.local_shipping_rounded, 'Supplier', '/suppliers', [Color(0xFF4B7C9E), Color(0xFF2F5570)]),
  _Action(Icons.history_rounded, 'Riwayat Inventori', '/inventory-histories', [Color(0xFF7B8B5A), Color(0xFF54613A)]),
  _Action(Icons.payments_rounded, 'Pembayaran', '/payments', [Color(0xFF3E8B6D), Color(0xFF26634B)]),
  _Action(Icons.cloud_rounded, 'SaaS Dashboard', '/saas', [Color(0xFF4C6F8F), Color(0xFF2E4A63)]),
  _Action(Icons.business_rounded, 'Tenant', '/tenants', [Color(0xFF8B6C4A), Color(0xFF5E462C)]),
  _Action(Icons.card_membership_rounded, 'Paket', '/plans', [Color(0xFF9A7B3F), Color(0xFF6B5326)]),
  _Action(Icons.description_rounded, 'Invoice Langganan', '/invoices', [Color(0xFF6F6F8F), Color(0xFF484862)]),
  _Action(Icons.storage_rounded, 'Koneksi Database', '/db-setup', [Color(0xFF4A7C74), Color(0xFF2C554E)]),
];

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<LocalDatabaseProvider>().initFromSaved();
      if (!mounted) return;
      context.read<LocalDatabaseProvider>().loadAll();
      context.read<TransactionProvider>().loadTransactions(refresh: true);
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await context.read<LocalDatabaseProvider>().loadAll();
    if (!mounted) return;
    await context.read<TransactionProvider>().loadTransactions(refresh: true);
  }

  void _openAction(BuildContext context, _Action action) {
    if (action.route == '__all__') {
      _showAllMenu(context);
      return;
    }
    Navigator.pushNamed(context, action.route);
  }

  void _showAllMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Semua Menu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text('Pilih fitur yang ingin dibuka', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _allActions.length,
                  itemBuilder: (context, index) {
                    final action = _allActions[index];
                    return FeatureTile(
                      icon: action.icon,
                      label: action.label,
                      colors: action.colors,
                      compact: true,
                      onTap: () {
                        Navigator.pop(context);
                        _openAction(context, action);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktop(context)) {
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
        return _DashboardTab(onRefresh: _refresh, onOpenAction: _openAction, onShowAll: _showAllMenu);
      case 1:
        return const ProductsScreen(embedded: true);
      case 2:
        return const TransactionsScreen(embedded: true);
      case 3:
        return const SettingsScreen(embedded: true);
      default:
        return _DashboardTab(onRefresh: _refresh, onOpenAction: _openAction, onShowAll: _showAllMenu);
    }
  }

  Widget _buildSideNav() {
    final items = [
      (Icons.dashboard_rounded, 'Beranda'),
      (Icons.inventory_2_rounded, 'Produk'),
      (Icons.receipt_long_rounded, 'Transaksi'),
      (Icons.settings_rounded, 'Lainnya'),
    ];

    return Container(
      width: 92,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppGradients.hero,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.soft,
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 26),
            for (var i = 0; i < items.length; i++) _buildSideNavItem(i, items[i].$1, items[i].$2),
            const Spacer(),
            PressableScale(
              onTap: () => Navigator.pushNamed(context, '/pos'),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  gradient: AppGradients.gold,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.gold,
                ),
                child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return PressableScale(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 66,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 21, color: isSelected ? AppColors.primary : AppColors.textMuted),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.lifted,
      ),
      child: SafeArea(
        top: false,
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
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: isSelected ? AppColors.primary : AppColors.textMuted),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavCenterButton() {
    return Expanded(
      child: PressableScale(
        onTap: () => Navigator.pushNamed(context, '/pos'),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 50,
          height: 50,
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            gradient: AppGradients.gold,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppShadows.gold,
          ),
          child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 23),
        ),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final void Function(BuildContext, _Action) onOpenAction;
  final void Function(BuildContext) onShowAll;

  const _DashboardTab({required this.onRefresh, required this.onOpenAction, required this.onShowAll});

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
    final firstName = (auth.user?.name ?? 'User').split(' ').first;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHero(context, firstName, todayTotal, todayCount, db, padding)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 18, padding, 0),
            sliver: SliverGrid.count(
              crossAxisCount: isDesktop ? 3 : 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: isDesktop ? 2.1 : 1.05,
              children: [
                _MiniStat(
                  title: 'Produk',
                  value: '$productCount',
                  icon: Icons.inventory_2_rounded,
                  color: AppColors.info,
                ),
                _MiniStat(
                  title: 'Stok Rendah',
                  value: '$lowStockCount',
                  icon: Icons.warning_amber_rounded,
                  color: lowStockCount > 0 ? AppColors.warning : AppColors.success,
                ),
                _MiniStat(
                  title: 'Transaksi',
                  value: '$todayCount',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 22, padding, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Menu Cepat',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onShowAll(context),
                    style: TextButton.styleFrom(foregroundColor: AppColors.secondaryDark),
                    child: const Text('Lihat semua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 6, padding, 8),
            sliver: SliverGrid.count(
              crossAxisCount: isDesktop ? 6 : 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: isDesktop ? 1.35 : 0.72,
              children: [
                for (final action in _primaryActions)
                  FeatureTile(
                    icon: action.icon,
                    label: action.label,
                    colors: action.colors,
                    compact: true,
                    onTap: () => onOpenAction(context, action),
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 18, padding, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Transaksi Terakhir',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/transactions'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.secondaryDark),
                    child: const Text('Lihat semua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
          if (db.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (db.transactions.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.fromLTRB(padding, 8, padding, 24),
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(height: 12),
                    const Text('Belum ada transaksi hari ini', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text(
                      'Mulai transaksi pertama Anda dari menu Kasir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, 8, padding, 28),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final t = db.transactions[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_upward_rounded, color: AppColors.success, size: 17),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.invoiceNumber ?? '#${t.id}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t.customerName ?? t.userName ?? 'Pelanggan Umum',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatCurrency(t.total),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: db.transactions.length > 10 ? 10 : db.transactions.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHero(
    BuildContext context,
    String firstName,
    num todayTotal,
    int todayCount,
    LocalDatabaseProvider db,
    double padding,
  ) {
    final now = DateTime.now();
    const dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(padding, 14, padding, 22),
      decoration: const BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'POSQUPRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        '${dayNames[now.weekday - 1]}, ${now.day} ${monthNames[now.month - 1]} ${now.year}',
                        style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: db.isConnected ? Colors.white.withValues(alpha: 0.14) : AppColors.danger.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        db.isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        db.isConnected ? 'Tersinkron' : 'Offline',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Selamat datang kembali,',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.72)),
            ),
            const SizedBox(height: 2),
            Text(
              firstName,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PENJUALAN HARI INI',
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.66),
                          ),
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatCurrency(todayTotal.toDouble()),
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$todayCount',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const Text(
                          'transaksi',
                          style: TextStyle(fontSize: 9, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
