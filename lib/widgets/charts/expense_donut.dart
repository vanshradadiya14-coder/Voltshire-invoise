import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/dashboard_metrics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'chart_shell.dart';

/// Expense composition as a donut with the total in the middle.
///
/// A donut is the right shape here because expenses genuinely are parts of one
/// whole, and the hole gives somewhere useful to put the total.
class ExpenseDonut extends StatefulWidget {
  const ExpenseDonut({
    required this.slices,
    required this.symbol,
    this.title = 'Where the money went',
    this.height = 200,
    super.key,
  });

  final List<BreakdownSlice> slices;
  final String symbol;
  final String title;
  final double height;

  @override
  State<ExpenseDonut> createState() => _ExpenseDonutState();
}

class _ExpenseDonutState extends State<ExpenseDonut> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // Beyond six categories the legend stops being readable, so the tail is
    // rolled into "Other" rather than producing twelve unnameable slivers.
    final List<BreakdownSlice> shown = _collapse(widget.slices, 6);
    final double total =
        shown.fold<double>(0, (double s, BreakdownSlice b) => s + b.value);
    final bool empty = shown.isEmpty || total < 0.005;

    return ChartShell(
      title: widget.title,
      subtitle: 'By category',
      height: widget.height,
      isEmpty: empty,
      emptyIcon: Icons.pie_chart_outline,
      emptyMessage: 'No expenses recorded in this period',
      legend: empty
          ? null
          : ChartLegend(
              entries: <ChartLegendEntry>[
                for (int i = 0; i < shown.length; i++)
                  ChartLegendEntry(
                    color: AppColors.series(i),
                    label: shown[i].label,
                    value: Formatters.money(shown[i].value,
                        symbol: widget.symbol),
                  ),
              ],
            ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 56,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, PieTouchResponse? res) {
                  setState(() {
                    _touched = (!event.isInterestedForInteractions ||
                            res?.touchedSection == null)
                        ? -1
                        : res!.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sections: <PieChartSectionData>[
                for (int i = 0; i < shown.length; i++)
                  PieChartSectionData(
                    value: shown[i].value,
                    color: AppColors.series(i),
                    radius: _touched == i ? 30 : 24,
                    showTitle: false,
                  ),
              ],
            ),
            duration: Motion.fast,
          ),
          // Centre readout: the whole, or the slice under the finger.
          AnimatedSwitcher(
            duration: Motion.fast,
            child: Column(
              key: ValueKey<int>(_touched),
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _touched >= 0 && _touched < shown.length
                      ? shown[_touched].label
                      : 'Total',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.money(
                    _touched >= 0 && _touched < shown.length
                        ? shown[_touched].value
                        : total,
                    symbol: widget.symbol,
                  ),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (_touched >= 0 && _touched < shown.length && total > 0)
                  Text(
                    '${(shown[_touched].value / total * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Keeps the [limit] largest categories and folds the remainder into "Other".
  List<BreakdownSlice> _collapse(List<BreakdownSlice> input, int limit) {
    final List<BreakdownSlice> nonZero =
        input.where((BreakdownSlice s) => s.value > 0.005).toList();
    if (nonZero.length <= limit) return nonZero;

    final List<BreakdownSlice> head = nonZero.take(limit - 1).toList();
    final Iterable<BreakdownSlice> tail = nonZero.skip(limit - 1);
    return <BreakdownSlice>[
      ...head,
      BreakdownSlice(
        label: 'Other',
        value: tail.fold<double>(0, (double s, BreakdownSlice b) => s + b.value),
        count: tail.fold<int>(0, (int s, BreakdownSlice b) => s + b.count),
      ),
    ];
  }
}
