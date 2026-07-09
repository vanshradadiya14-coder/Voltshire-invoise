import '../core/utils/firestore_utils.dart';

/// A stored document (contract, certificate, guarantee, planning doc, receipt,
/// invoice, …). Collection `documents`.
class DocumentFile {
  const DocumentFile({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.url,
    required this.storagePath,
    this.category = 'Other',
    this.contentType = '',
    this.sizeBytes = 0,
    this.jobId,
    this.customerId,
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String url;
  final String storagePath;
  final String category;
  final String contentType;
  final int sizeBytes;

  /// Optional links so a document can be filtered by job or customer.
  final String? jobId;
  final String? customerId;

  final DateTime? createdAt;

  bool get isImage => contentType.startsWith('image/');
  bool get isPdf => contentType == 'application/pdf' ||
      name.toLowerCase().endsWith('.pdf');

  factory DocumentFile.fromMap(String id, Map<String, dynamic> map) {
    return DocumentFile(
      id: id,
      ownerId: asString(map['ownerId']),
      name: asString(map['name']),
      url: asString(map['url']),
      storagePath: asString(map['storagePath']),
      category: asString(map['category'], fallback: 'Other'),
      contentType: asString(map['contentType']),
      sizeBytes: asInt(map['sizeBytes']),
      jobId: map['jobId'] as String?,
      customerId: map['customerId'] as String?,
      createdAt: tsToDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerId': ownerId,
        'name': name,
        'url': url,
        'storagePath': storagePath,
        'category': category,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
        'jobId': jobId,
        'customerId': customerId,
        'createdAt': dateToTs(createdAt ?? DateTime.now()),
      };
}
