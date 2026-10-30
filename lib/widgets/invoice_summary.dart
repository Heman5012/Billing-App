import 'package:flutter/material.dart';

class InvoiceSummaryWidget extends StatelessWidget {
  final double subtotal;
  final double overallDiscountPercent;
  final double overallDiscountAmount;
  final double taxableAmount;
  final double tax;
  final Map<String, double> taxBreakdown;
  final double total;
  final String currency;
  final ValueChanged<double>? onOverallDiscountChanged;

  const InvoiceSummaryWidget({
    super.key,
    required this.subtotal,
    this.overallDiscountPercent = 0.0,
    required this.overallDiscountAmount,
    required this.taxableAmount,
    required this.tax,
    required this.taxBreakdown,
    required this.total,
    this.currency = '₹',
    this.onOverallDiscountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bill Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (onOverallDiscountChanged != null)
                TextButton.icon(
                  onPressed: () => _showDiscountDialog(context),
                  icon: const Icon(Icons.percent, size: 16),
                  label: Text(
                    overallDiscountPercent > 0
                        ? '${overallDiscountPercent.toStringAsFixed(0)}% Off'
                        : 'Add Discount',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _row('Subtotal', '$currency${subtotal.toStringAsFixed(2)}'),
          if (overallDiscountAmount > 0) ...[
            const SizedBox(height: 6),
            _row(
              'Overall Discount (${overallDiscountPercent.toStringAsFixed(0)}%)',
              '-$currency${overallDiscountAmount.toStringAsFixed(2)}',
              isNegative: true,
            ),
          ],
          const SizedBox(height: 6),
          _row(
            'Taxable Amount',
            '$currency${taxableAmount.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 6),
          if (taxBreakdown.isNotEmpty)
            ...taxBreakdown.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _row(
                  'Tax (${e.key})',
                  '$currency${e.value.toStringAsFixed(2)}',
                  isSubtle: true,
                ),
              ),
            )
          else
            _row('Tax', '$currency${tax.toStringAsFixed(2)}'),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Total Payable',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$currency${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool isNegative = false,
    bool isSubtle = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isSubtle ? Colors.grey.shade600 : Colors.grey.shade800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isNegative
                  ? Colors.red.shade600
                  : (isSubtle ? Colors.grey.shade700 : Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  void _showDiscountDialog(BuildContext context) {
    final controller = TextEditingController(
      text: overallDiscountPercent > 0
          ? overallDiscountPercent.toStringAsFixed(0)
          : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Overall Bill Discount'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter overall discount percentage (0 to 100%):',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Discount %',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              onOverallDiscountChanged?.call(0.0);
              Navigator.of(ctx).pop();
            },
            child: const Text('Clear Discount'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? 0.0;
              if (val >= 0 && val <= 100) {
                onOverallDiscountChanged?.call(val);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
