import '../core/utils/firestore_utils.dart';

/// A business expense (materials, fuel, equipment, labour, skip hire, …).
/// Collection `expenses`.
class Expense {
  const Expense({
    required this.id,
    required this.ownerId,
    required this.category,
    required this.amount,
    this.supplier = '',
    this.description = '',
    this.jobId,
    this.jobTitle = '',
    this.receiptUrl = '',
    this.receiptPath = '',
    this.date,
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final String category;
  final double amount;
  final String supplier;
  final String description;

  /// Optional link to a job so expenses roll up into the profit report.
  final String? jobId;
  final String jobTitle;

  /// Firebase Storage download URL + path (path kept so the file can be deleted).
  final String receiptUrl;
  final String receiptPath;

  final DateTime? date;
  final DateTime? createdAt;

  bool get hasReceipt => receiptUrl.isNotEmpty;

  Expense copyWith({
    String? category,
    double? amount,
    String? supplier,
    String? description,
    String? jobId,
    String? jobTitle,
    String? receiptUrl,
    String? receiptPath,
    DateTime? date,
  }) {
    return Expense(
      id: id,
      ownerId: ownerId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      supplier: supplier ?? this.supplier,
      description: description ?? this.description,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      receiptPath: receiptPath ?? this.receiptPath,
      date: date ?? this.date,
      createdAt: createdAt,
    );
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      ownerId: asString(map['ownerId']),
      category: asString(map['category'], fallback: 'Other'),
      amount: asDouble(map['amount']),
      supplier: asString(map['supplier']),
      description: asString(map['description']),
      jobId: map['jobId'] as String?,
      jobTitle: asString(map['jobTitle']),
      receiptUrl: asString(map['receiptUrl']),
      receiptPath: asString(map['receiptPath']),
      date: tsToDate(map['date']),
      createdAt: tsToDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerId': ownerId,
        'category': category,
        'amount': amount,
        'supplier': supplier,
        'description': description,
        'jobId': jobId,
        'jobTitle': jobTitle,
        'receiptUrl': receiptUrl,
        'receiptPath': receiptPath,
        'date': dateToTs(date ?? DateTime.now()),
        'createdAt': dateToTs(createdAt ?? DateTime.now()),
      };
}
