import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../providers/trash_providers.dart';
import '../../repositories/trash_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ui_helpers.dart';

/// Recently deleted records, recoverable for 30 days.
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  @override
  void initState() {
    super.initState();
    // Opportunistic cleanup: no Cloud Function needed on the free plan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trashRepositoryProvider)?.purgeExpired();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<TrashedItem>> items = ref.watch(trashProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently deleted'),
        actions: <Widget>[
          if ((items.valueOrNull ?? const <TrashedItem>[]).isNotEmpty)
            TextButton(
              onPressed: _emptyBin,
              child: Text(
                'Empty',
                style: TextStyle(color: AppColors.of(context).danger),
              ),
            ),
        ],
      ),
      body: AsyncValueView<List<TrashedItem>>(
        value: items,
        onRetry: () => ref.invalidate(trashProvider),
        data: (List<TrashedItem> list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.delete_outline,
              title: 'Nothing deleted',
              message:
                  'Deleted records appear here for 30 days so you can restore '
                  'them if you change your mind.',
            );
          }

          return ListView.separated(
            padding: Insets.pageTop,
            itemCount: list.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
            itemBuilder: (BuildContext context, int i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: Insets.sm),
                  child: Text(
                    'Records are permanently removed 30 days after deletion.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                );
              }

              final TrashedItem item = list[i - 1];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      _icon(item.collection),
                      size: 19,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.typeLabel} · '
                    '${item.deletedAt == null ? 'Deleted' : Formatters.date(item.deletedAt!)} · '
                    '${item.daysRemaining} ${item.daysRemaining == 1 ? 'day' : 'days'} left',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.restore),
                        tooltip: 'Restore',
                        onPressed: () => _restore(item),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_forever_outlined,
                            color: AppColors.of(context).danger),
                        tooltip: 'Delete permanently',
                        onPressed: () => _purge(item),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _icon(String collection) => switch (collection) {
        'customers' => Icons.person_outline,
        'jobs' => Icons.construction_outlined,
        'quotes' => Icons.description_outlined,
        'invoices' => Icons.receipt_long_outlined,
        'payments' => Icons.payments_outlined,
        'expenses' => Icons.account_balance_wallet_outlined,
        'documents' => Icons.folder_outlined,
        'photos' => Icons.photo_outlined,
        _ => Icons.insert_drive_file_outlined,
      };

  Future<void> _restore(TrashedItem item) async {
    try {
      await ref.read(trashRepositoryProvider)?.restore(item);
      if (mounted) showSnack(context, '${item.typeLabel} restored.');
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Could not restore that record.', error: true);
      }
    }
  }

  Future<void> _purge(TrashedItem item) async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Delete permanently?',
      message: '"${item.label}" cannot be recovered after this.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(trashRepositoryProvider)?.purge(item.id);
  }

  Future<void> _emptyBin() async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Empty recently deleted?',
      message: 'Everything in here will be permanently removed.',
      confirmLabel: 'Empty',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(trashRepositoryProvider)?.purgeAll();
  }
}
