import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/database_config_service.dart';
import '../core/database_service.dart';
import '../models/db_config.dart';
import '../providers/local_database_provider.dart';

class DbSetupScreen extends StatefulWidget {
  final VoidCallback onConfigured;
  const DbSetupScreen({super.key, required this.onConfigured});

  @override
  State<DbSetupScreen> createState() => _DbSetupScreenState();
}

class _DbSetupScreenState extends State<DbSetupScreen> {
  final _wifiHost = TextEditingController();
  final _hostingHost = TextEditingController();
  String _mode = 'wifi';
  bool _testing = false;
  String _status = '';

  @override
  void dispose() {
    _wifiHost.dispose();
    _hostingHost.dispose();
    super.dispose();
  }

  Future<void> _testAndSave(DbConfig config) async {
    setState(() {
      _testing = true;
      _status = 'Menguji koneksi...';
    });

    try {
      if (config.mode == 'offline') {
        // offline pakai local sqflite nanti; anggap siap
      } else if (config.mode == 'wifi') {
        // coba konek langsung ke MySQL PC
        final db = DatabaseService();
        db.setConfig(config);
        await db.query('SELECT 1');
      } else if (config.mode == 'hosting') {
        // tes via HTTP ke API
        ApiService().setBaseUrl(config.apiBaseUrl);
        await ApiService().get('/health').timeout(const Duration(seconds: 10));
      }

      await DatabaseConfigService().saveConfig(config);
      if (!mounted) return;
      if (config.mode == 'hosting') {
        ApiService().setBaseUrl(config.apiBaseUrl);
      }
      context.read<LocalDatabaseProvider>().setDbConfig(config);
      setState(() {
        _status = 'Berhasil disimpan';
      });
      widget.onConfigured();
    } catch (e) {
      setState(() {
        _status = 'Gagal: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _testing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Koneksi Database'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Pilih sumber data saat pertama kali membuka aplikasi',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Card(
            child: RadioListTile<String>(
              title: const Text('1) Offline (Perangkat)'),
              subtitle: const Text('Data tersimpan lokal di HP/tablet (tanpa server)'),
              value: 'offline',
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
            ),
          ),
          Card(
            child: RadioListTile<String>(
              title: const Text('2) Online via WiFi (terhubung ke PC Server MySQL)'),
              subtitle: const Text('Langsung ke MySQL PC di jaringan lokal'),
              value: 'wifi',
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
            ),
          ),
          if (_mode == 'wifi')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _wifiHost,
                decoration: const InputDecoration(
                  labelText: 'IP PC Server (contoh: 192.168.1.100)',
                  hintText: '192.168.1.100',
                ),
                keyboardType: TextInputType.url,
              ),
            ),
          Card(
            child: RadioListTile<String>(
              title: const Text('3) Online Full (Hosting)'),
              subtitle: const Text('Koneksi ke API Laravel di hosting'),
              value: 'hosting',
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
            ),
          ),
          if (_mode == 'hosting')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _hostingHost,
                decoration: const InputDecoration(
                  labelText: 'Domain/URL Hosting (contoh: https://posqupro.com)',
                  hintText: 'https://posqupro.com',
                ),
                keyboardType: TextInputType.url,
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _testing
                ? null
                : () {
                    if (_mode == 'offline') {
                      _testAndSave(DbConfig.offline());
                    } else if (_mode == 'wifi') {
                      if (_wifiHost.text.trim().isEmpty) {
                        setState(() => _status = 'Masukkan IP PC server');
                        return;
                      }
                      _testAndSave(DbConfig.wifi(_wifiHost.text.trim()));
                    } else if (_mode == 'hosting') {
                      if (_hostingHost.text.trim().isEmpty) {
                        setState(() => _status = 'Masukkan domain hosting');
                        return;
                      }
                      _testAndSave(DbConfig.hosting(_hostingHost.text.trim()));
                    }
                  },
            icon: const Icon(Icons.save),
            label: Text(_testing ? 'Memproses...' : 'Simpan & Lanjut'),
          ),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_status),
            ),
        ],
      ),
    );
  }
}
