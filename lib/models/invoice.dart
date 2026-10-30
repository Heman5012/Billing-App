import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceItem {
  final String? productId;
  final String name;
  final double unitPrice;
  final int quantity;
  final double discountPercent; // e.g., 5.0 for 5%
  final double taxRate; // e.g., 18.0 for 18%

  InvoiceItem({
    this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.discountPercent = 0.0,
    this.taxRate = 0.0,
  });

  double get lineSubtotal => unitPrice * quantity;
  double get lineDiscount => lineSubtotal * (discountPercent / 100.0);
  double get lineTaxable => lineSubtotal - lineDiscount;
  double get lineTax => lineTaxable * (taxRate / 100.0);
  double get lineTotal => lineTaxable + lineTax;

  Map<String, dynamic> toMap() {
    return {
      if (productId != null) 'productId': productId,
      'name': name,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'discountPercent': discountPercent,
      'taxRate': taxRate,
      'lineSubtotal': lineSubtotal,
      'lineDiscount': lineDiscount,
      'lineTaxable': lineTaxable,
      'lineTax': lineTax,
      'lineTotal': lineTotal,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      productId: map['productId'] as String?,
      name: map['name'] as String? ?? 'Item',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      discountPercent: (map['discountPercent'] as num?)?.toDouble() ?? 0.0,
      taxRate: (map['taxRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CustomerDetails {
  final String name;
  final String phone;
  final String email;

  CustomerDetails({this.name = '', this.phone = '', this.email = ''});

  bool get isEmpty => name.isEmpty && phone.isEmpty && email.isEmpty;
  bool get isNotEmpty => !isEmpty;

  Map<String, dynamic> toMap() {
    return {'name': name.trim(), 'phone': phone.trim(), 'email': email.trim()};
  }

  factory CustomerDetails.fromMap(Map<String, dynamic>? map) {
    if (map == null) return CustomerDetails();
    return CustomerDetails(
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
    );
  }
}

class BusinessProfile {
  final String businessName;
  final String address;
  final String phone;
  final String currency;
  final List<double> configuredTaxRates;

  BusinessProfile({
    this.businessName = 'BillWave Enterprise',
    this.address = '100 Tech Hub Avenue, Suite 400',
    this.phone = '+91 98765 43210',
    this.currency = '₹',
    this.configuredTaxRates = const [0.0, 5.0, 12.0, 18.0, 28.0],
  });

  Map<String, dynamic> toMap() {
    return {
      'businessName': businessName,
      'address': address,
      'phone': phone,
      'currency': currency,
      'configuredTaxRates': configuredTaxRates,
    };
  }

  factory BusinessProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) return BusinessProfile();
    final rawTaxes = map['configuredTaxRates'] as List<dynamic>?;
    final rates = rawTaxes != null
        ? rawTaxes.map((e) => (e as num).toDouble()).toList()
        : [0.0, 5.0, 12.0, 18.0, 28.0];

    return BusinessProfile(
      businessName: map['businessName'] as String? ?? 'BillWave Enterprise',
      address: map['address'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      currency: map['currency'] as String? ?? '₹',
      configuredTaxRates: rates,
    );
  }
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final String userId;
  final CustomerDetails customer;
  final List<InvoiceItem> items;
  final double subtotal;
  final double overallDiscountPercent;
  final double overallDiscountAmount;
  final double taxableAmount;
  final double tax;
  final Map<String, double> taxBreakdown;
  final double total;
  final String paymentMethod; // "UPI (Demo)", "Card (Demo)", "Cash (Demo)"
  final String paymentStatus; // "paid", "failed", "cancelled"
  final String transactionMode; // "SIMULATED / DEMO"
  final String notes;
  final DateTime createdAt;
  final String shareToken;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.userId,
    required this.customer,
    required this.items,
    required this.subtotal,
    this.overallDiscountPercent = 0.0,
    required this.overallDiscountAmount,
    required this.taxableAmount,
    required this.tax,
    required this.taxBreakdown,
    required this.total,
    required this.paymentMethod,
    this.paymentStatus = 'paid',
    this.transactionMode = 'SIMULATED / DEMO',
    this.notes = '',
    required this.createdAt,
    required this.shareToken,
  });

  bool get isPaid => paymentStatus == 'paid';
  bool get isCancelled => paymentStatus == 'cancelled';

  Map<String, dynamic> toMap() {
    return {
      'invoiceNumber': invoiceNumber,
      'userId': userId,
      'customer': customer.toMap(),
      'items': items.map((i) => i.toMap()).toList(),
      'subtotal': subtotal,
      'overallDiscountPercent': overallDiscountPercent,
      'overallDiscountAmount': overallDiscountAmount,
      'taxableAmount': taxableAmount,
      'tax': tax,
      'taxBreakdown': taxBreakdown,
      'total': total,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'transactionMode': transactionMode,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'shareToken': shareToken,
    };
  }

  /// Minimal sanitized public map for QR / public link retrieval without sensitive metadata
  Map<String, dynamic> toPublicMap(String businessName) {
    return {
      'invoiceNumber': invoiceNumber,
      'businessName': businessName,
      'customerName': customer.name,
      'items': items.map((i) => i.toMap()).toList(),
      'subtotal': subtotal,
      'overallDiscountAmount': overallDiscountAmount,
      'taxableAmount': taxableAmount,
      'tax': tax,
      'taxBreakdown': taxBreakdown,
      'total': total,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'transactionMode': transactionMode,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'shareToken': shareToken,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    final rawItems = map['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((e) => InvoiceItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    final rawBreakdown = map['taxBreakdown'] as Map<dynamic, dynamic>? ?? {};
    final breakdown = <String, double>{};
    rawBreakdown.forEach((k, v) {
      breakdown[k.toString()] = (v as num).toDouble();
    });

    return Invoice(
      id: id,
      invoiceNumber: map['invoiceNumber'] as String? ?? id,
      userId: map['userId'] as String? ?? '',
      customer: CustomerDetails.fromMap(
        map['customer'] != null
            ? Map<String, dynamic>.from(map['customer'] as Map)
            : null,
      ),
      items: items,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      overallDiscountPercent:
          (map['overallDiscountPercent'] as num?)?.toDouble() ?? 0.0,
      overallDiscountAmount:
          (map['overallDiscountAmount'] as num?)?.toDouble() ?? 0.0,
      taxableAmount: (map['taxableAmount'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      taxBreakdown: breakdown,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] as String? ?? 'Cash (Demo)',
      paymentStatus: map['paymentStatus'] as String? ?? 'paid',
      transactionMode: map['transactionMode'] as String? ?? 'SIMULATED / DEMO',
      notes: map['notes'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
      shareToken: map['shareToken'] as String? ?? '',
    );
  }
}
