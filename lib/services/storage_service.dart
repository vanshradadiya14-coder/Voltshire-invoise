import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../core/errors/app_exception.dart';

/// Result of an upload: the public download URL and the storage path (kept so
/// the object can later be deleted).
class UploadResult {
  const UploadResult({required this.url, required this.path, this.sizeBytes = 0});
  final String url;
  final String path;
  final int sizeBytes;
}

/// Wraps Firebase Storage uploads/deletes.
class StorageService {
  StorageService(this._storage);

  final FirebaseStorage _storage;

  /// Uploads a local [file] to [folder], returning the download URL & path.
  /// A unique filename is generated to avoid collisions.
  Future<UploadResult> uploadFile({
    required String folder,
    required File file,
    String? fileName,
    String? contentType,
  }) async {
    try {
      final String name = fileName ??
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.pathSeparator).last}';
      final Reference ref = _storage.ref('$folder/$name');
      final TaskSnapshot snap = await ref.putFile(
        file,
        contentType != null ? SettableMetadata(contentType: contentType) : null,
      );
      final String url = await snap.ref.getDownloadURL();
      return UploadResult(url: url, path: snap.ref.fullPath, sizeBytes: snap.totalBytes);
    } on FirebaseException catch (e) {
      throw AppException('Upload failed: ${e.message}', code: e.code, cause: e);
    }
  }

  /// Uploads raw [bytes] (used for the company logo captured from the picker).
  Future<UploadResult> uploadBytes({
    required String path,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final Reference ref = _storage.ref(path);
      final TaskSnapshot snap =
          await ref.putData(bytes, SettableMetadata(contentType: contentType));
      final String url = await snap.ref.getDownloadURL();
      return UploadResult(url: url, path: snap.ref.fullPath, sizeBytes: snap.totalBytes);
    } on FirebaseException catch (e) {
      throw AppException('Upload failed: ${e.message}', code: e.code, cause: e);
    }
  }

  /// Deletes an object by its full storage [path]. Silently ignores a missing
  /// object so deleting a parent record never fails on a stale reference.
  Future<void> delete(String path) async {
    if (path.isEmpty) return;
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      throw AppException('Could not delete file: ${e.message}', code: e.code, cause: e);
    }
  }
}
