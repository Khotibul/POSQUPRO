class Transaction {
  final int id;
  final String? invoiceNumber;
  final String type;
  final String? customerName;
  final String? supplierName;
  final String? userName;
  final List<TransactionItem> items;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double total;
  final String status;
  final String? notes;
  final DateTime? createdAt;

  Transaction({
    required this.id,
    this.invoiceNumber,
    required this.type,
    this.customerName,
    this.supplierName,
    this.userName,
    this.items = const [],
    this.subtotal = 0,
    this.discount = 0,
    this.taxAmount = 0,
    this.total = 0,
    this.status = 'completed',
    this.notes,
    this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? 0,
      invoiceNumber: json['invoice_number'],
      type: json['type'] ?? 'sell',
      customerName: json['customer']?['name'],
      supplierName: json['supplier']?['name'],
      userName: json['user']?['name'],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => TransactionItem.fromJson(e))
              .toList() ??
          [],
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0,
      taxAmount: double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? 'completed',
      notes: json['notes'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}

class TransactionItem {
  final int id;
  final int productId;
  final String? productName;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double total;

  TransactionItem({
    required this.id,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    required this.total,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product']?['name'] ?? json['product_name'],
      quantity: json['quantity'] ?? 0,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
    );
  }
}
