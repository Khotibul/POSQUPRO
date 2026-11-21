import 'package:flutter/services.dart';

/// Membuka URL pembayaran memakai Activity Android tanpa menambah plugin.
class BrowserService {
  static const MethodChannel _channel = MethodChannel('posqupro/browser');

  static Future<bool> open(String url) async {
    try {
      final result = await _channel.invokeMethod<bool>('open', {'url': url});
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
