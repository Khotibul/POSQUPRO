import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';

class ProductsScreen extends StatefulWidget {
  final bool embedded;
  const ProductsScreen({super.key, this.embedded = false});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts(refresh: true);
      context.read<ProductProvider>().loadCategories();
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Produk', style: TextStyle(fontSize: 18)),
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 22),
            onPressed: () => _openProductForm(context, null),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                _buildCategoryChip(context, null, 'Semua'),
                ...products.categories.map((c) => _buildCategoryChip(context, c.id, c.name)),
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
                        itemBuilder: (context, index) => _buildProductCard(context, products.products[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context, int? categoryId, String label) {
    final isSelected = context.read<ProductProvider>().selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textSecondary)),
        selected: isSelected,
        onSelected: (_) => context.read<ProductProvider>().filterByCategory(categoryId),
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

  Widget _buildProductCard(BuildContext context, Product p) {
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(10)),
            child: p.image != null && p.image!.isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(p.image!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 24)))
                : const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (p.isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(4)),
                        child: const Text('Stok Rendah', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.danger)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(formatCurrency(p.sellingPrice), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const SizedBox(width: 8),
                    Text('Stok: ${p.stock}', style: TextStyle(fontSize: 12, color: p.isLowStock ? AppColors.danger : AppColors.textMuted)),
                  ],
                ),
                if (p.categoryName != null) ...[
                  const SizedBox(height: 2),
                  Text(p.categoryName!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
          PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Edit')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 16, color: AppColors.danger), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: AppColors.danger))])),
            ],
            onSelected: (v) {
              if (v == 'edit') _openProductForm(context, p);
              if (v == 'delete') _confirmDelete(context, p);
            },
            icon: const Icon(Icons.more_vert_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  void _openProductForm(BuildContext context, Product? product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductFormSheet(product: product),
    );
  }

  void _confirmDelete(BuildContext context, Product p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text('Hapus "${p.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final api = ApiService();
              final res = await api.delete('${ApiConstants.products}/${p.id}');
              if (res['success'] == true && context.mounted) {
                context.read<ProductProvider>().loadProducts(refresh: true);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk dihapus')));
              }
            },
            child: const Text('Hapus', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _ProductFormSheet extends StatefulWidget {
  final Product? product;
  const _ProductFormSheet({this.product});

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _minStockCtrl;
  late final TextEditingController _descCtrl;
  int? _categoryId;
  int? _unitQuantityId;
  int? _taxId;
  int? _supplierId;
  String _type = 'finished_goods';
  bool _isActive = true;
  bool _isSaving = false;
  final _picker = ImagePicker();
  String? _photoUrl;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?.name ?? '');
    _skuCtrl = TextEditingController(text: widget.product?.sku ?? '');
    _barcodeCtrl = TextEditingController(text: widget.product?.barcode ?? '');
    _priceCtrl = TextEditingController(text: widget.product?.sellingPrice.toString() ?? '');
    _costCtrl = TextEditingController(text: widget.product?.costPrice.toString() ?? '');
    _stockCtrl = TextEditingController(text: widget.product?.stock.toString() ?? '0');
    _minStockCtrl = TextEditingController(text: widget.product?.minStock.toString() ?? '0');
    _descCtrl = TextEditingController(text: widget.product?.description ?? '');
    _categoryId = widget.product?.categoryId;
    _unitQuantityId = widget.product?.unitQuantityId;
    _taxId = widget.product?.taxId;
    _supplierId = widget.product?.supplierId;
    _type = widget.product?.type ?? 'finished_goods';
    _isActive = widget.product?.isActive ?? true;
    _photoUrl = widget.product?.image;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProductProvider>().loadMasterData();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _minStockCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final categories = provider.categories;
    final units = provider.units;
    final taxes = provider.taxes;
    final suppliers = provider.suppliers;
    final isEdit = widget.product != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(isEdit ? 'Edit Produk' : 'Tambah Produk', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close_rounded, size: 22), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nama Produk *'),
                      validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _skuCtrl,
                            decoration: const InputDecoration(labelText: 'SKU'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _barcodeCtrl,
                            decoration: const InputDecoration(labelText: 'Barcode'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Tipe *'),
                      items: const [
                        DropdownMenuItem(value: 'finished_goods', child: Text('Barang Jadi')),
                        DropdownMenuItem(value: 'raw_material', child: Text('Bahan Baku')),
                        DropdownMenuItem(value: 'service', child: Text('Jasa')),
                      ],
                      onChanged: (v) => setState(() => _type = v ?? 'finished_goods'),
                    ),
                    const SizedBox(height: 12),
                    if (categories.isNotEmpty) ...[
                      DropdownButtonFormField<int>(
                        initialValue: _categoryId,
                        decoration: const InputDecoration(labelText: 'Kategori'),
                        items: [
                          const DropdownMenuItem<int>(value: null, child: Text('- Tanpa kategori -')),
                          ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (units.isNotEmpty) ...[
                      DropdownButtonFormField<int>(
                        initialValue: _unitQuantityId,
                        decoration: const InputDecoration(labelText: 'Satuan'),
                        items: [
                          const DropdownMenuItem<int>(value: null, child: Text('- Pilih satuan -')),
                          ...units.map((u) => DropdownMenuItem(value: u['id'] as int, child: Text('${u['name']}'))),
                        ],
                        onChanged: (v) => setState(() => _unitQuantityId = v),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (taxes.isNotEmpty) ...[
                      DropdownButtonFormField<int>(
                        initialValue: _taxId,
                        decoration: const InputDecoration(labelText: 'Pajak'),
                        items: [
                          const DropdownMenuItem<int>(value: null, child: Text('- Tanpa pajak -')),
                          ...taxes.map((t) => DropdownMenuItem(value: t['id'] as int, child: Text('${t['name']} (${t['rate'] ?? 0}%)'))),
                        ],
                        onChanged: (v) => setState(() => _taxId = v),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (suppliers.isNotEmpty) ...[
                      DropdownButtonFormField<int>(
                        initialValue: _supplierId,
                        decoration: const InputDecoration(labelText: 'Supplier'),
                        items: [
                          const DropdownMenuItem<int>(value: null, child: Text('- Pilih supplier -')),
                          ...suppliers.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text('${s['name']}'))),
                        ],
                        onChanged: (v) => setState(() => _supplierId = v),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceCtrl,
                            decoration: const InputDecoration(labelText: 'Harga Jual *', prefixText: 'Rp '),
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _costCtrl,
                            decoration: const InputDecoration(labelText: 'Harga Beli *', prefixText: 'Rp '),
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stockCtrl,
                            decoration: const InputDecoration(labelText: 'Stok *'),
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _minStockCtrl,
                            decoration: const InputDecoration(labelText: 'Stok Minimum'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(labelText: 'Deskripsi'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    if (isEdit) ...[
                      const Text('Foto Produk', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: _photoUrl != null && _photoUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      _photoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: AppColors.primary, size: 24),
                                    ),
                                  )
                                : const Icon(Icons.photo_camera_outlined, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _photoBusy ? null : _pickPhoto,
                                  icon: const Icon(Icons.photo_library_rounded, size: 16),
                                  label: const Text('Pilih Foto', style: TextStyle(fontSize: 12)),
                                ),
                                const SizedBox(height: 6),
                                OutlinedButton.icon(
                                  onPressed: _photoBusy || _photoUrl == null || _photoUrl!.isEmpty
                                      ? null
                                      : _generateLabelPhoto,
                                  icon: const Icon(Icons.text_fields_rounded, size: 16),
                                  label: const Text('Generate Berteks', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_photoBusy) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(minHeight: 3),
                      ],
                      const SizedBox(height: 12),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Produk Aktif', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Nonaktifkan agar tidak muncul di kasir', style: TextStyle(fontSize: 11)),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Simpan' : 'Tambah'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final api = ApiService();
    final body = <String, dynamic>{
      'name': _nameCtrl.text,
      'sku': _skuCtrl.text.isNotEmpty ? _skuCtrl.text : null,
      'barcode': _barcodeCtrl.text.isNotEmpty ? _barcodeCtrl.text : null,
      'type': _type,
      'selling_price': double.tryParse(_priceCtrl.text) ?? 0,
      'cost_price': double.tryParse(_costCtrl.text) ?? 0,
      'stock': int.tryParse(_stockCtrl.text) ?? 0,
      'min_stock': int.tryParse(_minStockCtrl.text) ?? 0,
      'category_id': _categoryId,
      'unit_quantity_id': _unitQuantityId,
      'tax_id': _taxId,
      'supplier_id': _supplierId,
      'description': _descCtrl.text.isNotEmpty ? _descCtrl.text : null,
      'is_active': _isActive,
    };

    final isEdit = widget.product != null;
    final res = isEdit
        ? await api.put('${ApiConstants.products}/${widget.product!.id}', body: body)
        : await api.post(ApiConstants.products, body: body);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res['success'] == true) {
      Navigator.pop(context);
      if (mounted) {
        context.read<ProductProvider>().loadProducts(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Produk diperbarui' : 'Produk ditambahkan')));
      }
    } else {
      final errors = res['errors'];
      String msg = res['message'] ?? 'Gagal menyimpan';
      if (errors is Map && errors.isNotEmpty) {
        msg = errors.values.expand((v) => v is List ? v : [v]).join('\n');
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, size: 20),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, size: 20),
              title: const Text('Ambil dengan Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
      if (picked == null) return;
      await _uploadPhoto(picked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih foto: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _uploadPhoto(XFile file) async {
    setState(() => _photoBusy = true);

    final api = ApiService();
    final res = await api.postMultipart(
      '${ApiConstants.products}/${widget.product!.id}/photo',
      fileField: 'photo',
      filePath: file.path,
    );

    if (!mounted) return;
    setState(() => _photoBusy = false);

    if (res['success'] == true) {
      final data = res['data'];
      final product = data is Map ? data['data'] : null;
      setState(() => _photoUrl = product is Map ? (product['image'] ?? product['photo']) : _photoUrl);
      if (mounted) {
        context.read<ProductProvider>().loadProducts(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto produk diupload')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Gagal upload foto'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _generateLabelPhoto() async {
    setState(() => _photoBusy = true);

    final api = ApiService();
    final res = await api.post('${ApiConstants.products}/${widget.product!.id}/generate-label');

    if (!mounted) return;
    setState(() => _photoBusy = false);

    if (res['success'] == true) {
      final data = res['data'];
      final product = data is Map ? data['data'] : null;
      setState(() => _photoUrl = product is Map ? (product['image'] ?? _photoUrl) : _photoUrl);
      if (mounted) {
        context.read<ProductProvider>().loadProducts(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto berteks berhasil digenerate')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Gagal generate foto'), backgroundColor: AppColors.danger),
      );
    }
  }
}
