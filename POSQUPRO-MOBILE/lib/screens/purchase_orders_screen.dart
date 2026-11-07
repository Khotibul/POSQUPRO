import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/theme.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final _api = ApiService();
  bool _loading = false;
  List _items = [];
  List _suppliers = [];
  List _products = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadMaster();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/v1/purchase-orders');
      setState(() {
        _items = res['data'] is List ? res['data'] : (res['data']?['data'] ?? []);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMaster() async {
    try {
      final results = await Future.wait([
        _api.get('/v1/suppliers'),
        _api.get('/v1/products', queryParams: {'per_page': '100'}),
      ]);
      setState(() {
        _suppliers = _extract(results[0]);
        _products = _extract(results[1]);
      });
    } catch (_) {}
  }

  List _extract(dynamic res) {
    if (res is! Map || res['success'] != true) return [];
    final data = res['data'];
    return data is List ? data : (data?['data'] ?? []);
  }

  String _statusLabel(String? s) => switch (s) {
        'draft' => 'Draft',
        'ordered' => 'Dipesan',
        'partial' => 'Sebagian',
        'received' => 'Diterima',
        'cancelled' => 'Dibatalkan',
        _ => s ?? '-',
      };

  Color _statusColor(String? s) => switch (s) {
        'draft' => AppColors.textMuted,
        'ordered' => AppColors.primary,
        'partial' => AppColors.warning,
        'received' => AppColors.success,
        _ => AppColors.danger,
      };

  Future<void> _create() async {
    if (_suppliers.isEmpty || _products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data supplier/produk belum dimuat'), backgroundColor: AppColors.danger),
      );
      return;
    }

    int? supplierId;
    final items = <_PoItemLine>[];
    final notes = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Buat Purchase Order'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: supplierId,
                    decoration: const InputDecoration(labelText: 'Supplier *'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('- Pilih -')),
                      ..._suppliers.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text('${s['name']}', style: const TextStyle(fontSize: 13)))),
                    ],
                    onChanged: (v) => setDialogState(() => supplierId = v),
                  ),
                  const SizedBox(height: 12),
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final line = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: line.productId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Produk', isDense: true),
                              items: [
                                const DropdownMenuItem<int>(value: null, child: Text('- Pilih -')),
                                ..._products.map((p) => DropdownMenuItem(value: p['id'] as int, child: Text('${p['name']}', style: const TextStyle(fontSize: 12)))),
                              ],
                              onChanged: (v) => setDialogState(() => line.productId = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              initialValue: '${line.quantity}',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                              onChanged: (v) => line.quantity = int.tryParse(v) ?? 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 90,
                            child: TextFormField(
                              initialValue: line.unitCost.toStringAsFixed(0),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Harga', isDense: true, prefixText: 'Rp '),
                              onChanged: (v) => line.unitCost = double.tryParse(v) ?? 0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                            onPressed: () => setDialogState(() => items.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () => setDialogState(() => items.add(_PoItemLine())),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Tambah Item', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: notes, decoration: const InputDecoration(labelText: 'Catatan'), maxLines: 2),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final validItems = items
        .where((l) => l.productId != null && l.quantity > 0)
        .map((l) => {
              'product_id': l.productId,
              'quantity': l.quantity,
              'unit_cost': l.unitCost,
            })
        .toList();

    if (supplierId == null || validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier dan minimal 1 item wajib diisi'), backgroundColor: AppColors.danger),
      );
      return;
    }

    try {
      final res = await _api.post('/v1/purchase-orders', body: {
        'supplier_id': supplierId,
        'items': validItems,
        if (notes.text.isNotEmpty) 'notes': notes.text.trim(),
      });
      if (!mounted) return;
      if (res['success'] == true) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PO dibuat'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal membuat PO'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _receive(Map po) async {
    final detailRes = await _api.get('/v1/purchase-orders/${po['id']}');
    if (!mounted) return;
    if (detailRes['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detailRes['message'] ?? 'Gagal memuat detail PO'), backgroundColor: AppColors.danger),
      );
      return;
    }
    final detail = detailRes['data'];
    final lines = <Map>[];
    final received = <int, int>{};
    void collect(List? items) {
      if (items == null) return;
      for (final raw in items) {
        final m = Map<String, dynamic>.from(raw as Map);
        lines.add(m);
        received[m['id']] = (m['received_quantity'] as num?)?.toInt() ?? 0;
      }
    }

    collect(detail['items'] is List ? detail['items'] as List : null);
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PO tidak memiliki item'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final amounts = <int, int>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Terima PO ${po['po_number'] ?? ''}'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...lines.map((line) {
                    final id = line['id'] as int;
                    final ordered = (line['quantity'] as num?)?.toInt() ?? 0;
                    final recv = received[id] ?? 0;
                    final remaining = (ordered - recv).clamp(0, ordered);
                    amounts.putIfAbsent(id, () => remaining);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${line['product']?['name'] ?? 'Item #$id'}',
                              style: const TextStyle(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('$recv/$ordered', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 70,
                            child: TextFormField(
                              initialValue: '${amounts[id]}',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Diterima', isDense: true),
                              onChanged: (v) => amounts[id] = (int.tryParse(v) ?? 0).clamp(0, remaining),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Terima')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final body = amounts.entries
        .where((e) => e.value > 0)
        .map((e) => {'purchase_order_item_id': e.key, 'quantity': e.value})
        .toList();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada jumlah diterima'), backgroundColor: AppColors.danger),
      );
      return;
    }

    try {
      final res = await _api.post('/v1/purchase-orders/${po['id']}/receive', body: {'items': body});
      if (!mounted) return;
      if (res['success'] == true) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PO diterima'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal menerima PO'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _delete(Map po) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus PO'),
        content: Text('Hapus ${po['po_number'] ?? '#${po['id']}'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.delete('/v1/purchase-orders/${po['id']}');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Purchase Order', style: TextStyle(fontSize: 18)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, size: 22), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat PO'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            ..._items.map((raw) {
              final p = Map<String, dynamic>.from(raw as Map);
              final status = p['status']?.toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(p['po_number'] ?? '#${p['id']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                        child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor(status))),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Supplier #${p['supplier_id'] ?? '-'} · ${p['total_amount'] ?? 0}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status == 'ordered' || status == 'partial' || status == 'draft')
                        IconButton(
                          icon: const Icon(Icons.download_rounded, size: 20, color: AppColors.success),
                          tooltip: 'Terima',
                          onPressed: () => _receive(p),
                        ),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'receive') _receive(p);
                          if (v == 'delete') _delete(p);
                        },
                        itemBuilder: (_) => [
                          if (status == 'ordered' || status == 'partial' || status == 'draft')
                            const PopupMenuItem(value: 'receive', child: Text('Terima Barang')),
                          if (status == 'draft' || status == 'cancelled')
                            const PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: AppColors.danger))),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (!_loading && _items.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Belum ada PO'))),
            const SizedBox(height: 72),
          ],
        ),
      ),
    );
  }
}

class _PoItemLine {
  int? productId;
  int quantity = 1;
  double unitCost = 0;
}
