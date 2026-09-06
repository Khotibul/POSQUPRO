import 'package:flutter/material.dart';
import '../core/database_service.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/transaction.dart';

class LocalDatabaseProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<Product> _products = [];
  List<Customer> _customers = [];
  List<Supplier> _suppliers = [];
  List<Transaction> _transactions = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;
  bool _isConnected = false;
  String? _error;

  List<Product> get products => _products;
  List<Customer> get customers => _customers;
  List<Supplier> get suppliers => _suppliers;
  List<Transaction> get transactions => _transactions;
  Map<String, dynamic> get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String? get error => _error;

  Future<bool> connect() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _db.connection;
      _isConnected = true;
      _error = null;
    } catch (e) {
      _isConnected = false;
      _error = 'Gagal koneksi database: $e';
    }

    _isLoading = false;
    notifyListeners();
    return _isConnected;
  }

  Future<void> loadAll() async {
    if (!_isConnected) {
      final connected = await connect();
      if (!connected) return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        loadProducts(),
        loadCustomers(),
        loadSuppliers(),
        loadTransactions(),
        loadStats(),
      ]);
    } catch (e) {
      _error = 'Gagal memuat data: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadProducts() async {
    try {
      final rows = await _db.query('''
        SELECT p.*, pc.name as category_name, u.name as unit_name
        FROM products p
        LEFT JOIN product_categories pc ON p.category_id = pc.id
        LEFT JOIN units u ON p.unit_quantity_id = u.id
        WHERE p.is_active = 1
        ORDER BY p.name ASC
        LIMIT 200
      ''');
      _products = rows.map((row) => Product.fromJson(_mapRow(row))).toList();
      notifyListeners();
    } catch (e) {
      _error = 'Gagal memuat produk: $e';
    }
  }

  Future<void> loadCustomers() async {
    try {
      final rows = await _db.query('''
        SELECT * FROM customers WHERE is_active = 1 ORDER BY name ASC LIMIT 100
      ''');
      _customers = rows.map((row) => Customer.fromJson(_mapRow(row))).toList();
      notifyListeners();
    } catch (e) {
      _error = 'Gagal memuat pelanggan: $e';
    }
  }

  Future<void> loadSuppliers() async {
    try {
      final rows = await _db.query('''
        SELECT * FROM suppliers WHERE is_active = 1 ORDER BY name ASC LIMIT 100
      ''');
      _suppliers = rows.map((row) => Supplier.fromJson(_mapRow(row))).toList();
      notifyListeners();
    } catch (e) {
      _error = 'Gagal memuat supplier: $e';
    }
  }

  Future<void> loadTransactions() async {
    try {
      final rows = await _db.query('''
        SELECT s.*, c.name as customer_name, u.name as user_name
        FROM sales s
        LEFT JOIN customers c ON s.customer_id = c.id
        LEFT JOIN users u ON s.user_id = u.id
        ORDER BY s.created_at DESC
        LIMIT 50
      ''');
      _transactions = rows.map((row) => Transaction.fromJson(_mapSaleRow(row))).toList();
      notifyListeners();
    } catch (e) {
      _error = 'Gagal memuat transaksi: $e';
    }
  }

  Future<void> loadStats() async {
    try {
      final productCount = await _db.queryOne('SELECT COUNT(*) as cnt FROM products WHERE is_active = 1');
      final customerCount = await _db.queryOne('SELECT COUNT(*) as cnt FROM customers WHERE is_active = 1');
      final supplierCount = await _db.queryOne('SELECT COUNT(*) as cnt FROM suppliers WHERE is_active = 1');
      final todaySales = await _db.queryOne('''
        SELECT COUNT(*) as cnt, COALESCE(SUM(total), 0) as total
        FROM sales WHERE DATE(created_at) = CURDATE()
      ''');
      final lowStock = await _db.queryOne('SELECT COUNT(*) as cnt FROM products WHERE is_active = 1 AND stock <= min_stock');

      _stats = {
        'product_count': productCount?['cnt'] ?? 0,
        'customer_count': customerCount?['cnt'] ?? 0,
        'supplier_count': supplierCount?['cnt'] ?? 0,
        'today_sales_count': todaySales?['cnt'] ?? 0,
        'today_sales_total': double.tryParse(todaySales?['total']?.toString() ?? '0') ?? 0,
        'low_stock_count': lowStock?['cnt'] ?? 0,
      };
      notifyListeners();
    } catch (e) {
      _error = 'Gagal memuat statistik: $e';
    }
  }

  Map<String, dynamic> _mapRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'name': row['name'],
      'sku': row['sku'],
      'barcode': row['barcode'],
      'type': row['type'],
      'category_id': row['category_id'],
      'category': row['category_name'] != null ? {'name': row['category_name']} : null,
      'unit_quantity_id': row['unit_quantity_id'],
      'unit_quantity': row['unit_name'] != null ? {'name': row['unit_name']} : null,
      'cost_price': row['cost_price'],
      'selling_price': row['selling_price'] ?? row['price'],
      'price': row['price'],
      'stock': row['stock'],
      'min_stock': row['min_stock'],
      'image': row['image'] ?? row['photo'],
      'photo': row['photo'],
      'description': row['description'],
      'is_active': row['is_active'] ?? row['active'],
      'active': row['active'],
    };
  }

  Map<String, dynamic> _mapSaleRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'invoice_number': row['invoice_number'],
      'type': 'sell',
      'customer': row['customer_name'] != null ? {'name': row['customer_name']} : null,
      'user': row['user_name'] != null ? {'name': row['user_name']} : null,
      'subtotal': row['subtotal'] ?? row['total'],
      'discount': row['discount'] ?? 0,
      'tax_amount': row['tax_amount'] ?? 0,
      'total': row['total'],
      'status': row['status'] ?? 'completed',
      'notes': row['notes'],
      'created_at': row['created_at']?.toString(),
      'items': [],
    };
  }

  @override
  void dispose() {
    _db.disconnect();
    super.dispose();
  }
}
