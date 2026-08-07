import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/billing_config.dart';
import '../../models/subscription.dart';
import '../../providers/subscription_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/ui_helpers.dart';

/// The upgrade screen.
///
/// Three deliberate choices here:
///  * yearly is preselected and shows the saving, because annual plans have far
///    better retention and the discount is real;
///  * the comparison table lists what the user *gets*, not what they're denied;
///  * "Restore purchases" is always visible — App Store review requires it and
///    users who reinstall need it.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({this.highlight, this.reason, super.key});

  /// Tier to visually emphasise. Defaults to Pro.
  final SubscriptionTier? highlight;

  /// Why the paywall opened, e.g. "You've reached the 5 customer limit".
  final String? reason;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  late SubscriptionTier _selectedTier =
      widget.highlight ?? SubscriptionTier.pro;

  @override
  void initState() {
    super.initState();
    // Record that the user has seen this, so the app can avoid nagging.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionRepositoryProvider)?.markPaywallSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final BillingPeriod period = ref.watch(paywallPeriodProvider);
    final Entitlements current = ref.watch(currentEntitlementsProvider);
    final AsyncValue<List<SubscriptionOffer>> offers =
        ref.watch(subscriptionOffersProvider);
    final bool busy = ref.watch(purchaseControllerProvider).isLoading;

    final List<SubscriptionOffer> list = offers.valueOrNull ?? const [];
    final SubscriptionOffer? selected = _offerFor(list, _selectedTier, period);

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 168,
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: _close,
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _Header(reason: widget.reason),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.sm, Insets.gutter, Insets.huge),
            sliver: SliverList.list(
              children: <Widget>[
                if (current.isPaid) ...<Widget>[
                  _CurrentPlanBanner(entitlements: current),
                  const SizedBox(height: Insets.lg),
                ],
                _PeriodToggle(
                  value: period,
                  onChanged: (BillingPeriod p) =>
                      ref.read(paywallPeriodProvider.notifier).state = p,
                ),
                const SizedBox(height: Insets.lg),
                for (final SubscriptionTier tier in <SubscriptionTier>[
                  SubscriptionTier.pro,
                  SubscriptionTier.business,
                ]) ...<Widget>[
                  _PlanCard(
                    tier: tier,
                    period: period,
                    offer: _offerFor(list, tier, period),
                    selected: _selectedTier == tier,
                    isCurrent: current.effectiveTier == tier &&
                        current.status.grantsAccess,
                    onTap: () => setState(() => _selectedTier = tier),
                  ),
                  const SizedBox(height: Insets.md),
                ],
                const SizedBox(height: Insets.sm),
                const _ComparisonTable(),
                const SizedBox(height: Insets.xl),
                if (offers.hasError || (offers.hasValue && list.isEmpty))
                  const _StoreUnavailable(),
                const SizedBox(height: Insets.sm),
                const _LegalFooter(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _PurchaseBar(
        offer: selected,
        tier: _selectedTier,
        period: period,
        busy: busy,
        loadingOffers: offers.isLoading,
        onBuy: selected == null ? null : () => _buy(selected),
        onRestore: busy ? null : _restore,
      ),
    );
  }

  SubscriptionOffer? _offerFor(
    List<SubscriptionOffer> offers,
    SubscriptionTier tier,
    BillingPeriod period,
  ) {
    for (final SubscriptionOffer o in offers) {
      if (o.tier == tier && o.period == period) return o;
    }
    return null;
  }

  Future<void> _buy(SubscriptionOffer offer) async {
    final PurchaseResult result =
        await ref.read(purchaseControllerProvider.notifier).buy(offer);
    if (!mounted) return;

    switch (result.outcome) {
      case PurchaseOutcome.success:
        showSnack(context, 'Welcome to ${offer.tier.label}. Everything is unlocked.');
        _close();
      case PurchaseOutcome.cancelled:
        break; // The user chose to back out; saying anything would be noise.
      case PurchaseOutcome.pending:
        showSnack(context,
            'Your purchase is pending approval. Features unlock once it clears.');
      case PurchaseOutcome.failed:
        showSnack(context, result.message ?? 'The purchase failed.', error: true);
    }
  }

  Future<void> _restore() async {
    final PurchaseResult result =
        await ref.read(purchaseControllerProvider.notifier).restore();
    if (!mounted) return;
    if (result.isSuccess) {
      showSnack(context, 'Your subscription has been restored.');
      _close();
    } else {
      showSnack(context, result.message ?? 'Nothing to restore.', error: true);
    }
  }

  /// Dismisses the paywall.
  ///
  /// Guarded rather than a bare `context.pop()`: this screen is normally
  /// pushed, but it is also rendered directly in widget tests where there is
  /// nothing to pop and no GoRouter in the tree.
  void _close() {
    final NavigatorState nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }
}

// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({this.reason});
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.brandDark,
            AppColors.seed,
            AppColors.seed.withValues(alpha: 0.82),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Insets.xl, Insets.huge, Insets.xl, Insets.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.workspace_premium_rounded,
                      color: AppColors.accent, size: 26),
                  const SizedBox(width: Insets.sm),
                  Text(
                    'Upgrade',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xs),
              Text(
                reason ?? 'Run the whole business without limits.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentPlanBanner extends StatelessWidget {
  const _CurrentPlanBanner({required this.entitlements});
  final Entitlements entitlements;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors c = AppColors.of(context);
    final bool problem = entitlements.hasBillingProblem;
    final Color tone = problem ? c.warning : c.success;

    return Container(
      padding: Insets.cardTight,
      decoration: BoxDecoration(
        color: c.container(tone),
        borderRadius: Radii.card,
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(problem ? Icons.error_outline : Icons.verified_outlined,
              color: tone, size: 20),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              problem
                  ? 'There is a problem with your payment method. Update it to keep ${entitlements.tier.label}.'
                  : entitlements.isTrialing
                      ? 'You are on the ${entitlements.tier.label} trial — '
                          '${entitlements.trialDaysRemaining} days left.'
                      : 'You are on ${entitlements.tier.label}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.value, required this.onChanged});
  final BillingPeriod value;
  final ValueChanged<BillingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Insets.xs),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: Radii.stadium,
      ),
      child: Row(
        children: BillingPeriod.values.map((BillingPeriod p) {
          final bool active = p == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: Motion.fast,
                curve: Motion.enter,
                padding: const EdgeInsets.symmetric(vertical: Insets.md),
                decoration: BoxDecoration(
                  color: active ? theme.colorScheme.surface : Colors.transparent,
                  borderRadius: Radii.stadium,
                  boxShadow:
                      active ? Shadows.low(theme.brightness) : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      p.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (p == BillingPeriod.yearly) ...<Widget>[
                      const SizedBox(width: Insets.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Insets.sm, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.9),
                          borderRadius: Radii.stadium,
                        ),
                        child: Text(
                          'SAVE ${SubscriptionTier.pro.yearlySavingPercent}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.black87,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.tier,
    required this.period,
    required this.offer,
    required this.selected,
    required this.isCurrent,
    required this.onTap,
  });

  final SubscriptionTier tier;
  final BillingPeriod period;
  final SubscriptionOffer? offer;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool recommended = tier == SubscriptionTier.pro;

    // Fall back to reference pricing until the store's live prices arrive, so
    // the card never renders blank.
    final String price = offer?.priceString ??
        '£${(period == BillingPeriod.yearly ? tier.yearlyPrice : tier.monthlyPrice).toStringAsFixed(2)}';
    final double monthly =
        offer?.monthlyEquivalent ??
            (period == BillingPeriod.yearly
                ? tier.yearlyPrice / 12
                : tier.monthlyPrice);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        padding: Insets.card,
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.16 : 0.06)
              : theme.colorScheme.surfaceContainerLowest,
          borderRadius: Radii.card,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(tier.icon, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: Insets.sm),
                Text(
                  tier.label,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: Insets.sm),
                if (recommended && !isCurrent)
                  _Pill(
                    label: 'MOST POPULAR',
                    background: AppColors.accent,
                    foreground: Colors.black87,
                  ),
                if (isCurrent)
                  _Pill(
                    label: 'CURRENT',
                    background: theme.colorScheme.primary,
                    foreground: theme.colorScheme.onPrimary,
                  ),
                const Spacer(),
                AnimatedScale(
                  duration: Motion.fast,
                  scale: selected ? 1 : 0.85,
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              tier.tagline,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Insets.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  price,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Text(
                  '/ ${period.unit}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            if (period == BillingPeriod.yearly)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xxs),
                child: Text(
                  'Works out at £${monthly.toStringAsFixed(2)} a month',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            if (offer?.hasTrial ?? false)
              Padding(
                padding: const EdgeInsets.only(top: Insets.sm),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.card_giftcard_rounded,
                        size: 16, color: AppColors.of(context).success),
                    const SizedBox(width: Insets.xs),
                    Text(
                      '${offer!.introOfferDays} days free, cancel anytime',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.of(context).success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: Radii.stadium),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 9,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

/// Feature comparison. Phrased as what each plan includes.
class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable();

  static const List<_Row> _rows = <_Row>[
    _Row('Customers', '5', 'Unlimited', 'Unlimited'),
    _Row('Jobs', '5', 'Unlimited', 'Unlimited'),
    _Row('Invoices & quotes', '5', 'Unlimited', 'Unlimited'),
    _Row('Job photos', '10', 'Unlimited', 'Unlimited'),
    _Row('PDF branding', 'Watermarked', 'Your logo', 'Full custom'),
    _Row('Advanced dashboard', '—', 'Yes', 'Yes'),
    _Row('Reports', '—', 'Yes', 'Yes + P&L'),
    _Row('Data export', '—', 'CSV', 'CSV + accounting'),
    _Row('Document storage', '—', 'Unlimited', 'Unlimited'),
    _Row('Recurring invoices', '—', '—', 'Yes'),
    _Row('Automatic reminders', '—', '—', 'Yes'),
    _Row('Team seats', '1', '1', '5'),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Compare plans',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: Insets.md),
        Card(
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md, vertical: Insets.md),
                color: theme.colorScheme.surfaceContainerHigh,
                child: Row(
                  children: <Widget>[
                    const Expanded(flex: 4, child: SizedBox.shrink()),
                    _head(context, 'Free'),
                    _head(context, 'Pro'),
                    _head(context, 'Business'),
                  ],
                ),
              ),
              for (int i = 0; i < _rows.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Insets.md, vertical: Insets.md),
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : Border(
                            top: BorderSide(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.6)),
                          ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        flex: 4,
                        child: Text(_rows[i].label,
                            style: theme.textTheme.bodySmall),
                      ),
                      _cell(context, _rows[i].free),
                      _cell(context, _rows[i].pro, emphasise: true),
                      _cell(context, _rows[i].business),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _head(BuildContext context, String label) => Expanded(
        flex: 3,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      );

  Widget _cell(BuildContext context, String value, {bool emphasise = false}) {
    final ThemeData theme = Theme.of(context);
    final bool dash = value == '—';
    return Expanded(
      flex: 3,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: emphasise && !dash ? FontWeight.w700 : FontWeight.w500,
          color: dash
              ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
              : emphasise
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.free, this.pro, this.business);
  final String label;
  final String free;
  final String pro;
  final String business;
}

class _StoreUnavailable extends StatelessWidget {
  const _StoreUnavailable();

  @override
  Widget build(BuildContext context) {
    final AppStatusColors c = AppColors.of(context);
    return Container(
      padding: Insets.cardTight,
      decoration: BoxDecoration(
        color: c.container(c.warning),
        borderRadius: Radii.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 20, color: c.warning),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              'Plans could not be loaded from the store right now. '
              'Check your connection and try again — the prices shown are '
              'for reference only.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 11,
      height: 1.5,
    );

    return Column(
      children: <Widget>[
        Text(
          'Subscriptions renew automatically unless cancelled at least 24 hours '
          'before the end of the current period. Manage or cancel anytime in '
          'your store account settings.',
          textAlign: TextAlign.center,
          style: style,
        ),
        const SizedBox(height: Insets.sm),
        Wrap(
          alignment: WrapAlignment.center,
          children: <Widget>[
            TextButton(
              onPressed: () => _open(BillingConfig.termsUrl),
              child: const Text('Terms', style: TextStyle(fontSize: 12)),
            ),
            Text('·', style: style),
            TextButton(
              onPressed: () => _open(BillingConfig.privacyUrl),
              child: const Text('Privacy', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _open(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _PurchaseBar extends StatelessWidget {
  const _PurchaseBar({
    required this.offer,
    required this.tier,
    required this.period,
    required this.busy,
    required this.loadingOffers,
    required this.onBuy,
    required this.onRestore,
  });

  final SubscriptionOffer? offer;
  final SubscriptionTier tier;
  final BillingPeriod period;
  final bool busy;
  final bool loadingOffers;
  final VoidCallback? onBuy;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool trial = offer?.hasTrial ?? false;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
            Insets.gutter, Insets.md, Insets.gutter, Insets.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onBuy,
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(
                        loadingOffers
                            ? 'Loading plans…'
                            : trial
                                ? 'Start ${offer!.introOfferDays}-day free trial'
                                : 'Get ${tier.label}',
                      ),
              ),
            ),
            TextButton(
              onPressed: onRestore,
              child: const Text('Restore purchases'),
            ),
          ],
        ),
      ),
    );
  }
}
