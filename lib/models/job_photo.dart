import '../core/utils/firestore_utils.dart';

/// A photo attached to a job (before/progress/completed). Collection `photos`.
class JobPhoto {
  const JobPhoto({
    required this.id,
    required this.ownerId,
    required this.jobId,
    required this.url,
    required this.storagePath,
    this.category = 'Progress',
    this.caption = '',
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final String jobId;
  final String url;
  final String storagePath;
  final String category;
  final String caption;
  final DateTime? createdAt;

  factory JobPhoto.fromMap(String id, Map<String, dynamic> map) {
    return JobPhoto(
      id: id,
      ownerId: asString(map['ownerId']),
      jobId: asString(map['jobId']),
      url: asString(map['url']),
      storagePath: asString(map['storagePath']),
      category: asString(map['category'], fallback: 'Progress'),
      caption: asString(map['caption']),
      createdAt: tsToDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerId': ownerId,
        'jobId': jobId,
        'url': url,
        'storagePath': storagePath,
        'category': category,
        'caption': caption,
        'createdAt': dateToTs(createdAt ?? DateTime.now()),
      };
}
