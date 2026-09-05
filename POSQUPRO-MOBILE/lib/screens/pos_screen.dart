import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/customer_provider.dart';
import '../models/customer.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchController = TextEditingController();
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts(refresh: true);
      context.read<ProductProvider>().loadCategories();
      context.read<CustomerProvider>().loadCustomers(refresh: true);
    });
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
              icon: const Icon(Icons.refresh_rounded, size: 22),
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
                hintText: 'Cari produk...',
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
                                      Text('Stok: ${p.stock}', style: TextStyle(fontSize: 11, color: p.isLowStock ? AppColors.danger : AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: p.stock > 0 ? () => _addToCart(context, p) : null,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: p.stock > 0 ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
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

  void _addToCart(BuildContext context, product) {
    context.read<CartProvider>().addItem(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} ditambahkan'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating),
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

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  if (widget.customers.isNotEmpty) ...[
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
                  ],
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
                    decoration: const InputDecoration(hintText: 'Catatan (opsional)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow('Subtotal', formatCurrency(widget.cart.subtotal)),
                  _buildSummaryRow('Diskon', '-${formatCurrency(widget.cart.totalDiscount)}'),
                  const Divider(),
                  _buildSummaryRow('Total', formatCurrency(widget.cart.total), isBold: true),
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
        'amount': cart.total,
      },
    );

    if (!context.mounted) return;
    Navigator.pop(context);

    if (tx != null) {
      cart.clear();
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
