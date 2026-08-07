import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/dashboard_metrics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'chart_shell.dart';

/// Money in vs money out, as grouped bars across the period's buckets.
///
/// Grouped bars (rather than stacked) because the question a builder asks is
/// "did I take more than I spent this week?", which is a comparison, not a
/// composition.
class CashFlowChart extends StatelessWidget {
  const CashFlowChart({
    required this.series,
    required this.symbol,
    this.height = 220,
    super.key,
  });

  final List<ChartSeries> series;
  final String symbol;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);

    final ChartSeries income =
        series.isNotEmpty ? series[0] : ChartSeries.empty;
    final ChartSeries spend =
        series.length > 1 ? series[1] : ChartSeries.empty;

    final bool empty = income.isEmpty && spend.isEmpty;
    final double rawMax =
        <double>[income.max, spend.max].reduce((a, b) => a > b ? a : b);
    final double maxY = niceAxisMax(rawMax);

    // With many buckets, labelling every one turns the axis into a smear.
    final int count = income.points.length;
    final int labelEvery = count <= 8
        ? 1
        : count <= 16
            ? 2
            : count <= 32
                ? 5
                : (count / 6).ceil();

    return ChartShell(
      title: 'Cash flow',
      subtitle: 'Received against spent',
      height: height,
      isEmpty: empty,
      emptyIcon: Icons.bar_chart_outlined,
      emptyMessage: 'No payments or expenses in this period',
      legend: ChartLegend(
        entries: <ChartLegendEntry>[
          ChartLegendEntry(
            color: c.success,
            label: 'In',
            value: Formatters.money(income.total, symbol: symbol),
          ),
          ChartLegendEntry(
            color: c.warning,
            label: 'Out',
            value: Formatters.money(spend.total, symbol: symbol),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          groupsSpace: count > 20 ? 2 : 8,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              tooltipRoundedRadius: Radii.sm,
              getTooltipItem: (BarChartGroupData group, int groupIndex,
                  BarChartRodData rod, int rodIndex) {
                final String label = rodIndex == 0 ? 'In' : 'Out';
                return BarTooltipItem(
                  '${income.points[group.x].label}\n',
                  theme.textTheme.labelSmall!.copyWith(
                    color: theme.colorScheme.onInverseSurface
                        .withValues(alpha: 0.75),
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text:
                          '$label ${Formatters.money(rod.toY, symbol: symbol)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (double value) => FlLine(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              strokeWidth: 1,
              dashArray: const <int>[4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: maxY / 4,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: Insets.xs),
                    child: Text(
                      compactMoney(value, symbol),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int i = value.toInt();
                  if (i < 0 || i >= income.points.length) {
                    return const SizedBox.shrink();
                  }
                  if (i % labelEvery != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: Insets.sm),
                    child: Text(
                      income.points[i].label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: <BarChartGroupData>[
            for (int i = 0; i < income.points.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 2,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: income.points[i].value,
                    color: c.success,
                    width: count > 20 ? 3 : 7,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                  BarChartRodData(
                    toY: i < spend.points.length ? spend.points[i].value : 0,
                    color: c.warning,
                    width: count > 20 ? 3 : 7,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              ),
          ],
        ),
        duration: Motion.chart,
        curve: Motion.enter,
      ),
    );
  }
}
