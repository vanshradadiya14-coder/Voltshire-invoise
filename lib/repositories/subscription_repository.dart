import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../models/subscription.dart';

/// Read-through cache of the user's entitlements in `subscriptions/{uid}`.
///
/// The store (via RevenueCat) is always the source of truth. This cache exists
/// for two situations the SDK cannot cover:
///
///  * **Cold start** — the app knows the tier immediately, before the SDK has
///    finished its network round-trip, so the UI does not flash Free-then-Pro.
///  * **Offline** — a builder on a site with no signal still gets the features
///    they paid for.
///
/// It is deliberately *not* trusted for anything security-sensitive. Firestore
/// rules make this document client-readable but only server-writable in the
/// hardened ruleset, so a user editing it locally gains nothing that survives
/// the next sync.
class SubscriptionRepository {
  SubscriptionRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection(FirestorePaths.subscriptions).doc(_uid);

  /// The cached entitlements, or [Entitlements.free] when nothing is stored.
  Stream<Entitlements> watch() {
    return _doc.snapshots().map((DocumentSnapshot<Map<String, dynamic>> snap) {
      if (!snap.exists || snap.data() == null) return Entitlements.free;
      return Entitlements.fromMap(snap.data()!);
    }).handleError((_) => Entitlements.free);
  }

  Future<Entitlements> fetch() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await _doc.get();
      if (!snap.exists || snap.data() == null) return Entitlements.free;
      return Entitlements.fromMap(snap.data()!);
    } catch (_) {
      return Entitlements.free;
    }
  }

  /// Mirrors the store's answer into Firestore. Never throws — a failed cache
  /// write must not surface as a purchase failure.
  Future<void> cache(Entitlements entitlements) async {
    try {
      await _doc.set(<String, dynamic>{
        ...entitlements.toMap(),
        'ownerId': _uid,
      }, SetOptions(merge: true));
    } catch (_) {
      // Best effort only.
    }
  }

  /// Records the moment the user first saw the paywall, so the app can avoid
  /// re-prompting on every launch.
  Future<void> markPaywallSeen() async {
    try {
      await _doc.set(<String, dynamic>{
        'ownerId': _uid,
        'lastPaywallSeenAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<DateTime?> lastPaywallSeen() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await _doc.get();
      final Object? raw = snap.data()?['lastPaywallSeenAt'];
      return raw is Timestamp ? raw.toDate() : null;
    } catch (_) {
      return null;
    }
  }
}
