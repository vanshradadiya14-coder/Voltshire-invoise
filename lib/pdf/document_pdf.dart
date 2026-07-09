import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils/calculations.dart';
import '../core/utils/formatters.dart';
import '../models/company_profile.dart';
import '../models/invoice.dart';
import '../models/line_item.dart';
import '../models/quote.dart';

/// Generates professional invoice and quotation PDFs whose layout mirrors the
/// reference document: company header + logo, bill-to block, meta panel, item
/// table, totals, payment/bank details, terms and a signature area.
class DocumentPdf {
  const DocumentPdf._();

  // Brand accent used for headings and the table header band.
  static const PdfColor _accent = PdfColor.fromInt(0xFF2A5BD7);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _line = PdfColor.fromInt(0xFFE2E5EA);
  static const PdfColor _band = PdfColor.fromInt(0xFFEDF1FB);

  /// Builds an invoice PDF and returns its bytes.
  static Future<Uint8List> invoice({
    required Invoice invoice,
    required CompanyProfile company,
  }) {
    return _build(
      title: 'INVOICE',
      company: company,
      logoUrl: company.logoUrl,
      number: invoice.numberFormatted,
      customerName: invoice.customerName,
      customerAddress: invoice.customerAddress,
      issueDate: invoice.issueDate,
      secondaryDateLabel: 'Due date',
      secondaryDate: invoice.dueDate,
      jobTitle: invoice.jobTitle,
      workDescription: invoice.workDescription,
      items: invoice.items,
      symbol: company.currencySymbol,
      totalLabel: 'TOTAL DUE',
      totalValue: invoice.balanceDue > 0 ? invoice.balanceDue : invoice.grandTotal,
      amountPaid: invoice.amountPaid,
      notes: invoice.notes,
      showBankDetails: true,
      paymentMethodLabel: 'Transfer',
    );
  }

  /// Builds a quotation PDF and returns its bytes.
  static Future<Uint8List> quote({
    required Quote quote,
    required CompanyProfile company,
  }) {
    return _build(
      title: 'QUOTATION',
      company: company,
      logoUrl: company.logoUrl,
      number: quote.numberFormatted,
      customerName: quote.customerName,
      customerAddress: quote.customerAddress,
      issueDate: quote.issueDate,
      secondaryDateLabel: 'Valid until',
      secondaryDate: quote.validUntil,
      jobTitle: quote.jobTitle,
      workDescription: quote.workDescription,
      items: quote.items,
      symbol: company.currencySymbol,
      totalLabel: 'TOTAL',
      totalValue: quote.grandTotal,
      amountPaid: 0,
      notes: quote.notes,
      showBankDetails: false,
      paymentMethodLabel: null,
    );
  }

