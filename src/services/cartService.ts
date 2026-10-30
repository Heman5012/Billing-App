import { useState, useEffect } from 'react';
import { Product, InvoiceItem, CustomerDetails, AddToCartResult, AddToCartStatus } from '../types';

class CartStore {
  private static instance: CartStore;
  private items: InvoiceItem[] = [];
  private customer: CustomerDetails = { name: '', phone: '', email: '' };
  private overallDiscountPercent: number = 0;
  private notes: string = '';
  private listeners: (() => void)[] = [];

  private constructor() {
    this.loadFromStorage();
  }

  public static getInstance(): CartStore {
    if (!CartStore.instance) {
      CartStore.instance = new CartStore();
    }
    return CartStore.instance;
  }

  private saveToStorage() {
    try {
      localStorage.setItem(
        'billwave_cart',
        JSON.stringify({
          items: this.items,
          customer: this.customer,
          overallDiscountPercent: this.overallDiscountPercent,
          notes: this.notes,
        })
      );
    } catch (_) {}
  }

  private loadFromStorage() {
    try {
      const raw = localStorage.getItem('billwave_cart');
      if (raw) {
        const data = JSON.parse(raw);
        if (Array.isArray(data.items)) this.items = data.items;
        if (data.customer) this.customer = data.customer;
        if (typeof data.overallDiscountPercent === 'number') {
          this.overallDiscountPercent = data.overallDiscountPercent;
        }
        if (typeof data.notes === 'string') this.notes = data.notes;
      }
    } catch (_) {}
  }

  private notify() {
    this.saveToStorage();
    this.listeners.forEach((l) => l());
  }

  public subscribe(listener: () => void): () => void {
    this.listeners.push(listener);
    return () => {
      this.listeners = this.listeners.filter((l) => l !== listener);
    };
  }

  public getSnapshot() {
    const subtotal = this.items.reduce((sum, item) => sum + item.lineSubtotal, 0);
    const taxableTotal = this.items.reduce((sum, item) => sum + item.lineTaxable, 0);
    const taxTotal = this.items.reduce((sum, item) => sum + item.lineTax, 0);

    const overallDiscountAmount = taxableTotal * (this.overallDiscountPercent / 100);
    const finalTaxable = taxableTotal - overallDiscountAmount;
    const discountFactor = taxableTotal > 0 ? finalTaxable / taxableTotal : 1.0;
    const finalTax = taxTotal * discountFactor;
    const grandTotal = finalTaxable + finalTax;

    const rawTaxBreakdown: Record<string, number> = {};
    for (const item of this.items) {
      const key = `${item.taxRate.toFixed(0)}%`;
      rawTaxBreakdown[key] = (rawTaxBreakdown[key] || 0) + item.lineTax;
    }

    const taxBreakdown: Record<string, number> = {};
    for (const [rate, amt] of Object.entries(rawTaxBreakdown)) {
      taxBreakdown[rate] = amt * discountFactor;
    }

    return {
      items: [...this.items],
      customer: { ...this.customer },
      overallDiscountPercent: this.overallDiscountPercent,
      overallDiscountAmount,
      notes: this.notes,
      itemCount: this.items.length,
      totalQuantity: this.items.reduce((sum, item) => sum + item.quantity, 0),
      isEmpty: this.items.length === 0,
      subtotal,
      taxableTotal: finalTaxable,
      taxableAmount: finalTaxable,
      taxTotal: finalTax,
      tax: finalTax,
      grandTotal,
      total: grandTotal,
      taxBreakdown,
    };
  }

  public getProductQuantity(product: Product): number {
    for (const item of this.items) {
      if (
        (product.id && item.productId === product.id) ||
        item.name.trim().toLowerCase() === product.name.trim().toLowerCase()
      ) {
        return item.quantity;
      }
    }
    return 0;
  }

  private calculateItemLines(
    unitPrice: number,
    quantity: number,
    discountPercent: number,
    taxRate: number
  ) {
    const lineSubtotal = unitPrice * quantity;
    const lineDiscount = lineSubtotal * (discountPercent / 100);
    const lineTaxable = lineSubtotal - lineDiscount;
    const lineTax = lineTaxable * (taxRate / 100);
    const lineTotal = lineTaxable + lineTax;
    return { lineSubtotal, lineDiscount, lineTaxable, lineTax, lineTotal };
  }

