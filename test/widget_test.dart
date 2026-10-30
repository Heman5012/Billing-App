import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:billwave/models/invoice.dart';
import 'package:billwave/models/product.dart';
import 'package:billwave/services/barcode_lookup_service.dart';
import 'package:billwave/services/cart_service.dart';
import 'package:billwave/services/invoice_service.dart';
import 'package:billwave/services/pdf_service.dart';

void main() {
  group('BillWave Unit Tests - Core Billing & Financial Consistency', () {
    test('InvoiceItem calculates line values accurately', () {
      final item = InvoiceItem(
        productId: 'prod_1',
        name: 'Wireless Barcode Scanner',
        unitPrice: 1200.0,
        quantity: 2,
        discountPercent: 10.0, // 10% discount
        taxRate: 18.0, // 18% GST
      );

      // Subtotal = 1200 * 2 = 2400
      expect(item.lineSubtotal, equals(2400.0));
      // Discount = 2400 * 0.10 = 240
      expect(item.lineDiscount, equals(240.0));
      // Taxable = 2400 - 240 = 2160
      expect(item.lineTaxable, equals(2160.0));
      // Tax = 2160 * 0.18 = 388.80
      expect(item.lineTax, closeTo(388.80, 0.001));
      // Total = 2160 + 388.80 = 2548.80
      expect(item.lineTotal, closeTo(2548.80, 0.001));
    });

    test('Overall invoice calculations with mixed tax rates and discounts', () {
      final items = [
        InvoiceItem(
          name: 'Thermal Paper Roll',
          unitPrice: 50.0,
          quantity: 4, // 200.0
          discountPercent: 0.0,
          taxRate: 5.0, // 5% tax = 10.0
        ),
        InvoiceItem(
          name: 'POS Terminal Stand',
          unitPrice: 800.0,
          quantity: 1, // 800.0
          discountPercent: 0.0,
          taxRate: 18.0, // 18% tax = 144.0
        ),
      ];

      double subtotal = 0.0;
      double taxableTotal = 0.0;
      double taxTotal = 0.0;
      final taxBreakdown = <String, double>{};

      for (final item in items) {
        subtotal += item.lineSubtotal;
        taxableTotal += item.lineTaxable;
        taxTotal += item.lineTax;
        final rateKey = '${item.taxRate.toStringAsFixed(0)}%';
        taxBreakdown[rateKey] = (taxBreakdown[rateKey] ?? 0.0) + item.lineTax;
      }

      // Overall 10% discount on entire bill
      const overallDiscountPercent = 10.0;
      final overallDiscountAmount =
          taxableTotal * (overallDiscountPercent / 100.0);
      final finalTaxable = taxableTotal - overallDiscountAmount;
      final factor = taxableTotal > 0 ? (finalTaxable / taxableTotal) : 1.0;
      final finalTax = taxTotal * factor;
      final grandTotal = finalTaxable + finalTax;

      expect(subtotal, equals(1000.0));
      expect(taxableTotal, equals(1000.0));
      expect(overallDiscountAmount, equals(100.0));
      expect(finalTaxable, equals(900.0));
      // Original taxes: 10 (5%) + 144 (18%) = 154. Scaled by 0.9 = 138.6
      expect(finalTax, closeTo(138.60, 0.01));
      expect(grandTotal, closeTo(1038.60, 0.01));
    });

    test('Product model correctly identifies low stock and out of stock', () {
      final inStock = Product(
        id: '1',
        name: 'Item A',
        price: 100,
        stock: 15,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(inStock.isLowStock, isFalse);
      expect(inStock.isOutOfStock, isFalse);

      final lowStock = Product(
        id: '2',
        name: 'Item B',
        price: 100,
        stock: 4,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(lowStock.isLowStock, isTrue);
      expect(lowStock.isOutOfStock, isFalse);

      final outOfStock = Product(
        id: '3',
        name: 'Item C',
        price: 100,
        stock: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(outOfStock.isOutOfStock, isTrue);
    });

    test('Invoice number and secure share token format consistency', () {
      final invNum = InvoiceService.instance.generateInvoiceNumber();
      expect(invNum, startsWith('INV-'));

      final token = InvoiceService.instance.generateSecureShareToken(
        invNum,
        'user123',
      );
      expect(token.length, equals(32));
      expect(token, matches(RegExp(r'^[a-f0-9]{32}$')));
    });

    test('Invoice serialization toMap and fromMap roundtrip', () {
      final now = DateTime.now();
      final invoice = Invoice(
        id: 'test_inv_1',
        invoiceNumber: 'INV-20261028-9999',
        userId: 'usr_abc',
        customer: CustomerDetails(name: 'Jane Doe', phone: '9876543210'),
        items: [
          InvoiceItem(
            productId: 'p1',
            name: 'Test Product',
            unitPrice: 250.0,
            quantity: 2,
            taxRate: 5.0,
          ),
        ],
        subtotal: 500.0,
        overallDiscountPercent: 0.0,
        overallDiscountAmount: 0.0,
        taxableAmount: 500.0,
        tax: 25.0,
        taxBreakdown: {'5%': 25.0},
        total: 525.0,
        paymentMethod: 'UPI (Demo - Google Pay)',
        paymentStatus: 'paid',
        transactionMode: 'SIMULATED / DEMO',
        notes: 'Deliver before noon',
        createdAt: now,
        shareToken: 'abcdef1234567890abcdef1234567890',
      );

      final map = invoice.toMap();
      final deserialized = Invoice.fromMap(map, 'test_inv_1');

      expect(deserialized.id, equals('test_inv_1'));
      expect(deserialized.invoiceNumber, equals('INV-20261028-9999'));
      expect(deserialized.customer.name, equals('Jane Doe'));
      expect(deserialized.items.length, equals(1));
      expect(deserialized.items.first.name, equals('Test Product'));
      expect(deserialized.total, equals(525.0));
      expect(deserialized.isPaid, isTrue);
      expect(
        deserialized.shareToken,
        equals('abcdef1234567890abcdef1234567890'),
      );
    });

    test('Public invoice map sanitizes private fields', () {
      final now = DateTime.now();
      final invoice = Invoice(
        id: 'test_inv_priv',
        invoiceNumber: 'INV-20261028-1111',
        userId: 'super_secret_uid_123',
        customer: CustomerDetails(name: 'Alice', phone: '9999988888'),
        items: [
          InvoiceItem(
            productId: 'p_private',
            name: 'Item Secret',
            unitPrice: 100.0,
            quantity: 1,
          ),
        ],
        subtotal: 100.0,
        overallDiscountAmount: 0.0,
        taxableAmount: 100.0,
        tax: 0.0,
        taxBreakdown: {},
        total: 100.0,
        paymentMethod: 'Cash (Demo)',
        createdAt: now,
        shareToken: 'tok_1234567890abcdef1234567890',
      );

      final publicMap = invoice.toPublicMap('My Shop');
      expect(publicMap.containsKey('userId'), isFalse);
      expect(publicMap['businessName'], equals('My Shop'));
      expect(publicMap['invoiceNumber'], equals('INV-20261028-1111'));
      expect(publicMap['total'], equals(100.0));
    });

    test('PdfService generates PDF bytes with embedded fonts and currency symbol', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final invoice = Invoice(
        id: 'inv_pdf_test',
        invoiceNumber: 'INV-20261029-7777',
        userId: 'u1',
        customer: CustomerDetails(name: 'Test Customer', phone: '1234567890'),
        items: [
          InvoiceItem(
            name: 'Item Alpha',
            unitPrice: 150.0,
            quantity: 2,
            taxRate: 18.0,
          ),
        ],
        subtotal: 300.0,
        overallDiscountAmount: 0.0,
        taxableAmount: 300.0,
        tax: 54.0,
        taxBreakdown: {'18%': 54.0},
        total: 354.0,
        paymentMethod: 'UPI (Demo)',
        createdAt: DateTime.now(),
        shareToken: 'testtoken1234567890abcdef123456',
      );

      final business = BusinessProfile(
        businessName: 'BillWave Retail',
        currency: '₹',
      );

      final pdfBytes = await PdfService.instance.generateInvoicePdf(
        invoice: invoice,
        business: business,
      );

      expect(pdfBytes, isNotEmpty);
      // Valid PDF magic header %PDF
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });
  });

  group('Barcode & Product Lookup Unit Tests', () {
    test('Barcode normalization and validation', () {
      expect(BarcodeLookupService.normalizeBarcode('  301762 0422003  '),
          equals('3017620422003'));
      expect(BarcodeLookupService.isValidBarcode('3017620422003'), isTrue);
      expect(BarcodeLookupService.isValidBarcode('EAN-12345'), isTrue);
      expect(BarcodeLookupService.isValidBarcode('ab'), isFalse); // too short
      expect(BarcodeLookupService.isValidBarcode('   '), isFalse);
    });

    test('Product model roundtrip preserves brand and imageUrl', () {
      final now = DateTime.now();
      final product = Product(
        id: 'p_101',
        name: 'Nutella 400g',
        brand: 'Ferrero',
        sku: 'NUT-400',
        barcode: '3017620422003',
        imageUrl: 'https://images.openfoodfacts.org/front.jpg',
        price: 349.0,
        stock: 50,
        taxRate: 18.0,
        category: 'Groceries',
        createdAt: now,
        updatedAt: now,
      );

      final map = product.toMap();
      expect(map['brand'], equals('Ferrero'));
      expect(map['imageUrl'], equals('https://images.openfoodfacts.org/front.jpg'));
      expect(map['barcode'], equals('3017620422003'));

      final restored = Product.fromMap(map, 'p_101');
      expect(restored.brand, equals('Ferrero'));
      expect(restored.imageUrl, equals('https://images.openfoodfacts.org/front.jpg'));
      expect(restored.barcode, equals('3017620422003'));
      expect(restored.price, equals(349.0));
    });

    test('Open Food Facts API mock parsing for known barcode', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('3017620422003.json'));
        expect(request.headers['User-Agent'], contains('BillWave'));

        final responseBody = jsonEncode({
          'status': 1,
          'status_verbose': 'product found',
          'product': {
            'code': '3017620422003',
            'product_name': 'Nutella',
            'brands': 'Ferrero, Nutella',
            'categories': 'Breakfasts, Cocoa and hazelnuts spreads',
            'image_front_url':
                'https://images.openfoodfacts.org/front_en.jpg',
          },
        });

        return http.Response(responseBody, 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final result = await BarcodeLookupService.instance.lookup(
        'mock_uid',
        ' 3017620422003 ',
        client: mockClient,
      );

      expect(result.foundInOpenFoodFacts, isTrue);
      expect(result.barcode, equals('3017620422003'));
      expect(result.name, equals('Nutella'));
      expect(result.brand, equals('Ferrero'));
      expect(result.imageUrl, equals('https://images.openfoodfacts.org/front_en.jpg'));
      expect(result.hasDetails, isTrue);
      // Selling price and stock must NEVER be populated from lookup
      expect(result.existingProduct, isNull);
    });

    test('Open Food Facts API mock handles unknown barcode gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 0,
            'status_verbose': 'product not found',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final result = await BarcodeLookupService.instance.lookup(
        'mock_uid',
        '0000000000000',
        client: mockClient,
      );

      expect(result.foundInOpenFoodFacts, isFalse);
      expect(result.errorMessage, contains('not found in online catalog'));
    });

    test('Open Food Facts API mock handles HTTP 429 rate limit', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Too many requests', 429);
      });

      final result = await BarcodeLookupService.instance.lookup(
        'mock_uid',
        '8901030865412',
        client: mockClient,
      );

      expect(result.isRateLimited, isTrue);
      expect(result.errorMessage, contains('rate limit'));
    });
  });

  group('CartService Unit Tests - Synchronized Active Bill Workflow', () {
    setUp(() {
      CartService.instance.clear();
    });

    test('Add product to empty cart creates line item', () {
      final product = Product(
        id: 'p1',
        name: 'Organic Milk 1L',
        price: 60.0,
        stock: 10,
        taxRate: 5.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final res = CartService.instance.addProduct(product, quantity: 2);
      expect(res.isSuccess, isTrue);
      expect(res.status, equals(AddToCartStatus.added));
      expect(CartService.instance.itemCount, equals(1));
      expect(CartService.instance.totalQuantity, equals(2));
      expect(CartService.instance.subtotal, equals(120.0));
      expect(CartService.instance.grandTotal, closeTo(126.0, 0.01));
    });

    test('Adding same product increments quantity without duplicate lines', () {
      final product = Product(
        id: 'p1',
        name: 'Organic Milk 1L',
        price: 60.0,
        stock: 10,
        taxRate: 5.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      CartService.instance.addProduct(product, quantity: 2);
      final res2 = CartService.instance.addProduct(product, quantity: 3);

      expect(res2.isSuccess, isTrue);
      expect(res2.status, equals(AddToCartStatus.quantityUpdated));
      expect(CartService.instance.itemCount, equals(1));
      expect(CartService.instance.totalQuantity, equals(5));
      expect(CartService.instance.items.first.quantity, equals(5));
    });

    test('Cannot add out of stock product', () {
      final product = Product(
        id: 'p2',
        name: 'Fresh Bread',
        price: 40.0,
        stock: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final res = CartService.instance.addProduct(product);
      expect(res.isSuccess, isFalse);
      expect(res.status, equals(AddToCartStatus.outOfStock));
      expect(CartService.instance.isEmpty, isTrue);
    });

    test('Cannot exceed product available stock', () {
      final product = Product(
        id: 'p3',
        name: 'Limited Edition Mug',
        price: 250.0,
        stock: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      CartService.instance.addProduct(product, quantity: 2);
      final res = CartService.instance.addProduct(product, quantity: 2);

      expect(res.isSuccess, isFalse);
      expect(res.status, equals(AddToCartStatus.maxStockReached));
      expect(CartService.instance.totalQuantity, equals(2));
    });

    test('Quantity update reduces or removes item when reaching 0', () {
      final product = Product(
        id: 'p4',
        name: 'Notebook',
        price: 50.0,
        stock: 20,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      CartService.instance.addProduct(product, quantity: 2);
      CartService.instance.updateQuantity(0, -1);
      expect(CartService.instance.items.first.quantity, equals(1));

      CartService.instance.updateQuantity(0, -1);
      expect(CartService.instance.isEmpty, isTrue);
    });

    test('Clear active bill clears items, customer, discount and notes', () {
      final product = Product(
        id: 'p5',
        name: 'Pen',
        price: 20.0,
        stock: 50,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      CartService.instance.addProduct(product, quantity: 3);
      CartService.instance.updateCustomer(
        CustomerDetails(name: 'John Doe', phone: '9876543210'),
      );
      CartService.instance.updateOverallDiscount(10.0);
      CartService.instance.updateNotes('Table 4');

      expect(CartService.instance.isNotEmpty, isTrue);
      expect(CartService.instance.customer.name, equals('John Doe'));

      CartService.instance.clear();

      expect(CartService.instance.isEmpty, isTrue);
      expect(CartService.instance.itemCount, equals(0));
      expect(CartService.instance.customer.name, isEmpty);
      expect(CartService.instance.overallDiscountPercent, equals(0.0));
      expect(CartService.instance.notes, isEmpty);
      expect(CartService.instance.grandTotal, equals(0.0));
    });

    test('Badge count convention remains synchronized across additions and quantity updates', () {
      final p1 = Product(
        id: 'item_1',
        name: 'Item 1',
        price: 100.0,
        stock: 50,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final p2 = Product(
        id: 'item_2',
        name: 'Item 2',
        price: 200.0,
        stock: 50,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Empty: badge count is 0
      expect(CartService.instance.itemCount, equals(0));
      expect(CartService.instance.isEmpty, isTrue);

      // Add item 1: badge count is 1
      CartService.instance.addProduct(p1, quantity: 1);
      expect(CartService.instance.itemCount, equals(1));
      expect(CartService.instance.totalQuantity, equals(1));

      // Add item 2: badge count is 2
      CartService.instance.addProduct(p2, quantity: 1);
      expect(CartService.instance.itemCount, equals(2));
      expect(CartService.instance.totalQuantity, equals(2));

      // Increase quantity of item 1: item count remains 2, total quantity increases to 4
      CartService.instance.addProduct(p1, quantity: 2);
      expect(CartService.instance.itemCount, equals(2));
      expect(CartService.instance.totalQuantity, equals(4));

      // Remove item 2: badge count decreases to 1
      CartService.instance.removeItem(1);
      expect(CartService.instance.itemCount, equals(1));
      expect(CartService.instance.totalQuantity, equals(3));

      // Clear cart: badge count is 0
      CartService.instance.clear();
      expect(CartService.instance.itemCount, equals(0));
      expect(CartService.instance.totalQuantity, equals(0));
      expect(CartService.instance.isEmpty, isTrue);
    });
  });

  group('Product Model & Edit Workflow Unit Tests', () {
    test('Product toUpdateMap excludes createdAt to satisfy Firestore security rules', () {
      final product = Product(
        id: 'prod_edit_1',
        name: 'Wireless Keyboard',
        price: 1500.0,
        stock: 25,
        taxRate: 18.0,
        category: 'Electronics',
        createdAt: DateTime(2025, 1, 1, 10, 0),
        updatedAt: DateTime(2025, 1, 1, 10, 0),
      );

      final updateMap = product.toUpdateMap();
      expect(updateMap.containsKey('createdAt'), isFalse,
          reason: 'createdAt must never be in update map to prevent immutable field violations');
      expect(updateMap.containsKey('updatedAt'), isTrue);
      expect(updateMap['name'], equals('Wireless Keyboard'));
      expect(updateMap['taxRate'], equals(18.0));
      expect(updateMap['category'], equals('Electronics'));
    });

    test('Editing only category updates category and preserves all other fields', () {
      final orig = Product(
        id: 'prod_edit_2',
        name: 'Cold Pressed Coconut Oil',
        sku: 'OIL-100',
        barcode: '8901234567890',
        price: 320.0,
        stock: 40,
        taxRate: 5.0,
        category: 'General',
        brand: 'NatureFresh',
        imageUrl: 'https://example.com/oil.png',
        createdAt: DateTime(2025, 2, 1),
        updatedAt: DateTime(2025, 2, 1),
      );

      final edited = orig.copyWith(category: 'Groceries');
      final updateMap = edited.toUpdateMap();

      expect(updateMap['category'], equals('Groceries'));
      expect(updateMap['taxRate'], equals(5.0));
      expect(updateMap['name'], equals(orig.name));
      expect(updateMap['sku'], equals(orig.sku));
      expect(updateMap['barcode'], equals(orig.barcode));
      expect(updateMap['price'], equals(orig.price));
      expect(updateMap['stock'], equals(orig.stock));
      expect(updateMap['brand'], equals(orig.brand));
      expect(updateMap['imageUrl'], equals(orig.imageUrl));
      expect(updateMap.containsKey('createdAt'), isFalse);
    });

    test('Editing only tax rate updates tax rate and preserves all other fields', () {
      final orig = Product(
        id: 'prod_edit_3',
        name: 'Fresh Juice',
        price: 80.0,
        stock: 15,
        taxRate: 0.0,
        category: 'Beverages',
        createdAt: DateTime(2025, 2, 1),
        updatedAt: DateTime(2025, 2, 1),
      );

      final edited = orig.copyWith(taxRate: 12.0);
      final updateMap = edited.toUpdateMap();

      expect(updateMap['taxRate'], equals(12.0));
      expect(updateMap['category'], equals('Beverages'));
      expect(updateMap['name'], equals(orig.name));
      expect(updateMap['price'], equals(orig.price));
      expect(updateMap.containsKey('createdAt'), isFalse);
    });

    test('Editing both category and tax rate together updates both', () {
      final orig = Product(
        id: 'prod_edit_4',
        name: 'Organic Honey',
        price: 450.0,
        stock: 20,
        taxRate: 0.0,
        category: 'General',
        createdAt: DateTime(2025, 2, 1),
        updatedAt: DateTime(2025, 2, 1),
      );

      final edited = orig.copyWith(category: 'Groceries', taxRate: 5.0);
      final updateMap = edited.toUpdateMap();

      expect(updateMap['category'], equals('Groceries'));
      expect(updateMap['taxRate'], equals(5.0));
    });

    test('Product.fromMap safely parses legacy, missing, and string-typed fields without crashing', () {
      final legacyMap = <String, dynamic>{
        'name': 'Legacy Biscuit',
        'price': '45.50', // String price from legacy data
        'stock': '10', // String stock
        'taxRate': '18', // String tax rate
        'category': null, // Null category
        // missing sku, barcode, brand, imageUrl, createdAt, updatedAt
      };

      final parsed = Product.fromMap(legacyMap, 'legacy_1');

      expect(parsed.id, equals('legacy_1'));
      expect(parsed.name, equals('Legacy Biscuit'));
      expect(parsed.price, equals(45.50));
      expect(parsed.stock, equals(10));
      expect(parsed.taxRate, equals(18.0));
      expect(parsed.category, equals('General'));
      expect(parsed.sku, isEmpty);
      expect(parsed.barcode, isEmpty);
      expect(parsed.brand, isEmpty);
      expect(parsed.imageUrl, isEmpty);
      expect(parsed.createdAt, isNotNull);
      expect(parsed.updatedAt, isNotNull);
    });

    test('Product field bounds sanitization clamps values within Firestore rule limits', () {
      final overBounds = Product(
        id: 'overflow_1',
        name: 'A' * 300, // over 200 chars
        sku: 'S' * 150, // over 100 chars
        barcode: 'B' * 150, // over 100 chars
        category: 'C' * 150, // over 100 chars
        brand: 'D' * 150, // over 100 chars
        imageUrl: 'http://${'x' * 1200}', // over 1000 chars
        price: -50.0, // negative price
        stock: -10, // negative stock
        taxRate: 150.0, // over 100% tax
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = overBounds.toMap();
      expect((map['name'] as String).length, equals(200));
      expect((map['sku'] as String).length, equals(100));
      expect((map['barcode'] as String).length, equals(100));
      expect((map['category'] as String).length, equals(100));
      expect((map['brand'] as String).length, equals(100));
      expect((map['imageUrl'] as String).length, equals(1000));
      expect(map['price'], equals(0.0));
      expect(map['stock'], equals(0));
      expect(map['taxRate'], equals(100.0));
    });
  });

  group('Barcode Billing Formulas', () {
    test('Barcode item line billing formulas adhere strictly to tax specification', () {
      // Line subtotal = unit price * quantity
      // Line tax = line subtotal * tax rate / 100
      // Line total = line subtotal + line tax
      const unitPrice = 120.0; // Shampoo
      const qty = 3;
      const taxRate = 18.0;

      final item = InvoiceItem(
        name: 'Shampoo',
        unitPrice: unitPrice,
        quantity: qty,
        taxRate: taxRate,
      );

      expect(item.lineSubtotal, equals(360.0));
      expect(item.lineTax, closeTo(64.8, 0.001));
      expect(item.lineTotal, closeTo(424.8, 0.001));
    });

    test('All 10 sample barcode products adhere to exact schema, string preservation, and cart calculation', () {
      final sampleProducts = [
        {'name': 'Detergent', 'barcode': '8901030123456', 'category': 'Household', 'price': 100.0, 'stock': 35, 'taxRate': 18.0},
        {'name': 'Soap', 'barcode': '8901030895458', 'category': 'Personal Care', 'price': 40.0, 'stock': 50, 'taxRate': 5.0},
        {'name': 'Bottled Water', 'barcode': '8901058001234', 'category': 'Beverages', 'price': 20.0, 'stock': 80, 'taxRate': 0.0},
        {'name': 'Rice 1 kg', 'barcode': '8901063012345', 'category': 'Grocery', 'price': 75.0, 'stock': 60, 'taxRate': 5.0},
        {'name': 'Shampoo', 'barcode': '8901491101205', 'category': 'Personal Care', 'price': 120.0, 'stock': 30, 'taxRate': 18.0},
        {'name': 'Chocolate', 'barcode': '8901571001234', 'category': 'Snacks', 'price': 50.0, 'stock': 40, 'taxRate': 18.0},
        {'name': 'Toothpaste', 'barcode': '8901719100012', 'category': 'Personal Care', 'price': 65.0, 'stock': 40, 'taxRate': 18.0},
        {'name': 'Biscuits', 'barcode': '8901725000018', 'category': 'Snacks', 'price': 30.0, 'stock': 100, 'taxRate': 5.0},
        {'name': 'Coffee Powder', 'barcode': '8901725901234', 'category': 'Beverages', 'price': 95.0, 'stock': 20, 'taxRate': 5.0},
        {'name': 'Cooking Oil 1 L', 'barcode': '8901764012340', 'category': 'Grocery', 'price': 150.0, 'stock': 25, 'taxRate': 5.0},
      ];

      for (final rawData in sampleProducts) {
        final p = Product.fromMap({
          'name': rawData['name'],
          'barcode': rawData['barcode'],
          'category': rawData['category'],
          'price': rawData['price'],
          'stock': rawData['stock'],
          'taxRate': rawData['taxRate'],
        }, rawData['barcode'] as String);

        expect(p.barcode, equals(rawData['barcode']));
        expect(p.barcode, isA<String>());
        expect(p.name, equals(rawData['name']));
        expect(p.category, equals(rawData['category']));
        expect(p.price, equals(rawData['price']));
        expect(p.stock, equals(rawData['stock']));
        expect(p.taxRate, equals(rawData['taxRate']));

        // Verify line item calculation
        final item = InvoiceItem(
          name: p.name,
          unitPrice: p.price,
          quantity: 2,
          taxRate: p.taxRate,
        );
        final expectedSubtotal = (rawData['price'] as double) * 2;
        final expectedTax = expectedSubtotal * (rawData['taxRate'] as double) / 100;
        expect(item.lineSubtotal, equals(expectedSubtotal));
        expect(item.lineTax, closeTo(expectedTax, 0.001));
        expect(item.lineTotal, closeTo(expectedSubtotal + expectedTax, 0.001));
      }
    });
  });
}
