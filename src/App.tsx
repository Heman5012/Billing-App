import React, { useState, useEffect } from 'react';
import { firebaseService, LocalUser } from './services/firebase';
import { useCart } from './services/cartService';
import { Product, Invoice, BusinessProfile } from './types';
import { AppNavigation } from './components/AppNavigation';
import { BarcodeScannerModal } from './components/BarcodeScannerModal';
import { DashboardScreen } from './screens/DashboardScreen';
import { BillingScreen } from './screens/BillingScreen';
import { ProductsScreen } from './screens/ProductsScreen';
import { PaymentScreen } from './screens/PaymentScreen';
import { InvoiceScreen } from './screens/InvoiceScreen';
import { HistoryScreen } from './screens/HistoryScreen';
import { ReportsScreen } from './screens/ReportsScreen';
import { SettingsScreen } from './screens/SettingsScreen';
import { PublicInvoiceScreen } from './screens/PublicInvoiceScreen';
import { LoginScreen } from './screens/LoginScreen';

export const App: React.FC = () => {
  // Authentication & session
  const [currentUser, setCurrentUser] = useState<LocalUser | null>(firebaseService.getCurrentUser());
  const [authChecking, setAuthChecking] = useState(true);

  // Tab indices: 0: Dashboard, 1: Products, 2: Create Bill, 3: History, 4: Reports, 5: Settings
  const [activeTab, setActiveTab] = useState<number>(0);

  // Business Profile, Products, Invoices
  const [businessProfile, setBusinessProfile] = useState<BusinessProfile>(firebaseService.getLocalBusinessProfile());
  const [products, setProducts] = useState<Product[]>([]);
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  
  // Modals & Sub-flows
  const [isScannerOpen, setIsScannerOpen] = useState(false);
  const [isPaymentActive, setIsPaymentActive] = useState(false);
  const [activeInvoice, setActiveInvoice] = useState<Invoice | null>(null);

  // Check URL token for Public Invoice view (e.g. ?token=BILL-xxx or ?invoiceId=xxx)
  const [publicToken, setPublicToken] = useState<string | null>(null);

  // Cart Hook
  const cart = useCart();

  // Check URL params on initial load
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const token = params.get('token') || params.get('invoiceId');
    if (token) {
      setPublicToken(token);
    }
  }, []);

  // Listen to Auth State
  useEffect(() => {
    const unsub = firebaseService.onAuthStateChanged((user: LocalUser | null) => {
      setCurrentUser(user);
      setAuthChecking(false);
    });
    return unsub;
  }, []);

  // Subscribe to products, invoices, business profile
  useEffect(() => {
    if (!currentUser) return;

    const unsubProducts = firebaseService.streamProducts((prods) => {
      setProducts(prods);
    });

    const unsubInvoices = firebaseService.streamInvoices((invs) => {
      setInvoices(invs);
    });

    const unsubProfile = firebaseService.streamBusinessProfile((profile) => {
      setBusinessProfile(profile);
    });

    return () => {
      unsubProducts();
      unsubInvoices();
      unsubProfile();
    };
  }, [currentUser]);

  // Handle scanned barcode
  const handleBarcodeScanned = (code: string, matchedProduct?: Product | null) => {
    const cleanCode = code.trim();
    const product = matchedProduct || products.find(p => p.barcode === cleanCode || p.id === cleanCode);
    if (product) {
      cart.addProduct(product, 1);
      setIsScannerOpen(false);
      setActiveTab(2); // Navigate to Create Bill
    } else {
      alert(`Product with barcode "${cleanCode}" was not found in catalog.`);
    }
  };

  // Cancel invoice
  const handleCancelInvoice = async (invoiceId: string, reason: string): Promise<boolean> => {
    await firebaseService.cancelInvoice(invoiceId, reason);
    return true;
  };

  // Reset to seed products
  const handleResetSeedProducts = async () => {
    await firebaseService.resetToSeedProducts();
  };

  // Update business profile
  const handleUpdateBusiness = async (updated: BusinessProfile): Promise<boolean> => {
    await firebaseService.saveBusinessProfile(updated);
    setBusinessProfile(updated);
    return true;
  };

  // Sign out
  const handleSignOut = () => {
    firebaseService.signOutUser();
    setCurrentUser(null);
    cart.clear();
    setActiveInvoice(null);
    setIsPaymentActive(false);
    setActiveTab(0);
  };

  // If a public verification token is in the URL, render PublicInvoiceScreen
  if (publicToken) {
    return (
      <PublicInvoiceScreen
        tokenOrId={publicToken}
        onLookupInvoice={(token) => firebaseService.getPublicInvoice(token)}
        onClose={() => {
          window.history.pushState({}, document.title, window.location.pathname);
          setPublicToken(null);
        }}
      />
    );
  }

  // Auth Gate
  if (authChecking) {
    return (
      <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center text-white">
        <div className="w-12 h-12 border-4 border-emerald-500 border-t-transparent rounded-full animate-spin mb-4" />
        <p className="text-sm font-semibold text-emerald-200">Loading BillWave POS...</p>
      </div>
    );
  }

  if (!currentUser) {
    return <LoginScreen onLoginSuccess={setCurrentUser} />;
  }

  // Map of cart item quantities
  const cartQuantities: Record<string, number> = {};
  cart.items.forEach((item) => {
    if (item.productId) {
      cartQuantities[item.productId] = (cartQuantities[item.productId] || 0) + item.quantity;
    }
  });

  const cartItemCount = cart.items.reduce((s, i) => s + i.quantity, 0);
  const dashboardStats = firebaseService.getDashboardStats();

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col text-slate-900 selection:bg-emerald-500 selection:text-white">
      {/* Top Header & Navigation */}
      <AppNavigation
        activeTab={activeTab}
        onTabChange={(tabIndex) => {
          setIsPaymentActive(false);
          setActiveInvoice(null);
          setActiveTab(tabIndex);
        }}
        user={currentUser}
        business={businessProfile}
        cartItemCount={cartItemCount}
        cartGrandTotal={cart.total}
        onOpenCart={() => {
          setIsPaymentActive(false);
          setActiveInvoice(null);
          setActiveTab(2); // Go to billing
        }}
        onOpenScanner={() => setIsScannerOpen(true)}
        onSignOut={handleSignOut}
        onOpenVerify={() => {
          const token = prompt('Enter Invoice Number or Share Token to verify:');
          if (token && token.trim()) {
            setPublicToken(token.trim());
          }
        }}
      />

      {/* Main Content Area */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-6">
        {/* Sub-flow: Invoice Screen (Receipt details) */}
        {activeInvoice ? (
          <InvoiceScreen
            invoice={activeInvoice}
            business={businessProfile}
            onBackToHistory={() => {
              setActiveInvoice(null);
              setActiveTab(3); // History tab
            }}
            onStartNewBill={() => {
              setActiveInvoice(null);
              cart.clear();
              setActiveTab(2); // Billing tab
            }}
          />
        ) : isPaymentActive ? (
          /* Sub-flow: Payment Screen */
          <PaymentScreen
            items={cart.items}
            customer={cart.customer}
            overallDiscountPercent={cart.overallDiscountPercent}
            overallDiscountAmount={cart.overallDiscountAmount}
            taxableAmount={cart.taxableAmount}
            tax={cart.tax}
            taxBreakdown={cart.taxBreakdown}
            total={cart.total}
            notes={cart.notes}
            business={businessProfile}
            onPaymentSuccess={(newInvoice) => {
              cart.clear();
              setIsPaymentActive(false);
              setActiveInvoice(newInvoice);
            }}
            onCancel={() => setIsPaymentActive(false)}
          />
        ) : (
          /* Primary Screen Tabs */
          <>
            {activeTab === 0 && (
              <DashboardScreen
                stats={dashboardStats}
                business={businessProfile}
                onCreateBill={() => setActiveTab(2)}
                onAddProduct={() => setActiveTab(1)}
                onSelectInvoice={(inv) => setActiveInvoice(inv)}
                onOpenScanner={() => setIsScannerOpen(true)}
                userName={currentUser.displayName || 'Merchant'}
              />
            )}

            {activeTab === 1 && (
              <ProductsScreen
                products={products}
                cartQuantities={cartQuantities}
                onAddToCart={(prod) => cart.addProduct(prod, 1)}
                onOpenScanner={() => setIsScannerOpen(true)}
                onViewBill={() => setActiveTab(2)}
              />
            )}

            {activeTab === 2 && (
              <BillingScreen
                products={products}
                business={businessProfile}
                onProceedToPayment={() => setIsPaymentActive(true)}
                onOpenScanner={() => setIsScannerOpen(true)}
              />
            )}

            {activeTab === 3 && (
              <HistoryScreen
                invoices={invoices}
                business={businessProfile}
                onSelectInvoice={(inv) => setActiveInvoice(inv)}
                onCancelInvoice={handleCancelInvoice}
                onRefresh={() => {
                  setInvoices(firebaseService.getLocalInvoices());
                }}
              />
            )}

            {activeTab === 4 && (
              <ReportsScreen
                invoices={invoices}
                products={products}
                business={businessProfile}
              />
            )}

            {activeTab === 5 && (
              <SettingsScreen
                business={businessProfile}
                onUpdateBusiness={handleUpdateBusiness}
                onResetProducts={handleResetSeedProducts}
                onSignOut={handleSignOut}
                userEmail={currentUser?.email || undefined}
                isDemoUser={currentUser?.isDemo}
              />
            )}
          </>
        )}
      </main>

      {/* Barcode Scanner Modal */}
      <BarcodeScannerModal
        isOpen={isScannerOpen}
        onClose={() => setIsScannerOpen(false)}
        onDetected={handleBarcodeScanned}
      />
    </div>
  );
};
