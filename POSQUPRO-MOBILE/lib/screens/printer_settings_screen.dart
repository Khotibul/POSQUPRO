import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';
import '../core/printer/bluetooth_printer_service.dart';
import '../core/printer/receipt_builder.dart';
import '../core/theme.dart';
import '../providers/settings_provider.dart';

/// Pengaturan printer thermal — mengikuti opsi pos-next-js
/// (connection, paper, header/footer, auto-print, show SKU/diskon/pajak).
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  late SettingsProvider _settings;

  String _connection = 'bluetooth';
  String _deviceName = '';
  String _deviceAddress = '';
  String _paper = '80';
  String _fontSize = 'medium';
  bool _autoPrint = false;
  bool _showSku = true;
  bool _showUnitPrice = true;
  bool _showDiscount = true;
  bool _showTax = true;
  final _headerCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();

  List<BluetoothDevice> _devices = [];
  bool _scanning = false;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  void _load() {
    _settings = context.read<SettingsProvider>();
    final s = _settings;
    setState(() {
      _connection = s.getSetting('printer.connection.type', defaultValue: 'bluetooth');
      if (_connection.isEmpty) _connection = 'bluetooth';
      _deviceName = s.getSetting('printer.name', defaultValue: '');
      _deviceAddress = s.getSetting('printer.bluetooth.mac', defaultValue: '');
      _paper = s.getSetting('printer.paper.width', defaultValue: '80');
      if (_paper == '48mm' || _paper == '58mm' || _paper == '80mm') {
        _paper = _paper.substring(0, 2);
      }
      _fontSize = s.getSetting('printer.font.size', defaultValue: 'medium');
      if (!['small', 'medium', 'large'].contains(_fontSize)) _fontSize = 'medium';
      _autoPrint = s.getSetting('printer.auto.print', defaultValue: 'false') == 'true';
      _showSku = s.getSetting('printer.show.sku', defaultValue: 'true') != 'false';
      _showUnitPrice = s.getSetting('printer.show.unitPrice', defaultValue: 'true') != 'false';
      _showDiscount = s.getSetting('printer.show.discount', defaultValue: 'true') != 'false';
      _showTax = s.getSetting('printer.show.tax', defaultValue: 'true') != 'false';
      _headerCtrl.text = s.getSetting('receipt.header', defaultValue: '').isNotEmpty
          ? s.getSetting('receipt.header', defaultValue: '')
          : s.getSetting('store.name', defaultValue: 'POSQUPRO');
      _footerCtrl.text = s.getSetting('receipt.footer', defaultValue: 'Terima kasih sudah berbelanja.');
    });
    _scanDevices();
  }

  Future<void> _scanDevices() async {
    setState(() => _scanning = true);
    try {
      await BluetoothPrinterService.ensurePermissions();
      if (!await BluetoothPrinterService.isEnabled()) {
        await BluetoothPrinterService.requestEnable();
      }
      final devices = await BluetoothPrinterService.bondedDevices();
      if (mounted) setState(() => _devices = devices);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final provider = context.read<SettingsProvider>();
    final data = <String, String>{
      'printer.connection.type': _connection,
      'printer.name': _deviceName.trim(),
      'printer.bluetooth.mac': _deviceAddress.trim(),
      'printer.paper.width': _paper,
      'printer.font.size': _fontSize,
      'printer.auto.print': _autoPrint ? 'true' : 'false',
      'printer.show.sku': _showSku ? 'true' : 'false',
      'printer.show.unitPrice': _showUnitPrice ? 'true' : 'false',
      'printer.show.discount': _showDiscount ? 'true' : 'false',
      'printer.show.tax': _showTax ? 'true' : 'false',
      'receipt.header': _headerCtrl.text.trim(),
      'receipt.footer': _footerCtrl.text.trim(),
    };

    var ok = true;
    for (final e in data.entries) {
      final saved = await provider.saveSettingPair(e.key, e.value);
      if (!saved) ok = false;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Pengaturan printer disimpan' : (provider.error ?? 'Gagal menyimpan')),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ),
    );
    if (ok) await provider.loadPublicSettings();
  }

  String _sampleReceipt() {
    final address = _settings.getSetting('store.address', defaultValue: '');
    final phone = _settings.getSetting('store.phone', defaultValue: '');
    final subtitle = [
      if (address.isNotEmpty) address,
      if (phone.isNotEmpty) 'Telp: $phone',
    ].join('\n');

    return ReceiptBuilder.build(
      receipt: ReceiptData(
        invoiceNo: 'INV-TEST',
        createdAt: DateTime.now(),
        status: 'paid',
        subtotal: 50000,
        discount: 5000,
        tax: 0,
        total: 45000,
        paid: 50000,
        change: 5000,
        paymentMethod: 'cash',
        items: const [
          ReceiptLine(name: 'Kopi Susu', quantity: 2, unitPrice: 25000, sku: 'KS-01'),
        ],
      ),
      headerTitle: _headerCtrl.text.trim().isEmpty ? 'POSQUPRO' : _headerCtrl.text.trim(),
      headerSubtitle: subtitle,
      footerNote: _footerCtrl.text.trim(),
      paperWidth: _paper,
      showSku: _showSku,
      showDiscount: _showDiscount,
      showTax: _showTax,
      showUnitPrice: _showUnitPrice,
    );
  }

  Future<void> _testPrint() async {
    setState(() => _testing = true);
    try {
      await BluetoothPrinterService.printText(
        _sampleReceipt(),
        deviceName: _deviceName,
        deviceAddress: _deviceAddress,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Struk tes terkirim ke printer'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _previewReceipt() {
    final text = _sampleReceipt();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pratinjau Struk'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                text.replaceAll('\x1B', '').replaceAll(RegExp(r'\[[0-9;]*m'), ''),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.35),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan Printer', style: TextStyle(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined, size: 20),
            tooltip: 'Pratinjau struk',
            onPressed: _previewReceipt,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(
              'Koneksi Printer',
              [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'bluetooth', label: Text('Bluetooth'), icon: Icon(Icons.bluetooth_rounded, size: 16)),
                    ButtonSegment(value: 'share', label: Text('Pratinjau'), icon: Icon(Icons.preview_rounded, size: 16)),
                  ],
                  selected: {_connection},
                  onSelectionChanged: (v) => setState(() => _connection = v.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
                if (_connection == 'bluetooth') ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _deviceName.isEmpty ? 'Belum memilih printer' : _deviceName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _deviceName.isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _scanning ? null : _scanDevices,
                        icon: _scanning
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(_scanning ? 'Memindai...' : 'Pindai', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_devices.isEmpty)
                    const Text(
                      'Tidak ada perangkat terpasang. Pair printer di Pengaturan Android terlebih dahulu.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    )
                  else
                    RadioGroup<String>(
                      groupValue: _deviceAddress,
                      onChanged: (v) {
                        final address = v ?? '';
                        final match = _devices.where((d) => d.address == address).firstOrNull;
                        setState(() {
                          _deviceAddress = address;
                          _deviceName = match?.name ?? address;
                        });
                      },
                      child: Column(
                        children: _devices
                            .map(
                              (d) => RadioListTile<String>(
                                dense: true,
                                value: d.address,
                                title: Text(
                                  d.name?.isNotEmpty == true ? d.name! : d.address,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(d.address, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                contentPadding: EdgeInsets.zero,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _testPrint,
                    icon: _testing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.print_rounded, size: 16),
                    label: Text(_testing ? 'Mengirim...' : 'Test Cetak', style: const TextStyle(fontSize: 12)),
                  ),
                ] else
                  const Text(
                    'Mode pratinjau: struk ditampilkan di layar (tanpa printer). Pakai Bluetooth untuk cetak thermal langsung.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _paper,
                  decoration: const InputDecoration(labelText: 'Ukuran Kertas', isDense: true),
                  items: const [
                    DropdownMenuItem(value: '48', child: Text('48mm (24 char)')),
                    DropdownMenuItem(value: '58', child: Text('58mm (32 char)')),
                    DropdownMenuItem(value: '80', child: Text('80mm (48 char)')),
                  ],
                  onChanged: (v) => setState(() => _paper = v ?? '80'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _fontSize,
                  decoration: const InputDecoration(labelText: 'Ukuran Font Struk', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'small', child: Text('Kecil')),
                    DropdownMenuItem(value: 'medium', child: Text('Sedang')),
                    DropdownMenuItem(value: 'large', child: Text('Besar')),
                  ],
                  onChanged: (v) => setState(() => _fontSize = v ?? 'medium'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _section(
              'Header & Footer Struk',
              [
                TextField(
                  controller: _headerCtrl,
                  decoration: const InputDecoration(labelText: 'Judul Struk (nama toko)', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _footerCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Catatan Kaki', isDense: true),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _section(
              'Tampilan Struk',
              [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Auto print setelah bayar', style: TextStyle(fontSize: 13)),
                  value: _autoPrint,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _autoPrint = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Tampilkan SKU item', style: TextStyle(fontSize: 13)),
                  value: _showSku,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _showSku = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Tampilkan harga satuan', style: TextStyle(fontSize: 13)),
                  value: _showUnitPrice,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _showUnitPrice = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Tampilkan diskon', style: TextStyle(fontSize: 13)),
                  value: _showDiscount,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _showDiscount = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Tampilkan pajak', style: TextStyle(fontSize: 13)),
                  value: _showTax,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _showTax = v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppGradients.hero,
                  borderRadius: BorderRadius.circular(AppRadius.field),
                  boxShadow: AppShadows.soft,
                ),
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan Pengaturan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
