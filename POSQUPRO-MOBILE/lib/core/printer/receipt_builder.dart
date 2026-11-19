/// Builder struk teks ESC/POS — port dari pos-next-js `generateReceiptText`.
/// Lebar baris mengikuti ukuran kertas (48mm=24, 58mm=32, 80mm=48 char).
library;

class ReceiptLine {
  final String name;
  final int quantity;
  final double unitPrice;
  final double discount;
  final String? sku;

  const ReceiptLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    this.sku,
  });

  double get lineTotal => (unitPrice * quantity) - discount;
}

class ReceiptData {
  final String invoiceNo;
  final DateTime createdAt;
  final String status;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double paid;
  final double change;
  final String paymentMethod;
  final List<ReceiptLine> items;

  const ReceiptData({
    required this.invoiceNo,
    required this.createdAt,
    required this.status,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paid,
    required this.change,
    required this.paymentMethod,
    required this.items,
  });
}

class ReceiptBuilder {
  static int charsPerLine(String paperWidth) {
    switch (paperWidth) {
      case '48':
      case '48mm':
        return 24;
      case '58':
      case '58mm':
        return 32;
      case '80':
      case '80mm':
      default:
        return 48;
    }
  }

  static String formatRupiah(double value) {
    final rounded = value.round();
    final negative = rounded < 0;
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return '${negative ? '-' : ''}Rp $buffer';
  }

  static String _padRight(String s, int width) {
    if (s.length >= width) return s.substring(0, width);
    return s.padRight(width);
  }

  static String _truncate(String s, int width) {
    if (s.length <= width) return s;
    return '${s.substring(0, width > 0 ? width - 1 : 0)}…';
  }

  static String _wrap(String text, int width) {
    if (width <= 0) return text;
    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      if (current.isEmpty) {
        current = word;
      } else if ('$current $word'.length <= width) {
        current = '$current $word';
      } else {
        lines.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.join('\n');
  }

  static String _center(String s, int width) {
    if (s.length >= width) return s.substring(0, width);
    final pad = (width - s.length) ~/ 2;
    return '${' ' * pad}$s';
  }

  static String _leftRight(String left, String right, int width) {
    final space = width - left.length - right.length;
    if (space <= 1) return '$left $right';
    return '$left${' ' * space}$right';
  }

  /// Build plain-text receipt (ESC/POS-ready; caller wraps with init/cut).
  static String build({
    required ReceiptData receipt,
    required String headerTitle,
    String headerSubtitle = '',
    String footerNote = '',
    String paperWidth = '80',
    bool showSku = true,
    bool showDiscount = true,
    bool showTax = true,
    bool showUnitPrice = true,
  }) {
    final width = charsPerLine(paperWidth);
    final sepFull = '=' * width;
    final sepDash = '-' * width;
    final sb = StringBuffer();

    // Header (centered)
    sb.writeln('\x1B\x61\x01');
    sb.writeln(_center(headerTitle, width));
    if (headerSubtitle.trim().isNotEmpty) {
      for (final line in _wrap(headerSubtitle, width).split('\n')) {
        sb.writeln(_center(line, width));
      }
    }
    sb.writeln('\x1B\x61\x00');

    // Meta
    final dateStr = receipt.createdAt.toLocal().toString().substring(0, 16).replaceAll('T', ' ');
    sb.writeln(_leftRight('No:', receipt.invoiceNo, width));
    sb.writeln(_leftRight('Tgl:', dateStr, width));
    final statusLabel = receipt.status == 'credit'
        ? 'BELUM LUNAS'
        : receipt.status == 'void'
            ? 'DIBATALKAN'
            : 'LUNAS';
    sb.writeln(_leftRight('Status:', statusLabel, width));
    sb.writeln(sepFull);

    // Items
    final priceCol = width >= 48 ? 16 : 12;
    final nameCol = width - priceCol - 1;
    for (final item in receipt.items) {
      final name = _truncate(item.name, nameCol);
      final totalStr = formatRupiah(item.lineTotal);
      final paddedTotal = totalStr.length >= priceCol
          ? totalStr.substring(totalStr.length - priceCol)
          : totalStr.padLeft(priceCol);
      sb.writeln('${_padRight(name, nameCol)} $paddedTotal');

      final details = <String>[];
      if (showUnitPrice) {
        details.add('${item.quantity} x ${formatRupiah(item.unitPrice)}');
      } else {
        details.add('x${item.quantity}');
      }
      if (showSku && (item.sku?.isNotEmpty ?? false)) {
        details.add('SKU: ${item.sku}');
      }
      if (showDiscount && item.discount > 0) {
        details.add('Diskon: ${formatRupiah(item.discount)}');
      }
      sb.writeln('  ${details.join(' · ')}');
    }

    sb.writeln(sepDash);

    void totalLine(String label, double value) {
      sb.writeln(_leftRight(label, formatRupiah(value), width));
    }

    totalLine('Subtotal', receipt.subtotal);
    if (showDiscount && receipt.discount > 0) totalLine('Diskon', receipt.discount);
    if (showTax && receipt.tax > 0) totalLine('Pajak', receipt.tax);
    sb.writeln(sepDash);
    totalLine('Total', receipt.total);

    if (receipt.paymentMethod.isNotEmpty) {
      totalLine('Bayar (${receipt.paymentMethod})', receipt.paid);
      if (receipt.change > 0) totalLine('Kembali', receipt.change);
    }

    sb.writeln(sepFull);
    sb.writeln('\x1B\x61\x01');
    if (footerNote.trim().isNotEmpty) {
      for (final line in _wrap(footerNote, width).split('\n')) {
        sb.writeln(_center(line, width));
      }
    }
    sb.writeln();
    sb.writeln();

    return sb.toString();
  }

  /// Full byte stream: ESC @ init, text, feed, GS V cut.
  static List<int> toBytes(String text) {
    final init = <int>[0x1B, 0x40];
    final body = text.codeUnits; // Latin-1 safe for ESC/POS thermal
    final feed = <int>[0x0A, 0x0A, 0x0A];
    final cut = <int>[0x1D, 0x56, 0x41, 0x00];
    return <int>[...init, ...body, ...feed, ...cut];
  }
}
