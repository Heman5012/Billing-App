import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/auth_service.dart';
import '../services/firebase_service.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  // Comprehensive controller supporting all common linear retail & 2D formats
  late final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.itf14,
      BarcodeFormat.codabar,
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.pdf417,
      BarcodeFormat.aztec,
    ],
  );

  bool _hasScanned = false;
  bool _isTorchOn = false;
  String? _detectedRawValue;
  String? _detectedFormat;
  String _detectionStatus = 'Ready to scan';
  String _firestoreStatus = 'Waiting for scan';
  String? _scannerError;

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_hasScanned) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final raw = barcode.rawValue ?? barcode.displayValue;
    if (raw == null || raw.trim().isEmpty) return;

    _hasScanned = true;
    final clean = raw.trim();
    final formatName = barcode.format.name.toUpperCase();

    if (mounted) {
      setState(() {
        _detectedRawValue = clean;
        _detectedFormat = formatName;
        _detectionStatus = 'Detection Succeeded';
        _firestoreStatus = 'Searching Firestore...';
      });
    }

    // Direct Firestore lookup for immediate debugging confirmation
    final uid = AuthService.instance.currentUser?.uid ?? '';
    final product =
        await FirebaseService.instance.findProductByBarcode(uid, clean);

    if (!mounted) return;

    if (product != null) {
      setState(() {
        _firestoreStatus =
            'Found: ${product.name} (₹${product.price.toStringAsFixed(2)})';
      });

      // Brief confirmation so user sees the green diagnostic feedback
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        Navigator.of(context).pop(
          product.barcode.isNotEmpty ? product.barcode : clean,
        );
      }
    } else {
      setState(() {
        _firestoreStatus = 'Not found in Firestore (Queried: "$clean")';
      });

      // Display diagnostic bottom sheet for not-found barcodes
      _showNotFoundDiagnosticSheet(clean, formatName);
    }
  }

  void _showNotFoundDiagnosticSheet(String raw, String format) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFE65100), size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Barcode Scanned (Not in Inventory)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _resumeScanning();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Raw Barcode: $raw',
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Symbology: $format',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 12)),
                    const SizedBox(height: 4),
                    const Text('Detection Status: Succeeded',
                        style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('Firestore: No matching product in "products"',
                        style: TextStyle(
                            color: Color(0xFFC62828),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _resumeScanning();
                      },
                      child: const Text('Scan Again'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop(raw);
                      },
                      child: const Text('Add to Catalogue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resumeScanning() {
    if (mounted) {
      setState(() {
        _hasScanned = false;
        _detectedRawValue = null;
        _detectedFormat = null;
        _detectionStatus = 'Ready to scan';
        _firestoreStatus = 'Waiting for scan';
      });
    }
  }

  void _promptManualEntry() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Barcode Manually'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            labelText: 'Barcode Number / Code',
            hintText: 'e.g. 8901030895458',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = ctrl.text.trim();
              Navigator.of(ctx).pop();
              if (text.isNotEmpty && mounted) {
                _hasScanned = true;
                Navigator.of(context).pop(text);
              }
            },
            child: const Text('Use Barcode'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Scan Product Barcode',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.amber : Colors.white,
            ),
            tooltip: 'Toggle Flash',
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            tooltip: 'Switch Camera',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Camera Viewfinder
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              _scannerError = error.errorCode.name;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        size: 56,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Camera Error (${error.errorCode.name})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.errorCode == MobileScannerErrorCode.permissionDenied
                            ? 'Camera permission was denied. Please allow camera access in Settings or enter barcode manually.'
                            : 'Could not start camera. Please enter barcode manually.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _promptManualEntry,
                        icon: const Icon(Icons.keyboard, size: 18),
                        label: const Text('Enter Manually'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Viewfinder Reticle Framing Overlay
          LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > constraints.maxHeight;
              final boxWidth = isLandscape
                  ? (constraints.maxHeight * 0.70).clamp(240.0, 360.0)
                  : (constraints.maxWidth * 0.85).clamp(260.0, 360.0);
              final boxHeight = isLandscape
                  ? (boxWidth * 0.50).clamp(130.0, 180.0)
                  : (boxWidth * 0.65).clamp(170.0, 240.0);

              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: boxWidth,
                    height: boxHeight,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _detectedRawValue != null
                            ? const Color(0xFF10B981)
                            : const Color(0xFF00E5FF),
                        width: 2.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (_detectedRawValue != null
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF00E5FF))
                              .withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        if (_detectedRawValue == null)
                          AnimatedBuilder(
                            animation: _animController,
                            builder: (context, child) {
                              return Positioned(
                                top: (boxHeight - 4) * _animController.value,
                                left: 6,
                                right: 6,
                                child: Container(
                                  height: 2.5,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00E5FF)
                                            .withValues(alpha: 0.6),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: (constraints.maxHeight / 2) + (boxHeight / 2) + 16,
                    left: 20,
                    right: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Align product barcode within frame',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                        if (!isLandscape) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Supports EAN-13, EAN-8, UPC, Code 128, Code 39',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // 3. Live Diagnostics & Debug HUD (Top overlay)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _detectedRawValue != null
                      ? const Color(0xFF10B981)
                      : (_scannerError != null ? Colors.red : Colors.white24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📸 Detection: $_detectionStatus',
                        style: TextStyle(
                          color: _detectedRawValue != null
                              ? const Color(0xFF10B981)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_detectedFormat != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade900,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _detectedFormat!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '🔢 Raw Scanned: ${_detectedRawValue ?? "(none yet)"}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '☁️ Firestore: $_firestoreStatus',
                    style: TextStyle(
                      color: _firestoreStatus.startsWith('Found')
                          ? const Color(0xFF4ADE80)
                          : (_firestoreStatus.startsWith('Not found')
                              ? const Color(0xFFF87171)
                              : Colors.white60),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Action Bar
          Positioned(
            bottom: 28,
            left: 24,
            right: 24,
            child: Center(
              child: OutlinedButton.icon(
                onPressed: _promptManualEntry,
                icon: const Icon(Icons.keyboard_outlined, size: 18),
                label: const Text('Enter Barcode Manually'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black54,
                  side: const BorderSide(color: Colors.white38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
