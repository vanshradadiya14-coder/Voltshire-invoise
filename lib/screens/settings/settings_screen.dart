import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/ui_helpers.dart';

/// App settings: appearance, company details and account.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final company = ref.watch(companyProfileProvider).valueOrNull;
    final user = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          const SectionHeader('Appearance'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                RadioListTile<ThemeMode>(
                  title: const Text('System default'),
                  value: ThemeMode.system,
                  groupValue: mode,
                  onChanged: (ThemeMode? m) =>
                      ref.read(themeModeProvider.notifier).setMode(m!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Light'),
                  value: ThemeMode.light,
                  groupValue: mode,
                  onChanged: (ThemeMode? m) =>
                      ref.read(themeModeProvider.notifier).setMode(m!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Dark'),
                  value: ThemeMode.dark,
                  groupValue: mode,
                  onChanged: (ThemeMode? m) =>
                      ref.read(themeModeProvider.notifier).setMode(m!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SectionHeader('Company'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: const Text('Company details'),
                  subtitle: Text(company?.companyName.isNotEmpty ?? false
                      ? company!.companyName
                      : 'Not set'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('${Routes.settings}/company'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_balance_outlined),
                  title: const Text('Bank details'),
                  subtitle: Text(company?.bankName.isNotEmpty ?? false
                      ? company!.bankName
                      : 'Not set'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('${Routes.settings}/company'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Invoice defaults'),
                  subtitle: Text(
                    'Prefix ${company?.invoicePrefix ?? AppConstants.defaultInvoicePrefix} · '
                    'VAT ${Formatters.percent(company?.defaultVatRate ?? AppConstants.defaultVatRate)} · '
                    '${company?.currencyCode ?? AppConstants.defaultCurrencyCode}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('${Routes.settings}/company'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SectionHeader('Account'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('Signed in as'),
                  subtitle: Text(user?.email ?? ''),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                  title: Text('Sign out',
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  onTap: () async {
                    final bool ok = await showConfirmDialog(
                      context,
                      title: 'Sign out?',
                      message: 'You can sign back in anytime.',
                      confirmLabel: 'Sign out',
                    );
                    if (ok) {
                      await ref.read(authControllerProvider.notifier).signOut();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('${AppConstants.appName} v1.0.0',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
