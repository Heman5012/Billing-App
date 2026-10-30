/**
 * BillWave — One-time Firestore product seed script
 *
 * Inserts 10 sample FMCG products into Cloud Firestore.
 * Uses each product's barcode string as the Firestore document ID.
 * Running this script multiple times is safe: existing documents are skipped.
 *
 * Usage:
 *   1. Install the Firebase Admin SDK:
 *        npm install firebase-admin
 *
 *   2. Download your service account key from:
 *        Firebase Console → Project Settings → Service Accounts → Generate new private key
 *      Save it as  scripts/serviceAccountKey.json  (never commit this file to git)
 *
 *   3. Run from the project root:
 *        GOOGLE_APPLICATION_CREDENTIALS=scripts/serviceAccountKey.json node scripts/seed_products.js
 *
 *      Or on Windows (PowerShell):
 *        $env:GOOGLE_APPLICATION_CREDENTIALS="scripts/serviceAccountKey.json"; node scripts/seed_products.js
 *
 * NOTE: These are sample educational records for demo/testing purposes.
 *       Barcodes are not guaranteed to match real-world manufacturer data.
 */

'use strict';

const admin = require('firebase-admin');

// Initialize the Admin SDK using the service account key set in the environment variable
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

const PRODUCTS = [
  {
    barcode: '8901030895458',
    name: 'Soap',
    brand: 'Lifebuoy',
    category: 'Personal Care',
    price: 40,
    taxRate: 5,
    stock: 50,
  },
  {
    barcode: '8901491101205',
    name: 'Shampoo',
    brand: 'Head & Shoulders',
    category: 'Personal Care',
    price: 120,
    taxRate: 18,
    stock: 30,
  },
  {
    barcode: '8901719100012',
    name: 'Toothpaste',
    brand: 'Colgate',
    category: 'Personal Care',
    price: 65,
    taxRate: 18,
    stock: 40,
  },
  {
    barcode: '8901725000018',
    name: 'Biscuits',
    brand: 'Good Day',
    category: 'Snacks',
    price: 30,
    taxRate: 5,
    stock: 100,
  },
  {
    barcode: '8901063012345',
    name: 'Rice 1 kg',
    brand: 'Tata Sampann',
    category: 'Grocery',
    price: 75,
    taxRate: 5,
    stock: 60,
  },
  {
    barcode: '8901764012340',
    name: 'Cooking Oil 1 L',
    brand: 'Fortune',
    category: 'Grocery',
    price: 150,
    taxRate: 5,
    stock: 25,
  },
  {
    barcode: '8901571001234',
    name: 'Chocolate',
    brand: 'Dairy Milk',
    category: 'Snacks',
    price: 50,
    taxRate: 18,
    stock: 40,
  },
  {
    barcode: '8901030123456',
    name: 'Detergent',
    brand: 'Surf Excel',
    category: 'Household',
    price: 110,
    taxRate: 18,
    stock: 35,
  },
  {
    barcode: '8901058001234',
    name: 'Bottled Water',
    brand: 'Bisleri',
    category: 'Beverages',
    price: 20,
    taxRate: 0,
    stock: 80,
  },
  {
    barcode: '8901725901234',
    name: 'Coffee Powder',
    brand: 'Nescafe',
    category: 'Beverages',
    price: 95,
    taxRate: 5,
    stock: 20,
  },
];

async function seedProducts() {
  const now = admin.firestore.FieldValue.serverTimestamp();
  let addedCount = 0;
  let skippedCount = 0;

  console.log(`\nSeeding ${PRODUCTS.length} products into Firestore users collection...\n`);

  // NOTE: The app currently stores products under users/{uid}/products/{barcode}.
  // This script seeds products for a specific user UID.
  // Replace the UID below with the actual Firebase Auth UID of the user/store owner.
  //
  // To find your UID: Firebase Console → Authentication → Users → copy the User UID.
  const USER_UID = process.env.USER_UID;

  if (!USER_UID) {
    console.error('ERROR: USER_UID environment variable is not set.');
    console.error('Run as: USER_UID=your-firebase-uid GOOGLE_APPLICATION_CREDENTIALS=scripts/serviceAccountKey.json node scripts/seed_products.js');
    process.exit(1);
  }

  const productsCol = db.collection('users').doc(USER_UID).collection('products');

  for (const item of PRODUCTS) {
    const docRef = productsCol.doc(item.barcode);
    const snap = await docRef.get();

    if (snap.exists) {
      console.log(`  SKIPPED  ${item.barcode}  ${item.name}  (already exists)`);
      skippedCount++;
      continue;
    }

    const sku = `SKU-${item.barcode.slice(-6)}`;
    await docRef.set({
      barcode: item.barcode,
      name: item.name,
      brand: item.brand,
      category: item.category,
      price: item.price,
      taxRate: item.taxRate,
      stock: item.stock,
      sku: sku,
      imageUrl: '',
      createdAt: now,
      updatedAt: now,
    });

    console.log(`  ADDED    ${item.barcode}  ${item.name}`);
    addedCount++;
  }

  console.log(`\nDone. Added: ${addedCount}  |  Skipped: ${skippedCount}\n`);
  process.exit(0);
}

seedProducts().catch((err) => {
  console.error('\nSeed script failed:', err.message);
  process.exit(1);
});

