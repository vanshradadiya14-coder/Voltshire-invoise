import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/dashboard_metrics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'chart_shell.dart';

/// Cumulative revenue across the period, as a filled area line.
///
/// A running total answers "are we ahead of where we were?" — the question
/// daily bars make you compute in your head.
class RevenueChart extends StatelessWidget {
  const RevenueChart({
    required this.series,
    required this.symbol,
    this.height = 200,
    super.key,
  });

  final ChartSeries series;
  final String symbol;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color line = theme.colorScheme.primary;

    final bool empty = series.isEmpty;
    final double maxY = niceAxisMax(series.max);
    final int count = series.points.length;
    final int labelEvery = count <= 8
        ? 1
        : count <= 16
            ? 3
            : (count / 5).ceil();

    return ChartShell(
      title: 'Revenue trend',
      subtitle: 'Running total for the period',
      height: height,
      isEmpty: empty,
      emptyIcon: Icons.show_chart,
      emptyMessage: 'No payments received in this period',
      trailing: empty
          ? null
          : Text(
              Formatters.money(series.max, symbol: symbol),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: line,
              ),
            ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          minX: 0,
          maxX: (count - 1).toDouble().clamp(1, double.infinity),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              tooltipRoundedRadius: Radii.sm,
              getTooltipItems: (List<LineBarSpot> spots) => spots
                  .map((LineBarSpot s) => LineTooltipItem(
                        '${series.points[s.x.toInt()].label}\n',
                        theme.textTheme.labelSmall!.copyWith(
                          color: theme.colorScheme.onInverseSurface
                              .withValues(alpha: 0.75),
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: Formatters.money(s.y, symbol: symbol),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onInverseSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ))
                  .toList(),
            ),
            getTouchedSpotIndicator: (LineChartBarData bar, List<int> indexes) {
              return indexes
                  .map((_) => TouchedSpotIndicatorData(
                        FlLine(color: line.withValues(alpha: 0.4), strokeWidth: 1),
                        FlDotData(
                          getDotPainter: (_, __, ___, ____) =>
                              FlDotCirclePainter(
                            radius: 4.5,
                            color: line,
                            strokeWidth: 2,
                            strokeColor: theme.colorScheme.surface,
                          ),
                        ),
                      ))
                  .toList();
            },
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
                interval: 1,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int i = value.toInt();
                  if (i < 0 || i >= count || i % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: Insets.sm),
                    child: Text(
                      series.points[i].label,
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
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: <FlSpot>[
                for (int i = 0; i < count; i++)
                  FlSpot(i.toDouble(), series.points[i].value),
              ],
              isCurved: true,
              curveSmoothness: 0.28,
              // Prevents the smoothing from dipping the line below zero
              // between two low points, which would imply negative revenue.
              preventCurveOverShooting: true,
              color: line,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: count <= 14),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    line.withValues(alpha: 0.28),
                    line.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: Motion.chart,
        curve: Motion.enter,
      ),
    );
  }
}

/// A tiny inline trend line for metric tiles — no axes, no labels, just shape.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.values,
    this.color,
    this.height = 28,
    super.key,
  });

  final List<double> values;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);
    final Color c = color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: <FlSpot>[
                for (int i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              isCurved: true,
              curveSmoothness: 0.3,
              preventCurveOverShooting: true,
              color: c,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: c.withValues(alpha: 0.14),
              ),
            ),
          ],
        ),
        duration: Motion.fast,
      ),
    );
  }
}
