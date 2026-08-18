import '../core/utils/calculations.dart';
import '../core/utils/firestore_utils.dart';
import 'line_item.dart';
import 'trade_enums.dart';

/// Extra work agreed after a job started. Collection `variations`.
///
/// "While you're here, could you also…" is how builders lose money. The work
/// gets done on a Tuesday, the invoice gets raised three weeks later, and
/// nobody remembers the extra. A variation is a written record of the ask, the
/// price and the answer — and it flows onto the final invoice automatically.
class Variation {
  const Variation({
    required this.id,
    required this.ownerId,
    required this.jobId,
    required this.description,
    this.jobTitle = '',
    this.customerId = '',
    this.amount = 0,
    this.quantity = 1,
    this.category = LineCategory.labour,
    this.vatPercent = 20,
    this.status = VariationStatus.proposed,
    this.requestedBy = '',
    this.notes = '',
    this.approvedAt,
    this.invoiceId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String jobId;
  final String jobTitle;
  final String customerId;

  final String description;

  /// Unit price of the extra work.
  final double amount;
  final double quantity;

  final LineCategory category;
  final double vatPercent;

  final VariationStatus status;

  /// Who asked for it — "Mrs Patel", "site manager". Useful when the bill is
  /// later queried by somebody who was not on site.
  final String requestedBy;

  final String notes;
  final DateTime? approvedAt;

  /// Set once this has been rolled onto an invoice.
  final String? invoiceId;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Net value before VAT.
  double get netTotal => Calc.round2(quantity * amount);

  double get vatAmount => Calc.round2(netTotal * (vatPercent / 100));

  double get grossTotal => Calc.round2(netTotal + vatAmount);

  /// Agreed but not yet billed — the money most at risk of being forgotten.
  bool get isUnbilled => status == VariationStatus.approved && invoiceId == null;

  /// Converts to a line item for the invoice, tagged so it is obvious on the
  /// document that this was extra to the original scope.
  LineItem toLineItem() => LineItem(
        description: 'Variation — $description',
        quantity: quantity,
        unitPrice: amount,
        vatPercent: vatPercent,
        category: category,
      );

  Variation copyWith({
    String? description,
    double? amount,
    double? quantity,
    LineCategory? category,
    double? vatPercent,
    VariationStatus? status,
    String? requestedBy,
    String? notes,
    DateTime? approvedAt,
    String? invoiceId,
    DateTime? updatedAt,
  }) {
    return Variation(
      id: id,
      ownerId: ownerId,
      jobId: jobId,
      jobTitle: jobTitle,
      customerId: customerId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      vatPercent: vatPercent ?? this.vatPercent,
      status: status ?? this.status,
      requestedBy: requestedBy ?? this.requestedBy,
      notes: notes ?? this.notes,
      approvedAt: approvedAt ?? this.approvedAt,
      invoiceId: invoiceId ?? this.invoiceId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Variation.fromMap(String id, Map<String, dynamic> map) {
    return Variation(
      id: id,
      ownerId: asString(map['ownerId']),
      jobId: asString(map['jobId']),
      jobTitle: asString(map['jobTitle']),
      customerId: asString(map['customerId']),
      description: asString(map['description']),
      amount: asDouble(map['amount']),
      quantity: asDouble(map['quantity'], fallback: 1),
      category: LineCategory.fromName(map['category'] as String?),
      vatPercent: asDouble(map['vatPercent'], fallback: 20),
      status: VariationStatus.fromName(map['status'] as String?),
      requestedBy: asString(map['requestedBy']),
      notes: asString(map['notes']),
      approvedAt: tsToDate(map['approvedAt']),
      invoiceId: map['invoiceId'] as String?,
      createdAt: tsToDate(map['createdAt']),
      updatedAt: tsToDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerId': ownerId,
        'jobId': jobId,
        'jobTitle': jobTitle,
        'customerId': customerId,
        'description': description,
        'amount': amount,
        'quantity': quantity,
        'category': category.name,
        'vatPercent': vatPercent,
        'status': status.name,
        'requestedBy': requestedBy,
        'notes': notes,
        'approvedAt': dateToTs(approvedAt),
        'invoiceId': invoiceId,
        'netTotal': netTotal,
        'grossTotal': grossTotal,
        'createdAt': dateToTs(createdAt ?? DateTime.now()),
        'updatedAt': dateToTs(DateTime.now()),
      };
}

/// Aggregates for a job's variations.
extension VariationTotals on List<Variation> {
  double get approvedNet => where((Variation v) =>
          v.status == VariationStatus.approved ||
          v.status == VariationStatus.invoiced)
      .fold<double>(0, (double s, Variation v) => s + v.netTotal);

  double get unbilledNet => where((Variation v) => v.isUnbilled)
      .fold<double>(0, (double s, Variation v) => s + v.netTotal);

  double get proposedNet =>
      where((Variation v) => v.status == VariationStatus.proposed)
          .fold<double>(0, (double s, Variation v) => s + v.netTotal);

  List<Variation> get unbilled =>
      where((Variation v) => v.isUnbilled).toList();
}
