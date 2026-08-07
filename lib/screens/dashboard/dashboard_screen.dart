import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/dashboard_layout.dart';
import '../../models/dashboard_metrics.dart';
import '../../models/invoice.dart';
import '../../models/job.dart';
import '../../models/subscription.dart';
import '../../providers/dashboard_layout_provider.dart';
import '../../providers/dashboard_v2_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/charts/cash_flow_chart.dart';
import '../../widgets/charts/expense_donut.dart';
import '../../widgets/charts/pipeline_funnel.dart';
import '../../widgets/charts/revenue_chart.dart';
import '../../widgets/dashboard/action_card.dart';
import '../../widgets/dashboard/metric_tile.dart';
import '../../widgets/dashboard/period_selector.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/ui_helpers.dart';
import '../../widgets/upgrade_prompt.dart';

/// The home dashboard.
///
/// Structure is driven by the user's saved [DashboardLayout], so sections can
/// be reordered and hidden. Free-tier users get the headline, action centre and
/// key figures; charts sit behind the Pro entitlement with a visible preview.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final DashboardLayout layout = ref.watch(dashboardLayoutProvider);
    final AsyncValue<DashboardMetrics> metrics =
        ref.watch(dashboardMetricsProvider);
    final String symbol = ref.watch(currencySymbolProvider);
    final String company =
        ref.watch(companyProfileProvider).valueOrNull?.companyName ?? '';
    final Entitlements ent = ref.watch(currentEntitlementsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(customersProvider);
          ref.invalidate(jobsProvider);
          ref.invalidate(invoicesProvider);
          ref.invalidate(paymentsProvider);
          ref.invalidate(expensesProvider);
          ref.invalidate(quotesProvider);
        },
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              floating: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Dashboard'),
                  if (company.isNotEmpty)
                    Text(
                      company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              actions: <Widget>[
                if (!ent.isPaid)
                  Padding(
                    padding: const EdgeInsets.only(right: Insets.xs),
                    child: GestureDetector(
                      onTap: () => openPaywall(context),
                      child: const Center(child: ProBadge()),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search',
                  onPressed: () => context.push(Routes.search),
                ),
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Customise dashboard',
                  onPressed: () => context.push(Routes.customizeDashboard),
                ),
              ],
            ),

            const SliverToBoxAdapter(child: SizedBox(height: Insets.xs)),
            const SliverToBoxAdapter(child: PeriodSelector()),
            const SliverToBoxAdapter(child: SizedBox(height: Insets.lg)),

            if (metrics.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (metrics.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: Insets.card,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.error_outline,
                            size: 40, color: theme.colorScheme.error),
                        const SizedBox(height: Insets.md),
                        const Text("Couldn't load your dashboard"),
                        const SizedBox(height: Insets.md),
                        FilledButton.tonal(
                          onPressed: () => ref.invalidate(invoicesProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.gutter,
                  0,
                  Insets.gutter,
                  Insets.scrollBottom,
                ),
                sliver: SliverList.separated(
                  itemCount: layout.visible.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: Insets.lg),
                  itemBuilder: (BuildContext context, int i) => _Section(
                    section: layout.visible[i],
                    metrics: metrics.value!,
                    symbol: symbol,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Renders one dashboard section. Kept as a separate widget so a change in one
/// provider only rebuilds the section that watches it.
class _Section extends ConsumerWidget {
  const _Section({
    required this.section,
    required this.metrics,
    required this.symbol,
  });

  final DashboardSection section;
  final DashboardMetrics metrics;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool advanced =
        ref.watch(hasFeatureProvider(PaidFeature.advancedDashboard));

    switch (section) {
      case DashboardSection.hero:
        return HeroMetric(
          label: 'Revenue received',
          metric: metrics.revenue,
          symbol: symbol,
          comparisonLabel: metrics.period.comparisonLabel,
          secondary: <(String, String)>[
            (
              'Invoiced',
              Formatters.money(metrics.invoiced.current, symbol: symbol)
            ),
            (
              'Profit',
              Formatters.money(metrics.profit.current, symbol: symbol)
            ),
            (
              'Collected',
              '${metrics.collectionRate.toStringAsFixed(0)}%',
            ),
          ],
          onTap: () => context.push(Routes.reports),
        );

      case DashboardSection.actions:
        final List<ActionItem> items = ref.watch(actionCentreProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionHeader(
              'Needs attention',
              trailing: items.isEmpty
                  ? null
                  : Text(
                      '${items.length}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.of(context).danger,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
            ),
            ActionCentre(items: items, symbol: symbol),
          ],
        );

      case DashboardSection.metrics:
        return _MetricGrid(metrics: metrics, symbol: symbol);

      case DashboardSection.revenueChart:
        return _Gated(
          enabled: advanced,
          child: RevenueChart(
            series: ref.watch(revenueTrendProvider),
            symbol: symbol,
          ),
        );

      case DashboardSection.cashFlow:
        return _Gated(
          enabled: advanced,
          child: CashFlowChart(
            series: ref.watch(cashFlowSeriesProvider),
            symbol: symbol,
          ),
        );

      case DashboardSection.pipeline:
        return _Gated(
          enabled: advanced,
          child: PipelineFunnel(
            stages: ref.watch(jobPipelineProvider),
            symbol: symbol,
            onStageTap: (_) => context.push(Routes.jobs),
          ),
        );

      case DashboardSection.expenses:
        return _Gated(
          enabled: advanced,
          child: ExpenseDonut(
            slices: ref.watch(expenseBreakdownProvider),
            symbol: symbol,
          ),
        );

      case DashboardSection.topCustomers:
        return _Gated(
          enabled: advanced,
          child: RankedBars(
            title: 'Top customers',
            subtitle: 'By payments received this period',
            slices: ref.watch(topCustomersProvider),
            symbol: symbol,
            emptyMessage: 'No payments received in this period',
          ),
        );

      case DashboardSection.recentJobs:
        return _RecentJobs(jobs: ref.watch(recentJobsProvider));

      case DashboardSection.recentInvoices:
        return _RecentInvoices(
          invoices: ref.watch(recentInvoicesProvider),
          symbol: symbol,
        );
    }
  }
}

/// Wraps a chart in a feature gate — locked users still see the shape of what
/// they're missing, which converts far better than hiding it.
class _Gated extends StatelessWidget {
  const _Gated({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (enabled) return child;
    return FeatureGate(
      feature: PaidFeature.advancedDashboard,
      title: 'Charts are a Pro feature',
      message: 'See trends, cash flow and where your money goes.',
      child: child,
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics, required this.symbol});
  final DashboardMetrics metrics;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors c = AppColors.of(context);
    final String vs = metrics.period.comparisonLabel;
    final int columns = Breakpoints.metricColumns(context);

    final List<Widget> tiles = <Widget>[
      MetricTile(
        label: 'Profit',
        metric: metrics.profit,
        icon: Icons.savings_outlined,
        symbol: symbol,
        comparisonLabel: vs,
        accent: metrics.profit.current >= 0 ? c.success : c.danger,
        onTap: () => context.push(Routes.reports),
      ),
      MetricTile(
        label: 'Expenses',
        metric: metrics.expenses,
        icon: Icons.receipt_outlined,
        symbol: symbol,
        comparisonLabel: vs,
        accent: c.warning,
        onTap: () => context.push(Routes.expenses),
      ),
      MetricTile(
        label: 'Outstanding',
        metric: metrics.outstanding,
        icon: Icons.account_balance_wallet_outlined,
        symbol: symbol,
        comparisonLabel: vs,
        accent: c.warning,
        onTap: () => context.push(Routes.invoices),
      ),
      MetricTile(
        label: 'Overdue',
        metric: metrics.overdue,
        icon: Icons.warning_amber_rounded,
        symbol: symbol,
        comparisonLabel: vs,
        accent: c.danger,
        onTap: () => context.push(Routes.invoices),
      ),
      MetricTile(
        label: 'New jobs',
        metric: metrics.newJobs,
        icon: Icons.construction_outlined,
        symbol: symbol,
        comparisonLabel: vs,
        accent: c.info,
        onTap: () => context.push(Routes.jobs),
      ),
      MetricTile(
        label: 'Jobs completed',
        metric: metrics.completedJobs,
        icon: Icons.task_alt,
        symbol: symbol,
        comparisonLabel: vs,
        accent: c.success,
        onTap: () => context.push(Routes.jobs),
      ),
      MetricTile(
        label: 'New customers',
        metric: metrics.newCustomers,
        icon: Icons.person_add_alt,
        symbol: symbol,
        comparisonLabel: vs,
        onTap: () => context.push(Routes.customers),
      ),
      MetricTile(
        label: 'Quotes won',
        metric: metrics.quotesAccepted,
        icon: Icons.handshake_outlined,
        symbol: symbol,
        comparisonLabel: vs,
        accent: c.success,
        onTap: () => context.push(Routes.quotes),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader('Key figures'),
        GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Insets.md,
          crossAxisSpacing: Insets.md,
          childAspectRatio: columns >= 3 ? 1.25 : 1.18,
          children: tiles,
        ),
        if (metrics.quotesSent.current > 0) ...<Widget>[
          const SizedBox(height: Insets.md),
          _ConversionStrip(metrics: metrics),
        ],
      ],
    );
  }
}

/// A slim summary of quote conversion — a ratio that deserves context rather
/// than its own tile.
class _ConversionStrip extends StatelessWidget {
  const _ConversionStrip({required this.metrics});
  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);
    final double rate = metrics.quoteConversionRate;
    final Color tone =
        rate >= 50 ? c.success : (rate >= 25 ? c.warning : c.danger);

    return Card(
      child: Padding(
        padding: Insets.card,
        child: Row(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Quote conversion',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: 2),
                Text(
                  '${rate.toStringAsFixed(0)}%',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800, color: tone),
                ),
              ],
            ),
            const SizedBox(width: Insets.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.xs),
                    child: LinearProgressIndicator(
                      value: (rate / 100).clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(tone),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    '${metrics.quotesAccepted.current.toStringAsFixed(0)} won '
                    'of ${metrics.quotesSent.current.toStringAsFixed(0)} sent',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

class _RecentJobs extends StatelessWidget {
  const _RecentJobs({required this.jobs});
  final List<Job> jobs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          'Recent jobs',
          trailing: TextButton(
            onPressed: () => context.push(Routes.jobs),
            child: const Text('See all'),
          ),
        ),
        if (jobs.isEmpty)
          const AppCard(child: Text('No jobs yet.'))
        else
          Card(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < jobs.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    title: Text(jobs[i].title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(jobs[i].customerName),
                    trailing: StatusChip(
                      label: jobs[i].status.label,
                      color: AppColors.of(context).resolve(jobs[i].status.color),
                      dense: true,
                    ),
                    onTap: () => context.push(Routes.jobDetail(jobs[i].id)),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _RecentInvoices extends StatelessWidget {
  const _RecentInvoices({required this.invoices, required this.symbol});
  final List<Invoice> invoices;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          'Recent invoices',
          trailing: TextButton(
            onPressed: () => context.push(Routes.invoices),
            child: const Text('See all'),
          ),
        ),
        if (invoices.isEmpty)
          const AppCard(child: Text('No invoices yet.'))
        else
          Card(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < invoices.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    title: Text(invoices[i].numberFormatted),
                    subtitle: Text(invoices[i].customerName),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          Formatters.money(invoices[i].grandTotal,
                              symbol: symbol),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        StatusChip(
                          label: invoices[i].status.label,
                          color: AppColors.of(context)
                              .resolve(invoices[i].status.color),
                          dense: true,
                        ),
                      ],
                    ),
                    onTap: () =>
                        context.push(Routes.invoiceDetail(invoices[i].id)),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
