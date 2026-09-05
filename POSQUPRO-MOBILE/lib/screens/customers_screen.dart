import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/customer_provider.dart';
import '../models/customer.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    final provider = context.watch<CustomerProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pelanggan', style: TextStyle(fontSize: 18)),
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
                hintText: 'Cari pelanggan...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: AppColors.surface,
              ),
            ),
          ),
          Expanded(
            child: provider.isLoading && provider.customers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.customers.isEmpty
                    ? const Center(child: Text('Belum ada pelanggan', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.customers.length,
                        itemBuilder: (context, index) => _buildCard(context, provider.customers[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Customer c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primarySurface,
            child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (c.phone != null && c.phone!.isNotEmpty) Text(c.phone!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (c.email != null && c.email!.isNotEmpty) Text(c.email!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Edit')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 16, color: AppColors.danger), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: AppColors.danger))])),
            ],
            onSelected: (v) {
              if (v == 'edit') _openForm(context, c);
              if (v == 'delete') _confirmDelete(context, c);
            },
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, Customer? customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerFormSheet(customer: customer),
    );
  }

  void _confirmDelete(BuildContext context, Customer c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Pelanggan'),
        content: Text('Hapus "${c.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<CustomerProvider>().deleteCustomer(c.id);
            },
            child: const Text('Hapus', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _CustomerFormSheet extends StatefulWidget {
  final Customer? customer;
  const _CustomerFormSheet({this.customer});

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.customer?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.customer?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.customer?.email ?? '');
    _addressCtrl = TextEditingController(text: widget.customer?.address ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(isEdit ? 'Edit Pelanggan' : 'Tambah Pelanggan', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
      'phone': _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : null,
      'email': _emailCtrl.text.isNotEmpty ? _emailCtrl.text : null,
      'address': _addressCtrl.text.isNotEmpty ? _addressCtrl.text : null,
    };

    final provider = context.read<CustomerProvider>();
    final result = widget.customer != null
        ? await provider.updateCustomer(widget.customer!.id, data)
        : await provider.createCustomer(data);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.customer != null ? 'Pelanggan diperbarui' : 'Pelanggan ditambahkan')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error ?? 'Gagal menyimpan'), backgroundColor: AppColors.danger));
    }
  }
}
