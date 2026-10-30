import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/invoice.dart';

class PdfService {
  static final PdfService instance = PdfService._();
  PdfService._();

  static const PdfColor primaryBlue = PdfColor.fromInt(0xFF1E88E5);
  static const PdfColor darkNavy = PdfColor.fromInt(0xFF0D47A1);
  static const PdfColor lightGrey = PdfColor.fromInt(0xFFF5F7FA);
  static const PdfColor textDark = PdfColor.fromInt(0xFF263238);
  static const PdfColor borderGrey = PdfColor.fromInt(0xFFE0E0E0);
  static const PdfColor demoBadgeColor = PdfColor.fromInt(0xFFE65100);

  pw.Font? _cachedBaseFont;
  pw.Font? _cachedBoldFont;
  List<pw.Font>? _cachedFallbacks;
  // ignore: unused_field — retained for future font-aware logic (e.g. emoji/regional glyphs)
  bool _isUnicodeSupported = false;

  /// Loads and embeds bundled Roboto font assets (with full native Unicode and Rupee ₹ glyph coverage)
  /// so that typography and currency symbols render consistently across all external devices and PDF viewers.
  Future<pw.ThemeData> _buildPdfTheme() async {
    if (_cachedBaseFont != null && _cachedBoldFont != null) {
      return pw.ThemeData.withFont(
        base: _cachedBaseFont!,
        bold: _cachedBoldFont!,
        italic: _cachedBaseFont!,
        boldItalic: _cachedBoldFont!,
        fontFallback: _cachedFallbacks ?? const [],
      );
    }

    pw.Font? baseFont;
    pw.Font? boldFont;

    // 1. Primary invoice typography: Bundled Roboto with full native Unicode & Rupee (₹) glyph coverage
    try {
      final regData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      baseFont = pw.Font.ttf(regData);
      _isUnicodeSupported = true;
    } catch (_) {}

    try {
      final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      boldFont = pw.Font.ttf(boldData);
    } catch (_) {}

    // 2. Web / Cloud fallback via Printing package (downloads official Roboto with complete Unicode support)
    if (baseFont == null) {
      try {
        baseFont = await PdfGoogleFonts.robotoRegular();
        _isUnicodeSupported = true;
      } catch (_) {}
    }
    if (boldFont == null) {
      try {
        boldFont = await PdfGoogleFonts.robotoBold();
      } catch (_) {}
    }

    // 3. Fallback to standard fonts if still null
    if (baseFont == null) {
      baseFont = pw.Font.helvetica();
      _isUnicodeSupported = false;
    }
    boldFont ??= pw.Font.helveticaBold();

    _cachedBaseFont = baseFont;
    _cachedBoldFont = boldFont;

    final fallbacks = <pw.Font>[baseFont, boldFont];
    _cachedFallbacks = fallbacks;

    return pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
      italic: baseFont,
      boldItalic: boldFont,
      fontFallback: fallbacks,
    );
  }

  /// Generates the complete PDF bytes for an invoice with embedded typography
  Future<Uint8List> generateInvoicePdf({
    required Invoice invoice,
    required BusinessProfile business,
    String? qrUrl,
  }) async {
    final theme = await _buildPdfTheme();
    final pdf = pw.Document(theme: theme);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final formattedDate = dateFormat.format(invoice.createdAt);
    
    // Currency symbol sanitation: PDFs shared across devices/browsers can show tofu glyph
    // boxes '🗌' for ₹ (U+20B9) even when Roboto is loaded, because some PDF viewers
    // strip embedded font subsets or fall back to system fonts that lack the Rupee glyph.
    // Use 'Rs. ' universally in PDFs to guarantee legible currency display on all viewers.
    final rawCur = business.currency.trim().isEmpty ? '₹' : business.currency.trim();
    final cur = (rawCur == '₹' || rawCur.contains('₹')) ? 'Rs. ' : rawCur;

    // Public QR verification link or share token URL
    final qrData =
        qrUrl ??
        'https://billing-and-invoice-fe416.web.app/?token=${invoice.shareToken}';

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER WITH BILLWAVE BRANDING & BUSINESS INFO
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: pw.BoxDecoration(
                              color: primaryBlue,
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.Text(
                              'BillWave',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            'TAX INVOICE',
                            style: pw.TextStyle(
                              color: darkNavy,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        business.businessName,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                          color: textDark,
                        ),
                      ),
                      if (business.address.isNotEmpty)
                        pw.Text(
                          business.address,
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      if (business.phone.isNotEmpty)
                        pw.Text(
                          'Phone: ${business.phone}',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      // DEMO NOTICE BADGE
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFFFF3E0),
                          border: pw.Border.all(color: demoBadgeColor),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'DEMO TRANSACTION',
                          style: pw.TextStyle(
                            color: demoBadgeColor,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Invoice #: ${invoice.invoiceNumber}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: textDark,
                        ),
                      ),
                      pw.Text(
                        'Date: $formattedDate',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Payment: ${invoice.paymentMethod} [${invoice.paymentStatus.toUpperCase()}]',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: invoice.isPaid
                              ? PdfColor.fromInt(0xFF2E7D32)
                              : PdfColor.fromInt(0xFFC62828),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: borderGrey, thickness: 1),
              pw.SizedBox(height: 8),

              // CUSTOMER DETAILS
              if (invoice.customer.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: lightGrey,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text(
                        'Billed To: ',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                          color: textDark,
                        ),
                      ),
                      pw.Text(
                        invoice.customer.name.isNotEmpty
                            ? invoice.customer.name
                            : 'Guest Customer',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      if (invoice.customer.phone.isNotEmpty) ...[
                        pw.SizedBox(width: 16),
                        pw.Text(
                          'Phone: ${invoice.customer.phone}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                      if (invoice.customer.email.isNotEmpty) ...[
                        pw.SizedBox(width: 16),
                        pw.Text(
                          'Email: ${invoice.customer.email}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
              ],

              // ITEMS TABLE
              pw.Table(
                border: pw.TableBorder(
                  horizontalInside: const pw.BorderSide(
                    color: borderGrey,
                    width: 0.5,
                  ),
                  bottom: const pw.BorderSide(color: borderGrey, width: 1),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3.5),
                  1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(1.0),
                  3: pw.FlexColumnWidth(1.0),
                  4: pw.FlexColumnWidth(1.0),
                  5: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: lightGrey),
                    children: [
                      _tableHeader('Item Description'),
                      _tableHeader('Unit Price', align: pw.TextAlign.right),
                      _tableHeader('Qty', align: pw.TextAlign.center),
                      _tableHeader('Disc %', align: pw.TextAlign.center),
                      _tableHeader('Tax %', align: pw.TextAlign.center),
                      _tableHeader('Total', align: pw.TextAlign.right),
                    ],
                  ),
                  ...invoice.items.map((item) {
                    return pw.TableRow(
                      children: [
                        _tableCell(item.name),
                        _tableCell(
                          '$cur${item.unitPrice.toStringAsFixed(2)}',
                          align: pw.TextAlign.right,
                        ),
                        _tableCell(
                          '${item.quantity}',
                          align: pw.TextAlign.center,
                        ),
                        _tableCell(
                          item.discountPercent > 0
                              ? '${item.discountPercent.toStringAsFixed(0)}%'
                              : '-',
                          align: pw.TextAlign.center,
                        ),
                        _tableCell(
                          item.taxRate > 0
                              ? '${item.taxRate.toStringAsFixed(0)}%'
                              : '0%',
                          align: pw.TextAlign.center,
                        ),
                        _tableCell(
                          '$cur${item.lineTotal.toStringAsFixed(2)}',
                          align: pw.TextAlign.right,
                          isBold: true,
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),

              // FINANCIAL SUMMARY & QR CODE
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // QR CODE & VERIFICATION NOTICE
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderGrey),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: qrData,
                          width: 64,
                          height: 64,
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Scan to Verify',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                  color: textDark,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Retrieve digital copy and verify demo transaction authenticity.',
                                style: const pw.TextStyle(
                                  fontSize: 7.5,
                                  color: PdfColors.grey600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // TOTALS BREAKDOWN
                  pw.Container(
                    width: 240,
                    child: pw.Column(
                      children: [
                        _summaryRow(
                          'Subtotal:',
                          '$cur${invoice.subtotal.toStringAsFixed(2)}',
                        ),
                        if (invoice.overallDiscountAmount > 0)
                          _summaryRow(
                            'Discount (${invoice.overallDiscountPercent.toStringAsFixed(0)}%):',
                            '-$cur${invoice.overallDiscountAmount.toStringAsFixed(2)}',
                            isNegative: true,
                          ),
                        _summaryRow(
                          'Taxable Amount:',
                          '$cur${invoice.taxableAmount.toStringAsFixed(2)}',
                        ),
                        ...invoice.taxBreakdown.entries.map((entry) {
                          return _summaryRow(
                            'Tax (${entry.key}):',
                            '$cur${entry.value.toStringAsFixed(2)}',
                          );
                        }),
                        pw.Divider(color: borderGrey, thickness: 1),
                        _summaryRow(
                          'Total Payable:',
                          '$cur${invoice.total.toStringAsFixed(2)}',
                          isBold: true,
                          fontSize: 13,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (invoice.notes.isNotEmpty) ...[
                pw.SizedBox(height: 16),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: lightGrey,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'Notes: ${invoice.notes}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey800,
                    ),
                  ),
                ),
              ],

              pw.Spacer(),
              pw.Divider(color: borderGrey, thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'SIMULATED BILLING SYSTEM  |  DEMO MODE ONLY  |  NO REAL CURRENCY TRANSFERRED',
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Powered by BillWave',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _tableHeader(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 9.5,
          color: textDark,
        ),
      ),
    );
  }

  static pw.Widget _tableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textDark,
        ),
      ),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    bool isNegative = false,
    double fontSize = 9.5,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: textDark,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isNegative
                  ? PdfColor.fromInt(0xFFC62828)
                  : (isBold ? primaryBlue : textDark),
            ),
          ),
        ],
      ),
    );
  }

  /// Print or share the invoice
  Future<void> printInvoice({
    required Invoice invoice,
    required BusinessProfile business,
  }) async {
    final bytes = await generateInvoicePdf(
      invoice: invoice,
      business: business,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }

  /// Share the PDF file
  Future<void> shareInvoicePdf({
    required Invoice invoice,
    required BusinessProfile business,
  }) async {
    final bytes = await generateInvoicePdf(
      invoice: invoice,
      business: business,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }
}
