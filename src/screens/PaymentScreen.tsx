import React, { useState } from 'react';
import {
  ArrowLeft,
  AlertCircle,
  QrCode,
  CreditCard,
  Banknote,
  CheckCircle2,
  XCircle,
  Loader2,
  ShieldCheck,
} from 'lucide-react';
import { InvoiceItem, CustomerDetails, BusinessProfile, Invoice } from '../types';
import { firebaseService } from '../services/firebase';

interface PaymentScreenProps {
  items: InvoiceItem[];
  customer: CustomerDetails;
  overallDiscountPercent: number;
  overallDiscountAmount: number;
  taxableAmount: number;
  tax: number;
  taxBreakdown: Record<string, number>;
  total: number;
  notes: string;
  business: BusinessProfile;
  onPaymentSuccess: (invoice: Invoice) => void;
  onCancel: () => void;
}

export const PaymentScreen: React.FC<PaymentScreenProps> = ({
  items,
  customer,
  overallDiscountPercent,
  overallDiscountAmount,
  taxableAmount,
  tax,
  taxBreakdown,
  total,
  notes,
  business,
  onPaymentSuccess,
  onCancel,
}) => {
  const [selectedMethod, setSelectedMethod] = useState<'UPI' | 'Card' | 'Cash'>('UPI');
  const [selectedUpiApp, setSelectedUpiApp] = useState('Google Pay');
  const [upiId, setUpiId] = useState('merchant@billwave');
  const [cashReceived, setCashReceived] = useState(total.toFixed(0));
  const [isProcessing, setIsProcessing] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const cashVal = parseFloat(cashReceived) || 0;
  const changeDue = Math.max(0, cashVal - total);

  const generateInvoiceNumber = () => {
    const now = new Date();
    const dateStr = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(
      now.getDate()
    ).padStart(2, '0')}`;
    const rand = Math.floor(1000 + Math.random() * 9000);
    return `INV-${dateStr}-${rand}`;
  };

  const generateShareToken = (invNum: string) => {
    const chars = 'abcdef0123456789';
    let res = `${invNum.toLowerCase().replace(/[^a-z0-9]/g, '')}-`;
    for (let i = 0; i < 16; i++) {
      res += chars[Math.floor(Math.random() * chars.length)];
    }
    return res;
  };

  const handleProcessPayment = async (simulateSuccess: boolean) => {
    if (isProcessing) return;
    setIsProcessing(true);
    setErrorMessage(null);

    // Simulated network processing delay
    await new Promise((resolve) => setTimeout(resolve, 1200));

    if (!simulateSuccess) {
      setIsProcessing(false);
      setErrorMessage(
        'Demo payment failed (simulated decline). You can retry or choose another payment method.'
      );
      return;
    }

    try {
      const invNum = generateInvoiceNumber();
      const shareToken = generateShareToken(invNum);
      const user = firebaseService.getCurrentUser();

      const paymentMethodLabel =
        selectedMethod === 'UPI'
          ? `UPI (Demo - ${selectedUpiApp})`
          : selectedMethod === 'Card'
          ? 'Card (Demo)'
          : 'Cash (Demo)';

      const newInvoice: Invoice = {
        id: invNum,
        invoiceNumber: invNum,
        userId: user?.uid || 'demo_merchant',
        customer: { ...customer },
        items: [...items],
        subtotal: items.reduce((s, i) => s + i.lineSubtotal, 0),
        overallDiscountPercent,
        overallDiscountAmount,
        taxableAmount,
        tax,
        taxBreakdown,
        total,
        paymentMethod: paymentMethodLabel,
        paymentStatus: 'paid',
        transactionMode: 'SIMULATED / DEMO',
        notes: notes || '',
        createdAt: new Date().toISOString(),
        shareToken,
      };

      await firebaseService.createInvoice(newInvoice);
      onPaymentSuccess(newInvoice);
    } catch (err: any) {
      setIsProcessing(false);
      setErrorMessage(`Checkout failed: ${err.message || err}`);
    }
  };

  return (
    <div className="max-w-2xl mx-auto px-4 sm:px-6 py-8 animate-in fade-in duration-200">
      <div className="bg-white rounded-3xl border border-slate-200 shadow-xl overflow-hidden p-6 sm:p-8 space-y-6">
        {/* Header */}
        <div className="flex items-center gap-3">
          <button
            type="button"
            disabled={isProcessing}
            onClick={onCancel}
            className="p-2 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-xl transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div>
            <h1 className="text-lg sm:text-xl font-extrabold text-slate-900 tracking-tight">
              Simulated Payment Checkout
            </h1>
            <p className="text-xs text-slate-500">Test secure payment methods with simulated verification</p>
          </div>
        </div>

        {/* DEMO MODE NOTICE BANNER */}
        <div className="p-3.5 bg-amber-50 border border-amber-200 rounded-2xl flex items-center gap-3 text-amber-900">
          <ShieldCheck className="w-5 h-5 text-amber-600 shrink-0" />
          <div className="text-xs">
            <span className="font-extrabold block">DEMO MODE — No real money transferred</span>
            <span className="text-amber-800/80">Simulate UPI, card or cash transactions safely for testing.</span>
          </div>
        </div>

        {/* Amount Payable Box */}
        <div className="p-5 bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-100 rounded-2xl flex items-center justify-between">
          <div>
            <span className="text-xs font-semibold text-blue-700 uppercase tracking-wider block">
              Payable Amount
            </span>
            <span className="text-xs text-blue-600 font-medium">
              {items.length} items in current bill
            </span>
          </div>
          <div className="text-2xl sm:text-3xl font-black text-blue-900">
            {business.currency}
            {total.toFixed(2)}
          </div>
        </div>

        {/* Error message */}
        {errorMessage && (
          <div className="p-3.5 bg-red-50 border border-red-200 rounded-2xl text-xs text-red-800 flex items-center gap-2">
            <AlertCircle className="w-4 h-4 text-red-600 shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        {/* Payment Methods Selection */}
        <div>
          <label className="block text-xs font-bold text-slate-700 mb-2">Choose Demo Payment Method</label>
          <div className="grid grid-cols-3 gap-2 p-1 bg-slate-100 rounded-xl border border-slate-200/60">
            <button
              type="button"
              disabled={isProcessing}
              onClick={() => {
                setSelectedMethod('UPI');
                setErrorMessage(null);
              }}
              className={`py-2 text-xs font-bold rounded-lg flex items-center justify-center gap-1.5 transition-all ${
                selectedMethod === 'UPI' ? 'bg-white text-blue-600 shadow-xs' : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              <QrCode className="w-3.5 h-3.5" />
              UPI Demo
            </button>
            <button
              type="button"
              disabled={isProcessing}
              onClick={() => {
                setSelectedMethod('Card');
                setErrorMessage(null);
              }}
              className={`py-2 text-xs font-bold rounded-lg flex items-center justify-center gap-1.5 transition-all ${
                selectedMethod === 'Card' ? 'bg-white text-blue-600 shadow-xs' : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              <CreditCard className="w-3.5 h-3.5" />
              Card Demo
            </button>
            <button
              type="button"
              disabled={isProcessing}
              onClick={() => {
                setSelectedMethod('Cash');
                setErrorMessage(null);
              }}
              className={`py-2 text-xs font-bold rounded-lg flex items-center justify-center gap-1.5 transition-all ${
                selectedMethod === 'Cash' ? 'bg-white text-blue-600 shadow-xs' : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              <Banknote className="w-3.5 h-3.5" />
              Cash Demo
            </button>
          </div>
        </div>

        {/* Method Details */}
        {selectedMethod === 'UPI' && (
          <div className="p-4 bg-slate-50 border border-slate-200 rounded-2xl space-y-3">
            <span className="text-xs font-bold text-slate-700 block">Select Demo UPI Application:</span>
            <div className="flex flex-wrap gap-2">
              {['Google Pay', 'PhonePe', 'Paytm', 'BHIM UPI'].map((app) => (
                <button
                  key={app}
                  type="button"
                  onClick={() => setSelectedUpiApp(app)}
                  className={`px-3 py-1.5 text-xs font-semibold rounded-xl border transition-all ${
                    selectedUpiApp === app
                      ? 'bg-blue-600 text-white border-blue-600 shadow-xs'
                      : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-100'
                  }`}
                >
                  {app}
                </button>
              ))}
            </div>
            <div>
              <label className="block text-[11px] font-medium text-slate-500 mb-1">Simulated UPI ID / VPA</label>
              <input
                type="text"
                value={upiId}
                onChange={(e) => setUpiId(e.target.value)}
                className="w-full px-3 py-2 text-xs bg-white border border-slate-300 rounded-xl focus:outline-none focus:ring-1 focus:ring-blue-500 font-mono"
              />
            </div>
          </div>
        )}

        {selectedMethod === 'Card' && (
          <div className="p-6 bg-gradient-to-tr from-slate-900 via-indigo-950 to-blue-900 rounded-2xl text-white shadow-md space-y-4">
            <div className="flex items-center justify-between text-xs font-bold tracking-widest text-slate-300 uppercase">
              <span>Demo Payment Card</span>
              <CreditCard className="w-5 h-5 text-blue-400" />
            </div>
            <div className="text-lg sm:text-xl font-mono tracking-widest font-bold">•••• •••• •••• 4242</div>
            <div className="flex items-center justify-between text-xs">
              <div>
                <span className="block text-[9px] text-slate-400 uppercase">Card Holder</span>
                <span className="font-semibold">{business.businessName.toUpperCase() || 'DEMO MERCHANT'}</span>
              </div>
              <div className="text-right">
                <span className="block text-[9px] text-slate-400 uppercase">Expires</span>
                <span className="font-semibold">12/29</span>
              </div>
            </div>
          </div>
        )}

        {selectedMethod === 'Cash' && (
          <div className="p-4 bg-slate-50 border border-slate-200 rounded-2xl space-y-3">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Cash Received ({business.currency})</label>
              <input
                type="number"
                step="1"
                value={cashReceived}
                onChange={(e) => setCashReceived(e.target.value)}
                className="w-full px-3 py-2 text-sm font-bold bg-white border border-slate-300 rounded-xl focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </div>
            <div className="flex items-center justify-between p-3 bg-white rounded-xl border border-slate-200">
              <span className="text-xs font-bold text-slate-700">Change Due to Customer:</span>
              <span
                className={`text-base font-black ${
                  changeDue > 0 ? 'text-emerald-600' : 'text-slate-800'
                }`}
              >
                {business.currency}
                {changeDue.toFixed(2)}
              </span>
            </div>
          </div>
        )}

        {/* Action Buttons */}
        <div className="pt-2 space-y-2">
          {isProcessing ? (
            <div className="w-full py-4 text-center text-xs font-bold text-blue-600 flex items-center justify-center gap-2">
              <Loader2 className="w-5 h-5 animate-spin" />
              <span>Processing simulated payment...</span>
            </div>
          ) : (
            <>
              <button
                type="button"
                onClick={() => handleProcessPayment(true)}
                className="w-full py-3.5 text-xs sm:text-sm font-extrabold text-white bg-emerald-600 hover:bg-emerald-700 rounded-xl flex items-center justify-center gap-2 shadow-sm shadow-emerald-500/25 transition-all"
              >
                <CheckCircle2 className="w-4 h-4" />
                {selectedMethod === 'Cash'
                  ? `Confirm Demo Cash (${business.currency}${total.toFixed(2)})`
                  : `Complete Demo Payment (${business.currency}${total.toFixed(2)})`}
              </button>

              {selectedMethod !== 'Cash' && (
                <button
                  type="button"
                  onClick={() => handleProcessPayment(false)}
                  className="w-full py-2.5 text-xs font-bold text-red-600 hover:text-red-700 bg-red-50 hover:bg-red-100/70 border border-red-200 rounded-xl flex items-center justify-center gap-1.5 transition-colors"
                >
                  <XCircle className="w-3.5 h-3.5" />
                  Simulate Gateway Failure (Test Error Handling)
                </button>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
};
