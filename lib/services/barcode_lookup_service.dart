import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/product.dart';
import 'firebase_service.dart';

class BarcodeLookupResult {
  final String barcode;
  final String? name;
  final String? brand;
  final String? category;
  final String? imageUrl;
  final bool foundInFirestore;
  final bool foundInOpenFoodFacts;
  final Product? existingProduct;
  final String? errorMessage;
  final bool isRateLimited;

  const BarcodeLookupResult({
    required this.barcode,
    this.name,
    this.brand,
    this.category,
    this.imageUrl,
    this.foundInFirestore = false,
    this.foundInOpenFoodFacts = false,
    this.existingProduct,
    this.errorMessage,
    this.isRateLimited = false,
  });

  bool get hasDetails =>
      (name != null && name!.isNotEmpty) ||
      (brand != null && brand!.isNotEmpty) ||
      (category != null && category!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);
}

class BarcodeLookupService {
  BarcodeLookupService._();
  static final BarcodeLookupService instance = BarcodeLookupService._();

  /// Required by Open Food Facts ToS: descriptive User-Agent with app, platform, and contact
  static const String _userAgent =
      'BillWave - Flutter/Retail - Version 1.0 - contact@billwave.app';

  /// Normalizes a barcode string by trimming whitespace and control characters.
  static String normalizeBarcode(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), '');
  }

  /// Basic format validation for barcodes (EAN-13, EAN-8, UPC-A, UPC-E, Code 128, etc.)
  static bool isValidBarcode(String code) {
    final clean = normalizeBarcode(code);
    if (clean.length < 3 || clean.length > 64) return false;
    // Allow standard alphanumeric barcodes without control chars
    return RegExp(r'^[a-zA-Z0-9\-_]+$').hasMatch(clean);
  }

  /// Looks up a barcode: checks Firestore inventory first, then falls back to Open Food Facts API.
  Future<BarcodeLookupResult> lookup(
    String uid,
    String rawBarcode, {
    http.Client? client,
  }) async {
    final normalized = normalizeBarcode(rawBarcode);
    if (!isValidBarcode(normalized)) {
      return BarcodeLookupResult(
        barcode: normalized,
        errorMessage: 'Invalid barcode format.',
      );
    }

    // 1. Search local Firestore product collection first
    try {
      final existing = await FirebaseService.instance.findProductByBarcode(
        uid,
        normalized,
      );
      if (existing != null) {
        return BarcodeLookupResult(
          barcode: normalized,
          name: existing.name,
          brand: existing.brand,
          category: existing.category,
          imageUrl: existing.imageUrl,
          foundInFirestore: true,
          existingProduct: existing,
        );
      }
    } catch (e) {
      debugPrint('[BarcodeLookup] Firestore lookup failed: $e');
    }

    // 2. Query Open Food Facts product API
    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$normalized.json',
      );

      final response = await httpClient
          .get(
            uri,
            headers: {
              'User-Agent': _userAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 429) {
        return BarcodeLookupResult(
          barcode: normalized,
          isRateLimited: true,
          errorMessage:
              'Lookup service rate limit reached. Please enter details manually.',
        );
      }

      if (response.statusCode == 404) {
        return BarcodeLookupResult(
          barcode: normalized,
          errorMessage: 'Barcode not found in online product database.',
        );
      }

      if (response.statusCode != 200) {
        return BarcodeLookupResult(
          barcode: normalized,
          errorMessage:
              'Product lookup service returned HTTP ${response.statusCode}.',
        );
      }

      final Map<String, dynamic> data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      final status = data['status'];
      if (status != 1) {
        return BarcodeLookupResult(
          barcode: normalized,
          errorMessage:
              'Product not found in online catalog. You can add it manually.',
        );
      }

      final product = data['product'] as Map<String, dynamic>? ?? {};

      // Parse only fields actually returned by the API
      final rawName = product['product_name'] as String? ??
          product['product_name_en'] as String? ??
          product['generic_name'] as String?;
      final name = (rawName != null && rawName.trim().isNotEmpty)
          ? rawName.trim()
          : null;

      final rawBrand = product['brands'] as String? ??
          product['brand_owner'] as String?;
      String? brand;
      if (rawBrand != null && rawBrand.trim().isNotEmpty) {
        // Take the primary brand if multiple are comma-separated
        brand = rawBrand.split(',').first.trim();
      }

      final rawImg = product['image_front_url'] as String? ??
          product['image_url'] as String? ??
          product['image_front_small_url'] as String?;
      final imageUrl = (rawImg != null && rawImg.trim().isNotEmpty)
          ? rawImg.trim()
          : null;

      final category = _resolveCategory(product);

      return BarcodeLookupResult(
        barcode: normalized,
        name: name,
        brand: brand,
        category: category,
        imageUrl: imageUrl,
        foundInOpenFoodFacts: true,
      );
    } on SocketException {
      return BarcodeLookupResult(
        barcode: normalized,
        errorMessage: 'Network offline. Please check your internet connection.',
      );
    } on TimeoutException {
      return BarcodeLookupResult(
        barcode: normalized,
        errorMessage: 'Online product lookup timed out. Enter details manually.',
      );
    } catch (e) {
      debugPrint('[BarcodeLookup] API exception: $e');
      return BarcodeLookupResult(
        barcode: normalized,
        errorMessage: 'Lookup error ($e). Please enter details manually.',
      );
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  /// Maps Open Food Facts categories into common retail categories.
  static String? _resolveCategory(Map<String, dynamic> product) {
    final rawCategories = product['categories'] as String? ?? '';
    final tags = (product['categories_tags'] as List<dynamic>?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        [];

    final combined = '$rawCategories ${tags.join(' ')}'.toLowerCase();

    if (combined.contains('beverage') ||
        combined.contains('drink') ||
        combined.contains('juice') ||
        combined.contains('soda') ||
        combined.contains('water') ||
        combined.contains('tea') ||
        combined.contains('coffee')) {
      return 'Beverages';
    }
    if (combined.contains('snack') ||
        combined.contains('biscuit') ||
        combined.contains('cookie') ||
        combined.contains('chip') ||
        combined.contains('chocolate') ||
        combined.contains('confection') ||
        combined.contains('candy')) {
      return 'Snacks';
    }
    if (combined.contains('dairy') ||
        combined.contains('milk') ||
        combined.contains('cheese') ||
        combined.contains('yogurt') ||
        combined.contains('butter')) {
      return 'Dairy';
    }
    if (combined.contains('grocery') ||
        combined.contains('groceries') ||
        combined.contains('cereal') ||
        combined.contains('flour') ||
        combined.contains('rice') ||
        combined.contains('pasta') ||
        combined.contains('oil') ||
        combined.contains('sauce') ||
        combined.contains('spice')) {
      return 'Groceries';
    }
    if (combined.contains('hygiene') ||
        combined.contains('beauty') ||
        combined.contains('cosmetic') ||
        combined.contains('soap') ||
        combined.contains('shampoo') ||
        combined.contains('care')) {
      return 'Personal Care';
    }

    if (rawCategories.trim().isNotEmpty) {
      final first = rawCategories.split(',').first.trim();
      if (first.isNotEmpty && first.length <= 30) {
        return first;
      }
    }

    return null;
  }
}
