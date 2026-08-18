import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/telemetry/telemetry.dart';
import '../core/utils/formatters.dart';
import '../core/utils/reminder_templates.dart';
import '../models/company_profile.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/trade_enums.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../providers/repository_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'ui_helpers.dart';

/// Chase an unpaid invoice.
///
/// Three escalating drafts, sent through whichever channel the customer
/// actually answers on. The message is fully editable before it goes — a
/// builder knows their customer better than a template does.
Future<void> showChasePaymentSheet(
  BuildContext context,
  Invoice invoice,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => _ChaseSheet(invoice: invoice),
  );
}

class _ChaseSheet extends ConsumerStatefulWidget {
  const _ChaseSheet({required this.invoice});
  final Invoice invoice;

  @override
  ConsumerState<_ChaseSheet> createState() => _ChaseSheetState();
}

class _ChaseSheetState extends ConsumerState<_ChaseSheet> {
  late ReminderStage _stage;
  final TextEditingController _message = TextEditingController();
  bool _sending = false;
  bool _edited = false;

  Customer? get _customer =>
      ref.read(customerProvider(widget.invoice.customerId)).valueOrNull;

  CompanyProfile? get _company =>
      ref.read(companyProfileProvider).valueOrNull;

  @override
  void initState() {
    super.initState();
    // Start at the level the lateness justifies rather than always at the
    // gentlest — nobody wants to send three messages to get to the right tone.
    _stage = widget.invoice.suggestedReminder;
    WidgetsBinding.instance.addPostFrameCallback((_) => _regenerate());
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _regenerate() {
    final List<ReminderStage> allowed =
        ReminderTemplates.availableFor(_customer);
    if (!allowed.contains(_stage)) _stage = allowed.last;

    _message.text = ReminderTemplates.build(
      stage: _stage,
      invoice: widget.invoice,
      customer: _customer,
      company: _company,
    );
    _edited = false;
    if (mounted) setState(() {});
  }

  Future<void> _send(_Channel channel) async {
    setState(() => _sending = true);
    try {
      final share = ref.read(shareServiceProvider);
      final Customer? c = _customer;
      final String body = _message.text;

      switch (channel) {
        case _Channel.email:
          await share.composeEmail(
            to: c?.email ?? '',
            subject: ReminderTemplates.subject(
              stage: _stage,
              invoice: widget.invoice,
            ),
            body: body,
          );
        case _Channel.sms:
          await share.composeSms(phone: c?.phone ?? '', message: body);
        case _Channel.whatsapp:
          await share.openWhatsAppChat(
            phone: c?.phone ?? '',
            message: body,
          );
        case _Channel.copy:
          await Clipboard.setData(ClipboardData(text: body));
      }

      // Record the chase so the history is defensible if this ever ends up in
      // a county court claim.
      await ref.read(invoiceRepositoryProvider).recordReminder(
            widget.invoice.id,
            _stage,
          );
      Telemetry.logEvent(AppEvent.paymentReminderSent, <String, Object>{
        'stage': _stage.name,
        'channel': channel.name,
        'days_overdue': widget.invoice.daysOverdue,
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(
        context,
        channel == _Channel.copy
            ? 'Message copied.'
            : 'Reminder logged against ${widget.invoice.numberFormatted}.',
      );
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Could not open that app.', error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);
    final String symbol = ref.watch(currencySymbolProvider);
    final Customer? customer = ref.watch(
      customerProvider(widget.invoice.customerId),
    ).valueOrNull;
    final List<ReminderStage> stages =
        ReminderTemplates.availableFor(customer);
    final Invoice inv = widget.invoice;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (BuildContext context, ScrollController controller) {
          return Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(
                      Insets.xl, 0, Insets.xl, Insets.lg),
                  children: <Widget>[
                    Text(
                      'Chase payment',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      '${inv.numberFormatted} · '
                      '${Formatters.money(inv.balanceDue, symbol: symbol)} '
                      'outstanding · ${inv.daysOverdue} '
                      '${inv.daysOverdue == 1 ? 'day' : 'days'} overdue',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),

                    if (inv.remindersSent > 0) ...<Widget>[
                      const SizedBox(height: Insets.md),
                      Container(
                        padding: Insets.cardTight,
                        decoration: BoxDecoration(
                          color: c.container(c.info),
                          borderRadius: Radii.field,
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.history, size: 17, color: c.info),
                            const SizedBox(width: Insets.sm),
                            Expanded(
                              child: Text(
                                '${inv.remindersSent} '
                                '${inv.remindersSent == 1 ? 'reminder' : 'reminders'} '
                                'already sent'
                                '${inv.lastReminderAt == null ? '' : ', last on ${Formatters.date(inv.lastReminderAt!)}'}.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: Insets.lg),
                    Text(
                      'Tone',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: Insets.sm),
                    for (final ReminderStage s in stages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.sm),
                        child: _StageOption(
                          stage: s,
                          selected: s == _stage,
                          onTap: () {
                            _stage = s;
                            _regenerate();
                          },
                        ),
                      ),

                    // Explains why the hardest option is missing, rather than
                    // silently hiding it.
                    if (stages.length < ReminderStage.values.length) ...<Widget>[
                      const SizedBox(height: Insets.xs),
                      Text(
                        'Statutory late-payment interest only applies between '
                        'businesses, so the final notice is not offered for a '
                        'private customer.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],

                    const SizedBox(height: Insets.lg),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Message',
                            style: theme.textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (_edited)
                          TextButton.icon(
                            onPressed: _regenerate,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Reset'),
                          ),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    TextField(
                      controller: _message,
                      maxLines: null,
                      minLines: 8,
                      onChanged: (_) {
                        if (!_edited) setState(() => _edited = true);
                      },
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      decoration: const InputDecoration(
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              _SendBar(
                customer: customer,
                busy: _sending,
                onSend: _send,
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _Channel { email, sms, whatsapp, copy }

class _StageOption extends StatelessWidget {
  const _StageOption({
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  final ReminderStage stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);
    final Color tone = c.resolve(stage.color);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: Radii.card,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: Insets.cardTight,
          decoration: BoxDecoration(
            color: selected
                ? tone.withValues(alpha: 0.12)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: Radii.card,
            border: Border.all(
              color: selected ? tone : theme.colorScheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(stage.icon, size: 20, color: selected ? tone : null),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      stage.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    Text(
                      stage.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 19, color: tone),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendBar extends StatelessWidget {
  const _SendBar({
    required this.customer,
    required this.busy,
    required this.onSend,
  });

  final Customer? customer;
  final bool busy;
  final ValueChanged<_Channel> onSend;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasEmail = customer?.email.trim().isNotEmpty ?? false;
    final bool hasPhone = customer?.phone.trim().isNotEmpty ?? false;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
            Insets.xl, Insets.md, Insets.xl, Insets.md),
        child: busy
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(Insets.sm),
                  child: CircularProgressIndicator(),
                ),
              )
            : Row(
                children: <Widget>[
                  if (hasEmail)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onSend(_Channel.email),
                        icon: const Icon(Icons.mail_outline, size: 18),
                        label: const Text('Email'),
                      ),
                    ),
                  if (hasEmail && hasPhone) const SizedBox(width: Insets.sm),
                  if (hasPhone) ...<Widget>[
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => onSend(_Channel.sms),
                        icon: const Icon(Icons.sms_outlined, size: 18),
                        label: const Text('Text'),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    IconButton.filledTonal(
                      onPressed: () => onSend(_Channel.whatsapp),
                      icon: const Icon(Icons.chat_outlined),
                      tooltip: 'WhatsApp',
                    ),
                  ],
                  // Always available — covers a customer with no contact
                  // details, and anyone who'd rather paste it somewhere else.
                  if (!hasEmail && !hasPhone)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onSend(_Channel.copy),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy message'),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: () => onSend(_Channel.copy),
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copy',
                    ),
                ],
              ),
      ),
    );
  }
}
