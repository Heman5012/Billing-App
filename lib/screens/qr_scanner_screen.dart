import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/barcode_lookup_service.dart';
import '../services/cart_service.dart';
import '../services/firebase_service.dart';
import '../services/invoice_service.dart';
import 'public_invoice_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    cameraResolution: const Size(1920, 1080),
    autoZoom: true,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.itf14,
      BarcodeFormat.qrCode,
    ],
  );
  final TextEditingController _manualTokenCtrl = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    _manualTokenCtrl.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue ?? barcodes.first.displayValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _isProcessing = true;
    _parseAndOpenToken(rawValue);
  }

  Future<void> _parseAndOpenToken(String raw) async {
    String token = raw.trim();

    // 1. Extract from token= query or fragment
    if (token.contains('token=')) {
      final uri = Uri.tryParse(token);
      if (uri != null && uri.queryParameters.containsKey('token')) {
        token = uri.queryParameters['token']!;
      } else {
        final split = token.split('token=');
        if (split.length > 1) {
          token = split[1].split('&').first.split('#').first;
        }
      }
    } else if (token.startsWith('http://') || token.startsWith('https://')) {
      final uri = Uri.tryParse(token);
      if (uri != null) {
        if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty) {
          token = uri.pathSegments.last;
        } else if (uri.fragment.isNotEmpty) {
          token = uri.fragment.split('/').last;
        }
      }
    }

    token = token.trim();
    if (token.isEmpty) {
      _isProcessing = false;
      return;
    }

    final uid = AuthService.instance.currentUser?.uid ?? '';

    // 1. Check if product exists in catalogue (checks root 'products' collection & user catalogue)
    final product =
        await FirebaseService.instance.findProductByBarcode(uid, token);
    if (!mounted) return;

    if (product != null) {
      _showProductDetectedSheet(product, token);
      return;
    }

    // 2. Check if this token matches an invoice in Firestore
    final invoiceData = await InvoiceService.instance.getPublicInvoice(token);
    if (!mounted) return;

    if (invoiceData != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PublicInvoiceScreen(initialToken: token),
        ),
      );
      return;
    }

    // 3. If not in catalogue and not an existing invoice:
    // Any numeric string (6-30 digits) or non-URL string is treated as a product barcode
    final isBarcode = RegExp(r'^\d{4,30}$').hasMatch(token) || !token.contains('://');
    if (isBarcode) {
      final online = await BarcodeLookupService.instance.lookup(uid, token);
      if (!mounted) return;

      _showProductNotFoundSheet(token, online);
      return;
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PublicInvoiceScreen(initialToken: token),
      ),
    );
  }

  void _showProductDetectedSheet(Product product, String barcode) {
    int quantity = 1;

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final maxStock = product.stock;
          final isOutOfStock = product.stock <= 0;

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 20.0,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF2E7D32),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Product Found in Inventory',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                          product.category.isNotEmpty ? product.category : 'General',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          setState(() => _isProcessing = false);
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (product.brand.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Brand: ${product.brand}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.blueGrey.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E88E5),
                      ),
                    ),
                    if (product.taxRate > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '+${product.taxRate.toStringAsFixed(0)}% GST',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOutOfStock
                            ? 'Out of Stock'
                            : '${product.stock} in stock',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOutOfStock
                              ? Colors.red.shade700
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Barcode: $barcode',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Quantity selector
                Row(
                  children: [
                    const Text(
                      'Quantity:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: quantity > 1
                                ? () => setSheetState(() => quantity--)
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '$quantity',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: (maxStock <= 0 || quantity < maxStock)
                                ? () => setSheetState(() => quantity++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isOutOfStock
                            ? null
                            : () {
                                for (int i = 0; i < quantity; i++) {
                                  CartService.instance.addProduct(product);
                                }
                                Navigator.of(ctx).pop();
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Added $quantity × "${product.name}" to Current Bill!',
                                    ),
                                    backgroundColor: const Color(0xFF2E7D32),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: Text(
                          quantity > 1
                              ? 'Add $quantity to Bill (₹${(product.price * quantity).toStringAsFixed(2)})'
                              : 'Add to Current Bill',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                          horizontal: 16,
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) =>
                              PublicInvoiceScreen(initialToken: barcode),
                        ),
                      );
                    },
                    child: const Text(
                      'Lookup as Invoice Verification Token',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ).then((_) {
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  void _showProductNotFoundSheet(
    String barcode,
    BarcodeLookupResult lookup,
  ) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.qr_code_2,
                    color: Color(0xFFE65100),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lookup.hasDetails
                          ? 'Product Found Online'
                          : 'Product Barcode Scanned',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() => _isProcessing = false);
                    },
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (lookup.hasDetails) ...[
              Text(
                lookup.name ?? 'Product ($barcode)',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Found in online database (${lookup.brand ?? 'Retail'}), ready to be added to your store catalogue.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              if (lookup.category != null && lookup.category!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    lookup.category!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ] else ...[
              Text(
                'Barcode: $barcode',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'This product barcode is not in your store catalogue yet.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 20),

            // Action Buttons
            Column(
              children: [
                // 1. Add to Store Catalogue
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _openQuickRegisterDialog(barcode, lookup);
                    },
                    icon: const Icon(Icons.add_business_outlined, size: 18),
                    label: const Text('Add to Store Catalogue'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Quick Add to Current Bill
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _promptQuickAddToBill(barcode, lookup);
                        },
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: const Text('Add to Bill'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E88E5),
                          side: const BorderSide(color: Color(0xFF90CAF9)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          PublicInvoiceScreen(initialToken: barcode),
                    ),
                  );
                },
                child: const Text(
                  'Lookup as Invoice Verification Token',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ).then((_) {
    if (mounted) setState(() => _isProcessing = false);
  });
  }

  void _openQuickRegisterDialog(
    String barcode,
    BarcodeLookupResult lookup,
  ) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    final nameCtrl = TextEditingController(text: lookup.name ?? '');
    final brandCtrl = TextEditingController(text: lookup.brand ?? '');
    final priceCtrl = TextEditingController(text: '40.00');
    final stockCtrl = TextEditingController(text: '50');
    String category = lookup.category ?? 'Groceries';
    double taxRate = 5.0;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_business_outlined, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Register Product'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Price (₹) *',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Groceries', child: Text('Groceries')),
                          DropdownMenuItem(value: 'Personal Care', child: Text('Personal Care')),
                          DropdownMenuItem(value: 'Snacks', child: Text('Snacks')),
                          DropdownMenuItem(value: 'Beverages', child: Text('Beverages')),
                          DropdownMenuItem(value: 'Household', child: Text('Household')),
                          DropdownMenuItem(value: 'General', child: Text('General')),
                        ],
                        onChanged: (val) => setDlgState(() => category = val ?? 'General'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<double>(
                        initialValue: taxRate,
                        decoration: const InputDecoration(
                          labelText: 'Tax Rate',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 0.0, child: Text('0%')),
                          DropdownMenuItem(value: 5.0, child: Text('5%')),
                          DropdownMenuItem(value: 12.0, child: Text('12%')),
                          DropdownMenuItem(value: 18.0, child: Text('18%')),
                          DropdownMenuItem(value: 28.0, child: Text('28%')),
                        ],
                        onChanged: (val) => setDlgState(() => taxRate = val ?? 0.0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Barcode: $barcode',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(dlgCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                      final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;

                      setDlgState(() => isSaving = true);
                      final now = DateTime.now();
                      final newProduct = Product(
                        id: barcode,
                        name: name,
                        brand: brandCtrl.text.trim(),
                        category: category,
                        barcode: barcode,
                        sku: 'SKU-${barcode.length >= 6 ? barcode.substring(barcode.length - 6) : barcode}',
                        price: price,
                        taxRate: taxRate,
                        stock: stock,
                        createdAt: now,
                        updatedAt: now,
                      );

                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await FirebaseService.instance.addProduct(uid, newProduct);
                        if (dlgCtx.mounted) Navigator.of(dlgCtx).pop();
                        if (!mounted) return;

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Product "$name" registered in your catalogue!'),
                            backgroundColor: const Color(0xFF2E7D32),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );

                        // Show product detected sheet with full details
                        _showProductDetectedSheet(newProduct, barcode);
                      } catch (e) {
                        setDlgState(() => isSaving = false);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to save product: $e'),
                              backgroundColor: Colors.red.shade700,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 16),
              label: Text(isSaving ? 'Saving...' : 'Save & Register'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _promptQuickAddToBill(
    String barcode,
    BarcodeLookupResult lookup,
  ) {
    final name = lookup.name ?? 'Scanned Item ($barcode)';
    final priceCtrl = TextEditingController(text: '50.00');
    final qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_shopping_cart, color: Color(0xFF1E88E5)),
            SizedBox(width: 8),
            Text('Add to Current Bill'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Unit Price (₹) *',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;

              final customProduct = Product(
                id: barcode,
                name: name,
                category: lookup.category ?? 'General',
                barcode: barcode,
                price: price,
                taxRate: 5.0,
                stock: 999,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              for (int i = 0; i < qty; i++) {
                CartService.instance.addProduct(customProduct);
              }

              Navigator.of(dlgCtx).pop();
              Navigator.of(context).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added $qty × "$name" to Current Bill!'),
                  backgroundColor: const Color(0xFF2E7D32),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add to Bill'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Invoice QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Toggle Flash',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            tooltip: 'Switch Camera',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          // SCANNER CAMERA VIEW
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleBarcode,
                  errorBuilder: (context, error) {
                    return Container(
                      color: Colors.black87,
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.camera_alt_outlined,
                              size: 48,
                              color: Colors.white70,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Camera unavailable or permission denied.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'You can enter the invoice token or link below.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Scanner Frame Overlay
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF10B981),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          ),

          // MANUAL TOKEN INPUT / FALLBACK
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Or Enter Invoice Token Manually',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'If camera scanning is not possible, paste the token from the QR code.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _manualTokenCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Invoice Token or URL',
                              prefixIcon: Icon(Icons.qr_code),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: _parseAndOpenToken,
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: () {
                            if (_manualTokenCtrl.text.trim().isNotEmpty) {
                              _parseAndOpenToken(_manualTokenCtrl.text.trim());
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          child: const Text('Lookup'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
