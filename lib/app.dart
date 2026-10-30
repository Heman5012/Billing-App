import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models/invoice.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/firebase_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/products_screen.dart';
import 'screens/billing_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/invoice_screen.dart';
import 'screens/history_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/public_invoice_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'widgets/app_navigation.dart';

/// Reusable Slide Page Transitions Builder for Theme-wide Smooth Horizontal Sliding
class SlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final primaryOffset = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    final secondaryOffset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.25, 0.0),
    ).animate(CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    return SlideTransition(
      position: secondaryOffset,
      child: SlideTransition(
        position: primaryOffset,
        child: child,
      ),
    );
  }
}

/// Standalone SlidePageRoute for push/pushReplacement transitions
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget Function(BuildContext) builder;
  final bool slideFromRight;

  SlidePageRoute({
    required this.builder,
    this.slideFromRight = true,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final startOffset = slideFromRight
                ? const Offset(1.0, 0.0)
                : const Offset(-1.0, 0.0);
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final secondaryCurved = CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: slideFromRight
                    ? const Offset(-0.25, 0.0)
                    : const Offset(0.25, 0.0),
              ).animate(secondaryCurved),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: startOffset,
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}

String? extractTokenFromBrowserUrl() {
  try {
    final baseUri = Uri.base;
    // 1. Check query parameters: ?token=xyz
    if (baseUri.queryParameters.containsKey('token')) {
      final t = baseUri.queryParameters['token'];
      if (t != null && t.trim().isNotEmpty) return t.trim();
    }
    // 2. Check fragment: /#/invoice?token=xyz or /?token=xyz
    if (baseUri.fragment.isNotEmpty) {
      final frag = baseUri.fragment;
      if (frag.contains('?')) {
        final fragUri = Uri.tryParse(frag);
        if (fragUri != null && fragUri.queryParameters.containsKey('token')) {
          final t = fragUri.queryParameters['token'];
          if (t != null && t.trim().isNotEmpty) return t.trim();
        }
      }
      if (frag.contains('token=')) {
        final split = frag.split('token=');
        if (split.length > 1) {
          final t = split[1].split('&').first.split('#').first;
          if (t.trim().isNotEmpty) return t.trim();
        }
      }
    }
  } catch (_) {}
  return null;
}

