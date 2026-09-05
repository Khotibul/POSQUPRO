import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../models/paginated_response.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<Product> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _products = [];
    }
    if (!_hasMore || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      final params = <String, String>{
        'page': _currentPage.toString(),
        'per_page': '50',
      };
      if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;

      final res = await api.get(ApiConstants.products, queryParams: params);
      if (res['success'] == true) {
        final parsed = PaginatedResponse.fromJson(res['data'], (json) => Product.fromJson(json));
        setState(() {
          if (refresh) {
            _products = parsed.data;
          } else {
            _products.addAll(parsed.data);
          }
          _hasMore = parsed.hasMorePages;
          _currentPage++;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal memuat data stok')));
    }

    setState(() => _isLoading = false);
  }

  Future<void> _adjustStock(Product product, int adjustment, String type) async {
    try {
      final api = ApiService();
      final res = await api.post(ApiConstants.inventoryHistories, body: {
        'product_id': product.id,
        'type': type,
        'quantity': adjustment,
        'notes': 'Adjustment dari mobile',
      });

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stok ${product.name} diperbarui')));
        _loadProducts(refresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Gagal'), backgroundColor: AppColors.danger));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengubah stok'), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manajemen Stok', style: TextStyle(fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: TextField(
              onChanged: (v) {
                _searchQuery = v;
                _loadProducts(refresh: true);
              },
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: AppColors.surface,
              ),
            ),
          ),
          Expanded(
            child: _isLoading && _products.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('Tidak ada data', style: TextStyle(color: AppColors.textMuted)))
                    : RefreshIndicator(
                        onRefresh: () => _loadProducts(refresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _products.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _products.length) {
                              _loadProducts();
                              return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                            }
                            final p = _products[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            _StockBadge(label: 'Stok', value: '${p.stock}', color: p.isLowStock ? AppColors.danger : AppColors.success),
                                            const SizedBox(width: 8),
                                            _StockBadge(label: 'Min', value: '${p.minStock}', color: AppColors.textMuted),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      _StockButton(icon: Icons.remove_rounded, color: AppColors.danger, onTap: () => _showAdjustDialog(product: p, type: 'out')),
                                      const SizedBox(width: 6),
                                      _StockButton(icon: Icons.add_rounded, color: AppColors.success, onTap: () => _showAdjustDialog(product: p, type: 'in')),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showAdjustDialog({required Product product, required String type}) {
    final controller = TextEditingController();
    final isAdjustIn = type == 'in';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isAdjustIn ? 'Tambah Stok' : 'Kurangi Stok'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jumlah'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(controller.text) ?? 0;
              if (qty > 0) {
                Navigator.pop(context);
                _adjustStock(product, qty, type);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StockBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text('$label: $value', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _StockButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StockButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
