import '../core/utils/firestore_utils.dart';

/// A payment recorded against an invoice. Collection `payments`.
class Payment {
  const Payment({
    required this.id,
    required this.ownerId,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.customerName,
    required this.amount,
    this.method = 'Bank Transfer',
    this.reference = '',
    this.date,
    this.notes = '',
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final String invoiceId;
  final String invoiceNumber;
  final String customerName;
  final double amount;
  final String method;
  final String reference;
  final DateTime? date;
  final String notes;
  final DateTime? createdAt;

  Payment copyWith({
    double? amount,
    String? method,
    String? reference,
    DateTime? date,
    String? notes,
  }) {
    return Payment(
      id: id,
      ownerId: ownerId,
      invoiceId: invoiceId,
      invoiceNumber: invoiceNumber,
      customerName: customerName,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      reference: reference ?? this.reference,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  factory Payment.fromMap(String id, Map<String, dynamic> map) {
    return Payment(
      id: id,
      ownerId: asString(map['ownerId']),
      invoiceId: asString(map['invoiceId']),
      invoiceNumber: asString(map['invoiceNumber']),
      customerName: asString(map['customerName']),
      amount: asDouble(map['amount']),
      method: asString(map['method'], fallback: 'Bank Transfer'),
      reference: asString(map['reference']),
      date: tsToDate(map['date']),
      notes: asString(map['notes']),
      createdAt: tsToDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerId': ownerId,
        'invoiceId': invoiceId,
        'invoiceNumber': invoiceNumber,
        'customerName': customerName,
        'amount': amount,
        'method': method,
        'reference': reference,
        'date': dateToTs(date ?? DateTime.now()),
        'notes': notes,
        'createdAt': dateToTs(createdAt ?? DateTime.now()),
      };
}
