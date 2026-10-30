import 'package:flutter/material.dart';

import '../models/invoice.dart';
import '../services/auth_service.dart';
import '../services/invoice_service.dart';

class PaymentScreen extends StatefulWidget {
  final List<InvoiceItem> items;
  final CustomerDetails customer;
  final double overallDiscountPercent;
  final String notes;
  final BusinessProfile business;
  final ValueChanged<Invoice> onPaymentSuccess;
  final VoidCallback onCancel;

  const PaymentScreen({
    super.key,
    required this.items,
    required this.customer,
    required this.overallDiscountPercent,
    required this.notes,
    required this.business,
    required this.onPaymentSuccess,
    required this.onCancel,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'UPI'; // UPI, Card, Cash
  bool _isProcessing = false;
  String? _errorMessage;

  // UPI Demo state
  String _selectedUpiApp = 'Google Pay';
  final _upiIdCtrl = TextEditingController(text: 'merchant@billwave');

  // Card Demo state
  final _cardHolderCtrl = TextEditingController(text: 'DEMO CARDHOLDER');
  final _cardNumberCtrl = TextEditingController(text: '•••• •••• •••• 4242');

  // Cash Demo state
  final _cashReceivedCtrl = TextEditingController();
  double _changeDue = 0.0;

  @override
  void initState() {
    super.initState();
    final grandTotal = _calculateTotal();
    _cashReceivedCtrl.text = grandTotal.toStringAsFixed(0);
    _calculateChange();
  }

  @override
  void dispose() {
    _upiIdCtrl.dispose();
    _cardHolderCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cashReceivedCtrl.dispose();
    super.dispose();
  }

  double _calculateTotal() {
    double taxable = 0.0;
    double tax = 0.0;
    for (final item in widget.items) {
      taxable += item.lineTaxable;
      tax += item.lineTax;
    }
    final discount = taxable * (widget.overallDiscountPercent / 100.0);
    final finalTaxable = taxable - discount;
    final factor = taxable > 0 ? (finalTaxable / taxable) : 1.0;
    final finalTax = tax * factor;
    return finalTaxable + finalTax;
  }

  void _calculateChange() {
    final total = _calculateTotal();
    final received = double.tryParse(_cashReceivedCtrl.text) ?? 0.0;
    setState(() {
      _changeDue = (received - total).clamp(0.0, double.infinity);
    });
  }

  Future<void> _processSimulatedPayment({required bool simulateSuccess}) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    // Simulate network latency / gateway response
    await Future.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;

    if (!simulateSuccess) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Demo payment failed (simulated decline). You can retry or choose another payment method.';
      });
      return;
    }

    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        throw StateError('You must be signed in to complete checkout.');
      }

      final paymentMethodLabel = _selectedMethod == 'UPI'
          ? 'UPI (Demo - $_selectedUpiApp)'
          : (_selectedMethod == 'Card' ? 'Card (Demo)' : 'Cash (Demo)');

      final createdInvoice = await InvoiceService.instance
          .createInvoiceWithTransaction(
            uid: user.uid,
            customer: widget.customer,
            items: widget.items,
            overallDiscountPercent: widget.overallDiscountPercent,
            paymentMethod: paymentMethodLabel,
            businessName: widget.business.businessName,
            notes: widget.notes,
          );

      if (mounted) {
        widget.onPaymentSuccess(createdInvoice);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Checkout failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = _calculateTotal();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Simulated Payment Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isProcessing ? null : widget.onCancel,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Prominent DEMO MODE BANNER
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        border: Border.all(color: const Color(0xFFFDBA74)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFFC2410C),
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'DEMO MODE — No real money is transferred. Test simulated payments safely.',
                              style: TextStyle(
                                color: Color(0xFF9A3412),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Amount Due Display
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Payable Amount',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF1565C0),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.items.length} items in bill',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '₹${grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error Message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Payment Method Tabs
                    const Text(
                      'Choose Demo Payment Method',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'UPI',
                          icon: Icon(Icons.qr_code_2),
                          label: Text('UPI Demo'),
                        ),
                        ButtonSegment(
                          value: 'Card',
                          icon: Icon(Icons.credit_card),
                          label: Text('Card Demo'),
                        ),
                        ButtonSegment(
                          value: 'Cash',
                          icon: Icon(Icons.money),
                          label: Text('Cash Demo'),
                        ),
                      ],
                      selected: {_selectedMethod},
                      onSelectionChanged: (val) {
                        setState(() {
                          _selectedMethod = val.first;
                          _errorMessage = null;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Method Specific Simulated Views
                    if (_selectedMethod == 'UPI') ...[
                      // UPI Demo View
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Demo UPI Application:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children:
                                  [
                                    'Google Pay',
                                    'PhonePe',
                                    'Paytm',
                                    'BHIM UPI',
                                  ].map((app) {
                                    final isSel = _selectedUpiApp == app;
                                    return ChoiceChip(
                                      label: Text(app),
                                      selected: isSel,
                                      onSelected: (_) =>
                                          setState(() => _selectedUpiApp = app),
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _upiIdCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Simulated UPI ID / VPA',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.alternate_email),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_selectedMethod == 'Card') ...[
                      // Card Demo View
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'DEMO PAYMENT CARD',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Icon(Icons.credit_card, color: Colors.white),
                              ],
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              '•••• •••• •••• 4242',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CARD HOLDER',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 9,
                                      ),
                                    ),
                                    Text(
                                      'DEMO TEST MERCHANT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'EXPIRES',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 9,
                                      ),
                                    ),
                                    Text(
                                      '12/29',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Cash Demo View
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _cashReceivedCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => _calculateChange(),
                              decoration: const InputDecoration(
                                labelText: 'Cash Received (₹)',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Change Due to Customer:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '₹${_changeDue.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: _changeDue > 0
                                        ? Colors.green.shade800
                                        : Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Actions
                    if (_isProcessing) ...[
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text(
                              'Processing simulated payment...',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _processSimulatedPayment(
                                simulateSuccess: true,
                              ),
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(
                                _selectedMethod == 'Cash'
                                    ? 'Confirm Demo Cash (₹${grandTotal.toStringAsFixed(2)})'
                                    : 'Complete Demo Payment (₹${grandTotal.toStringAsFixed(2)})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          if (_selectedMethod != 'Cash') ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _processSimulatedPayment(
                                  simulateSuccess: false,
                                ),
                                icon: const Icon(
                                  Icons.highlight_off,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Simulate Failure',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.red.shade300),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
