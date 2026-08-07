import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/dashboard_metrics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// A headline figure with its period-over-period movement.
///
/// The delta is coloured by whether the movement is *good*, not by whether it
/// is *up*. Rising expenses and rising revenue are both increases; only one of
/// them is worth celebrating.
class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.label,
    required this.metric,
    required this.icon,
    required this.symbol,
    this.comparisonLabel,
    this.accent,
    this.onTap,
    this.suffix,
    this.compact = false,
    super.key,
  });

  final String label;
  final Metric metric;
  final IconData icon;
  final String symbol;
  final String? comparisonLabel;
  final Color? accent;
  final VoidCallback? onTap;

  /// Appended to the value, e.g. `%`.
  final String? suffix;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);
    final Color tone = accent ?? theme.colorScheme.primary;

    final String value = metric.isCurrency
        ? Formatters.money(metric.current, symbol: symbol)
        : '${metric.current.toStringAsFixed(0)}${suffix ?? ''}';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.card,
        child: Padding(
          padding: compact ? Insets.cardTight : Insets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(Insets.sm),
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.14),
                      borderRadius: Radii.chip,
                    ),
                    child: Icon(icon, color: tone, size: 18),
                  ),
                  const Spacer(),
                  if (metric.hasComparison && !compact)
                    _DeltaChip(metric: metric, colors: c),
                ],
              ),
              SizedBox(height: compact ? Insets.sm : Insets.md),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: (compact
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures()
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (metric.hasComparison && comparisonLabel != null && !compact)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    comparisonLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.75),
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.metric, required this.colors});
  final Metric metric;
  final AppStatusColors colors;

  @override
  Widget build(BuildContext context) {
    final double? pct = metric.percentChange;
    if (pct == null) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final Color tone = metric.isFlat
        ? colors.neutral
        : (metric.isFavourable ? colors.success : colors.danger);

    final IconData arrow = metric.isFlat
        ? Icons.remove
        : metric.isUp
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;

    // Beyond 999% the exact figure stops meaning anything useful.
    final String text = metric.isFlat
        ? '0%'
        : pct.abs() >= 999
            ? '>999%'
            : '${pct.abs().toStringAsFixed(pct.abs() < 10 ? 1 : 0)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: Radii.stadium,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(arrow, size: 11, color: tone),
          const SizedBox(width: 2),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// A wide hero tile for the single most important figure of the period.
class HeroMetric extends StatelessWidget {
  const HeroMetric({
    required this.label,
    required this.metric,
    required this.symbol,
    required this.comparisonLabel,
    this.secondary = const <(String, String)>[],
    this.onTap,
    super.key,
  });

  final String label;
  final Metric metric;
  final String symbol;
  final String comparisonLabel;

  /// Supporting label/value pairs shown along the bottom edge.
  final List<(String, String)> secondary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);
    final double? pct = metric.percentChange;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.brandDark, AppColors.seed],
        ),
        borderRadius: Radii.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.card,
          child: Padding(
            padding: Insets.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Insets.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formatters.money(metric.current, symbol: symbol),
                          maxLines: 1,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (pct != null) ...<Widget>[
                      const SizedBox(width: Insets.md),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Insets.sm, vertical: 3),
                          decoration: BoxDecoration(
                            color: (metric.isFavourable
                                    ? c.successDarkOnBrand
                                    : c.dangerOnBrand)
                                .withValues(alpha: 0.24),
                            borderRadius: Radii.stadium,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                metric.isFlat
                                    ? Icons.remove
                                    : metric.isUp
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                pct.abs() >= 999
                                    ? '>999%'
                                    : '${pct.abs().toStringAsFixed(0)}%',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  comparisonLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                if (secondary.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Insets.lg),
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < secondary.length; i++) ...<Widget>[
                        if (i > 0)
                          Container(
                            width: 1,
                            height: 26,
                            margin: const EdgeInsets.symmetric(
                                horizontal: Insets.md),
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                secondary[i].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                secondary[i].$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Light/dark-safe accents for use on the brand gradient, where the normal
/// semantic colours would not have enough contrast.
extension on AppStatusColors {
  Color get successDarkOnBrand => const Color(0xFF7DF0AC);
  Color get dangerOnBrand => const Color(0xFFFFB4AE);
}
