import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/job.dart';
import '../../models/payment_stage.dart';
import '../../models/trade_enums.dart';
import '../../providers/data_providers.dart';
import '../../providers/trade_providers.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/ui_helpers.dart';

/// Deposits and staged payments for a job.
///
/// Builders rarely bill everything at the end — a deposit covers materials,
/// then the rest is staged. Tracking it here is the difference between knowing
/// your cash position and guessing it.
class PaymentStagesScreen extends ConsumerWidget {
  const PaymentStagesScreen({required this.jobId, super.key});
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String symbol = ref.watch(currencySymbolProvider);
    final Job? job = ref.watch(jobProvider(jobId)).valueOrNull;
    final JobBilling billing = ref.watch(jobBillingProvider(jobId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment schedule'),
        actions: <Widget>[
          if (billing.hasSchedule)
            PopupMenuButton<String>(
              onSelected: (String v) async {
                if (v == 'clear') {
                  final bool ok = await showConfirmDialog(
                    context,
                    title: 'Clear the schedule?',
                    message: 'Stages already invoiced are kept.',
                    confirmLabel: 'Clear',
                    destructive: true,
                  );
                  if (!ok) return;
                  await ref
                      .read(paymentStageRepositoryProvider)
                      ?.replaceSchedule(jobId, const <PaymentStage>[]);
                }
              },
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                    value: 'clear', child: Text('Clear schedule')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.gutter, Insets.sm, Insets.gutter, Insets.scrollBottom),
        children: <Widget>[
          _ValueCard(billing: billing, symbol: symbol, job: job),
          const SizedBox(height: Insets.lg),

          if (!billing.hasSchedule) ...<Widget>[
            const SectionHeader('Choose a schedule'),
            Text(
              'These are the ways building work is usually billed. Pick one to '
              'set it up in a tap — you can edit the stages afterwards.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Insets.md),
            for (final StagePreset p in StagePreset.values)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: _PresetCard(
                  preset: p,
                  jobValue: billing.jobValue,
                  symbol: symbol,
                  onTap: () => _applyPreset(context, ref, p, job),
                ),
              ),
          ] else ...<Widget>[
            const SectionHeader('Stages'),
            for (final PaymentStage s in billing.stages)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: _StageCard(
                  stage: s,
                  jobValue: billing.jobValue,
                  symbol: symbol,
                  onInvoice: s.isBilled
                      ? null
                      : () => _invoiceStage(context, ref, s, billing, job),
                  onOpenInvoice: s.invoiceId == null
                      ? null
                      : () => context.push(Routes.invoiceDetail(s.invoiceId!)),
                ),
              ),
            if (!billing.stages.percentagesBalance) ...<Widget>[
              const SizedBox(height: Insets.sm),
              _Warning(
                message: 'Your stages add up to '
                    '${billing.stages.percentageTotal.toStringAsFixed(0)}%, '
                    'not 100%. The job would be '
                    '${billing.stages.percentageTotal > 100 ? 'over' : 'under'}-billed.',
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _applyPreset(
    BuildContext context,
    WidgetRef ref,
    StagePreset preset,
    Job? job,
  ) async {
    final List<PaymentStage> stages = <PaymentStage>[
      for (int i = 0; i < preset.stages.length; i++)
        PaymentStage(
          id: '',
          ownerId: '',
          jobId: jobId,
          jobTitle: job?.title ?? '',
          customerId: job?.customerId ?? '',
          customerName: job?.customerName ?? '',
          label: preset.stages[i].label,
          percent: preset.stages[i].percent,
          order: i,
          // The deposit is due immediately; later stages are dated when they
          // are actually reached rather than guessed at now.
          status: i == 0 ? StageStatus.due : StageStatus.pending,
        ),
    ];

    await ref
        .read(paymentStageRepositoryProvider)
        ?.replaceSchedule(jobId, stages);
    if (context.mounted) showSnack(context, '${preset.label} schedule set up.');
  }

  /// Raises an invoice for one stage, pre-filled with its amount.
  Future<void> _invoiceStage(
    BuildContext context,
    WidgetRef ref,
    PaymentStage stage,
    JobBilling billing,
    Job? job,
  ) async {
    final double amount = stage.amountFor(billing.jobValue);
    if (amount <= 0.005) {
      showSnack(
        context,
        'This job has no value yet — quote or price it first.',
        error: true,
      );
      return;
    }

    // Hand the stage through to the invoice form so it arrives pre-filled and
    // the stage gets linked on save.
    context.push(
      '${Routes.invoiceNew}?jobId=$jobId'
      '${job == null ? '' : '&customerId=${job.customerId}'}'
      '&stageId=${stage.id}',
    );
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({
    required this.billing,
    required this.symbol,
    required this.job,
  });

  final JobBilling billing;
  final String symbol;
  final Job? job;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);

    return Card(
      child: Padding(
        padding: Insets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (job != null)
              Text(
                job!.title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: Insets.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Job value',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        Formatters.money(billing.jobValue, symbol: symbol),
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      'Still to bill',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      Formatters.money(billing.remaining, symbol: symbol),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: billing.remaining > 0.005 ? c.warning : c.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (billing.jobValue > 0.005) ...<Widget>[
              const SizedBox(height: Insets.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.xs),
                child: LinearProgressIndicator(
                  value: billing.progress,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: Insets.sm),
              Text(
                '${Formatters.money(billing.invoicedTotal, symbol: symbol)} '
                'invoiced so far',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: Insets.sm),
                child: Text(
                  'Quote this job to set its value — stages are worked out as a '
                  'share of it.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.jobValue,
    required this.symbol,
    required this.onTap,
  });

  final StagePreset preset;
  final double jobValue;
  final String symbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: Radii.card,
        onTap: onTap,
        child: Padding(
          padding: Insets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      preset.label,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              Text(
                preset.description,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: preset.stages.map((({String label, double percent}) s) {
                  return Expanded(
                    flex: s.percent.round(),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: Insets.xs),
                          Text(
                            jobValue > 0.005
                                ? Formatters.money(
                                    jobValue * s.percent / 100,
                                    symbol: symbol,
                                  )
                                : '${s.percent.toStringAsFixed(0)}%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.stage,
    required this.jobValue,
    required this.symbol,
    required this.onInvoice,
    required this.onOpenInvoice,
  });

  final PaymentStage stage;
  final double jobValue;
  final String symbol;
  final VoidCallback? onInvoice;
  final VoidCallback? onOpenInvoice;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);
    final double amount = stage.amountFor(jobValue);

    return Card(
      child: Padding(
        padding: Insets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    stage.label,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip(
                  label: stage.status.label,
                  color: c.resolve(stage.status.color),
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  Formatters.money(amount, symbol: symbol),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: Insets.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    stage.shareLabel(symbol),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            if (stage.isBilled)
              OutlinedButton.icon(
                onPressed: onOpenInvoice,
                icon: const Icon(Icons.receipt_long_outlined, size: 17),
                label: const Text('View invoice'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 42),
                ),
              )
            else
              FilledButton.tonalIcon(
                onPressed: onInvoice,
                icon: const Icon(Icons.receipt_long, size: 17),
                label: const Text('Invoice this stage'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 42),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors c = AppColors.of(context);
    return Container(
      padding: Insets.cardTight,
      decoration: BoxDecoration(
        color: c.container(c.warning),
        borderRadius: Radii.card,
        border: Border.all(color: c.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, size: 19, color: c.warning),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(message,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
