import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/trade_providers.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/ui_helpers.dart';

/// A menu of secondary sections not on the bottom bar.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(companyProfileProvider).valueOrNull;
    final user = ref.watch(appUserProvider).valueOrNull;

    // Live counts, so this reads as a dashboard of the business rather than a
    // static menu. "Quotations · 3 awaiting reply" is information; "Quotations"
    // is a signpost.
    final int quoteCount = ref.watch(quotesProvider).valueOrNull?.length ?? 0;
    final int unbilledExtras = ref.watch(unbilledVariationsProvider).length;
    final int priceCount = ref.watch(priceItemsProvider).valueOrNull?.length ?? 0;
    final int uninvoiced = ref.watch(uninvoicedCompletedJobsProvider).length;

    final List<_MenuGroup> groups = <_MenuGroup>[
      _MenuGroup('Work', <_MenuItem>[
        _MenuItem('Quotations', Icons.description_outlined, Routes.quotes,
            badge: quoteCount == 0 ? null : '$quoteCount'),
        _MenuItem('Payments', Icons.payments_outlined, Routes.payments),
        _MenuItem(
            'Expenses', Icons.account_balance_wallet_outlined, Routes.expenses),
        _MenuItem('Documents', Icons.folder_outlined, Routes.documents),
      ]),
      _MenuGroup('Tools', <_MenuItem>[
        _MenuItem('Price list', Icons.list_alt, Routes.priceList,
            subtitle: priceCount == 0
                ? 'Save the prices you use over and over'
                : '$priceCount saved ${priceCount == 1 ? 'price' : 'prices'}'),
        _MenuItem('Reports', Icons.bar_chart_outlined, Routes.reports),
        _MenuItem('Search', Icons.search, Routes.search),
      ]),
      _MenuGroup('Account', <_MenuItem>[
        _MenuItem('Settings', Icons.settings_outlined, Routes.settings),
      ]),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          AppCard(
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 26,
                  backgroundImage: (company?.logoUrl.isNotEmpty ?? false)
                      ? NetworkImage(company!.logoUrl)
                      : null,
                  child: (company?.logoUrl.isEmpty ?? true)
                      ? const Icon(Icons.business)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        company?.companyName.isNotEmpty ?? false
                            ? company!.companyName
                            : 'Your company',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (user?.email.isNotEmpty ?? false)
                        Text(user!.email,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('${Routes.settings}/company'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Things needing attention float to the top, above the menu. A
          // builder opening "More" to find something is better served by being
          // told what is outstanding first.
          if (uninvoiced > 0 || unbilledExtras > 0) ...<Widget>[
            if (uninvoiced > 0)
              _AlertTile(
                icon: Icons.receipt_long_outlined,
                message: '$uninvoiced completed '
                    '${uninvoiced == 1 ? 'job has' : 'jobs have'} not been '
                    'invoiced',
                onTap: () => context.push(Routes.jobs),
              ),
            if (unbilledExtras > 0)
              _AlertTile(
                icon: Icons.add_task_outlined,
                message: '$unbilledExtras agreed '
                    '${unbilledExtras == 1 ? 'extra is' : 'extras are'} waiting '
                    'to be billed',
                onTap: () => context.push(Routes.jobs),
              ),
            const SizedBox(height: 8),
          ],

          for (final _MenuGroup group in groups) ...<Widget>[
            SectionHeader(group.title),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < group.items.length; i++) ...<Widget>[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: Icon(group.items[i].icon),
                      title: Text(group.items[i].label),
                      subtitle: group.items[i].subtitle == null
                          ? null
                          : Text(group.items[i].subtitle!),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (group.items[i].badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                group.items[i].badge!,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => context.push(group.items[i].route),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final bool ok = await showConfirmDialog(
                context,
                title: 'Sign out?',
                message: 'You can sign back in anytime.',
                confirmLabel: 'Sign out',
              );
              if (ok) await ref.read(authControllerProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _MenuGroup {
  const _MenuGroup(this.title, this.items);
  final String title;
  final List<_MenuItem> items;
}

class _MenuItem {
  const _MenuItem(this.label, this.icon, this.route, {this.subtitle, this.badge});
  final String label;
  final IconData icon;
  final String route;
  final String? subtitle;
  final String? badge;
}

/// A tappable warning row for outstanding work.
class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.icon,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: Radii.card,
          onTap: onTap,
          child: Container(
            padding: Insets.cardTight,
            decoration: BoxDecoration(
              color: c.container(c.warning),
              borderRadius: Radii.card,
              border: Border.all(color: c.warning.withValues(alpha: 0.32)),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 20, color: c.warning),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right, size: 19, color: c.warning),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
