import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dashboard_period.dart';
import '../../providers/dashboard_v2_provider.dart';
import '../../theme/app_spacing.dart';

/// Horizontal period picker with a custom-range option.
///
/// Scrollable rather than a `SegmentedButton` because six options do not fit on
/// a phone, and truncating "This quarter" to "Q" helps nobody.
class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final DashboardRange active = ref.watch(dashboardRangeProvider);
    final DashboardPeriod period = ref.watch(dashboardPeriodProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            itemCount: DashboardRange.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
            itemBuilder: (BuildContext context, int i) {
              final DashboardRange r = DashboardRange.values[i];
              final bool selected = r == active;
              return _Chip(
                label: r.shortLabel,
                selected: selected,
                icon: r == DashboardRange.custom
                    ? Icons.date_range_outlined
                    : null,
                onTap: () async {
                  if (r == DashboardRange.custom) {
                    await _pickCustom(context, ref);
                  } else {
                    ref.read(dashboardRangeProvider.notifier).state = r;
                  }
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Insets.gutter, Insets.sm, Insets.gutter, 0),
          child: Text(
            period.description,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Future<void> _pickCustom(BuildContext context, WidgetRef ref) async {
    final DateTime now = DateTime.now();
    final DashboardPeriod current = ref.read(dashboardPeriodProvider);

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 6),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(
        start: current.start,
        end: current.end.subtract(const Duration(days: 1)),
      ),
      helpText: 'Select a date range',
      saveText: 'Apply',
    );
    if (picked == null) return;

    ref.read(customPeriodProvider.notifier).state =
        DashboardPeriod.custom(picked.start, picked.end);
    ref.read(dashboardRangeProvider.notifier).state = DashboardRange.custom;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.stadium,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.enter,
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg, vertical: Insets.sm),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: Radii.stadium,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 15,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Insets.xs + 2),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
