import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/invoice.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/pdf_service.dart';

class InvoiceScreen extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onStartNewBill;
  final VoidCallback onBackToHistory;

  const InvoiceScreen({
    super.key,
    required this.invoice,
    required this.onStartNewBill,
    required this.onBackToHistory,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final formattedDate = dateFormat.format(invoice.createdAt);

    // Secure unguessable retrieval link
    final publicShareUrl =
        'https://billing-and-invoice-fe416.web.app/?token=${invoice.shareToken}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Invoice ${invoice.invoiceNumber}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBackToHistory,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart),
            tooltip: 'Start New Bill',
            onPressed: onStartNewBill,
          ),
        ],
      ),
      body: FutureBuilder<BusinessProfile>(
        future: user != null
            ? FirebaseService.instance.getBusinessProfile(user.uid)
            : Future.value(BusinessProfile()),
        builder: (context, snapshot) {
          final business = snapshot.data ?? BusinessProfile();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 680;

              return SingleChildScrollView(
                padding: EdgeInsets.all(isCompact ? 12.0 : 24.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Actions Card (Print, Share, New Bill)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(6),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.check_circle,
                                      color: Colors.green.shade700,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Invoice Completed',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.5,
                                          color: Colors.green.shade900,
                                        ),
                                      ),
                                      Text(
                                        'Recorded securely to cloud records',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () async {
                                      await PdfService.instance.printInvoice(
                                        invoice: invoice,
                                        business: business,
                                      );
                                    },
                                    icon: const Icon(Icons.print, size: 15),
                                    label: const Text('Print / Save PDF'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await PdfService.instance.shareInvoicePdf(
                                        invoice: invoice,
                                        business: business,
                                      );
                                    },
                                    icon: const Icon(Icons.share, size: 15),
                                    label: const Text('Share PDF'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: onStartNewBill,
                                    icon: const Icon(Icons.add, size: 15),
                                    label: const Text('New Bill'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // INVOICE RECEIPT CARD
                        Card(
                          elevation: 1,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isCompact ? 16.0 : 28.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Badge Row: Brand + TAX INVOICE + DEMO TRANSACTION
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
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
                                            borderRadius:
                                                BorderRadius.circular(6),
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
                                          'TAX INVOICE',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        border: Border.all(
                                          color: Colors.amber.shade400,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'DEMO TRANSACTION',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Business info & Metadata container
                                if (isCompact) ...[
                                  // Mobile Business Stack
                                  Text(
                                    business.businessName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (business.address.isNotEmpty)
                                    Text(
                                      business.address,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  if (business.phone.isNotEmpty)
                                    Text(
                                      'Phone: ${business.phone}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  // Metadata Pill Card (Invoice #, Date, Payment Status)
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              invoice.invoiceNumber,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                            Text(
                                              formattedDate,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: invoice.isPaid
                                                ? Colors.green.shade50
                                                : Colors.red.shade50,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: invoice.isPaid
                                                  ? Colors.green.shade300
                                                  : Colors.red.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            '${invoice.paymentMethod} • ${invoice.paymentStatus.toUpperCase()}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: invoice.isPaid
                                                  ? Colors.green.shade800
                                                  : Colors.red.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  // Desktop Side-by-Side Business & Metadata Header
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              business.businessName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            if (business.address.isNotEmpty)
                                              Text(
                                                business.address,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            if (business.phone.isNotEmpty)
                                              Text(
                                                'Phone: ${business.phone}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              invoice.invoiceNumber,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              formattedDate,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: invoice.isPaid
                                                    ? Colors.green.shade50
                                                    : Colors.red.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: invoice.isPaid
                                                      ? Colors.green.shade300
                                                      : Colors.red.shade300,
                                                ),
                                              ),
                                              child: Text(
                                                '${invoice.paymentMethod} • ${invoice.paymentStatus.toUpperCase()}',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: invoice.isPaid
                                                      ? Colors.green.shade800
                                                      : Colors.red.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const Divider(height: 24),

                                // Customer Details (if recorded)
                                if (invoice.customer.isNotEmpty) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Billed To: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              invoice.customer.name.isNotEmpty
                                                  ? invoice.customer.name
                                                  : 'Customer',
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        if (invoice
                                            .customer
                                            .phone
                                            .isNotEmpty) ...[
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'Phone: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                invoice.customer.phone,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                // Items Table
                                Table(
                                  border: TableBorder(
                                    horizontalInside: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                    bottom: BorderSide(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  columnWidths: const {
                                    0: FlexColumnWidth(3.0),
                                    1: FlexColumnWidth(2.2),
                                    2: FlexColumnWidth(1.0),
                                    3: FlexColumnWidth(1.2),
                                    4: FlexColumnWidth(2.6),
                                  },
                                  children: [
                                    TableRow(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                      ),
                                      children: const [
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            'Item',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            'Unit Price',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            'Qty',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            'Tax',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            'Total',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    ...invoice.items.map((item) {
                                      return TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 4,
                                            ),
                                            child: Text(
                                              item.name,
                                              style: TextStyle(
                                                fontSize: isCompact ? 12 : 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 4,
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                '₹${item.unitPrice.toStringAsFixed(2)}',
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontSize:
                                                      isCompact ? 11.5 : 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 4,
                                            ),
                                            child: Text(
                                              '${item.quantity}',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: isCompact ? 12 : 13,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 4,
                                            ),
                                            child: Text(
                                              item.taxRate > 0
                                                  ? '${item.taxRate.toStringAsFixed(0)}%'
                                                  : '0%',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize:
                                                    isCompact ? 11.5 : 13,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 4,
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                '₹${item.lineTotal.toStringAsFixed(2)}',
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontSize: isCompact ? 12 : 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                // Bottom Summary & QR Code
                                if (isCompact) ...[
                                  // Mobile: Financial Breakdown stacked with QR Code
                                  Column(
                                    children: [
                                      _row(
                                        'Subtotal',
                                        '₹${invoice.subtotal.toStringAsFixed(2)}',
                                      ),
                                      if (invoice.overallDiscountAmount > 0)
                                        _row(
                                          'Discount (${invoice.overallDiscountPercent.toStringAsFixed(0)}%)',
                                          '-₹${invoice.overallDiscountAmount.toStringAsFixed(2)}',
                                          isNegative: true,
                                        ),
                                      _row(
                                        'Taxable Amount',
                                        '₹${invoice.taxableAmount.toStringAsFixed(2)}',
                                      ),
                                      ...invoice.taxBreakdown.entries.map(
                                        (e) => _row(
                                          'Tax (${e.key})',
                                          '₹${e.value.toStringAsFixed(2)}',
                                        ),
                                      ),
                                      const Divider(height: 16),
                                      _row(
                                        'Grand Total',
                                        '₹${invoice.total.toStringAsFixed(2)}',
                                        isBold: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Center(
                                    child: _buildQrCard(
                                      context,
                                      publicShareUrl,
                                      invoice.shareToken,
                                    ),
                                  ),
                                ] else ...[
                                  // Desktop Side-by-Side: QR Card and Fluid Financial Summary
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildQrCard(
                                        context,
                                        publicShareUrl,
                                        invoice.shareToken,
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            _row(
                                              'Subtotal',
                                              '₹${invoice.subtotal.toStringAsFixed(2)}',
                                            ),
                                            if (invoice.overallDiscountAmount >
                                                0)
                                              _row(
                                                'Discount (${invoice.overallDiscountPercent.toStringAsFixed(0)}%)',
                                                '-₹${invoice.overallDiscountAmount.toStringAsFixed(2)}',
                                                isNegative: true,
                                              ),
                                            _row(
                                              'Taxable Amount',
                                              '₹${invoice.taxableAmount.toStringAsFixed(2)}',
                                            ),
                                            ...invoice.taxBreakdown.entries.map(
                                              (e) => _row(
                                                'Tax (${e.key})',
                                                '₹${e.value.toStringAsFixed(2)}',
                                              ),
                                            ),
                                            const Divider(height: 16),
                                            _row(
                                              'Grand Total',
                                              '₹${invoice.total.toStringAsFixed(2)}',
                                              isBold: true,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                if (invoice.notes.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Note: ${invoice.notes}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildQrCard(
    BuildContext context,
    String url,
    String shareToken,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: url,
            version: QrVersions.auto,
            size: 130.0,
            padding: const EdgeInsets.all(4),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan to Retrieve',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            'Token: ${shareToken.length > 8 ? shareToken.substring(0, 8) : shareToken}...',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invoice link copied to clipboard!'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 13),
            label: const Text('Copy Link', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 28),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool isBold = false,
    bool isNegative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 14 : 12.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isBold ? 16 : 12.5,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                color: isNegative
                    ? Colors.red.shade700
                    : (isBold ? const Color(0xFF10B981) : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
