import '../core/utils/calculations.dart';
import '../core/utils/firestore_utils.dart';
import 'enums.dart';
import 'line_item.dart';

/// A quotation. Collection `quotes`. Mirrors [Invoice] closely so a quote can
/// be converted into an invoice in one step.
class Quote {
  const Quote({
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
    this.validUntil,
    this.status = QuoteStatus.draft,
    this.notes = '',
    this.convertedInvoiceId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final int number;
  final String numberFormatted;

  final String customerId;
  final String customerName;
  final String customerAddress;

  final String? jobId;
  final String jobTitle;
  final String workDescription;

  final List<LineItem> items;
  final DateTime? issueDate;
  final DateTime? validUntil;
  final QuoteStatus status;
  final String notes;

  /// Set once the quote has been converted to an invoice.
  final String? convertedInvoiceId;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  DocumentTotals get totals => items.totals;
  double get grandTotal => totals.grandTotal;

  bool get isExpired =>
      validUntil != null &&
      status != QuoteStatus.accepted &&
      status != QuoteStatus.converted &&
      DateTime.now().isAfter(validUntil!);

  Quote copyWith({
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
    DateTime? validUntil,
    QuoteStatus? status,
    String? notes,
    String? convertedInvoiceId,
    DateTime? updatedAt,
  }) {
    return Quote(
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
      validUntil: validUntil ?? this.validUntil,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      convertedInvoiceId: convertedInvoiceId ?? this.convertedInvoiceId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Quote.fromMap(String id, Map<String, dynamic> map) {
    return Quote(
      id: id,
      ownerId: asString(map['ownerId']),
      number: asInt(map['number']),
      numberFormatted: asString(map['numberFormatted']),
      customerId: asString(map['customerId']),
      customerName: asString(map['customerName']),
      customerAddress: asString(map['customerAddress']),
      jobId: map['jobId'] as String?,
      jobTitle: asString(map['jobTitle']),
      workDescription: asString(map['workDescription']),
      items: (map['items'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => LineItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      issueDate: tsToDate(map['issueDate']),
      validUntil: tsToDate(map['validUntil']),
      status: QuoteStatus.fromName(asString(map['status'])),
      notes: asString(map['notes']),
      convertedInvoiceId: map['convertedInvoiceId'] as String?,
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
      'validUntil': dateToTs(validUntil),
      'status': status.name,
      'notes': notes,
      'convertedInvoiceId': convertedInvoiceId,
      'subtotal': t.subtotal,
      'vatTotal': t.vatTotal,
      'grandTotal': t.grandTotal,
      'createdAt': dateToTs(createdAt ?? DateTime.now()),
      'updatedAt': dateToTs(DateTime.now()),
    };
  }
}
