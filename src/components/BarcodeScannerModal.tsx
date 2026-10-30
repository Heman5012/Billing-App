import React, { useState, useEffect, useRef } from 'react';
import {
  X,
  Camera,
  Search,
  Sparkles,
  Check,
  AlertCircle,
  Volume2,
  VolumeX,
  FlipHorizontal,
  Zap,
  Image as ImageIcon,
  Plus,
  Minus,
  ShoppingCart,
  ArrowRight
} from 'lucide-react';
import { Html5Qrcode, Html5QrcodeSupportedFormats } from 'html5-qrcode';
import { firebaseService } from '../services/firebase';
import { Product } from '../types';
import { INITIAL_PRODUCTS } from '../services/seedData';

interface BarcodeScannerModalProps {
  isOpen: boolean;
  onClose: () => void;
  onDetected: (barcode: string, product?: Product | null) => void;
  title?: string;
  subtitle?: string;
}

// Play pleasant checkout beep using Web Audio API
const playBeep = () => {
  try {
    const AudioContextClass = window.AudioContext || (window as any).webkitAudioContext;
    if (!AudioContextClass) return;
    const ctx = new AudioContextClass();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(1400, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(1800, ctx.currentTime + 0.08);

    gain.gain.setValueAtTime(0.3, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.12);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start();
    osc.stop(ctx.currentTime + 0.12);
  } catch (_) {}
};

export const BarcodeScannerModal: React.FC<BarcodeScannerModalProps> = ({
  isOpen,
  onClose,
  onDetected,
  title = 'Barcode & QR Scanner',
  subtitle = 'Point camera at any product barcode to auto-detect and add to bill',
}) => {
  const [manualCode, setManualCode] = useState('');
  const [isSearching, setIsSearching] = useState(false);
  const [cameraActive, setCameraActive] = useState(false);
  const [cameraError, setCameraError] = useState<string | null>(null);
  const [soundEnabled, setSoundEnabled] = useState(true);
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [scannedBarcode, setScannedBarcode] = useState<string>('');
  const [itemQuantity, setItemQuantity] = useState<number>(1);
  const [facingMode, setFacingMode] = useState<'environment' | 'user'>('environment');
  const [torchOn, setTorchOn] = useState(false);
  const [hasTorch, setHasTorch] = useState(false);

  const html5QrCodeRef = useRef<Html5Qrcode | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const isHandlingScanRef = useRef(false);

  useEffect(() => {
    if (!isOpen) {
      stopScanner();
      setSelectedProduct(null);
      setScannedBarcode('');
      setManualCode('');
      setCameraError(null);
      isHandlingScanRef.current = false;
      return;
    }

    // Small delay to ensure DOM container `#reader` is mounted
    const timer = setTimeout(() => {
      startScanner();
    }, 250);

    return () => {
      clearTimeout(timer);
      stopScanner();
    };
  }, [isOpen, facingMode]);

  const startScanner = async () => {
    try {
      setCameraError(null);
      const readerElem = document.getElementById('barcode-reader-viewport');
      if (!readerElem) return;

      // Stop existing instance if any
      await stopScanner();

      const scanner = new Html5Qrcode('barcode-reader-viewport', {
        formatsToSupport: [
          Html5QrcodeSupportedFormats.EAN_13,
          Html5QrcodeSupportedFormats.EAN_8,
          Html5QrcodeSupportedFormats.CODE_128,
          Html5QrcodeSupportedFormats.CODE_39,
          Html5QrcodeSupportedFormats.UPC_A,
          Html5QrcodeSupportedFormats.UPC_E,
          Html5QrcodeSupportedFormats.QR_CODE,
          Html5QrcodeSupportedFormats.DATA_MATRIX,
        ],
        verbose: false,
      });

      html5QrCodeRef.current = scanner;

      const config = {
        fps: 15,
        qrbox: { width: 280, height: 180 },
        aspectRatio: 1.333,
      };

      await scanner.start(
        { facingMode },
        config,
        (decodedText) => {
          handleSuccessfulScan(decodedText);
        },
        () => {
          // Frame analysis in progress (ignore no-detection frames)
        }
      );

      setCameraActive(true);

      // Check if torch/flashlight is supported
      try {
        const capabilities = scanner.getRunningTrackCapabilities();
        if (capabilities && (capabilities as any).torch) {
          setHasTorch(true);
        }
      } catch (_) {}
    } catch (err: any) {
      console.warn('Camera start error:', err);
      setCameraActive(false);
      setCameraError(
        'Unable to access camera. Please allow camera permissions in browser settings, or enter barcode manually below.'
      );
    }
  };

  const stopScanner = async () => {
    if (html5QrCodeRef.current) {
      try {
        if (html5QrCodeRef.current.isScanning) {
          await html5QrCodeRef.current.stop();
        }
        html5QrCodeRef.current.clear();
      } catch (e) {
        console.warn('Error stopping scanner:', e);
      } finally {
        html5QrCodeRef.current = null;
        setCameraActive(false);
      }
    }
  };

  const toggleTorch = async () => {
    if (!html5QrCodeRef.current || !hasTorch) return;
    try {
      const nextState = !torchOn;
      await html5QrCodeRef.current.applyVideoConstraints({
        advanced: [{ torch: nextState } as any],
      });
      setTorchOn(nextState);
    } catch (_) {}
  };

  const toggleCameraFacing = () => {
    setFacingMode((prev) => (prev === 'environment' ? 'user' : 'environment'));
  };

  const handleSuccessfulScan = async (code: string) => {
    if (isHandlingScanRef.current) return;
    const clean = code.trim();
    if (!clean) return;

    isHandlingScanRef.current = true;

    // Haptic feedback
    if (navigator.vibrate) {
      navigator.vibrate([80, 40, 80]);
    }
    if (soundEnabled) {
      playBeep();
    }

    setScannedBarcode(clean);
    setIsSearching(true);

    try {
      const product = await firebaseService.findProductByBarcode(clean);
      if (product) {
        setSelectedProduct(product);
        setItemQuantity(1);
      } else {
        // Unknown barcode, allow adding to cart directly or opening catalog
        setSelectedProduct({
          id: `prod_${clean}`,
          name: `Scanned Item (${clean})`,
          sku: `SKU-${clean.slice(-4)}`,
          brand: 'General',
          imageUrl: '',
          price: 99.0,
          stock: 50,
          barcode: clean,
          category: 'General',
          taxRate: 5,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        });
        setItemQuantity(1);
      }
    } catch (_) {
      setSelectedProduct(null);
    } finally {
      setIsSearching(false);
    }
  };

  const handleConfirmAddToCart = (andCheckout = false) => {
    if (selectedProduct) {
      // Repeat call or add multiple quantity
      for (let i = 0; i < itemQuantity; i++) {
        onDetected(scannedBarcode || selectedProduct.barcode, selectedProduct);
      }
    }
    if (andCheckout) {
      onClose();
    } else {
      // Reset selected preview and continue scanning
      setSelectedProduct(null);
      setScannedBarcode('');
      isHandlingScanRef.current = false;
    }
  };

  const handleManualLookup = async (code: string) => {
    const clean = code.trim();
    if (!clean) return;
    handleSuccessfulScan(clean);
  };

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    try {
      const scanner = new Html5Qrcode('barcode-file-decoder');
      const result = await scanner.scanFile(file, true);
      scanner.clear();
      if (result) {
        handleSuccessfulScan(result);
      }
    } catch (err: any) {
      alert('Could not detect a barcode in this image. Please try another photo or enter manually.');
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-900/80 backdrop-blur-xs animate-in fade-in duration-200">
      <div className="relative w-full max-w-lg bg-white rounded-3xl shadow-2xl overflow-hidden border border-slate-200 flex flex-col max-h-[94vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-3.5 border-b border-slate-100 bg-slate-50/80">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-blue-600 text-white flex items-center justify-center shadow-xs">
              <Camera className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-sm font-bold text-slate-900">{title}</h3>
              <p className="text-[11px] text-slate-500">{subtitle}</p>
            </div>
          </div>

          {/* Quick controls */}
          <div className="flex items-center gap-1">
            <button
              type="button"
              onClick={() => setSoundEnabled(!soundEnabled)}
              className={`p-2 rounded-xl transition ${
                soundEnabled ? 'text-blue-600 bg-blue-50' : 'text-slate-400 hover:bg-slate-100'
              }`}
              title={soundEnabled ? 'Mute beep' : 'Enable beep sound'}
            >
              {soundEnabled ? <Volume2 className="w-4 h-4" /> : <VolumeX className="w-4 h-4" />}
            </button>

            {hasTorch && (
              <button
                type="button"
                onClick={toggleTorch}
                className={`p-2 rounded-xl transition ${
                  torchOn ? 'text-amber-500 bg-amber-50' : 'text-slate-400 hover:bg-slate-100'
                }`}
                title="Toggle Torch"
              >
                <Zap className="w-4 h-4" />
              </button>
            )}

            <button
              type="button"
              onClick={toggleCameraFacing}
              className="p-2 text-slate-500 hover:bg-slate-100 rounded-xl transition"
              title="Flip camera"
            >
              <FlipHorizontal className="w-4 h-4" />
            </button>

            <button
              onClick={onClose}
              className="p-2 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-xl transition-colors ml-1"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Hidden element for file scanning */}
        <div id="barcode-file-decoder" className="hidden" />

        {/* Body */}
        <div className="p-5 overflow-y-auto space-y-4">
          {/* Active Camera Viewport */}
          <div className="relative w-full bg-slate-950 rounded-2xl overflow-hidden border border-slate-800 shadow-inner flex flex-col items-center justify-center min-h-[220px]">
            <div
              id="barcode-reader-viewport"
              className="w-full h-full min-h-[220px] [&_video]:w-full [&_video]:object-cover"
            />

            {/* Target Reticle Overlay */}
            {cameraActive && !selectedProduct && (
              <div className="absolute inset-x-8 inset-y-6 pointer-events-none border-2 border-emerald-400/80 rounded-xl flex flex-col justify-between p-2 shadow-[0_0_20px_rgba(16,185,129,0.3)]">
                <div className="flex justify-between">
                  <div className="w-5 h-5 border-t-3 border-l-3 border-emerald-400 rounded-tl-sm" />
                  <div className="w-5 h-5 border-t-3 border-r-3 border-emerald-400 rounded-tr-sm" />
                </div>
                <div className="w-full h-0.5 bg-red-500/90 shadow-[0_0_10px_rgba(239,68,68,0.9)] animate-pulse" />
                <div className="flex justify-between">
                  <div className="w-5 h-5 border-b-3 border-l-3 border-emerald-400 rounded-bl-sm" />
                  <div className="w-5 h-5 border-b-3 border-r-3 border-emerald-400 rounded-br-sm" />
                </div>
              </div>
            )}

            {/* Camera Error Message */}
            {cameraError && (
              <div className="p-4 text-center text-slate-300 max-w-sm">
                <AlertCircle className="w-8 h-8 mx-auto mb-2 text-amber-400" />
                <p className="text-xs font-semibold text-white">Camera Offline or Permission Denied</p>
                <p className="text-[11px] text-slate-400 mt-1">{cameraError}</p>
                <button
                  type="button"
                  onClick={startScanner}
                  className="mt-3 px-3 py-1.5 text-xs font-bold text-white bg-blue-600 hover:bg-blue-700 rounded-xl"
                >
                  Retry Camera Permission
                </button>
              </div>
            )}
          </div>

          {/* Scanned Product Detected Modal Overlay Card */}
          {selectedProduct && (
            <div className="p-4 bg-emerald-50 border-2 border-emerald-400 rounded-2xl shadow-lg animate-in fade-in zoom-in-95 space-y-3">
              <div className="flex items-start justify-between gap-3">
                <div className="flex items-center gap-3">
                  {selectedProduct.imageUrl ? (
                    <img
                      src={selectedProduct.imageUrl}
                      alt={selectedProduct.name}
                      className="w-14 h-14 object-contain rounded-xl bg-white border border-emerald-200 p-1 shrink-0"
                    />
                  ) : (
                    <div className="w-14 h-14 rounded-xl bg-emerald-100 text-emerald-700 flex items-center justify-center font-bold text-lg shrink-0">
                      ✓
                    </div>
                  )}
                  <div>
                    <span className="text-[10px] font-bold uppercase text-emerald-700 bg-emerald-100/80 px-2 py-0.5 rounded-md">
                      Item Detected
                    </span>
                    <h4 className="text-sm font-bold text-slate-900 mt-0.5">{selectedProduct.name}</h4>
                    <div className="text-sm font-black text-emerald-700">₹{selectedProduct.price.toFixed(2)}</div>
                    <div className="text-[10px] text-slate-500 font-mono">Barcode: {scannedBarcode}</div>
                  </div>
                </div>

                {/* Quantity Controls */}
                <div className="flex items-center gap-1.5 bg-white border border-emerald-300 rounded-xl p-1 shadow-2xs">
                  <button
                    type="button"
                    onClick={() => setItemQuantity(Math.max(1, itemQuantity - 1))}
                    className="p-1 hover:bg-slate-100 rounded text-slate-600"
                  >
                    <Minus className="w-3.5 h-3.5" />
                  </button>
                  <span className="w-6 text-center text-xs font-bold text-slate-900">{itemQuantity}</span>
                  <button
                    type="button"
                    onClick={() => setItemQuantity(itemQuantity + 1)}
                    className="p-1 hover:bg-slate-100 rounded text-slate-600"
                  >
                    <Plus className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>

              {/* Action Buttons for Scanned Item */}
              <div className="grid grid-cols-2 gap-2 pt-1">
                <button
                  type="button"
                  onClick={() => handleConfirmAddToCart(false)}
                  className="py-2.5 px-3 text-xs font-bold rounded-xl text-emerald-800 bg-emerald-100 hover:bg-emerald-200 border border-emerald-300 transition flex items-center justify-center gap-1.5 cursor-pointer"
                >
                  <Plus className="w-3.5 h-3.5" />
                  Add & Scan Next
                </button>
                <button
                  type="button"
                  onClick={() => handleConfirmAddToCart(true)}
                  className="py-2.5 px-3 text-xs font-bold rounded-xl text-white bg-emerald-600 hover:bg-emerald-700 shadow transition flex items-center justify-center gap-1.5 cursor-pointer"
                >
                  <ShoppingCart className="w-3.5 h-3.5" />
                  Add & View Bill
                </button>
              </div>
            </div>
          )}

          {/* Manual Barcode Input & Photo Upload */}
          <div className="space-y-2">
            <form
              onSubmit={(e) => {
                e.preventDefault();
                handleManualLookup(manualCode);
              }}
              className="flex gap-2"
            >
              <div className="relative flex-1">
                <input
                  type="text"
                  value={manualCode}
                  onChange={(e) => setManualCode(e.target.value)}
                  placeholder="Type barcode (e.g. 8901030895458)..."
                  className="w-full pl-3.5 pr-8 py-2 text-xs bg-slate-50 border border-slate-300 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-blue-500/30 focus:border-blue-500 font-mono"
                />
                {manualCode && (
                  <button
                    type="button"
                    onClick={() => setManualCode('')}
                    className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                  >
                    <X className="w-3.5 h-3.5" />
                  </button>
                )}
              </div>
              <button
                type="submit"
                disabled={isSearching || !manualCode.trim()}
                className="px-3.5 py-2 text-xs font-bold text-white bg-blue-600 hover:bg-blue-700 disabled:bg-slate-300 rounded-xl flex items-center gap-1.5 transition-colors shrink-0 cursor-pointer"
              >
                <Search className="w-3.5 h-3.5" />
                Find
              </button>
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                className="p-2 text-slate-600 bg-slate-100 hover:bg-slate-200 border border-slate-300 rounded-xl transition"
                title="Scan barcode from image photo"
              >
                <ImageIcon className="w-4 h-4" />
              </button>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={handleFileUpload}
              />
            </form>
          </div>

          {/* Quick-Scan Demo Barcodes from the 10 FMCG Items */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-bold text-slate-700 flex items-center gap-1.5">
                <Sparkles className="w-3.5 h-3.5 text-amber-500" />
                1-Tap Test FMCG Barcodes
              </span>
              <span className="text-[10px] text-slate-400">Click any product to simulate scan</span>
            </div>
            <div className="grid grid-cols-2 sm:grid-cols-5 gap-2 max-h-36 overflow-y-auto p-1">
              {INITIAL_PRODUCTS.map((prod) => (
                <button
                  key={prod.barcode}
                  type="button"
                  onClick={() => {
                    setManualCode(prod.barcode);
                    handleManualLookup(prod.barcode);
                  }}
                  className="p-2 text-left bg-slate-50 hover:bg-blue-50 border border-slate-200 hover:border-blue-300 rounded-xl transition-all text-[11px] group flex flex-col justify-between h-16 cursor-pointer"
                >
                  <div className="font-semibold text-slate-800 group-hover:text-blue-700 truncate">
                    {prod.name.split(' ')[0]}
                  </div>
                  <div className="font-mono text-[9px] text-slate-400 group-hover:text-blue-500 truncate">
                    {prod.barcode.slice(-6)}
                  </div>
                  <div className="font-bold text-emerald-600 text-[10px]">₹{prod.price}</div>
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="px-5 py-3 bg-slate-50 border-t border-slate-100 flex items-center justify-between">
          <span className="text-[11px] text-slate-500 font-medium">
            Supports EAN-13, EAN-8, Code-128, UPC-A, & QR Codes
          </span>
          <button
            onClick={onClose}
            className="px-4 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-200 rounded-xl transition cursor-pointer"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
