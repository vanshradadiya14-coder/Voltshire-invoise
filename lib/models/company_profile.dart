import '../core/constants/app_constants.dart';
import '../core/utils/firestore_utils.dart';

/// The company / business profile captured by the Business Setup Wizard and
/// editable from Settings. Stored in `settings/{uid}`.
///
/// Every invoice and quote is populated from this profile, so it is the single
/// source of truth for company identity, bank details and document defaults.
class CompanyProfile {
  const CompanyProfile({
    this.logoUrl = '',
    this.companyName = '',
    this.ownerName = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.registrationNumber = '',
    this.vatNumber = '',
    this.address = '',
    this.postCode = '',
    this.city = '',
    this.country = 'United Kingdom',
    this.bankName = '',
    this.accountName = '',
    this.sortCode = '',
    this.accountNumber = '',
    this.iban = '',
    this.swift = '',
    this.invoicePrefix = AppConstants.defaultInvoicePrefix,
    this.quotePrefix = AppConstants.defaultQuotePrefix,
    this.defaultVatRate = AppConstants.defaultVatRate,
    this.paymentTerms = AppConstants.defaultPaymentTerms,
    this.currencyCode = AppConstants.defaultCurrencyCode,
    this.currencySymbol = AppConstants.defaultCurrencySymbol,
    this.notes = '',
    this.nextInvoiceNumber = 1,
    this.nextQuoteNumber = 1,
    this.updatedAt,
  });

  final String logoUrl;
  final String companyName;
  final String ownerName;
  final String phone;
  final String email;
  final String website;
  final String registrationNumber;
  final String vatNumber;

  final String address;
  final String postCode;
  final String city;
  final String country;

  final String bankName;
  final String accountName;
  final String sortCode;
  final String accountNumber;
  final String iban;
  final String swift;

  final String invoicePrefix;
  final String quotePrefix;
  final double defaultVatRate;
  final String paymentTerms;
  final String currencyCode;
  final String currencySymbol;
  final String notes;

  /// Auto-numbering counters. Incremented atomically when a document is issued.
  final int nextInvoiceNumber;
  final int nextQuoteNumber;

  final DateTime? updatedAt;

  /// True when the profile has enough info to be considered "set up".
  bool get isComplete => companyName.trim().isNotEmpty;

  /// Full formatted address block for documents.
  String get fullAddress {
    final List<String> parts = <String>[
      address,
      [postCode, city].where((s) => s.trim().isNotEmpty).join(' '),
      country,
    ];
    return parts.where((String s) => s.trim().isNotEmpty).join('\n');
  }

  /// Formats an invoice number, e.g. `INV-000018`.
  String formatInvoiceNumber(int number) =>
      '$invoicePrefix${number.toString().padLeft(AppConstants.invoiceNumberPadding, '0')}';

  String formatQuoteNumber(int number) =>
      '$quotePrefix${number.toString().padLeft(AppConstants.invoiceNumberPadding, '0')}';

  CompanyProfile copyWith({
    String? logoUrl,
    String? companyName,
    String? ownerName,
    String? phone,
    String? email,
    String? website,
    String? registrationNumber,
    String? vatNumber,
    String? address,
    String? postCode,
    String? city,
    String? country,
    String? bankName,
    String? accountName,
    String? sortCode,
    String? accountNumber,
    String? iban,
    String? swift,
    String? invoicePrefix,
    String? quotePrefix,
    double? defaultVatRate,
    String? paymentTerms,
    String? currencyCode,
    String? currencySymbol,
    String? notes,
    int? nextInvoiceNumber,
    int? nextQuoteNumber,
    DateTime? updatedAt,
  }) {
    return CompanyProfile(
      logoUrl: logoUrl ?? this.logoUrl,
      companyName: companyName ?? this.companyName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      vatNumber: vatNumber ?? this.vatNumber,
      address: address ?? this.address,
      postCode: postCode ?? this.postCode,
      city: city ?? this.city,
      country: country ?? this.country,
      bankName: bankName ?? this.bankName,
      accountName: accountName ?? this.accountName,
      sortCode: sortCode ?? this.sortCode,
      accountNumber: accountNumber ?? this.accountNumber,
      iban: iban ?? this.iban,
      swift: swift ?? this.swift,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      quotePrefix: quotePrefix ?? this.quotePrefix,
      defaultVatRate: defaultVatRate ?? this.defaultVatRate,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      notes: notes ?? this.notes,
      nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
      nextQuoteNumber: nextQuoteNumber ?? this.nextQuoteNumber,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CompanyProfile.fromMap(Map<String, dynamic> map) {
    return CompanyProfile(
      logoUrl: asString(map['logoUrl']),
      companyName: asString(map['companyName']),
      ownerName: asString(map['ownerName']),
      phone: asString(map['phone']),
      email: asString(map['email']),
      website: asString(map['website']),
      registrationNumber: asString(map['registrationNumber']),
      vatNumber: asString(map['vatNumber']),
      address: asString(map['address']),
      postCode: asString(map['postCode']),
      city: asString(map['city']),
      country: asString(map['country'], fallback: 'United Kingdom'),
      bankName: asString(map['bankName']),
      accountName: asString(map['accountName']),
      sortCode: asString(map['sortCode']),
      accountNumber: asString(map['accountNumber']),
      iban: asString(map['iban']),
      swift: asString(map['swift']),
      invoicePrefix: asString(map['invoicePrefix'], fallback: AppConstants.defaultInvoicePrefix),
      quotePrefix: asString(map['quotePrefix'], fallback: AppConstants.defaultQuotePrefix),
      defaultVatRate: asDouble(map['defaultVatRate'], fallback: AppConstants.defaultVatRate),
      paymentTerms: asString(map['paymentTerms'], fallback: AppConstants.defaultPaymentTerms),
      currencyCode: asString(map['currencyCode'], fallback: AppConstants.defaultCurrencyCode),
      currencySymbol:
          asString(map['currencySymbol'], fallback: AppConstants.defaultCurrencySymbol),
      notes: asString(map['notes']),
      nextInvoiceNumber: asInt(map['nextInvoiceNumber'], fallback: 1),
      nextQuoteNumber: asInt(map['nextQuoteNumber'], fallback: 1),
      updatedAt: tsToDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'logoUrl': logoUrl,
        'companyName': companyName,
        'ownerName': ownerName,
        'phone': phone,
        'email': email,
        'website': website,
        'registrationNumber': registrationNumber,
        'vatNumber': vatNumber,
        'address': address,
        'postCode': postCode,
        'city': city,
        'country': country,
        'bankName': bankName,
        'accountName': accountName,
        'sortCode': sortCode,
        'accountNumber': accountNumber,
        'iban': iban,
        'swift': swift,
        'invoicePrefix': invoicePrefix,
        'quotePrefix': quotePrefix,
        'defaultVatRate': defaultVatRate,
        'paymentTerms': paymentTerms,
        'currencyCode': currencyCode,
        'currencySymbol': currencySymbol,
        'notes': notes,
        'nextInvoiceNumber': nextInvoiceNumber,
        'nextQuoteNumber': nextQuoteNumber,
        'updatedAt': dateToTs(updatedAt ?? DateTime.now()),
      };
}
