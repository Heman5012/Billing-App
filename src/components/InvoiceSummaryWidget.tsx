import React, { useState } from 'react';
import { Tag, ChevronDown, ChevronUp } from 'lucide-react';

interface InvoiceSummaryProps {
  subtotal: number;
  overallDiscountPercent: number;
  overallDiscountAmount: number;
  taxableAmount: number;
  tax: number;
  taxBreakdown: Record<string, number>;
  total: number;
  currency?: string;
  onOverallDiscountChanged: (discount: number) => void;
}

export const InvoiceSummaryWidget: React.FC<InvoiceSummaryProps> = ({
  subtotal,
  overallDiscountPercent,
  overallDiscountAmount,
  taxableAmount,
  tax,
  taxBreakdown,
  total,
  currency = '₹',
  onOverallDiscountChanged,
}) => {
  const [showDiscountInput, setShowDiscountInput] = useState(overallDiscountPercent > 0);
  const [tempDiscount, setTempDiscount] = useState(overallDiscountPercent.toString());

  const handleApplyDiscount = () => {
    const val = parseFloat(tempDiscount);
    if (!isNaN(val) && val >= 0 && val <= 100) {
      onOverallDiscountChanged(val);
    } else {
      setTempDiscount(overallDiscountPercent.toString());
    }
  };

  return (
    <div className="bg-slate-50/80 rounded-2xl p-5 border border-slate-200/80 shadow-xs space-y-3.5">
      <div className="flex items-center justify-between text-xs font-medium text-slate-600">
        <span>Cart Subtotal</span>
        <span className="font-semibold text-slate-800">
          {currency}
          {subtotal.toFixed(2)}
        </span>
      </div>

      {/* Overall Discount Row & Toggle */}
      <div className="border-t border-slate-200/60 pt-3">
        <div className="flex items-center justify-between">
          <button
            type="button"
            onClick={() => setShowDiscountInput(!showDiscountInput)}
            className="text-xs font-semibold text-blue-600 hover:text-blue-700 flex items-center gap-1.5 transition-colors"
          >
            <Tag className="w-3.5 h-3.5" />
            {overallDiscountPercent > 0
              ? `Overall Bill Discount (${overallDiscountPercent.toFixed(0)}%)`
              : 'Add Bill Discount'}
            {showDiscountInput ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
          </button>
          {overallDiscountAmount > 0 && (
            <span className="text-xs font-bold text-red-600">
              -{currency}
              {overallDiscountAmount.toFixed(2)}
            </span>
          )}
        </div>

        {showDiscountInput && (
          <div className="mt-2.5 flex items-center gap-2 p-2.5 bg-white rounded-xl border border-blue-100 shadow-xs">
            <span className="text-xs text-slate-500 font-medium">Discount %:</span>
            <input
              type="number"
              min="0"
              max="100"
              value={tempDiscount}
              onChange={(e) => setTempDiscount(e.target.value)}
              onBlur={handleApplyDiscount}
              onKeyDown={(e) => e.key === 'Enter' && handleApplyDiscount()}
              placeholder="0"
              className="w-16 px-2 py-1 text-xs border border-slate-300 rounded-lg text-center font-bold text-slate-800 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <div className="flex gap-1">
              {[5, 10, 15].map((preset) => (
                <button
                  key={preset}
                  type="button"
                  onClick={() => {
                    setTempDiscount(preset.toString());
                    onOverallDiscountChanged(preset);
                  }}
                  className={`px-2 py-1 text-[11px] font-semibold rounded-md border transition-all ${
                    overallDiscountPercent === preset
                      ? 'bg-blue-600 text-white border-blue-600'
                      : 'bg-slate-50 hover:bg-slate-100 text-slate-600 border-slate-200'
                  }`}
                >
                  {preset}%
                </button>
              ))}
              {overallDiscountPercent > 0 && (
                <button
                  type="button"
                  onClick={() => {
                    setTempDiscount('0');
                    onOverallDiscountChanged(0);
                    setShowDiscountInput(false);
                  }}
                  className="px-2 py-1 text-[11px] font-semibold text-red-600 hover:bg-red-50 rounded-md border border-red-200"
                >
                  Clear
                </button>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Taxable Amount */}
      <div className="flex items-center justify-between text-xs text-slate-600">
        <span>Taxable Amount</span>
        <span className="font-medium text-slate-800">
          {currency}
          {taxableAmount.toFixed(2)}
        </span>
      </div>

      {/* Detailed Tax Breakdown by GST Slabs */}
      {Object.entries(taxBreakdown).length > 0 && (
        <div className="bg-white/70 rounded-xl p-3 border border-slate-200/60 space-y-1.5">
          <div className="text-[11px] font-bold text-slate-500 tracking-wider uppercase">Tax Breakdown</div>
          {Object.entries(taxBreakdown).map(([rate, amt]) => (
            <div key={rate} className="flex items-center justify-between text-xs text-slate-600">
              <span className="text-slate-500">GST slab ({rate})</span>
              <span className="font-medium text-slate-700">
                {currency}
                {amt.toFixed(2)}
              </span>
            </div>
          ))}
          <div className="border-t border-slate-100 pt-1.5 flex items-center justify-between text-xs font-semibold text-slate-800">
            <span>Total Tax</span>
            <span>
              {currency}
              {tax.toFixed(2)}
            </span>
          </div>
        </div>
      )}

      {/* Grand Total */}
      <div className="border-t border-slate-300 pt-3 flex items-baseline justify-between">
        <div>
          <span className="text-sm font-extrabold text-slate-900">Grand Total</span>
          <span className="block text-[11px] text-slate-500">Includes all applicable taxes</span>
        </div>
        <span className="text-2xl font-black text-emerald-600 tracking-tight">
          {currency}
          {total.toFixed(2)}
        </span>
      </div>
    </div>
  );
};
