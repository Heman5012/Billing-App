export interface Product {
  id: string;
  name: string;
  sku: string;
  barcode: string;
  price: number;
  mrp?: number;
  costPrice?: number;
  stock: number;
  stockQuantity?: number;
  taxRate: number; // e.g. 5 for 5%
  category: string;
  brand: string;
  unit?: string;
  description?: string;
  imageUrl: string;
  createdAt?: string; // ISO string
  updatedAt?: string; // ISO string
}

export interface InvoiceItem {
  productId?: string;
  name: string;
  productName?: string;
  unitPrice: number;
  quantity: number;
  discount?: number;
  discountPercent: number; // e.g. 5 for 5%
  taxRate: number; // e.g. 18 for 18%
  lineSubtotal: number;
  lineDiscount: number;
  lineTaxable: number;
  lineTax: number;
  lineTotal: number;
  totalPrice?: number;
}

export interface CustomerDetails {
  name: string;
  phone: string;
  email?: string;
}

export interface BusinessProfile {
  name?: string;
  businessName: string;
  address: string;
  phone: string;
  email?: string;
  gstin?: string;
  terms?: string;
  currency: string;
  defaultTaxRate?: number;
  configuredTaxRates: number[];
}

export interface Invoice {
  id: string;
  invoiceNumber: string;
  userId?: string;
  customer: CustomerDetails;
  items: InvoiceItem[];
  subtotal: number;
  overallDiscountPercent: number;
  overallDiscountAmount: number;
  discountAmount?: number;
  taxableAmount: number;
  tax: number;
  taxAmount?: number;
  taxBreakdown: Record<string, number>;
  total: number;
  totalAmount?: number;
  paymentMethod: string; // "UPI", "Card", "Cash"
  paymentStatus: 'paid' | 'failed' | 'cancelled';
  status?: 'paid' | 'failed' | 'cancelled';
  cashReceived?: number;
  changeReturned?: number;
  transactionMode?: string;
  notes?: string;
  createdAt: string; // ISO string
  shareToken: string;
  cancellationReason?: string;
  cancelReason?: string;
  cancelledAt?: string;
  business?: BusinessProfile;
}

export interface DashboardStats {
  todaySales: number;
  totalInvoices: number;
  totalProducts: number;
  avgInvoiceValue: number;
  recentInvoices: Invoice[];
  last7DaysSales: Record<string, number>;
  lowStockProducts: Product[];
  topSellingProducts: { name: string; quantity: number }[];
}

export enum AddToCartStatus {
  Added = 'added',
  QuantityUpdated = 'quantityUpdated',
  OutOfStock = 'outOfStock',
  MaxStockReached = 'maxStockReached',
  InvalidData = 'invalidData',
}

export interface AddToCartResult {
  status: AddToCartStatus;
  message: string;
  quantity: number;
}
