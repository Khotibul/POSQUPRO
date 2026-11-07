import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/theme.dart';

class StockCountsScreen extends StatefulWidget {
  const StockCountsScreen({super.key});

  @override
  State<StockCountsScreen> createState() => _StockCountsScreenState();
}

class _StockCountsScreenState extends State<StockCountsScreen> {
  final _api = ApiService();
  bool _loading = false;
  List _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/v1/stock-counts');
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

  String _statusLabel(String? s) => switch (s) {
        'draft' => 'Draft',
        'counting' => 'Menghitung',
        'pending_approval' => 'Menunggu',
        'approved' => 'Disetujui',
        'posted' => 'Diposting',
        'cancelled' => 'Dibatalkan',
        _ => s ?? '-',
      };

  Color _statusColor(String? s) => switch (s) {
        'draft' => AppColors.textMuted,
        'counting' => AppColors.warning,
        'pending_approval' => AppColors.secondary,
        'approved' => AppColors.primary,
        'posted' => AppColors.success,
        _ => AppColors.danger,
      };

  Future<void> _create() async {
    bool isBlind = false;
    final notes = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Buat Stock Count'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Blind Count', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Sembunyikan stok sistem saat menghitung', style: TextStyle(fontSize: 11)),
                value: isBlind,
                onChanged: (v) => setDialogState(() => isBlind = v),
              ),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Catatan'), maxLines: 2),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final res = await _api.post('/v1/stock-counts', body: {
        'is_blind': isBlind,
        if (notes.text.isNotEmpty) 'notes': notes.text.trim(),
      });
      if (!mounted) return;
      if (res['success'] == true) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock count dibuat'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal membuat'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _start(Map sc) async {
    try {
      final res = await _api.post('/v1/stock-counts/${sc['id']}/start');
      if (!mounted) return;
      if (res['success'] == true) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Penghitungan dimulai'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal memulai'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _record(Map sc) async {
    final detailRes = await _api.get('/v1/stock-counts/${sc['id']}');
    if (!mounted) return;
    if (detailRes['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detailRes['message'] ?? 'Gagal memuat detail'), backgroundColor: AppColors.danger),
      );
      return;
    }
    final detail = detailRes['data'];
    final rawItems = detail['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada item untuk dihitung'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final lines = rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final counts = <int, int>{};
    for (final line in lines) {
      counts[line['id'] as int] = (line['counted_quantity'] as num?)?.toInt() ?? 0;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Catat Hasil Hitung'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...lines.map((line) {
                    final id = line['id'] as int;
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
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              initialValue: '${counts[id]}',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Dihitung', isDense: true),
                              onChanged: (v) => counts[id] = int.tryParse(v) ?? 0,
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
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final res = await _api.post('/v1/stock-counts/${sc['id']}/record', body: {
        'items': counts.entries
            .map((e) => {'stock_count_item_id': e.key, 'counted_quantity': e.value})
            .toList(),
      });
      if (!mounted) return;
      if (res['success'] == true) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hasil hitung disimpan'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal menyimpan'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _action(Map sc, String action, String label) async {
    try {
      final res = await _api.post('/v1/stock-counts/${sc['id']}/$action');
      if (!mounted) return;
      if (res['success'] == true) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(label), backgroundColor: AppColors.success),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stock Count', style: TextStyle(fontSize: 18)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, size: 22), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            ..._items.map((raw) {
              final s = Map<String, dynamic>.from(raw as Map);
              final status = s['status']?.toString();
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
                        child: Text(s['reference'] ?? '#${s['id']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                        child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor(status))),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${s['count_date'] ?? s['created_at'] ?? ''}${s['is_blind'] == true ? ' · Blind' : ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'start':
                          _start(s);
                        case 'record':
                          _record(s);
                        case 'approve':
                          _action(s, 'approve', 'Disetujui');
                        case 'post':
                          _action(s, 'post', 'Diposting ke stok');
                      }
                    },
                    itemBuilder: (_) => [
                      if (status == 'draft') const PopupMenuItem(value: 'start', child: Text('Mulai Hitung')),
                      if (status == 'counting') const PopupMenuItem(value: 'record', child: Text('Catat Hasil')),
                      if (status == 'pending_approval') const PopupMenuItem(value: 'approve', child: Text('Setujui')),
                      if (status == 'approved') const PopupMenuItem(value: 'post', child: Text('Post ke Stok')),
                    ],
                  ),
                ),
              );
            }),
            if (!_loading && _items.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Belum ada stock count'))),
            const SizedBox(height: 72),
          ],
        ),
      ),
    );
  }
}
