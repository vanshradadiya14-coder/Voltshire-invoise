import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../providers/data_providers.dart';
import '../../providers/search_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ui_helpers.dart';

/// Global search across customers, jobs, quotes, invoices and payments.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    // Clear the term when leaving so the next visit starts fresh.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SearchResults results = ref.watch(globalSearchProvider);
    final String symbol = ref.watch(currencySymbolProvider);
    final String term = ref.watch(globalSearchTermProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              controller: _controller,
              autoFocus: true,
              hintText: 'Search everything',
              leading: const Icon(Icons.search),
              trailing: <Widget>[
                if (term.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      ref.read(globalSearchTermProvider.notifier).state = '';
                    },
                  ),
              ],
              onChanged: (String v) =>
                  ref.read(globalSearchTermProvider.notifier).state = v,
            ),
          ),
        ),
      ),
      body: term.trim().isEmpty
          ? const EmptyState(
              icon: Icons.search,
              title: 'Search your business',
              message:
                  'Find customers, jobs, quotes, invoices and payments in one place.',
            )
          : results.isEmpty
              ? EmptyState(
                  icon: Icons.search_off,
                  title: 'No results',
                  message: 'Nothing matches "$term".',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: <Widget>[
                    if (results.customers.isNotEmpty) ...<Widget>[
                      const SectionHeader('Customers'),
                      ...results.customers.map((c) => _tile(
                            icon: Icons.person_outline,
                            title: c.name,
                            subtitle: c.phone,
                            onTap: () => context.push(Routes.customerDetail(c.id)),
                          )),
                    ],
                    if (results.jobs.isNotEmpty) ...<Widget>[
                      const SectionHeader('Jobs'),
                      ...results.jobs.map((j) => _tile(
                            icon: Icons.construction_outlined,
                            title: j.title,
                            subtitle: j.customerName,
                            onTap: () => context.push(Routes.jobDetail(j.id)),
                          )),
                    ],
                    if (results.quotes.isNotEmpty) ...<Widget>[
                      const SectionHeader('Quotes'),
                      ...results.quotes.map((q) => _tile(
                            icon: Icons.description_outlined,
                            title: q.numberFormatted,
                            subtitle:
                                '${q.customerName} · ${Formatters.money(q.grandTotal, symbol: symbol)}',
                            onTap: () => context.push(Routes.quoteDetail(q.id)),
                          )),
                    ],
                    if (results.invoices.isNotEmpty) ...<Widget>[
                      const SectionHeader('Invoices'),
                      ...results.invoices.map((i) => _tile(
                            icon: Icons.receipt_long_outlined,
                            title: i.numberFormatted,
                            subtitle:
                                '${i.customerName} · ${Formatters.money(i.grandTotal, symbol: symbol)}',
                            onTap: () => context.push(Routes.invoiceDetail(i.id)),
                          )),
                    ],
                    if (results.payments.isNotEmpty) ...<Widget>[
                      const SectionHeader('Payments'),
                      ...results.payments.map((p) => _tile(
                            icon: Icons.payments_outlined,
                            title: Formatters.money(p.amount, symbol: symbol),
                            subtitle: '${p.invoiceNumber} · ${p.customerName}',
                            onTap: () => context.push(Routes.invoiceDetail(p.invoiceId)),
                          )),
                    ],
                  ],
                ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}
