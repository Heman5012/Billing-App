import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import 'dart:convert';

import '../models/invoice.dart';

class InvoiceService {
  static final InvoiceService instance = InvoiceService._();
  InvoiceService._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final Set<String> _inFlightCheckouts = {};

  CollectionReference<Map<String, dynamic>> _invoicesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('invoices');
  }

  CollectionReference<Map<String, dynamic>> get _publicInvoicesRef {
    return _firestore.collection('public_invoices');
  }

  /// Generate a human-readable unique invoice number like INV-20261028-4821
  String generateInvoiceNumber() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomPart = (Random().nextInt(9000) + 1000).toString();
    return 'INV-$dateStr-$randomPart';
  }

  /// Generate an unguessable secure token for public QR code retrieval
  String generateSecureShareToken(String invoiceNumber, String uid) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final randomInt = Random.secure().nextInt(1000000);
    final raw = '$invoiceNumber-$uid-$nowMs-$randomInt';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 32);
  }

  /// Atomic transaction checkout:
  /// 1. Prevents duplicate button presses via inFlight guard
  /// 2. Reads catalog products and verifies available stock
  /// 3. Decrements stock safely
  /// 4. Writes the invoice under users/{uid}/invoices/{invoiceId}
  /// 5. Writes a sanitized public record under public_invoices/{shareToken}
  Future<Invoice> createInvoiceWithTransaction({
    required String uid,
    required CustomerDetails customer,
    required List<InvoiceItem> items,
    required double overallDiscountPercent,
    required String paymentMethod,
    required String businessName,
    String notes = '',
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Cannot checkout with an empty cart.');
    }

    // Checkout idempotency check: generate unique client checkout token
    final invoiceNumber = generateInvoiceNumber();
    if (_inFlightCheckouts.contains(invoiceNumber)) {
      throw StateError('This checkout is already in progress. Please wait.');
    }
    _inFlightCheckouts.add(invoiceNumber);

    try {
      final now = DateTime.now();
      final shareToken = generateSecureShareToken(invoiceNumber, uid);

      // Calculations
      double subtotal = 0.0;
      double taxableTotal = 0.0;
      double taxTotal = 0.0;
      final taxBreakdown = <String, double>{};

      for (final item in items) {
        if (item.unitPrice < 0 || item.quantity <= 0) {
          throw ArgumentError('Invalid item price or quantity in cart.');
        }
        subtotal += item.lineSubtotal;
        taxableTotal += item.lineTaxable;
        taxTotal += item.lineTax;

        final rateKey = '${item.taxRate.toStringAsFixed(0)}%';
        taxBreakdown[rateKey] = (taxBreakdown[rateKey] ?? 0.0) + item.lineTax;
      }

      // Overall discount
      final overallDiscountAmount =
          taxableTotal * (overallDiscountPercent / 100.0);
      final finalTaxable = taxableTotal - overallDiscountAmount;
      // Adjust tax proportionally if overall discount is applied
      final discountFactor = taxableTotal > 0
          ? (finalTaxable / taxableTotal)
          : 1.0;
      final finalTax = taxTotal * discountFactor;

      final updatedBreakdown = <String, double>{};
      taxBreakdown.forEach((rate, amt) {
        updatedBreakdown[rate] = amt * discountFactor;
      });

      final total = finalTaxable + finalTax;

      // Prepare invoice document reference
      final invoiceDocRef = _invoicesRef(uid).doc();
      final publicDocRef = _publicInvoicesRef.doc(shareToken);

      // Execute atomic Firestore transaction
      await _firestore.runTransaction((transaction) async {
        // Collect all catalog product IDs to update stock
        final catalogItems = items
            .where((i) => i.productId != null && i.productId!.isNotEmpty)
            .toList();
        final productDocRefs =
            <String, DocumentReference<Map<String, dynamic>>>{};
        final productSnapshots =
            <String, DocumentSnapshot<Map<String, dynamic>>>{};

        for (final item in catalogItems) {
          final pRef = _firestore
              .collection('users')
              .doc(uid)
              .collection('products')
              .doc(item.productId);
          productDocRefs[item.productId!] = pRef;
          productSnapshots[item.productId!] = await transaction.get(pRef);
        }

        // Validate stock for all catalog items inside transaction
        for (final item in catalogItems) {
          final snap = productSnapshots[item.productId!];
          if (snap != null && snap.exists) {
            final currentStock = (snap.data()?['stock'] as num?)?.toInt() ?? 0;
            if (currentStock < item.quantity) {
              throw StateError(
                'Insufficient stock for "${item.name}". Available: $currentStock, Requested: ${item.quantity}',
              );
            }
          }
        }

        // Decrement stock for each catalog item
        for (final item in catalogItems) {
          final snap = productSnapshots[item.productId!];
          if (snap != null && snap.exists) {
            final currentStock = (snap.data()?['stock'] as num?)?.toInt() ?? 0;
            final newStock = currentStock - item.quantity;
            transaction.update(productDocRefs[item.productId!]!, {
              'stock': newStock,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        final invoiceObj = Invoice(
          id: invoiceDocRef.id,
          invoiceNumber: invoiceNumber,
          userId: uid,
          customer: customer,
          items: items,
          subtotal: subtotal,
          overallDiscountPercent: overallDiscountPercent,
          overallDiscountAmount: overallDiscountAmount,
          taxableAmount: finalTaxable,
          tax: finalTax,
          taxBreakdown: updatedBreakdown,
          total: total,
          paymentMethod: paymentMethod,
          paymentStatus: 'paid',
          transactionMode: 'SIMULATED / DEMO',
          notes: notes,
          createdAt: now,
          shareToken: shareToken,
        );

        // Save Invoice under user records
        transaction.set(invoiceDocRef, invoiceObj.toMap());

        // Also write to users/{uid}/bills and root bills for full dual collection compatibility
        final userBillRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('bills')
            .doc(invoiceDocRef.id);
        final rootBillRef = _firestore.collection('bills').doc(invoiceDocRef.id);
        final billRecord = {
          'billId': invoiceDocRef.id,
          'invoiceNumber': invoiceNumber,
          'userId': uid,
          'customer': customer.toMap(),
          'items': items
              .map((i) => {
                    'productId': i.productId ?? '',
                    'name': i.name,
                    'unitPrice': i.unitPrice,
                    'quantity': i.quantity,
                    'taxRate': i.taxRate,
                    'lineSubtotal': i.lineSubtotal,
                    'lineTax': i.lineTax,
                    'lineTotal': i.lineTotal,
                  })
              .toList(),
          'subtotal': subtotal,
          'tax': finalTax,          // matches isValidBill field 'tax'
          'total': total,           // matches isValidBill field 'total'
          'paymentMethod': paymentMethod,
          'paymentStatus': 'paid',
          'transactionMode': 'SIMULATED / DEMO',
          'shareToken': shareToken,
          'createdAt': Timestamp.fromDate(now),
        };
        transaction.set(userBillRef, billRecord);
        transaction.set(rootBillRef, billRecord);

        // Save sanitized public record for QR retrieval
        transaction.set(publicDocRef, invoiceObj.toPublicMap(businessName));
      });

      return Invoice(
        id: invoiceDocRef.id,
        invoiceNumber: invoiceNumber,
        userId: uid,
        customer: customer,
        items: items,
        subtotal: subtotal,
        overallDiscountPercent: overallDiscountPercent,
        overallDiscountAmount: overallDiscountAmount,
        taxableAmount: finalTaxable,
        tax: finalTax,
        taxBreakdown: updatedBreakdown,
        total: total,
        paymentMethod: paymentMethod,
        paymentStatus: 'paid',
        transactionMode: 'SIMULATED / DEMO',
        notes: notes,
        createdAt: now,
        shareToken: shareToken,
      );
    } finally {
      _inFlightCheckouts.remove(invoiceNumber);
    }
  }

  /// Stream of user invoices with filtering
  Stream<List<Invoice>> streamInvoices(
    String uid, {
    String? searchQuery,
    String? paymentMethod,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query<Map<String, dynamic>> query = _invoicesRef(uid)
        .orderBy('createdAt', descending: true);

    return query.snapshots().map((snapshot) {
      var invoices = snapshot.docs
          .map((doc) => Invoice.fromMap(doc.data(), doc.id))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        invoices = invoices
            .where(
              (inv) =>
                  inv.invoiceNumber.toLowerCase().contains(q) ||
                  inv.customer.name.toLowerCase().contains(q) ||
                  inv.customer.phone.contains(q),
            )
            .toList();
      }

      if (paymentMethod != null &&
          paymentMethod.isNotEmpty &&
          paymentMethod != 'All') {
        invoices = invoices
            .where((inv) => inv.paymentMethod == paymentMethod)
            .toList();
      }

      if (status != null && status.isNotEmpty && status != 'All') {
        invoices = invoices
            .where((inv) => inv.paymentStatus == status)
            .toList();
      }

      if (startDate != null) {
        invoices = invoices
            .where((inv) => inv.createdAt.isAfter(startDate))
            .toList();
      }

      if (endDate != null) {
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        invoices = invoices
            .where((inv) => inv.createdAt.isBefore(endOfDay))
            .toList();
      }

      return invoices;
    });
  }

  /// Get public invoice by shareToken or invoiceNumber for non-signed-in QR code retrieval
  Future<Map<String, dynamic>?> getPublicInvoice(String tokenOrInvNum) async {
    final clean = tokenOrInvNum.trim();
    if (clean.isEmpty) return null;

    // 1. Try direct shareToken document ID lookup
    try {
      final doc = await _publicInvoicesRef.doc(clean).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
    } catch (_) {}

    // 2. Fallback: try searching by invoiceNumber in public_invoices
    try {
      final query = await _publicInvoicesRef
          .where('invoiceNumber', isEqualTo: clean.toUpperCase())
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
    } catch (_) {}

    // 3. Fallback: try searching in root 'bills' collection by document ID
    try {
      final doc = await _firestore.collection('bills').doc(clean).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
    } catch (_) {}

    // 4. Fallback: try searching in root 'bills' collection by invoiceNumber
    try {
      final query = await _firestore
          .collection('bills')
          .where('invoiceNumber', isEqualTo: clean.toUpperCase())
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
    } catch (_) {}

    return null;
  }

  /// Auditable status change: cancel invoice
  Future<void> cancelInvoice(
    String uid,
    String invoiceId,
    String reason,
  ) async {
    final invoiceRef = _invoicesRef(uid).doc(invoiceId);
    final doc = await invoiceRef.get();
    if (!doc.exists) {
      throw StateError('Invoice not found.');
    }
    final inv = Invoice.fromMap(doc.data()!, doc.id);

    // Update user's invoice
    await invoiceRef.update({
      'paymentStatus': 'cancelled',
      'cancellationReason': reason,
      'cancelledAt': FieldValue.serverTimestamp(),
    });

    // Update public view if token exists
    if (inv.shareToken.isNotEmpty) {
      await _publicInvoicesRef.doc(inv.shareToken).update({
        'paymentStatus': 'cancelled',
        'cancellationReason': reason,
      });
    }
  }
}
