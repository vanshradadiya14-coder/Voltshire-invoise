import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/billing_config.dart';
import '../../core/utils/formatters.dart';
import '../../models/subscription.dart';
import '../../providers/subscription_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/ui_helpers.dart';
import '../../widgets/upgrade_prompt.dart';

/// Shows the active plan, what it includes, current usage against any caps,
/// and the routes to change or restore it.
class ManageSubscriptionScreen extends ConsumerWidget {
  const ManageSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Entitlements ent = ref.watch(currentEntitlementsProvider);
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: ListView(
        padding: Insets.pageTop,
        children: <Widget>[
          _PlanSummary(entitlements: ent),
          const SizedBox(height: Insets.lg),

          if (ent.hasBillingProblem) ...<Widget>[
            _Notice(
              icon: Icons.error_outline,
              tone: c.warning,
              title: 'Payment problem',
              message:
                  'Your last payment did not go through. Update your payment '
                  'method in the store to keep ${ent.tier.label} — access '
                  'continues during the retry window.',
            ),
            const SizedBox(height: Insets.lg),
          ],

          if (ent.isTrialing) ...<Widget>[
            _Notice(
              icon: Icons.timer_outlined,
              tone: c.info,
              title: '${ent.trialDaysRemaining} days left in your trial',
              message: ent.trialEndsAt == null
                  ? 'Cancel any time before it ends and you will not be charged.'
                  : 'Billing starts ${Formatters.longDate(ent.trialEndsAt!)}. '
                      'Cancel before then and you will not be charged.',
            ),
            const SizedBox(height: Insets.lg),
          ],

          const SectionHeader('Your usage'),
          Card(
            child: Padding(
              padding: Insets.card,
              child: Column(
                children: <Widget>[
                  for (final LimitedResource r in LimitedResource.values)
                    _UsageRow(resource: r),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),

          const SectionHeader("What's included"),
          Card(
            child: Padding(
              padding: Insets.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final PaidFeature f in PaidFeature.values)
                    _FeatureRow(
                      feature: f,
                      included: ent.has(f),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),

          if (!ent.isPaid)
            UpgradeCard(
              title: 'Unlock everything',
              message: 'Unlimited records, reports, clean PDFs and exports.',
              icon: Icons.rocket_launch_outlined,
            )
          else
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: const Text('Change plan'),
                    subtitle: const Text('Switch tier or billing period'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openPaywall(context, highlight: ent.tier),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: const Text('Manage or cancel'),
                    subtitle: Text(_storeName()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openStore(context, ent.managementUrl),
                  ),
                ],
              ),
            ),

          const SizedBox(height: Insets.md),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('Restore purchases'),
                  subtitle:
                      const Text('Already subscribed on another device?'),
                  onTap: () => _restore(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined),
                  title: const Text('Billing support'),
                  subtitle: const Text(BillingConfig.supportEmail),
                  onTap: () => _email(),
                ),
              ],
            ),
          ),

          if (ent.expiresAt != null) ...<Widget>[
            const SizedBox(height: Insets.lg),
            Center(
              child: Text(
                ent.willRenew
                    ? 'Renews on ${Formatters.longDate(ent.expiresAt!)}'
                    : 'Access ends on ${Formatters.longDate(ent.expiresAt!)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _storeName() {
    if (kIsWeb) return 'Store';
    try {
      if (Platform.isIOS) return 'App Store subscriptions';
      if (Platform.isAndroid) return 'Google Play subscriptions';
    } catch (_) {}
    return 'Store subscriptions';
  }

  Future<void> _openStore(BuildContext context, String? managementUrl) async {
    String url = managementUrl ?? '';
    if (url.isEmpty) {
      bool ios = false;
      try {
        ios = !kIsWeb && Platform.isIOS;
      } catch (_) {}
      url = ios ? BillingConfig.appStoreManageUrl : BillingConfig.playManageUrl;
    }
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      showSnack(context, 'Could not open the store.', error: true);
    }
  }

  Future<void> _email() async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: BillingConfig.supportEmail,
      queryParameters: <String, String>{'subject': 'Builder CRM billing'},
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final PurchaseResult result =
        await ref.read(purchaseControllerProvider.notifier).restore();
    if (!context.mounted) return;
    showSnack(
      context,
      result.isSuccess
          ? 'Subscription restored.'
          : result.message ?? 'Nothing to restore.',
      error: !result.isSuccess,
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.entitlements});
  final Entitlements entitlements;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SubscriptionTier tier = entitlements.effectiveTier;
    final bool paid = tier.isPaid;

    return Container(
      padding: Insets.card,
      decoration: BoxDecoration(
        gradient: paid
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[AppColors.brandDark, AppColors.seed],
              )
            : null,
        color: paid ? null : theme.colorScheme.surfaceContainerHigh,
        borderRadius: Radii.card,
        border: paid
            ? null
            : Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(tier.icon,
                  color: paid ? AppColors.accent : theme.colorScheme.primary,
                  size: 28),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${tier.label} plan',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: paid ? Colors.white : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      entitlements.status.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: paid
                            ? Colors.white.withValues(alpha: 0.85)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (entitlements.period != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Insets.md, vertical: Insets.xs),
                  decoration: BoxDecoration(
                    color: (paid ? Colors.white : theme.colorScheme.primary)
                        .withValues(alpha: 0.18),
                    borderRadius: Radii.stadium,
                  ),
                  child: Text(
                    entitlements.period!.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color:
                          paid ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: Insets.card,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: Radii.card,
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: tone, size: 22),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageRow extends ConsumerWidget {
  const _UsageRow({required this.resource});
  final LimitedResource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LimitCheck check = ref.watch(canCreateProvider(resource));
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              resource.plural[0].toUpperCase() + resource.plural.substring(1),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (check.isUnlimited)
            Row(
              children: <Widget>[
                Icon(Icons.all_inclusive, size: 15, color: c.success),
                const SizedBox(width: Insets.xs),
                Text('Unlimited',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: c.success,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            )
          else
            Row(
              children: <Widget>[
                SizedBox(
                  width: 72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.xs),
                    child: LinearProgressIndicator(
                      value: check.fraction,
                      minHeight: 5,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        check.allowed ? theme.colorScheme.primary : c.danger,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Text('${check.used}/${check.limit}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures()
                      ],
                    )),
              ],
            ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature, required this.included});
  final PaidFeature feature;
  final bool included;

  static String label(PaidFeature f) => switch (f) {
        PaidFeature.unlimitedCustomers => 'Unlimited customers',
        PaidFeature.unlimitedJobs => 'Unlimited jobs',
        PaidFeature.unlimitedDocuments => 'Unlimited invoices & quotes',
        PaidFeature.unlimitedPhotos => 'Unlimited job photos',
        PaidFeature.cleanPdf => 'PDFs without a watermark',
        PaidFeature.customBranding => 'Custom PDF branding',
        PaidFeature.advancedDashboard => 'Advanced dashboard & charts',
        PaidFeature.reports => 'Business reports',
        PaidFeature.dataExport => 'Data export (CSV)',
        PaidFeature.documentStorage => 'Document storage',
        PaidFeature.recurringInvoices => 'Recurring invoices',
        PaidFeature.automaticReminders => 'Automatic payment reminders',
        PaidFeature.teamSeats => 'Team seats',
        PaidFeature.prioritySupport => 'Priority support',
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs + 2),
      child: Row(
        children: <Widget>[
          Icon(
            included ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            size: 18,
            color: included
                ? c.success
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              label(feature),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: included
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (!included)
            Text(
              Entitlements.minimumTier(feature).label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
