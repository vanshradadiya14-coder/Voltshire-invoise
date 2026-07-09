import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../models/company_profile.dart';
import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../models/job.dart';
import '../../models/line_item.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/entity_pickers.dart';
import '../../widgets/line_items_editor.dart';
import '../../widgets/ui_helpers.dart';

/// Create or edit an invoice. Can be seeded from a customer, a job, or a quote.
class InvoiceFormScreen extends ConsumerStatefulWidget {
  const InvoiceFormScreen({
    this.invoiceId,
    this.customerId,
    this.jobId,
    this.fromQuoteId,
    super.key,
  });

  final String? invoiceId;
  final String? customerId;
  final String? jobId;
  final String? fromQuoteId;

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
  }

  Future<void> _pickCustomer() async {
    final Customer? c = await showCustomerPicker(context, ref);
    if (c != null) {
      setState(() {
        _customerId = c.id;
        _customerName = c.name;
        _customerAddress = c.billingAddress.isNotEmpty ? c.billingAddress : c.siteAddress;
        // Clear job if it belonged to another customer.
        _jobId = null;
        _jobTitle = '';
      });
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
    setState(() => _saving = true);
    try {
      final repo = ref.read(invoiceRepositoryProvider);
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
          updatedAt: DateTime.now(),
        ));
        if (mounted) showSnack(context, 'Invoice updated.');
      } else {
        await repo.create(base);
        if (mounted) showSnack(context, 'Invoice created.');
      }
      if (mounted) context.pop();
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
        // Seed customer name/address from preselected customer.
        if (_customerId != null && _customerName.isEmpty) {
          final Customer? c = ref.watch(customerProvider(_customerId!)).valueOrNull;
          if (c != null) {
            _customerName = c.name;
            _customerAddress =
                c.billingAddress.isNotEmpty ? c.billingAddress : c.siteAddress;
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
            const SizedBox(height: 18),
            const SectionHeader('Items'),
            LineItemsEditor(
              items: _items,
              currencySymbol: symbol,
              defaultVat: defaultVat,
              onChanged: (List<LineItem> v) => setState(() => _items = v),
            ),
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
