import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../models/invoice.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onCreateBillPressed;
  final VoidCallback onAddProductPressed;
  final ValueChanged<Invoice> onInvoiceSelected;
  final VoidCallback? onScanQrPressed;

  const DashboardScreen({
    super.key,
    required this.onCreateBillPressed,
    required this.onAddProductPressed,
    required this.onInvoiceSelected,
    this.onScanQrPressed,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to view dashboard.'));
    }

    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return StreamBuilder<DashboardStats>(
      stream: FirebaseService.instance.streamDashboardStats(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Failed to load dashboard: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final stats =
            snapshot.data ??
            DashboardStats(
              todaySales: 0.0,
              totalInvoices: 0,
              totalProducts: 0,
              avgInvoiceValue: 0.0,
              recentInvoices: [],
              last7DaysSales: {},
              lowStockProducts: [],
              topSellingProducts: [],
            );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 600;

            return SingleChildScrollView(
              padding: EdgeInsets.all(isSmall ? 16.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header & Quick Actions
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isSmall
                              ? (constraints.maxWidth - 32)
                              : (constraints.maxWidth - 48) * 0.55,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, ${user.displayName ?? "Merchant"}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Real-time overview of your store billing and inventory',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (onScanQrPressed != null)
                            OutlinedButton.icon(
                              onPressed: onScanQrPressed,
                              icon: const Icon(Icons.qr_code_scanner, size: 16),
                              label: const Text('Scan QR'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                foregroundColor: const Color(0xFF1E88E5),
                                side: const BorderSide(
                                  color: Color(0xFF90CAF9),
                                ),
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: onAddProductPressed,
                            icon: const Icon(Icons.add_box_outlined, size: 16),
                            label: const Text('Add Product'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: onCreateBillPressed,
                            icon: const Icon(Icons.receipt, size: 16),
                            label: const Text('Create Bill'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1E88E5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // KPI Metric Cards arranged vertically in a Column
                  Column(
                    children: [
                      _buildMetricCard(
                        width: double.infinity,
                        title: "Today's Sales",
                        value: currencyFormat.format(stats.todaySales),
                        subtitle: 'Simulated Demo Sales',
                        icon: Icons.payments_outlined,
                        color: const Color(0xFF1E88E5),
                        bgLight: const Color(0xFFE3F2FD),
                      ),
                      const SizedBox(height: 12),
                      _buildMetricCard(
                        width: double.infinity,
                        title: 'Completed Bills',
                        value: stats.totalInvoices.toString(),
                        subtitle: 'Paid transactions',
                        icon: Icons.receipt_long,
                        color: const Color(0xFF2E7D32),
                        bgLight: const Color(0xFFE8F5E9),
                      ),
                      const SizedBox(height: 12),
                      _buildMetricCard(
                        width: double.infinity,
                        title: 'Avg. Bill Value',
                        value: currencyFormat.format(stats.avgInvoiceValue),
                        subtitle: 'Per invoice',
                        icon: Icons.trending_up,
                        color: const Color(0xFF7B1FA2),
                        bgLight: const Color(0xFFF3E5F5),
                      ),
                      const SizedBox(height: 12),
                      _buildMetricCard(
                        width: double.infinity,
                        title: 'Total Products',
                        value: stats.totalProducts.toString(),
                        subtitle: stats.lowStockProducts.isNotEmpty
                            ? '${stats.lowStockProducts.length} low stock'
                            : 'All in stock',
                        icon: Icons.inventory_2_outlined,
                        color: stats.lowStockProducts.isNotEmpty
                            ? const Color(0xFFE65100)
                            : const Color(0xFF00897B),
                        bgLight: stats.lowStockProducts.isNotEmpty
                            ? const Color(0xFFFFF3E0)
                            : const Color(0xFFE0F2F1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 7-DAY SALES SUMMARY
                  Container(
                    padding: const EdgeInsets.all(16),
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
                              '7-Day Sales Trend',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                border: Border.all(
                                  color: Colors.amber.shade300,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Demo Transactions',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Visual Day Bars with Expanded & FittedBox to prevent any overflow
                        if (stats.last7DaysSales.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No sales recorded in the past 7 days.',
                              ),
                            ),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, chartConstraints) {
                              final maxSale = stats.last7DaysSales.values.fold(
                                1.0,
                                (prev, curr) => curr > prev ? curr : prev,
                              );

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: stats.last7DaysSales.entries.map((e) {
                                  final heightRatio = (e.value / maxSale).clamp(
                                    0.08,
                                    1.0,
                                  );

                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              e.value > 0
                                                  ? '₹${e.value.toStringAsFixed(0)}'
                                                  : '₹0',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: e.value > 0
                                                    ? const Color(0xFF1E88E5)
                                                    : Colors.grey.shade400,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            width: 22,
                                            height: 80 * heightRatio,
                                            decoration: BoxDecoration(
                                              color: e.value > 0
                                                  ? const Color(0xFF1E88E5)
                                                  : Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              e.key,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // RECENT INVOICES & TOP SELLING PRODUCTS
                  Builder(
                    builder: (context) {
                      final isWide = constraints.maxWidth >= 800;

                      final recentInvoicesWidget = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recent Transactions',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (stats.recentInvoices.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        size: 36,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No invoices generated yet.',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: onCreateBillPressed,
                                        child: const Text(
                                          'Create your first bill',
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
                                itemCount: stats.recentInvoices.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final inv = stats.recentInvoices[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 17,
                                      backgroundColor: const Color(0xFFE3F2FD),
                                      child: Icon(
                                        inv.paymentMethod.contains('UPI')
                                            ? Icons.qr_code_2
                                            : (inv.paymentMethod.contains(
                                                    'Card',
                                                  )
                                                  ? Icons.credit_card
                                                  : Icons.monetization_on),
                                        color: const Color(0xFF1E88E5),
                                        size: 16,
                                      ),
                                    ),
                                    title: Text(
                                      inv.invoiceNumber,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${inv.items.length} items • ${DateFormat('dd MMM, hh:mm a').format(inv.createdAt)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${inv.total.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            color: Color(0xFF1E88E5),
                                          ),
                                        ),
                                        Text(
                                          inv.paymentStatus.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: inv.isPaid
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () => onInvoiceSelected(inv),
                                  );
                                },
                              ),
                          ],
                        ),
                      );

                      final topProductsWidget = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Frequently Sold Products',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (stats.topSellingProducts.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.bar_chart,
                                        size: 36,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Sales statistics will appear here.',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12.5,
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
                                itemCount: stats.topSellingProducts.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = stats.topSellingProducts[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: Colors.amber.shade50,
                                      child: Text(
                                        '#${index + 1}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      item.key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    trailing: Text(
                                      '${item.value} units',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
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
                            Expanded(flex: 3, child: recentInvoicesWidget),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: topProductsWidget),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            recentInvoicesWidget,
                            const SizedBox(height: 16),
                            topProductsWidget,
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard({
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgLight,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
