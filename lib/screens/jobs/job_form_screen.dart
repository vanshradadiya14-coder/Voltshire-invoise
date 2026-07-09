import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/validators.dart';
import '../../models/customer.dart';
import '../../models/enums.dart';
import '../../models/job.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/entity_pickers.dart';
import '../../widgets/ui_helpers.dart';

/// Create or edit a job. Optionally pre-selects a customer via [customerId].
class JobFormScreen extends ConsumerStatefulWidget {
  const JobFormScreen({this.jobId, this.customerId, super.key});
  final String? jobId;
  final String? customerId;

  @override
  ConsumerState<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends ConsumerState<JobFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _site = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  String? _customerId;
  String _customerName = '';
  JobStatus _status = JobStatus.quote;
  DateTime? _startDate;
  DateTime? _completionDate;

  bool _loaded = false;
  bool _saving = false;
  bool get _isEdit => widget.jobId != null;

  @override
  void initState() {
    super.initState();
    _customerId = widget.customerId;
  }

  @override
  void dispose() {
    _title.dispose();
    _site.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _hydrate(Job j) {
    _title.text = j.title;
    _site.text = j.siteAddress;
    _description.text = j.description;
    _notes.text = j.notes;
    _customerId = j.customerId;
    _customerName = j.customerName;
    _status = j.status;
    _startDate = j.startDate;
    _completionDate = j.completionDate;
  }

  Future<void> _pickCustomer() async {
    final Customer? c = await showCustomerPicker(context, ref);
    if (c != null) {
      setState(() {
        _customerId = c.id;
        _customerName = c.name;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      showSnack(context, 'Please select a customer.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(jobRepositoryProvider);
      if (_isEdit) {
        final Job? existing = ref.read(jobProvider(widget.jobId!)).valueOrNull;
        if (existing == null) throw StateError('Job not found');
        await repo.update(existing.copyWith(
          customerId: _customerId,
          customerName: _customerName,
          title: _title.text.trim(),
          siteAddress: _site.text.trim(),
          description: _description.text.trim(),
          status: _status,
          startDate: _startDate,
          completionDate: _completionDate,
          clearStartDate: _startDate == null,
          clearCompletionDate: _completionDate == null,
          notes: _notes.text.trim(),
          updatedAt: DateTime.now(),
        ));
      } else {
        await repo.create(Job(
          id: '',
          ownerId: '',
          customerId: _customerId!,
          customerName: _customerName,
          title: _title.text.trim(),
          siteAddress: _site.text.trim(),
          description: _description.text.trim(),
          status: _status,
          startDate: _startDate,
          completionDate: _completionDate,
          notes: _notes.text.trim(),
        ));
      }
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Job updated.' : 'Job created.');
      context.pop();
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && !_loaded) {
      final Job? j = ref.watch(jobProvider(widget.jobId!)).valueOrNull;
      if (j != null) {
        _hydrate(j);
        _loaded = true;
      }
    }
    // Resolve the preselected customer's name for display.
    if (!_isEdit && _customerId != null && _customerName.isEmpty) {
      final Customer? c = ref.watch(customerProvider(_customerId!)).valueOrNull;
      if (c != null) _customerName = c.name;
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit job' : 'New job')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            AppTextField(
              controller: _title,
              label: 'Job title *',
              textCapitalization: TextCapitalization.sentences,
              validator: (String? v) => Validators.required(v, field: 'Title'),
            ),
            const SizedBox(height: 14),
            _CustomerSelector(name: _customerName, onTap: _pickCustomer),
            const SizedBox(height: 14),
            AppTextField(
              controller: _site,
              label: 'Site address',
              maxLines: 2,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _description,
              label: 'Description',
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),
            _StatusSelector(
              status: _status,
              onChanged: (JobStatus s) => setState(() => _status = s),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: DateField(
                    label: 'Start date',
                    value: _startDate,
                    clearable: true,
                    onChanged: (DateTime? d) => setState(() => _startDate = d),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DateField(
                    label: 'Completion date',
                    value: _completionDate,
                    clearable: true,
                    onChanged: (DateTime? d) => setState(() => _completionDate = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(controller: _notes, label: 'Notes', maxLines: 3),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.save_outlined),
              label: Text(_isEdit ? 'Save changes' : 'Create job'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerSelector extends StatelessWidget {
  const _CustomerSelector({required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text('Customer *',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: InputDecorator(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline),
              suffixIcon: Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              name.isEmpty ? 'Select customer' : name,
              style: name.isEmpty
                  ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({required this.status, required this.onChanged});
  final JobStatus status;
  final ValueChanged<JobStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          children: JobStatus.values
              .map((JobStatus s) => ChoiceChip(
                    label: Text(s.label),
                    selected: status == s,
                    onSelected: (_) => onChanged(s),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
