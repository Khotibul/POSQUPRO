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
  final String? taxName;
  final int? supplierId;
  final String? supplierName;
  final double costPrice;
  final double sellingPrice;
  final double wholesalePrice;
  final int minWholesale;
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
    this.taxName,
    this.supplierId,
    this.supplierName,
    this.costPrice = 0,
    this.sellingPrice = 0,
    this.wholesalePrice = 0,
    this.minWholesale = 0,
    this.stock = 0,
    this.minStock = 0,
    this.image,
    this.description,
    this.isActive = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: _toInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString(),
      barcode: json['barcode']?.toString(),
      type: json['type']?.toString(),
      categoryId: _toInt(json['category_id']),
      categoryName: _relationName(json['category']) ?? json['category_text']?.toString(),
      unitQuantityId: _toInt(json['unit_quantity_id']),
      unitName: _relationName(json['unit_quantity']),
      taxId: _toInt(json['tax_id']),
      taxName: _relationName(json['tax']),
      supplierId: _toInt(json['supplier_id']),
      supplierName: _relationName(json['supplier']),
      costPrice: _toDouble(json['cost_price'] ?? json['cost']),
      sellingPrice: _toDouble(json['selling_price'] ?? json['price']),
      wholesalePrice: _toDouble(json['wholesale_price']),
      minWholesale: _toInt(json['min_wholesale']) ?? 0,
      stock: _toDouble(json['stock']).round(),
      minStock: _toDouble(json['min_stock']).round(),
      image: json['image']?.toString() ?? json['photo']?.toString(),
      description: json['description']?.toString(),
      isActive: _toBool(json['is_active'] ?? json['active'], fallback: true),
    );
  }

  /// API mengembalikan relasi sebagai objek {name:...}, tetapi kolom legacy
  /// `products.category` (varchar) bisa menimpanya menjadi string polos.
  static String? _relationName(dynamic value) {
    if (value is Map) {
      return value['name']?.toString();
    }
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static bool _toBool(dynamic value, {required bool fallback}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().toLowerCase();
    if (s == '1' || s == 'true') return true;
    if (s == '0' || s == 'false') return false;
    return fallback;
  }
}
