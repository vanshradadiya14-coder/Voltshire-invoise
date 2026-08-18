import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/calculations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/job.dart';
import '../../models/trade_enums.dart';
import '../../models/variation.dart';
import '../../providers/data_providers.dart';
import '../../providers/trade_providers.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/ui_helpers.dart';

/// Extra work agreed after a job started.
///
/// "While you're here, could you also…" is how builders lose money — the work
/// gets done and never gets billed. Recording it here means it flows onto the
/// invoice by default instead of being remembered.
class VariationsScreen extends ConsumerWidget {
  const VariationsScreen({required this.jobId, super.key});
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);
    final String symbol = ref.watch(currencySymbolProvider);
    final Job? job = ref.watch(jobProvider(jobId)).valueOrNull;
    final List<Variation> all =
        ref.watch(variationsForJobProvider(jobId)).valueOrNull ??
            const <Variation>[];

    final double unbilled = all.unbilledNet;
    final double proposed = all.proposedNet;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Variations'),
        bottom: job == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: Insets.gutter, bottom: Insets.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      job.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, job: job),
        icon: const Icon(Icons.add),
        label: const Text('Add extra'),
      ),
      body: all.isEmpty
          ? const EmptyState(
              icon: Icons.add_task_outlined,
              title: 'No extras recorded',
              message:
                  'When a customer asks for something outside the original '
                  'price, add it here. Approved extras get added to the '
                  'invoice automatically, so nothing goes unbilled.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  Insets.gutter, Insets.sm, Insets.gutter, Insets.scrollBottom),
              children: <Widget>[
                if (unbilled > 0.005 || proposed > 0.005)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.lg),
                    child: Row(
                      children: <Widget>[
                        if (unbilled > 0.005)
                          Expanded(
                            child: _Tally(
                              label: 'Approved, unbilled',
                              value:
                                  Formatters.money(unbilled, symbol: symbol),
                              tone: c.info,
                            ),
                          ),
                        if (unbilled > 0.005 && proposed > 0.005)
                          const SizedBox(width: Insets.md),
                        if (proposed > 0.005)
                          Expanded(
                            child: _Tally(
                              label: 'Awaiting approval',
                              value:
                                  Formatters.money(proposed, symbol: symbol),
                              tone: c.warning,
                            ),
                          ),
                      ],
                    ),
                  ),
                for (final Variation v in all)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: _VariationCard(
                      variation: v,
                      symbol: symbol,
                      onEdit: () => _edit(context, ref, job: job, existing: v),
                      onStatus: (VariationStatus s) => ref
                          .read(variationRepositoryProvider)
                          ?.setStatus(v.id, s),
                      onDelete: () => _delete(context, ref, v),
                    ),
                  ),
                if (unbilled > 0.005) ...<Widget>[
                  const SizedBox(height: Insets.md),
                  FilledButton.icon(
                    onPressed: () => context.push(
                      '${Routes.invoiceNew}?jobId=$jobId'
                      '${job == null ? '' : '&customerId=${job.customerId}'}',
                    ),
                    icon: const Icon(Icons.receipt_long),
                    label: Text(
                      'Invoice this job with '
                      '${Formatters.money(unbilled, symbol: symbol)} of extras',
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    Job? job,
    Variation? existing,
  }) async {
    final Variation? result = await showModalBottomSheet<Variation>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => _VariationEditor(
        existing: existing,
        jobId: jobId,
        jobTitle: job?.title ?? '',
        customerId: job?.customerId ?? '',
      ),
    );
    if (result == null) return;

    final repo = ref.read(variationRepositoryProvider);
    if (existing == null) {
      await repo?.create(result);
      if (context.mounted) showSnack(context, 'Extra recorded.');
    } else {
      await repo?.update(result);
      if (context.mounted) showSnack(context, 'Extra updated.');
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Variation v) async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Delete this extra?',
      message: '"${v.description}" will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(variationRepositoryProvider)?.delete(v.id);
  }
}

class _Tally extends StatelessWidget {
  const _Tally({required this.label, required this.value, required this.tone});
  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: Insets.cardTight,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: Radii.card,
        border: Border.all(color: tone.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800, color: tone),
          ),
        ],
      ),
    );
  }
}

class _VariationCard extends StatelessWidget {
  const _VariationCard({
    required this.variation,
    required this.symbol,
    required this.onEdit,
    required this.onStatus,
    required this.onDelete,
  });

