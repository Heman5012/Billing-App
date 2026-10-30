import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/barcode_lookup_service.dart';
import '../services/cart_service.dart';
import '../services/firebase_service.dart';
import '../widgets/current_bill_indicator.dart';
import '../widgets/product_card.dart';
import 'barcode_scanner_screen.dart';

class ProductsScreen extends StatefulWidget {
  final VoidCallback? onViewBill;
  final VoidCallback? onMakePayment;

  const ProductsScreen({
    super.key,
    this.onViewBill,
    this.onMakePayment,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'General',
    'Groceries',
    'Beverages',
    'Snacks',
    'Dairy',
    'Personal Care',
    'Electronics',
    'Clothing',
    'Services',
  ];

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to manage products.'));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: CurrentBillIndicator(
        onViewBill: widget.onViewBill,
        onMakePayment: widget.onMakePayment,
      ),
      body: StreamBuilder<List<Product>>(
        stream: FirebaseService.instance.streamProducts(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading products: ${snapshot.error}'),
            );
          }

          final allProducts = snapshot.data ?? [];

          // Filtering
          final filteredProducts = allProducts.where((p) {
            final matchesQuery =
                _searchQuery.isEmpty ||
                p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.sku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.barcode.contains(_searchQuery);
            final matchesCategory =
                _selectedCategory == 'All' ||
                p.category.toLowerCase() == _selectedCategory.toLowerCase();
            return matchesQuery && matchesCategory;
          }).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header & Add Button
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Product Catalogue',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${allProducts.length} items registered in your inventory',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ListenableBuilder(
                                listenable: CartService.instance,
                                builder: (context, _) {
                                  final count = CartService.instance.itemCount;
                                  if (count == 0) return const SizedBox.shrink();
                                  return OutlinedButton.icon(
                                    onPressed: widget.onViewBill,
                                    icon: Badge(
                                      label: Text('$count'),
                                      backgroundColor: const Color(0xFFEF4444),
                                      child: const Icon(
                                        Icons.shopping_cart_outlined,
                                        size: 18,
                                      ),
                                    ),
                                    label: Text(
                                      'View Bill (₹${CartService.instance.grandTotal.toStringAsFixed(2)})',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF1E88E5),
                                      side: const BorderSide(
                                        color: Color(0xFF90CAF9),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              FilledButton.icon(
                                onPressed: () => _openProductFormDialog(context),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Product'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Search bar & Filter Chips
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                              decoration: InputDecoration(
                                hintText:
                                    'Search products by name, SKU or barcode...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.qr_code_scanner,
                                    color: Color(0xFF10B981),
                                  ),
                                  tooltip: 'Scan Barcode',
                                  onPressed: () =>
                                      _scanAndShowProduct(user.uid),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: Text(cat),
                                selected: isSelected,
                                onSelected: (sel) {
                                  setState(() {
                                    _selectedCategory = cat;
                                  });
                                },
                                selectedColor: const Color(0xFFE3F2FD),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF1E88E5)
                                      : Colors.grey.shade800,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF1E88E5)
                                      : Colors.grey.shade300,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Product List / Grid
              if (filteredProducts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 54,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          allProducts.isEmpty
                              ? 'No products in your catalogue yet.'
                              : 'No products match your search/filter.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (allProducts.isEmpty) ...[
                          FilledButton.icon(
                            onPressed: () => _openProductFormDialog(context),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add your first product'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 340,
                          mainAxisExtent: 220,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final product = filteredProducts[index];
                      return ProductCard(
                        product: product,
                        onTap: () =>
                            _showProductDetailsBottomSheet(context, product),
                        onAddToCart: product.isOutOfStock
                            ? null
                            : () {
                                final res =
                                    CartService.instance.addProduct(product);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res.message),
                                    backgroundColor: res.isSuccess
                                        ? const Color(0xFF2E7D32)
                                        : Colors.red.shade700,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                        onEdit: () =>
                            _openProductFormDialog(context, product: product),
                        onDelete: () => _confirmDelete(context, product),
                      );
                    }, childCount: filteredProducts.length),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  void _openProductFormDialog(
    BuildContext context, {
    Product? product,
    String? initialBarcode,
  }) {
    final isEditing = product != null;
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final brandCtrl = TextEditingController(text: product?.brand ?? '');
    final skuCtrl = TextEditingController(text: product?.sku ?? '');
    final barcodeCtrl = TextEditingController(
      text: product?.barcode ?? (initialBarcode ?? ''),
    );
    final imageUrlCtrl = TextEditingController(text: product?.imageUrl ?? '');
    final priceCtrl = TextEditingController(
      text: product != null ? product.price.toStringAsFixed(2) : '',
    );
    final stockCtrl = TextEditingController(
      text: product != null ? product.stock.toString() : '',
    );
    double taxRate = product?.taxRate ?? 0.0;
    String category = product?.category ?? 'General';
    bool isSaving = false;
    bool isLookingUp = false;
    String? lookupStatusMessage;
    bool lookupStatusIsSuccess = false;

    final formKey = GlobalKey<FormState>();

    // Prepare selectable categories ensuring current category is included
    final availableCategories = _categories.where((c) => c != 'All').toList();
    if (!availableCategories.contains(category) && category.trim().isNotEmpty) {
      availableCategories.add(category.trim());
    }

    // Prepare selectable tax rates ensuring current rate is included
    final availableTaxRates = <double>[0.0, 5.0, 12.0, 18.0, 28.0];
    if (!availableTaxRates.any((r) => (r - taxRate).abs() < 0.001)) {
      availableTaxRates.add(taxRate);
      availableTaxRates.sort();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
            bool hasChanges() {
              if (!isEditing) {
                return nameCtrl.text.trim().isNotEmpty ||
                    brandCtrl.text.trim().isNotEmpty ||
                    skuCtrl.text.trim().isNotEmpty ||
                    barcodeCtrl.text.trim().isNotEmpty ||
                    imageUrlCtrl.text.trim().isNotEmpty ||
                    priceCtrl.text.trim().isNotEmpty ||
                    stockCtrl.text.trim().isNotEmpty ||
                    category != 'General' ||
                    taxRate != 0.0;
              }
              final orig = product;
              final curPrice = double.tryParse(priceCtrl.text.trim());
              final curStock = int.tryParse(stockCtrl.text.trim());

              final nameChanged = nameCtrl.text.trim() != orig.name.trim();
              final brandChanged = brandCtrl.text.trim() != orig.brand.trim();
              final skuChanged = skuCtrl.text.trim() != orig.sku.trim();
              final barcodeChanged =
                  barcodeCtrl.text.trim() != orig.barcode.trim();
              final imageChanged =
                  imageUrlCtrl.text.trim() != orig.imageUrl.trim();
              final priceChanged = curPrice == null ||
                  (curPrice - orig.price).abs() > 0.001 ||
                  priceCtrl.text.trim() != orig.price.toStringAsFixed(2);
              final stockChanged =
                  curStock == null || curStock != orig.stock;
              final categoryChanged = category.trim() != orig.category.trim();
              final taxChanged = (taxRate - orig.taxRate).abs() > 0.001;

              return nameChanged ||
                  brandChanged ||
                  skuChanged ||
                  barcodeChanged ||
                  imageChanged ||
                  priceChanged ||
                  stockChanged ||
                  categoryChanged ||
                  taxChanged;
            }

            Future<void> handleCancel() async {
              if (isSaving) return;
              if (!hasChanges()) {
                Navigator.of(ctx).pop();
                return;
              }

              final discard = await showDialog<bool>(
                context: ctx,
                builder: (dialogCtx) => AlertDialog(
                  title: const Text('Discard changes?'),
                  content: const Text(
                    'You have unsaved changes. Are you sure you want to discard them?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(false),
                      child: const Text('Keep Editing'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                      ),
                      child: const Text('Discard'),
                    ),
                  ],
                ),
              );

              if (discard == true && ctx.mounted) {
                Navigator.of(ctx).pop();
              }
            }
          Future<void> performBarcodeLookup(String rawBarcode) async {
            final cleanBarcode =
                BarcodeLookupService.normalizeBarcode(rawBarcode);
            if (cleanBarcode.isEmpty) return;

            barcodeCtrl.text = cleanBarcode;
            setDialogState(() {
              isLookingUp = true;
              lookupStatusMessage =
                  'Searching inventory & product database for $cleanBarcode...';
              lookupStatusIsSuccess = false;
            });

            final uid = AuthService.instance.currentUser?.uid;
            if (uid == null) {
              setDialogState(() {
                isLookingUp = false;
                lookupStatusMessage = 'Please sign in to search inventory.';
              });
              return;
            }

            final result = await BarcodeLookupService.instance.lookup(
              uid,
              cleanBarcode,
            );

            setDialogState(() {
              isLookingUp = false;

              if (result.foundInFirestore && result.existingProduct != null) {
                final p = result.existingProduct!;
                lookupStatusIsSuccess = true;
                lookupStatusMessage =
                    'Product "${p.name}" found in your inventory! Details populated.';
                nameCtrl.text = p.name;
                if (p.brand.isNotEmpty) brandCtrl.text = p.brand;
                if (p.sku.isNotEmpty) skuCtrl.text = p.sku;
                if (p.imageUrl.isNotEmpty) imageUrlCtrl.text = p.imageUrl;
                priceCtrl.text = p.price.toStringAsFixed(2);
                stockCtrl.text = p.stock.toString();
                taxRate = p.taxRate;
                if (p.category.isNotEmpty) {
                  category = p.category;
                  if (!availableCategories.contains(category)) {
                    availableCategories.add(category);
                  }
                }
              } else if (result.foundInOpenFoodFacts) {
                lookupStatusIsSuccess = true;
                lookupStatusMessage =
                    'Product found in Open Food Facts! Please enter your selling price & stock.';
                if (result.name != null && result.name!.isNotEmpty) {
                  nameCtrl.text = result.name!;
                }
                if (result.brand != null && result.brand!.isNotEmpty) {
                  brandCtrl.text = result.brand!;
                }
                if (result.imageUrl != null && result.imageUrl!.isNotEmpty) {
                  imageUrlCtrl.text = result.imageUrl!;
                }
                if (result.category != null && result.category!.isNotEmpty) {
                  category = result.category!;
                  if (!availableCategories.contains(category)) {
                    availableCategories.add(category);
                  }
                }
                // Price & stock are strictly left for manual retailer input
              } else {
                lookupStatusIsSuccess = false;
                lookupStatusMessage = result.errorMessage ??
                    'Barcode not found online. You can enter details manually.';
              }
            });
          }

          Future<void> scanBarcodeWithCamera() async {
            final scanned = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) => const BarcodeScannerScreen(),
              ),
            );
            if (scanned != null && scanned.trim().isNotEmpty) {
              await performBarcodeLookup(scanned.trim());
            }
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                handleCancel();
              }
            },
            child: AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
            actionsOverflowButtonSpacing: 8,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isEditing ? 'Edit Product' : 'Add New Product'),
                if (!isEditing)
                  IconButton(
                    icon: const Icon(
                      Icons.qr_code_scanner,
                      color: Color(0xFF1E88E5),
                    ),
                    tooltip: 'Scan Barcode',
                    onPressed: isSaving || isLookingUp
                        ? null
                        : scanBarcodeWithCamera,
                  ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Prominent Scan Barcode Button
                      if (!isEditing) ...[
                        OutlinedButton.icon(
                          onPressed: isSaving || isLookingUp
                              ? null
                              : scanBarcodeWithCamera,
                          icon: const Icon(Icons.qr_code_scanner, size: 20),
                          label: const Text('Scan Product Barcode'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E88E5),
                            side: const BorderSide(
                              color: Color(0xFF1E88E5),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Lookup Progress & Feedback Banner
                      if (isLookingUp) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1E88E5),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  lookupStatusMessage ?? 'Searching database...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else if (lookupStatusMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: lookupStatusIsSuccess
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: lookupStatusIsSuccess
                                  ? const Color(0xFFA5D6A7)
                                  : const Color(0xFFFFCC80),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                lookupStatusIsSuccess
                                    ? Icons.check_circle_outline
                                    : Icons.info_outline,
                                size: 18,
                                color: lookupStatusIsSuccess
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFE65100),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lookupStatusMessage!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: lookupStatusIsSuccess
                                        ? const Color(0xFF1B5E20)
                                        : const Color(0xFFBF360C),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => setDialogState(
                                  () => lookupStatusMessage = null,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Image Preview Thumbnail (if present)
                      if (imageUrlCtrl.text.trim().isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  imageUrlCtrl.text.trim(),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 48,
                                    height: 48,
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.broken_image,
                                      size: 20,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Product Image (Online)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      imageUrlCtrl.text.trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                tooltip: 'Remove image URL',
                                onPressed: () {
                                  setDialogState(() {
                                    imageUrlCtrl.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Product Name
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Product Name *',
                          hintText: 'e.g. Nutella Hazelnut Spread',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Product name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Brand & SKU Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: brandCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Brand (Optional)',
                                hintText: 'e.g. Ferrero',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: skuCtrl,
                              decoration: const InputDecoration(
                                labelText: 'SKU (Optional)',
                                hintText: 'e.g. NUT-400G',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Barcode Input Field with suffix scan & lookup actions
                      TextFormField(
                        controller: barcodeCtrl,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'Barcode (EAN-13, UPC, Code 128)',
                          hintText: 'e.g. 3017620422003',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.search, size: 20),
                                tooltip: 'Lookup Barcode Online',
                                onPressed: isSaving || isLookingUp
                                    ? null
                                    : () {
                                        final code = barcodeCtrl.text.trim();
                                        if (code.isNotEmpty) {
                                          performBarcodeLookup(code);
                                        }
                                      },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.qr_code_scanner,
                                  size: 20,
                                ),
                                tooltip: 'Scan with Camera',
                                onPressed: isSaving || isLookingUp
                                    ? null
                                    : scanBarcodeWithCamera,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Price and Stock (Always manually entered by retailer)
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: priceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Selling Price (₹) *',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) {
                                final val = double.tryParse(v ?? '');
                                if (val == null || val < 0) {
                                  return 'Enter valid price >= 0';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: stockCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Available Stock *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) {
                                final val = int.tryParse(v ?? '');
                                if (val == null || val < 0) {
                                  return 'Enter valid stock >= 0';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        key: ValueKey('cat_$category'),
                        initialValue: category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: availableCategories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: isSaving
                            ? null
                            : (val) {
                                if (val != null) {
                                  setDialogState(() => category = val);
                                }
                              },
                      ),
                      const SizedBox(height: 12),

                      // Tax Rate Dropdown
                      DropdownButtonFormField<double>(
                        key: ValueKey('tax_$taxRate'),
                        initialValue: taxRate,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Tax Rate (%)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: availableTaxRates
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                  '${t.toStringAsFixed(0)}%',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: isSaving
                            ? null
                            : (val) {
                                if (val != null) {
                                  setDialogState(() => taxRate = val);
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : handleCancel,
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving || isLookingUp
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final uid = AuthService.instance.currentUser?.uid;
                        if (uid == null) return;

                        setDialogState(() => isSaving = true);

                        final now = DateTime.now();
                        final parsedPrice =
                            double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                        final parsedStock =
                            int.tryParse(stockCtrl.text.trim()) ?? 0;
                        final newProduct = Product(
                          id: product?.id ?? '',
                          name: nameCtrl.text.trim(),
                          brand: brandCtrl.text.trim(),
                          sku: skuCtrl.text.trim(),
                          barcode: barcodeCtrl.text.trim(),
                          imageUrl: imageUrlCtrl.text.trim(),
                          price: parsedPrice.clamp(0.0, 100000000.0),
                          stock: parsedStock < 0 ? 0 : parsedStock,
                          taxRate: taxRate,
                          category: category.trim().isEmpty
                              ? 'General'
                              : category.trim(),
                          createdAt: product?.createdAt ?? now,
                          updatedAt: now,
                        );

                        try {
                          if (isEditing) {
                            await FirebaseService.instance.updateProduct(
                              uid,
                              newProduct,
                            );
                          } else {
                            await FirebaseService.instance.addProduct(
                              uid,
                              newProduct,
                            );
                          }

                          if (ctx.mounted) Navigator.of(ctx).pop();

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEditing
                                      ? 'Product "${newProduct.name}" updated successfully!'
                                      : 'Product "${newProduct.name}" added successfully!',
                                ),
                                backgroundColor: const Color(0xFF2E7D32),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (dialogContext.mounted) {
                            String message = 'Failed to save product. Please try again.';
                            if (e is ArgumentError) {
                              message = e.message.toString();
                            } else if (e.toString().toLowerCase().contains('permission-denied') ||
                                e.toString().toLowerCase().contains('permission denied')) {
                              message = 'Permission denied. Unable to update product.';
                            } else if (e.toString().toLowerCase().contains('network') ||
                                e.toString().toLowerCase().contains('unavailable')) {
                              message = 'Network error: Please check your connection and try again.';
                            }
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(message),
                                backgroundColor: Colors.red.shade700,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEditing ? 'Save Changes' : 'Create Product'),
              ),
            ],
          ),
        );
      },
    ),
  );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final uid = AuthService.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseService.instance.deleteProduct(uid, product.id);
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanAndShowProduct(String uid) async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (scanned == null || scanned.trim().isEmpty || !mounted) return;
    final barcode = scanned.trim();

    BuildContext? loadingDialogCtx;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        loadingDialogCtx = ctx;
        return const Center(child: CircularProgressIndicator());
      },
    );

    Product? product;
    try {
      product =
          await FirebaseService.instance.findProductByBarcode(uid, barcode);
    } catch (_) {}

    if (!mounted) return;
    if (loadingDialogCtx != null && loadingDialogCtx!.mounted) {
      Navigator.of(loadingDialogCtx!).pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    if (product != null) {
      _showProductDetailsBottomSheet(context, product);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.search_off, color: Color(0xFFE65100)),
              SizedBox(width: 8),
              Text('Product Not Found'),
            ],
          ),
          content: Text(
            'No product with barcode "$barcode" exists in your catalogue.\n\nWould you like to add it manually?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _openProductFormDialog(context, initialBarcode: barcode);
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Product'),
            ),
          ],
        ),
      );
    }
  }

  void _showProductDetailsBottomSheet(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        int selectedQuantity = 1;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final cart = CartService.instance;
            final currentInCart = cart.getProductQuantity(product);
            final isOut = product.isOutOfStock;
            final maxCanAdd = product.stock - currentInCart;

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pull Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Badge & Close Action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            product.category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Product Image & Primary Info Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              product.imageUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 32,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              size: 36,
                              color: Color(0xFF1E88E5),
                            ),
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                              const SizedBox(height: 6),
                              Text(
                                '₹${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E88E5),
                                ),
                              ),
                              if (product.taxRate > 0)
                                Text(
                                  '+${product.taxRate.toStringAsFixed(0)}% GST included',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Badges: Barcode, SKU, Stock
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (product.barcode.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.qr_code,
                                  size: 14,
                                  color: Colors.black54,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  product.barcode,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (product.sku.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'SKU: ${product.sku}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isOut
                                ? Colors.red.shade50
                                : (product.isLowStock
                                    ? Colors.amber.shade50
                                    : Colors.green.shade50),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOut
                                ? 'Out of Stock'
                                : '${product.stock} available in stock${product.isLowStock ? " (Low Stock)" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOut
                                  ? Colors.red.shade700
                                  : (product.isLowStock
                                      ? Colors.amber.shade800
                                      : Colors.green.shade800),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (currentInCart > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_bag_outlined,
                              size: 16,
                              color: Color(0xFF1E88E5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Already in current bill: $currentInCart pcs',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Quantity Controls
                    if (!isOut) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Quantity to add:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: selectedQuantity > 1
                                      ? () => setSheetState(
                                            () => selectedQuantity--,
                                          )
                                      : null,
                                  icon: const Icon(Icons.remove, size: 18),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    '$selectedQuantity',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: selectedQuantity < maxCanAdd
                                      ? () => setSheetState(
                                            () => selectedQuantity++,
                                          )
                                      : null,
                                  icon: const Icon(Icons.add, size: 18),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total for this item: ₹${(product.price * selectedQuantity).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Action: Add to Bill Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: isOut || maxCanAdd <= 0
                            ? null
                            : () {
                                final res = CartService.instance.addProduct(
                                  product,
                                  quantity: selectedQuantity,
                                );
                                Navigator.of(ctx).pop();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res.message),
                                      backgroundColor: res.isSuccess
                                          ? const Color(0xFF2E7D32)
                                          : Colors.red.shade700,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: Text(
                          isOut
                              ? 'Out of Stock'
                              : (maxCanAdd <= 0
                                  ? 'Maximum Stock in Bill'
                                  : 'Add to Bill (₹${(product.price * selectedQuantity).toStringAsFixed(2)})'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    // Actions when current bill has items: View Bill & Make Payment
                    ListenableBuilder(
                      listenable: CartService.instance,
                      builder: (context, _) {
                        if (CartService.instance.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final count = CartService.instance.itemCount;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    widget.onViewBill?.call();
                                  },
                                  icon: Badge(
                                    label: Text('$count'),
                                    backgroundColor: const Color(0xFFEF4444),
                                    child: const Icon(
                                      Icons.shopping_cart_outlined,
                                      size: 18,
                                    ),
                                  ),
                                  label: Text(
                                    'View Current Bill ($count ${count == 1 ? "item" : "items"})',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1E88E5),
                                    side: const BorderSide(
                                      color: Color(0xFF90CAF9),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    widget.onMakePayment?.call();
                                  },
                                  icon: const Icon(Icons.payment, size: 18),
                                  label: Text(
                                    'Make Payment (₹${CartService.instance.grandTotal.toStringAsFixed(2)})',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