  public addProduct(product: Product, quantity = 1): AddToCartResult {
    if (!product.name || product.name.trim() === '') {
      return { status: AddToCartStatus.InvalidData, message: 'Product name cannot be empty.', quantity: 0 };
    }
    if (product.price < 0) {
      return { status: AddToCartStatus.InvalidData, message: 'Price cannot be negative.', quantity: 0 };
    }
    if (quantity <= 0) {
      return { status: AddToCartStatus.InvalidData, message: 'Quantity must be at least 1.', quantity: 0 };
    }
    if (product.stock <= 0) {
      return { status: AddToCartStatus.OutOfStock, message: `"${product.name}" is currently out of stock.`, quantity: 0 };
    }

    const existingIndex = this.items.findIndex(
      (item) =>
        (product.id && item.productId === product.id) ||
        item.name.trim().toLowerCase() === product.name.trim().toLowerCase()
    );

    if (existingIndex >= 0) {
      const current = this.items[existingIndex];
      const newQty = current.quantity + quantity;

      if (newQty > product.stock) {
        return {
          status: AddToCartStatus.MaxStockReached,
          message: `Cannot add more "${product.name}". Max stock is ${product.stock} (already have ${current.quantity} in bill).`,
          quantity: current.quantity,
        };
      }

      const lines = this.calculateItemLines(current.unitPrice, newQty, current.discountPercent, current.taxRate);
      this.items[existingIndex] = {
        ...current,
        quantity: newQty,
        ...lines,
      };
      this.notify();
      return {
        status: AddToCartStatus.QuantityUpdated,
        message: `Updated "${product.name}" quantity to ${newQty}.`,
        quantity: newQty,
      };
    } else {
      if (quantity > product.stock) {
        return {
          status: AddToCartStatus.MaxStockReached,
          message: `Requested quantity (${quantity}) exceeds available stock of ${product.stock}.`,
          quantity: 0,
        };
      }

      const lines = this.calculateItemLines(product.price, quantity, 0, product.taxRate);
      this.items.push({
        productId: product.id || undefined,
        name: product.name.trim(),
        unitPrice: product.price,
        quantity,
        discountPercent: 0,
        taxRate: product.taxRate,
        ...lines,
      });
      this.notify();
      return {
        status: AddToCartStatus.Added,
        message: `Added "${product.name}" (×${quantity}) to bill.`,
        quantity,
      };
    }
  }

  public addCustomItem(item: Omit<InvoiceItem, 'lineSubtotal' | 'lineDiscount' | 'lineTaxable' | 'lineTax' | 'lineTotal'>) {
    const lines = this.calculateItemLines(item.unitPrice, item.quantity, item.discountPercent || 0, item.taxRate || 0);
    this.items.push({
      ...item,
      ...lines,
    });
    this.notify();
  }

  public updateQuantity(index: number, delta: number, maxStock?: number) {
    if (index < 0 || index >= this.items.length) return;
    const current = this.items[index];
    const newQty = current.quantity + delta;

    if (newQty <= 0) {
      this.items.splice(index, 1);
    } else {
      if (maxStock !== undefined && newQty > maxStock) return;
      const lines = this.calculateItemLines(current.unitPrice, newQty, current.discountPercent, current.taxRate);
      this.items[index] = { ...current, quantity: newQty, ...lines };
    }
    this.notify();
  }

  public setQuantity(index: number, newQty: number, maxStock?: number) {
    if (index < 0 || index >= this.items.length) return;
    if (newQty <= 0) {
      this.items.splice(index, 1);
    } else {
      const clamped = maxStock ? Math.min(newQty, maxStock) : newQty;
      const current = this.items[index];
      const lines = this.calculateItemLines(current.unitPrice, clamped, current.discountPercent, current.taxRate);
      this.items[index] = { ...current, quantity: clamped, ...lines };
    }
    this.notify();
  }

  public setItemDiscount(index: number, discountPercent: number) {
    if (index < 0 || index >= this.items.length) return;
    const clamped = Math.max(0, Math.min(100, discountPercent));
    const current = this.items[index];
    const lines = this.calculateItemLines(current.unitPrice, current.quantity, clamped, current.taxRate);
    this.items[index] = { ...current, discountPercent: clamped, ...lines };
    this.notify();
  }

  public removeItem(index: number) {
    if (index < 0 || index >= this.items.length) return;
    this.items.splice(index, 1);
    this.notify();
  }

  public clear() {
    this.items = [];
    this.customer = { name: '', phone: '', email: '' };
    this.overallDiscountPercent = 0;
    this.notes = '';
    this.notify();
  }

  public updateCustomer(details: Partial<CustomerDetails>) {
    this.customer = { ...this.customer, ...details };
    this.notify();
  }

  public updateNotes(notes: string) {
    this.notes = notes;
    this.notify();
  }

  public updateOverallDiscount(discount: number) {
    this.overallDiscountPercent = Math.max(0, Math.min(100, discount));
    this.notify();
  }
}

export const cartStore = CartStore.getInstance();

export function useCart() {
  const [snapshot, setSnapshot] = useState(cartStore.getSnapshot());

  useEffect(() => {
    return cartStore.subscribe(() => {
      setSnapshot(cartStore.getSnapshot());
    });
  }, []);

  return {
    ...snapshot,
    addProduct: (product: Product, quantity?: number) => cartStore.addProduct(product, quantity),
    addCustomItem: (item: any) => cartStore.addCustomItem(item),
    updateQuantity: (index: number, delta: number, maxStock?: number) =>
      cartStore.updateQuantity(index, delta, maxStock),
    setQuantity: (index: number, qty: number, maxStock?: number) =>
      cartStore.setQuantity(index, qty, maxStock),
    setItemDiscount: (index: number, disc: number) => cartStore.setItemDiscount(index, disc),
    removeItem: (index: number) => cartStore.removeItem(index),
    clear: () => cartStore.clear(),
    updateCustomer: (cust: Partial<CustomerDetails>) => cartStore.updateCustomer(cust),
    updateNotes: (n: string) => cartStore.updateNotes(n),
    updateOverallDiscount: (d: number) => cartStore.updateOverallDiscount(d),
    getProductQuantity: (product: Product) => cartStore.getProductQuantity(product),
  };
}

export function formatCurrency(amount: number, currency = '₹'): string {
  const safeAmount = Number.isFinite(amount) ? amount : 0;
  return `${currency}${safeAmount.toLocaleString('en-IN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

export function formatDate(dateString: string): string {
  try {
    const d = new Date(dateString);
    if (isNaN(d.getTime())) return dateString;
    return d.toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return dateString;
  }
}
