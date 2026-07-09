import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../models/job.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/ui_helpers.dart';

/// Full customer profile: contact info, jobs and invoices, quick actions.
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({required this.customerId, super.key});
  final String customerId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Delete customer?',
      message: 'This removes the customer record. Jobs and invoices are kept.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(customerRepositoryProvider).delete(customerId);
    if (context.mounted) {
      showSnack(context, 'Customer deleted.');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Customer?> customer = ref.watch(customerProvider(customerId));
    final String symbol = ref.watch(currencySymbolProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.customerEdit(customerId)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: AsyncValueView<Customer?>(
        value: customer,
        data: (Customer? c) {
          if (c == null) {
            return const Center(child: Text('Customer not found.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              _Header(customer: c, ref: ref),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DetailRow(label: 'Phone', value: c.phone, icon: Icons.phone_outlined),
                    DetailRow(label: 'Email', value: c.email, icon: Icons.mail_outline),
                    DetailRow(
                        label: 'Billing',
                        value: c.billingAddress,
                        icon: Icons.location_on_outlined),
                    DetailRow(
                        label: 'Site',
                        value: c.siteAddress,
                        icon: Icons.place_outlined),
                    DetailRow(label: 'Notes', value: c.notes, icon: Icons.notes_outlined),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.push('${Routes.jobNew}?customerId=$customerId'),
                      icon: const Icon(Icons.add),
                      label: const Text('New job'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          context.push('${Routes.invoiceNew}?customerId=$customerId'),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('New invoice'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _JobsSection(customerId: customerId),
              const SizedBox(height: 8),
              _InvoicesSection(customerId: customerId, symbol: symbol),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.customer, required this.ref});
  final Customer customer;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              customer.name,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (customer.phone.isNotEmpty)
            IconButton.filledTonal(
              icon: const Icon(Icons.call),
              onPressed: () => ref.read(shareServiceProvider).call(customer.phone),
            ),
          if (customer.email.isNotEmpty)
            IconButton.filledTonal(
              icon: const Icon(Icons.mail_outline),
              onPressed: () =>
                  ref.read(shareServiceProvider).composeEmail(to: customer.email),
            ),
        ],
      ),
    );
  }
}

class _JobsSection extends ConsumerWidget {
  const _JobsSection({required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Job>> jobs = ref.watch(jobsByCustomerProvider(customerId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader('Jobs'),
        jobs.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object e, _) => Text('Error: $e'),
          data: (List<Job> list) => list.isEmpty
              ? const AppCard(child: Text('No jobs for this customer yet.'))
              : AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < list.length; i++) ...<Widget>[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          title: Text(list[i].title),
                          subtitle: list[i].siteAddress.isEmpty
                              ? null
                              : Text(list[i].siteAddress,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: StatusChip(
                            label: list[i].status.label,
                            color: list[i].status.color,
                            dense: true,
                          ),
                          onTap: () => context.push(Routes.jobDetail(list[i].id)),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _InvoicesSection extends ConsumerWidget {
  const _InvoicesSection({required this.customerId, required this.symbol});
  final String customerId;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Invoice>> invoices =
        ref.watch(invoicesByCustomerProvider(customerId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader('Invoices'),
        invoices.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object e, _) => Text('Error: $e'),
          data: (List<Invoice> list) => list.isEmpty
              ? const AppCard(child: Text('No invoices for this customer yet.'))
              : AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < list.length; i++) ...<Widget>[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          title: Text(list[i].numberFormatted),
                          subtitle: Text(list[i].issueDate == null
                              ? ''
                              : Formatters.date(list[i].issueDate!)),
                          trailing: Text(
                            Formatters.money(list[i].grandTotal, symbol: symbol),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () =>
                              context.push(Routes.invoiceDetail(list[i].id)),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
