import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/quote.dart';
import '../../providers/data_providers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';

/// List of quotations.
class QuotesScreen extends ConsumerWidget {
  const QuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Quote>> quotes = ref.watch(quotesProvider);
    final String symbol = ref.watch(currencySymbolProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quotations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.quoteNew),
        icon: const Icon(Icons.add),
        label: const Text('New quote'),
      ),
      body: AsyncValueView<List<Quote>>(
        value: quotes,
        data: (List<Quote> list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.description_outlined,
              title: 'No quotations',
              message: 'Create a professional quote for a customer.',
              actionLabel: 'New quote',
              onAction: () => context.push(Routes.quoteNew),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int i) {
              final Quote q = list[i];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  title: Row(
                    children: <Widget>[
                      Expanded(child: Text(q.numberFormatted)),
                      StatusChip(
                        label: q.isExpired ? 'Expired' : q.status.label,
                        color: q.status.color,
                        dense: true,
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${q.customerName} · ${Formatters.money(q.grandTotal, symbol: symbol)}',
                  ),
                  onTap: () => context.push(Routes.quoteDetail(q.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
