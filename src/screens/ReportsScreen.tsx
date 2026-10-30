import React, { useState } from 'react';
import { 
  BarChart3, 
  TrendingUp, 
  CreditCard, 
  Banknote, 
  QrCode, 
  AlertTriangle, 
  Package, 
  Layers,
  ShieldAlert
} from 'lucide-react';
import { Invoice, Product, BusinessProfile } from '../types';
import { formatCurrency } from '../services/cartService';

interface ReportsScreenProps {
  invoices: Invoice[];
  products: Product[];
  business: BusinessProfile;
  onSelectProduct?: (product: Product) => void;
}

export const ReportsScreen: React.FC<ReportsScreenProps> = ({ invoices, products, business }) => {
  const [timeRange, setTimeRange] = useState<'today' | '7days' | '30days' | 'all'>('7days');
  const currency = business.currency || '₹';

  const isPaidInvoice = (inv: Invoice) => {
    return (inv.paymentStatus === 'paid' || inv.status === 'paid') && inv.paymentStatus !== 'cancelled' && inv.status !== 'cancelled';
  };

  const getInvoiceAmount = (inv: Invoice) => {
    return inv.total ?? inv.totalAmount ?? 0;
  };

  const getInvoiceTax = (inv: Invoice) => {
    return inv.tax ?? inv.taxAmount ?? 0;
  };

  // Filter paid invoices by time range
  const validInvoices = invoices.filter(isPaidInvoice);

  const filteredInvoices = validInvoices.filter(inv => {
    if (timeRange === 'all') return true;
    const invDate = new Date(inv.createdAt);
    const now = new Date();
    if (timeRange === 'today') {
      return invDate.toDateString() === now.toDateString();
    } else if (timeRange === '7days') {
      const past = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      return invDate >= past;
    } else if (timeRange === '30days') {
      const past = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      return invDate >= past;
    }
    return true;
  });

  // Calculate metrics
  const totalRevenue = filteredInvoices.reduce((sum, i) => sum + getInvoiceAmount(i), 0);
  const totalInvoicesCount = filteredInvoices.length;
  const avgOrderValue = totalInvoicesCount > 0 ? totalRevenue / totalInvoicesCount : 0;
  const totalTaxCollected = filteredInvoices.reduce((sum, i) => sum + getInvoiceTax(i), 0);

  // Payment Breakdown
  const paymentMethodStats = filteredInvoices.reduce((acc, inv) => {
    const method = (inv.paymentMethod || 'cash').toLowerCase();
    const key = method.includes('upi') ? 'upi' : method.includes('card') ? 'card' : 'cash';
    acc[key] = (acc[key] || 0) + getInvoiceAmount(inv);
    return acc;
  }, {} as Record<string, number>);

  const cashShare = paymentMethodStats['cash'] || 0;
  const cardShare = paymentMethodStats['card'] || 0;
  const upiShare = paymentMethodStats['upi'] || 0;

  // Best Selling Products
  const productSalesMap: Record<string, { name: string; quantity: number; revenue: number }> = {};
  filteredInvoices.forEach(inv => {
    inv.items.forEach(item => {
      const key = item.productId || item.name;
      if (!productSalesMap[key]) {
        productSalesMap[key] = { name: item.name || item.productName || 'Item', quantity: 0, revenue: 0 };
      }
      productSalesMap[key].quantity += item.quantity;
      const lineVal = item.lineTotal ?? item.totalPrice ?? (item.unitPrice * item.quantity);
      productSalesMap[key].revenue += lineVal;
    });
  });

  const topSelling = Object.values(productSalesMap)
    .sort((a, b) => b.quantity - a.quantity)
    .slice(0, 5);

  // Low stock inventory (stock <= 10)
  const lowStockProducts = products.filter(p => (p.stock ?? p.stockQuantity ?? 0) <= 10);

  // GST Breakdown
  const taxSlabBreakdown: Record<number, { taxable: number; tax: number }> = {};
  filteredInvoices.forEach(inv => {
    inv.items.forEach(item => {
      const rate = item.taxRate || 0;
      if (!taxSlabBreakdown[rate]) {
        taxSlabBreakdown[rate] = { taxable: 0, tax: 0 };
      }
      const itemSubtotal = item.lineTaxable ?? (item.unitPrice * item.quantity - (item.discount || 0));
      const itemTax = item.lineTax ?? ((itemSubtotal * rate) / 100);
      taxSlabBreakdown[rate].taxable += itemSubtotal;
      taxSlabBreakdown[rate].tax += itemTax;
    });
  });

  return (
    <div className="space-y-6">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Financial & Sales Analytics</h1>
          <p className="text-sm text-gray-500">Comprehensive overview of store sales, GST tax liability, and inventory levels</p>
        </div>

        {/* Time Filter Pills */}
        <div className="inline-flex p-1 bg-gray-100 rounded-xl border border-gray-200">
          {(['today', '7days', '30days', 'all'] as const).map((range) => {
            const labels = {
              today: 'Today',
              '7days': 'Last 7 Days',
              '30days': 'Last 30 Days',
              all: 'All Time'
            };
            return (
              <button
                key={range}
                onClick={() => setTimeRange(range)}
                className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition cursor-pointer ${
                  timeRange === range
                    ? 'bg-white text-emerald-700 shadow-xs'
                    : 'text-gray-600 hover:text-gray-900'
                }`}
              >
                {labels[range]}
              </button>
            );
          })}
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-5 rounded-2xl border border-gray-200 shadow-xs flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider">Gross Revenue</p>
            <h3 className="text-2xl font-black text-gray-900 mt-1">{formatCurrency(totalRevenue, currency)}</h3>
            <p className="text-xs text-emerald-600 font-medium mt-1 flex items-center gap-1">
              <TrendingUp className="w-3.5 h-3.5" /> {filteredInvoices.length} paid invoices
            </p>
          </div>
          <div className="w-12 h-12 bg-emerald-50 text-emerald-600 rounded-2xl flex items-center justify-center">
            <BarChart3 className="w-6 h-6" />
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-gray-200 shadow-xs flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider">Avg Order Value</p>
            <h3 className="text-2xl font-black text-gray-900 mt-1">{formatCurrency(avgOrderValue, currency)}</h3>
            <p className="text-xs text-gray-500 font-medium mt-1">Per transaction ticket</p>
          </div>
          <div className="w-12 h-12 bg-blue-50 text-blue-600 rounded-2xl flex items-center justify-center">
            <TrendingUp className="w-6 h-6" />
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-gray-200 shadow-xs flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider">GST Tax Collected</p>
            <h3 className="text-2xl font-black text-gray-900 mt-1">{formatCurrency(totalTaxCollected, currency)}</h3>
            <p className="text-xs text-gray-500 font-medium mt-1">Net tax obligation</p>
          </div>
          <div className="w-12 h-12 bg-amber-50 text-amber-600 rounded-2xl flex items-center justify-center">
            <Layers className="w-6 h-6" />
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-gray-200 shadow-xs flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider">Stock Alerts</p>
            <h3 className="text-2xl font-black text-gray-900 mt-1">{lowStockProducts.length}</h3>
            <p className={`text-xs font-medium mt-1 ${lowStockProducts.length > 0 ? 'text-red-600' : 'text-emerald-600'}`}>
              {lowStockProducts.length > 0 ? 'Items below threshold' : 'Optimal inventory'}
            </p>
          </div>
          <div className={`w-12 h-12 rounded-2xl flex items-center justify-center ${lowStockProducts.length > 0 ? 'bg-red-50 text-red-600' : 'bg-emerald-50 text-emerald-600'}`}>
            <AlertTriangle className="w-6 h-6" />
          </div>
        </div>
      </div>

      {/* Row 2: Payment Distribution & Top Sellers */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Payment Methods */}
        <div className="bg-white p-5 rounded-2xl border border-gray-200 shadow-xs space-y-4">
          <h2 className="text-base font-bold text-gray-900 flex items-center gap-2">
            <CreditCard className="w-5 h-5 text-emerald-600" />
            Payment Channel Breakdown
          </h2>

          <div className="space-y-4 pt-2">
            {/* Cash */}
            <div>
              <div className="flex items-center justify-between text-xs font-semibold text-gray-700 mb-1">
                <span className="flex items-center gap-1.5"><Banknote className="w-4 h-4 text-emerald-600" /> Cash</span>
                <span>{formatCurrency(cashShare, currency)} ({totalRevenue > 0 ? Math.round((cashShare / totalRevenue) * 100) : 0}%)</span>
              </div>
              <div className="w-full h-2.5 bg-gray-100 rounded-full overflow-hidden">
                <div 
                  className="h-full bg-emerald-500 rounded-full" 
                  style={{ width: `${totalRevenue > 0 ? (cashShare / totalRevenue) * 100 : 0}%` }}
                />
              </div>
            </div>

            {/* UPI */}
            <div>
              <div className="flex items-center justify-between text-xs font-semibold text-gray-700 mb-1">
                <span className="flex items-center gap-1.5"><QrCode className="w-4 h-4 text-purple-600" /> UPI (GPay, PhonePe, Paytm)</span>
                <span>{formatCurrency(upiShare, currency)} ({totalRevenue > 0 ? Math.round((upiShare / totalRevenue) * 100) : 0}%)</span>
              </div>
              <div className="w-full h-2.5 bg-gray-100 rounded-full overflow-hidden">
                <div 
                  className="h-full bg-purple-500 rounded-full" 
                  style={{ width: `${totalRevenue > 0 ? (upiShare / totalRevenue) * 100 : 0}%` }}
                />
              </div>
            </div>

            {/* Card */}
            <div>
              <div className="flex items-center justify-between text-xs font-semibold text-gray-700 mb-1">
                <span className="flex items-center gap-1.5"><CreditCard className="w-4 h-4 text-blue-600" /> Debit / Credit Card</span>
                <span>{formatCurrency(cardShare, currency)} ({totalRevenue > 0 ? Math.round((cardShare / totalRevenue) * 100) : 0}%)</span>
              </div>
              <div className="w-full h-2.5 bg-gray-100 rounded-full overflow-hidden">
                <div 
                  className="h-full bg-blue-500 rounded-full" 
                  style={{ width: `${totalRevenue > 0 ? (cardShare / totalRevenue) * 100 : 0}%` }}
                />
              </div>
            </div>
          </div>
        </div>

        {/* Top Selling Products */}
        <div className="bg-white p-5 rounded-2xl border border-gray-200 shadow-xs space-y-4">
          <h2 className="text-base font-bold text-gray-900 flex items-center gap-2">
            <Package className="w-5 h-5 text-emerald-600" />
            Top Selling FMCG Items
          </h2>

          {topSelling.length === 0 ? (
            <p className="text-xs text-gray-500 py-6 text-center">No sales recorded for this period</p>
          ) : (
            <div className="space-y-3 pt-1">
              {topSelling.map((item, idx) => (
                <div key={idx} className="flex items-center justify-between p-2.5 rounded-xl bg-gray-50 border border-gray-100">
                  <div className="flex items-center gap-3">
                    <span className="w-6 h-6 rounded-full bg-emerald-100 text-emerald-800 font-black text-xs flex items-center justify-center">
                      {idx + 1}
                    </span>
                    <div>
                      <p className="text-xs font-bold text-gray-900">{item.name}</p>
                      <p className="text-[11px] text-gray-500">{item.quantity} units sold</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-xs font-bold text-emerald-700">{formatCurrency(item.revenue, currency)}</p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Row 3: GST Tax Slab Liability & Low Stock Alerts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* GST Slab Table */}
        <div className="bg-white p-5 rounded-2xl border border-gray-200 shadow-xs space-y-3">
          <h2 className="text-base font-bold text-gray-900 flex items-center gap-2">
            <Layers className="w-5 h-5 text-amber-600" />
            GST Tax Slab Analysis
          </h2>
          <div className="overflow-x-auto">
            <table className="w-full text-xs text-left">
              <thead className="bg-gray-50 text-gray-600 uppercase border-b border-gray-100">
                <tr>
                  <th className="py-2.5 px-3">Tax Slab</th>
                  <th className="py-2.5 px-3">Taxable Value</th>
                  <th className="py-2.5 px-3 text-right">Tax Generated</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {[0, 5, 12, 18, 28].map(slab => {
                  const data = taxSlabBreakdown[slab] || { taxable: 0, tax: 0 };
                  return (
                    <tr key={slab} className="hover:bg-gray-50/50">
                      <td className="py-2 px-3 font-semibold text-gray-800">{slab}% GST</td>
                      <td className="py-2 px-3 text-gray-600">{formatCurrency(data.taxable, currency)}</td>
                      <td className="py-2 px-3 text-right font-bold text-gray-900">{formatCurrency(data.tax, currency)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>

        {/* Low Stock Alerts */}
        <div className="bg-white p-5 rounded-2xl border border-gray-200 shadow-xs space-y-3">
          <h2 className="text-base font-bold text-gray-900 flex items-center gap-2">
            <ShieldAlert className="w-5 h-5 text-red-600" />
            Low Stock Inventory Alerts (≤ 10 units)
          </h2>

          {lowStockProducts.length === 0 ? (
            <div className="py-6 text-center text-xs text-emerald-700 bg-emerald-50 rounded-xl">
              All inventory levels are healthy! No items currently low.
            </div>
          ) : (
            <div className="space-y-2 max-h-56 overflow-y-auto pr-1">
              {lowStockProducts.map(p => (
                <div key={p.id} className="flex items-center justify-between p-2.5 rounded-xl bg-red-50/50 border border-red-100 text-xs">
                  <div>
                    <p className="font-bold text-gray-900">{p.name}</p>
                    <p className="text-[11px] text-gray-500 font-mono">Barcode: {p.barcode}</p>
                  </div>
                  <div className="text-right">
                    <span className="inline-block px-2 py-0.5 rounded-full font-bold bg-red-100 text-red-700 text-xs">
                      {p.stock ?? p.stockQuantity ?? 0} {p.unit || 'units'} remaining
                    </span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
