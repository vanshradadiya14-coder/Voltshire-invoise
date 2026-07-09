import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../models/company_profile.dart';
import '../../models/customer.dart';
import '../../models/enums.dart';
import '../../models/job.dart';
import '../../models/line_item.dart';
import '../../models/quote.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/entity_pickers.dart';
import '../../widgets/line_items_editor.dart';
import '../../widgets/ui_helpers.dart';

/// Create or edit a quotation.
class QuoteFormScreen extends ConsumerStatefulWidget {
  const QuoteFormScreen({this.quoteId, this.customerId, this.jobId, super.key});
  final String? quoteId;
  final String? customerId;
  final String? jobId;

  @override
  ConsumerState<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends ConsumerState<QuoteFormScreen> {
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
  DateTime? _validUntil;
  QuoteStatus _status = QuoteStatus.draft;

  bool _seeded = false;
  bool _saving = false;
  bool get _isEdit => widget.quoteId != null;

  @override
  void initState() {
    super.initState();
    _customerId = widget.customerId;
    _jobId = widget.jobId;
    _validUntil =
        DateTime.now().add(const Duration(days: AppConstants.defaultQuoteValidityDays));
  }

  @override
  void dispose() {
    _workDescription.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _hydrate(Quote q) {
    _customerId = q.customerId;
    _customerName = q.customerName;
    _customerAddress = q.customerAddress;
    _jobId = q.jobId;
    _jobTitle = q.jobTitle;
    _workDescription.text = q.workDescription;
    _notes.text = q.notes;
    _items = q.items;
    _issueDate = q.issueDate ?? DateTime.now();
    _validUntil = q.validUntil;
    _status = q.status;
  }

  Future<void> _pickCustomer() async {
    final Customer? c = await showCustomerPicker(context, ref);
    if (c != null) {
      setState(() {
        _customerId = c.id;
        _customerName = c.name;
        _customerAddress =
            c.billingAddress.isNotEmpty ? c.billingAddress : c.siteAddress;
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
      final repo = ref.read(quoteRepositoryProvider);
      if (_isEdit) {
        final Quote? existing =
            ref.read(quoteProvider(widget.quoteId!)).valueOrNull;
        if (existing == null) throw StateError('Quote not found');
        await repo.update(existing.copyWith(
          customerId: _customerId,
          customerName: _customerName,
          customerAddress: _customerAddress,
          jobId: _jobId,
          jobTitle: _jobTitle,
          workDescription: _workDescription.text.trim(),
          items: _items,
          issueDate: _issueDate,
          validUntil: _validUntil,
          status: _status,
          notes: _notes.text.trim(),
          updatedAt: DateTime.now(),
        ));
        if (mounted) showSnack(context, 'Quote updated.');
      } else {
        await repo.create(Quote(
          id: '',
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
          validUntil: _validUntil,
          status: _status,
          notes: _notes.text.trim(),
        ));
        if (mounted) showSnack(context, 'Quote created.');
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

    if (!_seeded) {
      if (_isEdit) {
        final Quote? q = ref.watch(quoteProvider(widget.quoteId!)).valueOrNull;
        if (q != null) {
          _hydrate(q);
          _seeded = true;
        }
      } else {
        if (_customerId != null && _customerName.isEmpty) {
          final Customer? c = ref.watch(customerProvider(_customerId!)).valueOrNull;
          if (c != null) {
            _customerName = c.name;
            _customerAddress =
                c.billingAddress.isNotEmpty ? c.billingAddress : c.siteAddress;
          }
        }
        if (_jobId != null && _jobTitle.isEmpty) {
          final Job? j = ref.watch(jobProvider(_jobId!)).valueOrNull;
          if (j != null) _jobTitle = j.title;
        }
        _seeded = true;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit quote' : 'New quote')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            _picker('Customer *', _customerName, Icons.person_outline, _pickCustomer),
            const SizedBox(height: 14),
            _picker('Job (optional)', _jobTitle, Icons.construction_outlined, _pickJob),
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
                    label: 'Valid until',
                    value: _validUntil,
                    clearable: true,
                    onChanged: (DateTime? d) => setState(() => _validUntil = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _statusSelector(),
            const SizedBox(height: 14),
            AppTextField(
              controller: _workDescription,
              label: 'Work description',
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
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
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.save_outlined),
              label: Text(_isEdit ? 'Save changes' : 'Create quote'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusSelector() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text('Status',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Wrap(
            spacing: 8,
            children: <QuoteStatus>[
              QuoteStatus.draft,
              QuoteStatus.sent,
              QuoteStatus.accepted,
              QuoteStatus.rejected,
            ]
                .map((QuoteStatus s) => ChoiceChip(
                      label: Text(s.label),
                      selected: _status == s,
                      onSelected: (_) => setState(() => _status = s),
                    ))
                .toList(),
          ),
        ],
      );

  Widget _picker(String label, String value, IconData icon, VoidCallback onTap) {
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
            child: Text(value.isEmpty ? 'Select' : value,
                style: value.isEmpty
                    ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                    : null),
          ),
        ),
      ],
    );
  }
}
