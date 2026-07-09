import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/payment.dart';
import '../../providers/data_providers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';

/// A ledger of all recorded payments.
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Payment>> payments = ref.watch(paymentsProvider);
    final String symbol = ref.watch(currencySymbolProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: AsyncValueView<List<Payment>>(
        value: payments,
        data: (List<Payment> list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.payments_outlined,
              title: 'No payments',
              message: 'Payments recorded against invoices appear here.',
            );
          }
          final double total =
              list.fold<double>(0, (double s, Payment p) => s + p.amount);
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('${list.length} payment${list.length == 1 ? '' : 's'}',
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int i) {
                    final Payment p = list[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.check),
                        ),
                        title: Text(Formatters.money(p.amount, symbol: symbol)),
                        subtitle: Text(
                          '${p.invoiceNumber} · ${p.customerName}\n'
                          '${p.method}${p.date == null ? '' : ' · ${Formatters.date(p.date!)}'}',
                        ),
                        isThreeLine: true,
                        onTap: () => context.push(Routes.invoiceDetail(p.invoiceId)),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
