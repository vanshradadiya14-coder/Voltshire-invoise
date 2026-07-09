import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/expense.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ui_helpers.dart';

/// A list of business expenses with a running total.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Expense>> expenses = ref.watch(expensesProvider);
    final String symbol = ref.watch(currencySymbolProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.expenseNew),
        icon: const Icon(Icons.add),
        label: const Text('New expense'),
      ),
      body: AsyncValueView<List<Expense>>(
        value: expenses,
        data: (List<Expense> list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No expenses',
              message: 'Track materials, fuel, equipment, labour and more.',
              actionLabel: 'Add expense',
              onAction: () => context.push(Routes.expenseNew),
            );
          }
          final double total =
              list.fold<double>(0, (double s, Expense e) => s + e.amount);
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('${list.length} expense${list.length == 1 ? '' : 's'}',
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int i) {
                    final Expense e = list[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: e.hasReceipt
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: e.receiptUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : CircleAvatar(
                                child: Text(e.category.isNotEmpty
                                    ? e.category[0].toUpperCase()
                                    : '?'),
                              ),
                        title: Text(e.category),
                        subtitle: Text(
                          '${e.supplier.isEmpty ? '' : '${e.supplier} · '}'
                          '${e.date == null ? '' : Formatters.date(e.date!)}',
                        ),
                        trailing: Text(
                          Formatters.money(e.amount, symbol: symbol),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () => context.push(Routes.expenseEdit(e.id)),
                        onLongPress: () async {
                          final bool ok = await showConfirmDialog(
                            context,
                            title: 'Delete expense?',
                            message: 'This permanently deletes the expense.',
                            confirmLabel: 'Delete',
                            destructive: true,
                          );
                          if (ok) {
                            await ref.read(expenseRepositoryProvider).delete(e);
                          }
                        },
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
