import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/dashboard_layout.dart';

/// Persists the user's dashboard arrangement to device storage.
///
/// Writes are fire-and-forget: a failed preference write should never surface
/// as an error while someone is dragging a card around.
class DashboardLayoutController extends StateNotifier<DashboardLayout> {
  DashboardLayoutController() : super(DashboardLayout.defaults) {
    _load();
  }

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      state = DashboardLayout.decode(
        prefs.getString(AppConstants.prefDashboardOrder),
        prefs.getString(AppConstants.prefDashboardHidden),
      );
    } catch (_) {
      state = DashboardLayout.defaults;
    }
  }

  Future<void> _save() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          AppConstants.prefDashboardOrder, state.encodeOrder());
      await prefs.setString(
          AppConstants.prefDashboardHidden, state.encodeHidden());
    } catch (_) {}
  }

  void reorder(int oldIndex, int newIndex) {
    state = state.reorder(oldIndex, newIndex);
    _save();
  }

  void toggle(DashboardSection section) {
    state = state.toggle(section);
    _save();
  }

  void reset() {
    state = DashboardLayout.defaults;
    _save();
  }
}

final dashboardLayoutProvider =
    StateNotifierProvider<DashboardLayoutController, DashboardLayout>((ref) {
  return DashboardLayoutController();
});
