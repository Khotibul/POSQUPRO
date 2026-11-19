import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

/// Print struk thermal via Bluetooth SPP RFCOMM (ESC/POS),
/// mengikuti perilaku pos-next-js `printViaBluetooth` / Capacitor plugin.
class BluetoothPrinterService {
  static const MethodChannel _permissions = MethodChannel('posqupro/bluetooth_permissions');
  static const Duration _connectTimeout = Duration(seconds: 15);
  static const int _chunkSize = 768;
  static const Duration _chunkDelay = Duration(milliseconds: 25);

  /// Minta izin Bluetooth (Android 12+: CONNECT/SCAN; lama: BT + location).
  static Future<bool> ensurePermissions() async {
    try {
      final result = await _permissions.invokeMethod<bool>('request');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return true;
    }
  }

  static Future<bool> isEnabled() async {
    try {
      return await FlutterBluetoothSerial.instance.isEnabled ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestEnable() async {
    try {
      final enabled = await FlutterBluetoothSerial.instance.requestEnable();
      return enabled ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Daftar perangkat yang sudah di-bond (paired).
  static Future<List<BluetoothDevice>> bondedDevices() async {
    try {
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (_) {
      return <BluetoothDevice>[];
    }
  }

  /// Cari perangkat bonded yang cocok dengan [deviceName] (nama atau MAC).
  /// Kembalikan null jika tidak ada.
  static Future<BluetoothDevice?> resolveDevice(String deviceName) async {
    final devices = await bondedDevices();
    if (devices.isEmpty) return null;

    final query = deviceName.trim().toLowerCase();
    if (query.isEmpty) {
      // Default: perangkat bonded pertama yang name-nya mirip printer
      const hints = ['printer', 'pos', 'thermal', 'esc', 'rp', 'xp', 'gprinter', 'epson', 'casio'];
      for (final d in devices) {
        final n = (d.name ?? '').toLowerCase();
        if (hints.any((h) => n.contains(h))) return d;
      }
      return devices.first;
    }

    for (final d in devices) {
      if (d.address.toLowerCase() == query) return d;
    }
    for (final d in devices) {
      if ((d.name ?? '').toLowerCase().contains(query)) return d;
    }
    return null;
  }

  /// Kirim [text] ke printer. Melempar [Exception] dengan pesan Indonesia bila gagal.
  static Future<void> printText(
    String text, {
    String? deviceName,
    String? deviceAddress,
  }) async {
    if (!await ensurePermissions()) {
      throw Exception('Izin Bluetooth ditolak. Aktifkan izin Bluetooth di Pengaturan aplikasi.');
    }
    if (!await isEnabled()) {
      final enabled = await requestEnable();
      if (!enabled) {
        throw Exception('Bluetooth belum aktif. Nyalakan Bluetooth lalu coba lagi.');
      }
    }

    BluetoothDevice? device;
    if (deviceAddress != null && deviceAddress.isNotEmpty) {
      device = BluetoothDevice(address: deviceAddress, name: deviceName);
    } else {
      device = await resolveDevice(deviceName ?? '');
    }
    if (device == null) {
      throw Exception(
        deviceName == null || deviceName.isEmpty
            ? 'Tidak ada printer Bluetooth yang dipasangkan. Pair dulu di Pengaturan Android.'
            : 'Printer "$deviceName" tidak ditemukan di daftar perangkat terpasang.',
      );
    }

    await _sendToDevice(device, text);
  }

  static Future<void> _sendToDevice(BluetoothDevice device, String text) async {
    BluetoothConnection? connection;
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        connection = await BluetoothConnection.toAddress(device.address)
            .timeout(_connectTimeout);
        break;
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    if (connection == null) {
      throw Exception(
        'Gagal terhubung ke printer ${device.name ?? device.address}: $lastError',
      );
    }

    try {
      final bytes = _encode(text);
      for (var i = 0; i < bytes.length; i += _chunkSize) {
        final end =
            (i + _chunkSize) > bytes.length ? bytes.length : i + _chunkSize;
        connection.output.add(Uint8List.fromList(bytes.sublist(i, end)));
        await connection.output.allSent.timeout(const Duration(seconds: 10));
        if (end < bytes.length) {
          await Future<void>.delayed(_chunkDelay);
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    } finally {
      try {
        connection.dispose();
      } catch (_) {}
    }
  }

  /// Encode struk + bungkus ESC/POS (init, teks, feed, cut).
  static List<int> _encode(String text) {
    final init = <int>[0x1B, 0x40];
    final body = latin1.encode(text);
    final feed = <int>[0x0A, 0x0A, 0x0A];
    final cut = <int>[0x1D, 0x56, 0x41, 0x00];
    return <int>[...init, ...body, ...feed, ...cut];
  }
}
