import React, { useState } from 'react';
import { 
  Search, 
  Filter, 
  Eye, 
  Ban, 
  CreditCard, 
  Banknote, 
  QrCode, 
  CheckCircle2, 
  XCircle, 
  RefreshCw,
  AlertTriangle
} from 'lucide-react';
import { Invoice, BusinessProfile } from '../types';
import { formatCurrency, formatDate } from '../services/cartService';

interface HistoryScreenProps {
  invoices: Invoice[];
  business: BusinessProfile;
  onSelectInvoice: (invoice: Invoice) => void;
  onCancelInvoice: (invoiceId: string, reason: string) => Promise<boolean>;
  onRefresh: () => void;
}

export const HistoryScreen: React.FC<HistoryScreenProps> = ({
  invoices,
  business,
  onSelectInvoice,
  onCancelInvoice,
  onRefresh,
}) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'paid' | 'cancelled'>('all');
  const [paymentFilter, setPaymentFilter] = useState<'all' | 'cash' | 'card' | 'upi'>('all');
  const [dateFilter, setDateFilter] = useState<'all' | 'today' | 'week' | 'month'>('all');
  
  // Cancel dialog state
  const [cancellingInvoice, setCancellingInvoice] = useState<Invoice | null>(null);
  const [cancelReason, setCancelReason] = useState('');
  const [isSubmittingCancel, setIsSubmittingCancel] = useState(false);

  const currency = business.currency || '₹';

  const isPaidInvoice = (inv: Invoice) => {
    return (inv.paymentStatus === 'paid' || inv.status === 'paid') && inv.paymentStatus !== 'cancelled' && inv.status !== 'cancelled';
  };

  const getInvoiceAmount = (inv: Invoice) => {
    return inv.total ?? inv.totalAmount ?? 0;
  };

  const filteredInvoices = invoices.filter(inv => {
    // Search filter
    const matchesSearch = 
      inv.invoiceNumber.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (inv.customer?.name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (inv.customer?.phone || '').includes(searchTerm);
    
    // Status filter
    const isPaid = isPaidInvoice(inv);
    let matchesStatus = true;
    if (statusFilter === 'paid') matchesStatus = isPaid;
    if (statusFilter === 'cancelled') matchesStatus = !isPaid;

    // Payment method filter
    const payMethod = (inv.paymentMethod || '').toLowerCase();
    const matchesPayment = paymentFilter === 'all' || payMethod.includes(paymentFilter);

    // Date filter
    let matchesDate = true;
    if (dateFilter !== 'all') {
      const invDate = new Date(inv.createdAt);
      const now = new Date();
      if (dateFilter === 'today') {
        matchesDate = invDate.toDateString() === now.toDateString();
      } else if (dateFilter === 'week') {
        const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        matchesDate = invDate >= weekAgo;
      } else if (dateFilter === 'month') {
        const monthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
        matchesDate = invDate >= monthAgo;
      }
    }

    return matchesSearch && matchesStatus && matchesPayment && matchesDate;
  }).sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

  const handleConfirmCancel = async () => {
    if (!cancellingInvoice) return;
    setIsSubmittingCancel(true);
    try {
      await onCancelInvoice(cancellingInvoice.id, cancelReason || 'Cancelled by merchant');
      setCancellingInvoice(null);
      setCancelReason('');
    } finally {
      setIsSubmittingCancel(false);
    }
  };

  const getPaymentBadge = (method: string) => {
    const lower = (method || '').toLowerCase();
    if (lower.includes('upi')) {
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-50 text-purple-700 border border-purple-200">
          <QrCode className="w-3 h-3" /> UPI
        </span>
      );
    }
    if (lower.includes('card')) {
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-50 text-blue-700 border border-blue-200">
          <CreditCard className="w-3 h-3" /> Card
        </span>
      );
    }
    return (
      <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium bg-emerald-50 text-emerald-700 border border-emerald-200">
        <Banknote className="w-3 h-3" /> Cash
      </span>
    );
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Invoice History</h1>
          <p className="text-sm text-gray-500">View, audit, search, and manage all store transactions</p>
        </div>
        <button
          onClick={onRefresh}
          className="inline-flex items-center gap-2 px-3.5 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-xl hover:bg-gray-50 shadow-xs transition cursor-pointer"
        >
          <RefreshCw className="w-4 h-4 text-gray-500" />
          Refresh
        </button>
      </div>

      {/* Filter and Search Bar */}
      <div className="bg-white p-4 rounded-2xl border border-gray-200 shadow-xs space-y-3">
        <div className="flex flex-col md:flex-row gap-3">
          <div className="relative flex-1">
            <Search className="w-5 h-5 text-gray-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Search by invoice #, customer name or phone..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none"
            />
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value as any)}
              className="px-3 py-2 text-sm border border-gray-300 rounded-xl bg-white text-gray-700 focus:ring-2 focus:ring-emerald-500 outline-none cursor-pointer"
            >
              <option value="all">All Statuses</option>
              <option value="paid">Paid</option>
              <option value="cancelled">Cancelled</option>
            </select>

            <select
              value={paymentFilter}
              onChange={(e) => setPaymentFilter(e.target.value as any)}
              className="px-3 py-2 text-sm border border-gray-300 rounded-xl bg-white text-gray-700 focus:ring-2 focus:ring-emerald-500 outline-none cursor-pointer"
            >
              <option value="all">All Payments</option>
              <option value="cash">Cash</option>
              <option value="card">Card</option>
              <option value="upi">UPI</option>
            </select>

            <select
              value={dateFilter}
              onChange={(e) => setDateFilter(e.target.value as any)}
              className="px-3 py-2 text-sm border border-gray-300 rounded-xl bg-white text-gray-700 focus:ring-2 focus:ring-emerald-500 outline-none cursor-pointer"
            >
              <option value="all">All Time</option>
              <option value="today">Today</option>
              <option value="week">Past 7 Days</option>
              <option value="month">Past 30 Days</option>
            </select>
          </div>
        </div>

        <div className="text-xs text-gray-500 flex items-center justify-between pt-1 border-t border-gray-100">
          <span>Found <strong>{filteredInvoices.length}</strong> matching invoices</span>
          <span>
            Total value: <strong>{formatCurrency(filteredInvoices.filter(isPaidInvoice).reduce((s, i) => s + getInvoiceAmount(i), 0), currency)}</strong>
          </span>
        </div>
      </div>

      {/* Invoices List / Table */}
      {filteredInvoices.length === 0 ? (
        <div className="bg-white rounded-2xl border border-gray-200 p-12 text-center shadow-xs">
          <div className="w-16 h-16 bg-gray-100 text-gray-400 rounded-full flex items-center justify-center mx-auto mb-3">
            <Filter className="w-8 h-8" />
          </div>
          <h3 className="text-lg font-bold text-gray-800">No invoices found</h3>
          <p className="text-sm text-gray-500 mt-1 max-w-sm mx-auto">
            Try adjusting your search query or filters. Newly billed invoices will appear here immediately.
          </p>
        </div>
      ) : (
        <div className="bg-white rounded-2xl border border-gray-200 shadow-xs overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="bg-gray-50/80 text-gray-600 font-semibold border-b border-gray-200 text-xs uppercase tracking-wider">
                <tr>
                  <th className="py-3.5 px-4">Invoice #</th>
                  <th className="py-3.5 px-4">Date & Time</th>
                  <th className="py-3.5 px-4">Customer</th>
                  <th className="py-3.5 px-4">Items</th>
                  <th className="py-3.5 px-4">Payment</th>
                  <th className="py-3.5 px-4">Status</th>
                  <th className="py-3.5 px-4 text-right">Amount</th>
                  <th className="py-3.5 px-4 text-center">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filteredInvoices.map((inv) => {
                  const isPaid = isPaidInvoice(inv);
                  const amount = getInvoiceAmount(inv);
                  const dateStr = formatDate(inv.createdAt);
                  return (
                    <tr 
                      key={inv.id} 
                      className={`hover:bg-gray-50/80 transition-colors ${!isPaid ? 'bg-red-50/30' : ''}`}
                    >
                      <td className="py-3 px-4 font-mono font-medium text-emerald-700">
                        {inv.invoiceNumber}
                      </td>
                      <td className="py-3 px-4 text-xs text-gray-600">
                        {dateStr}
                      </td>
                      <td className="py-3 px-4">
                        <div className="font-medium text-gray-900">{inv.customer?.name || 'Walk-in'}</div>
                        <div className="text-xs text-gray-500">{inv.customer?.phone || '—'}</div>
                      </td>
                      <td className="py-3 px-4 text-xs text-gray-600">
                        {inv.items.length} {inv.items.length === 1 ? 'item' : 'items'}
                      </td>
                      <td className="py-3 px-4">
                        {getPaymentBadge(inv.paymentMethod)}
                      </td>
                      <td className="py-3 px-4">
                        {isPaid ? (
                          <span className="inline-flex items-center gap-1 text-xs font-semibold text-emerald-700 bg-emerald-50 px-2.5 py-0.5 rounded-full border border-emerald-200">
                            <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
                            Paid
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 text-xs font-semibold text-red-700 bg-red-50 px-2.5 py-0.5 rounded-full border border-red-200" title={inv.cancellationReason || inv.cancelReason}>
                            <XCircle className="w-3.5 h-3.5 text-red-600" />
                            Cancelled
                          </span>
                        )}
                      </td>
                      <td className="py-3 px-4 text-right font-bold text-gray-900">
                        <span className={!isPaid ? 'line-through text-gray-400' : ''}>
                          {formatCurrency(amount, currency)}
                        </span>
                      </td>
                      <td className="py-3 px-4">
                        <div className="flex items-center justify-center gap-1">
                          <button
                            onClick={() => onSelectInvoice(inv)}
                            title="View / Print Receipt"
                            className="p-1.5 text-gray-600 hover:text-emerald-700 hover:bg-emerald-50 rounded-lg transition cursor-pointer"
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                          
                          {isPaid && (
                            <button
                              onClick={() => {
                                setCancellingInvoice(inv);
                                setCancelReason('');
                              }}
                              title="Cancel Invoice"
                              className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition cursor-pointer"
                            >
                              <Ban className="w-4 h-4" />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Cancel Confirmation Modal */}
      {cancellingInvoice && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-gray-100">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 rounded-2xl bg-red-100 text-red-600 flex items-center justify-center shrink-0">
                <AlertTriangle className="w-6 h-6" />
              </div>
              <div className="space-y-1">
                <h3 className="text-lg font-bold text-gray-900">Cancel Invoice</h3>
                <p className="text-xs text-gray-500">
                  Are you sure you want to cancel invoice <strong className="font-mono text-gray-700">{cancellingInvoice.invoiceNumber}</strong>?
                </p>
              </div>
            </div>

            <div className="mt-4 p-3 bg-red-50 rounded-xl text-xs text-red-800 border border-red-100">
              This invoice amount ({formatCurrency(getInvoiceAmount(cancellingInvoice), currency)}) will be voided in reports, and item stock quantities will be restored.
            </div>

            <div className="mt-4 space-y-1.5">
              <label className="text-xs font-semibold text-gray-700">Reason for Cancellation</label>
              <textarea
                value={cancelReason}
                onChange={(e) => setCancelReason(e.target.value)}
                placeholder="e.g. Customer returned goods, entry mistake, duplicate bill..."
                rows={2}
                className="w-full text-xs p-2.5 border border-gray-300 rounded-xl focus:ring-2 focus:ring-red-500 focus:border-red-500 outline-none"
              />
            </div>

            <div className="mt-6 flex items-center justify-end gap-2.5">
              <button
                type="button"
                onClick={() => setCancellingInvoice(null)}
                disabled={isSubmittingCancel}
                className="px-4 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-100 rounded-xl transition cursor-pointer"
              >
                Keep Active
              </button>
              <button
                type="button"
                onClick={handleConfirmCancel}
                disabled={isSubmittingCancel}
                className="px-4 py-2 text-sm font-semibold text-white bg-red-600 hover:bg-red-700 rounded-xl shadow-md transition disabled:opacity-50 cursor-pointer"
              >
                {isSubmittingCancel ? 'Cancelling...' : 'Confirm Cancellation'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
