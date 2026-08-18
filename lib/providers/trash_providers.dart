import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/trash_repository.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

final trashRepositoryProvider = Provider<TrashRepository?>((ref) {
  final String? uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return TrashRepository(ref.watch(firestoreProvider), uid);
});

final trashProvider = StreamProvider<List<TrashedItem>>((ref) {
  final TrashRepository? repo = ref.watch(trashRepositoryProvider);
  if (repo == null) return Stream<List<TrashedItem>>.value(<TrashedItem>[]);
  return repo.watchAll();
});

final trashCountProvider = Provider<int>((ref) {
  return ref.watch(trashProvider).valueOrNull?.length ?? 0;
});

/// Moves a record to the recycle bin instead of destroying it.
///
/// Settings tells the user deleted records are "kept for 30 days", so the
/// delete actions in the app have to honour that. Only records that live
/// purely in Firestore are routed here: photos, receipts and attached
/// documents also own a Storage object, and restoring a document whose file
/// has been deleted would put a broken link back in the list, so those keep a
/// direct delete.
///
/// Returns true when the record was binned. Falls back to `false` when there
/// is no signed-in user, so callers can decide what to do.
Future<bool> trashRecord(
  WidgetRef ref, {
  required String collection,
  required String docId,
  required String label,
}) async {
  final TrashRepository? repo = ref.read(trashRepositoryProvider);
  if (repo == null) return false;
  await repo.moveToTrash(
    collection: collection,
    docId: docId,
    label: label,
  );
  return true;
}
