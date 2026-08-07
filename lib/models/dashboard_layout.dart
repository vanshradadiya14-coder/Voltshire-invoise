import 'package:flutter/material.dart';

/// The sections a user can reorder or hide on the dashboard.
enum DashboardSection {
  hero(
    'Headline',
    'Revenue for the period with comparison',
    Icons.trending_up,
  ),
  actions(
    'Action centre',
    'Overdue invoices, expiring quotes, unbilled work',
    Icons.notifications_active_outlined,
  ),
  metrics(
    'Key figures',
    'Profit, outstanding, jobs, customers',
    Icons.grid_view_outlined,
  ),
  revenueChart(
    'Revenue trend',
    'Running total across the period',
    Icons.show_chart,
  ),
  cashFlow(
    'Cash flow',
    'Money in against money out',
    Icons.bar_chart,
  ),
  pipeline(
    'Job pipeline',
    'Jobs by stage with value',
    Icons.filter_alt_outlined,
  ),
  expenses(
    'Expense breakdown',
    'Where the money went, by category',
    Icons.pie_chart_outline,
  ),
  topCustomers(
    'Top customers',
    'Biggest payers this period',
    Icons.leaderboard_outlined,
  ),
  recentJobs(
    'Recent jobs',
    'Latest five jobs',
    Icons.construction_outlined,
  ),
  recentInvoices(
    'Recent invoices',
    'Latest five invoices',
    Icons.receipt_long_outlined,
  );

  const DashboardSection(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;

  /// Sections that stay put — hiding the action centre would defeat the point
  /// of the dashboard, so it is not user-removable.
  bool get isLocked => this == DashboardSection.actions;

  static DashboardSection? fromName(String name) {
    for (final DashboardSection s in DashboardSection.values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// A user's dashboard arrangement: order plus visibility.
///
/// Persisted to `SharedPreferences` rather than Firestore — a layout preference
/// is device-local, changes often, and does not warrant a network write or a
/// document read on every cold start.
class DashboardLayout {
  const DashboardLayout({required this.order, required this.hidden});

  /// Section order, top to bottom.
  final List<DashboardSection> order;

  /// Sections the user has switched off.
  final Set<DashboardSection> hidden;

  static const DashboardLayout defaults = DashboardLayout(
    order: <DashboardSection>[
      DashboardSection.hero,
      DashboardSection.actions,
      DashboardSection.metrics,
      DashboardSection.revenueChart,
      DashboardSection.cashFlow,
      DashboardSection.pipeline,
      DashboardSection.expenses,
      DashboardSection.topCustomers,
      DashboardSection.recentJobs,
      DashboardSection.recentInvoices,
    ],
    hidden: <DashboardSection>{},
  );

  /// The sections to actually render, in order.
  List<DashboardSection> get visible =>
      order.where((DashboardSection s) => !hidden.contains(s)).toList();

  bool isVisible(DashboardSection s) => !hidden.contains(s);

  DashboardLayout copyWith({
    List<DashboardSection>? order,
    Set<DashboardSection>? hidden,
  }) {
    return DashboardLayout(
      order: order ?? this.order,
      hidden: hidden ?? this.hidden,
    );
  }

  DashboardLayout toggle(DashboardSection s) {
    if (s.isLocked) return this;
    final Set<DashboardSection> next = <DashboardSection>{...hidden};
    if (!next.remove(s)) next.add(s);
    return copyWith(hidden: next);
  }

  DashboardLayout reorder(int oldIndex, int newIndex) {
    final List<DashboardSection> next = <DashboardSection>[...order];
    // ReorderableListView reports the target index before the item is removed.
    final int target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    next.insert(target, next.removeAt(oldIndex));
    return copyWith(order: next);
  }

  /// Serialised as two delimited strings — compact, human-readable in prefs,
  /// and trivially forward-compatible: unknown names are simply dropped.
  String encodeOrder() => order.map((DashboardSection s) => s.name).join(',');
  String encodeHidden() => hidden.map((DashboardSection s) => s.name).join(',');

  factory DashboardLayout.decode(String? orderCsv, String? hiddenCsv) {
    final List<DashboardSection> parsed = <DashboardSection>[];
    for (final String name in (orderCsv ?? '').split(',')) {
      final DashboardSection? s = DashboardSection.fromName(name.trim());
      if (s != null && !parsed.contains(s)) parsed.add(s);
    }
    // Append any section added by a newer app version, so an upgrade never
    // silently hides a new feature.
    for (final DashboardSection s in DashboardLayout.defaults.order) {
      if (!parsed.contains(s)) parsed.add(s);
    }

    final Set<DashboardSection> hidden = <DashboardSection>{};
    for (final String name in (hiddenCsv ?? '').split(',')) {
      final DashboardSection? s = DashboardSection.fromName(name.trim());
      if (s != null && !s.isLocked) hidden.add(s);
    }

    return DashboardLayout(order: parsed, hidden: hidden);
  }
}
