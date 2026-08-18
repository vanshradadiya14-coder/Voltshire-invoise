import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/flow/save_outcome.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Shown after something is created, offering what happens next.
///
/// This is the fix for the app's central flaw: every create form used to end
/// with `context.pop()`, dumping the builder back on a list. Work has an order —
/// customer, then quote, then job, then invoice, then payment — and the app
/// should carry them along it rather than making them navigate back to the
/// right tab and start again.
///
/// Dismissing leaves them on the detail screen for the thing they just made,
/// which is itself a useful place to be.
Future<void> showNextStepSheet(
  BuildContext context,
  SaveOutcome outcome,
) {
  final List<NextStep> steps = outcome.nextSteps;
  if (steps.isEmpty) return Future<void>.value();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext ctx) =>
        _NextStepSheet(outcome: outcome, steps: steps),
  );
}

class _NextStepSheet extends StatelessWidget {
  const _NextStepSheet({required this.outcome, required this.steps});

  final SaveOutcome outcome;
  final List<NextStep> steps;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);

    return SafeArea(
      child: Padding(
        padding: Insets.sheet,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: Insets.xs),
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: c.container(c.success),
                    borderRadius: Radii.field,
                  ),
                  child: Icon(Icons.check_rounded, color: c.success, size: 24),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        outcome.confirmation,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        outcome.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xl),
            Text(
              'What next?',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Insets.md),
            for (int i = 0; i < steps.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: Insets.sm),
              _StepTile(step: steps[i]),
            ],
            const SizedBox(height: Insets.md),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step});
  final NextStep step;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool primary = step.isPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: Radii.card,
        onTap: () {
          // Close the sheet first so the pushed screen does not appear behind
          // it, then navigate. The detail screen underneath stays in the stack,
          // so backing out of the next form lands somewhere sensible.
          Navigator.of(context).pop();
          context.push(step.route);
        },
        child: Container(
          padding: Insets.cardTight,
          decoration: BoxDecoration(
            color: primary
                ? theme.colorScheme.primary
                    .withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.09)
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: Radii.card,
            border: Border.all(
              color: primary
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : theme.colorScheme.outlineVariant,
              width: primary ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: primary
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: Radii.chip,
                ),
                child: Icon(
                  step.icon,
                  size: 19,
                  color: primary
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      step.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    Text(
                      step.detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                size: 18,
                color: primary
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Completes a create/edit: navigate to the new record, then offer the next
/// step over the top.
///
/// Called by every form's `_save()` in place of the old bare `context.pop()`.
Future<void> completeSave(BuildContext context, SaveOutcome outcome) async {
  final String? detail = outcome.kind.detailRoute(outcome.id);

  if (outcome.wasEdit || detail == null) {
    // Editing, or a record with no detail screen (expense, payment) — just go
    // back to where they were.
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    return;
  }

  // Replace the form with the detail screen. `pushReplacement` rather than
  // `push` so backing out of the detail screen does not land on the form that
  // has already been submitted.
  if (!context.mounted) return;
  context.pushReplacement(detail);

  // Let the detail screen build before layering the sheet over it.
  await Future<void>.delayed(const Duration(milliseconds: 260));

  // Present the sheet on the ROOT navigator, not the form's context. The
  // pushReplacement above unmounts the form, so its context is dead by now —
  // using it (as the original code did) meant the `mounted` guard fired and the
  // sheet silently never appeared. The root context survives the replacement.
  final BuildContext? rootContext = rootNavigatorKey.currentContext;
  if (rootContext == null || !rootContext.mounted) return;
  await showNextStepSheet(rootContext, outcome);
}
