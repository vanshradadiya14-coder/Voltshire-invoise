import '../core/utils/calculations.dart';
import '../core/utils/firestore_utils.dart';
import 'enums.dart';
import 'line_item.dart';

/// A customer invoice. Collection `invoices`.
///
/// Line items are embedded. Totals are derived on read; only `amountPaid` and
/// the manually-set/derived `status` are persisted alongside the raw items.
class Invoice {
  const Invoice({
    required this.id,
    required this.ownerId,
    required this.number,
    required this.numberFormatted,
    required this.customerId,
    required this.customerName,
    this.customerAddress = '',
    this.jobId,
    this.jobTitle = '',
    this.workDescription = '',
    this.items = const <LineItem>[],
    this.issueDate,
    this.dueDate,
    this.amountPaid = 0,
    this.isDraft = false,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;

  /// Sequential integer used for ordering and generating [numberFormatted].
  final int number;

  /// Display number, e.g. `INV-000018`.
  final String numberFormatted;

  final String customerId;
  final String customerName;
  final String customerAddress;

  final String? jobId;
  final String jobTitle;
  final String workDescription;

  final List<LineItem> items;
  final DateTime? issueDate;
  final DateTime? dueDate;

  final double amountPaid;
  final bool isDraft;
  final String notes;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ---- Derived values ----

  DocumentTotals get totals => items.totals;
  double get grandTotal => totals.grandTotal;
  double get balanceDue => Calc.round2(Calc.nonNegative(grandTotal - amountPaid));

  /// Payment status, recomputed from amounts and due date.
  InvoiceStatus get status {
    if (isDraft) return InvoiceStatus.draft;
    if (grandTotal > 0 && amountPaid >= grandTotal) return InvoiceStatus.paid;
    if (amountPaid > 0) return InvoiceStatus.partiallyPaid;
    // No payment yet — overdue if past the due date.
    if (dueDate != null && DateTime.now().isAfter(dueDate!)) {
      return InvoiceStatus.overdue;
    }
    return InvoiceStatus.unpaid;
  }

  bool get isPaid => status == InvoiceStatus.paid;

  Invoice copyWith({
    int? number,
    String? numberFormatted,
    String? customerId,
    String? customerName,
    String? customerAddress,
    String? jobId,
    String? jobTitle,
    String? workDescription,
    List<LineItem>? items,
    DateTime? issueDate,
    DateTime? dueDate,
    double? amountPaid,
    bool? isDraft,
    String? notes,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id,
      ownerId: ownerId,
      number: number ?? this.number,
      numberFormatted: numberFormatted ?? this.numberFormatted,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      workDescription: workDescription ?? this.workDescription,
      items: items ?? this.items,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      amountPaid: amountPaid ?? this.amountPaid,
      isDraft: isDraft ?? this.isDraft,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Invoice.fromMap(String id, Map<String, dynamic> map) {
    return Invoice(
      id: id,
      ownerId: asString(map['ownerId']),
      number: asInt(map['number']),
      numberFormatted: asString(map['numberFormatted']),
      customerId: asString(map['customerId']),
      customerName: asString(map['customerName']),
      customerAddress: asString(map['customerAddress']),
      jobId: (map['jobId'] as String?),
      jobTitle: asString(map['jobTitle']),
      workDescription: asString(map['workDescription']),
      items: (map['items'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => LineItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      issueDate: tsToDate(map['issueDate']),
      dueDate: tsToDate(map['dueDate']),
      amountPaid: asDouble(map['amountPaid']),
      isDraft: asBool(map['isDraft']),
      notes: asString(map['notes']),
      createdAt: tsToDate(map['createdAt']),
      updatedAt: tsToDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final DocumentTotals t = totals;
    return <String, dynamic>{
      'ownerId': ownerId,
      'number': number,
      'numberFormatted': numberFormatted,
      'customerId': customerId,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'workDescription': workDescription,
      'items': items.map((LineItem e) => e.toMap()).toList(),
      'issueDate': dateToTs(issueDate ?? DateTime.now()),
      'dueDate': dateToTs(dueDate),
      'amountPaid': amountPaid,
      'isDraft': isDraft,
      'notes': notes,
      // Denormalised totals & status: stored so list/report queries don't need
      // to recompute across every embedded item, and so Firestore can filter
      // by status directly.
      'subtotal': t.subtotal,
      'vatTotal': t.vatTotal,
      'grandTotal': t.grandTotal,
      'balanceDue': balanceDue,
      'status': status.name,
      'createdAt': dateToTs(createdAt ?? DateTime.now()),
      'updatedAt': dateToTs(DateTime.now()),
    };
  }
}
