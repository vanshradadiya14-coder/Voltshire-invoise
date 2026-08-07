import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../models/subscription.dart';
import '../../providers/auth_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../providers/theme_provider.dart';
import '../../providers/trash_providers.dart';
import '../../routes/app_routes.dart';
import '../../services/app_lock_service.dart';
import '../../widgets/ui_helpers.dart';
import '../../widgets/upgrade_prompt.dart';

/// App settings: appearance, company details and account.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final company = ref.watch(companyProfileProvider).valueOrNull;
    final user = ref.watch(appUserProvider).valueOrNull;
    final Entitlements entitlements = ref.watch(currentEntitlementsProvider);
    final int trashCount = ref.watch(trashCountProvider);

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
          const SectionHeader('Subscription'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: Icon(entitlements.effectiveTier.icon),
                  title: const Text('Your plan'),
                  subtitle: Text(
                    '${entitlements.effectiveTier.label}'
                    '${entitlements.isTrialing ? ' · trial, ${entitlements.trialDaysRemaining} days left' : ''}',
                  ),
                  trailing: entitlements.isPaid
                      ? const Icon(Icons.chevron_right)
                      : const ProBadge(compact: true),
                  onTap: () => context.push(Routes.subscription),
                ),
                if (!entitlements.isPaid) ...<Widget>[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.rocket_launch_outlined),
                    title: const Text('Upgrade'),
                    subtitle:
                        const Text('Unlimited records, charts and exports'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openPaywall(context),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SectionHeader('Data & security'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                _BiometricTile(),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Export data'),
                  subtitle: const Text('Download your records as CSV'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.dataExport),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Recently deleted'),
                  subtitle: Text(
                    trashCount == 0
                        ? 'Nothing deleted'
                        : '$trashCount ${trashCount == 1 ? 'item' : 'items'} · kept for 30 days',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.trash),
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
            child: Text('${AppConstants.appName} v${AppConstants.appVersion}',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Biometric app lock toggle.
///
/// Renders nothing on a device with no biometrics or PIN configured — offering
/// a switch that cannot work is worse than omitting it.
class _BiometricTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<bool> supported = ref.watch(appLockSupportedProvider);
    final AsyncValue<bool> enabled = ref.watch(appLockEnabledProvider);

    if (supported.valueOrNull != true) return const SizedBox.shrink();

    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint),
      title: const Text('Require unlock'),
      subtitle: const Text(
        'Ask for your fingerprint, face or device PIN when opening the app',
      ),
      value: enabled.valueOrNull ?? false,
      onChanged: (bool value) async {
        final AppLockService svc = ref.read(appLockServiceProvider);
        // Verify before enabling, so nobody can lock themselves out with a
        // biometric sensor that does not actually recognise them.
        if (value) {
          final bool ok =
              await svc.authenticate(reason: 'Confirm to turn on app lock');
          if (!ok) {
            if (context.mounted) {
              showSnack(context, 'Could not verify. App lock stays off.');
            }
            return;
          }
        }
        await svc.setEnabled(value);
        ref.invalidate(appLockEnabledProvider);
      },
    );
  }
}
