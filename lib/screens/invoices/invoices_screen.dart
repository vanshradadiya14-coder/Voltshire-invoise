import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/invoice.dart';
import '../../providers/data_providers.dart';
import '../../providers/trade_providers.dart';
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
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New invoice',
            onPressed: () => context.push(Routes.invoiceNew),
          ),
        ],
      ),
      // An empty invoice list on an account that *has* finished work is a live
      // prompt, not a placeholder. Telling someone "no invoices yet" when they
      // have three completed jobs waiting to be billed is a wasted screen.
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
                  // If there is finished work sitting unbilled, say so and
                  // offer to bill it — far more useful than a generic prompt.
                  final int unbilled =
                      ref.watch(uninvoicedCompletedJobsProvider).length;

                  if (_filter == null && unbilled > 0) {
                    return EmptyState(
                      icon: Icons.assignment_late_outlined,
                      title: 'Nothing invoiced yet',
                      message: 'You have $unbilled completed '
                          '${unbilled == 1 ? 'job' : 'jobs'} that '
                          "${unbilled == 1 ? 'has' : 'have'} never been "
                          'billed. Start there.',
                      actionLabel: 'See the work',
                      onAction: () => context.push(Routes.jobs),
                    );
                  }

                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No invoices',
                    message: _filter == null
                        ? 'Invoices you raise appear here, with what is paid, '
                            'outstanding and overdue at a glance.'
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
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int i) {
                          final Invoice inv = list[i];
                          final bool isDark = Theme.of(context).brightness == Brightness.dark;
                          final String initials = inv.customerName.isNotEmpty
                              ? inv.customerName.trim().split(' ').map((String w) => w.isNotEmpty ? w[0] : '').take(2).join()
                              : 'C';

                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? Theme.of(context).colorScheme.surfaceContainer : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF262E3A)
                                    : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.8),
                                width: 1,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => context.push(Routes.invoiceDetail(inv.id)),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: <Widget>[
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: isDark ? 0.22 : 0.12),
                                        child: Text(
                                          initials.toUpperCase(),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Row(
                                              children: <Widget>[
                                                Expanded(
                                                  child: Text(
                                                    inv.numberFormatted,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(fontWeight: FontWeight.w800),
                                                  ),
                                                ),
                                                StatusChip(
                                                  label: inv.status.label,
                                                  color: inv.status.color,
                                                  dense: true,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              inv.customerName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: Theme.of(context).colorScheme.onSurface,
                                                  ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: <Widget>[
                                                if (inv.issueDate != null) ...<Widget>[
                                                  Text(
                                                    Formatters.date(inv.issueDate!),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                  Text(' · ',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                          )),
                                                ],
                                                Text(
                                                  Formatters.money(inv.grandTotal, symbol: symbol),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        fontWeight: FontWeight.w800,
                                                        color: Theme.of(context).colorScheme.primary,
                                                      ),
                                                ),
                                                if (inv.balanceDue > 0 && inv.amountPaid > 0)
                                                  Expanded(
                                                    child: Text(
                                                      ' · Due ${Formatters.money(inv.balanceDue, symbol: symbol)}',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: const Color(0xFFC0342F),
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
