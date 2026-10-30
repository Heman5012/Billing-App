import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String sku;
  final String barcode;
  final double price;
  final int stock;
  final double taxRate;
  final String category;
  final String brand;
  final String imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    this.sku = '',
    this.barcode = '',
    required this.price,
    required this.stock,
    this.taxRate = 0.0,
    this.category = 'General',
    this.brand = '',
    this.imageUrl = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => stock <= 5;
  bool get isOutOfStock => stock <= 0;

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? barcode,
    double? price,
    int? stock,
    double? taxRate,
    String? category,
    String? brand,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      taxRate: taxRate ?? this.taxRate,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  double get taxPercent => taxRate;

  Map<String, dynamic> toMap() {
    final safeCat = category.trim().isEmpty ? 'General' : category.trim();
    final clampedTax = (taxRate.isNaN ? 0.0 : taxRate).clamp(0.0, 100.0).toDouble();
    return {
      'name': name.trim().length > 200 ? name.trim().substring(0, 200) : name.trim(),
      'sku': sku.trim().length > 100 ? sku.trim().substring(0, 100) : sku.trim(),
      'barcode': barcode.trim().length > 100 ? barcode.trim().substring(0, 100) : barcode.trim(),
      'price': (price.isNaN ? 0.0 : price).clamp(0.0, 100000000.0).toDouble(),
      'stock': stock < 0 ? 0 : (stock > 10000000 ? 10000000 : stock),
      'taxRate': clampedTax,
      'taxPercent': clampedTax,
      'category': safeCat.length > 100 ? safeCat.substring(0, 100) : safeCat,
      'brand': brand.trim().length > 100 ? brand.trim().substring(0, 100) : brand.trim(),
      'imageUrl': imageUrl.trim().length > 1000 ? imageUrl.trim().substring(0, 1000) : imageUrl.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Map representation for editing/updating existing products.
  /// Does NOT include 'createdAt' so Firestore immutable rules are strictly preserved.
  Map<String, dynamic> toUpdateMap() {
    final safeCat = category.trim().isEmpty ? 'General' : category.trim();
    final clampedTax = (taxRate.isNaN ? 0.0 : taxRate).clamp(0.0, 100.0).toDouble();
    return {
      'name': name.trim().length > 200 ? name.trim().substring(0, 200) : name.trim(),
      'sku': sku.trim().length > 100 ? sku.trim().substring(0, 100) : sku.trim(),
      'barcode': barcode.trim().length > 100 ? barcode.trim().substring(0, 100) : barcode.trim(),
      'price': (price.isNaN ? 0.0 : price).clamp(0.0, 100000000.0).toDouble(),
      'stock': stock < 0 ? 0 : (stock > 10000000 ? 10000000 : stock),
      'taxRate': clampedTax,
      'taxPercent': clampedTax,
      'category': safeCat.length > 100 ? safeCat.substring(0, 100) : safeCat,
      'brand': brand.trim().length > 100 ? brand.trim().substring(0, 100) : brand.trim(),
      'imageUrl': imageUrl.trim().length > 1000 ? imageUrl.trim().substring(0, 1000) : imageUrl.trim(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    double parseDouble(dynamic value, [double def = 0.0]) {
      if (value is num) return value.toDouble();
      if (value is String) {
        // Strip out non-numeric characters except decimal point and minus sign
        final sanitized = value.replaceAll(RegExp(r'[^\d.-]'), '').trim();
        return double.tryParse(sanitized) ?? def;
      }
      return def;
    }

    int parseInt(dynamic value, [int def = 0]) {
      if (value is num) return value.toInt();
      if (value is String) {
        final sanitized = value.replaceAll(RegExp(r'[^\d-]'), '').trim();
        return int.tryParse(sanitized) ?? def;
      }
      return def;
    }

    String parseString(dynamic value, [String def = '']) {
      if (value == null) return def;
      return value.toString();
    }

    // Name fallbacks: name -> productName -> title
    final name = parseString(
      map['name'] ?? map['productName'] ?? map['title'],
      'Unnamed Product',
    );

    // Barcode fallbacks: barcode -> barcodeNumber -> code -> ean
    // Note: If no barcode field is present in the map, leave as empty string.
    final barcodeVal = parseString(
      map['barcode'] ?? map['barcodeNumber'] ?? map['code'] ?? map['ean'],
    ).trim();

    // Tax rate fallbacks: taxRate -> taxPercent -> tax -> gst
    final taxVal = parseDouble(
      map['taxRate'] ?? map['taxPercent'] ?? map['tax'] ?? map['gst'],
    ).clamp(0.0, 100.0);

    // Stock fallbacks: stock -> quantity -> stockQuantity -> availableStock -> inventory
    final stockVal = parseInt(
      map['stock'] ??
          map['quantity'] ??
          map['stockQuantity'] ??
          map['availableStock'] ??
          map['inventory'],
    );

    // Price fallbacks: price -> unitPrice -> cost
    final priceVal = parseDouble(
      map['price'] ?? map['unitPrice'] ?? map['cost'],
    );

    final catRaw = parseString(
      map['category'] ?? map['categoryName'],
      'General',
    ).trim();

    return Product(
      id: id,
      name: name,
      sku: parseString(map['sku']),
      barcode: barcodeVal,
      price: priceVal,
      stock: stockVal,
      taxRate: taxVal,
      category: catRaw.isEmpty ? 'General' : catRaw,
      brand: parseString(map['brand'] ?? map['brandName']),
      imageUrl: parseString(map['imageUrl'] ?? map['image']),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
