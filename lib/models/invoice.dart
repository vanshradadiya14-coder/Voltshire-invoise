import '../core/utils/calculations.dart';
import '../core/utils/firestore_utils.dart';
import '../core/utils/settlement.dart';
import 'enums.dart';
import 'line_item.dart';
import 'trade_enums.dart';

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
    this.cisStatus = CisStatus.notApplicable,
    this.reverseCharge = false,
    this.stageId,
    this.stageLabel = '',
    this.remindersSent = 0,
    this.lastReminderAt,
    this.lastReminderStage,
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

  // ---- Trade / tax ------------------------------------------------------
  // Copied from the customer at creation time rather than read live, so a
  // historic invoice keeps the treatment it was actually issued under even if
  // the customer's settings change later. Re-deriving it would silently
  // restate what a customer was billed.

  final CisStatus cisStatus;
  final bool reverseCharge;

  /// Set when this invoice bills a scheduled payment stage on a job.
  final String? stageId;
  final String stageLabel;

  // ---- Chase history ----------------------------------------------------

  final int remindersSent;
  final DateTime? lastReminderAt;
  final ReminderStage? lastReminderStage;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ---- Derived values ----

  DocumentTotals get totals => items.totals;

  /// The full UK-construction settlement: labour/materials split, VAT or
  /// reverse charge, and any CIS deduction.
  Settlement get settlement => Settlement.of(
        items,
        cis: cisStatus,
        reverseCharge: reverseCharge,
      );

  /// The value of the work — subtotal plus VAT actually charged.
  ///
  /// This stays the revenue figure even when CIS is withheld: the money was
  /// earned, it was just paid to HMRC on the builder's behalf rather than into
  /// the bank. Reporting [amountDue] as revenue would understate turnover.
  double get grandTotal => settlement.grossTotal;

  /// What the customer actually transfers, after any CIS deduction.
  double get amountDue => settlement.amountDue;

  /// Outstanding balance, measured against what the customer owes.
  double get balanceDue => Calc.round2(Calc.nonNegative(amountDue - amountPaid));

  /// True when the settlement differs from a plain subtotal + VAT.
  bool get hasTaxAdjustments => settlement.isAdjusted;

  /// Whole days past the due date, or 0 when not overdue.
  int get daysOverdue {
    if (dueDate == null || balanceDue <= 0.005) return 0;
    final DateTime today = DateTime.now();
    final int days = DateTime(today.year, today.month, today.day)
        .difference(DateTime(dueDate!.year, dueDate!.month, dueDate!.day))
        .inDays;
    return days > 0 ? days : 0;
  }

  bool get isOverdue => daysOverdue > 0;

  /// How firmly to chase, based on how late it is.
  ReminderStage get suggestedReminder =>
      ReminderStage.suggestedFor(daysOverdue);

  /// Payment status, recomputed from amounts and due date.
  InvoiceStatus get status {
    if (isDraft) return InvoiceStatus.draft;
    // Settled against what the customer owes, not the gross value — otherwise
    // a CIS invoice paid in full would never show as paid, because the
    // withheld tax never arrives in the bank.
    if (amountDue > 0 && amountPaid >= amountDue - 0.005) {
      return InvoiceStatus.paid;
    }
    if (amountPaid > 0) return InvoiceStatus.partiallyPaid;
    // No payment yet — overdue if past the due date.
    if (dueDate != null && DateTime.now().isAfter(dueDate!)) {
      return InvoiceStatus.overdue;
    }
    return InvoiceStatus.unpaid;
  }

  bool get isPaid => status == InvoiceStatus.paid;

  Invoice copyWith({
    String? id,
    String? ownerId,
    DateTime? createdAt,
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
    CisStatus? cisStatus,
    bool? reverseCharge,
    String? stageId,
    String? stageLabel,
    int? remindersSent,
    DateTime? lastReminderAt,
    ReminderStage? lastReminderStage,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
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
      cisStatus: cisStatus ?? this.cisStatus,
      reverseCharge: reverseCharge ?? this.reverseCharge,
      stageId: stageId ?? this.stageId,
      stageLabel: stageLabel ?? this.stageLabel,
      remindersSent: remindersSent ?? this.remindersSent,
      lastReminderAt: lastReminderAt ?? this.lastReminderAt,
      lastReminderStage: lastReminderStage ?? this.lastReminderStage,
      createdAt: createdAt ?? this.createdAt,
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
      cisStatus: CisStatus.fromName(map['cisStatus'] as String?),
      reverseCharge: asBool(map['reverseCharge']),
      stageId: map['stageId'] as String?,
      stageLabel: asString(map['stageLabel']),
      remindersSent: asInt(map['remindersSent']),
      lastReminderAt: tsToDate(map['lastReminderAt']),
      lastReminderStage: map['lastReminderStage'] == null
          ? null
          : ReminderStage.fromName(map['lastReminderStage'] as String?),
      createdAt: tsToDate(map['createdAt']),
      updatedAt: tsToDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final Settlement s = settlement;
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
      'cisStatus': cisStatus.name,
      'reverseCharge': reverseCharge,
      'stageId': stageId,
      'stageLabel': stageLabel,
      'remindersSent': remindersSent,
      'lastReminderAt': dateToTs(lastReminderAt),
      'lastReminderStage': lastReminderStage?.name,
      // Denormalised totals & status: stored so list/report queries don't need
      // to recompute across every embedded item, and so Firestore can filter
      // by status directly.
      'subtotal': s.subtotal,
      'labourNet': s.labourNet,
      'materialsNet': s.materialsNet,
      'vatTotal': s.vatCharged,
      'vatReverseCharged': s.vatReverseCharged,
      'cisDeduction': s.cisDeduction,
      'grandTotal': s.grossTotal,
      'amountDue': s.amountDue,
      'balanceDue': balanceDue,
      'status': status.name,
      'createdAt': dateToTs(createdAt ?? DateTime.now()),
      'updatedAt': dateToTs(DateTime.now()),
    };
  }
}
