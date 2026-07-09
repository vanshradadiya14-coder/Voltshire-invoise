import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/invoice.dart';
import '../../providers/data_providers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';

/// List of invoices with a status filter and a header total.
class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  InvoiceStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Invoice>> invoices = ref.watch(invoicesProvider);
    final String symbol = ref.watch(currencySymbolProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.invoiceNew),
        icon: const Icon(Icons.add),
        label: const Text('New invoice'),
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: <Widget>[
                _chip('All', _filter == null, () => setState(() => _filter = null)),
                for (final InvoiceStatus s in InvoiceStatus.values)
                  _chip(s.label, _filter == s, () => setState(() => _filter = s)),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Invoice>>(
              value: invoices,
              data: (List<Invoice> all) {
                final List<Invoice> list = _filter == null
                    ? all
                    : all.where((Invoice i) => i.status == _filter).toList();
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No invoices',
                    message: _filter == null
                        ? 'Create your first invoice.'
                        : 'No ${_filter!.label.toLowerCase()} invoices.',
                    actionLabel: _filter == null ? 'New invoice' : null,
                    onAction: _filter == null
                        ? () => context.push(Routes.invoiceNew)
                        : null,
                  );
                }
                final double total = list.fold<double>(
                    0, (double s, Invoice i) => s + i.grandTotal);
                return Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text('${list.length} invoice${list.length == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.bodySmall),
                          Text('Total: ${Formatters.money(total, symbol: symbol)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int i) {
                          final Invoice inv = list[i];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              title: Row(
                                children: <Widget>[
                                  Expanded(child: Text(inv.numberFormatted)),
                                  StatusChip(
                                    label: inv.status.label,
                                    color: inv.status.color,
                                    dense: true,
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(inv.customerName),
                                  Text(
                                    '${inv.issueDate == null ? '' : Formatters.date(inv.issueDate!)} · ${Formatters.money(inv.grandTotal, symbol: symbol)}'
                                    '${inv.balanceDue > 0 && inv.amountPaid > 0 ? '  ·  Due ${Formatters.money(inv.balanceDue, symbol: symbol)}' : ''}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                              onTap: () =>
                                  context.push(Routes.invoiceDetail(inv.id)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}