  final Variation variation;
  final String symbol;
  final VoidCallback onEdit;
  final ValueChanged<VariationStatus> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);
    final Variation v = variation;

    return Card(
      child: Padding(
        padding: Insets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    v.description,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                StatusChip(
                  label: v.status.label,
                  color: c.resolve(v.status.color),
                  dense: true,
                ),
              ],
            ),
            if (v.requestedBy.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Requested by ${v.requestedBy}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: Insets.sm),
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: v.category.color.withValues(alpha: 0.16),
                    borderRadius: Radii.chip,
                  ),
                  child: Text(
                    v.category.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: v.category.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 9.5,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  Formatters.money(v.netTotal, symbol: symbol),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (v.status != VariationStatus.invoiced) ...<Widget>[
              const Divider(height: Insets.xl),
              Row(
                children: <Widget>[
                  if (v.status == VariationStatus.proposed) ...<Widget>[
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => onStatus(VariationStatus.approved),
                        icon: const Icon(Icons.check, size: 17),
                        label: const Text('Approved'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onStatus(VariationStatus.rejected),
                        icon: const Icon(Icons.close, size: 17),
                        label: const Text('Declined'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        v.isUnbilled
                            ? 'Will be added to the next invoice for this job'
                            : v.status.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (String v2) =>
                        v2 == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                      PopupMenuItem<String>(
                          value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VariationEditor extends StatefulWidget {
  const _VariationEditor({
    this.existing,
    required this.jobId,
    required this.jobTitle,
    required this.customerId,
  });

  final Variation? existing;
  final String jobId;
  final String jobTitle;
  final String customerId;

  @override
  State<_VariationEditor> createState() => _VariationEditorState();
}

class _VariationEditorState extends State<_VariationEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _quantity;
  late final TextEditingController _requestedBy;
  late LineCategory _category;
  late VariationStatus _status;

  @override
  void initState() {
    super.initState();
    final Variation? v = widget.existing;
    _description = TextEditingController(text: v?.description ?? '');
    _amount = TextEditingController(
        text: v == null ? '' : v.amount.toStringAsFixed(2));
    _quantity = TextEditingController(
        text: (v?.quantity ?? 1).toString().replaceAll(RegExp(r'\.0$'), ''));
    _requestedBy = TextEditingController(text: v?.requestedBy ?? '');
    _category = v?.category ?? LineCategory.labour;
    _status = v?.status ?? VariationStatus.proposed;
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _quantity.dispose();
    _requestedBy.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final Variation base = widget.existing ??
        Variation(
          id: '',
          ownerId: '',
          jobId: widget.jobId,
          jobTitle: widget.jobTitle,
          customerId: widget.customerId,
          description: '',
        );
    Navigator.of(context).pop(base.copyWith(
      description: _description.text.trim(),
      amount: parseNum(_amount.text),
      quantity: parseNum(_quantity.text),
      category: _category,
      status: _status,
      requestedBy: _requestedBy.text.trim(),
      approvedAt: _status == VariationStatus.approved ? DateTime.now() : null,
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: Insets.xl,
        right: Insets.xl,
        top: Insets.xs,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.existing == null ? 'Extra work' : 'Edit extra',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                'Anything outside the original price.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: Insets.lg),
              AppTextField(
                controller: _description,
                label: 'What was asked for *',
                hint: 'e.g. Move socket to other wall',
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                validator: (String? v) =>
                    Validators.required(v, field: 'Description'),
              ),
              const SizedBox(height: Insets.md),
              AppTextField(
                controller: _requestedBy,
                label: 'Who asked',
                hint: 'Useful if the bill is queried later',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      controller: _quantity,
                      label: 'Quantity',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimalFormatters,
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: AppTextField(
                      controller: _amount,
                      label: 'Price *',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimalFormatters,
                      validator: (String? v) =>
                          Validators.number(v, field: 'Price'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Text('Category',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: LineCategory.values
                    .map((LineCategory c) => ChoiceChip(
                          label: Text(c.label),
                          selected: _category == c,
                          selectedColor: c.color.withValues(alpha: 0.18),
                          onSelected: (_) => setState(() => _category = c),
                        ))
                    .toList(),
              ),
              const SizedBox(height: Insets.lg),
              SegmentedButton<VariationStatus>(
                segments: const <ButtonSegment<VariationStatus>>[
                  ButtonSegment<VariationStatus>(
                    value: VariationStatus.proposed,
                    label: Text('Proposed'),
                  ),
                  ButtonSegment<VariationStatus>(
                    value: VariationStatus.approved,
                    label: Text('Agreed'),
                  ),
                ],
                selected: <VariationStatus>{
                  _status == VariationStatus.approved
                      ? VariationStatus.approved
                      : VariationStatus.proposed
                },
                onSelectionChanged: (Set<VariationStatus> s) =>
                    setState(() => _status = s.first),
              ),
              const SizedBox(height: Insets.xl),
              FilledButton(
                onPressed: _save,
                child: Text(
                    widget.existing == null ? 'Record extra' : 'Save changes'),
              ),
              const SizedBox(height: Insets.xl),
            ],
          ),
        ),
      ),
    );
  }
}
