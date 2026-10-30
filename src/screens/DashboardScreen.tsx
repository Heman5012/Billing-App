import React from 'react';
import {
  Banknote,
  Receipt,
  TrendingUp,
  Package,
  Plus,
  QrCode,
  CreditCard,
  CircleDollarSign,
  ChevronRight,
  Sparkles,
} from 'lucide-react';
import { DashboardStats, Invoice, BusinessProfile } from '../types';

interface DashboardScreenProps {
  stats: DashboardStats;
  business: BusinessProfile;
  onCreateBill: () => void;
  onAddProduct: () => void;
  onSelectInvoice: (invoice: Invoice) => void;
  onOpenScanner: () => void;
  userName?: string;
}

export const DashboardScreen: React.FC<DashboardScreenProps> = ({
  stats,
  business,
  onCreateBill,
  onAddProduct,
  onSelectInvoice,
  onOpenScanner,
  userName = 'Merchant',
}) => {
  const currency = business.currency || '₹';

  // 7-day max sales for chart normalization
  const maxDaySale = Math.max(1, ...Object.values(stats.last7DaysSales));

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 py-8 space-y-8 animate-in fade-in duration-200">
      {/* Welcome & Quick Action Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-6 rounded-2xl border border-slate-200/90 shadow-2xs">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-xl sm:text-2xl font-extrabold text-slate-900 tracking-tight">
              Welcome back, {userName}
            </h1>
            <span className="hidden sm:inline-flex items-center gap-1 text-[11px] font-bold text-emerald-700 bg-emerald-50 border border-emerald-200 px-2 py-0.5 rounded-full">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-ping" />
              Live POS
            </span>
          </div>
          <p className="text-xs sm:text-sm text-slate-500 mt-1">
            Real-time overview of your store billing, POS transactions, and inventory.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          <button
            type="button"
            onClick={onOpenScanner}
            className="px-3.5 py-2 text-xs font-bold text-blue-700 bg-blue-50 hover:bg-blue-100 border border-blue-200 rounded-xl flex items-center gap-1.5 transition-colors"
          >
            <QrCode className="w-4 h-4 text-blue-600" />
            Scan Barcode
          </button>
          <button
            type="button"
            onClick={onAddProduct}
            className="px-3.5 py-2 text-xs font-bold text-slate-700 hover:text-slate-900 bg-white hover:bg-slate-50 border border-slate-200 rounded-xl flex items-center gap-1.5 transition-colors shadow-2xs"
          >
            <Plus className="w-4 h-4 text-slate-500" />
            Add Product
          </button>
          <button
            type="button"
            onClick={onCreateBill}
            className="px-4 py-2 text-xs font-bold text-white bg-blue-600 hover:bg-blue-700 rounded-xl flex items-center gap-1.5 shadow-sm shadow-blue-500/20 transition-all"
          >
            <Receipt className="w-4 h-4" />
            Create Bill
          </button>
        </div>
      </div>

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: Today's Sales */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-2xs flex items-center justify-between">
          <div>
            <div className="text-xs font-semibold text-slate-500">Today's Sales</div>
            <div className="text-2xl font-black text-slate-900 mt-1">
              {currency}
              {stats.todaySales.toFixed(2)}
            </div>
            <div className="text-[11px] text-slate-400 mt-0.5 flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-blue-500" />
              Simulated Demo Sales
            </div>
          </div>
          <div className="w-12 h-12 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center shrink-0">
            <Banknote className="w-6 h-6" />
          </div>
        </div>

        {/* Card 2: Completed Bills */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-2xs flex items-center justify-between">
          <div>
            <div className="text-xs font-semibold text-slate-500">Completed Bills</div>
            <div className="text-2xl font-black text-slate-900 mt-1">{stats.totalInvoices}</div>
            <div className="text-[11px] text-slate-400 mt-0.5 flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
              Paid transactions
            </div>
          </div>
          <div className="w-12 h-12 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center shrink-0">
            <Receipt className="w-6 h-6" />
          </div>
        </div>

        {/* Card 3: Avg. Bill Value */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-2xs flex items-center justify-between">
          <div>
            <div className="text-xs font-semibold text-slate-500">Avg. Bill Value</div>
            <div className="text-2xl font-black text-slate-900 mt-1">
              {currency}
              {stats.avgInvoiceValue.toFixed(2)}
            </div>
            <div className="text-[11px] text-slate-400 mt-0.5 flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-purple-500" />
              Per customer bill
            </div>
          </div>
          <div className="w-12 h-12 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center shrink-0">
            <TrendingUp className="w-6 h-6" />
          </div>
        </div>

        {/* Card 4: Total Products */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/90 shadow-2xs flex items-center justify-between">
          <div>
            <div className="text-xs font-semibold text-slate-500">Total Products</div>
            <div className="text-2xl font-black text-slate-900 mt-1">{stats.totalProducts}</div>
            <div className="text-[11px] text-slate-400 mt-0.5 flex items-center gap-1">
              {stats.lowStockProducts.length > 0 ? (
                <span className="text-amber-600 font-semibold">{stats.lowStockProducts.length} low stock items</span>
              ) : (
                <span className="text-emerald-600 font-medium">Healthy inventory</span>
              )}
            </div>
          </div>
          <div
            className={`w-12 h-12 rounded-xl flex items-center justify-center shrink-0 ${
              stats.lowStockProducts.length > 0
                ? 'bg-amber-50 text-amber-600'
                : 'bg-teal-50 text-teal-600'
            }`}
          >
            <Package className="w-6 h-6" />
          </div>
        </div>
      </div>

      {/* 7-Day Sales Trend Bar Chart */}
      <div className="bg-white p-6 rounded-2xl border border-slate-200/90 shadow-2xs">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h3 className="text-base font-bold text-slate-900 flex items-center gap-2">
              <TrendingUp className="w-4 h-4 text-blue-600" />
              7-Day Sales Trend
            </h3>
            <p className="text-xs text-slate-500 mt-0.5">Daily billings across the last week</p>
          </div>
          <span className="px-2.5 py-1 text-[11px] font-bold bg-amber-50 text-amber-800 border border-amber-300 rounded-md">
            Demo Transactions
          </span>
        </div>

        <div className="flex items-end gap-3 sm:gap-6 h-40 pt-4 px-2 border-b border-slate-100">
          {Object.entries(stats.last7DaysSales).map(([dateLabel, amount]) => {
            const heightPercent = Math.max(8, (amount / maxDaySale) * 100);
            const hasSales = amount > 0;

            return (
              <div key={dateLabel} className="flex-1 flex flex-col items-center gap-2 h-full justify-end group">
                <div className="text-[10px] font-bold text-slate-500 opacity-0 group-hover:opacity-100 transition-opacity truncate">
                  {currency}
                  {amount.toFixed(0)}
                </div>
                <div className="w-full max-w-[42px] bg-slate-100 rounded-t-lg overflow-hidden flex flex-col justify-end h-full">
                  <div
                    style={{ height: `${heightPercent}%` }}
                    className={`w-full rounded-t-lg transition-all duration-500 ${
                      hasSales
                        ? 'bg-gradient-to-t from-blue-600 to-blue-400 group-hover:from-blue-700 group-hover:to-blue-500'
                        : 'bg-slate-200'
                    }`}
                  />
                </div>
                <span className="text-[10px] sm:text-xs font-semibold text-slate-500 mt-1 truncate">
                  {dateLabel}
                </span>
              </div>
            );
          })}
        </div>
      </div>

      {/* Split Section: Recent Transactions & Frequently Sold Products */}
      <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
        {/* Recent Invoices (3 cols) */}
        <div className="lg:col-span-3 bg-white p-6 rounded-2xl border border-slate-200/90 shadow-2xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-4">
              <div>
                <h3 className="text-base font-bold text-slate-900">Recent Transactions</h3>
                <p className="text-xs text-slate-500">Latest completed receipts</p>
              </div>
              <button
                type="button"
                onClick={onCreateBill}
                className="text-xs font-bold text-blue-600 hover:text-blue-700 flex items-center gap-1"
              >
                New Bill <ChevronRight className="w-3.5 h-3.5" />
              </button>
            </div>

            {stats.recentInvoices.length === 0 ? (
              <div className="py-12 text-center text-slate-400">
                <Receipt className="w-10 h-10 mx-auto mb-2 opacity-40" />
                <p className="text-xs font-medium">No invoices generated yet.</p>
                <button
                  type="button"
                  onClick={onCreateBill}
                  className="mt-3 text-xs font-bold text-blue-600 hover:underline"
                >
                  Create your first bill now
                </button>
              </div>
            ) : (
              <div className="divide-y divide-slate-100">
                {stats.recentInvoices.map((inv) => {
                  const isUpi = inv.paymentMethod.includes('UPI');
                  const isCard = inv.paymentMethod.includes('Card');
                  const formattedDate = new Date(inv.createdAt).toLocaleDateString('en-IN', {
                    day: '2-digit',
                    month: 'short',
                    hour: '2-digit',
                    minute: '2-digit',
                  });

                  return (
                    <div
                      key={inv.id}
                      onClick={() => onSelectInvoice(inv)}
                      className="py-3 flex items-center justify-between gap-3 hover:bg-slate-50/80 px-2 rounded-xl transition-colors cursor-pointer group"
                    >
                      <div className="flex items-center gap-3 min-w-0">
                        <div className="w-9 h-9 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center shrink-0">
                          {isUpi ? (
                            <QrCode className="w-4 h-4" />
                          ) : isCard ? (
                            <CreditCard className="w-4 h-4" />
                          ) : (
                            <CircleDollarSign className="w-4 h-4" />
                          )}
                        </div>
                        <div className="min-w-0">
                          <div className="text-xs font-bold text-slate-800 group-hover:text-blue-600 transition-colors truncate">
                            {inv.invoiceNumber}
                          </div>
                          <div className="text-[11px] text-slate-400 truncate">
                            {inv.items.length} items • {formattedDate}
                          </div>
                        </div>
                      </div>

                      <div className="text-right shrink-0">
                        <div className="text-sm font-black text-slate-900">
                          {currency}
                          {inv.total.toFixed(2)}
                        </div>
                        <span
                          className={`inline-block px-1.5 py-0.2 text-[9.5px] font-bold rounded capitalize ${
                            inv.paymentStatus === 'paid'
                              ? 'bg-emerald-50 text-emerald-700'
                              : 'bg-red-50 text-red-700'
                          }`}
                        >
                          {inv.paymentStatus}
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>

        {/* Top Selling Products (2 cols) */}
        <div className="lg:col-span-2 bg-white p-6 rounded-2xl border border-slate-200/90 shadow-2xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-4">
              <div>
                <h3 className="text-base font-bold text-slate-900">Frequently Sold Items</h3>
                <p className="text-xs text-slate-500">Popular items across store receipts</p>
              </div>
              <Sparkles className="w-4 h-4 text-amber-500" />
            </div>

            {stats.topSellingProducts.length === 0 ? (
              <div className="py-12 text-center text-slate-400">
                <Package className="w-10 h-10 mx-auto mb-2 opacity-40" />
                <p className="text-xs font-medium">Sales statistics will appear here.</p>
              </div>
            ) : (
              <div className="space-y-2.5">
                {stats.topSellingProducts.map((item, index) => (
                  <div
                    key={item.name}
                    className="p-3 bg-slate-50/80 rounded-xl border border-slate-100 flex items-center justify-between gap-3"
                  >
                    <div className="flex items-center gap-2.5 min-w-0">
                      <span className="w-6 h-6 rounded-lg bg-amber-100/80 text-amber-800 text-[11px] font-bold flex items-center justify-center shrink-0">
                        #{index + 1}
                      </span>
                      <span className="text-xs font-bold text-slate-800 truncate">{item.name}</span>
                    </div>
                    <span className="text-xs font-semibold text-slate-600 bg-white px-2 py-0.5 rounded-md border border-slate-200 shrink-0">
                      {item.quantity} sold
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
