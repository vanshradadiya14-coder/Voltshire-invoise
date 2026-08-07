import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reports whether the device currently has a network path.
///
/// This is deliberately *not* wired into any write path. Firestore's offline
/// persistence already queues writes and replays them on reconnect, so gating
/// saves on connectivity would break a feature that already works. The only
/// consumer is the UI banner, which exists to reassure — not to block.
class ConnectivityService {
  ConnectivityService(this._connectivity);

  final Connectivity _connectivity;

  Stream<bool> watchOnline() async* {
    yield await isOnline();
    yield* _connectivity.onConnectivityChanged.map(_hasPath);
  }

  Future<bool> isOnline() async {
    try {
      return _hasPath(await _connectivity.checkConnectivity());
    } catch (_) {
      // If the plugin fails, assume online — a false "offline" banner is worse
      // than no banner at all.
      return true;
    }
  }

  bool _hasPath(List<ConnectivityResult> results) =>
      results.isNotEmpty &&
      results.any((ConnectivityResult r) => r != ConnectivityResult.none);
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(Connectivity());
});

/// True when the device has a network path. Defaults to online while resolving.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).watchOnline();
});

final isOfflineProvider = Provider<bool>((ref) {
  return ref.watch(isOnlineProvider).valueOrNull == false;
});
