import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/trade_providers.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Two taps to anything, from anywhere.
///
/// The old app made you navigate to the right tab before you could create
/// something. On a building site, with one hand free, that is three taps too
/// many. The most common actions come first, and the list adapts to what is
/// actually outstanding.
Future<void> showQuickAddSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => const _QuickAddSheet(),
  );
}

class _QuickAddSheet extends ConsumerWidget {
  const _QuickAddSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);

    // Contextual prompt: if there is finished work that was never billed, that
    // is more useful than any generic "new invoice" button.
    final int uninvoiced = ref.watch(uninvoicedCompletedJobsProvider).length;

    final List<_Action> actions = <_Action>[
      _Action(
        label: 'New invoice',
        detail: 'Bill a customer',
        icon: Icons.receipt_long,
        route: Routes.invoiceNew,
        tone: c.success,
      ),
      _Action(
        label: 'New quote',
        detail: 'Price up a job',
        icon: Icons.description_outlined,
        route: Routes.quoteNew,
        tone: c.info,
      ),
      _Action(
        label: 'New job',
        detail: 'Start tracking work',
        icon: Icons.construction,
        route: Routes.jobNew,
        tone: c.warning,
      ),
      _Action(
        label: 'New customer',
        detail: 'Add a client',
        icon: Icons.person_add_alt,
        route: Routes.customerNew,
        tone: theme.colorScheme.primary,
      ),
      _Action(
        label: 'Log expense',
        detail: 'Materials, fuel, skip hire',
        icon: Icons.receipt_outlined,
        route: Routes.expenseNew,
        tone: c.neutral,
      ),
      _Action(
        label: 'Price list',
        detail: 'Your saved prices',
        icon: Icons.list_alt,
        route: Routes.priceList,
        tone: c.neutral,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: Insets.sheet,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Create',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: Insets.lg),

            if (uninvoiced > 0) ...<Widget>[
              _Prompt(
                message: '$uninvoiced finished '
                    '${uninvoiced == 1 ? 'job has' : 'jobs have'} not been '
                    'invoiced',
                actionLabel: 'Bill them',
                tone: c.warning,
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(Routes.jobs);
                },
              ),
              const SizedBox(height: Insets.lg),
            ],

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Insets.md,
              crossAxisSpacing: Insets.md,
              childAspectRatio: 1.55,
              children: actions
                  .map((_Action a) => _ActionTile(action: a))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action {
  const _Action({
    required this.label,
    required this.detail,
    required this.icon,
    required this.route,
    required this.tone,
  });

  final String label;
  final String detail;
  final IconData icon;
  final String route;
  final Color tone;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});
  final _Action action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainer : Colors.white,
        borderRadius: Radii.card,
        border: Border.all(
          color: isDark
              ? action.tone.withValues(alpha: 0.20)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: isDark
            ? Shadows.glow(action.tone, opacity: 0.06, radius: 10)
            : Shadows.low(theme.brightness),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: Radii.card,
          onTap: () {
            Navigator.of(context).pop();
            context.push(action.route);
          },
          child: Padding(
            padding: Insets.cardTight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(Insets.sm),
                  decoration: BoxDecoration(
                    color: action.tone.withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: action.tone.withValues(alpha: isDark ? 0.35 : 0.20),
                      width: 1,
                    ),
                  ),
                  child: Icon(action.icon, size: 20, color: action.tone),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      action.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({
    required this.message,
    required this.actionLabel,
    required this.tone,
    required this.onTap,
  });

  final String message;
  final String actionLabel;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: Radii.card,
        onTap: onTap,
        child: Container(
          padding: Insets.cardTight,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: Radii.card,
            border: Border.all(color: tone.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, size: 20, color: tone),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                actionLabel,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: tone, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
