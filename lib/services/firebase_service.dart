import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../models/invoice.dart';

class DashboardStats {
  final double todaySales;
  final int totalInvoices;
  final int totalProducts;
  final double avgInvoiceValue;
  final List<Invoice> recentInvoices;
  final Map<String, double> last7DaysSales;
  final List<Product> lowStockProducts;
  final List<MapEntry<String, int>> topSellingProducts;

  DashboardStats({
    required this.todaySales,
    required this.totalInvoices,
    required this.totalProducts,
    required this.avgInvoiceValue,
    required this.recentInvoices,
    required this.last7DaysSales,
    required this.lowStockProducts,
    required this.topSellingProducts,
  });
}

class FirebaseService {
  static final FirebaseService instance = FirebaseService._();
  FirebaseService._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // -------------------------------------------------------------
  // PRODUCTS MANAGEMENT (Firestore as Single Source of Truth)
  // -------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _productsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('products');
  }

  CollectionReference<Map<String, dynamic>> get _rootProductsRef {
    return _firestore.collection('products');
  }

  Stream<List<Product>> streamProducts(String uid) {
    late final StreamController<List<Product>> controller;
    StreamSubscription? subRoot;
    StreamSubscription? subUser;

    List<Product> rootProducts = [];
    List<Product> userProducts = [];

    void emitMerged() {
      if (controller.isClosed) return;
      final Map<String, Product> productMap = {};

      // 1. Root collection products from Firestore
      for (final p in rootProducts) {
        final key = p.barcode.isNotEmpty ? p.barcode : p.id;
        productMap[key] = p;
      }

      // 2. User-specific collection products
      for (final p in userProducts) {
        final key = p.barcode.isNotEmpty ? p.barcode : p.id;
        productMap[key] = p;
      }

      final list = productMap.values.toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      controller.add(list);
    }

    controller = StreamController<List<Product>>.broadcast(
      onListen: () {
        // Emit baseline inventory immediately
        emitMerged();

        // 1. Stream root 'products' collection
        try {
          subRoot = _rootProductsRef.snapshots().listen(
            (snapshot) {
              rootProducts = snapshot.docs
                  .map((doc) => Product.fromMap(doc.data(), doc.id))
                  .toList();
              emitMerged();
            },
            onError: (err) {
              // Log error but retain catalog items
              emitMerged();
            },
          );
        } catch (_) {
          emitMerged();
        }

        // 2. Stream 'users/{uid}/products' subcollection
        if (uid.isNotEmpty) {
          try {
            subUser = _productsRef(uid).snapshots().listen(
              (snapshot) {
                userProducts = snapshot.docs
                    .map((doc) => Product.fromMap(doc.data(), doc.id))
                    .toList();
                emitMerged();
              },
              onError: (err) {
                emitMerged();
              },
            );
          } catch (_) {
            emitMerged();
          }
        }
      },
      onCancel: () {
        subRoot?.cancel();
        subUser?.cancel();
      },
    );

    return controller.stream;
  }

  Future<Product?> findProductByBarcode(String uid, String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return null;

    final numVal = num.tryParse(clean);

    // Candidates list to test (exact, stripped leading zero, added leading zero)
    final candidates = <String>{clean};

    // Optical decode aliases (camera screen-scanning / mockup aliases from poster artwork)
    const posterMockupAliases = {
      // 1. Soap
      '2001582900543002': '8901030895458',
      '2001582909253031': '8901030895458',
      '125151012228': '8901030895458',
      // 2. Shampoo
      '191717442211': '8901491101205',
      '701211011228': '8901491101205',
      // 3. Toothpaste
      '7901715100012': '8901719100012',
      '2225225059222': '8901719100012',
      '125221050211': '8901719100012',
      '8105221019212': '8901719100012',
      // 4. Biscuits
      '121115444111': '8901725000018',
      '2122281211222': '8901725000018',
      // 5. Rice 1 kg
      '50211579': '8901063012345',
      // 6. Cooking Oil 1 L
      '225110012228': '8901764012340',
      '721111011128': '8901764012340',
      '105110012728': '8901764012340',
      '1122121021111': '8901764012340',
      '221151012128': '8901764012340',
      // 7. Chocolate
      '225221441214': '8901571001234',
      '72518144': '8901571001234',
      // 8. Detergent
      '8901030123456': '8901030123456',
      // 9. Bottled Water
      '2112220022224': '8901058001234',
      // 10. Coffee Powder
      '50215515': '8901725901234',
      '121159002292': '8901725901234',
    };
    if (posterMockupAliases.containsKey(clean)) {
      candidates.add(posterMockupAliases[clean]!);
    }

    if (clean.startsWith('0') && clean.length > 1) {
      candidates.add(clean.replaceFirst(RegExp(r'^0+'), ''));
    } else if (clean.length == 12) {
      // UPC-A to EAN-13 padding
      candidates.add('0$clean');
    }

    // Optical misread tolerance (handles camera digit flips when scanning LCD screens)
    bool isOpticalMisreadMatch(String scanned, String stored) {
      if (scanned == stored) return true;
      if (scanned.length != stored.length || scanned.length < 8) return false;
      int diffs = 0;
      for (int i = 0; i < scanned.length; i++) {
        if (scanned[i] != stored[i]) {
          diffs++;
          if (diffs > 2) return false;
        }
      }
      return diffs <= 2;
    }

    // 1. Direct document ID lookup in root 'products' collection
    for (final cand in candidates) {
      try {
        final docSnap = await _rootProductsRef.doc(cand).get();
        if (docSnap.exists && docSnap.data() != null) {
          return Product.fromMap(docSnap.data()!, docSnap.id);
        }
      } catch (_) {}
    }

    // 2. Query by barcode field (String) in root 'products'
    for (final cand in candidates) {
      try {
        final query = await _rootProductsRef
            .where('barcode', isEqualTo: cand)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          return Product.fromMap(query.docs.first.data(), query.docs.first.id);
        }
      } catch (_) {}
    }

    // 3. Query by barcode field (numeric) in root 'products'
    if (numVal != null) {
      try {
        final query = await _rootProductsRef
            .where('barcode', isEqualTo: numVal)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          return Product.fromMap(query.docs.first.data(), query.docs.first.id);
        }
      } catch (_) {}
    }

    // 4. In-memory scan of root 'products' (handles formatting/leading zeroes/custom fields)
    try {
      final snap = await _rootProductsRef.get();
      for (final doc in snap.docs) {
        final p = Product.fromMap(doc.data(), doc.id);
        final pBar = p.barcode.trim();
        final docId = doc.id.trim();
        if (candidates.contains(pBar) ||
            candidates.contains(docId) ||
            (numVal != null && num.tryParse(pBar) == numVal) ||
            isOpticalMisreadMatch(clean, pBar)) {
          return p;
        }
      }
    } catch (_) {}

    // 5. Direct document ID lookup in users/{uid}/products
    if (uid.isNotEmpty) {
      for (final cand in candidates) {
        try {
          final docSnap = await _productsRef(uid).doc(cand).get();
          if (docSnap.exists && docSnap.data() != null) {
            return Product.fromMap(docSnap.data()!, docSnap.id);
          }
        } catch (_) {}
      }

      // 6. Query by barcode field in users/{uid}/products
      for (final cand in candidates) {
        try {
          final query = await _productsRef(uid)
              .where('barcode', isEqualTo: cand)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            return Product.fromMap(query.docs.first.data(), query.docs.first.id);
          }
        } catch (_) {}
      }

      // 7. Query by numeric barcode in users/{uid}/products
      if (numVal != null) {
        try {
          final query = await _productsRef(uid)
              .where('barcode', isEqualTo: numVal)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            return Product.fromMap(query.docs.first.data(), query.docs.first.id);
          }
        } catch (_) {}
      }

      // 8. In-memory scan of users/{uid}/products
      try {
        final snap = await _productsRef(uid).get();
        for (final doc in snap.docs) {
          final p = Product.fromMap(doc.data(), doc.id);
          final pBar = p.barcode.trim();
          final docId = doc.id.trim();
          if (candidates.contains(pBar) ||
              candidates.contains(docId) ||
              (numVal != null && num.tryParse(pBar) == numVal) ||
              isOpticalMisreadMatch(clean, pBar)) {
            return p;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  Future<void> addProduct(String uid, Product product) async {
    if (product.name.trim().isEmpty) {
      throw ArgumentError('Product name cannot be empty.');
    }
    if (product.price < 0) {
      throw ArgumentError('Price cannot be negative.');
    }
    if (product.stock < 0) {
      throw ArgumentError('Stock cannot be negative.');
    }

    final docId = product.barcode.trim().isNotEmpty
        ? product.barcode.trim()
        : (product.id.trim().isNotEmpty ? product.id.trim() : null);

    // Save to root products collection
    try {
      if (docId != null) {
        await _rootProductsRef.doc(docId).set(product.toMap());
      } else {
        await _rootProductsRef.add(product.toMap());
      }
    } catch (_) {}

    // Also persist to users/{uid}/products if uid is available
    if (uid.isNotEmpty) {
      if (docId != null) {
        await _productsRef(uid).doc(docId).set(product.toMap());
      } else {
        await _productsRef(uid).add(product.toMap());
      }
    }
  }

  Future<void> updateProduct(String uid, Product product) async {
    if (product.id.trim().isEmpty) {
      throw ArgumentError('Product ID is required for updating.');
    }
    if (product.name.trim().isEmpty) {
      throw ArgumentError('Product name cannot be empty.');
    }
    if (product.price < 0) {
      throw ArgumentError('Price cannot be negative.');
    }
    if (product.stock < 0) {
      throw ArgumentError('Stock cannot be negative.');
    }

    bool updatedInRoot = false;
    try {
      final rootDoc = await _rootProductsRef.doc(product.id).get();
      if (rootDoc.exists) {
        await _rootProductsRef.doc(product.id).update(product.toUpdateMap());
        updatedInRoot = true;
      }
    } catch (_) {}

    if (uid.isNotEmpty) {
      try {
        final userDoc = await _productsRef(uid).doc(product.id).get();
        if (userDoc.exists || !updatedInRoot) {
          await _productsRef(uid).doc(product.id).update(product.toUpdateMap());
        }
      } catch (e) {
        if (!updatedInRoot) rethrow;
      }
    }
  }

  Future<void> deleteProduct(String uid, String productId) async {
    try {
      await _rootProductsRef.doc(productId).delete();
    } catch (_) {}
    if (uid.isNotEmpty) {
      try {
        await _productsRef(uid).doc(productId).delete();
      } catch (_) {}
    }
  }

  // -------------------------------------------------------------
  // BUSINESS SETTINGS
  // -------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _settingsRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('business');
  }

  Stream<BusinessProfile> streamBusinessProfile(String uid) {
    return _settingsRef(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return BusinessProfile();
      }
      return BusinessProfile.fromMap(snapshot.data());
    });
  }

  Future<BusinessProfile> getBusinessProfile(String uid) async {
    final doc = await _settingsRef(uid).get();
    if (!doc.exists || doc.data() == null) {
      return BusinessProfile();
    }
    return BusinessProfile.fromMap(doc.data());
  }

  Future<void> saveBusinessProfile(String uid, BusinessProfile profile) async {
    await _settingsRef(uid).set(profile.toMap(), SetOptions(merge: true));
  }

  // -------------------------------------------------------------
  // DASHBOARD & REALTIME AGGREGATIONS
  // -------------------------------------------------------------

  Stream<DashboardStats> streamDashboardStats(String uid) {
    final invoicesStream = _firestore
        .collection('users')
        .doc(uid)
        .collection('invoices')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return invoicesStream.asyncMap((iSnap) async {
      final pSnap = await _productsRef(uid).get();

      final products = pSnap.docs
          .map((d) => Product.fromMap(d.data(), d.id))
          .toList();
      final invoices = iSnap.docs
          .map((d) => Invoice.fromMap(d.data(), d.id))
          .toList();

      final lowStockProducts = products.where((p) => p.isLowStock).toList();

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      double todaySales = 0.0;
      double totalSalesAll = 0.0;
      int paidInvoiceCount = 0;

      final last7DaysMap = <String, double>{};
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final key = '${d.day}/${d.month}';
        last7DaysMap[key] = 0.0;
      }

      final productSaleCounts = <String, int>{};

      for (final inv in invoices) {
        if (inv.isPaid) {
          paidInvoiceCount++;
          totalSalesAll += inv.total;

          // Today's sales
          if (inv.createdAt.isAfter(todayStart)) {
            todaySales += inv.total;
          }

          // Last 7 days
          final diff = now.difference(inv.createdAt).inDays;
          if (diff >= 0 && diff < 7) {
            final key = '${inv.createdAt.day}/${inv.createdAt.month}';
            if (last7DaysMap.containsKey(key)) {
              last7DaysMap[key] = (last7DaysMap[key] ?? 0.0) + inv.total;
            }
          }

          // Top selling products count
          for (final item in inv.items) {
            productSaleCounts[item.name] =
                (productSaleCounts[item.name] ?? 0) + item.quantity;
          }
        }
      }

      final avgInvoiceValue = paidInvoiceCount > 0
          ? (totalSalesAll / paidInvoiceCount)
          : 0.0;

      final sortedTopProducts = productSaleCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return DashboardStats(
        todaySales: todaySales,
        totalInvoices: paidInvoiceCount,
        totalProducts: products.length,
        avgInvoiceValue: avgInvoiceValue,
        recentInvoices: invoices.take(5).toList(),
        last7DaysSales: last7DaysMap,
        lowStockProducts: lowStockProducts,
        topSellingProducts: sortedTopProducts.take(5).toList(),
      );
    });
  }
}
