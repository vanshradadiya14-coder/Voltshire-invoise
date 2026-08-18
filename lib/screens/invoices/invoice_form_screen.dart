import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/flow/save_outcome.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/settlement.dart';
import '../../models/company_profile.dart';
import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../models/job.dart';
import '../../models/line_item.dart';
import '../../models/payment_stage.dart';
import '../../models/subscription.dart';
import '../../models/trade_enums.dart';
import '../../models/variation.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/trade_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/entity_pickers.dart';
import '../../widgets/line_items_editor.dart';
import '../../widgets/next_step_sheet.dart';
import '../../widgets/settlement_summary.dart';
import '../../widgets/ui_helpers.dart';
import '../../widgets/upgrade_prompt.dart';

/// Create or edit an invoice. Can be seeded from a customer, a job, or a quote.
class InvoiceFormScreen extends ConsumerStatefulWidget {
  const InvoiceFormScreen({
    this.invoiceId,
    this.customerId,
    this.jobId,
    this.fromQuoteId,
    this.stageId,
    super.key,
  });

  final String? invoiceId;
  final String? customerId;
  final String? jobId;
  final String? fromQuoteId;

  /// Set when billing a scheduled payment stage. The form arrives pre-filled
  /// with that stage's amount and links back to it on save.
  final String? stageId;

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _workDescription = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  String? _customerId;
  String _customerName = '';
  String _customerAddress = '';
  String? _jobId;
  String _jobTitle = '';
  List<LineItem> _items = <LineItem>[];
  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate;
  bool _isDraft = false;

  /// Tax treatment, copied from the customer when one is chosen. Held on the
  /// invoice so a historic document keeps the treatment it was issued under
  /// even if the customer's settings change later.
  CisStatus _cis = CisStatus.notApplicable;
  bool _reverseCharge = false;

  /// Approved variations already pulled onto this invoice, so they can be
  /// marked as billed on save.
  final Set<String> _pulledVariationIds = <String>{};

  /// Label of the payment stage this invoice bills, when raised from a
  /// schedule.
  String _stageLabel = '';

  bool _seeded = false;
  bool _saving = false;
  bool get _isEdit => widget.invoiceId != null;

  @override
  void initState() {
    super.initState();
    _customerId = widget.customerId;
    _jobId = widget.jobId;
    _dueDate = DateTime.now().add(const Duration(days: AppConstants.defaultInvoiceDueDays));
  }

