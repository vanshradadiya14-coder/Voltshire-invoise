import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/utils/validators.dart';
import '../../models/company_profile.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/ui_helpers.dart';

/// Common currency options offered in the wizard.
const Map<String, String> _currencies = <String, String>{
  'GBP': '£',
  'EUR': '€',
  'USD': r'$',
  'AUD': r'A$',
  'CAD': r'C$',
};

/// The first-run Business Setup Wizard. Also reused (with [editing] = true)
/// from Settings to edit the company profile later.
class BusinessSetupWizard extends ConsumerStatefulWidget {
  const BusinessSetupWizard({this.editing = false, super.key});

  final bool editing;

  @override
  ConsumerState<BusinessSetupWizard> createState() => _BusinessSetupWizardState();
}

class _BusinessSetupWizardState extends ConsumerState<BusinessSetupWizard> {
  final PageController _pageController = PageController();
  int _step = 0;
  bool _saving = false;
  bool _initialised = false;

  // A form key per step so we validate progressively.
  final List<GlobalKey<FormState>> _formKeys =
      List<GlobalKey<FormState>>.generate(4, (_) => GlobalKey<FormState>());

  // Controllers for every field.
  final TextEditingController _companyName = TextEditingController();
  final TextEditingController _ownerName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _website = TextEditingController();
  final TextEditingController _regNumber = TextEditingController();
  final TextEditingController _vatNumber = TextEditingController();

  final TextEditingController _address = TextEditingController();
  final TextEditingController _postCode = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _country = TextEditingController(text: 'United Kingdom');

  final TextEditingController _bankName = TextEditingController();
  final TextEditingController _accountName = TextEditingController();
  final TextEditingController _sortCode = TextEditingController();
  final TextEditingController _accountNumber = TextEditingController();
  final TextEditingController _iban = TextEditingController();
  final TextEditingController _swift = TextEditingController();

  final TextEditingController _invoicePrefix =
      TextEditingController(text: AppConstants.defaultInvoicePrefix);
  final TextEditingController _quotePrefix =
      TextEditingController(text: AppConstants.defaultQuotePrefix);
  final TextEditingController _vatRate =
      TextEditingController(text: AppConstants.defaultVatRate.toStringAsFixed(0));
  final TextEditingController _paymentTerms =
      TextEditingController(text: AppConstants.defaultPaymentTerms);
  final TextEditingController _notes = TextEditingController();

  String _currencyCode = AppConstants.defaultCurrencyCode;
  String? _existingLogoUrl;
  File? _pickedLogo;

