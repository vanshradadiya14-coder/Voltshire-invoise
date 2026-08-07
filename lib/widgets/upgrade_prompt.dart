import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/subscription.dart';
import '../providers/subscription_providers.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Opens the paywall. Every upgrade path in the app funnels through here so
/// there is exactly one place that knows the route.
Future<void> openPaywall(
  BuildContext context, {
  SubscriptionTier? highlight,
  String? reason,
}) {
  return context.push(
    Routes.paywall,
    extra: PaywallArgs(highlight: highlight, reason: reason),
  ).then((_) {});
}

/// Arguments passed to the paywall route.
class PaywallArgs {
  const PaywallArgs({this.highlight, this.reason});
  final SubscriptionTier? highlight;
  final String? reason;
}

/// A small "PRO" badge for labelling gated affordances in-place.
class ProBadge extends StatelessWidget {
  const ProBadge({this.tier = SubscriptionTier.pro, this.compact = false, super.key});

  final SubscriptionTier tier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? Insets.xs : Insets.sm,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.accent, Color(0xFFF59E0B)],
        ),
        borderRadius: Radii.stadium,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.workspace_premium_rounded,
              size: compact ? 9 : 11, color: Colors.black87),
          const SizedBox(width: 3),
          Text(
            tier.label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 8 : 9,
                  letterSpacing: 0.4,
                ),
          ),
        ],
      ),
    );
  }
}

/// Wraps content that requires a paid feature.
///
/// When the user lacks the entitlement it renders [locked] (a blurred preview
/// by default) with a tap-to-upgrade overlay, rather than hiding the feature
/// entirely — people upgrade for things they can see.
class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    required this.feature,
    required this.child,
    this.locked,
    this.title,
    this.message,
    this.showPreview = true,
    super.key,
  });

  final PaidFeature feature;
  final Widget child;

  /// Custom locked-state widget. Defaults to a preview of [child] behind a
  /// frosted overlay.
  final Widget? locked;

  final String? title;
  final String? message;

  /// When false, the locked state is a compact card with no preview.
  final bool showPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(hasFeatureProvider(feature))) return child;
    if (locked != null) return locked!;

    final SubscriptionTier required = Entitlements.minimumTier(feature);
    final String heading = title ?? '${required.label} feature';
    final String body =
        message ?? 'Upgrade to ${required.label} to unlock this.';

    if (!showPreview) {
      return UpgradeCard(
        title: heading,
        message: body,
        tier: required,
      );
    }

    return Stack(
      children: <Widget>[
        // Muted, non-interactive preview so the value is visible.
        Opacity(
          opacity: 0.35,
          child: IgnorePointer(child: child),
        ),
        Positioned.fill(
          child: _LockedOverlay(
            title: heading,
            message: body,
            tier: required,
          ),
        ),
      ],
    );
  }
}

class _LockedOverlay extends StatelessWidget {
  const _LockedOverlay({
    required this.title,
    required this.message,
    required this.tier,
  });

  final String title;
  final String message;
  final SubscriptionTier tier;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Container(
        margin: Insets.card,
        padding: Insets.card,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.96),
          borderRadius: Radii.card,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: Shadows.medium(theme.brightness),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ProBadge(tier: tier),
            const SizedBox(height: Insets.md),
            Text(title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Insets.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Insets.md),
            FilledButton.tonal(
              onPressed: () => openPaywall(context, highlight: tier, reason: message),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
              child: Text('Unlock with ${tier.label}'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A standalone upgrade call-to-action card.
class UpgradeCard extends StatelessWidget {
  const UpgradeCard({
    required this.title,
    required this.message,
    this.tier = SubscriptionTier.pro,
    this.icon = Icons.workspace_premium_outlined,
    this.compact = false,
    super.key,
  });

  final String title;
  final String message;
  final SubscriptionTier tier;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: Radii.card,
        onTap: () => openPaywall(context, highlight: tier, reason: message),
        child: Container(
          padding: compact ? Insets.cardTight : Insets.card,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.seed.withValues(alpha: 0.12),
                AppColors.accent.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: Radii.card,
            border: Border.all(
              color: AppColors.seed.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(Insets.sm),
                decoration: BoxDecoration(
                  color: AppColors.seed.withValues(alpha: 0.16),
                  borderRadius: Radii.field,
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        ProBadge(tier: tier, compact: true),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              Icon(Icons.chevron_right, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A progress meter showing how much of a Free-tier allowance is used.
///
/// Only renders when a cap actually applies, so paid users never see it.
class UsageMeter extends ConsumerWidget {
  const UsageMeter({required this.resource, this.dense = false, super.key});

  final LimitedResource resource;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LimitCheck check = ref.watch(canCreateProvider(resource));
    if (check.isUnlimited) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);
    final Color tone = check.allowed
        ? (check.isNearLimit ? c.warning : theme.colorScheme.primary)
        : c.danger;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? Insets.xs : Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${check.used} of ${check.limit} ${resource.plural} used',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => openPaywall(
                  context,
                  reason: 'Get unlimited ${resource.plural} with Pro.',
                ),
                child: Text(
                  'Upgrade',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xs),
            child: LinearProgressIndicator(
              value: check.fraction,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(tone),
            ),
          ),
        ],
      ),
    );
  }
}

/// Checks a creation limit and, when blocked, shows an explanatory sheet.
///
/// Returns true when the caller may proceed. Call this at the top of every
/// "create" action:
///
/// ```dart
/// if (!await ensureCanCreate(context, ref, LimitedResource.customers)) return;
/// ```
Future<bool> ensureCanCreate(
  BuildContext context,
  WidgetRef ref,
  LimitedResource resource,
) async {
  final LimitCheck check = ref.read(canCreateProvider(resource));
  if (check.allowed) return true;

  if (!context.mounted) return false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext ctx) => _LimitReachedSheet(check: check),
  );
  return false;
}

class _LimitReachedSheet extends StatelessWidget {
  const _LimitReachedSheet({required this.check});
  final LimitCheck check;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: Insets.sheet,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: Insets.sm),
          Center(
            child: Container(
              padding: const EdgeInsets.all(Insets.lg),
              decoration: BoxDecoration(
                color: AppColors.seed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline_rounded,
                  size: 32, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: Insets.lg),
          Text(
            "You've reached your Free plan limit",
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'The Free plan includes ${check.limit} ${check.resource.plural}. '
            'Upgrade to Pro for unlimited ${check.resource.plural} — everything '
            "you've already created stays exactly where it is.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Insets.xl),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openPaywall(
                context,
                reason:
                    'Get unlimited ${check.resource.plural} and much more.',
              );
            },
            child: const Text('See plans'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not now'),
          ),
        ],
      ),
    );
  }
}
