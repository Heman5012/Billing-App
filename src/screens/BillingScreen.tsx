import React, { useState } from 'react';
import {
  ShoppingCart,
  Search,
  Plus,
  Trash2,
  QrCode,
  Tag,
  Minus,
  Trash,
  CreditCard,
  User,
  ChevronDown,
  ChevronUp,
  Package,
} from 'lucide-react';
import { Product, BusinessProfile } from '../types';
import { useCart } from '../services/cartService';
import { InvoiceSummaryWidget } from '../components/InvoiceSummaryWidget';
import { firebaseService } from '../services/firebase';

interface BillingScreenProps {
  products: Product[];
  business: BusinessProfile;
  onProceedToPayment: () => void;
  onOpenScanner: () => void;
}

export const BillingScreen: React.FC<BillingScreenProps> = ({
  products,
  business,
  onProceedToPayment,
  onOpenScanner,
}) => {
  const cart = useCart();
  const [activeTab, setActiveTab] = useState<'catalogue' | 'cart'>('catalogue');
  const [searchQuery, setSearchQuery] = useState('');
  const [showCustomerFields, setShowCustomerFields] = useState(false);
  const [isCustomItemOpen, setIsCustomItemOpen] = useState(false);
  const [itemDiscountModalIndex, setItemDiscountModalIndex] = useState<number | null>(null);
  const [itemDiscountInput, setItemDiscountInput] = useState('');

  // Custom Item Form
  const [customItemForm, setCustomItemForm] = useState({
    name: '',
    price: '',
    quantity: '1',
    taxRate: '5',
    saveToCatalog: false,
  });

  const filteredProducts = products.filter((p) => {
    const q = searchQuery.toLowerCase().trim();
    if (!q) return true;
    return (
      p.name.toLowerCase().includes(q) ||
      (p.sku || '').toLowerCase().includes(q) ||
      (p.barcode || '').includes(q) ||
      (p.brand || '').toLowerCase().includes(q)
    );
  });

  const handleAddCustomItem = async (e: React.FormEvent) => {
    e.preventDefault();
    const price = parseFloat(customItemForm.price) || 0;
    const qty = parseInt(customItemForm.quantity, 10) || 1;
    const tax = parseFloat(customItemForm.taxRate) || 0;
    const name = customItemForm.name.trim();

    if (!name) return;

    if (customItemForm.saveToCatalog) {
      const now = new Date().toISOString();
      const newProd: Product = {
        id: `custom_${Date.now()}`,
        name,
        brand: '',
        sku: `SKU-${Date.now().toString().slice(-6)}`,
        barcode: '',
        price,
        stock: 100,
        taxRate: tax,
        category: 'General',
        imageUrl: '',
        createdAt: now,
        updatedAt: now,
      };
      await firebaseService.saveProduct(newProd);
    }

    cart.addCustomItem({
      name,
      unitPrice: price,
      quantity: qty,
      discountPercent: 0,
      taxRate: tax,
    });

    setIsCustomItemOpen(false);
    setCustomItemForm({
      name: '',
      price: '',
      quantity: '1',
      taxRate: '5',
      saveToCatalog: false,
    });
  };

  const openDiscountModal = (index: number) => {
    setItemDiscountModalIndex(index);
    setItemDiscountInput(cart.items[index].discountPercent ? cart.items[index].discountPercent.toString() : '');
  };

  const applyItemDiscount = () => {
    if (itemDiscountModalIndex !== null) {
      const val = parseFloat(itemDiscountInput) || 0;
      cart.setItemDiscount(itemDiscountModalIndex, val);
      setItemDiscountModalIndex(null);
    }
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 py-6 animate-in fade-in duration-200">
      {/* Mobile Tab Toggle */}
      <div className="lg:hidden flex mb-4 bg-slate-100 p-1 rounded-xl border border-slate-200">
        <button
          type="button"
          onClick={() => setActiveTab('catalogue')}
          className={`flex-1 py-2 text-xs font-bold rounded-lg transition-all ${
            activeTab === 'catalogue' ? 'bg-white text-blue-600 shadow-xs' : 'text-slate-600'
          }`}
        >
          Select Products
        </button>
        <button
          type="button"
          onClick={() => setActiveTab('cart')}
          className={`flex-1 py-2 text-xs font-bold rounded-lg transition-all flex items-center justify-center gap-1.5 ${
            activeTab === 'cart' ? 'bg-white text-blue-600 shadow-xs' : 'text-slate-600'
          }`}
        >
          <ShoppingCart className="w-3.5 h-3.5" />
          <span>Current Bill ({cart.itemCount})</span>
        </button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* Left Catalogue Pane */}
        <div
          className={`lg:col-span-6 xl:col-span-7 bg-white p-5 rounded-2xl border border-slate-200/90 shadow-2xs space-y-4 ${
            activeTab === 'cart' ? 'hidden lg:block' : 'block'
          }`}
        >
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-base font-bold text-slate-900">Select Products</h2>
              <p className="text-xs text-slate-500">Pick from catalogue or scan barcode</p>
            </div>
            <button
              type="button"
              onClick={() => setIsCustomItemOpen(true)}
              className="px-3 py-1.5 text-xs font-bold text-blue-700 bg-blue-50 hover:bg-blue-100 border border-blue-200 rounded-xl flex items-center gap-1 transition-colors"
            >
              <Plus className="w-3.5 h-3.5" />
              Custom Item
            </button>
          </div>

          {/* Search + Barcode Button */}
          <div className="flex gap-2">
            <div className="relative flex-1">
              <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search catalogue by name, SKU or barcode..."
                className="w-full pl-9 pr-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-blue-500/30 focus:border-blue-500 font-medium"
              />
            </div>
            <button
              type="button"
              onClick={onOpenScanner}
              className="p-2 text-blue-600 bg-blue-50 hover:bg-blue-100 border border-blue-200 rounded-xl flex items-center justify-center shrink-0"
              title="Scan barcode"
            >
              <QrCode className="w-4 h-4" />
            </button>
          </div>

          {/* Product Items List */}
          <div className="divide-y divide-slate-100 max-h-[580px] overflow-y-auto pr-1">
            {filteredProducts.map((p) => {
              const qtyInCart = cart.getProductQuantity(p);
              const inCart = qtyInCart > 0;
              const isOutOfStock = p.stock <= 0;

              return (
                <div
                  key={p.id}
                  className="py-3 flex items-center justify-between gap-3 hover:bg-slate-50/70 px-2 rounded-xl transition-colors"
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <div className="w-10 h-10 rounded-lg bg-slate-50 border border-slate-100 flex items-center justify-center shrink-0 overflow-hidden">
                      {p.imageUrl ? (
                        <img
                          src={p.imageUrl}
                          alt={p.name}
                          className="w-full h-full object-contain p-0.5"
                          onError={(e) => {
                            (e.target as HTMLElement).style.display = 'none';
                          }}
                        />
                      ) : (
                        <Package className="w-5 h-5 text-slate-400" />
                      )}
                    </div>
                    <div className="min-w-0">
                      <div className="text-xs font-bold text-slate-800 truncate">{p.name}</div>
                      <div className="text-[11px] text-slate-400">
                        ₹{p.price.toFixed(2)} • Stock: {p.stock}
                        {inCart && <span className="text-blue-600 font-bold"> • In Bill: {qtyInCart}</span>}
                        {p.taxRate > 0 && <span> • {p.taxRate}% GST</span>}
                      </div>
                    </div>
                  </div>

                  <button
                    type="button"
                    disabled={isOutOfStock}
                    onClick={() => cart.addProduct(p)}
                    className={`px-3 py-1.5 text-xs font-bold rounded-xl flex items-center gap-1 transition-all shrink-0 ${
                      isOutOfStock
                        ? 'bg-slate-200 text-slate-400 cursor-not-allowed'
                        : inCart
                        ? 'bg-blue-600 text-white hover:bg-blue-700 shadow-xs'
                        : 'bg-emerald-600 hover:bg-emerald-700 text-white shadow-xs'
                    }`}
                  >
                    <Plus className="w-3.5 h-3.5" />
                    {inCart ? 'Add (+1)' : 'Add'}
                  </button>
                </div>
              );
            })}
          </div>
        </div>

        {/* Right Active Bill Pane */}
        <div
          className={`lg:col-span-6 xl:col-span-5 bg-white p-5 rounded-2xl border border-slate-200/90 shadow-2xs space-y-4 ${
            activeTab === 'catalogue' ? 'hidden lg:block' : 'block'
          }`}
        >
          {/* Header */}
          <div className="flex items-center justify-between pb-3 border-b border-slate-100">
            <div className="flex items-center gap-2">
              <ShoppingCart className="w-5 h-5 text-blue-600" />
              <h2 className="text-base font-bold text-slate-900">Current Bill</h2>
              <span className="px-2 py-0.5 text-xs font-extrabold bg-blue-100 text-blue-700 rounded-full">
                {cart.itemCount} items
              </span>
            </div>
            {cart.items.length > 0 && (
              <button
                type="button"
                onClick={() => {
                  if (confirm('Are you sure you want to clear this entire bill?')) {
                    cart.clear();
                  }
                }}
                className="text-xs font-semibold text-red-600 hover:text-red-700 flex items-center gap-1"
              >
                <Trash className="w-3.5 h-3.5" />
                Clear Bill
              </button>
            )}
          </div>

          {/* Optional Customer Accordion */}
          <div className="border border-slate-200 rounded-xl overflow-hidden bg-slate-50/50">
            <button
              type="button"
              onClick={() => setShowCustomerFields(!showCustomerFields)}
              className="w-full px-4 py-2.5 text-left text-xs font-bold text-slate-700 flex items-center justify-between hover:bg-slate-100/60 transition-colors"
            >
              <span className="flex items-center gap-1.5">
                <User className="w-3.5 h-3.5 text-slate-500" />
                {cart.customer.name ? `Customer: ${cart.customer.name}` : 'Customer Details (Optional)'}
              </span>
              {showCustomerFields ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
            </button>
            {showCustomerFields && (
              <div className="p-3 bg-white border-t border-slate-200 space-y-2.5">
                <div className="grid grid-cols-2 gap-2">
                  <input
                    type="text"
                    value={cart.customer.name}
                    onChange={(e) => cart.updateCustomer({ name: e.target.value })}
                    placeholder="Customer Name"
                    className="w-full px-3 py-1.5 text-xs bg-slate-50 border border-slate-200 rounded-lg focus:bg-white focus:outline-none focus:ring-1 focus:ring-blue-500"
                  />
                  <input
                    type="tel"
                    value={cart.customer.phone}
                    onChange={(e) => cart.updateCustomer({ phone: e.target.value })}
                    placeholder="Phone Number"
                    className="w-full px-3 py-1.5 text-xs bg-slate-50 border border-slate-200 rounded-lg focus:bg-white focus:outline-none focus:ring-1 focus:ring-blue-500"
                  />
                </div>
                <input
                  type="text"
                  value={cart.notes}
                  onChange={(e) => cart.updateNotes(e.target.value)}
                  placeholder="Invoice Note / Reference..."
                  className="w-full px-3 py-1.5 text-xs bg-slate-50 border border-slate-200 rounded-lg focus:bg-white focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
            )}
          </div>

          {/* Cart Items List */}
          {cart.items.length === 0 ? (
            <div className="py-12 text-center text-slate-400">
              <ShoppingCart className="w-10 h-10 mx-auto mb-2 opacity-30 text-slate-400" />
              <p className="text-xs font-semibold text-slate-600">Your bill is empty.</p>
              <p className="text-[11px] text-slate-400 mt-0.5">Select products from the catalogue or scan barcodes.</p>
            </div>
          ) : (
            <div className="divide-y divide-slate-100 max-h-[300px] overflow-y-auto pr-1">
              {cart.items.map((item, index) => (
                <div key={`${item.name}-${index}`} className="py-2.5 flex items-center justify-between gap-2">
                  <div className="min-w-0 flex-1">
                    <div className="text-xs font-bold text-slate-900 truncate">{item.name}</div>
                    <div className="text-[11px] text-slate-500">
                      ₹{item.unitPrice.toFixed(2)} × {item.quantity} = ₹{item.lineSubtotal.toFixed(2)}
                      {item.discountPercent > 0 && (
                        <span className="text-blue-600 font-semibold"> • Disc: {item.discountPercent}%</span>
                      )}
                      {item.taxRate > 0 && <span className="text-slate-400"> • Tax: {item.taxRate}%</span>}
                    </div>
                  </div>

                  {/* Discount button */}
                  <button
                    type="button"
                    onClick={() => openDiscountModal(index)}
                    className={`p-1.5 rounded-lg text-xs transition-colors ${
                      item.discountPercent > 0
                        ? 'text-blue-600 bg-blue-50'
                        : 'text-slate-400 hover:text-slate-600 hover:bg-slate-100'
                    }`}
                    title="Set Item Discount"
                  >
                    <Tag className="w-3.5 h-3.5" />
                  </button>

                  {/* Quantity Stepper */}
                  <div className="flex items-center gap-1 bg-slate-100 p-0.5 rounded-lg">
                    <button
                      type="button"
                      onClick={() => cart.updateQuantity(index, -1)}
                      className="p-1 text-slate-500 hover:text-slate-800 rounded transition-colors"
                    >
                      <Minus className="w-3 h-3" />
                    </button>
                    <span className="w-6 text-center text-xs font-bold text-slate-900">{item.quantity}</span>
                    <button
                      type="button"
                      onClick={() => cart.updateQuantity(index, 1)}
                      className="p-1 text-slate-500 hover:text-slate-800 rounded transition-colors"
                    >
                      <Plus className="w-3 h-3" />
                    </button>
                  </div>

                  {/* Line Total */}
                  <div className="text-right min-w-[60px]">
                    <div className="text-xs font-extrabold text-slate-900">₹{item.lineTotal.toFixed(2)}</div>
                  </div>

                  {/* Delete Item */}
                  <button
                    type="button"
                    onClick={() => cart.removeItem(index)}
                    className="p-1 text-slate-400 hover:text-red-600 transition-colors"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              ))}
            </div>
          )}

          {/* Totals Summary */}
          <InvoiceSummaryWidget
            subtotal={cart.subtotal}
            overallDiscountPercent={cart.overallDiscountPercent}
            overallDiscountAmount={cart.overallDiscountAmount}
            taxableAmount={cart.taxableTotal}
            tax={cart.taxTotal}
            taxBreakdown={cart.taxBreakdown}
            total={cart.grandTotal}
            currency={business.currency}
            onOverallDiscountChanged={(d) => cart.updateOverallDiscount(d)}
          />

          {/* Checkout Button */}
          <button
            type="button"
            disabled={cart.isEmpty}
            onClick={onProceedToPayment}
            className="w-full py-3.5 text-xs sm:text-sm font-extrabold text-white bg-blue-600 hover:bg-blue-700 disabled:bg-slate-200 disabled:text-slate-400 rounded-xl flex items-center justify-center gap-2 shadow-sm shadow-blue-500/25 transition-all"
          >
            <CreditCard className="w-4 h-4" />
            Proceed to Payment ({business.currency}
            {cart.grandTotal.toFixed(2)})
          </button>
        </div>
      </div>

      {/* Custom Item Modal */}
      {isCustomItemOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/70 backdrop-blur-xs animate-in fade-in">
          <div className="w-full max-w-sm bg-white rounded-2xl shadow-2xl p-6 border border-slate-200">
            <h3 className="text-sm font-bold text-slate-900 mb-4">Add Custom / Ad-hoc Item</h3>
            <form onSubmit={handleAddCustomItem} className="space-y-3">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Item Name *</label>
                <input
                  type="text"
                  required
                  value={customItemForm.name}
                  onChange={(e) => setCustomItemForm({ ...customItemForm, name: e.target.value })}
                  placeholder="e.g. Gift Wrapping or Fresh Fruit"
                  className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-300 rounded-xl focus:bg-white focus:outline-none"
                />
              </div>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">Price (₹) *</label>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    required
                    value={customItemForm.price}
                    onChange={(e) => setCustomItemForm({ ...customItemForm, price: e.target.value })}
                    placeholder="0.00"
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-300 rounded-xl focus:bg-white focus:outline-none font-bold"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">Quantity</label>
                  <input
                    type="number"
                    min="1"
                    value={customItemForm.quantity}
                    onChange={(e) => setCustomItemForm({ ...customItemForm, quantity: e.target.value })}
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-300 rounded-xl focus:bg-white focus:outline-none"
                  />
                </div>
              </div>
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Tax Rate</label>
                <select
                  value={customItemForm.taxRate}
                  onChange={(e) => setCustomItemForm({ ...customItemForm, taxRate: e.target.value })}
                  className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-300 rounded-xl focus:bg-white focus:outline-none"
                >
                  <option value="0">0% Exempt</option>
                  <option value="5">5% GST</option>
                  <option value="12">12% GST</option>
                  <option value="18">18% GST</option>
                  <option value="28">28% GST</option>
                </select>
              </div>
              <div className="flex items-center gap-2 pt-1">
                <input
                  type="checkbox"
                  id="saveCatalog"
                  checked={customItemForm.saveToCatalog}
                  onChange={(e) => setCustomItemForm({ ...customItemForm, saveToCatalog: e.target.checked })}
                  className="rounded text-blue-600 focus:ring-blue-500"
                />
                <label htmlFor="saveCatalog" className="text-xs text-slate-600">
                  Save to product catalogue for future bills
                </label>
              </div>
              <div className="pt-3 flex justify-end gap-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setIsCustomItemOpen(false)}
                  className="px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-100 rounded-xl"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-1.5 text-xs font-bold text-white bg-blue-600 hover:bg-blue-700 rounded-xl"
                >
                  Add to Bill
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Item Discount Modal */}
      {itemDiscountModalIndex !== null && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/70 backdrop-blur-xs animate-in fade-in">
          <div className="w-full max-w-xs bg-white rounded-2xl shadow-2xl p-5 border border-slate-200">
            <h3 className="text-xs font-bold text-slate-900 mb-1">
              Item Discount: {cart.items[itemDiscountModalIndex]?.name}
            </h3>
            <p className="text-[11px] text-slate-500 mb-3">Enter discount percentage for this specific line item</p>
            <div className="flex gap-2 mb-3">
              <input
                type="number"
                min="0"
                max="100"
                value={itemDiscountInput}
                onChange={(e) => setItemDiscountInput(e.target.value)}
                placeholder="Discount %"
                className="w-full px-3 py-2 text-xs border border-slate-300 rounded-xl text-center font-bold"
                autoFocus
              />
            </div>
            <div className="flex justify-end gap-2">
              <button
                type="button"
                onClick={() => {
                  cart.setItemDiscount(itemDiscountModalIndex, 0);
                  setItemDiscountModalIndex(null);
                }}
                className="px-3 py-1.5 text-xs text-slate-500 hover:bg-slate-100 rounded-lg"
              >
                Clear
              </button>
              <button
                type="button"
                onClick={applyItemDiscount}
                className="px-4 py-1.5 text-xs font-bold text-white bg-blue-600 hover:bg-blue-700 rounded-lg"
              >
                Apply
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
