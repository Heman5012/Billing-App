# BillWave — Smart Billing & Invoice Management (React)

BillWave is a modern, high-speed Point-of-Sale (POS) and retail invoice management web application built with **React 18**, **TypeScript**, **Tailwind CSS**, and **Vite**.

Originally imported from Flutter, this application has been completely rewritten as a responsive web app while preserving all core business logic, retail workflows, and financial calculations.

---

## 🌟 Key Features

### 1. Real-Time POS Billing & Cart Management
- **Barcode & Optical Recognition**: Fast product lookup with camera scanner, optical recognition matching the 10-product poster, and manual barcode entry.
- **Dynamic Cart**: Real-time quantity adjustments, per-item discounts, overall invoice percentage or flat discounts.
- **GST / Tax Engine**: Full support for standard Indian GST slabs (0%, 5%, 12%, 18%, 28%) with accurate tax-inclusive/tax-exclusive breakdown and roundoff.
- **Customer Tagging**: Quick association with customer name and phone number for digital invoicing and return tracking.

### 2. Multi-Channel Payment Processing
- **Simulated Instant Payment Flow**: Seamless checkout supporting **Cash** (with automated change computation), **UPI** (interactive QR code and simulated PSP apps like Google Pay, PhonePe, Paytm), and **Debit/Credit Card**.
- **Atomic Stock Management**: Inventory counts decrement immediately upon payment completion and automatically restore upon invoice cancellation.

### 3. Smart Tax Invoices & Verification
- **Verifiable Digital Invoices**: Every invoice is assigned a unique invoice number and cryptographic ID encoded into a scannable QR code.
- **Public Receipt Verification**: Customers can scan the QR code to open the digital receipt (`/?token=...`) with authentic store signature.
- **Thermal & Letter Printing**: Optimized `@media print` layouts supporting standard 80mm/58mm thermal POS roll printers and A4 tax invoices.

### 4. Product Catalog & Inventory
- **10 Seed FMCG Products**: Preloaded with high-fidelity product imagery (Soap, Shampoo, Toothpaste, Biscuits, Rice, Oil, Chocolate, Detergent, Water, Coffee).
- **CRUD Operations**: Add, edit, filter, search, and manage products, unit measures, categories, MRP, cost price, selling price, and stock levels.
- **Low Stock Alerts**: Real-time indicators highlighting products running low (≤ 10 units).

### 5. Sales Analytics & Audit History
- **Financial Analytics**: Real-time calculation of Gross Revenue, Average Order Value (AOV), Net GST liability, and payment method distribution.
- **Transaction History**: Searchable and filterable invoice ledger with audit status, one-click cancellation dialog with reason capture.

---

## 🚀 Getting Started

### Development
```bash
npm install
npm run dev
```
The application runs on `http://localhost:3000`.

### Build
```bash
npm run build
```

---

## 🛠️ Tech Stack
- **Framework**: React 18, TypeScript, Vite
- **Styling**: Tailwind CSS v4
- **Icons**: Lucide React
- **Barcode & QR Generation**: JsBarcode, qrcode.react
- **Data & Auth**: Firebase Firestore & Auth integration with resilient LocalStorage offline mirror