  @override
  void dispose() {
    _pageController.dispose();
    for (final TextEditingController c in <TextEditingController>[
      _companyName, _ownerName, _phone, _email, _website, _regNumber, _vatNumber,
      _address, _postCode, _city, _country, _bankName, _accountName, _sortCode,
      _accountNumber, _iban, _swift, _invoicePrefix, _quotePrefix, _vatRate,
      _paymentTerms, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Prefills the form from an existing profile (edit mode / re-open).
  void _prefill(CompanyProfile p) {
    _companyName.text = p.companyName;
    _ownerName.text = p.ownerName;
    _phone.text = p.phone;
    _email.text = p.email;
    _website.text = p.website;
    _regNumber.text = p.registrationNumber;
    _vatNumber.text = p.vatNumber;
    _address.text = p.address;
    _postCode.text = p.postCode;
    _city.text = p.city;
    _country.text = p.country;
    _bankName.text = p.bankName;
    _accountName.text = p.accountName;
    _sortCode.text = p.sortCode;
    _accountNumber.text = p.accountNumber;
    _iban.text = p.iban;
    _swift.text = p.swift;
    _invoicePrefix.text = p.invoicePrefix;
    _quotePrefix.text = p.quotePrefix;
    _vatRate.text = p.defaultVatRate.toStringAsFixed(
        p.defaultVatRate.truncateToDouble() == p.defaultVatRate ? 0 : 2);
    _paymentTerms.text = p.paymentTerms;
    _notes.text = p.notes;
    _currencyCode = _currencies.containsKey(p.currencyCode)
        ? p.currencyCode
        : AppConstants.defaultCurrencyCode;
    _existingLogoUrl = p.logoUrl.isNotEmpty ? p.logoUrl : null;
  }

  Future<void> _pickLogo() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (file != null) setState(() => _pickedLogo = File(file.path));
  }

  void _next() {
    if (!_formKeys[_step].currentState!.validate()) return;
    if (_step < 3) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    // Validate all steps before saving.
    for (final GlobalKey<FormState> key in _formKeys) {
      if (key.currentState != null && !key.currentState!.validate()) return;
    }
    setState(() => _saving = true);
    try {
      final String uid = ref.read(currentUidProvider)!;
      final CompanyProfile existing =
          ref.read(companyProfileProvider).valueOrNull ?? const CompanyProfile();

      String logoUrl = _existingLogoUrl ?? '';
      if (_pickedLogo != null) {
        final upload = await ref.read(storageServiceProvider).uploadBytes(
              path: StoragePaths.logo(uid),
              bytes: await _pickedLogo!.readAsBytes(),
            );
        logoUrl = upload.url;
      }

      final CompanyProfile profile = existing.copyWith(
        logoUrl: logoUrl,
        companyName: _companyName.text.trim(),
        ownerName: _ownerName.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        website: _website.text.trim(),
        registrationNumber: _regNumber.text.trim(),
        vatNumber: _vatNumber.text.trim(),
        address: _address.text.trim(),
        postCode: _postCode.text.trim(),
        city: _city.text.trim(),
        country: _country.text.trim(),
        bankName: _bankName.text.trim(),
        accountName: _accountName.text.trim(),
        sortCode: _sortCode.text.trim(),
        accountNumber: _accountNumber.text.trim(),
        iban: _iban.text.trim(),
        swift: _swift.text.trim(),
        invoicePrefix: _invoicePrefix.text.trim(),
        quotePrefix: _quotePrefix.text.trim(),
        defaultVatRate: parseNum(_vatRate.text),
        paymentTerms: _paymentTerms.text.trim(),
        currencyCode: _currencyCode,
        currencySymbol: _currencies[_currencyCode] ?? '£',
        notes: _notes.text.trim(),
        updatedAt: DateTime.now(),
      );

      await ref.read(companyRepositoryProvider).save(profile);
      await ref.read(authRepositoryProvider).markCompanyProfileComplete(uid);

      if (!mounted) return;
      showSnack(context, widget.editing ? 'Company details saved.' : 'Setup complete!');
      if (widget.editing) {
        context.pop();
      } else {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prefill once when editing (or if a profile already exists).
    if (!_initialised) {
      final CompanyProfile? existing = ref.watch(companyProfileProvider).valueOrNull;
      if (existing != null) {
        _prefill(existing);
        _initialised = true;
      } else if (!widget.editing) {
        _initialised = true; // fresh onboarding, nothing to prefill
      }
    }

    const List<String> titles = <String>[
      'Company details',
      'Business address',
      'Bank details',
      'Invoice defaults',
    ];

    return PopScope(
      // Block back-swipe during first-run onboarding so setup can't be skipped.
      canPop: widget.editing,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.editing ? 'Edit company' : 'Business setup'),
          automaticallyImplyLeading: widget.editing,
        ),
        body: Column(
          children: <Widget>[
            _ProgressBar(step: _step, total: titles.length, title: titles[_step]),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  _buildCompanyStep(),
                  _buildAddressStep(),
                  _buildBankStep(),
                  _buildDefaultsStep(),
                ],
              ),
            ),
            _buildNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _stepScroll(GlobalKey<FormState> key, List<Widget> children) {
    return Form(
      key: key,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: <Widget>[
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCompanyStep() {
    final ThemeData theme = Theme.of(context);
    return _stepScroll(_formKeys[0], <Widget>[
      Center(
        child: Column(
          children: <Widget>[
            GestureDetector(
              onTap: _pickLogo,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: _pickedLogo != null
                    ? FileImage(_pickedLogo!)
                    : (_existingLogoUrl != null
                        ? NetworkImage(_existingLogoUrl!)
                        : null) as ImageProvider<Object>?,
                child: (_pickedLogo == null && _existingLogoUrl == null)
                    ? Icon(Icons.add_a_photo_outlined,
                        color: theme.colorScheme.onSurfaceVariant)
                    : null,
              ),
            ),
            TextButton(onPressed: _pickLogo, child: const Text('Company logo')),
          ],
        ),
      ),
      const SizedBox(height: 8),
      AppTextField(
        controller: _companyName,
        label: 'Company name *',
        textCapitalization: TextCapitalization.words,
        validator: (String? v) => Validators.required(v, field: 'Company name'),
      ),
      const SizedBox(height: 14),
      AppTextField(
        controller: _ownerName,
        label: 'Owner name',
        textCapitalization: TextCapitalization.words,
      ),
      const SizedBox(height: 14),
      AppTextField(
        controller: _phone,
        label: 'Phone number',
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 14),
      AppTextField(
        controller: _email,
        label: 'Email address',
        keyboardType: TextInputType.emailAddress,
        validator: Validators.optionalEmail,
      ),
      const SizedBox(height: 14),
      AppTextField(controller: _website, label: 'Website (optional)'),
      const SizedBox(height: 14),
      AppTextField(controller: _regNumber, label: 'Company registration number'),
      const SizedBox(height: 14),
      AppTextField(controller: _vatNumber, label: 'VAT number (optional)'),
    ]);
  }

  Widget _buildAddressStep() {
    return _stepScroll(_formKeys[1], <Widget>[
      AppTextField(
        controller: _address,
        label: 'Business address',
        maxLines: 2,
        textCapitalization: TextCapitalization.words,
      ),
      const SizedBox(height: 14),
      AppTextField(
        controller: _postCode,
        label: 'Post code',
        textCapitalization: TextCapitalization.characters,
      ),
      const SizedBox(height: 14),
      AppTextField(
        controller: _city,
        label: 'City',
        textCapitalization: TextCapitalization.words,
      ),
      const SizedBox(height: 14),
      AppTextField(
        controller: _country,
        label: 'Country',
        textCapitalization: TextCapitalization.words,
      ),
    ]);
  }

  Widget _buildBankStep() {
    return _stepScroll(_formKeys[2], <Widget>[
      AppTextField(controller: _bankName, label: 'Bank name'),
      const SizedBox(height: 14),
      AppTextField(controller: _accountName, label: 'Account name'),
      const SizedBox(height: 14),
      AppTextField(
        controller: _sortCode,
        label: 'Sort code',
        keyboardType: TextInputType.number,
        hint: '00-00-00',
      ),
      const SizedBox(height: 14),
      AppTextField(
        controller: _accountNumber,
        label: 'Account number',
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 14),
      AppTextField(controller: _iban, label: 'IBAN (optional)'),
      const SizedBox(height: 14),
      AppTextField(controller: _swift, label: 'SWIFT / BIC (optional)'),
    ]);
  }

  Widget _buildDefaultsStep() {
    return _stepScroll(_formKeys[3], <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: AppTextField(
              controller: _invoicePrefix,
              label: 'Invoice prefix',
              hint: 'INV-',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppTextField(
              controller: _quotePrefix,
              label: 'Quote prefix',
              hint: 'QT-',
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: AppTextField(
              controller: _vatRate,
              label: 'Default VAT %',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: decimalFormatters,
              validator: Validators.percent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildCurrencyDropdown()),
        ],
      ),
      const SizedBox(height: 14),
      AppTextField(
        controller: _paymentTerms,
        label: 'Default payment terms',
        maxLines: 2,
        hint: 'Payment due within 14 days',
      ),
      const SizedBox(height: 14),
      AppTextField(
        controller: _notes,
        label: 'Company notes (shown on documents)',
        maxLines: 3,
        hint: 'Thank you for choosing our company.',
      ),
    ]);
  }

  Widget _buildCurrencyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text('Currency',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
        DropdownButtonFormField<String>(
          value: _currencyCode,
          items: _currencies.entries
              .map((MapEntry<String, String> e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text('${e.key} (${e.value})'),
                  ))
              .toList(),
          onChanged: (String? v) => setState(() => _currencyCode = v ?? 'GBP'),
        ),
      ],
    );
  }

  Widget _buildNavBar() {
    final bool isLast = _step == 3;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: <Widget>[
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _back,
                  child: const Text('Back'),
                ),
              ),
            if (_step > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _saving ? null : _next,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(isLast
                        ? (widget.editing ? 'Save' : 'Finish setup')
                        : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step, required this.total, required this.title});
  final int step;
  final int total;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text('Step ${step + 1} of $total',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (step + 1) / total,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
