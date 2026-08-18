import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/flow/save_outcome.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/utils/validators.dart';
import '../../models/customer.dart';
import '../../models/subscription.dart';
import '../../models/trade_enums.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/next_step_sheet.dart';
import '../../widgets/ui_helpers.dart';
import '../../widgets/upgrade_prompt.dart';

/// Create or edit a customer. When [customerId] is null this is a create form.
class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({this.customerId, super.key});
  final String? customerId;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _billing = TextEditingController();
  final TextEditingController _site = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _contact = TextEditingController();
  final TextEditingController _vatNumber = TextEditingController();
  final TextEditingController _companyNumber = TextEditingController();
  final TextEditingController _terms = TextEditingController();

  CustomerType _type = CustomerType.domestic;
  CisStatus _cis = CisStatus.notApplicable;
  bool _reverseCharge = false;

  bool _loaded = false;
  bool _saving = false;

  bool get _isEdit => widget.customerId != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _billing.dispose();
    _site.dispose();
    _notes.dispose();
    _contact.dispose();
    _vatNumber.dispose();
    _companyNumber.dispose();
    _terms.dispose();
    super.dispose();
  }

  void _hydrate(Customer c) {
    _name.text = c.name;
    _phone.text = c.phone;
    _email.text = c.email;
    _billing.text = c.billingAddress;
    _site.text = c.siteAddress;
    _notes.text = c.notes;
    _contact.text = c.contactName;
    _vatNumber.text = c.vatNumber;
    _companyNumber.text = c.companyNumber;
    _terms.text = c.paymentTermsDays?.toString() ?? '';
    _type = c.type;
    _cis = c.cisStatus;
    _reverseCharge = c.reverseCharge;
  }

  /// Saves the customer.
  ///
  /// When [thenInvoice] is true (the primary create action) the form hands the
  /// builder straight into a new invoice for this customer instead of stopping
  /// at the customer record — because nobody adds a customer for its own sake,
  /// they add one because they are about to bill them.
  Future<void> _save({bool thenInvoice = false}) async {
    if (!_formKey.currentState!.validate()) return;

    // Free-tier cap. Checked before any write so the user is never told a
    // record saved and then finds it did not.
    if (!_isEdit &&
        !await ensureCanCreate(context, ref, LimitedResource.customers)) {
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      final String name = _name.text.trim();
      final int? termDays = int.tryParse(_terms.text.trim());

      // Tax settings only apply to business customers. Storing them for a
      // homeowner would mean a later type change silently re-enabled CIS.
      final bool business = _type.isBusiness;

      late final SaveOutcome outcome;

      if (_isEdit) {
        final Customer? existing =
            ref.read(customerProvider(widget.customerId!)).valueOrNull;
        if (existing == null) throw StateError('Customer not found');
        await repo.update(existing.copyWith(
          name: name,
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          billingAddress: _billing.text.trim(),
          siteAddress: _site.text.trim(),
          notes: _notes.text.trim(),
          type: _type,
          cisStatus: business ? _cis : CisStatus.notApplicable,
          reverseCharge: business && _reverseCharge,
          vatNumber: business ? _vatNumber.text.trim() : '',
          companyNumber: business ? _companyNumber.text.trim() : '',
          contactName: _contact.text.trim(),
          paymentTermsDays: termDays,
          clearPaymentTerms: termDays == null,
          updatedAt: DateTime.now(),
        ));
        outcome = SaveOutcome(
          kind: EntityKind.customer,
          id: widget.customerId!,
          label: name,
          wasEdit: true,
        );
      } else {
        final String id = await repo.create(Customer(
          id: '',
          ownerId: '',
          name: name,
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          billingAddress: _billing.text.trim(),
          siteAddress: _site.text.trim(),
          notes: _notes.text.trim(),
          type: _type,
          cisStatus: business ? _cis : CisStatus.notApplicable,
          reverseCharge: business && _reverseCharge,
          vatNumber: business ? _vatNumber.text.trim() : '',
          companyNumber: business ? _companyNumber.text.trim() : '',
          contactName: _contact.text.trim(),
          paymentTermsDays: termDays,
        ));
        Telemetry.logEvent(AppEvent.customerCreated,
            <String, Object>{'type': _type.name});
        outcome = SaveOutcome(
          kind: EntityKind.customer,
          id: id,
          label: name,
          customerId: id,
          customerName: name,
        );
      }

      if (!mounted) return;
      showSnack(context, outcome.confirmation);

      // Primary path: go straight into a new invoice for this customer, with
      // their details and tax treatment already applied. `pushReplacement` so
      // the submitted form is not left underneath — backing out of the invoice
      // lands on the customer list, where the new customer is waiting.
      if (thenInvoice && !_isEdit) {
        context.pushReplacement('${Routes.invoiceNew}?customerId=${outcome.id}');
        return;
      }

      // Otherwise carry the builder to the customer record and offer what comes
      // next (invoice / quote / job) via the next-step sheet.
      await completeSave(context, outcome);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Load existing values once when editing.
    if (_isEdit && !_loaded) {
      final Customer? c = ref.watch(customerProvider(widget.customerId!)).valueOrNull;
      if (c != null) {
        _hydrate(c);
        _loaded = true;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit customer' : 'New customer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: Insets.pageTop,
          children: <Widget>[
            _TypeSelector(
              value: _type,
              onChanged: (CustomerType t) => setState(() {
                _type = t;
                // Switching to a homeowner clears any tax treatment, so it
                // cannot linger invisibly and reappear later.
                if (!t.isBusiness) {
                  _cis = CisStatus.notApplicable;
                  _reverseCharge = false;
                }
              }),
            ),
            const SizedBox(height: Insets.xl),
            AppTextField(
              controller: _name,
              label: _type.isBusiness ? 'Company name *' : 'Name *',
              textCapitalization: TextCapitalization.words,
              validator: (String? v) => Validators.required(v, field: 'Name'),
            ),
            if (_type.isBusiness) ...<Widget>[
              const SizedBox(height: Insets.md),
              AppTextField(
                controller: _contact,
                label: 'Contact name',
                hint: 'Who you actually deal with',
                textCapitalization: TextCapitalization.words,
              ),
            ],
            const SizedBox(height: Insets.md),
            AppTextField(
              controller: _phone,
              label: 'Phone',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: Insets.md),
            AppTextField(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: Validators.optionalEmail,
            ),
            const SizedBox(height: Insets.md),
            AppTextField(
              controller: _billing,
              label: 'Billing address',
              maxLines: 3,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: Insets.md),
            AppTextField(
              controller: _site,
              label: 'Site address',
              maxLines: 3,
              textCapitalization: TextCapitalization.words,
            ),

            // Everything below is contractor-only. A homeowner never sees a
            // word about CIS or the reverse charge — it would be noise, and
            // none of it applies to them.
            if (_type.isBusiness) ...<Widget>[
              const SizedBox(height: Insets.xl),
              const SectionHeader('Tax treatment'),
              _TaxCard(
                cis: _cis,
                reverseCharge: _reverseCharge,
                onCis: (CisStatus s) => setState(() => _cis = s),
                onReverseCharge: (bool v) =>
                    setState(() => _reverseCharge = v),
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      controller: _vatNumber,
                      label: 'VAT number',
                      hint: 'GB123456789',
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: AppTextField(
                      controller: _companyNumber,
                      label: 'Company no.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              AppTextField(
                controller: _terms,
                label: 'Payment terms (days)',
                hint: 'Leave blank to use your default',
                keyboardType: TextInputType.number,
              ),
            ],

            const SizedBox(height: Insets.md),
            AppTextField(
              controller: _notes,
              label: 'Notes',
              maxLines: 3,
            ),
            const SizedBox(height: Insets.xxl),
            if (_isEdit)
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(),
                icon: _saving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Icon(Icons.save_outlined),
                label: const Text('Save changes'),
              )
            else ...<Widget>[
              // Primary action: invoicing is why the customer is being added, so
              // the form goes straight there instead of dead-ending on a record.
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(thenInvoice: true),
                icon: _saving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Icon(Icons.receipt_long),
                label: const Text('Save & create invoice'),
              ),
              const SizedBox(height: Insets.sm),
              // Quiet escape hatch for adding a contact without billing yet —
              // this still offers quote/job next on the customer's page.
              TextButton(
                onPressed: _saving ? null : () => _save(),
                child: const Text('Just save customer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Homeowner vs contractor. The single most consequential field on the form —
/// it decides whether the app applies UK construction tax rules at all.
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.value, required this.onChanged});

  final CustomerType value;
  final ValueChanged<CustomerType> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: CustomerType.values.map((CustomerType t) {
        final bool selected = t == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: t == CustomerType.values.first ? Insets.md : 0,
            ),
            child: InkWell(
              borderRadius: Radii.card,
              onTap: () => onChanged(t),
              child: AnimatedContainer(
                duration: Motion.fast,
                padding: Insets.cardTight,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary.withValues(
                          alpha: theme.brightness == Brightness.dark ? 0.2 : 0.09)
                      : theme.colorScheme.surfaceContainerLow,
                  borderRadius: Radii.card,
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      t.icon,
                      size: 22,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: Insets.sm),
                    Text(
                      t.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// CIS and reverse-charge configuration, with enough explanation that a builder
/// who has only half-understood these rules can still set them correctly.
class _TaxCard extends StatelessWidget {
  const _TaxCard({
    required this.cis,
    required this.reverseCharge,
    required this.onCis,
    required this.onReverseCharge,
  });

  final CisStatus cis;
  final bool reverseCharge;
  final ValueChanged<CisStatus> onCis;
  final ValueChanged<bool> onReverseCharge;

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
            Text(
              'CIS deduction',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Deducted from labour only. Materials and plant are never '
              'deducted from.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<CisStatus>(
              initialValue: cis,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.percent),
              ),
              items: CisStatus.values
                  .map((CisStatus s) => DropdownMenuItem<CisStatus>(
                        value: s,
                        child: Text(s.label),
                      ))
                  .toList(),
              onChanged: (CisStatus? s) => onCis(s ?? CisStatus.notApplicable),
            ),
            const SizedBox(height: Insets.lg),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: Insets.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: reverseCharge,
              onChanged: onReverseCharge,
              title: Text(
                'VAT domestic reverse charge',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'For construction services to a VAT-registered customer who '
                'is not the end user. You charge no VAT; they account for it.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (reverseCharge) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Container(
                padding: Insets.cardTight,
                decoration: BoxDecoration(
                  color: c.container(c.info),
                  borderRadius: Radii.field,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.info_outline, size: 17, color: c.info),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        'Invoices to this customer will show £0 VAT and carry '
                        'the wording HMRC requires.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