  @override
  void dispose() {
    _workDescription.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _hydrateFromInvoice(Invoice inv) {
    _customerId = inv.customerId;
    _customerName = inv.customerName;
    _customerAddress = inv.customerAddress;
    _jobId = inv.jobId;
    _jobTitle = inv.jobTitle;
    _workDescription.text = inv.workDescription;
    _notes.text = inv.notes;
    _items = inv.items;
    _issueDate = inv.issueDate ?? DateTime.now();
    _dueDate = inv.dueDate;
    _isDraft = inv.isDraft;
    _cis = inv.cisStatus;
    _reverseCharge = inv.reverseCharge;
  }

  /// Applies a customer's saved tax treatment and payment terms.
  ///
  /// This is the payoff for configuring the customer once: the builder never
  /// has to remember that Barratt are CIS 20% and reverse charge.
  void _applyCustomer(Customer c) {
    _customerId = c.id;
    _customerName = c.name;
    _customerAddress = c.invoiceAddress;
    _cis = c.cisStatus;
    _reverseCharge = c.reverseCharge;
    if (c.paymentTermsDays != null) {
      _dueDate = _issueDate.add(Duration(days: c.paymentTermsDays!));
    }
  }

  Future<void> _pickCustomer() async {
    final Customer? c = await showCustomerPicker(context, ref);
    if (c != null) {
      setState(() {
        _applyCustomer(c);
        // Clear job if it belonged to another customer.
        _jobId = null;
        _jobTitle = '';
        _pulledVariationIds.clear();
      });
    }
  }

  /// Pulls approved-but-unbilled variations for the selected job onto the
  /// invoice.
  ///
  /// This is the feature that stops builders losing money: extra work agreed
  /// on site gets billed by default instead of being remembered.
  Future<void> _pullVariations(List<Variation> unbilled) async {
    setState(() {
      for (final Variation v in unbilled) {
        if (_pulledVariationIds.add(v.id)) {
          _items = <LineItem>[..._items, v.toLineItem()];
        }
      }
    });
    if (mounted) {
      showSnack(
        context,
        'Added ${unbilled.length} ${unbilled.length == 1 ? 'variation' : 'variations'} to this invoice.',
      );
    }
  }

  Future<void> _pickJob() async {
    if (_customerId == null) {
      showSnack(context, 'Select a customer first.', error: true);
      return;
    }
    final Job? j = await showJobPicker(context, ref, customerId: _customerId);
    if (j != null) {
      setState(() {
        _jobId = j.id;
        _jobTitle = j.title;
        if (_workDescription.text.trim().isEmpty && j.description.isNotEmpty) {
          _workDescription.text = j.description;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      showSnack(context, 'Please select a customer.', error: true);
      return;
    }
    if (_items.isEmpty) {
      showSnack(context, 'Add at least one line item.', error: true);
      return;
    }
    if (!_isEdit &&
        !await ensureCanCreate(context, ref, LimitedResource.documents)) {
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(invoiceRepositoryProvider);
      late final SaveOutcome outcome;
      final Invoice base = Invoice(
        id: widget.invoiceId ?? '',
        ownerId: '',
        number: 0,
        numberFormatted: '',
        customerId: _customerId!,
        customerName: _customerName,
        customerAddress: _customerAddress,
        jobId: _jobId,
        jobTitle: _jobTitle,
        workDescription: _workDescription.text.trim(),
        items: _items,
        issueDate: _issueDate,
        dueDate: _dueDate,
        notes: _notes.text.trim(),
        isDraft: _isDraft,
        cisStatus: _cis,
        reverseCharge: _reverseCharge,
        stageId: widget.stageId,
        stageLabel: _stageLabel,
      );

      if (_isEdit) {
        final Invoice? existing =
            ref.read(invoiceProvider(widget.invoiceId!)).valueOrNull;
        if (existing == null) throw StateError('Invoice not found');
        await repo.update(existing.copyWith(
          customerId: _customerId,
          customerName: _customerName,
          customerAddress: _customerAddress,
          jobId: _jobId,
          jobTitle: _jobTitle,
          workDescription: _workDescription.text.trim(),
          items: _items,
          issueDate: _issueDate,
          dueDate: _dueDate,
          notes: _notes.text.trim(),
          isDraft: _isDraft,
          cisStatus: _cis,
          reverseCharge: _reverseCharge,
          updatedAt: DateTime.now(),
        ));
        outcome = SaveOutcome(
          kind: EntityKind.invoice,
          id: widget.invoiceId!,
          label: existing.numberFormatted,
          wasEdit: true,
        );
      } else {
        final String id = await repo.create(base);

        // Mark any variations billed on this invoice, so they stop showing as
        // outstanding extras on the job.
        if (_pulledVariationIds.isNotEmpty) {
          await ref
              .read(variationRepositoryProvider)
              ?.markInvoiced(_pulledVariationIds.toList(), id);
        }

        // Link the payment stage, so the schedule shows it as billed and the
        // job's remaining balance drops.
        if (widget.stageId != null) {
          await ref
              .read(paymentStageRepositoryProvider)
              ?.markInvoiced(widget.stageId!, id);
        }

        Telemetry.documentCreated('invoice', lineItems: _items.length);
        outcome = SaveOutcome(
          kind: EntityKind.invoice,
          id: id,
          label: 'Invoice for $_customerName',
          customerId: _customerId,
          customerName: _customerName,
          jobId: _jobId,
          jobTitle: _jobTitle,
        );
      }
      if (!mounted) return;
      showSnack(context, outcome.confirmation);
      await completeSave(context, outcome);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CompanyProfile? profile = ref.watch(companyProfileProvider).valueOrNull;
    final String symbol = profile?.currencySymbol ?? '£';
    final double defaultVat = profile?.defaultVatRate ?? AppConstants.defaultVatRate;

    // One-time seeding of the form.
    if (!_seeded) {
      if (_isEdit) {
        final Invoice? inv = ref.watch(invoiceProvider(widget.invoiceId!)).valueOrNull;
        if (inv != null) {
          _hydrateFromInvoice(inv);
          _seeded = true;
        }
      } else {
        // Seed from a quote if requested.
        if (widget.fromQuoteId != null) {
          final quote = ref.watch(quoteProvider(widget.fromQuoteId!)).valueOrNull;
          if (quote != null) {
            _customerId = quote.customerId;
            _customerName = quote.customerName;
            _customerAddress = quote.customerAddress;
            _jobId = quote.jobId;
            _jobTitle = quote.jobTitle;
            _workDescription.text = quote.workDescription;
            _items = quote.items;
            _seeded = true;
          }
        }
        // Seed customer name/address/tax treatment from a preselected customer.
        if (_customerId != null && _customerName.isEmpty) {
          final Customer? c = ref.watch(customerProvider(_customerId!)).valueOrNull;
          if (c != null) _applyCustomer(c);
        }

        // Billing a scheduled stage: pre-fill a single line for its share of
        // the job value, so the deposit invoice is one tap from the schedule.
        if (widget.stageId != null && _items.isEmpty && _jobId != null) {
          final JobBilling billing = ref.watch(jobBillingProvider(_jobId!));
          PaymentStage? stage;
          for (final PaymentStage s in billing.stages) {
            if (s.id == widget.stageId) stage = s;
          }
          if (stage != null) {
            final double amount = stage.amountFor(billing.jobValue);
            if (amount > 0.005) {
              _stageLabel = stage.label;
              _items = <LineItem>[
                LineItem(
                  description: '${stage.label} — ${_jobTitle.isEmpty ? 'work' : _jobTitle}',
                  quantity: 1,
                  unitPrice: amount,
                  vatPercent: _reverseCharge ? 0 : defaultVat,
                  category: LineCategory.other,
                ),
              ];
            }
          }
        }
        // Seed job title from preselected job.
        if (_jobId != null && _jobTitle.isEmpty) {
          final Job? j = ref.watch(jobProvider(_jobId!)).valueOrNull;
          if (j != null) _jobTitle = j.title;
        }
        if (widget.fromQuoteId == null) _seeded = true;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit invoice' : 'New invoice')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            _PickerField(
              label: 'Customer *',
              value: _customerName,
              icon: Icons.person_outline,
              onTap: _pickCustomer,
            ),
            const SizedBox(height: 14),
            _PickerField(
              label: 'Job (optional)',
              value: _jobTitle,
              icon: Icons.construction_outlined,
              onTap: _pickJob,
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: DateField(
                    label: 'Issue date',
                    value: _issueDate,
                    onChanged: (DateTime? d) =>
                        setState(() => _issueDate = d ?? _issueDate),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DateField(
                    label: 'Due date',
                    value: _dueDate,
                    clearable: true,
                    onChanged: (DateTime? d) => setState(() => _dueDate = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _workDescription,
              label: 'Work description',
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              hint: 'Summary of the work carried out',
            ),
            // Unbilled extras on the selected job. Surfaced right above the
            // items so it is impossible to raise the invoice without seeing
            // that there is agreed work still to bill.
            if (_jobId != null) _UnbilledVariations(
              jobId: _jobId!,
              symbol: symbol,
              alreadyPulled: _pulledVariationIds,
              onPull: _pullVariations,
            ),
            const SizedBox(height: 18),
            const SectionHeader('Items'),
            LineItemsEditor(
              items: _items,
              currencySymbol: symbol,
              defaultVat: _reverseCharge ? 0 : defaultVat,
              showCategories: _cis.deducts,
              onChanged: (List<LineItem> v) => setState(() => _items = v),
            ),
            if (_items.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              SettlementSummary(
                settlement: Settlement.of(
                  _items,
                  cis: _cis,
                  reverseCharge: _reverseCharge,
                ),
                symbol: symbol,
              ),
            ],
            const SizedBox(height: 14),
            AppTextField(controller: _notes, label: 'Notes', maxLines: 2),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Save as draft'),
              subtitle: const Text('Drafts are excluded from outstanding totals'),
              value: _isDraft,
              onChanged: (bool v) => setState(() => _isDraft = v),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.save_outlined),
              label: Text(_isEdit ? 'Save changes' : 'Create invoice'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prompts to add approved-but-unbilled variations for the selected job.
class _UnbilledVariations extends ConsumerWidget {
  const _UnbilledVariations({
    required this.jobId,
    required this.symbol,
    required this.alreadyPulled,
    required this.onPull,
  });

  final String jobId;
  final String symbol;
  final Set<String> alreadyPulled;
  final Future<void> Function(List<Variation>) onPull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Variation> unbilled =
        (ref.watch(variationsForJobProvider(jobId)).valueOrNull ??
                const <Variation>[])
            .unbilled
            .where((Variation v) => !alreadyPulled.contains(v.id))
            .toList();

    if (unbilled.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);
    final double total =
        unbilled.fold<double>(0, (double s, Variation v) => s + v.netTotal);

    return Padding(
      padding: const EdgeInsets.only(top: Insets.lg),
      child: Container(
        padding: Insets.cardTight,
        decoration: BoxDecoration(
          color: c.container(c.warning),
          borderRadius: Radii.card,
          border: Border.all(color: c.warning.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.add_task_outlined, color: c.warning, size: 22),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${unbilled.length} approved ${unbilled.length == 1 ? 'extra' : 'extras'} not yet billed',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${Formatters.money(total, symbol: symbol)} of agreed variation work',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            FilledButton.tonal(
              onPressed: () => onPull(unbilled),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable field that opens a picker (customer/job).
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: Icon(icon),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              value.isEmpty ? 'Select' : value,
              style: value.isEmpty
                  ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
