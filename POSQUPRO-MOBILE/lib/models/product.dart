class Product {
  final int id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? type;
  final int? categoryId;
  final String? categoryName;
  final int? unitQuantityId;
  final String? unitName;
  final int? taxId;
  final double costPrice;
  final double sellingPrice;
  final int stock;
  final int minStock;
  final String? image;
  final String? description;
  final bool isActive;

  bool get isLowStock => stock <= minStock;

  Product({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.type,
    this.categoryId,
    this.categoryName,
    this.unitQuantityId,
    this.unitName,
    this.taxId,
    this.costPrice = 0,
    this.sellingPrice = 0,
    this.stock = 0,
    this.minStock = 0,
    this.image,
    this.description,
    this.isActive = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      sku: json['sku'],
      barcode: json['barcode'],
      type: json['type'],
      categoryId: json['category_id'],
      categoryName: json['category']?['name'],
      unitQuantityId: json['unit_quantity_id'],
      unitName: json['unit_quantity']?['name'],
      taxId: json['tax_id'],
      costPrice: double.tryParse(json['cost_price']?.toString() ?? '0') ?? 0,
      sellingPrice: double.tryParse(json['selling_price']?.toString() ?? json['price']?.toString() ?? '0') ?? 0,
      stock: json['stock'] ?? 0,
      minStock: json['min_stock'] ?? 0,
      image: json['image'] ?? json['photo'],
      description: json['description'],
      isActive: json['is_active'] ?? json['active'] ?? true,
    );
  }
}
