import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';

/// Singleton Firebase SDK instances, exposed as providers so they can be
/// overridden in tests.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final firebaseStorageProvider =
    Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

/// Stateless services.
final authServiceProvider =
    Provider<AuthService>((ref) => AuthService(ref.watch(firebaseAuthProvider)));

final storageServiceProvider =
    Provider<StorageService>((ref) => StorageService(ref.watch(firebaseStorageProvider)));

final shareServiceProvider = Provider<ShareService>((ref) => const ShareService());
