import '../core/utils/firestore_utils.dart';
import 'enums.dart';

/// A job/project for a customer. Collection `jobs`.
///
/// Denormalises `customerName` so job lists render without an extra read.
class Job {
  const Job({
    required this.id,
    required this.ownerId,
    required this.customerId,
    required this.customerName,
    required this.title,
    this.siteAddress = '',
    this.description = '',
    this.status = JobStatus.quote,
    this.startDate,
    this.completionDate,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String customerId;
  final String customerName;
  final String title;
  final String siteAddress;
  final String description;
  final JobStatus status;
  final DateTime? startDate;
  final DateTime? completionDate;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Job copyWith({
    String? customerId,
    String? customerName,
    String? title,
    String? siteAddress,
    String? description,
    JobStatus? status,
    DateTime? startDate,
    DateTime? completionDate,
    bool clearStartDate = false,
    bool clearCompletionDate = false,
    String? notes,
    DateTime? updatedAt,
  }) {
    return Job(
      id: id,
      ownerId: ownerId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      title: title ?? this.title,
      siteAddress: siteAddress ?? this.siteAddress,
      description: description ?? this.description,
      status: status ?? this.status,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      completionDate:
          clearCompletionDate ? null : (completionDate ?? this.completionDate),
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Job.fromMap(String id, Map<String, dynamic> map) {
    return Job(
      id: id,
      ownerId: asString(map['ownerId']),
      customerId: asString(map['customerId']),
      customerName: asString(map['customerName']),
      title: asString(map['title']),
      siteAddress: asString(map['siteAddress']),
      description: asString(map['description']),
      status: JobStatus.fromName(asString(map['status'])),
      startDate: tsToDate(map['startDate']),
      completionDate: tsToDate(map['completionDate']),
      notes: asString(map['notes']),
      createdAt: tsToDate(map['createdAt']),
      updatedAt: tsToDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerId': ownerId,
        'customerId': customerId,
        'customerName': customerName,
        'title': title,
        'siteAddress': siteAddress,
        'description': description,
        'status': status.name,
        'startDate': dateToTs(startDate),
        'completionDate': dateToTs(completionDate),
        'notes': notes,
        'createdAt': dateToTs(createdAt ?? DateTime.now()),
        'updatedAt': dateToTs(DateTime.now()),
      };
}