  static Future<Uint8List> _build({
    required String title,
    required CompanyProfile company,
    required String logoUrl,
    required String number,
    required String customerName,
    required String customerAddress,
    required DateTime? issueDate,
    required String secondaryDateLabel,
    required DateTime? secondaryDate,
    required String jobTitle,
    required String workDescription,
    required List<LineItem> items,
    required String symbol,
    required String totalLabel,
    required double totalValue,
    required double amountPaid,
    required String notes,
    required bool showBankDetails,
    required String? paymentMethodLabel,
  }) async {
    final pw.Document doc = pw.Document();

    // Try to load the company logo (network). Ignore failures gracefully.
    pw.ImageProvider? logo;
    if (logoUrl.isNotEmpty) {
      try {
        logo = await networkImage(logoUrl);
      } catch (_) {
        logo = null;
      }
    }

    final totals = items.totals;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 44),
        build: (pw.Context context) => <pw.Widget>[
          _header(title, company, logo),
          pw.SizedBox(height: 22),
          _billToAndMeta(
            company: company,
            number: number,
            customerName: customerName,
            customerAddress: customerAddress,
            issueDate: issueDate,
            secondaryDateLabel: secondaryDateLabel,
            secondaryDate: secondaryDate,
            paymentMethodLabel: paymentMethodLabel,
          ),
          pw.SizedBox(height: 18),
          if (jobTitle.isNotEmpty || workDescription.isNotEmpty)
            _workDescription(jobTitle, workDescription),
          if (jobTitle.isNotEmpty || workDescription.isNotEmpty)
            pw.SizedBox(height: 12),
          _itemsTable(items, symbol),
          pw.SizedBox(height: 12),
          _totals(totals, symbol, totalLabel, totalValue, amountPaid),
          pw.SizedBox(height: 20),
          if (notes.isNotEmpty || company.notes.isNotEmpty)
            _notesBlock(notes.isNotEmpty ? notes : company.notes),
          if (company.paymentTerms.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 10),
            _terms(company.paymentTerms),
          ],
          if (showBankDetails) ...<pw.Widget>[
            pw.SizedBox(height: 14),
            _bankDetails(company),
          ],
          pw.SizedBox(height: 30),
          _signature(),
        ],
        footer: (pw.Context context) => _footer(company, context),
      ),
    );

    return doc.save();
  }

  // ---- Header: logo/name on the left, company block on the right ----
  static pw.Widget _header(String title, CompanyProfile c, pw.ImageProvider? logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: <pw.Widget>[
            if (logo != null)
              pw.Container(
                width: 64,
                height: 64,
                margin: const pw.EdgeInsets.only(right: 12),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            pw.Text(
              c.companyName.isEmpty ? 'Your Company' : c.companyName,
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: _accent,
              ),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: <pw.Widget>[
            pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 26, fontWeight: pw.FontWeight.bold, color: _accent)),
            pw.SizedBox(height: 6),
            _rightLine(c.companyName),
            for (final String l in c.fullAddress.split('\n')) _rightLine(l),
            if (c.registrationNumber.isNotEmpty)
              _rightLine('Co. Reg. No.: ${c.registrationNumber}'),
            if (c.vatNumber.isNotEmpty) _rightLine('VAT No.: ${c.vatNumber}'),
            pw.SizedBox(height: 4),
            if (c.phone.isNotEmpty) _rightLine(c.phone),
            if (c.email.isNotEmpty) _rightLine(c.email),
            if (c.website.isNotEmpty) _rightLine(c.website),
          ],
        ),
      ],
    );
  }

  static pw.Widget _rightLine(String text) => text.trim().isEmpty
      ? pw.SizedBox()
      : pw.Text(text,
          textAlign: pw.TextAlign.right,
          style: const pw.TextStyle(fontSize: 9, color: _muted));

  // ---- Bill-to block + meta panel ----
  static pw.Widget _billToAndMeta({
    required CompanyProfile company,
    required String number,
    required String customerName,
    required String customerAddress,
    required DateTime? issueDate,
    required String secondaryDateLabel,
    required DateTime? secondaryDate,
    required String? paymentMethodLabel,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text('BILL TO',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted)),
              pw.SizedBox(height: 4),
              pw.Text(customerName,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              if (customerAddress.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(customerAddress,
                      style: const pw.TextStyle(fontSize: 10, color: _muted)),
                ),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            children: <pw.Widget>[
              _metaRow('Invoice No.', number),
              if (issueDate != null) _metaRow('Issue date', Formatters.date(issueDate)),
              if (secondaryDate != null)
                _metaRow(secondaryDateLabel, Formatters.date(secondaryDate)),
              if (paymentMethodLabel != null)
                _metaRow('Payment method', paymentMethodLabel),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _metaRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: _muted)),
            pw.Text(value,
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  static pw.Widget _workDescription(String jobTitle, String description) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _band,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          if (jobTitle.isNotEmpty)
            pw.Text(jobTitle,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          if (jobTitle.isNotEmpty && description.isNotEmpty) pw.SizedBox(height: 4),
          if (description.isNotEmpty)
            pw.Text(description, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  // ---- Item table ----
  static pw.Widget _itemsTable(List<LineItem> items, String symbol) {
    final List<pw.TableRow> rows = <pw.TableRow>[
      // header band
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _accent),
        children: <pw.Widget>[
          _cell('DESCRIPTION', header: true, align: pw.TextAlign.left),
          _cell('QTY', header: true, align: pw.TextAlign.center),
          _cell('UNIT PRICE', header: true, align: pw.TextAlign.right),
          _cell('DISC %', header: true, align: pw.TextAlign.right),
          _cell('VAT %', header: true, align: pw.TextAlign.right),
          _cell('AMOUNT', header: true, align: pw.TextAlign.right),
        ],
      ),
    ];

    for (int i = 0; i < items.length; i++) {
      final LineItem it = items[i];
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(
          color: i.isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF8F9FC),
        ),
        children: <pw.Widget>[
          _cell(it.description, align: pw.TextAlign.left),
          _cell(_qtyStr(it.quantity), align: pw.TextAlign.center),
          _cell(Formatters.money(it.unitPrice, symbol: symbol), align: pw.TextAlign.right),
          _cell(it.discountPercent == 0 ? '-' : Formatters.percent(it.discountPercent),
              align: pw.TextAlign.right),
          _cell(it.vatPercent == 0 ? '-' : Formatters.percent(it.vatPercent),
              align: pw.TextAlign.right),
          _cell(Formatters.money(it.netAfterDiscount, symbol: symbol),
              align: pw.TextAlign.right),
        ],
      ));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _line, width: 0.5),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(1.1),
        4: pw.FlexColumnWidth(1.1),
        5: pw.FlexColumnWidth(1.6),
      },
      children: rows,
    );
  }

  static String _qtyStr(double q) =>
      q.truncateToDouble() == q ? q.toStringAsFixed(0) : q.toString();

  static pw.Widget _cell(String text,
      {bool header = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: header ? 8.5 : 9.5,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: header ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  // ---- Totals block, right aligned ----
  static pw.Widget _totals(DocumentTotals totals, String symbol, String totalLabel,
      double totalValue, double amountPaid) {
    pw.Widget line(String label, String value, {bool bold = false, PdfColor? color}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: bold ? 12 : 10,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: color ?? PdfColors.black)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: bold ? 12 : 10,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: color ?? PdfColors.black)),
          ],
        ),
      );
    }

    return pw.Row(
      children: <pw.Widget>[
        pw.Spacer(flex: 3),
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            children: <pw.Widget>[
              line('Subtotal', Formatters.money(totals.subtotal, symbol: symbol)),
              if (totals.discountTotal > 0)
                line('Discount',
                    '-${Formatters.money(totals.discountTotal, symbol: symbol)}'),
              line('VAT', Formatters.money(totals.vatTotal, symbol: symbol)),
              pw.Divider(color: _line, height: 10),
              line('Grand Total', Formatters.money(totals.grandTotal, symbol: symbol),
                  bold: true),
              if (amountPaid > 0) ...<pw.Widget>[
                line('Amount Paid', '-${Formatters.money(amountPaid, symbol: symbol)}'),
              ],
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: _accent,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: <pw.Widget>[
                    pw.Text(totalLabel,
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text(Formatters.money(totalValue, symbol: symbol),
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _notesBlock(String notes) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text('Notes',
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted)),
          pw.SizedBox(height: 2),
          pw.Text(notes, style: const pw.TextStyle(fontSize: 9.5)),
        ],
      );

  static pw.Widget _terms(String terms) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text('Terms',
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted)),
          pw.SizedBox(height: 2),
          pw.Text(terms, style: const pw.TextStyle(fontSize: 9.5)),
        ],
      );

  static pw.Widget _bankDetails(CompanyProfile c) {
    final List<List<String>> pairs = <List<String>>[
      if (c.accountName.isNotEmpty) <String>['Account holder', c.accountName],
      if (c.bankName.isNotEmpty) <String>['Bank', c.bankName],
      if (c.sortCode.isNotEmpty) <String>['Sort code', c.sortCode],
      if (c.accountNumber.isNotEmpty) <String>['Account No.', c.accountNumber],
      if (c.iban.isNotEmpty) <String>['IBAN', c.iban],
      if (c.swift.isNotEmpty) <String>['SWIFT/BIC', c.swift],
    ];
    if (pairs.isEmpty) return pw.SizedBox();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text('PAYMENT DETAILS',
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold, color: _accent)),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 24,
            runSpacing: 4,
            children: pairs
                .map((List<String> p) => pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: <pw.Widget>[
                        pw.Text('${p[0]}: ',
                            style: const pw.TextStyle(fontSize: 9.5, color: _muted)),
                        pw.Text(p[1],
                            style: pw.TextStyle(
                                fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                      ],
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _signature() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Container(width: 160, height: 0.8, color: _muted),
            pw.SizedBox(height: 4),
            pw.Text('Authorised signature',
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Container(width: 120, height: 0.8, color: _muted),
            pw.SizedBox(height: 4),
            pw.Text('Date', style: const pw.TextStyle(fontSize: 9, color: _muted)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _footer(CompanyProfile c, pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        '${c.companyName}  •  Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: _muted),
      ),
    );
  }
}

/// Loads a bundled asset image for the PDF (unused fallback helper kept for
/// future use, e.g. a placeholder logo).
Future<Uint8List> loadAssetBytes(String path) async {
  final data = await rootBundle.load(path);
  return data.buffer.asUint8List();
}
