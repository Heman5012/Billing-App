import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/invoice.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/invoice_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to view reports.'));
    }

    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<List<Product>>(
        stream: FirebaseService.instance.streamProducts(user.uid),
        builder: (context, prodSnap) {
          final products = prodSnap.data ?? [];
          final lowStockProducts = products.where((p) => p.isLowStock).toList();

          return StreamBuilder<List<Invoice>>(
            stream: InvoiceService.instance.streamInvoices(user.uid),
            builder: (context, invSnap) {
              if (invSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allInvoices = invSnap.data ?? [];
              // Only consider PAID invoices for revenue totals
              final paidInvoices = allInvoices
                  .where((inv) => inv.isPaid)
                  .toList();

              double dailySales = 0.0;
              double weeklySales = 0.0;
              double monthlySales = 0.0;
              double totalSales = 0.0;

              final paymentMethodCounts = <String, int>{};
              final productUnitsSold = <String, int>{};
              final productRevenue = <String, double>{};

              for (final inv in paidInvoices) {
                totalSales += inv.total;

                if (inv.createdAt.isAfter(todayStart)) {
                  dailySales += inv.total;
                }
                if (inv.createdAt.isAfter(weekAgo)) {
                  weeklySales += inv.total;
                }
                if (inv.createdAt.isAfter(monthStart)) {
                  monthlySales += inv.total;
                }

                // Payment method breakdown
                final pm = inv.paymentMethod.contains('UPI')
                    ? 'UPI'
                    : (inv.paymentMethod.contains('Card')
                          ? 'Card'
                          : (inv.paymentMethod.contains('Cash')
                                ? 'Cash'
                                : 'Other'));
                paymentMethodCounts[pm] = (paymentMethodCounts[pm] ?? 0) + 1;

                // Products breakdown
                for (final item in inv.items) {
                  productUnitsSold[item.name] =
                      (productUnitsSold[item.name] ?? 0) + item.quantity;
                  productRevenue[item.name] =
                      (productRevenue[item.name] ?? 0.0) + item.lineTotal;
                }
              }

              final sortedProducts = productUnitsSold.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isSmall = constraints.maxWidth < 600;

                  return SingleChildScrollView(
                    padding: EdgeInsets.all(isSmall ? 16.0 : 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header & Demo Notice
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sales & Business Reports',
                              style: TextStyle(
                                fontSize: isSmall ? 20 : 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Consolidated financial and inventory metrics',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                    const SizedBox(height: 16),

                    // DEMO NOTICE
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
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'NOTICE: All sales figures reflect simulated demo mode transactions and do not represent real-world bank earnings.',
                              style: TextStyle(
                                color: Color(0xFF9A3412),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Revenue Period Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 720;
                        final cardWidth = isWide
                            ? (constraints.maxWidth - 48) / 4
                            : (constraints.maxWidth - 16) / 2;

                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _reportCard(
                              width: cardWidth,
                              title: 'Daily Sales',
                              value: currencyFormat.format(dailySales),
                              subtitle: "Today's demo revenue",
                              icon: Icons.today,
                              color: const Color(0xFF10B981),
                            ),
                            _reportCard(
                              width: cardWidth,
                              title: 'Weekly Sales',
                              value: currencyFormat.format(weeklySales),
                              subtitle: 'Last 7 days demo',
                              icon: Icons.calendar_view_week,
                              color: const Color(0xFF2E7D32),
                            ),
                            _reportCard(
                              width: cardWidth,
                              title: 'Monthly Sales',
                              value: currencyFormat.format(monthlySales),
                              subtitle:
                                  '${DateFormat('MMMM').format(now)} demo',
                              icon: Icons.calendar_month,
                              color: const Color(0xFF7B1FA2),
                            ),
                            _reportCard(
                              width: cardWidth,
                              title: 'Completed Bills',
                              value: paidInvoices.length.toString(),
                              subtitle:
                                  'Avg: ${currencyFormat.format(paidInvoices.isNotEmpty ? totalSales / paidInvoices.length : 0)}',
                              icon: Icons.receipt_long,
                              color: const Color(0xFFE65100),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // PAYMENT METHOD BREAKDOWN & TOP SELLING ITEMS
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 800;

                        final paymentMethodWidget = Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Payment Method Distribution',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (paymentMethodCounts.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(
                                    child: Text(
                                      'No completed transactions yet.',
                                    ),
                                  ),
                                )
                              else
                                ...paymentMethodCounts.entries.map((entry) {
                                  final count = entry.value;
                                  final total = paidInvoices.length;
                                  final percent = total > 0
                                      ? (count / total) * 100
                                      : 0.0;

                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12.0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                entry.key,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                '$count bills (${percent.toStringAsFixed(1)}%)',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        LinearProgressIndicator(
                                          value: percent / 100,
                                          backgroundColor: Colors.grey.shade200,
                                          color: const Color(0xFF10B981),
                                          minHeight: 8,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        );

                        final topItemsWidget = Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Best-Selling Products',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (sortedProducts.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(
                                    child: Text('No items sold yet.'),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: sortedProducts.take(5).length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final p = sortedProducts[index];
                                    final rev = productRevenue[p.key] ?? 0.0;

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(
                                          0xFFE3F2FD,
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Color(0xFF10B981),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        p.key,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${p.value} units sold',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      trailing: Text(
                                        currencyFormat.format(rev),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        );

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: paymentMethodWidget),
                              const SizedBox(width: 20),
                              Expanded(child: topItemsWidget),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              paymentMethodWidget,
                              const SizedBox(height: 20),
                              topItemsWidget,
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 28),

                    // LOW STOCK INVENTORY SECTION
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              const Text(
                                'Low Stock Inventory Alerts',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: lowStockProducts.isNotEmpty
                                      ? Colors.amber.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${lowStockProducts.length} items need attention',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: lowStockProducts.isNotEmpty
                                        ? Colors.amber.shade900
                                        : Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (lowStockProducts.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green.shade600,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'All products have sufficient stock levels.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: lowStockProducts.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final prod = lowStockProducts[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    prod.isOutOfStock
                                        ? Icons.error_outline
                                        : Icons.warning_amber,
                                    color: prod.isOutOfStock
                                        ? Colors.red
                                        : Colors.amber.shade800,
                                  ),
                                  title: Text(
                                    prod.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Price: ₹${prod.price.toStringAsFixed(2)} • Category: ${prod.category}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: prod.isOutOfStock
                                          ? Colors.red.shade50
                                          : Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: prod.isOutOfStock
                                            ? Colors.red.shade300
                                            : Colors.amber.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      prod.isOutOfStock
                                          ? '0 In Stock'
                                          : '${prod.stock} Left',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: prod.isOutOfStock
                                            ? Colors.red.shade700
                                            : Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  ),
);
}

  Widget _reportCard({
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
