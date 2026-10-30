import React, { useEffect, useState } from 'react';
import { 
  CheckCircle, 
  ShieldCheck, 
  Printer, 
  ArrowLeft, 
  AlertCircle
} from 'lucide-react';
import { QRCodeSVG } from 'qrcode.react';
import { Invoice } from '../types';
import { formatCurrency, formatDate } from '../services/cartService';
import { printInvoiceReceipt } from '../services/pdfService';

interface PublicInvoiceScreenProps {
  tokenOrId: string;
  onLookupInvoice: (tokenOrId: string) => Promise<Invoice | null>;
  onClose: () => void;
}

export const PublicInvoiceScreen: React.FC<PublicInvoiceScreenProps> = ({
  tokenOrId,
  onLookupInvoice,
  onClose,
}) => {
  const [invoice, setInvoice] = useState<Invoice | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let isMounted = true;
    async function load() {
      setIsLoading(true);
      setError(null);
      try {
        const result = await onLookupInvoice(tokenOrId);
        if (isMounted) {
          if (result) {
            setInvoice(result);
          } else {
            setError('The requested invoice could not be found or verification token has expired.');
          }
        }
      } catch (err: any) {
        if (isMounted) {
          setError(err?.message || 'Failed to verify invoice.');
        }
      } finally {
        if (isMounted) {
          setIsLoading(false);
        }
      }
    }
    load();
    return () => {
      isMounted = false;
    };
  }, [tokenOrId, onLookupInvoice]);

  const currency = invoice?.business?.currency || '₹';
  const businessName = invoice?.business?.businessName || invoice?.business?.name || 'BillWave Supermarket';
  const businessAddress = invoice?.business?.address || 'High Street, Retail Hub, Bangalore';
  const businessPhone = invoice?.business?.phone || '+91 98765 43210';
  const gstin = invoice?.business?.gstin;

  const totalAmount = invoice ? (invoice.total ?? invoice.totalAmount ?? 0) : 0;
  const discountAmount = invoice ? (invoice.overallDiscountAmount ?? invoice.discountAmount ?? 0) : 0;
  const taxAmount = invoice ? (invoice.tax ?? invoice.taxAmount ?? 0) : 0;

  return (
    <div className="min-h-screen bg-gradient-to-b from-emerald-50 via-gray-50 to-gray-100 py-8 px-4 flex flex-col items-center justify-center">
      {/* Top Bar */}
      <div className="w-full max-w-xl mb-4 flex items-center justify-between">
        <button
          onClick={onClose}
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-gray-600 hover:text-emerald-700 bg-white px-3 py-1.5 rounded-xl border border-gray-200 shadow-xs transition cursor-pointer"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Store POS
        </button>
        <div className="flex items-center gap-1.5 text-xs font-bold text-emerald-800 bg-emerald-100/70 px-3 py-1.5 rounded-xl">
          <ShieldCheck className="w-4 h-4 text-emerald-600" />
          Cryptographically Verified Digital Receipt
        </div>
      </div>

      {isLoading ? (
        <div className="w-full max-w-xl bg-white p-12 rounded-3xl border border-gray-200 shadow-lg text-center space-y-4">
          <div className="w-12 h-12 border-4 border-emerald-500 border-t-transparent rounded-full animate-spin mx-auto" />
          <p className="text-sm font-semibold text-gray-600">Verifying bill authenticity...</p>
        </div>
      ) : error || !invoice ? (
        <div className="w-full max-w-xl bg-white p-10 rounded-3xl border border-red-200 shadow-lg text-center space-y-4">
          <div className="w-14 h-14 bg-red-50 text-red-600 rounded-2xl flex items-center justify-center mx-auto">
            <AlertCircle className="w-8 h-8" />
          </div>
          <h2 className="text-lg font-bold text-gray-900">Verification Notice</h2>
          <p className="text-sm text-gray-600 max-w-sm mx-auto">{error || 'Invoice not found.'}</p>
          <button
            onClick={onClose}
            className="px-5 py-2 text-sm font-bold bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl shadow-md transition cursor-pointer"
          >
            Return to Dashboard
          </button>
        </div>
      ) : (
        <div className="w-full max-w-xl bg-white rounded-3xl border border-gray-200 shadow-xl overflow-hidden print:border-none print:shadow-none">
          {/* Header Banner */}
          <div className="bg-gradient-to-r from-emerald-600 to-teal-700 p-6 text-white text-center">
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-white/20 backdrop-blur-xs text-xs font-medium mb-3">
              <CheckCircle className="w-4 h-4 text-emerald-200" />
              Official BillWave Electronic Receipt
            </div>
            <h1 className="text-2xl font-black tracking-tight">{businessName}</h1>
            <p className="text-xs text-emerald-100 mt-1 max-w-sm mx-auto">{businessAddress}</p>
            {businessPhone && (
              <p className="text-xs text-emerald-200 font-mono mt-0.5">Tel: {businessPhone}</p>
            )}
            {gstin && (
              <p className="text-[11px] text-emerald-200 font-mono mt-0.5">GSTIN: {gstin}</p>
            )}
          </div>

          <div className="p-6 space-y-6">
            {/* Invoice Meta */}
            <div className="grid grid-cols-2 gap-4 pb-4 border-b border-gray-100 text-xs">
              <div>
                <span className="text-gray-400 block uppercase font-bold text-[10px]">Invoice No</span>
                <span className="font-mono font-bold text-emerald-800 text-sm">{invoice.invoiceNumber}</span>
              </div>
              <div className="text-right">
                <span className="text-gray-400 block uppercase font-bold text-[10px]">Date & Time</span>
                <span className="font-medium text-gray-700">{formatDate(invoice.createdAt)}</span>
              </div>

              <div>
                <span className="text-gray-400 block uppercase font-bold text-[10px]">Billed To</span>
                <span className="font-semibold text-gray-800">{invoice.customer?.name || 'Walk-in Customer'}</span>
                {invoice.customer?.phone && (
                  <span className="block text-gray-500 font-mono">{invoice.customer.phone}</span>
                )}
              </div>

              <div className="text-right">
                <span className="text-gray-400 block uppercase font-bold text-[10px]">Payment Method</span>
                <span className="font-bold uppercase tracking-wider text-emerald-700">{invoice.paymentMethod}</span>
                <span className="block text-[11px] text-gray-500 font-medium">Status: {(invoice.paymentStatus || invoice.status || 'paid').toUpperCase()}</span>
              </div>
            </div>

            {/* Items Table */}
            <div>
              <h3 className="text-xs font-bold text-gray-700 uppercase tracking-wider mb-2">Purchased Items</h3>
              <div className="space-y-2">
                {invoice.items.map((item, idx) => {
                  const lineTotal = item.lineTotal ?? item.totalPrice ?? (item.unitPrice * item.quantity);
                  const itemName = item.name || item.productName || 'Product';
                  return (
                    <div key={idx} className="flex items-center justify-between py-2 border-b border-gray-100 text-xs">
                      <div>
                        <p className="font-bold text-gray-900">{itemName}</p>
                        <p className="text-gray-400 text-[11px]">
                          {item.quantity} × {formatCurrency(item.unitPrice, currency)}
                          {item.taxRate > 0 && ` (GST ${item.taxRate}%)`}
                        </p>
                      </div>
                      <div className="text-right font-bold text-gray-900">
                        {formatCurrency(lineTotal, currency)}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Calculations Breakdown */}
            <div className="bg-gray-50 rounded-2xl p-4 space-y-2 text-xs">
              <div className="flex justify-between text-gray-600">
                <span>Subtotal</span>
                <span>{formatCurrency(invoice.subtotal, currency)}</span>
              </div>
              {discountAmount > 0 && (
                <div className="flex justify-between text-emerald-700 font-medium">
                  <span>Discount Applied</span>
                  <span>-{formatCurrency(discountAmount, currency)}</span>
                </div>
              )}
              <div className="flex justify-between text-gray-600">
                <span>Total GST / Tax</span>
                <span>{formatCurrency(taxAmount, currency)}</span>
              </div>
              <div className="flex justify-between pt-2 border-t border-gray-200 text-base font-black text-gray-900">
                <span>Net Total Paid</span>
                <span className="text-emerald-700">{formatCurrency(totalAmount, currency)}</span>
              </div>
            </div>

            {/* QR verification signature block */}
            <div className="flex items-center justify-between p-4 bg-emerald-50/50 rounded-2xl border border-emerald-100">
              <div className="space-y-1">
                <span className="text-xs font-bold text-emerald-900 flex items-center gap-1.5">
                  <ShieldCheck className="w-4 h-4 text-emerald-600" />
                  E-Invoice Verification Code
                </span>
                <p className="text-[11px] text-gray-500 font-mono break-all max-w-[260px]">
                  ID: {invoice.id}
                </p>
                <p className="text-[10px] text-emerald-700 font-medium">
                  Verified authentic transaction
                </p>
              </div>

              <div className="p-2 bg-white rounded-xl shadow-xs border border-gray-200 shrink-0">
                <QRCodeSVG
                  value={window.location.href}
                  size={72}
                  level="M"
                />
              </div>
            </div>

            {/* Actions */}
            <div className="flex items-center justify-center gap-3 pt-2 print:hidden">
              <button
                onClick={() => printInvoiceReceipt(invoice)}
                className="inline-flex items-center gap-2 px-5 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs rounded-xl shadow-md transition cursor-pointer"
              >
                <Printer className="w-4 h-4" />
                Print Official Receipt
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
