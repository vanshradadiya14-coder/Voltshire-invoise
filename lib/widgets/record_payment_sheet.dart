import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/formatters.dart';
import '../core/utils/validators.dart';
import '../models/invoice.dart';
import '../models/payment.dart';
import '../providers/data_providers.dart';
import '../providers/repository_providers.dart';
import 'app_text_field.dart';
import 'ui_helpers.dart';

/// Bottom sheet to record a payment against an [invoice]. Pre-fills the amount
/// with the current balance due.
Future<void> showRecordPaymentSheet(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => _RecordPaymentSheet(invoice: invoice, ref: ref),
  );
}

class _RecordPaymentSheet extends StatefulWidget {
  const _RecordPaymentSheet({required this.invoice, required this.ref});
  final Invoice invoice;
  final WidgetRef ref;

  @override
  State<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<_RecordPaymentSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  String _method = AppConstants.paymentMethods.first;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.invoice.balanceDue > 0
          ? widget.invoice.balanceDue.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.ref.read(paymentRepositoryProvider).addPayment(Payment(
            id: '',
            ownerId: '',
            invoiceId: widget.invoice.id,
            invoiceNumber: widget.invoice.numberFormatted,
            customerName: widget.invoice.customerName,
            amount: parseNum(_amount.text),
            method: _method,
            reference: _reference.text.trim(),
            date: _date,
            notes: _notes.text.trim(),
          ));
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'Payment recorded.');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String symbol = widget.ref.read(currencySymbolProvider);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Record payment',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '${widget.invoice.numberFormatted} · Balance ${Formatters.money(widget.invoice.balanceDue, symbol: symbol)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _amount,
                label: 'Amount',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: decimalFormatters,
                validator: (String? v) =>
                    Validators.number(v, field: 'Amount', allowZero: false),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Text('Method',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  DropdownButtonFormField<String>(
                    value: _method,
                    items: AppConstants.paymentMethods
                        .map((String m) =>
                            DropdownMenuItem<String>(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (String? v) =>
                        setState(() => _method = v ?? _method),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DateField(
                label: 'Date',
                value: _date,
                onChanged: (DateTime? d) => setState(() => _date = d ?? _date),
              ),
              const SizedBox(height: 12),
              AppTextField(controller: _reference, label: 'Reference'),
              const SizedBox(height: 12),
              AppTextField(controller: _notes, label: 'Notes', maxLines: 2),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Save payment'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
