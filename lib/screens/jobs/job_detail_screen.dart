import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';
import '../../models/job.dart';
import '../../models/job_photo.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/ui_helpers.dart';

/// Full job view: details, status control, photos preview, expenses.
class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({required this.jobId, super.key});
  final String jobId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Delete job?',
      message: 'This permanently deletes the job.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(jobRepositoryProvider).delete(jobId);
    if (context.mounted) {
      showSnack(context, 'Job deleted.');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Job?> job = ref.watch(jobProvider(jobId));
    final String symbol = ref.watch(currencySymbolProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.jobEdit(jobId)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: AsyncValueView<Job?>(
        value: job,
        data: (Job? j) {
          if (j == null) return const Center(child: Text('Job not found.'));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            j.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        StatusChip(label: j.status.label, color: j.status.color),
                      ],
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => context.push(Routes.customerDetail(j.customerId)),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.person_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(j.customerName),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DetailRow(
                        label: 'Site', value: j.siteAddress, icon: Icons.place_outlined),
                    DetailRow(
                        label: 'Start',
                        value: j.startDate == null ? '' : Formatters.date(j.startDate!),
                        icon: Icons.play_arrow_outlined),
                    DetailRow(
                        label: 'Completion',
                        value: j.completionDate == null
                            ? ''
                            : Formatters.date(j.completionDate!),
                        icon: Icons.flag_outlined),
                    if (j.description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text('Description',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(j.description),
                    ],
                    if (j.notes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text('Notes', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(j.notes),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _StatusButtons(job: j, ref: ref),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(
                          '${Routes.quoteNew}?customerId=${j.customerId}&jobId=${j.id}'),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Quote'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push(
                          '${Routes.invoiceNew}?customerId=${j.customerId}&jobId=${j.id}'),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Invoice'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PhotosSection(jobId: jobId),
              const SizedBox(height: 8),
              _ExpensesSection(jobId: jobId, symbol: symbol),
            ],
          );
        },
      ),
    );
  }
}

class _StatusButtons extends StatelessWidget {
  const _StatusButtons({required this.job, required this.ref});
  final Job job;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        children: JobStatus.values.map((JobStatus s) {
          final bool selected = job.status == s;
          return ChoiceChip(
            label: Text(s.label),
            selected: selected,
            onSelected: (_) {
              if (!selected) {
                ref.read(jobRepositoryProvider).updateStatus(job.id, s);
              }
            },
          );
        }).toList(),
      ),
    );
  }
}

class _PhotosSection extends ConsumerWidget {
  const _PhotosSection({required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<JobPhoto>> photos = ref.watch(photosForJobProvider(jobId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          'Photos',
          trailing: TextButton.icon(
            onPressed: () => context.push(Routes.jobPhotos(jobId)),
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: const Text('Manage'),
          ),
        ),
        photos.when(
          loading: () => const SizedBox(
              height: 90, child: Center(child: CircularProgressIndicator())),
          error: (Object e, _) => Text('Error: $e'),
          data: (List<JobPhoto> list) => list.isEmpty
              ? const AppCard(child: Text('No photos attached yet.'))
              : SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int i) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: list[i].url,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 96,
                          height: 96,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ExpensesSection extends ConsumerWidget {
  const _ExpensesSection({required this.jobId, required this.symbol});
  final String jobId;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Expense>> expenses =
        ref.watch(expensesForJobProvider(jobId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          'Expenses',
          trailing: TextButton.icon(
            onPressed: () => context.push('${Routes.expenseNew}?jobId=$jobId'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
        ),
        expenses.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator())),
          error: (Object e, _) => Text('Error: $e'),
          data: (List<Expense> list) {
            if (list.isEmpty) {
              return const AppCard(child: Text('No expenses recorded for this job.'));
            }
            final double total =
                list.fold<double>(0, (double s, Expense e) => s + e.amount);
            return AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < list.length; i++) ...<Widget>[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      title: Text(list[i].category),
                      subtitle: Text(list[i].supplier),
                      trailing: Text(
                        Formatters.money(list[i].amount, symbol: symbol),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Total',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    trailing: Text(
                      Formatters.money(total, symbol: symbol),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
