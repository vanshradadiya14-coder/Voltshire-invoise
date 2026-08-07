import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils/formatters.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/invoice.dart';
import '../models/job.dart';
import '../models/payment.dart';
import '../models/quote.dart';

/// What a user can export.
enum ExportKind {
  customers('Customers', 'customers'),
  jobs('Jobs', 'jobs'),
  quotes('Quotations', 'quotes'),
  invoices('Invoices', 'invoices'),
  payments('Payments', 'payments'),
  expenses('Expenses', 'expenses');

  const ExportKind(this.label, this.fileStem);
  final String label;
  final String fileStem;
}

/// Exports the user's records as CSV.
///
/// Two reasons this is not optional in a serious product: a business owner
/// must be able to hand their books to an accountant, and UK GDPR gives them a
/// right to their data in a portable format. Locking people's records inside
/// the app is both bad product and a compliance problem.
class ExportService {
  const ExportService();

  /// Writes one CSV and returns the file.
  Future<File> writeCsv({
    required ExportKind kind,
    required List<List<Object?>> rows,
  }) async {
    final Directory dir = await getTemporaryDirectory();
    final String stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 10)
        .replaceAll('-', '');
    final File file = File('${dir.path}/${kind.fileStem}_$stamp.csv');

    // Excel needs a UTF-8 BOM to render '£' correctly, and a UK business
    // exporting invoices will open this in Excel.
    const String bom = '﻿';
    final String csv = const ListToCsvConverter().convert(rows);
    await file.writeAsString('$bom$csv');
    return file;
  }

  Future<void> share(List<File> files, {String? subject}) async {
    if (files.isEmpty) return;
    await Share.shareXFiles(
      files.map((File f) => XFile(f.path)).toList(),
      subject: subject ?? 'Builder CRM export',
    );
  }

  // ---- Row builders -----------------------------------------------------
  // Dates are written as ISO-8601 (yyyy-MM-dd) rather than dd/MM/yyyy: every
  // spreadsheet and accounting package parses ISO unambiguously, whereas
  // 03/04/2026 means two different days depending on who opens it.

  List<List<Object?>> customerRows(List<Customer> items) => <List<Object?>>[
        <Object?>[
          'Name', 'Phone', 'Email', 'Billing address', 'Site address',
          'Notes', 'Created',
        ],
        for (final Customer c in items)
          <Object?>[
            c.name,
            c.phone,
            c.email,
            c.billingAddress,
            c.siteAddress,
            c.notes,
            _iso(c.createdAt),
          ],
      ];

  List<List<Object?>> jobRows(List<Job> items) => <List<Object?>>[
        <Object?>[
          'Title', 'Customer', 'Status', 'Site address', 'Start date',
          'Completion date', 'Description', 'Created',
        ],
        for (final Job j in items)
          <Object?>[
            j.title,
            j.customerName,
            j.status.label,
            j.siteAddress,
            _iso(j.startDate),
            _iso(j.completionDate),
            j.description,
            _iso(j.createdAt),
          ],
      ];

  List<List<Object?>> invoiceRows(List<Invoice> items) => <List<Object?>>[
        <Object?>[
          'Number', 'Customer', 'Job', 'Issue date', 'Due date', 'Status',
          'Subtotal', 'VAT', 'Total', 'Paid', 'Balance due',
        ],
        for (final Invoice i in items)
          <Object?>[
            i.numberFormatted,
            i.customerName,
            i.jobTitle,
            _iso(i.issueDate),
            _iso(i.dueDate),
            i.status.label,
            _money(i.totals.subtotal),
            _money(i.totals.vatTotal),
            _money(i.grandTotal),
            _money(i.amountPaid),
            _money(i.balanceDue),
          ],
      ];

  List<List<Object?>> quoteRows(List<Quote> items) => <List<Object?>>[
        <Object?>[
          'Number', 'Customer', 'Job', 'Issue date', 'Valid until', 'Status',
          'Subtotal', 'VAT', 'Total',
        ],
        for (final Quote q in items)
          <Object?>[
            q.numberFormatted,
            q.customerName,
            q.jobTitle,
            _iso(q.issueDate),
            _iso(q.validUntil),
            q.status.label,
            _money(q.totals.subtotal),
            _money(q.totals.vatTotal),
            _money(q.grandTotal),
          ],
      ];

  List<List<Object?>> paymentRows(List<Payment> items) => <List<Object?>>[
        <Object?>[
          'Date', 'Invoice', 'Customer', 'Amount', 'Method', 'Reference', 'Notes',
        ],
        for (final Payment p in items)
          <Object?>[
            _iso(p.date),
            p.invoiceNumber,
            p.customerName,
            _money(p.amount),
            p.method,
            p.reference,
            p.notes,
          ],
      ];

  List<List<Object?>> expenseRows(List<Expense> items) => <List<Object?>>[
        <Object?>[
          'Date', 'Category', 'Supplier', 'Description', 'Job', 'Amount',
          'Has receipt',
        ],
        for (final Expense e in items)
          <Object?>[
            _iso(e.date),
            e.category,
            e.supplier,
            e.description,
            e.jobTitle,
            _money(e.amount),
            e.hasReceipt ? 'Yes' : 'No',
          ],
      ];

  /// A plain-text summary suitable for emailing to an accountant.
  String summary({
    required double revenue,
    required double expenses,
    required String period,
    required String symbol,
  }) {
    final double profit = revenue - expenses;
    return <String>[
      'Builder CRM export',
      'Period: $period',
      '',
      'Revenue received: ${Formatters.money(revenue, symbol: symbol)}',
      'Expenses:         ${Formatters.money(expenses, symbol: symbol)}',
      'Profit:           ${Formatters.money(profit, symbol: symbol)}',
    ].join('\n');
  }

  /// Numbers are written unformatted so spreadsheets treat them as numeric.
  String _money(double value) => value.toStringAsFixed(2);

  String _iso(DateTime? date) => date == null
      ? ''
      : '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
}

final exportServiceProvider =
    Provider<ExportService>((ref) => const ExportService());
