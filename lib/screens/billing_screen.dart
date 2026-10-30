import 'package:flutter/material.dart';

import '../models/invoice.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/barcode_lookup_service.dart';
import '../services/cart_service.dart';
import '../services/firebase_service.dart';
import '../widgets/current_bill_indicator.dart';
import '../widgets/invoice_summary.dart';
import 'barcode_scanner_screen.dart';

class BillingScreen extends StatefulWidget {
  final Function(
    List<InvoiceItem> items,
    CustomerDetails customer,
    double overallDiscountPercent,
    String notes,
    BusinessProfile business,
  )
  onProceedToPayment;

  final int initialTabIndex;

  const BillingScreen({
    super.key,
    required this.onProceedToPayment,
    this.initialTabIndex = 0,
  });

  @override
  BillingScreenState createState() => BillingScreenState();
}

class BillingScreenState extends State<BillingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _productSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    final cart = CartService.instance;
    _customerNameCtrl.text = cart.customer.name;
    _customerPhoneCtrl.text = cart.customer.phone;
    _notesCtrl.text = cart.notes;

    _customerNameCtrl.addListener(_syncCustomer);
    _customerPhoneCtrl.addListener(_syncCustomer);
    _notesCtrl.addListener(_syncNotes);
  }

  @override
  void didUpdateWidget(BillingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      if (_tabController.index != widget.initialTabIndex) {
        _tabController.animateTo(widget.initialTabIndex.clamp(0, 1));
      }
    }
  }

  void switchToTab(int index) {
    if (mounted && _tabController.index != index) {
      _tabController.animateTo(index.clamp(0, 1));
    }
  }

  void _syncCustomer() {
    CartService.instance.updateCustomer(
      CustomerDetails(
        name: _customerNameCtrl.text.trim(),
        phone: _customerPhoneCtrl.text.trim(),
      ),
    );
  }

  void _syncNotes() {
    CartService.instance.updateNotes(_notesCtrl.text.trim());
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _notesCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _addToCart(Product product) {
    final res = CartService.instance.addProduct(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.isSuccess
            ? const Color(0xFF2E7D32)
            : (res.status == AddToCartStatus.outOfStock
                ? Colors.red.shade700
                : Colors.orange.shade800),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _scanBarcodeToCart(
    String uid,
    List<Product> allProducts,
  ) async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (scanned == null || scanned.trim().isEmpty) return;

    final cleanBarcode = BarcodeLookupService.normalizeBarcode(scanned);

    // 1. Check if product exists in local catalogue or Firestore
    Product? product;
    final matchingIndex = allProducts.indexWhere(
      (p) => p.barcode.trim() == cleanBarcode,
    );

    if (matchingIndex >= 0) {
      product = allProducts[matchingIndex];
    } else {
      product = await FirebaseService.instance.findProductByBarcode(
        uid,
        cleanBarcode,
      );
    }

    if (product != null) {
      _addToCart(product);
      return;
    }

    // 2. If not found in catalogue, prompt user to add item
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Product Not in Catalogue'),
        content: Text(
          'Barcode "$cleanBarcode" is not registered in your catalogue yet.\n\nWould you like to add it as a custom item to this bill?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showAddCustomItemDialog(context, uid);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Custom Item'),
          ),
        ],
      ),
    );
  }

  void _updateQuantity(int index, int delta, {int? maxStock}) {
    CartService.instance.updateQuantity(index, delta, maxStock: maxStock);
  }

  void _setItemDiscount(int index, double discountPercent) {
    CartService.instance.setItemDiscount(index, discountPercent);
  }

  void _removeCartItem(int index) {
    CartService.instance.removeItem(index);
  }

  void _confirmClearCart(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Current Bill?'),
        content: const Text(
          'Are you sure you want to remove all items from the current bill? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _clearCart();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Clear Bill'),
          ),
        ],
      ),
    );
  }

  void _clearCart() {
    CartService.instance.clear();
    _customerNameCtrl.clear();
    _customerPhoneCtrl.clear();
    _notesCtrl.clear();
  }

  void _proceedWithPayment(BusinessProfile business) {
    final cart = CartService.instance;
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot proceed: Current bill has no items.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    widget.onProceedToPayment(
      List.from(cart.items),
      CustomerDetails(
        name: _customerNameCtrl.text.trim(),
        phone: _customerPhoneCtrl.text.trim(),
      ),
      cart.overallDiscountPercent,
      _notesCtrl.text.trim(),
      business,
    );
  }

  void _showAddCustomItemDialog(BuildContext context, String uid) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    double taxRate = 0.0;
    bool saveToCatalog = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            actionsOverflowButtonSpacing: 8,
            title: const Text('Add Custom / Ad-hoc Item'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Item Name *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter item name'
                            : null,
                      ),
                      const SizedBox(height: 12),
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
                                labelText: 'Price *',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter price';
                                final val = double.tryParse(v);
                                if (val == null || val < 0) return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantity *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter qty';
                                final val = int.tryParse(v);
                                if (val == null || val <= 0) return 'Min 1';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<double>(
                        initialValue: taxRate,
                        decoration: const InputDecoration(
                          labelText: 'Tax Rate',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 0.0, child: Text('0% (Exempt)')),
                          DropdownMenuItem(value: 5.0, child: Text('5% GST')),
                          DropdownMenuItem(value: 12.0, child: Text('12% GST')),
                          DropdownMenuItem(value: 18.0, child: Text('18% GST')),
                          DropdownMenuItem(value: 28.0, child: Text('28% GST')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => taxRate = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: saveToCatalog,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          'Save to product catalog for future bills',
                          style: TextStyle(fontSize: 13),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) =>
                            setDialogState(() => saveToCatalog = v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final price = double.parse(priceCtrl.text);
                  final qty = int.parse(qtyCtrl.text);

                  String? newProductId;
                  if (saveToCatalog) {
                    final now = DateTime.now();
                    final prod = Product(
                      id: '',
                      name: nameCtrl.text.trim(),
                      price: price,
                      stock: 100, // default initial stock
                      taxRate: taxRate,
                      category: 'General',
                      createdAt: now,
                      updatedAt: now,
                    );
                    await FirebaseService.instance.addProduct(uid, prod);
                  }

                  CartService.instance.addCustomItem(
                    InvoiceItem(
                      productId: newProductId,
                      name: nameCtrl.text.trim(),
                      unitPrice: price,
                      quantity: qty,
                      discountPercent: 0.0,
                      taxRate: taxRate,
                    ),
                  );

                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Add to Bill'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showItemDiscountDialog(BuildContext context, int index) {
    final item = CartService.instance.items[index];
    final ctrl = TextEditingController(
      text: item.discountPercent > 0
          ? item.discountPercent.toStringAsFixed(0)
          : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Discount for "${item.name}"'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Item Discount % (0 - 100)',
            suffixText: '%',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _setItemDiscount(index, 0.0);
              Navigator.of(ctx).pop();
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text) ?? 0.0;
              if (val >= 0 && val <= 100) {
                _setItemDiscount(index, val);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to create bills.'));
    }

    return StreamBuilder<BusinessProfile>(
      stream: FirebaseService.instance.streamBusinessProfile(user.uid),
      builder: (context, profileSnap) {
        final business = profileSnap.data ?? BusinessProfile();

        return StreamBuilder<List<Product>>(
          stream: FirebaseService.instance.streamProducts(user.uid),
          builder: (context, productSnap) {
            final allProducts = productSnap.data ?? [];

            final filteredProducts = allProducts.where((p) {
              if (_productSearchQuery.isEmpty) return true;
              final q = _productSearchQuery.toLowerCase();
              return p.name.toLowerCase().contains(q) ||
                  p.sku.toLowerCase().contains(q) ||
                  p.barcode.contains(q);
            }).toList();

            return ListenableBuilder(
              listenable: CartService.instance,
              builder: (context, _) {
                final cart = CartService.instance;
                final cartItems = cart.items;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 960;

                    final leftCataloguePane = Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Select Products',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _showAddCustomItemDialog(context, user.uid),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Custom Item'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            onChanged: (v) =>
                                setState(() => _productSearchQuery = v),
                            decoration: InputDecoration(
                              hintText:
                                  'Search catalogue by name, SKU or barcode...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.qr_code_scanner,
                                  color: Color(0xFF1E88E5),
                                ),
                                tooltip: 'Scan Barcode to Add Product',
                                onPressed: () =>
                                    _scanBarcodeToCart(user.uid, allProducts),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: filteredProducts.isEmpty
                                ? Center(
                                    child: Text(
                                      allProducts.isEmpty
                                          ? 'No products in catalogue yet.'
                                          : 'No products match search.',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: filteredProducts.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final p = filteredProducts[index];
                                      final qtyInCart =
                                          cart.getProductQuantity(p);
                                      final inCart = qtyInCart > 0;

                                      return Card(
                                        elevation: 0.5,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          side: BorderSide(
                                            color: inCart
                                                ? const Color(0xFF1E88E5)
                                                : Colors.grey.shade200,
                                            width: inCart ? 1.5 : 1,
                                          ),
                                        ),
                                        child: ListTile(
                                          title: Text(
                                            p.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '₹${p.price.toStringAsFixed(2)} • Stock: ${p.stock}${inCart ? " • In Bill: $qtyInCart" : ""}${p.taxRate > 0 ? " • ${p.taxRate.toStringAsFixed(0)}% Tax" : ""}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: p.isOutOfStock
                                                  ? Colors.red
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                          trailing: FilledButton.tonalIcon(
                                            onPressed: p.isOutOfStock
                                                ? null
                                                : () => _addToCart(p),
                                            icon: const Icon(
                                              Icons.add_shopping_cart,
                                              size: 16,
                                            ),
                                            label: Text(
                                              inCart ? 'Add (+1)' : 'Add',
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          if (!isWide && cart.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: CurrentBillIndicator(
                                onViewBill: () => _tabController.animateTo(1),
                                onMakePayment: () =>
                                    _proceedWithPayment(business),
                              ),
                            ),
                        ],
                      ),
                    );

                    final rightCartPane = SingleChildScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cart Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.shopping_cart_outlined,
                                    color: Color(0xFF1E88E5),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Current Bill (${cartItems.length} items)',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (cartItems.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () => _confirmClearCart(context),
                                  icon: const Icon(
                                    Icons.delete_sweep,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'Clear Bill',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Optional Customer Details
                          ExpansionTile(
                            title: Text(
                              _customerNameCtrl.text.isNotEmpty
                                  ? 'Customer: ${_customerNameCtrl.text}'
                                  : 'Add Customer Details (Optional)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            tilePadding: EdgeInsets.zero,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _customerNameCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Customer Name',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _customerPhoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      decoration: const InputDecoration(
                                        labelText: 'Phone Number',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _notesCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Invoice Note / Reference',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                          const Divider(height: 16),

                          // Cart Items List
                          if (cartItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.remove_shopping_cart_outlined,
                                      size: 48,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Your bill is empty.',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Select products in Catalogue, tap cards in Products,\nor scan barcodes to add items.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: cartItems.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = cartItems[index];
                                final matchingProduct = allProducts.firstWhere(
                                  (p) => p.id == item.productId,
                                  orElse: () => Product(
                                    id: '',
                                    name: '',
                                    price: 0,
                                    stock: 9999,
                                    createdAt: DateTime.now(),
                                    updatedAt: DateTime.now(),
                                  ),
                                );

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '₹${item.unitPrice.toStringAsFixed(2)} × ${item.quantity} = ₹${item.lineSubtotal.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            if (item.discountPercent > 0 ||
                                                item.taxRate > 0)
                                              Text(
                                                '${item.discountPercent > 0 ? "Disc: ${item.discountPercent.toStringAsFixed(0)}%  " : ""}${item.taxRate > 0 ? "Tax: ${item.taxRate.toStringAsFixed(0)}%" : ""}',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: Colors.blue.shade700,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Item Discount Button
                                      IconButton(
                                        icon: Icon(
                                          Icons.discount_outlined,
                                          size: 16,
                                          color: item.discountPercent > 0
                                              ? const Color(0xFF1E88E5)
                                              : Colors.grey.shade500,
                                        ),
                                        tooltip: 'Set item discount',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () =>
                                            _showItemDiscountDialog(
                                          context,
                                          index,
                                        ),
                                      ),

                                      // Stepper (- / +)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                              size: 18,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () =>
                                                _updateQuantity(index, -1),
                                          ),
                                          Text(
                                            '${item.quantity}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                              size: 18,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () => _updateQuantity(
                                              index,
                                              1,
                                              maxStock: matchingProduct.stock,
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Line Total
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minWidth: 50,
                                          maxWidth: 75,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            '₹${item.lineTotal.toStringAsFixed(2)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),

                                      IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _removeCartItem(index),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                          const SizedBox(height: 16),

                          // Invoice Calculation Summary
                          InvoiceSummaryWidget(
                            subtotal: cart.subtotal,
                            overallDiscountPercent: cart.overallDiscountPercent,
                            overallDiscountAmount: cart.overallDiscountAmount,
                            taxableAmount: cart.finalTaxable,
                            tax: cart.finalTax,
                            taxBreakdown: cart.taxBreakdown,
                            total: cart.grandTotal,
                            currency: business.currency,
                            onOverallDiscountChanged: (disc) {
                              cart.updateOverallDiscount(disc);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Proceed to Payment Action
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: cartItems.isEmpty
                                  ? null
                                  : () => _proceedWithPayment(business),
                              icon: const Icon(Icons.payment, size: 20),
                              label: Text(
                                'Proceed to Payment (₹${cart.grandTotal.toStringAsFixed(2)})',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1E88E5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(flex: 5, child: leftCataloguePane),
                          Container(width: 1, color: Colors.grey.shade200),
                          Expanded(flex: 6, child: rightCartPane),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            tabs: [
                              const Tab(
                                icon: Icon(Icons.inventory_2),
                                text: 'Catalogue',
                              ),
                              Tab(
                                icon: cartItems.isNotEmpty
                                    ? Badge(
                                        label: Text('${cartItems.length}'),
                                        backgroundColor:
                                            const Color(0xFFEF4444),
                                        child: const Icon(Icons.shopping_cart),
                                      )
                                    : const Icon(Icons.shopping_cart),
                                text: cartItems.isNotEmpty
                                    ? 'Current Bill (${cartItems.length})'
                                    : 'Current Bill',
                              ),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [leftCataloguePane, rightCartPane],
                            ),
                          ),
                        ],
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
