import 'package:builder_crm/models/dashboard_metrics.dart';
import 'package:builder_crm/models/dashboard_period.dart';
import 'package:flutter_test/flutter_test.dart';

/// Period boundaries decide which payments land in "this month". Off-by-one
/// here means the dashboard quietly reports the wrong revenue, which is worse
/// than crashing — nobody notices.
void main() {
  group('month window', () {
    final DashboardPeriod p = DashboardPeriod.of(
      DashboardRange.month,
      now: DateTime(2026, 8, 14, 10, 30),
    );

    test('spans the calendar month', () {
      expect(p.start, DateTime(2026, 8, 1));
      expect(p.end, DateTime(2026, 9, 1));
    });

    test('compares against the previous calendar month, not 30 days', () {
      expect(p.previousStart, DateTime(2026, 7, 1));
      expect(p.previousEnd, DateTime(2026, 8, 1));
    });

    test('boundaries are half-open so no date is counted twice', () {
      expect(p.contains(DateTime(2026, 8, 1)), isTrue);
      expect(p.contains(DateTime(2026, 8, 31, 23, 59, 59)), isTrue);
      expect(p.contains(DateTime(2026, 9, 1)), isFalse);
      expect(p.contains(DateTime(2026, 7, 31, 23, 59)), isFalse);
    });

    test('the previous window ends exactly where the current begins', () {
      expect(p.containsPrevious(DateTime(2026, 7, 31, 23, 59)), isTrue);
      expect(p.containsPrevious(DateTime(2026, 8, 1)), isFalse);
      expect(p.previousEnd, p.start);
    });

    test('null dates are never in any window', () {
      expect(p.contains(null), isFalse);
      expect(p.containsPrevious(null), isFalse);
    });
  });

  group('year boundaries', () {
    test('January compares against December of the previous year', () {
      final DashboardPeriod p = DashboardPeriod.of(
        DashboardRange.month,
        now: DateTime(2026, 1, 15),
      );
      expect(p.start, DateTime(2026, 1, 1));
      expect(p.previousStart, DateTime(2025, 12, 1));
      expect(p.previousEnd, DateTime(2026, 1, 1));
    });

    test('December rolls the end into the next year', () {
      final DashboardPeriod p = DashboardPeriod.of(
        DashboardRange.month,
        now: DateTime(2026, 12, 3),
      );
      expect(p.end, DateTime(2027, 1, 1));
    });
  });

  group('quarters', () {
    test('Q3 is Jul–Sep and compares against Q2', () {
      final DashboardPeriod p = DashboardPeriod.of(
        DashboardRange.quarter,
        now: DateTime(2026, 8, 14),
      );
      expect(p.start, DateTime(2026, 7, 1));
      expect(p.end, DateTime(2026, 10, 1));
      expect(p.previousStart, DateTime(2026, 4, 1));
    });

    test('Q1 compares against Q4 of the previous year', () {
      final DashboardPeriod p = DashboardPeriod.of(
        DashboardRange.quarter,
        now: DateTime(2026, 2, 10),
      );
      expect(p.start, DateTime(2026, 1, 1));
      expect(p.end, DateTime(2026, 4, 1));
      expect(p.previousStart, DateTime(2025, 10, 1));
      expect(p.previousEnd, DateTime(2026, 1, 1));
    });
  });

  group('week', () {
    test('starts on Monday (ISO), not Sunday', () {
      // 14 Aug 2026 is a Friday.
      final DashboardPeriod p = DashboardPeriod.of(
        DashboardRange.week,
        now: DateTime(2026, 8, 14),
      );
      expect(p.start.weekday, DateTime.monday);
      expect(p.start, DateTime(2026, 8, 10));
      expect(p.end, DateTime(2026, 8, 17));
      expect(p.days, 7);
    });

    test('a Monday is the first day of its own week', () {
      final DashboardPeriod p = DashboardPeriod.of(
        DashboardRange.week,
        now: DateTime(2026, 8, 10),
      );
      expect(p.start, DateTime(2026, 8, 10));
    });

    test('a Sunday belongs to the week that began the previous Monday', () {
      final DashboardPeriod p = DashboardPeriod.of(
        DashboardRange.week,
        now: DateTime(2026, 8, 16),
      );
      expect(p.start, DateTime(2026, 8, 10));
    });
  });

  group('DST safety', () {
    // UK clocks change on the last Sunday of March and October. Day arithmetic
    // done with Duration would land on 23:00 or 01:00 and misbucket payments.
    test('a week spanning the spring change is still seven whole days', () {
      final DashboardPeriod p = DashboardPeriod.of(
        DashboardRange.week,
        now: DateTime(2026, 3, 30),
      );
      expect(p.start.hour, 0);
      expect(p.end.hour, 0);
      expect(p.days, 7);
    });

    test('a week spanning the autumn change is still seven whole days', () {
      final DashboardPeriod p = DashboardPeriod.of(
        DashboardRange.week,
        now: DateTime(2026, 10, 26),
      );
      expect(p.start.hour, 0);
      expect(p.end.hour, 0);
      expect(p.days, 7);
    });

    test('a month containing a clock change reports whole days', () {
      final DashboardPeriod p = DashboardPeriod.of(
        DashboardRange.month,
        now: DateTime(2026, 3, 15),
      );
      expect(p.days, 31);
    });
  });

  group('bucketing', () {
    test('granularity scales with window length', () {
      expect(DashboardPeriod.of(DashboardRange.today).granularity,
          SeriesGranularity.hour);
      expect(
        DashboardPeriod.of(DashboardRange.month, now: DateTime(2026, 8, 14))
            .granularity,
        SeriesGranularity.day,
      );
      expect(
        DashboardPeriod.of(DashboardRange.year, now: DateTime(2026, 8, 14))
            .granularity,
        SeriesGranularity.month,
      );
    });

    test('a month produces one bucket per day', () {
      final DashboardPeriod p = DashboardPeriod.of(
        DashboardRange.month,
        now: DateTime(2026, 8, 14),
      );
      expect(p.buckets().length, 31);
    });

    test('February 2028 produces 29 buckets', () {
      final DashboardPeriod p = DashboardPeriod.of(
        DashboardRange.month,
        now: DateTime(2028, 2, 10),
      );
      expect(p.buckets().length, 29);
    });

    test('a year produces twelve monthly buckets', () {
      final DashboardPeriod p = DashboardPeriod.of(
        DashboardRange.year,
        now: DateTime(2026, 8, 14),
      );
      expect(p.buckets().length, 12);
    });

    test('every date in the window maps to exactly one bucket', () {
      final DashboardPeriod p = DashboardPeriod.of(
        DashboardRange.month,
        now: DateTime(2026, 8, 14),
      );
      final List<DateTime> buckets = p.buckets();

      expect(p.bucketIndexOf(DateTime(2026, 8, 1, 9), buckets), 0);
      expect(p.bucketIndexOf(DateTime(2026, 8, 15, 23, 59), buckets), 14);
      expect(p.bucketIndexOf(DateTime(2026, 8, 31, 12), buckets), 30);
    });

    test('dates outside the window return -1', () {
      final DashboardPeriod p = DashboardPeriod.of(
        DashboardRange.month,
        now: DateTime(2026, 8, 14),
      );
      final List<DateTime> buckets = p.buckets();
      expect(p.bucketIndexOf(DateTime(2026, 7, 31), buckets), -1);
      expect(p.bucketIndexOf(DateTime(2026, 9, 1), buckets), -1);
    });
  });

  group('custom range', () {
    test('is inclusive of both endpoints', () {
      final DashboardPeriod p =
          DashboardPeriod.custom(DateTime(2026, 6, 1), DateTime(2026, 6, 30));
      expect(p.contains(DateTime(2026, 6, 1)), isTrue);
      expect(p.contains(DateTime(2026, 6, 30, 23, 59)), isTrue);
      expect(p.contains(DateTime(2026, 7, 1)), isFalse);
      expect(p.days, 30);
    });

    test('compares against the equally long window immediately before', () {
      final DashboardPeriod p =
          DashboardPeriod.custom(DateTime(2026, 6, 11), DateTime(2026, 6, 20));
      expect(p.days, 10);
      expect(p.previousStart, DateTime(2026, 6, 1));
      expect(p.previousEnd, DateTime(2026, 6, 11));
    });

    test('a single day is a valid range', () {
      final DashboardPeriod p =
          DashboardPeriod.custom(DateTime(2026, 6, 5), DateTime(2026, 6, 5));
      expect(p.days, 1);
      expect(p.contains(DateTime(2026, 6, 5, 13)), isTrue);
    });
  });

  group('Metric deltas', () {
    test('computes percentage change', () {
      const Metric m = Metric(current: 150, previous: 100);
      expect(m.percentChange, 50);
      expect(m.isUp, isTrue);
      expect(m.isFavourable, isTrue);
    });

    test('a rise in a lower-is-better metric is unfavourable', () {
      // Expenses going up is an increase, but not good news.
      const Metric m =
          Metric(current: 150, previous: 100, higherIsBetter: false);
      expect(m.isUp, isTrue);
      expect(m.isFavourable, isFalse);
    });

    test('a fall in a lower-is-better metric is favourable', () {
      const Metric m =
          Metric(current: 60, previous: 100, higherIsBetter: false);
      expect(m.isDown, isTrue);
      expect(m.isFavourable, isTrue);
    });

    test('no baseline yields null, not infinity or zero', () {
      // "No prior data" and "no change" are different statements.
      const Metric m = Metric(current: 500, previous: 0);
      expect(m.percentChange, isNull);
      expect(m.hasComparison, isFalse);
    });

    test('zero to zero is flat, not undefined', () {
      const Metric m = Metric(current: 0, previous: 0);
      expect(m.percentChange, 0);
      expect(m.isFlat, isTrue);
      expect(m.isFavourable, isTrue);
    });

    test('a drop to zero is -100%', () {
      const Metric m = Metric(current: 0, previous: 250);
      expect(m.percentChange, -100);
      expect(m.isDown, isTrue);
    });

    test('a negative baseline uses its magnitude', () {
      // Loss of £100 improving to a profit of £50 is a positive move.
      const Metric m = Metric(current: 50, previous: -100);
      expect(m.change, 150);
      expect(m.percentChange, 150);
      expect(m.isUp, isTrue);
    });
  });

  group('ChartSeries', () {
    test('an all-zero series counts as empty', () {
      final ChartSeries s = ChartSeries(
        name: 'x',
        points: <SeriesPoint>[
          SeriesPoint(bucket: DateTime(2026, 8, 1), label: '1', value: 0),
          SeriesPoint(bucket: DateTime(2026, 8, 2), label: '2', value: 0),
        ],
      );
      expect(s.isEmpty, isTrue);
    });

    test('totals and extremes are computed over the points', () {
      final ChartSeries s = ChartSeries(
        name: 'revenue',
        points: <SeriesPoint>[
          SeriesPoint(bucket: DateTime(2026, 8, 1), label: '1', value: 100),
          SeriesPoint(bucket: DateTime(2026, 8, 2), label: '2', value: 250),
          SeriesPoint(bucket: DateTime(2026, 8, 3), label: '3', value: 50),
        ],
      );
      expect(s.total, 400);
      expect(s.max, 250);
      expect(s.min, 50);
      expect(s.isEmpty, isFalse);
    });

    test('an empty series has zero totals rather than throwing', () {
      expect(ChartSeries.empty.total, 0);
      expect(ChartSeries.empty.max, 0);
      expect(ChartSeries.empty.min, 0);
      expect(ChartSeries.empty.isEmpty, isTrue);
    });
  });
}
