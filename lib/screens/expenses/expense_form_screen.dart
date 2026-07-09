import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../../models/expense.dart';
import '../../models/job.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/entity_pickers.dart';
import '../../widgets/ui_helpers.dart';

/// Create or edit an expense, optionally with a receipt photo and job link.
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({this.expenseId, this.jobId, super.key});
  final String? expenseId;
  final String? jobId;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _supplier = TextEditingController();
  final TextEditingController _description = TextEditingController();

  String _category = AppConstants.expenseCategories.first;
  DateTime _date = DateTime.now();
  String? _jobId;
  String _jobTitle = '';
  File? _receipt;
  String _existingReceiptUrl = '';
  String _existingReceiptPath = '';

  bool _loaded = false;
  bool _saving = false;
  bool get _isEdit => widget.expenseId != null;

  @override
  void initState() {
    super.initState();
    _jobId = widget.jobId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _supplier.dispose();
    _description.dispose();
    super.dispose();
  }

  void _hydrate(Expense e) {
    _category = e.category;
    _amount.text = e.amount.toStringAsFixed(2);
    _supplier.text = e.supplier;
    _description.text = e.description;
    _date = e.date ?? DateTime.now();
    _jobId = e.jobId;
    _jobTitle = e.jobTitle;
    _existingReceiptUrl = e.receiptUrl;
    _existingReceiptPath = e.receiptPath;
  }

  Future<void> _pickReceipt() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (file != null) setState(() => _receipt = File(file.path));
  }

  Future<void> _pickJob() async {
    final Job? j = await showJobPicker(context, ref);
    if (j != null) {
      setState(() {
        _jobId = j.id;
        _jobTitle = j.title;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(expenseRepositoryProvider);
      final Expense data = Expense(
        id: widget.expenseId ?? '',
        ownerId: '',
        category: _category,
        amount: parseNum(_amount.text),
        supplier: _supplier.text.trim(),
        description: _description.text.trim(),
        jobId: _jobId,
        jobTitle: _jobTitle,
        receiptUrl: _existingReceiptUrl,
        receiptPath: _existingReceiptPath,
        date: _date,
      );
      if (_isEdit) {
        await repo.update(data, receipt: _receipt);
        if (mounted) showSnack(context, 'Expense updated.');
      } else {
        await repo.create(data, receipt: _receipt);
        if (mounted) showSnack(context, 'Expense added.');
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
    if (_isEdit && !_loaded) {
      final Expense? e = ref
          .watch(expensesProvider)
          .valueOrNull
          ?.where((Expense x) => x.id == widget.expenseId!)
          .firstOrNull;
      if (e != null) {
        _hydrate(e);
        _loaded = true;
      }
    }
    if (!_isEdit && _jobId != null && _jobTitle.isEmpty) {
      final Job? j = ref.watch(jobProvider(_jobId!)).valueOrNull;
      if (j != null) _jobTitle = j.title;
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit expense' : 'New expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text('Category',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                DropdownButtonFormField<String>(
                  value: _category,
                  items: AppConstants.expenseCategories
                      .map((String c) =>
                          DropdownMenuItem<String>(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (String? v) => setState(() => _category = v ?? _category),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _amount,
              label: 'Amount *',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: decimalFormatters,
              validator: (String? v) =>
                  Validators.number(v, field: 'Amount', allowZero: false),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _supplier,
              label: 'Supplier',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _description,
              label: 'Description',
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),
            DateField(
              label: 'Date',
              value: _date,
              onChanged: (DateTime? d) => setState(() => _date = d ?? _date),
            ),
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text('Link to job (optional)',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickJob,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.construction_outlined),
                      suffixIcon: _jobId != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() {
                                _jobId = null;
                                _jobTitle = '';
                              }),
                            )
                          : const Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(_jobTitle.isEmpty ? 'No job' : _jobTitle),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ReceiptPicker(
              file: _receipt,
              existingUrl: _existingReceiptUrl,
              onPick: _pickReceipt,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.save_outlined),
              label: Text(_isEdit ? 'Save changes' : 'Add expense'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptPicker extends StatelessWidget {
  const _ReceiptPicker({
    required this.file,
    required this.existingUrl,
    required this.onPick,
  });
  final File? file;
  final String existingUrl;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final bool hasImage = file != null || existingUrl.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text('Receipt photo',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPick,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? (file != null
                    ? Image.file(file!, fit: BoxFit.cover, width: double.infinity)
                    : CachedNetworkImage(
                        imageUrl: existingUrl,
                        fit: BoxFit.cover,
                        width: double.infinity))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.receipt_long_outlined,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      const Text('Tap to attach a receipt'),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
