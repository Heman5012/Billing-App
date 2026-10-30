import { initializeApp, getApps, getApp, FirebaseApp } from 'firebase/app';
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
  User as FirebaseUser,
  updateProfile,
} from 'firebase/auth';
import {
  getFirestore,
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  query,
  orderBy,
  where,
  limit,
  onSnapshot,
  getDocFromServer,
} from 'firebase/firestore';
import appletConfig from '../../firebase-applet-config.json';
import { Product, Invoice, BusinessProfile, DashboardStats } from '../types';
import { INITIAL_PRODUCTS, POSTER_MOCKUP_ALIASES } from './seedData';

// Config from provisioned Firebase project billing-and-invoice-fe416
export const firebaseConfig = {
  apiKey: appletConfig.apiKey || 'AIzaSyCqlPIdZ4BKPgSfmREbuAjG-gqXexxa5RU',
  authDomain: appletConfig.authDomain || 'billing-and-invoice-fe416.firebaseapp.com',
  projectId: appletConfig.projectId || 'billing-and-invoice-fe416',
  storageBucket: appletConfig.storageBucket || 'billing-and-invoice-fe416.firebasestorage.app',
  messagingSenderId: appletConfig.messagingSenderId || '993029568453',
  appId: appletConfig.appId || '1:993029568453:web:055941860e5aa307083dac',
  firestoreDatabaseId: appletConfig.firestoreDatabaseId || 'ai-studio-billingapp-19180143-98e2-4cf8-ab2b-4f8a581ba1fd',
  measurementId: appletConfig.measurementId || '',
};

let app: FirebaseApp | null = null;
try {
  app = !getApps().length ? initializeApp(firebaseConfig) : getApp();
} catch (e) {
  console.warn('Firebase init warning:', e);
}

export const auth = app ? getAuth(app) : null;
export const db = app
  ? (firebaseConfig.firestoreDatabaseId
      ? getFirestore(app, firebaseConfig.firestoreDatabaseId)
      : getFirestore(app))
  : null;

// Validate initial Firestore server connectivity
if (db) {
  (async () => {
    try {
      await getDocFromServer(doc(db, 'test', 'connection'));
    } catch (error: any) {
      if (error instanceof Error && error.message.includes('the client is offline')) {
        console.error('Please check your Firebase configuration.');
      }
    }
  })();
}

// Local storage keys for resilient offline / demo mode
const STORAGE_PREFIX = 'billwave_';
const STORAGE_KEYS = {
  PRODUCTS: `${STORAGE_PREFIX}products`,
  INVOICES: `${STORAGE_PREFIX}invoices`,
  SETTINGS: `${STORAGE_PREFIX}settings`,
  USER: `${STORAGE_PREFIX}user`,
};

export interface LocalUser {
  uid: string;
  email: string | null;
  displayName: string | null;
  photoURL: string | null;
  isDemo?: boolean;
}

class FirebaseService {
  private static instance: FirebaseService;
  private currentUser: LocalUser | null = null;
  private authListeners: ((user: LocalUser | null) => void)[] = [];
  private productListeners: ((products: Product[]) => void)[] = [];
  private invoiceListeners: ((invoices: Invoice[]) => void)[] = [];
  private profileListeners: ((profile: BusinessProfile) => void)[] = [];

  private constructor() {
    this.initAuth();
  }

  public static getInstance(): FirebaseService {
    if (!FirebaseService.instance) {
      FirebaseService.instance = new FirebaseService();
    }
    return FirebaseService.instance;
  }

