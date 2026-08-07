import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

/// Common frame for every chart: title, optional trailing control, a fixed
/// height body, and a proper empty state.
///
/// Charts that render nothing on empty data look broken. Routing every chart
/// through this shell guarantees an empty window explains itself instead.
class ChartShell extends StatelessWidget {
  const ChartShell({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.legend,
    this.height = 220,
    this.isEmpty = false,
    this.emptyIcon = Icons.insights_outlined,
    this.emptyMessage = 'No data for this period',
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final Widget? legend;
  final double height;
  final bool isEmpty;
  final IconData emptyIcon;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: Insets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: Insets.lg),
            SizedBox(
              height: height,
              child: isEmpty
                  ? _Empty(icon: emptyIcon, message: emptyMessage)
                  : child,
            ),
            if (legend != null && !isEmpty) ...<Widget>[
              const SizedBox(height: Insets.md),
              legend!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            icon,
            size: 34,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A colour swatch + label pair, used beneath multi-series charts.
class ChartLegend extends StatelessWidget {
  const ChartLegend({required this.entries, this.alignment = WrapAlignment.start, super.key});

  final List<ChartLegendEntry> entries;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      alignment: alignment,
      spacing: Insets.lg,
      runSpacing: Insets.sm,
      children: entries
          .map((ChartLegendEntry e) => Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: e.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Text(e.label, style: theme.textTheme.bodySmall),
                  if (e.value != null) ...<Widget>[
                    const SizedBox(width: Insets.xs),
                    Text(
                      e.value!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ))
          .toList(),
    );
  }
}

class ChartLegendEntry {
  const ChartLegendEntry({required this.color, required this.label, this.value});
  final Color color;
  final String label;
  final String? value;
}

/// Compact money formatting for chart axes, where `£12,500.00` would not fit.
/// Produces `£12.5k`, `£1.2m`.
String compactMoney(double value, String symbol) {
  final double v = value.abs();
  final String sign = value < 0 ? '-' : '';
  if (v >= 1000000) {
    return '$sign$symbol${(v / 1000000).toStringAsFixed(v >= 10000000 ? 0 : 1)}m';
  }
  if (v >= 1000) {
    return '$sign$symbol${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
  }
  return '$sign$symbol${v.toStringAsFixed(0)}';
}

/// Chooses a "nice" axis maximum so gridlines land on round numbers rather
/// than on whatever the data happened to peak at.
double niceAxisMax(double rawMax) {
  if (rawMax <= 0) return 100;
  final double magnitude =
      _pow10((rawMax.abs()).toString().split('.').first.length - 1);
  final double normalised = rawMax / magnitude;
  final double stepped = normalised <= 1
      ? 1
      : normalised <= 2
          ? 2
          : normalised <= 2.5
              ? 2.5
              : normalised <= 5
                  ? 5
                  : 10;
  return stepped * magnitude;
}

double _pow10(int exponent) {
  double r = 1;
  for (int i = 0; i < exponent; i++) {
    r *= 10;
  }
  return r;
}
