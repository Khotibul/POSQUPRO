import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/theme.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final _api = ApiService();
  bool _loading = false;
  List _items = [];
  List _tenants = [];
  List _plans = [];
  String? _statusFilter;
  int _page = 1;
  bool _hasMore = true;

  static const _statuses = ['pending', 'paid'];

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
    _loadMasters();
  }

  Future<void> _loadMasters() async {
    try {
      final results = await Future.wait([
        _api.get('/v1/tenants', queryParams: {'per_page': '100'}),
        _api.get('/v1/plans'),
      ]);
      setState(() {
        _tenants = _extract(results[0]);
        _plans = results[1]['success'] == true && results[1]['data'] is List
            ? results[1]['data']
            : [];
      });
    } catch (_) {}
  }

  List _extract(dynamic res) {
    if (res is! Map || res['success'] != true) return [];
    final data = res['data'];
    return data is List ? data : (data?['data'] ?? []);
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }
    if (!_hasMore && !refresh) return;
    setState(() => _loading = true);
    try {
      final res = await _api.get('/v1/invoices', queryParams: {
        'page': '$_page',
        if (_statusFilter != null) 'status': _statusFilter!,
      });
      if (res['success'] == true) {
        final data = res['data'];
        final list = data is List ? data : (data?['data'] ?? []);
        setState(() {
          if (refresh) {
            _items = list;
          } else {
            _items = [..._items, ...list];
          }
          final meta = data is Map ? (data['meta']?['last_page'] ?? data['last_page']) : null;
          if (meta != null) {
            _hasMore = _page < (meta as num).toInt();
          } else {
            _hasMore = list.length >= 15;
          }
          _page++;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal memuat invoice'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _statusLabel(String? s) => switch (s) {
        'pending' => 'Menunggu',
        'paid' => 'Lunas',
        _ => s ?? '-',
      };

  Color _statusColor(String? s) => switch (s) {
        'paid' => AppColors.success,
        'pending' => AppColors.warning,
        _ => AppColors.textMuted,
      };

  bool _isOverdue(Map i) {
    if (i['status'] != 'pending') return false;
    final due = i['due_at'];
    if (due is! String || due.isEmpty) return false;
    final parsed = DateTime.tryParse(due);
    return parsed != null && parsed.isBefore(DateTime.now());
  }

  Future<void> _create() async {
    if (_tenants.isEmpty || _plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data tenant/paket belum dimuat'), backgroundColor: AppColors.danger),
      );
      return;
    }
    int? tenantId;
    int? planId;
    final amount = TextEditingController();
    final notes = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Buat Invoice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: tenantId,
                  decoration: const InputDecoration(labelText: 'Tenant *'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('- Pilih -')),
                    ..._tenants.map((t) => DropdownMenuItem(value: t['id'] as int, child: Text('${t['name']}', style: const TextStyle(fontSize: 13)))),
                  ],
                  onChanged: (v) => setDialogState(() => tenantId = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: planId,
                  decoration: const InputDecoration(labelText: 'Paket *'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('- Pilih -')),
                    ..._plans.map((p) => DropdownMenuItem(value: p['id'] as int, child: Text('${p['name']}', style: const TextStyle(fontSize: 13)))),
                  ],
                  onChanged: (v) {
                    setDialogState(() {
                      planId = v;
                      final plan = _plans.firstWhere((p) => p['id'] == v, orElse: () => {});
                      if (plan is Map && plan['price'] != null && amount.text.isEmpty) {
                        amount.text = '${plan['price']}';
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Jumlah (kosongkan = harga paket)', prefixText: 'Rp '),
                ),
                const SizedBox(height: 8),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'Catatan'), maxLines: 2),
              ],
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

    if (tenantId == null || planId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenant dan paket wajib dipilih'), backgroundColor: AppColors.danger),
      );
      return;
    }

    try {
      final res = await _api.post('/v1/invoices', body: {
        'tenant_id': tenantId,
        'plan_id': planId,
        if (amount.text.isNotEmpty) 'amount': double.tryParse(amount.text),
        if (notes.text.isNotEmpty) 'notes': notes.text.trim(),
      });
      if (!mounted) return;
      if (res['success'] == true) {
        _load(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice dibuat'), backgroundColor: AppColors.success),
        );
      } else {
        final errors = res['errors'];
        String msg = res['message'] ?? 'Gagal membuat invoice';
        if (errors is Map && errors.isNotEmpty) {
          msg = errors.values.expand((v) => v is List ? v : [v]).join('\n');
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _markPaid(Map i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tandai Lunas'),
        content: Text('Tandai invoice ${i['invoice_number'] ?? '#${i['id']}'} sebagai lunas?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lunas')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final res = await _api.post('/v1/invoices/${i['id']}/pay');
      if (!mounted) return;
      if (res['success'] == true) {
        _load(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice ditandai lunas'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _delete(Map i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Invoice'),
        content: Text('Hapus ${i['invoice_number'] ?? i['id']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.delete('/v1/invoices/${i['id']}');
      _load(refresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingTotal = _items
        .where((i) => i['status'] == 'pending')
        .fold(0.0, (s, i) => s + ((i['total'] as num?) ?? 0).toDouble());
    final paidTotal = _items
        .where((i) => i['status'] == 'paid')
        .fold(0.0, (s, i) => s + ((i['total'] as num?) ?? 0).toDouble());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invoice', style: TextStyle(fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, size: 22), onPressed: () => _load(refresh: true))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat'),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Belum Dibayar', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      Text(formatCurrency(pendingTotal), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.warning)),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: AppColors.border),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Terkumpul', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      Text(formatCurrency(paidTotal), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.success)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              children: [
                _filterChip(null, 'Semua'),
                ..._statuses.map((s) => _filterChip(s, _statusLabel(s))),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: _loading && _items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: _items.length + (_hasMore && _items.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _items.length) {
                          _load();
                          return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)));
                        }
                        final i = Map<String, dynamic>.from(_items[index] as Map);
                        final status = i['status']?.toString();
                        final overdue = _isOverdue(i);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: overdue ? AppColors.danger : AppColors.border),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(i['invoice_number'] ?? '#${i['id']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (overdue ? AppColors.danger : _statusColor(status)).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    overdue ? 'Jatuh Tempo' : _statusLabel(status),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: overdue ? AppColors.danger : _statusColor(status)),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              '${i['tenant']?['name'] ?? '-'} · ${i['plan']?['name'] ?? '-'} · jatuh tempo ${_fmtDate(i['due_at'])}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatCurrency(((i['total'] as num?) ?? 0).toDouble()),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (v) {
                                    switch (v) {
                                      case 'pay':
                                        _markPaid(i);
                                      case 'delete':
                                        _delete(i);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    if (status != 'paid')
                                      const PopupMenuItem(value: 'pay', child: Text('Tandai Lunas')),
                                    const PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: AppColors.danger))),
                                  ],
                                ),
                              ],
                            ),
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

  String _fmtDate(dynamic v) {
    if (v is! String || v.isEmpty) return '-';
    final d = DateTime.tryParse(v);
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _filterChip(String? value, String label) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textSecondary)),
        selected: isSelected,
        onSelected: (_) => setState(() => _statusFilter = value),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
