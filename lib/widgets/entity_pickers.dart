import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer.dart';
import '../models/job.dart';
import '../providers/data_providers.dart';

/// A searchable modal bottom sheet to pick a customer. Returns the selected
/// [Customer] or null if dismissed.
Future<Customer?> showCustomerPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => _CustomerPickerSheet(ref: ref),
  );
}

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    // Read (not watch): this sheet is built outside its owning consumer's
    // build, and re-reads on each setState from the search field.
    final List<Customer> all =
        widget.ref.read(customersProvider).valueOrNull ?? <Customer>[];
    final List<Customer> filtered = _query.isEmpty
        ? all
        : all
            .where((Customer c) =>
                c.name.toLowerCase().contains(_query.toLowerCase()) ||
                c.phone.contains(_query))
            .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                children: <Widget>[
                  Text('Select customer',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SearchBar(
                    hintText: 'Search',
                    leading: const Icon(Icons.search),
                    onChanged: (String v) => setState(() => _query = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No customers found.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (BuildContext context, int i) => ListTile(
                        leading: CircleAvatar(
                          child: Text(filtered[i].name.isNotEmpty
                              ? filtered[i].name[0].toUpperCase()
                              : '?'),
                        ),
                        title: Text(filtered[i].name),
                        subtitle: filtered[i].phone.isEmpty
                            ? null
                            : Text(filtered[i].phone),
                        onTap: () => Navigator.of(context).pop(filtered[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A searchable modal bottom sheet to pick a job for a given customer (or all
/// jobs when [customerId] is null). Returns the selected [Job] or null.
Future<Job?> showJobPicker(
  BuildContext context,
  WidgetRef ref, {
  String? customerId,
}) {
  return showModalBottomSheet<Job>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) {
      final List<Job> jobs = (customerId != null
              ? ref.read(jobsByCustomerProvider(customerId)).valueOrNull
              : ref.read(jobsProvider).valueOrNull) ??
          <Job>[];
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Select job'),
            ),
            Expanded(
              child: jobs.isEmpty
                  ? const Center(child: Text('No jobs available.'))
                  : ListView.builder(
                      itemCount: jobs.length,
                      itemBuilder: (BuildContext context, int i) => ListTile(
                        title: Text(jobs[i].title),
                        subtitle: Text(jobs[i].customerName),
                        onTap: () => Navigator.of(context).pop(jobs[i]),
                      ),
                    ),
            ),
          ],
        ),
      );
    },
  );
}
