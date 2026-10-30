import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/invoice.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/invoice_service.dart';
import '../services/pdf_service.dart';

class HistoryScreen extends StatefulWidget {
  final ValueChanged<Invoice> onSelectInvoice;

  const HistoryScreen({super.key, required this.onSelectInvoice});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  String _selectedPaymentMethod = 'All';
  String _selectedStatus = 'All';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text('Please sign in to view billing history.'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<BusinessProfile>(
        stream: FirebaseService.instance.streamBusinessProfile(user.uid),
        builder: (context, profileSnap) {
          final business = profileSnap.data ?? BusinessProfile();

          return StreamBuilder<List<Invoice>>(
            stream: InvoiceService.instance.streamInvoices(
              user.uid,
              searchQuery: _searchQuery,
              paymentMethod: _selectedPaymentMethod,
              status: _selectedStatus,
              startDate: _startDate,
              endDate: _endDate,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading invoices: ${snapshot.error}'),
                );
              }

              final invoices = snapshot.data ?? [];

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isSmall = constraints.maxWidth < 600;
                  final horizontalPadding = isSmall ? 16.0 : 24.0;

                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(horizontalPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Billing History',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${invoices.length} invoices found',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Search Bar
                              TextField(
                                onChanged: (val) =>
                                    setState(() => _searchQuery = val),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search by invoice #, customer name or phone...',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade400,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Filter Chips & Date Range
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Payment Method Dropdown
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedPaymentMethod,
                                        isDense: true,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF0F172A),
                                        ),
                                        items:
                                            [
                                                  'All',
                                                  'UPI (Demo)',
                                                  'Card (Demo)',
                                                  'Cash (Demo)',
                                                ]
                                                .map(
                                                  (m) => DropdownMenuItem(
                                                    value: m,
                                                    child: Text('Method: $m'),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(
                                              () =>
                                                  _selectedPaymentMethod = v,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),

                                  // Status Dropdown
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedStatus,
                                        isDense: true,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF0F172A),
                                        ),
                                        items: ['All', 'paid', 'cancelled']
                                            .map(
                                              (s) => DropdownMenuItem(
                                                value: s,
                                                child: Text('Status: $s'),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() => _selectedStatus = v);
                                          }
                                        },
                                      ),
                                    ),
                                  ),

                                  // Date Range Picker Button
                                  OutlinedButton.icon(
                                    onPressed: () => _pickDateRange(context),
                                    icon: const Icon(
                                      Icons.date_range,
                                      size: 15,
                                    ),
                                    label: Text(
                                      _startDate != null
                                          ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate ?? _startDate!)}'
                                          : 'Date Range',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),

                                  if (_startDate != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      tooltip: 'Clear date filter',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setState(() {
                                          _startDate = null;
                                          _endDate = null;
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Invoices List
                      if (invoices.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 48,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No invoices found matching criteria.',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final inv = invoices[index];
                              final formattedDate = DateFormat(
                                'dd MMM yyyy, hh:mm a',
                              ).format(inv.createdAt);

                              return Card(
                                elevation: 0.5,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: InkWell(
                                  onTap: () => widget.onSelectInvoice(inv),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Top Row: Avatar + Invoice Number + Status Badge + Action Menu
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: inv.isPaid
                                                  ? const Color(0xFFE3F2FD)
                                                  : Colors.red.shade50,
                                              child: Icon(
                                                inv.isPaid
                                                    ? Icons.receipt
                                                    : Icons.cancel_outlined,
                                                size: 16,
                                                color: inv.isPaid
                                                    ? const Color(0xFF10B981)
                                                    : Colors.red.shade700,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      inv.invoiceNumber,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13.5,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: inv.isPaid
                                                          ? Colors
                                                                .green
                                                                .shade50
                                                          : Colors.red.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      border: Border.all(
                                                        color: inv.isPaid
                                                            ? Colors
                                                                  .green
                                                                  .shade300
                                                            : Colors
                                                                  .red
                                                                  .shade300,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      inv.paymentStatus
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 9.0,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: inv.isPaid
                                                            ? Colors
                                                                  .green
                                                                  .shade800
                                                            : Colors
                                                                  .red
                                                                  .shade800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuButton<String>(
                                              padding: EdgeInsets.zero,
                                              iconSize: 20,
                                              constraints:
                                                  const BoxConstraints(),
                                              onSelected: (action) async {
                                                if (action == 'view') {
                                                  widget.onSelectInvoice(inv);
                                                } else if (action == 'pdf') {
                                                  await PdfService.instance
                                                      .printInvoice(
                                                        invoice: inv,
                                                        business: business,
                                                      );
                                                } else if (action == 'share') {
                                                  await PdfService.instance
                                                      .shareInvoicePdf(
                                                        invoice: inv,
                                                        business: business,
                                                      );
                                                } else if (action == 'cancel') {
                                                  _confirmCancelInvoice(
                                                    context,
                                                    user.uid,
                                                    inv,
                                                  );
                                                }
                                              },
                                              itemBuilder: (ctx) => [
                                                const PopupMenuItem(
                                                  value: 'view',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .visibility_outlined,
                                                        size: 18,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text('View Details'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'pdf',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.print_outlined,
                                                        size: 18,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Print / Download PDF',
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'share',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.share_outlined,
                                                        size: 18,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text('Share PDF'),
                                                    ],
                                                  ),
                                                ),
                                                if (inv.isPaid)
                                                  const PopupMenuItem(
                                                    value: 'cancel',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.cancel_outlined,
                                                          size: 18,
                                                          color: Colors.red,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Cancel Invoice',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Bottom Row: Details and Total Amount
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${inv.items.length} items • $formattedDate',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                  if (inv.customer.isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 2,
                                                          ),
                                                      child: Text(
                                                        'Customer: ${inv.customer.name}${inv.customer.phone.isNotEmpty ? ' (${inv.customer.phone})' : ''}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .grey
                                                              .shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 2,
                                                        ),
                                                    child: Text(
                                                      'Payment: ${inv.paymentMethod}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey
                                                            .shade700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              '₹${inv.total.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF10B981),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }, childCount: invoices.length),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _confirmCancelInvoice(
    BuildContext context,
    String uid,
    Invoice invoice,
  ) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Invoice'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel invoice "${invoice.invoiceNumber}"? This will update the invoice status to CANCELLED for financial auditing.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason for Cancellation *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Go Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason.')),
                );
                return;
              }

              await InvoiceService.instance.cancelInvoice(
                uid,
                invoice.id,
                reasonCtrl.text.trim(),
              );

              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );
  }
}
