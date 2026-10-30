import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/cart_service.dart';

class NavigationDestinationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const NavigationDestinationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class AppNavigationShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final VoidCallback? onScanQrPressed;
  final VoidCallback? onOpenCart;

  const AppNavigationShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.onScanQrPressed,
    this.onOpenCart,
  });

  static const List<NavigationDestinationItem> destinations = [
    NavigationDestinationItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    NavigationDestinationItem(
      label: 'Products',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
    NavigationDestinationItem(
      label: 'Create Bill',
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
    ),
    NavigationDestinationItem(
      label: 'History',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
    NavigationDestinationItem(
      label: 'Reports',
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
    ),
    NavigationDestinationItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 860;
    final user = AuthService.instance.currentUser;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // DESKTOP SIDEBAR
            Container(
              width: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: Colors.grey.shade200, width: 1.5),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // BillWave Logo & Brand
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E88E5)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.receipt_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BillWave',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1565C0),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Smart Billing POS',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  const SizedBox(height: 16),

                  // Navigation Items
                  Expanded(
                    child: ListView.builder(
                      itemCount: destinations.length,
                      itemBuilder: (context, index) {
                        final item = destinations[index];
                        final isSelected = selectedIndex == index;
                        final isCart = item.label == 'Create Bill';
                        return ListenableBuilder(
                          listenable: CartService.instance,
                          builder: (context, _) {
                            final count = CartService.instance.itemCount;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 3,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    if (index == 2 && onOpenCart != null) {
                                      onOpenCart!();
                                    } else {
                                      onDestinationSelected(index);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFE3F2FD)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        (isCart && count > 0)
                                            ? Badge(
                                                label: Text('$count'),
                                                backgroundColor:
                                                    const Color(0xFFEF4444),
                                                child: Icon(
                                                  isSelected
                                                      ? item.selectedIcon
                                                      : item.icon,
                                                  color: isSelected
                                                      ? const Color(0xFF1E88E5)
                                                      : Colors.grey.shade700,
                                                  size: 22,
                                                ),
                                              )
                                            : Icon(
                                                isSelected
                                                    ? item.selectedIcon
                                                    : item.icon,
                                                color: isSelected
                                                    ? const Color(0xFF1E88E5)
                                                    : Colors.grey.shade700,
                                                size: 22,
                                              ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            item.label,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? const Color(0xFF1E88E5)
                                                  : Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                        if (isCart && count > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$count',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Scan QR shortcut button
                  if (onScanQrPressed != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: onScanQrPressed,
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: const Text('Scan Invoice QR'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          foregroundColor: const Color(0xFF1E88E5),
                          side: const BorderSide(color: Color(0xFF90CAF9)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // User Profile & Sign Out
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE3F2FD),
                          backgroundImage: user?.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : null,
                          child: user?.photoURL == null
                              ? Text(
                                  (user?.displayName?.isNotEmpty ?? false)
                                      ? user!.displayName![0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E88E5),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? 'Merchant',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user?.email ?? 'signed in',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sign Out',
                          icon: const Icon(Icons.logout, size: 20),
                          color: Colors.red.shade400,
                          onPressed: () => _confirmSignOut(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // MAIN CONTENT AREA
            Expanded(child: child),
          ],
        ),
      );
    } else {
      // MOBILE / TABLET LAYOUT
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                destinations[selectedIndex].label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          actions: [
            if (onScanQrPressed != null)
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'Scan Invoice QR',
                onPressed: onScanQrPressed,
              ),
            ListenableBuilder(
              listenable: CartService.instance,
              builder: (context, _) {
                final count = CartService.instance.itemCount;
                return IconButton(
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    backgroundColor: const Color(0xFFEF4444),
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                  tooltip: 'View Current Bill ($count items)',
                  onPressed: onOpenCart,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: () => _confirmSignOut(context),
            ),
          ],
        ),
        drawer: Drawer(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF1E88E5)),
                accountName: Text(
                  user?.displayName ?? 'BillWave Merchant',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(user?.email ?? 'Signed in'),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? Text(
                          (user?.displayName?.isNotEmpty ?? false)
                              ? user!.displayName![0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E88E5),
                          ),
                        )
                      : null,
                ),
              ),
              ...List.generate(destinations.length, (index) {
                final d = destinations[index];
                final isCart = d.label == 'Create Bill';
                return ListenableBuilder(
                  listenable: CartService.instance,
                  builder: (context, _) {
                    final count = CartService.instance.itemCount;
                    return ListTile(
                      leading: (isCart && count > 0)
                          ? Badge(
                              label: Text('$count'),
                              backgroundColor: const Color(0xFFEF4444),
                              child: Icon(
                                d.icon,
                                color: selectedIndex == index
                                    ? const Color(0xFF1E88E5)
                                    : null,
                              ),
                            )
                          : Icon(
                              d.icon,
                              color: selectedIndex == index
                                  ? const Color(0xFF1E88E5)
                                  : null,
                            ),
                      title: Text(
                        d.label,
                        style: TextStyle(
                          fontWeight: selectedIndex == index
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: selectedIndex == index
                              ? const Color(0xFF1E88E5)
                              : null,
                        ),
                      ),
                      trailing: (isCart && count > 0)
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                      selected: selectedIndex == index,
                      onTap: () {
                        Navigator.of(context).pop();
                        if (index == 2 && onOpenCart != null) {
                          onOpenCart!();
                        } else {
                          onDestinationSelected(index);
                        }
                      },
                    );
                  },
                );
              }),
              const Spacer(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmSignOut(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        body: child,
        bottomNavigationBar: ListenableBuilder(
          listenable: CartService.instance,
          builder: (context, _) {
            final count = CartService.instance.itemCount;
            return NavigationBar(
              selectedIndex: selectedIndex.clamp(0, 3), // Top 4 items
              onDestinationSelected: (idx) {
                if (idx == 2 && onOpenCart != null) {
                  onOpenCart!();
                } else {
                  onDestinationSelected(idx);
                }
              },
              destinations: destinations.take(4).map((d) {
                final isCart = d.label == 'Create Bill';
                return NavigationDestination(
                  icon: (isCart && count > 0)
                      ? Badge(
                          label: Text('$count'),
                          backgroundColor: const Color(0xFFEF4444),
                          child: Icon(d.icon),
                        )
                      : Icon(d.icon),
                  selectedIcon: (isCart && count > 0)
                      ? Badge(
                          label: Text('$count'),
                          backgroundColor: const Color(0xFFEF4444),
                          child: Icon(d.selectedIcon),
                        )
                      : Icon(d.selectedIcon),
                  label: isCart && count > 0 ? 'Bill ($count)' : d.label,
                );
              }).toList(),
            );
          },
        ),
      );
    }
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out from BillWave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.instance.signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
