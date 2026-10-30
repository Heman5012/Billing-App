import 'package:flutter/foundation.dart';

import '../models/invoice.dart';
import '../models/product.dart';

enum AddToCartStatus {
  added,
  quantityUpdated,
  outOfStock,
  maxStockReached,
  invalidData,
}

class AddToCartResult {
  final AddToCartStatus status;
  final String message;
  final int quantity;

  const AddToCartResult({
    required this.status,
    required this.message,
    this.quantity = 0,
  });

  bool get isSuccess =>
      status == AddToCartStatus.added ||
      status == AddToCartStatus.quantityUpdated;
}

/// Central single source of truth for the active billing cart across the app.
class CartService extends ChangeNotifier {
  CartService._();
  static final CartService instance = CartService._();

  final List<InvoiceItem> _items = [];
  CustomerDetails _customer = CustomerDetails();
  double _overallDiscountPercent = 0.0;
  String _notes = '';

  List<InvoiceItem> get items => List.unmodifiable(_items);
  CustomerDetails get customer => _customer;
  double get overallDiscountPercent => _overallDiscountPercent;
  String get notes => _notes;

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  int get itemCount => _items.length;
  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);

  // Financial calculations matching BillWave core rules
  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.lineSubtotal);
  double get taxableTotal =>
      _items.fold(0.0, (sum, item) => sum + item.lineTaxable);
  double get taxTotal => _items.fold(0.0, (sum, item) => sum + item.lineTax);

  double get overallDiscountAmount =>
      taxableTotal * (_overallDiscountPercent / 100.0);
  double get finalTaxable => taxableTotal - overallDiscountAmount;
  double get discountFactor =>
      taxableTotal > 0 ? (finalTaxable / taxableTotal) : 1.0;
  double get finalTax => taxTotal * discountFactor;
  double get grandTotal => finalTaxable + finalTax;

  Map<String, double> get taxBreakdown {
    final breakdown = <String, double>{};
    for (final item in _items) {
      final rateKey = '${item.taxRate.toStringAsFixed(0)}%';
      breakdown[rateKey] = (breakdown[rateKey] ?? 0.0) + item.lineTax;
    }
    final updated = <String, double>{};
    breakdown.forEach((rate, amt) {
      updated[rate] = amt * discountFactor;
    });
    return updated;
  }

  /// Returns current quantity of this product in active bill, or 0 if not present.
  int getProductQuantity(Product product) {
    for (final item in _items) {
      if ((product.id.isNotEmpty && item.productId == product.id) ||
          item.name.trim().toLowerCase() == product.name.trim().toLowerCase()) {
        return item.quantity;
      }
    }
    return 0;
  }

  /// Adds a product to the active bill or increases its quantity.
  AddToCartResult addProduct(Product product, {int quantity = 1}) {
    if (product.name.trim().isEmpty) {
      return const AddToCartResult(
        status: AddToCartStatus.invalidData,
        message: 'Product name cannot be empty.',
      );
    }
    if (product.price < 0) {
      return const AddToCartResult(
        status: AddToCartStatus.invalidData,
        message: 'Product price cannot be negative.',
      );
    }
    if (quantity <= 0) {
      return const AddToCartResult(
        status: AddToCartStatus.invalidData,
        message: 'Quantity must be at least 1.',
      );
    }
    if (product.stock <= 0) {
      return AddToCartResult(
        status: AddToCartStatus.outOfStock,
        message: '"${product.name}" is currently out of stock.',
      );
    }

    final existingIndex = _items.indexWhere(
      (item) =>
          (product.id.isNotEmpty && item.productId == product.id) ||
          item.name.trim().toLowerCase() == product.name.trim().toLowerCase(),
    );

    if (existingIndex >= 0) {
      final current = _items[existingIndex];
      final newQuantity = current.quantity + quantity;

      if (newQuantity > product.stock) {
        return AddToCartResult(
          status: AddToCartStatus.maxStockReached,
          message:
              'Cannot add more "${product.name}". Max stock is ${product.stock} (already have ${current.quantity} in bill).',
          quantity: current.quantity,
        );
      }

      _items[existingIndex] = InvoiceItem(
        productId: current.productId ?? (product.id.isNotEmpty ? product.id : null),
        name: current.name,
        unitPrice: current.unitPrice,
        quantity: newQuantity,
        discountPercent: current.discountPercent,
        taxRate: current.taxRate,
      );

      notifyListeners();
      return AddToCartResult(
        status: AddToCartStatus.quantityUpdated,
        message: 'Updated "${product.name}" quantity to $newQuantity.',
        quantity: newQuantity,
      );
    } else {
      if (quantity > product.stock) {
        return AddToCartResult(
          status: AddToCartStatus.maxStockReached,
          message:
              'Requested quantity ($quantity) exceeds available stock of ${product.stock}.',
          quantity: 0,
        );
      }

      _items.add(
        InvoiceItem(
          productId: product.id.isNotEmpty ? product.id : null,
          name: product.name.trim(),
          unitPrice: product.price,
          quantity: quantity,
          discountPercent: 0.0,
          taxRate: product.taxRate,
        ),
      );

      notifyListeners();
      return AddToCartResult(
        status: AddToCartStatus.added,
        message: 'Added "${product.name}" (×$quantity) to bill.',
        quantity: quantity,
      );
    }
  }

  /// Adds a custom/ad-hoc invoice item directly to the active bill.
  void addCustomItem(InvoiceItem item) {
    _items.add(item);
    notifyListeners();
  }

  void updateQuantity(int index, int delta, {int? maxStock}) {
    if (index < 0 || index >= _items.length) return;

    final item = _items[index];
    final newQty = item.quantity + delta;

    if (newQty <= 0) {
      _items.removeAt(index);
    } else {
      if (maxStock != null && newQty > maxStock) return;
      _items[index] = InvoiceItem(
        productId: item.productId,
        name: item.name,
        unitPrice: item.unitPrice,
        quantity: newQty,
        discountPercent: item.discountPercent,
        taxRate: item.taxRate,
      );
    }
    notifyListeners();
  }

  void setQuantity(int index, int newQty, {int? maxStock}) {
    if (index < 0 || index >= _items.length) return;

    if (newQty <= 0) {
      _items.removeAt(index);
    } else {
      final clampedQty = maxStock != null ? newQty.clamp(1, maxStock) : newQty;
      final item = _items[index];
      _items[index] = InvoiceItem(
        productId: item.productId,
        name: item.name,
        unitPrice: item.unitPrice,
        quantity: clampedQty,
        discountPercent: item.discountPercent,
        taxRate: item.taxRate,
      );
    }
    notifyListeners();
  }

  void setItemDiscount(int index, double discountPercent) {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    _items[index] = InvoiceItem(
      productId: item.productId,
      name: item.name,
      unitPrice: item.unitPrice,
      quantity: item.quantity,
      discountPercent: discountPercent.clamp(0.0, 100.0),
      taxRate: item.taxRate,
    );
    notifyListeners();
  }

  void removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _customer = CustomerDetails();
    _overallDiscountPercent = 0.0;
    _notes = '';
    notifyListeners();
  }

  void updateCustomer(CustomerDetails details) {
    _customer = details;
    notifyListeners();
  }

  void updateNotes(String n) {
    _notes = n;
    notifyListeners();
  }

  void updateOverallDiscount(double discount) {
    _overallDiscountPercent = discount.clamp(0.0, 100.0);
    notifyListeners();
  }
}
