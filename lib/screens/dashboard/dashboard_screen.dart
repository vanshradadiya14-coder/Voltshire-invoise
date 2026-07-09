import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/invoice.dart';
import '../../models/job.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/data_providers.dart';
import '../../theme/app_colors.dart';
import '../../routes/app_routes.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/ui_helpers.dart';

/// The home dashboard: key metrics + recent jobs and invoices.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardStats> stats = ref.watch(dashboardStatsProvider);
    final String symbol = ref.watch(currencySymbolProvider);
    final String company =
        ref.watch(companyProfileProvider).valueOrNull?.companyName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Dashboard'),
            if (company.isNotEmpty)
              Text(
                company,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      body: AsyncValueView<DashboardStats>(
        value: stats,
        data: (DashboardStats s) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardStatsProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: <Widget>[
                  StatCard(
                    label: 'Monthly Revenue',
                    value: Formatters.money(s.monthlyRevenue, symbol: symbol),
                    icon: Icons.trending_up,
                    color: AppColors.success,
                  ),
                  StatCard(
                    label: 'Outstanding',
                    value: Formatters.money(s.outstandingTotal, symbol: symbol),
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppColors.warning,
                    onTap: () => context.push(Routes.invoices),
                  ),
                  StatCard(
                    label: 'Active Jobs',
                    value: '${s.activeJobs}',
                    icon: Icons.construction,
                    color: AppColors.info,
                    onTap: () => context.push(Routes.jobs),
                  ),
                  StatCard(
                    label: 'Completed Jobs',
                    value: '${s.completedJobs}',
                    icon: Icons.task_alt,
                    color: AppColors.success,
                    onTap: () => context.push(Routes.jobs),
                  ),
                  StatCard(
                    label: 'Pending Payments',
                    value: '${s.pendingPayments}',
                    icon: Icons.pending_actions,
                    color: AppColors.danger,
                    onTap: () => context.push(Routes.payments),
                  ),
                  StatCard(
                    label: 'Total Customers',
                    value: '${s.totalCustomers}',
                    icon: Icons.people,
                    color: AppColors.seed,
                    onTap: () => context.push(Routes.customers),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _RecentJobs(jobs: s.recentJobs),
              const SizedBox(height: 8),
              _RecentInvoices(invoices: s.recentInvoices, symbol: symbol),
              const SizedBox(height: 24),
            ],
          ),
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
          'Recent Jobs',
          trailing: TextButton(
            onPressed: () => context.push(Routes.jobs),
            child: const Text('See all'),
          ),
        ),
        if (jobs.isEmpty)
          const AppCard(child: Text('No jobs yet.'))
        else
          AppCard(
            padding: EdgeInsets.zero,
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
                      color: jobs[i].status.color,
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
          'Recent Invoices',
          trailing: TextButton(
            onPressed: () => context.push(Routes.invoices),
            child: const Text('See all'),
          ),
        ),
        if (invoices.isEmpty)
          const AppCard(child: Text('No invoices yet.'))
        else
          AppCard(
            padding: EdgeInsets.zero,
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
                          Formatters.money(invoices[i].grandTotal, symbol: symbol),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        StatusChip(
                          label: invoices[i].status.label,
                          color: invoices[i].status.color,
                          dense: true,
                        ),
                      ],
                    ),
                    onTap: () => context.push(Routes.invoiceDetail(invoices[i].id)),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
