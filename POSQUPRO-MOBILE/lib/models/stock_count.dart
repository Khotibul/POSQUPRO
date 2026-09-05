class StockCount {
  final int id;
  final String? countNumber;
  final int? warehouseId;
  final String? warehouseName;
  final int? userId;
  final String? userName;
  final String status;
  final String? notes;
  final DateTime? countedAt;
  final DateTime? createdAt;

  StockCount({
    required this.id,
    this.countNumber,
    this.warehouseId,
    this.warehouseName,
    this.userId,
    this.userName,
    this.status = 'draft',
    this.notes,
    this.countedAt,
    this.createdAt,
  });

  factory StockCount.fromJson(Map<String, dynamic> json) {
    return StockCount(
      id: json['id'] ?? 0,
      countNumber: json['count_number'],
      warehouseId: json['warehouse_id'],
      warehouseName: json['warehouse']?['name'],
      userId: json['user_id'],
      userName: json['user']?['name'],
      status: json['status'] ?? 'draft',
      notes: json['notes'],
      countedAt: json['counted_at'] != null ? DateTime.tryParse(json['counted_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}

class InventoryHistory {
  final int id;
  final int? productId;
  final String? productName;
  final String type;
  final int quantity;
  final int? beforeStock;
  final int? afterStock;
  final String? reference;
  final String? notes;
  final int? userId;
  final String? userName;
  final DateTime? createdAt;

  InventoryHistory({
    required this.id,
    this.productId,
    this.productName,
    required this.type,
    required this.quantity,
    this.beforeStock,
    this.afterStock,
    this.reference,
    this.notes,
    this.userId,
    this.userName,
    this.createdAt,
  });

  factory InventoryHistory.fromJson(Map<String, dynamic> json) {
    return InventoryHistory(
      id: json['id'] ?? 0,
      productId: json['product_id'],
      productName: json['product']?['name'] ?? json['product_name'],
      type: json['type'] ?? 'in',
      quantity: json['quantity'] ?? 0,
      beforeStock: json['before_stock'],
      afterStock: json['after_stock'],
      reference: json['reference'],
      notes: json['notes'],
      userId: json['user_id'],
      userName: json['user']?['name'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}
