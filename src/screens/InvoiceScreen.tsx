import React from 'react';
import {
  ArrowLeft,
  Printer,
  Share2,
  Plus,
  CheckCircle,
  Copy,
  ExternalLink,
} from 'lucide-react';
import { QRCodeSVG } from 'qrcode.react';
import { Invoice, BusinessProfile } from '../types';
import { PdfService } from '../services/pdfService';

interface InvoiceScreenProps {
  invoice: Invoice;
  business: BusinessProfile;
  onStartNewBill: () => void;
  onBackToHistory: () => void;
}

export const InvoiceScreen: React.FC<InvoiceScreenProps> = ({
  invoice,
  business,
  onStartNewBill,
  onBackToHistory,
}) => {
  const currency = business.currency || '₹';
  const shareUrl = `${window.location.origin}/?token=${invoice.shareToken}`;

  const formattedDate = new Date(invoice.createdAt).toLocaleDateString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

  const copyShareLink = async () => {
    try {
      await navigator.clipboard.writeText(shareUrl);
      alert('Verification link copied to clipboard!');
    } catch (_) {}
  };

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 py-8 space-y-6 animate-in fade-in duration-200">
      {/* Top Action Header Bar */}
      <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/90 shadow-2xs flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={onBackToHistory}
            className="p-2 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-xl transition-colors"
            title="Back to History"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-sm font-extrabold text-slate-900">
                Invoice {invoice.invoiceNumber}
              </span>
              <span className="px-2 py-0.5 text-[10px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200 rounded-full flex items-center gap-1">
                <CheckCircle className="w-3 h-3" />
                Completed
              </span>
            </div>
            <p className="text-xs text-slate-500">Recorded safely in cloud & local storage</p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={() => PdfService.printInvoice(invoice, business)}
            className="px-3.5 py-2 text-xs font-bold text-white bg-emerald-600 hover:bg-emerald-700 rounded-xl flex items-center gap-1.5 shadow-xs transition-colors"
          >
            <Printer className="w-4 h-4" />
            Print / Save PDF
          </button>
          <button
            type="button"
            onClick={() => PdfService.shareInvoice(invoice, business)}
            className="px-3.5 py-2 text-xs font-bold text-slate-700 bg-white hover:bg-slate-50 border border-slate-200 rounded-xl flex items-center gap-1.5 transition-colors shadow-2xs"
          >
            <Share2 className="w-4 h-4 text-slate-500" />
            Share Receipt
          </button>
          <button
            type="button"
            onClick={onStartNewBill}
            className="px-3.5 py-2 text-xs font-bold text-blue-700 bg-blue-50 hover:bg-blue-100 border border-blue-200 rounded-xl flex items-center gap-1.5 transition-colors"
          >
            <Plus className="w-4 h-4" />
            New Bill
          </button>
        </div>
      </div>

      {/* Official Tax Invoice Receipt Card */}
      <div className="bg-white rounded-3xl border border-slate-200 shadow-xl p-6 sm:p-10 space-y-6">
        {/* Top Branding & Meta Header */}
        <div className="flex flex-col sm:flex-row sm:items-start justify-between gap-4 pb-6 border-b border-slate-200">
          <div>
            <div className="flex items-center gap-2 mb-2">
              <span className="px-2 py-0.5 text-xs font-bold bg-emerald-600 text-white rounded">
                BillWave
              </span>
              <span className="text-xs font-extrabold text-slate-900 tracking-wider">
                TAX INVOICE
              </span>
            </div>
            <h2 className="text-xl font-extrabold text-slate-900">{business.businessName}</h2>
            {business.address && (
              <p className="text-xs text-slate-500 mt-1">{business.address}</p>
            )}
            {business.phone && (
              <p className="text-xs text-slate-500">Contact: {business.phone}</p>
            )}
          </div>

          <div className="sm:text-right">
            <span className="inline-block px-2 py-0.5 text-[10px] font-bold bg-amber-50 text-amber-800 border border-amber-300 rounded mb-2">
              DEMO TRANSACTION
            </span>
            <div className="text-sm font-extrabold text-slate-900 font-mono">
              {invoice.invoiceNumber}
            </div>
            <div className="text-xs text-slate-500 mt-0.5">{formattedDate}</div>
            <div className="text-xs font-bold text-emerald-700 mt-1.5 inline-block px-2 py-0.5 bg-emerald-50 rounded">
              {invoice.paymentMethod} • {invoice.paymentStatus.toUpperCase()}
            </div>
          </div>
        </div>

        {/* Customer Details */}
        {(invoice.customer.name || invoice.customer.phone) && (
          <div className="p-3 bg-slate-50 rounded-xl border border-slate-200 text-xs text-slate-700 flex flex-wrap gap-4">
            <div>
              <span className="font-bold text-slate-900">Billed To: </span>
              <span>{invoice.customer.name || 'Customer'}</span>
            </div>
            {invoice.customer.phone && (
              <div>
                <span className="font-bold text-slate-900">Phone: </span>
                <span>{invoice.customer.phone}</span>
              </div>
            )}
          </div>
        )}

        {/* Items Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b-2 border-slate-200 bg-slate-50/70 text-slate-600 uppercase text-[11px] font-bold">
                <th className="py-2.5 px-3">Item Description</th>
                <th className="py-2.5 px-3 text-right">Unit Price</th>
                <th className="py-2.5 px-3 text-center">Qty</th>
                <th className="py-2.5 px-3 text-center">GST Tax</th>
                <th className="py-2.5 px-3 text-right">Total</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {invoice.items.map((item, index) => (
                <tr key={`${item.name}-${index}`} className="hover:bg-slate-50/50">
                  <td className="py-3 px-3 font-semibold text-slate-800">{item.name}</td>
                  <td className="py-3 px-3 text-right font-medium text-slate-600">
                    {currency}
                    {item.unitPrice.toFixed(2)}
                  </td>
                  <td className="py-3 px-3 text-center font-bold text-slate-900">{item.quantity}</td>
                  <td className="py-3 px-3 text-center text-slate-500">{item.taxRate}%</td>
                  <td className="py-3 px-3 text-right font-extrabold text-slate-900">
                    {currency}
                    {item.lineTotal.toFixed(2)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Financial Summary & QR Code Section */}
        <div className="pt-4 border-t border-slate-200 grid grid-cols-1 md:grid-cols-2 gap-8 items-start">
          {/* QR Code Verification Card */}
          <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200/90 flex flex-col items-center sm:items-start text-center sm:text-left space-y-3">
            <span className="text-xs font-bold text-slate-800 flex items-center gap-1.5">
              <CheckCircle className="w-4 h-4 text-emerald-600" />
              Digital Receipt &amp; QR Verification
            </span>
            <div className="p-2.5 bg-white rounded-xl shadow-xs border border-slate-200 inline-block">
              <QRCodeSVG value={shareUrl} size={118} level="M" />
            </div>
            <p className="text-[11px] text-slate-500 max-w-xs">
              Scan with phone camera to view and verify this receipt online without app installation.
            </p>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={copyShareLink}
                className="px-2.5 py-1 text-[11px] font-semibold text-slate-700 bg-white hover:bg-slate-100 border border-slate-200 rounded-lg flex items-center gap-1 transition-colors"
              >
                <Copy className="w-3 h-3 text-slate-400" />
                Copy Link
              </button>
              <a
                href={shareUrl}
                target="_blank"
                rel="noreferrer"
                className="px-2.5 py-1 text-[11px] font-semibold text-blue-600 bg-blue-50 hover:bg-blue-100 border border-blue-200 rounded-lg flex items-center gap-1 transition-colors"
              >
                <ExternalLink className="w-3 h-3" />
                Open
              </a>
            </div>
          </div>

          {/* Totals Breakdown */}
          <div className="space-y-2.5 text-xs">
            <div className="flex items-center justify-between text-slate-600">
              <span>Subtotal:</span>
              <span className="font-semibold text-slate-900">
                {currency}
                {invoice.subtotal.toFixed(2)}
              </span>
            </div>

            {invoice.overallDiscountAmount > 0 && (
              <div className="flex items-center justify-between text-red-600 font-semibold">
                <span>Discount ({invoice.overallDiscountPercent.toFixed(0)}%):</span>
                <span>
                  -{currency}
                  {invoice.overallDiscountAmount.toFixed(2)}
                </span>
              </div>
            )}

            <div className="flex items-center justify-between text-slate-600">
              <span>Taxable Amount:</span>
              <span className="font-medium">
                {currency}
                {invoice.taxableAmount.toFixed(2)}
              </span>
            </div>

            {Object.entries(invoice.taxBreakdown).map(([slab, amt]) => (
              <div key={slab} className="flex items-center justify-between text-slate-500 text-[11px]">
                <span>Tax ({slab}):</span>
                <span>
                  {currency}
                  {amt.toFixed(2)}
                </span>
              </div>
            ))}

            <div className="border-t-2 border-slate-900 pt-3 flex items-baseline justify-between text-slate-900">
              <span className="text-sm font-extrabold">Grand Total:</span>
              <span className="text-2xl font-black text-emerald-600">
                {currency}
                {invoice.total.toFixed(2)}
              </span>
            </div>
          </div>
        </div>

        {invoice.notes && (
          <div className="pt-3 border-t border-slate-100 text-xs text-slate-500 italic">
            Note: {invoice.notes}
          </div>
        )}
      </div>
    </div>
  );
};
