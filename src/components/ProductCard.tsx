import React from 'react';
import { Package, Plus, Edit2, Trash2, AlertTriangle, CheckCircle2, ShoppingBag, Barcode } from 'lucide-react';
import { Product } from '../types';

interface ProductCardProps {
  product: Product;
  quantityInCart?: number;
  onAddToCart?: (product: Product) => void;
  onEdit?: (product: Product) => void;
  onDelete?: (product: Product) => void;
  onView?: (product: Product) => void;
  onViewBarcode?: (product: Product) => void;
}

export const ProductCard: React.FC<ProductCardProps> = ({
  product,
  quantityInCart = 0,
  onAddToCart,
  onEdit,
  onDelete,
  onView,
  onViewBarcode,
}) => {
  const isOutOfStock = product.stock <= 0;
  const isLowStock = !isOutOfStock && product.stock <= 5;
  const inCart = quantityInCart > 0;

  return (
    <div
      onClick={() => onView && onView(product)}
      className={`group relative bg-white rounded-2xl border transition-all duration-200 flex flex-col justify-between overflow-hidden shadow-xs hover:shadow-md ${
        inCart ? 'border-blue-500 ring-1 ring-blue-500/20' : 'border-slate-200/90 hover:border-slate-300'
      }`}
    >
      {/* Top Details & Image */}
      <div className="p-4">
        <div className="flex items-start gap-3">
          {/* Thumbnail */}
          <div className="relative w-14 h-14 rounded-xl bg-slate-50 border border-slate-100 flex items-center justify-center shrink-0 overflow-hidden group-hover:scale-105 transition-transform">
            {product.imageUrl ? (
              <img
                src={product.imageUrl}
                alt={product.name}
                className="w-full h-full object-contain p-1"
                onError={(e) => {
                  (e.target as HTMLElement).style.display = 'none';
                }}
              />
            ) : (
              <Package className="w-6 h-6 text-slate-400" />
            )}
            {inCart && (
              <span className="absolute top-1 right-1 w-4 h-4 bg-blue-600 text-white rounded-full text-[9px] font-bold flex items-center justify-center">
                {quantityInCart}
              </span>
            )}
          </div>

          {/* Info */}
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-1.5 mb-1">
              <span className="px-2 py-0.5 text-[10px] font-semibold bg-slate-100 text-slate-600 rounded-md truncate max-w-[110px]">
                {product.category || 'General'}
              </span>
              {product.brand && (
                <span className="text-[11px] text-slate-400 font-medium truncate">• {product.brand}</span>
              )}
            </div>
            <h4 className="text-xs font-bold text-slate-900 line-clamp-2 leading-snug group-hover:text-blue-600 transition-colors">
              {product.name}
            </h4>
            <div className="mt-1 flex items-center gap-2 text-[11px] font-mono text-slate-400">
              {product.barcode && <span className="truncate">BC: {product.barcode}</span>}
            </div>
          </div>
        </div>

        {/* Stock Status Badge */}
        <div className="mt-3 flex items-center justify-between text-xs">
          <div className="flex items-center gap-1.5">
            {isOutOfStock ? (
              <span className="inline-flex items-center gap-1 text-[11px] font-bold text-red-700 bg-red-50 border border-red-200 px-2 py-0.5 rounded-md">
                <AlertTriangle className="w-3 h-3 text-red-500" />
                Out of Stock
              </span>
            ) : isLowStock ? (
              <span className="inline-flex items-center gap-1 text-[11px] font-bold text-amber-700 bg-amber-50 border border-amber-200 px-2 py-0.5 rounded-md">
                <AlertTriangle className="w-3 h-3 text-amber-500" />
                {product.stock} left (Low)
              </span>
            ) : (
              <span className="inline-flex items-center gap-1 text-[11px] font-medium text-slate-500 bg-slate-50 px-2 py-0.5 rounded-md">
                <CheckCircle2 className="w-3 h-3 text-emerald-500" />
                {product.stock} in stock
              </span>
            )}
          </div>
          {product.taxRate > 0 && (
            <span className="text-[11px] font-semibold text-blue-600 bg-blue-50 px-1.5 py-0.5 rounded">
              {product.taxRate}% GST
            </span>
          )}
        </div>
      </div>

      {/* Bottom Bar: Price and Actions */}
      <div className="px-4 py-3 bg-slate-50/70 border-t border-slate-100 flex items-center justify-between">
        <div>
          <span className="text-[10px] text-slate-400 block font-medium">Price</span>
          <span className="text-base font-black text-slate-900">
            ₹{product.price.toFixed(2)}
          </span>
        </div>

        <div className="flex items-center gap-1.5" onClick={(e) => e.stopPropagation()}>
          {onViewBarcode && (
            <button
              type="button"
              onClick={() => onViewBarcode(product)}
              className="p-1.5 text-slate-500 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors cursor-pointer"
              title="View & Print Barcode / QR"
            >
              <Barcode className="w-3.5 h-3.5" />
            </button>
          )}
          {onEdit && (
            <button
              type="button"
              onClick={() => onEdit(product)}
              className="p-1.5 text-slate-400 hover:text-slate-700 hover:bg-slate-200/60 rounded-lg transition-colors cursor-pointer"
              title="Edit product"
            >
              <Edit2 className="w-3.5 h-3.5" />
            </button>
          )}
          {onDelete && (
            <button
              type="button"
              onClick={() => onDelete(product)}
              className="p-1.5 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors cursor-pointer"
              title="Delete product"
            >
              <Trash2 className="w-3.5 h-3.5" />
            </button>
          )}
          {onAddToCart && (
            <button
              type="button"
              disabled={isOutOfStock}
              onClick={() => onAddToCart(product)}
              className={`px-3 py-1.5 text-xs font-bold rounded-xl flex items-center gap-1 transition-all ${
                isOutOfStock
                  ? 'bg-slate-200 text-slate-400 cursor-not-allowed'
                  : inCart
                  ? 'bg-blue-600 text-white hover:bg-blue-700 shadow-xs'
                  : 'bg-emerald-600 hover:bg-emerald-700 text-white shadow-xs'
              }`}
            >
              {inCart ? (
                <>
                  <Plus className="w-3.5 h-3.5" />
                  Add (+1)
                </>
              ) : (
                <>
                  <ShoppingBag className="w-3.5 h-3.5" />
                  Add
                </>
              )}
            </button>
          )}
        </div>
      </div>
    </div>
  );
};
