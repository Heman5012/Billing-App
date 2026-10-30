import 'package:flutter/material.dart';

import '../services/cart_service.dart';

class CurrentBillIndicator extends StatelessWidget {
  final VoidCallback? onViewBill;
  final VoidCallback? onMakePayment;
  final String currency;

  const CurrentBillIndicator({
    super.key,
    this.onViewBill,
    this.onMakePayment,
    this.currency = '₹',
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService.instance,
      builder: (context, _) {
        final cart = CartService.instance;
        if (cart.isEmpty) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Material(
              elevation: 4,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF0F172A), // Sleek dark slate pill
              child: InkWell(
                onTap: onViewBill,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Cart Badge & Summary
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Badge(
                          isLabelVisible: cart.itemCount > 0,
                          label: Text('${cart.itemCount}'),
                          backgroundColor: const Color(0xFFEF4444),
                          child: const Icon(
                            Icons.shopping_cart_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${cart.itemCount} ${cart.itemCount == 1 ? "item" : "items"} (${cart.totalQuantity} pcs)',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '$currency${cart.grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action Buttons
                      if (onViewBill != null)
                        TextButton.icon(
                          onPressed: onViewBill,
                          icon: const Icon(
                            Icons.receipt_long,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'View Bill',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),

                      if (onMakePayment != null) ...[
                        const SizedBox(width: 6),
                        FilledButton.icon(
                          onPressed: cart.isEmpty ? null : onMakePayment,
                          icon: const Icon(Icons.payment, size: 16),
                          label: const Text(
                            'Pay',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

