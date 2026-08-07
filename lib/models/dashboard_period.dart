import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';

/// The time window the dashboard reports on.
enum DashboardRange {
  today('Today'),
  week('This week'),
  month('This month'),
  quarter('This quarter'),
  year('This year'),
  custom('Custom');

  const DashboardRange(this.label);
  final String label;

  /// Short label for the segmented selector.
  String get shortLabel => switch (this) {
        DashboardRange.today => 'Day',
        DashboardRange.week => 'Week',
        DashboardRange.month => 'Month',
        DashboardRange.quarter => 'Quarter',
        DashboardRange.year => 'Year',
        DashboardRange.custom => 'Custom',
      };
}

/// How a time series is bucketed for charting.
enum SeriesGranularity { hour, day, week, month }

/// A resolved date window plus the immediately preceding window of equal
/// length, which is what makes period-over-period deltas possible.
///
/// All boundaries are half-open `[start, end)` so a payment at exactly
/// midnight on the first of the month lands in exactly one bucket.
class DashboardPeriod {
  const DashboardPeriod({
    required this.range,
    required this.start,
    required this.end,
    required this.previousStart,
    required this.previousEnd,
  });

  final DashboardRange range;

  /// Inclusive start of the current window.
  final DateTime start;

  /// Exclusive end of the current window.
  final DateTime end;

  final DateTime previousStart;
  final DateTime previousEnd;

  /// Builds the window for [range] relative to [now].
  factory DashboardPeriod.of(DashboardRange range, {DateTime? now}) {
    final DateTime n = now ?? DateTime.now();
    final DateTime today = DateTime(n.year, n.month, n.day);

    switch (range) {
      case DashboardRange.today:
        return DashboardPeriod._span(range, today, _addDays(today, 1));

      case DashboardRange.week:
        // ISO week: Monday start.
        final DateTime monday =
            _addDays(today, -(today.weekday - DateTime.monday));
        return DashboardPeriod._span(range, monday, _addDays(monday, 7));

      case DashboardRange.month:
        final DateTime start = DateTime(n.year, n.month);
        final DateTime end = DateTime(n.year, n.month + 1);
        return DashboardPeriod(
          range: range,
          start: start,
          end: end,
          // Calendar-aware: the previous month, not "31 days ago".
          previousStart: DateTime(n.year, n.month - 1),
          previousEnd: start,
        );

      case DashboardRange.quarter:
        final int q = ((n.month - 1) ~/ 3);
        final DateTime start = DateTime(n.year, q * 3 + 1);
        final DateTime end = DateTime(n.year, q * 3 + 4);
        return DashboardPeriod(
          range: range,
          start: start,
          end: end,
          previousStart: DateTime(n.year, q * 3 - 2),
          previousEnd: start,
        );

      case DashboardRange.year:
        final DateTime start = DateTime(n.year);
        return DashboardPeriod(
          range: range,
          start: start,
          end: DateTime(n.year + 1),
          previousStart: DateTime(n.year - 1),
          previousEnd: start,
        );

      case DashboardRange.custom:
        // Defaults to the last 30 days until the user picks a range.
        return DashboardPeriod._span(
          range,
          _addDays(today, -29),
          _addDays(today, 1),
        );
    }
  }

