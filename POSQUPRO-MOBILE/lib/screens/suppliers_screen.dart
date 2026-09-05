import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/supplier_provider.dart';
import '../models/supplier.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierProvider>().loadSuppliers(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupplierProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Supplier', style: TextStyle(fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded, size: 22), onPressed: () => _openForm(context, null)),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => provider.search(v),
              decoration: InputDecoration(
                hintText: 'Cari supplier...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: AppColors.surface,
              ),
            ),
          ),
          Expanded(
            child: provider.isLoading && provider.suppliers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.suppliers.isEmpty
                    ? const Center(child: Text('Belum ada supplier', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.suppliers.length,
                        itemBuilder: (context, index) => _buildCard(context, provider.suppliers[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Supplier s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.secondaryLight,
            child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.secondary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (s.contactPerson != null) Text(s.contactPerson!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (s.phone != null) Text(s.phone!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Edit')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 16, color: AppColors.danger), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: AppColors.danger))])),
            ],
            onSelected: (v) {
              if (v == 'edit') _openForm(context, s);
              if (v == 'delete') _confirmDelete(context, s);
            },
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, Supplier? supplier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplierFormSheet(supplier: supplier),
    );
  }

  void _confirmDelete(BuildContext context, Supplier s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Supplier'),
        content: Text('Hapus "${s.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(onPressed: () async { Navigator.pop(context); await context.read<SupplierProvider>().deleteSupplier(s.id); }, child: const Text('Hapus', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
  }
}

class _SupplierFormSheet extends StatefulWidget {
  final Supplier? supplier;
  const _SupplierFormSheet({this.supplier});

  @override
  State<_SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends State<_SupplierFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.supplier?.name ?? '');
    _contactCtrl = TextEditingController(text: widget.supplier?.contactPerson ?? '');
    _phoneCtrl = TextEditingController(text: widget.supplier?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.supplier?.email ?? '');
    _addressCtrl = TextEditingController(text: widget.supplier?.address ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.supplier != null;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(isEdit ? 'Edit Supplier' : 'Tambah Supplier', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
                  children: [
                    TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nama *'), validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _contactCtrl, decoration: const InputDecoration(labelText: 'Contact Person')),
                    const SizedBox(height: 12),
                    TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Telepon'), keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    TextFormField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Alamat'), maxLines: 2),
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
                child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isEdit ? 'Simpan' : 'Tambah'),
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

    final data = {
      'name': _nameCtrl.text,
      'contact_person': _contactCtrl.text.isNotEmpty ? _contactCtrl.text : null,
      'phone': _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : null,
      'email': _emailCtrl.text.isNotEmpty ? _emailCtrl.text : null,
      'address': _addressCtrl.text.isNotEmpty ? _addressCtrl.text : null,
    };

    final provider = context.read<SupplierProvider>();
    final result = widget.supplier != null
        ? await provider.updateSupplier(widget.supplier!.id, data)
        : await provider.createSupplier(data);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.supplier != null ? 'Supplier diperbarui' : 'Supplier ditambahkan')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error ?? 'Gagal menyimpan'), backgroundColor: AppColors.danger));
    }
  }
}