class BillWaveApp extends StatelessWidget {
  const BillWaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BillWave — Smart Billing & Invoicing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          primary: const Color(0xFF1E88E5),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        // Global Slide Screen Page Transitions across all supported platforms
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: SlidePageTransitionsBuilder(),
            TargetPlatform.iOS: SlidePageTransitionsBuilder(),
            TargetPlatform.macOS: SlidePageTransitionsBuilder(),
            TargetPlatform.windows: SlidePageTransitionsBuilder(),
            TargetPlatform.linux: SlidePageTransitionsBuilder(),
            TargetPlatform.fuchsia: SlidePageTransitionsBuilder(),
          },
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 1.5),
          ),
        ),
      ),
      onGenerateRoute: (settings) {
        // Handle web deep links like /#invoice?token=xyz or /?token=xyz
        final uri = Uri.tryParse(settings.name ?? '');
        final browserToken = extractTokenFromBrowserUrl();

        if (uri != null &&
            (uri.path == '/invoice' ||
                uri.path == 'invoice' ||
                uri.fragment.startsWith('/invoice') ||
                uri.fragment.contains('token=') ||
                uri.queryParameters.containsKey('token') ||
                browserToken != null)) {
          String token = '';
          if (uri.queryParameters.containsKey('token')) {
            token = uri.queryParameters['token']!;
          } else if (uri.fragment.contains('token=')) {
            token = uri.fragment.split('token=').last.split('&').first;
          } else if (browserToken != null) {
            token = browserToken;
          }
          return SlidePageRoute(
            builder: (_) => PublicInvoiceScreen(initialToken: token),
          );
        }
        return null;
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // If opened via QR code or direct share link, display public invoice directly
    final directToken = extractTokenFromBrowserUrl();
    if (directToken != null && directToken.isNotEmpty) {
      return PublicInvoiceScreen(initialToken: directToken);
    }

    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: user == null ? const LoginScreen() : const MainShell(),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _navIndex = 0; // 0: Dashboard, 1: Products, 2: Billing, 3: History, 4: Reports, 5: Settings
  late final PageController _pageController;
  final GlobalKey<BillingScreenState> _billingScreenKey =
      GlobalKey<BillingScreenState>();
  int _billingInitialTab = 0;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _navIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToIndex(int index) {
    if (index == _navIndex) return;
    setState(() {
      _navIndex = index;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _navIndex = index;
    });
  }

  void _showInvoice(Invoice invoice) {
    Navigator.of(context).push(
      SlidePageRoute(
        builder: (_) => InvoiceScreen(
          invoice: invoice,
          onStartNewBill: () {
            Navigator.of(context).pop();
            _startNewBill();
          },
          onBackToHistory: () {
            Navigator.of(context).pop();
            _navigateToIndex(3);
          },
        ),
      ),
    );
  }

  void _startNewBill() {
    CartService.instance.clear();
    setState(() {
      _billingInitialTab = 0; // Fresh bill starts at catalogue to pick items
    });
    _billingScreenKey.currentState?.switchToTab(0);
    _navigateToIndex(2); // Create Bill tab
  }

  /// Single tap navigation that opens the active Current Bill screen immediately
  void _openCurrentBill() {
    if (_isNavigating) return;
    _isNavigating = true;

    setState(() {
      _billingInitialTab = 1; // Tab 1: Current Bill
    });
    _billingScreenKey.currentState?.switchToTab(1);
    _navigateToIndex(2); // Navigate directly to billing screen

    Future.delayed(const Duration(milliseconds: 350), () {
      _isNavigating = false;
    });
  }

  void _openQrScanner() {
    Navigator.of(context).push(
      SlidePageRoute(builder: (_) => const QrScannerScreen()),
    );
  }

  Future<void> _openPaymentFromCurrentCart() async {
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

    final uid = AuthService.instance.currentUser?.uid;
    BusinessProfile business = BusinessProfile();
    if (uid != null) {
      business = await FirebaseService.instance.getBusinessProfile(uid);
    }

    _proceedToPayment(
      items: List.from(cart.items),
      customer: cart.customer,
      overallDiscountPercent: cart.overallDiscountPercent,
      notes: cart.notes,
      business: business,
    );
  }

  void _proceedToPayment({
    required List<InvoiceItem> items,
    required CustomerDetails customer,
    required double overallDiscountPercent,
    required String notes,
    required BusinessProfile business,
  }) {
    Navigator.of(context).push(
      SlidePageRoute(
        builder: (_) => PaymentScreen(
          items: items,
          customer: customer,
          overallDiscountPercent: overallDiscountPercent,
          notes: notes,
          business: business,
          onCancel: () => Navigator.of(context).pop(),
          onPaymentSuccess: (invoice) {
            // Requirement 5: Clear the active bill only once payment is confirmed successful
            CartService.instance.clear();
            Navigator.of(context).pushReplacement(
              SlidePageRoute(
                builder: (_) => InvoiceScreen(
                  invoice: invoice,
                  onStartNewBill: () {
                    Navigator.of(context).pop();
                    _startNewBill();
                  },
                  onBackToHistory: () {
                    Navigator.of(context).pop();
                    _navigateToIndex(3);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      DashboardScreen(
        onCreateBillPressed: _startNewBill,
        onAddProductPressed: () => _navigateToIndex(1),
        onInvoiceSelected: _showInvoice,
        onScanQrPressed: _openQrScanner,
      ),
      ProductsScreen(
        onViewBill: _openCurrentBill,
        onMakePayment: _openPaymentFromCurrentCart,
      ),
      BillingScreen(
        key: _billingScreenKey,
        initialTabIndex: _billingInitialTab,
        onProceedToPayment: (items, customer, discount, notes, business) {
          _proceedToPayment(
            items: items,
            customer: customer,
            overallDiscountPercent: discount,
            notes: notes,
            business: business,
          );
        },
      ),
      HistoryScreen(onSelectInvoice: _showInvoice),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    return AppNavigationShell(
      selectedIndex: _navIndex,
      onDestinationSelected: _navigateToIndex,
      onOpenCart: _openCurrentBill,
      onScanQrPressed: _openQrScanner,
      child: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: screens,
      ),
    );
  }
}