  private initAuth() {
    // Check cached demo user
    const savedUser = localStorage.getItem(STORAGE_KEYS.USER);
    if (savedUser) {
      try {
        this.currentUser = JSON.parse(savedUser);
      } catch (_) {}
    }

    if (auth) {
      onAuthStateChanged(auth, (fbUser) => {
        if (fbUser) {
          this.currentUser = {
            uid: fbUser.uid,
            email: fbUser.email,
            displayName: fbUser.displayName || 'Merchant',
            photoURL: fbUser.photoURL,
            isDemo: false,
          };
          localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(this.currentUser));
        } else if (!this.currentUser?.isDemo) {
          this.currentUser = null;
          localStorage.removeItem(STORAGE_KEYS.USER);
        }
        this.notifyAuthListeners();
      });
    }
  }

  public onAuthChanged(callback: (user: LocalUser | null) => void) {
    this.authListeners.push(callback);
    callback(this.currentUser);
    return () => {
      this.authListeners = this.authListeners.filter((l) => l !== callback);
    };
  }

  public onAuthStateChanged(callback: (user: LocalUser | null) => void) {
    return this.onAuthChanged(callback);
  }

  private notifyAuthListeners() {
    this.authListeners.forEach((l) => l(this.currentUser));
  }

  public getCurrentUser(): LocalUser | null {
    return this.currentUser;
  }

  // --- AUTH METHODS ---

  public async signInWithGoogle(): Promise<LocalUser> {
    if (!auth) throw new Error('Firebase Auth not available');
    const provider = new GoogleAuthProvider();
    try {
      const result = await signInWithPopup(auth, provider);
      const fbUser = result.user;
      this.currentUser = {
        uid: fbUser.uid,
        email: fbUser.email,
        displayName: fbUser.displayName || 'Store Merchant',
        photoURL: fbUser.photoURL,
        isDemo: false,
      };
      localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(this.currentUser));
      this.notifyAuthListeners();
      return this.currentUser;
    } catch (err: any) {
      if (err?.code === 'auth/unauthorized-domain' || (err?.message && err.message.includes('unauthorized-domain'))) {
        const domain = typeof window !== 'undefined' ? window.location.hostname : '';
        const customErr: any = new Error(
          `Domain "${domain}" is not authorized in Firebase Authentication.`
        );
        customErr.code = 'auth/unauthorized-domain';
        customErr.hostname = domain;
        customErr.projectId = firebaseConfig.projectId;
        customErr.originalError = err;
        throw customErr;
      }
      throw err;
    }
  }

  public async signInWithEmail(email: string, pass: string): Promise<LocalUser> {
    if (!auth) throw new Error('Firebase Auth not available');
    const result = await signInWithEmailAndPassword(auth, email, pass);
    const fbUser = result.user;
    this.currentUser = {
      uid: fbUser.uid,
      email: fbUser.email,
      displayName: fbUser.displayName || email.split('@')[0],
      photoURL: fbUser.photoURL,
      isDemo: false,
    };
    localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(this.currentUser));
    this.notifyAuthListeners();
    return this.currentUser;
  }

  public async signUpWithEmail(email: string, pass: string, name?: string): Promise<LocalUser> {
    if (!auth) throw new Error('Firebase Auth not available');
    const result = await createUserWithEmailAndPassword(auth, email, pass);
    const fbUser = result.user;
    if (name) {
      await updateProfile(fbUser, { displayName: name });
    }
    this.currentUser = {
      uid: fbUser.uid,
      email: fbUser.email,
      displayName: name || email.split('@')[0],
      photoURL: fbUser.photoURL,
      isDemo: false,
    };
    localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(this.currentUser));
    this.notifyAuthListeners();
    return this.currentUser;
  }

  public async signInDemo(): Promise<LocalUser> {
    const demoUser: LocalUser = {
      uid: 'demo_merchant_billwave',
      email: 'demo.store@billwave.app',
      displayName: 'Demo Store Merchant',
      photoURL: null,
      isDemo: true,
    };
    this.currentUser = demoUser;
    localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(demoUser));
    this.notifyAuthListeners();
    // Ensure initial products exist for demo user
    this.getLocalProducts();
    return demoUser;
  }

  public async signOutUser(): Promise<void> {
    if (auth && !this.currentUser?.isDemo) {
      try {
        await signOut(auth);
      } catch (_) {}
    }
    this.currentUser = null;
    localStorage.removeItem(STORAGE_KEYS.USER);
    this.notifyAuthListeners();
  }

  // --- PRODUCTS DATA METHODS ---

  public getLocalProducts(): Product[] {
    const raw = localStorage.getItem(STORAGE_KEYS.PRODUCTS);
    if (!raw) {
      localStorage.setItem(STORAGE_KEYS.PRODUCTS, JSON.stringify(INITIAL_PRODUCTS));
      return INITIAL_PRODUCTS;
    }
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed) && parsed.length > 0) return parsed;
      localStorage.setItem(STORAGE_KEYS.PRODUCTS, JSON.stringify(INITIAL_PRODUCTS));
      return INITIAL_PRODUCTS;
    } catch (_) {
      return INITIAL_PRODUCTS;
    }
  }

  public async getProducts(): Promise<Product[]> {
    const local = this.getLocalProducts();
    if (!db || !this.currentUser || this.currentUser.isDemo) {
      return local;
    }
    try {
      const colRef = collection(db, 'users', this.currentUser.uid, 'products');
      const snap = await getDocs(colRef);
      if (snap.empty) {
        // Fallback or seed
        return local;
      }
      const remote = snap.docs.map((d) => ({ id: d.id, ...d.data() } as Product));
      // Merge with local products
      const map = new Map<string, Product>();
      local.forEach((p) => map.set(p.barcode || p.id, p));
      remote.forEach((p) => map.set(p.barcode || p.id, p));
      const merged = Array.from(map.values());
      localStorage.setItem(STORAGE_KEYS.PRODUCTS, JSON.stringify(merged));
      return merged;
    } catch (err) {
      console.warn('Firestore fetch products failed, using local:', err);
      return local;
    }
  }

  public streamProducts(callback: (products: Product[]) => void) {
    this.productListeners.push(callback);
    // Send immediate local snapshot
    callback(this.getLocalProducts());

    // Try firestore snapshot if online
    if (db && this.currentUser && !this.currentUser.isDemo) {
      try {
        const colRef = collection(db, 'users', this.currentUser.uid, 'products');
        const unsub = onSnapshot(
          colRef,
          (snap) => {
            if (!snap.empty) {
              const remote = snap.docs.map((d) => ({ id: d.id, ...d.data() } as Product));
              const map = new Map<string, Product>();
              this.getLocalProducts().forEach((p) => map.set(p.barcode || p.id, p));
              remote.forEach((p) => map.set(p.barcode || p.id, p));
              const merged = Array.from(map.values()).sort((a, b) => a.name.localeCompare(b.name));
              localStorage.setItem(STORAGE_KEYS.PRODUCTS, JSON.stringify(merged));
              callback(merged);
            }
          },
          (err) => {
            console.warn('Products onSnapshot error, retaining local:', err);
          }
        );
        return () => {
          unsub();
          this.productListeners = this.productListeners.filter((l) => l !== callback);
        };
      } catch (_) {}
    }

    return () => {
      this.productListeners = this.productListeners.filter((l) => l !== callback);
    };
  }

  public async findProductByBarcode(barcode: string): Promise<Product | null> {
    const clean = barcode.trim();
    if (!clean) return null;

    const products = this.getLocalProducts();
    const candidateSet = new Set<string>([clean]);

    if (POSTER_MOCKUP_ALIASES[clean]) {
      candidateSet.add(POSTER_MOCKUP_ALIASES[clean]);
    }
    if (clean.startsWith('0') && clean.length > 1) {
      candidateSet.add(clean.replace(/^0+/, ''));
    } else if (clean.length === 12) {
      candidateSet.add(`0${clean}`);
    }

    for (const p of products) {
      const pBar = (p.barcode || '').trim();
      const pId = (p.id || '').trim();
      const pSku = (p.sku || '').trim();

      if (candidateSet.has(pBar) || candidateSet.has(pId) || candidateSet.has(pSku)) {
        return p;
      }
      // Optical fuzzy check (max 2 digit flips for screen scanning)
      if (pBar.length === clean.length && clean.length >= 8) {
        let diffs = 0;
        for (let i = 0; i < clean.length; i++) {
          if (clean[i] !== pBar[i]) diffs++;
        }
        if (diffs <= 2) return p;
      }
    }
    return null;
  }

  public async saveProduct(product: Product): Promise<void> {
    const products = this.getLocalProducts();
    const now = new Date().toISOString();
    const id = product.id || product.barcode || `prod_${Date.now()}`;
    const toSave: Product = {
      ...product,
      id,
      updatedAt: now,
      createdAt: product.createdAt || now,
    };

    const index = products.findIndex((p) => p.id === id || (p.barcode && p.barcode === product.barcode));
    if (index >= 0) {
      products[index] = toSave;
    } else {
      products.push(toSave);
    }
    localStorage.setItem(STORAGE_KEYS.PRODUCTS, JSON.stringify(products));
    this.productListeners.forEach((l) => l([...products]));

    // Sync to Firestore if authenticated
    if (db && this.currentUser && !this.currentUser.isDemo) {
      try {
        const docRef = doc(db, 'users', this.currentUser.uid, 'products', id);
        await setDoc(docRef, toSave, { merge: true });
        // Also save to root products
        await setDoc(doc(db, 'products', id), toSave, { merge: true });
      } catch (e) {
        console.warn('Sync product to Firestore error:', e);
      }
    }
  }

  public async deleteProduct(productId: string): Promise<void> {
    let products = this.getLocalProducts();
    products = products.filter((p) => p.id !== productId && p.barcode !== productId);
    localStorage.setItem(STORAGE_KEYS.PRODUCTS, JSON.stringify(products));
    this.productListeners.forEach((l) => l([...products]));

    if (db && this.currentUser && !this.currentUser.isDemo) {
      try {
        await deleteDoc(doc(db, 'users', this.currentUser.uid, 'products', productId));
        await deleteDoc(doc(db, 'products', productId));
      } catch (e) {
        console.warn('Delete product from Firestore error:', e);
      }
    }
  }

  public async saveProducts(products: Product[]): Promise<void> {
    localStorage.setItem(STORAGE_KEYS.PRODUCTS, JSON.stringify(products));
    this.productListeners.forEach((l) => l([...products]));
  }

  public async resetToSeedProducts(): Promise<Product[]> {
    localStorage.setItem(STORAGE_KEYS.PRODUCTS, JSON.stringify(INITIAL_PRODUCTS));
    this.productListeners.forEach((l) => l([...INITIAL_PRODUCTS]));
    return INITIAL_PRODUCTS;
  }

  // --- INVOICES DATA METHODS ---

  public getLocalInvoices(): Invoice[] {
    const raw = localStorage.getItem(STORAGE_KEYS.INVOICES);
    if (!raw) return [];
    try {
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed : [];
    } catch (_) {
      return [];
    }
  }

  public streamInvoices(callback: (invoices: Invoice[]) => void) {
    this.invoiceListeners.push(callback);
    callback(this.getLocalInvoices());

    if (db && this.currentUser && !this.currentUser.isDemo) {
      try {
        const colRef = collection(db, 'users', this.currentUser.uid, 'invoices');
        const q = query(colRef, orderBy('createdAt', 'desc'));
        const unsub = onSnapshot(
          q,
          (snap) => {
            if (!snap.empty) {
              const remote = snap.docs.map((d) => ({ id: d.id, ...d.data() } as Invoice));
              localStorage.setItem(STORAGE_KEYS.INVOICES, JSON.stringify(remote));
              callback(remote);
            }
          },
          (err) => console.warn('Invoices onSnapshot error:', err)
        );
        return () => {
          unsub();
          this.invoiceListeners = this.invoiceListeners.filter((l) => l !== callback);
        };
      } catch (_) {}
    }

    return () => {
      this.invoiceListeners = this.invoiceListeners.filter((l) => l !== callback);
    };
  }

  public async createInvoice(invoice: Invoice): Promise<Invoice> {
    // 1. Decrement product stock in inventory
    const products = this.getLocalProducts();
    for (const item of invoice.items) {
      if (item.productId) {
        const prodIndex = products.findIndex((p) => p.id === item.productId || p.barcode === item.productId);
        if (prodIndex >= 0) {
          const currentStock = products[prodIndex].stock;
          products[prodIndex].stock = Math.max(0, currentStock - item.quantity);
          products[prodIndex].updatedAt = new Date().toISOString();
        }
      }
    }
    localStorage.setItem(STORAGE_KEYS.PRODUCTS, JSON.stringify(products));
    this.productListeners.forEach((l) => l([...products]));

    // 2. Save invoice locally
    const invoices = this.getLocalInvoices();
    invoices.unshift(invoice);
    localStorage.setItem(STORAGE_KEYS.INVOICES, JSON.stringify(invoices));
    this.invoiceListeners.forEach((l) => l([...invoices]));

    // 3. Save to public invoices cache so QR code / direct link lookup works
    const publicInvoices = this.getPublicInvoicesMap();
    publicInvoices[invoice.shareToken] = invoice;
    publicInvoices[invoice.invoiceNumber.toUpperCase()] = invoice;
    localStorage.setItem(`${STORAGE_PREFIX}public_invoices`, JSON.stringify(publicInvoices));

    // 4. If Firestore available, save remotely
    if (db && this.currentUser && !this.currentUser.isDemo) {
      try {
        await setDoc(doc(db, 'users', this.currentUser.uid, 'invoices', invoice.id), invoice);
        await setDoc(doc(db, 'public_invoices', invoice.shareToken), invoice);
      } catch (e) {
        console.warn('Sync invoice to Firestore error:', e);
      }
    }

    return invoice;
  }

  public async cancelInvoice(invoiceId: string, reason: string): Promise<void> {
    const invoices = this.getLocalInvoices();
    const index = invoices.findIndex((i) => i.id === invoiceId);
    if (index >= 0) {
      invoices[index].paymentStatus = 'cancelled';
      invoices[index].cancellationReason = reason;
      invoices[index].cancelledAt = new Date().toISOString();
      localStorage.setItem(STORAGE_KEYS.INVOICES, JSON.stringify(invoices));
      this.invoiceListeners.forEach((l) => l([...invoices]));

      // update public cache
      const token = invoices[index].shareToken;
      const publicInvoices = this.getPublicInvoicesMap();
      if (publicInvoices[token]) {
        publicInvoices[token].paymentStatus = 'cancelled';
        publicInvoices[token].cancellationReason = reason;
      }
      localStorage.setItem(`${STORAGE_PREFIX}public_invoices`, JSON.stringify(publicInvoices));

      // sync to firestore
      if (db && this.currentUser && !this.currentUser.isDemo) {
        try {
          await updateDoc(doc(db, 'users', this.currentUser.uid, 'invoices', invoiceId), {
            paymentStatus: 'cancelled',
            cancellationReason: reason,
            cancelledAt: new Date(),
          });
          if (token) {
            await updateDoc(doc(db, 'public_invoices', token), {
              paymentStatus: 'cancelled',
              cancellationReason: reason,
            });
          }
        } catch (_) {}
      }
    }
  }

  private getPublicInvoicesMap(): Record<string, Invoice> {
    const raw = localStorage.getItem(`${STORAGE_PREFIX}public_invoices`);
    if (!raw) return {};
    try {
      return JSON.parse(raw);
    } catch (_) {
      return {};
    }
  }

  public async getPublicInvoice(tokenOrInv: string): Promise<Invoice | null> {
    const clean = tokenOrInv.trim();
    if (!clean) return null;

    // 1. Check local public invoices cache
    const publicMap = this.getPublicInvoicesMap();
    if (publicMap[clean]) return publicMap[clean];
    if (publicMap[clean.toUpperCase()]) return publicMap[clean.toUpperCase()];

    // 2. Check local user invoices
    const local = this.getLocalInvoices();
    const found = local.find(
      (inv) => inv.shareToken === clean || inv.invoiceNumber.toUpperCase() === clean.toUpperCase() || inv.id === clean
    );
    if (found) return found;

    // 3. Check Firestore public_invoices
    if (db) {
      try {
        const docSnap = await getDoc(doc(db, 'public_invoices', clean));
        if (docSnap.exists()) {
          return { id: docSnap.id, ...docSnap.data() } as Invoice;
        }
        // search by invoiceNumber
        const q = query(collection(db, 'public_invoices'), where('invoiceNumber', '==', clean.toUpperCase()), limit(1));
        const qSnap = await getDocs(q);
        if (!qSnap.empty) {
          return { id: qSnap.docs[0].id, ...qSnap.docs[0].data() } as Invoice;
        }
      } catch (_) {}
    }

    return null;
  }

  // --- BUSINESS SETTINGS ---

  public getLocalBusinessProfile(): BusinessProfile {
    const raw = localStorage.getItem(STORAGE_KEYS.SETTINGS);
    const defaults: BusinessProfile = {
      businessName: 'BillWave Enterprise',
      address: '100 Tech Hub Avenue, Suite 400',
      phone: '+91 98765 43210',
      currency: '₹',
      configuredTaxRates: [0.0, 5.0, 12.0, 18.0, 28.0],
    };
    if (!raw) return defaults;
    try {
      return { ...defaults, ...JSON.parse(raw) };
    } catch (_) {
      return defaults;
    }
  }

  public streamBusinessProfile(callback: (profile: BusinessProfile) => void) {
    this.profileListeners.push(callback);
    callback(this.getLocalBusinessProfile());

    if (db && this.currentUser && !this.currentUser.isDemo) {
      try {
        const docRef = doc(db, 'users', this.currentUser.uid, 'settings', 'business');
        const unsub = onSnapshot(docRef, (snap) => {
          if (snap.exists()) {
            const data = snap.data() as BusinessProfile;
            localStorage.setItem(STORAGE_KEYS.SETTINGS, JSON.stringify(data));
            callback(data);
          }
        });
        return () => {
          unsub();
          this.profileListeners = this.profileListeners.filter((l) => l !== callback);
        };
      } catch (_) {}
    }

    return () => {
      this.profileListeners = this.profileListeners.filter((l) => l !== callback);
    };
  }

  public async saveBusinessProfile(profile: BusinessProfile): Promise<void> {
    localStorage.setItem(STORAGE_KEYS.SETTINGS, JSON.stringify(profile));
    this.profileListeners.forEach((l) => l(profile));

    if (db && this.currentUser && !this.currentUser.isDemo) {
      try {
        const docRef = doc(db, 'users', this.currentUser.uid, 'settings', 'business');
        await setDoc(docRef, profile, { merge: true });
      } catch (e) {
        console.warn('Sync profile to Firestore error:', e);
      }
    }
  }

  // --- STATS AGGREGATION ---

  public getDashboardStats(): DashboardStats {
    const invoices = this.getLocalInvoices();
    const products = this.getLocalProducts();
    const paid = invoices.filter((i) => i.paymentStatus === 'paid');

    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();

    let todaySales = 0;
    let totalSales = 0;
    const last7DaysMap: Record<string, number> = {};
    const productCounts: Record<string, number> = {};

    // initialize 7 days
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
      const key = `${d.getDate()}/${d.getMonth() + 1}`;
      last7DaysMap[key] = 0;
    }

    for (const inv of paid) {
      const invTime = new Date(inv.createdAt).getTime();
      totalSales += inv.total;

      if (invTime >= todayStart) {
        todaySales += inv.total;
      }

      const diffDays = Math.floor((now.getTime() - invTime) / (24 * 60 * 60 * 1000));
      if (diffDays >= 0 && diffDays < 7) {
        const d = new Date(invTime);
        const key = `${d.getDate()}/${d.getMonth() + 1}`;
        if (last7DaysMap[key] !== undefined) {
          last7DaysMap[key] += inv.total;
        }
      }

      for (const item of inv.items) {
        productCounts[item.name] = (productCounts[item.name] || 0) + item.quantity;
      }
    }

    const avgInvoiceValue = paid.length > 0 ? totalSales / paid.length : 0;
    const lowStockProducts = products.filter((p) => p.stock <= 5);

    const sortedProducts = Object.entries(productCounts)
      .map(([name, quantity]) => ({ name, quantity }))
      .sort((a, b) => b.quantity - a.quantity);

    return {
      todaySales,
      totalInvoices: paid.length,
      totalProducts: products.length,
      avgInvoiceValue,
      recentInvoices: invoices.slice(0, 5),
      last7DaysSales: last7DaysMap,
      lowStockProducts,
      topSellingProducts: sortedProducts.slice(0, 5),
    };
  }
}

