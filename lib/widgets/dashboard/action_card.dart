import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/dashboard_metrics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// The action centre: what needs doing, not just what happened.
///
/// Shown above the charts because a builder opening the app at 7am wants to
/// know who owes them money, not their quarterly profit margin.
class ActionCentre extends StatelessWidget {
  const ActionCentre({
    required this.items,
    required this.symbol,
    super.key,
  });

  final List<ActionItem> items;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _AllClear();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: Insets.sm),
          _ActionRow(item: items[i], symbol: symbol),
        ],
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.item, required this.symbol});
  final ActionItem item;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);

    final Color tone = switch (item.kind.severity) {
      ActionSeverity.critical => c.danger,
      ActionSeverity.warning => c.warning,
      ActionSeverity.info => c.info,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: Radii.card,
        onTap: item.route == null ? null : () => context.push(item.route!),
        child: Container(
          padding: Insets.cardTight,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: c.isDark ? 0.14 : 0.07),
            borderRadius: Radii.card,
            border: Border.all(color: tone.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.18),
                  borderRadius: Radii.chip,
                ),
                child: Icon(_icon(item.kind), size: 19, color: tone),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.amount > 0.005) ...<Widget>[
                const SizedBox(width: Insets.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      Formatters.money(item.amount, symbol: symbol),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: tone,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              Icon(Icons.chevron_right,
                  size: 20, color: tone.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(ActionKind kind) => switch (kind) {
        ActionKind.overdueInvoices => Icons.warning_amber_rounded,
        ActionKind.dueSoon => Icons.schedule,
        ActionKind.quotesExpiring => Icons.hourglass_bottom,
        ActionKind.uninvoicedJobs => Icons.receipt_long_outlined,
        ActionKind.acceptedQuotesNoJob => Icons.play_circle_outline,
        ActionKind.unpaidBalance => Icons.account_balance_wallet_outlined,
      };
}

/// Shown when there is genuinely nothing outstanding. Worth its own state —
/// "you're all caught up" is useful information, and an empty gap is not.
class _AllClear extends StatelessWidget {
  const _AllClear();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);

    return Container(
      padding: Insets.cardTight,
      decoration: BoxDecoration(
        color: c.success.withValues(alpha: c.isDark ? 0.14 : 0.08),
        borderRadius: Radii.card,
        border: Border.all(color: c.success.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.success.withValues(alpha: 0.18),
              borderRadius: Radii.chip,
            ),
            child: Icon(Icons.check_circle_outline, size: 19, color: c.success),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  "You're all caught up",
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Nothing overdue, expiring or waiting to be invoiced',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
