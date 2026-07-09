import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/validators.dart';
import '../../models/customer.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/ui_helpers.dart';

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
    super.dispose();
  }

  void _hydrate(Customer c) {
    _name.text = c.name;
    _phone.text = c.phone;
    _email.text = c.email;
    _billing.text = c.billingAddress;
    _site.text = c.siteAddress;
    _notes.text = c.notes;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      if (_isEdit) {
        final Customer? existing =
            ref.read(customerProvider(widget.customerId!)).valueOrNull;
        if (existing == null) throw StateError('Customer not found');
        await repo.update(existing.copyWith(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          billingAddress: _billing.text.trim(),
          siteAddress: _site.text.trim(),
          notes: _notes.text.trim(),
          updatedAt: DateTime.now(),
        ));
      } else {
        await repo.create(Customer(
          id: '',
          ownerId: '',
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          billingAddress: _billing.text.trim(),
          siteAddress: _site.text.trim(),
          notes: _notes.text.trim(),
        ));
      }
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Customer updated.' : 'Customer added.');
      context.pop();
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            AppTextField(
              controller: _name,
              label: 'Name *',
              textCapitalization: TextCapitalization.words,
              validator: (String? v) => Validators.required(v, field: 'Name'),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _phone,
              label: 'Phone',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: Validators.optionalEmail,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _billing,
              label: 'Billing address',
              maxLines: 3,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _site,
              label: 'Site address',
              maxLines: 3,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _notes,
              label: 'Notes',
              maxLines: 3,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.save_outlined),
              label: Text(_isEdit ? 'Save changes' : 'Add customer'),
            ),
          ],
        ),
      ),
    );
  }
}
