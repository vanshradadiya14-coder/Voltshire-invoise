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
