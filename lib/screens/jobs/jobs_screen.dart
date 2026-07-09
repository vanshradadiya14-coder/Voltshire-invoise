import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/job.dart';
import '../../providers/data_providers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';

/// List of jobs with a status filter.
class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  JobStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Job>> jobs = ref.watch(jobsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Jobs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.jobNew),
        icon: const Icon(Icons.add),
        label: const Text('New job'),
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                for (final JobStatus s in JobStatus.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(s.label),
                      selected: _filter == s,
                      onSelected: (_) => setState(() => _filter = s),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Job>>(
              value: jobs,
              data: (List<Job> all) {
                final List<Job> list = _filter == null
                    ? all
                    : all.where((Job j) => j.status == _filter).toList();
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.construction_outlined,
                    title: 'No jobs',
                    message: _filter == null
                        ? 'Create your first job to track work.'
                        : 'No ${_filter!.label.toLowerCase()} jobs.',
                    actionLabel: _filter == null ? 'New job' : null,
                    onAction:
                        _filter == null ? () => context.push(Routes.jobNew) : null,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int i) {
                    final Job j = list[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        title: Text(j.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(j.customerName),
                            if (j.startDate != null)
                              Text('Start: ${Formatters.date(j.startDate!)}',
                                  style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        isThreeLine: j.startDate != null,
                        trailing: StatusChip(
                          label: j.status.label,
                          color: j.status.color,
                          dense: true,
                        ),
                        onTap: () => context.push(Routes.jobDetail(j.id)),
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
