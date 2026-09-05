class PurchaseOrder {
  final int id;
  final String? orderNumber;
  final int? supplierId;
  final String? supplierName;
  final String? userName;
  final List<PurchaseOrderItem> items;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double total;
  final String status;
  final String? notes;
  final DateTime? orderDate;
  final DateTime? expectedDate;
  final DateTime? createdAt;

  PurchaseOrder({
    required this.id,
    this.orderNumber,
    this.supplierId,
    this.supplierName,
    this.userName,
    this.items = const [],
    this.subtotal = 0,
    this.discount = 0,
    this.taxAmount = 0,
    this.total = 0,
    this.status = 'draft',
    this.notes,
    this.orderDate,
    this.expectedDate,
    this.createdAt,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'],
      supplierId: json['supplier_id'],
      supplierName: json['supplier']?['name'],
      userName: json['user']?['name'],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => PurchaseOrderItem.fromJson(e))
              .toList() ??
          [],
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0,
      taxAmount: double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? 'draft',
      notes: json['notes'],
      orderDate: json['order_date'] != null ? DateTime.tryParse(json['order_date']) : null,
      expectedDate: json['expected_date'] != null ? DateTime.tryParse(json['expected_date']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}

class PurchaseOrderItem {
  final int id;
  final int productId;
  final String? productName;
  final int quantity;
  final int receivedQuantity;
  final double unitPrice;
  final double discount;
  final double total;

  PurchaseOrderItem({
    required this.id,
    required this.productId,
    this.productName,
    required this.quantity,
    this.receivedQuantity = 0,
    required this.unitPrice,
    this.discount = 0,
    required this.total,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItem(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product']?['name'] ?? json['product_name'],
      quantity: json['quantity'] ?? 0,
      receivedQuantity: json['received_quantity'] ?? 0,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
    );
  }
}
