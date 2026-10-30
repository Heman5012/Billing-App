import React, { useState } from 'react';
import { X, Printer, QrCode, Barcode, Check, Copy, ExternalLink, Download } from 'lucide-react';
import { QRCodeSVG } from 'qrcode.react';
import { Product } from '../types';
import { BarcodeRenderer } from './BarcodeRenderer';

interface BarcodeModalProps {
  isOpen: boolean;
  onClose: () => void;
  product?: Product | null;
  allProducts?: Product[];
}

export const BarcodeModal: React.FC<BarcodeModalProps> = ({
  isOpen,
  onClose,
  product,
  allProducts,
}) => {
  const [activeTab, setActiveTab] = useState<'single' | 'all'>(product ? 'single' : 'all');
  const [copiedCode, setCopiedCode] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleCopy = (code: string) => {
    navigator.clipboard.writeText(code);
    setCopiedCode(code);
    setTimeout(() => setCopiedCode(null), 2000);
  };

  const handlePrint = () => {
    window.print();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-900/80 backdrop-blur-xs animate-in fade-in duration-200">
      <div className="relative w-full max-w-3xl bg-white rounded-3xl shadow-2xl overflow-hidden border border-slate-200 flex flex-col max-h-[92vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100 bg-slate-50/80">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-blue-100 text-blue-700 flex items-center justify-center font-bold">
              <Barcode className="w-6 h-6" />
            </div>
            <div>
              <h3 className="text-base font-bold text-slate-900">
                {activeTab === 'single' && product
                  ? `${product.name} — Barcode & QR`
                  : 'Printable Scannable Barcode Catalog'}
              </h3>
              <p className="text-xs text-slate-500">
                High-contrast scannable codes ready for phone camera POS detection
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            {allProducts && allProducts.length > 0 && product && (
              <div className="flex bg-slate-200/80 p-0.5 rounded-xl text-xs font-semibold">
                <button
                  type="button"
                  onClick={() => setActiveTab('single')}
                  className={`px-3 py-1 rounded-lg transition ${
                    activeTab === 'single'
                      ? 'bg-white text-blue-700 shadow-xs'
                      : 'text-slate-600 hover:text-slate-900'
                  }`}
                >
                  This Item
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTab('all')}
                  className={`px-3 py-1 rounded-lg transition ${
                    activeTab === 'all'
                      ? 'bg-white text-blue-700 shadow-xs'
                      : 'text-slate-600 hover:text-slate-900'
                  }`}
                >
                  All Items ({allProducts.length})
                </button>
              </div>
            )}

            <button
              type="button"
              onClick={handlePrint}
              className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-slate-700 bg-white hover:bg-slate-100 border border-slate-300 rounded-xl shadow-2xs transition"
              title="Print Barcode Sheet"
            >
              <Printer className="w-4 h-4 text-slate-600" />
              <span>Print Sheet</span>
            </button>

            <button
              onClick={onClose}
              className="p-2 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-xl transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="p-6 overflow-y-auto space-y-6">
          {activeTab === 'single' && product ? (
            <div className="max-w-md mx-auto space-y-6 text-center">
              {/* Product Info Card */}
              <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 flex items-center gap-4 text-left">
                {product.imageUrl && (
                  <img
                    src={product.imageUrl}
                    alt={product.name}
                    className="w-16 h-16 object-contain rounded-xl bg-white p-1 border border-slate-200 shrink-0"
                  />
                )}
                <div>
                  <div className="text-[10px] font-bold uppercase text-blue-600 tracking-wider">
                    {product.category || 'General'}
                  </div>
                  <h4 className="text-sm font-bold text-slate-900">{product.name}</h4>
                  <div className="text-sm font-black text-emerald-600 mt-0.5">₹{product.price.toFixed(2)}</div>
                  <div className="text-[11px] text-slate-500 font-mono mt-0.5">Stock: {product.stock} units</div>
                </div>
              </div>

              {/* 1D Barcode Container */}
              <div className="p-6 bg-white rounded-2xl border-2 border-slate-200 shadow-xs flex flex-col items-center">
                <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 mb-2">
                  1D Barcode (EAN-13 / Code-128)
                </span>
                <div className="bg-white p-2 rounded-lg">
                  <BarcodeRenderer
                    value={product.barcode}
                    width={2}
                    height={65}
                    fontSize={13}
                  />
                </div>
                <div className="mt-2 flex items-center gap-2">
                  <code className="text-xs font-mono font-bold text-slate-700 bg-slate-100 px-2 py-1 rounded">
                    {product.barcode}
                  </code>
                  <button
                    type="button"
                    onClick={() => handleCopy(product.barcode)}
                    className="text-xs font-semibold text-blue-600 hover:text-blue-800 flex items-center gap-1"
                  >
                    {copiedCode === product.barcode ? (
                      <>
                        <Check className="w-3.5 h-3.5 text-emerald-600" />
                        <span className="text-emerald-600">Copied</span>
                      </>
                    ) : (
                      <>
                        <Copy className="w-3.5 h-3.5" />
                        <span>Copy</span>
                      </>
                    )}
                  </button>
                </div>
              </div>

              {/* 2D QR Code Container */}
              <div className="p-6 bg-white rounded-2xl border-2 border-slate-200 shadow-xs flex flex-col items-center">
                <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 mb-2">
                  2D QR Code (Quick Camera Scanner)
                </span>
                <div className="p-3 bg-white border border-slate-200 rounded-xl shadow-inner">
                  <QRCodeSVG value={product.barcode} size={150} level="H" />
                </div>
                <p className="text-[11px] text-slate-500 mt-2">
                  Point your phone camera here to scan instantly in BillWave
                </p>
              </div>
            </div>
          ) : (
            /* All Products Barcode Poster Grid */
            <div className="space-y-4">
              <div className="bg-blue-50 border border-blue-200 p-3.5 rounded-2xl flex items-center justify-between text-xs text-blue-900">
                <div>
                  <strong>Tip for Mobile Scanning:</strong> Keep this barcode sheet open on a computer screen or print it. Open the BillWave scanner on your phone to scan each item in seconds!
                </div>
                <button
                  type="button"
                  onClick={handlePrint}
                  className="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white font-bold rounded-xl text-xs flex items-center gap-1.5 shrink-0 ml-3"
                >
                  <Printer className="w-3.5 h-3.5" />
                  Print Catalog Sheet
                </button>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
                {(allProducts || []).map((prod) => (
                  <div
                    key={prod.id}
                    className="p-4 bg-white rounded-2xl border-2 border-slate-200 hover:border-blue-400 transition-colors flex flex-col justify-between shadow-xs"
                  >
                    <div>
                      <div className="flex items-center gap-2 mb-2">
                        {prod.imageUrl && (
                          <img
                            src={prod.imageUrl}
                            alt={prod.name}
                            className="w-10 h-10 object-contain rounded-lg border border-slate-100 p-0.5 shrink-0"
                          />
                        )}
                        <div className="min-w-0">
                          <h5 className="text-xs font-bold text-slate-900 truncate">{prod.name}</h5>
                          <div className="text-xs font-black text-emerald-600">₹{prod.price.toFixed(2)}</div>
                        </div>
                      </div>

                      {/* Barcode SVG */}
                      <div className="flex justify-center my-2 bg-slate-50/60 p-2 rounded-xl">
                        <BarcodeRenderer
                          value={prod.barcode}
                          width={1.6}
                          height={45}
                          fontSize={11}
                        />
                      </div>
                    </div>

                    <div className="flex items-center justify-between pt-2 border-t border-slate-100 text-[11px] font-mono text-slate-500">
                      <span className="truncate">{prod.barcode}</span>
                      <button
                        type="button"
                        onClick={() => handleCopy(prod.barcode)}
                        className="text-blue-600 hover:text-blue-800 font-semibold"
                      >
                        {copiedCode === prod.barcode ? 'Copied' : 'Copy'}
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-3 bg-slate-50 border-t border-slate-100 flex items-center justify-between">
          <p className="text-[11px] text-slate-400">
            Works with both 1D Barcode laser / camera scanner & 2D QR camera decoders
          </p>
          <button
            onClick={onClose}
            className="px-4 py-2 text-xs font-semibold text-slate-700 hover:bg-slate-200 rounded-xl transition"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