export const firebaseService = FirebaseService.getInstance();

export const signInWithGoogle = () => firebaseService.signInWithGoogle();
export const signInWithEmail = (e: string, p: string) => firebaseService.signInWithEmail(e, p);
export const signUpWithEmail = (e: string, p: string, n?: string) => firebaseService.signUpWithEmail(e, p, n);
export const startDemoSession = () => firebaseService.signInDemo();
export const signOutUser = () => firebaseService.signOutUser();
export const onAuthChange = (cb: (user: any) => void) => firebaseService.onAuthStateChanged(cb);
export const getStoredProducts = () => firebaseService.getLocalProducts();
export const saveProducts = (prods: Product[]) => firebaseService.saveProducts(prods);
export const getStoredInvoices = () => firebaseService.getLocalInvoices();
export const saveInvoice = (inv: Invoice) => firebaseService.createInvoice(inv);
export const cancelStoredInvoice = (id: string, reason: string) => firebaseService.cancelInvoice(id, reason);
export const getStoredBusinessProfile = () => firebaseService.getLocalBusinessProfile();
export const saveBusinessProfile = (profile: BusinessProfile) => firebaseService.saveBusinessProfile(profile);
export const resetToSeedProducts = () => firebaseService.resetToSeedProducts();
export const getInvoiceByToken = (token: string) => firebaseService.getPublicInvoice(token);
