import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().loadPublicSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan', style: TextStyle(fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primarySurface,
                    child:                     Text(user != null && user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'User', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text(user?.email ?? '-', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
                    child: Text(user?.role ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _Section(
              title: 'Toko',
              children: [
                _Tile(icon: Icons.store_rounded, title: 'Nama Toko', value: settings.getSetting('store.name', defaultValue: '-')),
                _Tile(icon: Icons.location_on_rounded, title: 'Alamat', value: settings.getSetting('store.address', defaultValue: '-')),
                _Tile(icon: Icons.phone_rounded, title: 'Telepon', value: settings.getSetting('store.phone', defaultValue: '-')),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Pajak',
              children: [
                _Tile(icon: Icons.receipt_rounded, title: 'Pajak Aktif', value: settings.getSetting('store.tax.enabled', defaultValue: 'false')),
                _Tile(icon: Icons.percent_rounded, title: 'Tarif Pajak', value: '${settings.getSetting('store.tax.rate', defaultValue: '0')}%'),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Printer',
              children: [
                _Tile(icon: Icons.print_rounded, title: 'Tipe Koneksi', value: settings.getSetting('printer.connection.type', defaultValue: '-')),
                _Tile(icon: Icons.bluetooth_rounded, title: 'Nama Printer', value: settings.getSetting('printer.name', defaultValue: '-')),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Navigasi',
              children: [
                _NavTile(icon: Icons.shopping_cart_rounded, title: 'Kasir', onTap: () => Navigator.pushNamed(context, '/pos')),
                _NavTile(icon: Icons.inventory_2_rounded, title: 'Produk', onTap: () => Navigator.pushNamed(context, '/products')),
                _NavTile(icon: Icons.people_rounded, title: 'Pelanggan', onTap: () => Navigator.pushNamed(context, '/customers')),
                _NavTile(icon: Icons.local_shipping_rounded, title: 'Supplier', onTap: () => Navigator.pushNamed(context, '/suppliers')),
                _NavTile(icon: Icons.assessment_rounded, title: 'Laporan', onTap: () => Navigator.pushNamed(context, '/reports')),
                _NavTile(icon: Icons.warehouse_rounded, title: 'Stok', onTap: () => Navigator.pushNamed(context, '/stock')),
                _NavTile(icon: Icons.receipt_long_rounded, title: 'Riwayat', onTap: () => Navigator.pushNamed(context, '/transactions')),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Keluar'),
                      content: const Text('Yakin ingin keluar?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Keluar', style: TextStyle(color: AppColors.danger))),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Keluar'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _Tile({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _NavTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
