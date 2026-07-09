import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/customer.dart';
import '../../providers/data_providers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';

/// Searchable list of customers.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Customer>> customers = ref.watch(customerSearchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.customerNew),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('New'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _search,
              hintText: 'Search customers',
              leading: const Icon(Icons.search),
              trailing: <Widget>[
                if (_search.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _search.clear();
                      ref.read(customerSearchTermProvider.notifier).state = '';
                      setState(() {});
                    },
                  ),
              ],
              onChanged: (String v) {
                ref.read(customerSearchTermProvider.notifier).state = v;
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Customer>>(
              value: customers,
              data: (List<Customer> list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline,
                    title: 'No customers',
                    message: _search.text.isEmpty
                        ? 'Add your first customer to get started.'
                        : 'No customers match "${_search.text}".',
                    actionLabel: _search.text.isEmpty ? 'Add customer' : null,
                    onAction: _search.text.isEmpty
                        ? () => context.push(Routes.customerNew)
                        : null,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int i) {
                    final Customer c = list[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                          ),
                        ),
                        title: Text(c.name),
                        subtitle: Text(
                          <String>[c.phone, c.email]
                              .where((String s) => s.isNotEmpty)
                              .join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(Routes.customerDetail(c.id)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
