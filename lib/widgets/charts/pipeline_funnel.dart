import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/dashboard_metrics.dart';
import '../../models/enums.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'chart_shell.dart';

/// The job pipeline, drawn as proportional stages.
///
/// Rendered with plain widgets rather than a chart library: a funnel is four
/// labelled bars, and hand-drawing them keeps the count, the value and the
/// stage name on one readable row — which a charting library makes harder,
/// not easier.
class PipelineFunnel extends StatelessWidget {
  const PipelineFunnel({
    required this.stages,
    required this.symbol,
    this.onStageTap,
    super.key,
  });

  final List<BreakdownSlice> stages;
  final String symbol;
  final ValueChanged<int>? onStageTap;

  @override
  Widget build(BuildContext context) {
    final int totalCount =
        stages.fold<int>(0, (int s, BreakdownSlice b) => s + b.count);
    final bool empty = totalCount == 0;

    final int maxCount = empty
        ? 1
        : stages
            .map((BreakdownSlice s) => s.count)
            .reduce((int a, int b) => a > b ? a : b);

    final double totalValue =
        stages.fold<double>(0, (double s, BreakdownSlice b) => s + b.value);

    return ChartShell(
      title: 'Job pipeline',
      subtitle: empty
          ? 'By stage'
          : '$totalCount active ${totalCount == 1 ? 'job' : 'jobs'} · '
              '${Formatters.money(totalValue, symbol: symbol)}',
      height: 190,
      isEmpty: empty,
      emptyIcon: Icons.filter_alt_outlined,
      emptyMessage: 'No jobs in the pipeline yet',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          for (int i = 0; i < stages.length; i++)
            _Stage(
              slice: stages[i],
              colour: _colourFor(stages[i].label, context),
              fraction: maxCount == 0 ? 0 : stages[i].count / maxCount,
              symbol: symbol,
              onTap: onStageTap == null ? null : () => onStageTap!(i),
            ),
        ],
      ),
    );
  }

  Color _colourFor(String label, BuildContext context) {
    final AppStatusColors c = AppColors.of(context);
    for (final JobStatus s in JobStatus.values) {
      if (s.label == label) return c.resolve(s.color);
    }
    return c.neutral;
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.slice,
    required this.colour,
    required this.fraction,
    required this.symbol,
    this.onTap,
  });

  final BreakdownSlice slice;
  final Color colour;
  final double fraction;
  final String symbol;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.chip,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 74,
              child: Text(
                slice.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(Radii.xs),
                    ),
                  ),
                  // A zero-count stage still shows a hairline so the row does
                  // not read as missing.
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: fraction.clamp(0.0, 1.0),
                    ),
                    duration: Motion.chart,
                    curve: Motion.enter,
                    builder: (BuildContext context, double v, _) =>
                        FractionallySizedBox(
                      widthFactor: v < 0.02 ? 0.02 : v,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: colour.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(Radii.xs),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                    child: Text(
                      '${slice.count}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: fraction > 0.08
                            ? Colors.white
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            SizedBox(
              width: 62,
              child: Text(
                slice.value > 0.005
                    ? compactMoney(slice.value, symbol)
                    : '—',
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal ranked bar list — used for top customers.
class RankedBars extends StatelessWidget {
  const RankedBars({
    required this.title,
    required this.slices,
    required this.symbol,
    this.subtitle,
    this.emptyMessage = 'Nothing to show yet',
    this.barColor,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<BreakdownSlice> slices;
  final String symbol;
  final String emptyMessage;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool empty = slices.isEmpty;
    final double max = empty
        ? 1
        : slices
            .map((BreakdownSlice s) => s.value)
            .reduce((double a, double b) => a > b ? a : b);

    return ChartShell(
      title: title,
      subtitle: subtitle,
      height: (slices.length.clamp(1, 5) * 34).toDouble() + 4,
      isEmpty: empty,
      emptyIcon: Icons.leaderboard_outlined,
      emptyMessage: emptyMessage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < slices.length && i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.xs + 1),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: Text(
                      slices[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    flex: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.xs),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: max <= 0 ? 0 : slices[i].value / max,
                        ),
                        duration: Motion.chart,
                        curve: Motion.enter,
                        builder: (BuildContext c, double v, _) =>
                            LinearProgressIndicator(
                          value: v,
                          minHeight: 14,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            barColor ?? AppColors.series(i),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  SizedBox(
                    width: 62,
                    child: Text(
                      compactMoney(slices[i].value, symbol),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
