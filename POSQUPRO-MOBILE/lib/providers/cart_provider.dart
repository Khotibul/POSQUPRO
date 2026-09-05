import 'package:flutter/material.dart';
import '../models/product.dart';

class CartItem {
  final Product product;
  int quantity;
  double unitPrice;
  double discount;

  CartItem({
    required this.product,
    this.quantity = 1,
    double? unitPrice,
    this.discount = 0,
  }) : unitPrice = unitPrice ?? product.sellingPrice;

  double get subtotal => unitPrice * quantity;
  double get total => subtotal - discount;
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String _paymentMethod = 'cash';
  int? _customerId;

  List<CartItem> get items => List.unmodifiable(_items);
  String get paymentMethod => _paymentMethod;
  int? get customerId => _customerId;

  double get subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get totalDiscount => _items.fold(0, (sum, item) => sum + item.discount);
  double get total => subtotal - totalDiscount;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  void addItem(Product product) {
    final existing = _items.indexWhere((i) => i.product.id == product.id);
    if (existing >= 0) {
      _items[existing].quantity++;
    } else {
      _items.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void removeItem(int productId) {
    _items.removeWhere((i) => i.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(int productId, int quantity) {
    final index = _items.indexWhere((i) => i.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void updateDiscount(int productId, double discount) {
    final index = _items.indexWhere((i) => i.product.id == productId);
    if (index >= 0) {
      _items[index].discount = discount;
      notifyListeners();
    }
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setCustomerId(int? id) {
    _customerId = id;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _customerId = null;
    _paymentMethod = 'cash';
    notifyListeners();
  }
}
