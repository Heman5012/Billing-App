import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/invoice.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/firebase_service.dart';
import '../services/invoice_service.dart';
import '../services/pdf_service.dart';

class PublicInvoiceScreen extends StatefulWidget {
  final String? initialToken;

  const PublicInvoiceScreen({super.key, this.initialToken});

  @override
  State<PublicInvoiceScreen> createState() => _PublicInvoiceScreenState();
}

class _PublicInvoiceScreenState extends State<PublicInvoiceScreen> {
  late final TextEditingController _tokenCtrl;
  bool _isLoading = false;
  Map<String, dynamic>? _invoiceData;
  Product? _matchedProduct;
  String? _error;
  bool _isProductBarcode = false;

  @override
  void initState() {
    super.initState();
    _tokenCtrl = TextEditingController(text: widget.initialToken ?? '');
    if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      _fetchPublicInvoice(widget.initialToken!);
    }
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPublicInvoice(String token) async {
    if (token.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _isProductBarcode = false;
      _matchedProduct = null;
      _invoiceData = null;
    });

    try {
      final cleanToken = token.trim();
      final data = await InvoiceService.instance.getPublicInvoice(cleanToken);
      if (!mounted) return;

      if (data == null) {
        // Check if this token matches a product in the catalogue
        final uid = AuthService.instance.currentUser?.uid ?? '';
        final product = await FirebaseService.instance.findProductByBarcode(uid, cleanToken);
        final looksLikeBarcode = RegExp(r'^\d{4,30}$').hasMatch(cleanToken);

        setState(() {
          _matchedProduct = product;
          _isProductBarcode = looksLikeBarcode || product != null;
          if (product != null) {
            _error = null; // Found product in inventory!
          } else if (looksLikeBarcode) {
            _error = '"$cleanToken" appears to be a retail product barcode, not an invoice verification token. Product barcodes can be scanned in "Create Bill" or "Products" to bill or manage items.';
          } else {
            _error = 'No invoice found for token or ID "$cleanToken". Please check the QR code or enter a valid invoice number.';
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _invoiceData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error retrieving invoice: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.verified_outlined, color: Color(0xFF10B981), size: 20),
            SizedBox(width: 8),
            Text(
              'BillWave Invoice Verification',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                // Search token card if not loaded
                if (_invoiceData == null) ...[
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Retrieve Invoice by Token',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter the secure token printed on your invoice QR code or receipt link.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _tokenCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Invoice Retrieval Token',
                                    hintText: 'e.g. 5d41402abc4b2a76b971...',
                                    prefixIcon: const Icon(
                                      Icons.vpn_key_outlined,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onSubmitted: _fetchPublicInvoice,
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : () =>
                                          _fetchPublicInvoice(_tokenCtrl.text),
                                icon: const Icon(Icons.search),
                                label: const Text('Lookup'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 16,
                                  ),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          if (_matchedProduct != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF15803D),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Product Found in Inventory',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _matchedProduct!.category,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _matchedProduct!.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${_matchedProduct!.price.toStringAsFixed(2)}  •  ${_matchedProduct!.stock} in stock  •  Barcode: ${_matchedProduct!.barcode}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  FilledButton.icon(
                                    onPressed: () {
                                      final res = CartService.instance.addProduct(_matchedProduct!);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res.message),
                                          backgroundColor: res.isSuccess
                                              ? const Color(0xFF15803D)
                                              : Colors.orange.shade800,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      Navigator.of(context).pop();
                                    },
                                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                                    label: const Text('Add to Current Bill'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _isProductBarcode
                                    ? const Color(0xFFFFF3E0)
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _isProductBarcode
                                      ? const Color(0xFFFFB74D)
                                      : Colors.red.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        _isProductBarcode
                                            ? Icons.qr_code_2
                                            : Icons.error_outline,
                                        color: _isProductBarcode
                                            ? const Color(0xFFE65100)
                                            : Colors.red.shade700,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: TextStyle(
                                            color: _isProductBarcode
                                                ? const Color(0xFFBF360C)
                                                : Colors.red.shade800,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_isProductBarcode) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          icon: const Icon(
                                            Icons.shopping_cart_outlined,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Go to Create Bill',
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF10B981),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          icon: const Icon(
                                            Icons.inventory_2_outlined,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Go to Products',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                if (_isLoading) ...[
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ],

                // Display retrieved public invoice
                if (_invoiceData != null) ...[
                  _buildPublicInvoiceReceipt(_invoiceData!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPublicInvoiceReceipt(Map<String, dynamic> data) {
    final businessName = data['businessName'] as String? ?? 'BillWave Merchant';
    final invNumber = data['invoiceNumber'] as String? ?? 'INVOICE';
    final customerName = data['customerName'] as String? ?? '';
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0.0;
    final tax = (data['tax'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = data['paymentMethod'] as String? ?? 'Demo Payment';
    final paymentStatus = data['paymentStatus'] as String? ?? 'paid';
    final rawItems = data['items'] as List<dynamic>? ?? [];

    DateTime parseCreatedAt(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    final createdAt = parseCreatedAt(data['createdAt']);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'BillWave',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'OFFICIAL RECEIPT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      businessName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified,
                        size: 14,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Verified [${paymentStatus.toUpperCase()}]',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Invoice #: $invNumber',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  paymentMethod,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            if (customerName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Customer: $customerName',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 16),

            // Items List
            ...rawItems.map((itemMap) {
              final name = itemMap['name'] as String? ?? 'Item';
              final qty = itemMap['quantity'] ?? 1;
              final price = (itemMap['unitPrice'] as num?)?.toDouble() ?? 0.0;
              final lineTotal =
                  (itemMap['lineTotal'] as num?)?.toDouble() ?? (price * qty);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$name × $qty',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '₹${lineTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:'),
                Text('₹${subtotal.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tax:'),
                Text('₹${tax.toStringAsFixed(2)}'),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    final items = rawItems
                        .map(
                          (e) => InvoiceItem.fromMap(
                            Map<String, dynamic>.from(e as Map),
                          ),
                        )
                        .toList();
                    final invoiceObj = Invoice(
                      id: invNumber,
                      invoiceNumber: invNumber,
                      userId: '',
                      customer: CustomerDetails(name: customerName),
                      items: items,
                      subtotal: subtotal,
                      overallDiscountAmount:
                          (data['overallDiscountAmount'] as num?)?.toDouble() ??
                          0.0,
                      taxableAmount:
                          (data['taxableAmount'] as num?)?.toDouble() ??
                          subtotal,
                      tax: tax,
                      taxBreakdown: {},
                      total: total,
                      paymentMethod: paymentMethod,
                      paymentStatus: paymentStatus,
                      transactionMode: 'SIMULATED / DEMO',
                      createdAt: createdAt,
                      shareToken: widget.initialToken ?? _tokenCtrl.text.trim(),
                    );
                    final biz = BusinessProfile(businessName: businessName);
                    await PdfService.instance.shareInvoicePdf(
                      invoice: invoiceObj,
                      business: biz,
                    );
                  },
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download Official PDF'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 18,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final items = rawItems
                        .map(
                          (e) => InvoiceItem.fromMap(
                            Map<String, dynamic>.from(e as Map),
                          ),
                        )
                        .toList();
                    final invoiceObj = Invoice(
                      id: invNumber,
                      invoiceNumber: invNumber,
                      userId: '',
                      customer: CustomerDetails(name: customerName),
                      items: items,
                      subtotal: subtotal,
                      overallDiscountAmount:
                          (data['overallDiscountAmount'] as num?)?.toDouble() ??
                          0.0,
                      taxableAmount:
                          (data['taxableAmount'] as num?)?.toDouble() ??
                          subtotal,
                      tax: tax,
                      taxBreakdown: {},
                      total: total,
                      paymentMethod: paymentMethod,
                      paymentStatus: paymentStatus,
                      transactionMode: 'SIMULATED / DEMO',
                      createdAt: createdAt,
                      shareToken: widget.initialToken ?? _tokenCtrl.text.trim(),
                    );
                    final biz = BusinessProfile(businessName: businessName);
                    await PdfService.instance.printInvoice(
                      invoice: invoiceObj,
                      business: biz,
                    );
                  },
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Print / Preview PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _invoiceData = null;
                      _tokenCtrl.clear();
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Lookup Another'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