  /// Calendar-based day arithmetic.
  ///
  /// `DateTime.add(Duration(days: n))` adds exact 24-hour spans, so crossing a
  /// BST/GMT boundary lands on 23:00 or 01:00 rather than midnight — which
  /// silently drops or double-counts a day's payments twice a year. The
  /// constructor normalises in local time and does not have that problem.
  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days, d.hour, d.minute);

  /// A user-selected window. The comparison window is the equally long span
  /// immediately before it.
  factory DashboardPeriod.custom(DateTime from, DateTime to) {
    final DateTime start = DateTime(from.year, from.month, from.day);
    final DateTime end = DateTime(to.year, to.month, to.day + 1);
    return DashboardPeriod._span(DashboardRange.custom, start, end);
  }

  /// Builds a period whose comparison window covers the same number of days,
  /// immediately prior. Correct for fixed-length ranges (day, week, custom).
  factory DashboardPeriod._span(
    DashboardRange range,
    DateTime start,
    DateTime end,
  ) {
    // Day count, not a Duration: across a DST change the two differ by an hour
    // and the comparison window would start at the wrong time.
    final int dayCount = DateTime(end.year, end.month, end.day)
        .difference(DateTime(start.year, start.month, start.day))
        .inDays
        .clamp(1, 100000);
    return DashboardPeriod(
      range: range,
      start: start,
      end: end,
      previousStart: _addDays(start, -dayCount),
      previousEnd: start,
    );
  }

  Duration get length => end.difference(start);

  /// Whole calendar days in the window. Calendar-based so a DST change does
  /// not report a 30-day month as 29 days and 23 hours.
  int get days => DateTime(end.year, end.month, end.day)
      .difference(DateTime(start.year, start.month, start.day))
      .inDays;

  bool contains(DateTime? date) =>
      date != null && !date.isBefore(start) && date.isBefore(end);

  bool containsPrevious(DateTime? date) =>
      date != null && !date.isBefore(previousStart) && date.isBefore(previousEnd);

  /// Bucket size that yields a readable number of points for this window.
  SeriesGranularity get granularity {
    final int d = days;
    if (d <= 1) return SeriesGranularity.hour;
    if (d <= 31) return SeriesGranularity.day;
    if (d <= 120) return SeriesGranularity.week;
    return SeriesGranularity.month;
  }

  /// What the comparison figure should be called in the UI.
  String get comparisonLabel => switch (range) {
        DashboardRange.today => 'vs yesterday',
        DashboardRange.week => 'vs last week',
        DashboardRange.month => 'vs last month',
        DashboardRange.quarter => 'vs last quarter',
        DashboardRange.year => 'vs last year',
        DashboardRange.custom => 'vs previous period',
      };

  /// Human-readable window, e.g. `1–31 Aug 2026`.
  String get description {
    final DateTime last = _addDays(end, -1);
    final DateFormat dm = DateFormat('d MMM', AppConstants.defaultLocale);
    final DateFormat dmy = DateFormat('d MMM yyyy', AppConstants.defaultLocale);

    if (range == DashboardRange.today) return dmy.format(start);
    if (range == DashboardRange.year) return '${start.year}';
    if (start.year == last.year) {
      return '${dm.format(start)} – ${dmy.format(last)}';
    }
    return '${dmy.format(start)} – ${dmy.format(last)}';
  }

  /// The ordered bucket boundaries for charting this window.
  List<DateTime> buckets() {
    final List<DateTime> out = <DateTime>[];
    switch (granularity) {
      case SeriesGranularity.hour:
        for (int h = 0; h < 24; h++) {
          out.add(DateTime(start.year, start.month, start.day, h));
        }
      case SeriesGranularity.day:
        DateTime d = start;
        while (d.isBefore(end)) {
          out.add(d);
          d = DateTime(d.year, d.month, d.day + 1);
        }
      case SeriesGranularity.week:
        DateTime d = _addDays(start, -(start.weekday - 1));
        while (d.isBefore(end)) {
          out.add(d);
          d = _addDays(d, 7);
        }
      case SeriesGranularity.month:
        DateTime d = DateTime(start.year, start.month);
        while (d.isBefore(end)) {
          out.add(d);
          d = DateTime(d.year, d.month + 1);
        }
    }
    return out;
  }

  /// Index of the bucket [date] belongs to, or -1 when outside the window.
  int bucketIndexOf(DateTime date, List<DateTime> buckets) {
    if (buckets.isEmpty || date.isBefore(buckets.first) || !date.isBefore(end)) {
      return -1;
    }
    for (int i = buckets.length - 1; i >= 0; i--) {
      if (!date.isBefore(buckets[i])) return i;
    }
    return -1;
  }

  /// Axis label for a bucket.
  String bucketLabel(DateTime bucket) => switch (granularity) {
        SeriesGranularity.hour =>
          DateFormat('HH', AppConstants.defaultLocale).format(bucket),
        SeriesGranularity.day =>
          DateFormat('d', AppConstants.defaultLocale).format(bucket),
        SeriesGranularity.week =>
          DateFormat('d MMM', AppConstants.defaultLocale).format(bucket),
        SeriesGranularity.month =>
          DateFormat('MMM', AppConstants.defaultLocale).format(bucket),
      };

  @override
  bool operator ==(Object other) =>
      other is DashboardPeriod &&
      other.range == range &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(range, start, end);
}
