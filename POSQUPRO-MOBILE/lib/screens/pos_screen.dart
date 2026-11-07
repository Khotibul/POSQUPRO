import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/theme.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/customer_provider.dart';
import '../models/customer.dart';
import '../models/product.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchController = TextEditingController();
  int? _selectedCategoryId;
  bool _restoredPark = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<ProductProvider>().loadProducts(refresh: true);
      context.read<ProductProvider>().loadCategories();
      context.read<CustomerProvider>().loadCustomers(refresh: true);
      await _maybeRestoreParked();
    });
  }

  Future<void> _maybeRestoreParked() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map || _restoredPark) return;
    _restoredPark = true;
    final items = (args['items'] as List?) ?? [];
    if (items.isEmpty) return;
    final products = context.read<ProductProvider>();
    final cart = context.read<CartProvider>();
    cart.clear();
    for (final raw in items) {
      if (raw is! Map) continue;
      final productId = raw['product_id'];
      Product? product;
      try {
        final api = ApiService();
        final pres = await api.get('/v1/products/$productId');
        if (pres['success'] == true && pres['data'] is Map) {
          product = Product.fromJson(Map<String, dynamic>.from(pres['data']));
        }
      } catch (_) {}
      product ??= products.products.where((p) => p.id == productId).firstOrNull;
      if (product == null) continue;
      cart.addItem(product);
      final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
      final price = (raw['unit_price'] as num?)?.toDouble() ?? product.sellingPrice;
      cart.updateQuantity(product.id, qty);
      cart.updatePrice(product.id, price);
      final disc = (raw['discount'] as num?)?.toDouble();
      if (disc != null && disc > 0) cart.updateDiscount(product.id, disc);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang dipulihkan dari transaksi tertahan'), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>();
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kasir', style: TextStyle(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (cart.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.pause_circle_outline_rounded, size: 22),
              tooltip: 'Tahan transaksi',
              onPressed: () => _parkCart(context),
            ),
          if (cart.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 22),
              onPressed: () => cart.clear(),
              tooltip: 'Kosongkan',
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => products.search(v),
              decoration: InputDecoration(
                hintText: 'Cari nama / SKU / barcode...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                _buildCategoryChip(null, 'Semua'),
                ...products.categories.map((c) => _buildCategoryChip(c.id, c.name)),
              ],
            ),
          ),
          Expanded(
            child: products.isLoading && products.products.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : products.products.isEmpty
                    ? const Center(child: Text('Produk tidak ditemukan', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: products.products.length,
                        itemBuilder: (context, index) {
                          final p = products.products[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySurface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: p.image != null && p.image!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(p.image!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 24)),
                                        )
                                      : const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text(formatCurrency(p.sellingPrice), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                      const SizedBox(height: 2),
                                      Text(p.type == 'service' ? 'Jasa' : 'Stok: ${p.stock}', style: TextStyle(fontSize: 11, color: p.isLowStock && p.type != 'service' ? AppColors.danger : AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: p.type == 'service' || p.stock > 0 ? () => _addToCart(context, p) : null,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: p.type == 'service' || p.stock > 0 ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          if (cart.items.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('Keranjang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(999)),
                        child: Text('${cart.itemCount} item', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _openCartEditor(context),
                        child: const Text('Edit', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...cart.items.take(3).map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(item.product.name, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            Text('x${item.quantity}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(width: 8),
                            Text(formatCurrency(item.total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                  if (cart.items.length > 3)
                    Text('+${cart.items.length - 3} item lainnya', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: cart.items.isEmpty
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${cart.itemCount} item', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(formatCurrency(cart.total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openCheckout(context),
                      icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 20),
                      label: const Text('Bayar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCategoryChip(int? categoryId, String label) {
    final isSelected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textSecondary)),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _selectedCategoryId = categoryId);
          context.read<ProductProvider>().filterByCategory(categoryId);
        },
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  void _addToCart(BuildContext context, Product product) {
    final cart = context.read<CartProvider>();
    if (product.type != 'service') {
      final existing = cart.items.where((i) => i.product.id == product.id).fold<int>(0, (s, i) => s + i.quantity);
      if (existing + 1 > product.stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stok ${product.name} tidak cukup'), backgroundColor: AppColors.danger),
        );
        return;
      }
    }
    cart.addItem(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} ditambahkan'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating),
    );
  }

  void _openCartEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CartEditorSheet(),
    );
  }

  void _openCheckout(BuildContext context) {
    final cart = context.read<CartProvider>();
    final customers = context.read<CustomerProvider>().customers;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CheckoutSheet(cart: cart, customers: customers),
    );
  }

  Future<void> _parkCart(BuildContext context) async {
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) return;
    final labelCtrl = TextEditingController(text: 'Keranjang ${DateTime.now().ddMMHHmm()}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tahan Transaksi'),
        content: TextField(
          controller: labelCtrl,
          decoration: const InputDecoration(labelText: 'Nama simpanan'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final api = ApiService();
      final body = {
        'items': cart.items
            .map((i) => {
                  'product_id': i.product.id,
                  'quantity': i.quantity,
                  'unit_price': i.unitPrice,
                  'discount': i.discount,
                })
            .toList(),
        'discount': cart.totalDiscount,
        'notes': labelCtrl.text.trim(),
      };
      final res = await api.post('/v1/parked-transactions', body: body);
      if (!context.mounted) return;
      if (res['success'] == true) {
        cart.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi ditahan'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal menahan transaksi'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }
}

extension on DateTime {
  String ddMMHHmm() => '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')} ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class _CartEditorSheet extends StatefulWidget {
  const _CartEditorSheet();

  @override
  State<_CartEditorSheet> createState() => _CartEditorSheetState();
}

class _CartEditorSheetState extends State<_CartEditorSheet> {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Edit Keranjang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close_rounded, size: 22), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: cart.items.length,
              itemBuilder: (context, index) {
                final item = cart.items[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                            onPressed: () {
                              cart.removeItem(item.product.id);
                              if (cart.items.isEmpty && mounted) Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => cart.updateQuantity(item.product.id, item.quantity - 1),
                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                          ),
                          SizedBox(
                            width: 48,
                            child: TextFormField(
                              initialValue: '${item.quantity}',
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                              onFieldSubmitted: (v) => cart.updateQuantity(item.product.id, int.tryParse(v) ?? 1),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (item.product.type != 'service' && item.quantity + 1 > item.product.stock) return;
                              cart.updateQuantity(item.product.id, item.quantity + 1);
                            },
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                          ),
                          const Spacer(),
                          const Text('Harga', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 110,
                            child: TextFormField(
                              initialValue: item.unitPrice.toStringAsFixed(0),
                              textAlign: TextAlign.right,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                prefixText: 'Rp ',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onFieldSubmitted: (v) => cart.updatePrice(item.product.id, double.tryParse(v) ?? item.unitPrice),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Diskon', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: item.discount.toStringAsFixed(0),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                prefixText: 'Rp ',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                              onFieldSubmitted: (v) => cart.updateDiscount(item.product.id, double.tryParse(v) ?? 0),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(formatCurrency(item.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        Text(formatCurrency(cart.total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Selesai'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  final CartProvider cart;
  final List<Customer> customers;

  const _CheckoutSheet({required this.cart, required this.customers});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  String _paymentMethod = 'cash';
  int? _selectedCustomerId;
  final _noteController = TextEditingController();
  final _paidController = TextEditingController();
  double _paid = 0;

  @override
  void initState() {
    super.initState();
    _paid = widget.cart.total;
    _paidController.text = widget.cart.total.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _paidController.dispose();
    super.dispose();
  }

  double get _change => (_paid - widget.cart.total).clamp(0, double.infinity);
  bool get _isCredit => _paymentMethod == 'credit';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Checkout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pelanggan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<int>(
                      value: _selectedCustomerId,
                      hint: const Text('Umum', style: TextStyle(fontSize: 13)),
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem<int>(value: null, child: Text('Umum')),
                        ...widget.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: (v) => setState(() => _selectedCustomerId = v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Metode Pembayaran', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPaymentChip('cash', 'Tunai', Icons.money_rounded),
                      const SizedBox(width: 8),
                      _buildPaymentChip('card', 'Kartu', Icons.credit_card_rounded),
                      const SizedBox(width: 8),
                      _buildPaymentChip('qris', 'QRIS', Icons.qr_code_rounded),
                      const SizedBox(width: 8),
                      _buildPaymentChip('transfer', 'Transfer', Icons.account_balance_rounded),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  if (!_isCredit) ...[
                    const Text('Uang Diterima', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _paidController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(prefixText: 'Rp ', hintText: 'Jumlah uang'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      onChanged: (v) => setState(() => _paid = double.tryParse(v) ?? 0),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _quickCash('Uang Pas', widget.cart.total),
                        _quickCash('10rb', 10000),
                        _quickCash('20rb', 20000),
                        _quickCash('50rb', 50000),
                        _quickCash('100rb', 100000),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kembalian', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        Text(formatCurrency(_change), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.success)),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildSummaryRow('Subtotal', formatCurrency(widget.cart.subtotal)),
                  _buildSummaryRow('Diskon', '-${formatCurrency(widget.cart.totalDiscount)}'),
                  const Divider(),
                  _buildSummaryRow('Total', formatCurrency(widget.cart.total), isBold: true),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _processPayment(context),
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: Text('Bayar ${formatCurrency(widget.cart.total)}'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickCash(String label, double amount) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        setState(() {
          _paid = amount;
          _paidController.text = amount.toStringAsFixed(0);
        });
      },
    );
  }

  Widget _buildPaymentChip(String value, String label, IconData icon) {
    final isSelected = _paymentMethod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.textMuted),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: isBold ? AppColors.textPrimary : AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: isBold ? 16 : 13, fontWeight: isBold ? FontWeight.w700 : FontWeight.w600, color: isBold ? AppColors.primary : AppColors.textPrimary)),
        ],
      ),
    );
  }

  Future<void> _processPayment(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final txProvider = context.read<TransactionProvider>();

    if (!_isCredit && _paid < widget.cart.total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah bayar kurang dari total'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final items = cart.items.map((item) => ({
      'product_id': item.product.id,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
      'discount': item.discount,
    })).toList();

    final tx = await txProvider.createTransaction(
      type: 'sell',
      customerId: _selectedCustomerId,
      items: items,
      discount: cart.totalDiscount,
      notes: _noteController.text.isNotEmpty ? _noteController.text : null,
      payment: {
        'method': _paymentMethod,
        'amount': _isCredit ? widget.cart.total : _paid,
      },
    );

    if (!context.mounted) return;
    Navigator.pop(context);

    if (tx != null) {
      final change = _isCredit ? 0.0 : _change;
      cart.clear();
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Transaksi Berhasil'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice: ${tx.invoiceNumber ?? '#${tx.id}'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Total: ${formatCurrency(tx.total)}'),
                if (change > 0) Text('Kembalian: ${formatCurrency(change)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaksi ${tx.invoiceNumber ?? "#${tx.id}"} berhasil'), backgroundColor: AppColors.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memproses transaksi'), backgroundColor: AppColors.danger),
      );
    }
  }
}
