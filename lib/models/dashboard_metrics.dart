import 'dashboard_period.dart';

/// A single headline figure with its comparison against the previous window.
class Metric {
  const Metric({
    required this.current,
    required this.previous,
    this.isCurrency = true,
    this.higherIsBetter = true,
  });

  final double current;
  final double previous;

  /// Formats as money when true, as a plain count when false.
  final bool isCurrency;

  /// Whether an increase should read as good. False for things like overdue
  /// balance, where growth is bad news.
  final bool higherIsBetter;

  static const Metric zero = Metric(current: 0, previous: 0);

  double get change => current - previous;

  /// Percentage change, or null when there is no baseline to compare against.
  /// Returning null rather than 0 or infinity matters — "no prior data" and
  /// "no change" are different statements.
  double? get percentChange {
    if (previous.abs() < 0.005) return current.abs() < 0.005 ? 0 : null;
    return (change / previous.abs()) * 100;
  }

  bool get hasComparison => percentChange != null;
  bool get isUp => change > 0.005;
  bool get isDown => change < -0.005;
  bool get isFlat => !isUp && !isDown;

  /// True when the movement is good news for the business.
  bool get isFavourable =>
      isFlat ? true : (isUp == higherIsBetter);

  Metric operator +(Metric other) => Metric(
        current: current + other.current,
        previous: previous + other.previous,
        isCurrency: isCurrency,
        higherIsBetter: higherIsBetter,
      );
}

/// One point in a charted series.
class SeriesPoint {
  const SeriesPoint({
    required this.bucket,
    required this.label,
    required this.value,
  });

  final DateTime bucket;
  final String label;
  final double value;
}

/// A named, charted series.
class ChartSeries {
  const ChartSeries({
    required this.name,
    required this.points,
  });

  final String name;
  final List<SeriesPoint> points;

  static const ChartSeries empty = ChartSeries(name: '', points: <SeriesPoint>[]);

  bool get isEmpty => points.isEmpty || points.every((p) => p.value.abs() < 0.005);

  double get total =>
      points.fold<double>(0, (double s, SeriesPoint p) => s + p.value);

  double get max => points.isEmpty
      ? 0
      : points.map((SeriesPoint p) => p.value).reduce((a, b) => a > b ? a : b);

  double get min => points.isEmpty
      ? 0
      : points.map((SeriesPoint p) => p.value).reduce((a, b) => a < b ? a : b);
}

/// A slice of a categorical breakdown (expenses by category, pipeline stages).
class BreakdownSlice {
  const BreakdownSlice({
    required this.label,
    required this.value,
    required this.count,
  });

  final String label;
  final double value;
  final int count;
}

/// Everything the dashboard's headline tiles need.
class DashboardMetrics {
  const DashboardMetrics({
    required this.period,
    this.revenue = Metric.zero,
    this.expenses = Metric.zero,
    this.profit = Metric.zero,
    this.invoiced = Metric.zero,
    this.outstanding = Metric.zero,
    this.overdue = Metric.zero,
    this.newJobs = Metric.zero,
    this.completedJobs = Metric.zero,
    this.newCustomers = Metric.zero,
    this.quotesSent = Metric.zero,
    this.quotesAccepted = Metric.zero,
    this.activeJobs = 0,
    this.overdueCount = 0,
    this.unpaidCount = 0,
    this.averageInvoiceValue = 0,
    this.collectionRate = 0,
    this.quoteConversionRate = 0,
  });

  final DashboardPeriod period;

  /// Money actually received in the window (payments), not merely invoiced.
  final Metric revenue;
  final Metric expenses;
  final Metric profit;

  /// Total value of invoices issued in the window.
  final Metric invoiced;

  /// Balance still owed across all non-draft invoices (a point-in-time figure,
  /// compared against the same measure at the end of the previous window).
  final Metric outstanding;
  final Metric overdue;

  final Metric newJobs;
  final Metric completedJobs;
  final Metric newCustomers;
  final Metric quotesSent;
  final Metric quotesAccepted;

  final int activeJobs;
  final int overdueCount;
  final int unpaidCount;

  final double averageInvoiceValue;

  /// Received ÷ invoiced within the window, as a percentage.
  final double collectionRate;

  /// Accepted ÷ sent quotes, as a percentage.
  final double quoteConversionRate;

  static DashboardMetrics empty(DashboardPeriod period) =>
      DashboardMetrics(period: period);

  /// Profit margin as a percentage of revenue.
  double get profitMargin =>
      revenue.current.abs() < 0.005 ? 0 : (profit.current / revenue.current) * 100;

  bool get hasAnyActivity =>
      revenue.current != 0 ||
      expenses.current != 0 ||
      invoiced.current != 0 ||
      newJobs.current != 0;
}

/// One actionable item in the action centre.
class ActionItem {
  const ActionItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.count,
    this.amount = 0,
    this.route,
    this.entityId,
  });

  final ActionKind kind;
  final String title;
  final String subtitle;
  final int count;
  final double amount;
  final String? route;
  final String? entityId;
}

/// The categories of work the action centre surfaces.
///
/// Ordered by urgency — the dashboard renders them in declaration order.
enum ActionKind {
  overdueInvoices,
  dueSoon,
  quotesExpiring,
  uninvoicedJobs,
  acceptedQuotesNoJob,
  unpaidBalance;

  /// Severity drives the colour: error, warning or informational.
  ActionSeverity get severity => switch (this) {
        ActionKind.overdueInvoices => ActionSeverity.critical,
        ActionKind.quotesExpiring || ActionKind.dueSoon => ActionSeverity.warning,
        ActionKind.uninvoicedJobs ||
        ActionKind.acceptedQuotesNoJob ||
        ActionKind.unpaidBalance =>
          ActionSeverity.info,
      };
}

enum ActionSeverity { critical, warning, info }
