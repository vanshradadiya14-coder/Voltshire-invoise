import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_providers.dart';
import '../../providers/data_providers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/ui_helpers.dart';

/// A menu of secondary sections not on the bottom bar.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(companyProfileProvider).valueOrNull;
    final user = ref.watch(appUserProvider).valueOrNull;

    final List<_MenuItem> items = <_MenuItem>[
      _MenuItem('Quotations', Icons.description_outlined, Routes.quotes),
      _MenuItem('Payments', Icons.payments_outlined, Routes.payments),
      _MenuItem('Expenses', Icons.account_balance_wallet_outlined, Routes.expenses),
      _MenuItem('Documents', Icons.folder_outlined, Routes.documents),
      _MenuItem('Reports', Icons.bar_chart_outlined, Routes.reports),
      _MenuItem('Search', Icons.search, Routes.search),
      _MenuItem('Settings', Icons.settings_outlined, Routes.settings),
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
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: Icon(items[i].icon),
                    title: Text(items[i].label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(items[i].route),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
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

class _MenuItem {
  const _MenuItem(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}
