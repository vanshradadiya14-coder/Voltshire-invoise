/// App-wide constant values and sensible defaults.
class AppConstants {
  const AppConstants._();

  static const String appName = 'Builder CRM';

  // Default company/invoice settings used before the setup wizard runs, and as
  // fallbacks when a value is missing.
  static const String defaultCurrencyCode = 'GBP';
  static const String defaultCurrencySymbol = '£';
  static const String defaultLocale = 'en_GB';
  static const double defaultVatRate = 20.0; // percent
  static const String defaultInvoicePrefix = 'INV-';
  static const String defaultQuotePrefix = 'QT-';
  static const int invoiceNumberPadding = 6; // INV-000001
  static const String defaultPaymentTerms = 'Payment due within 14 days';

  // How many days a quote is valid for by default.
  static const int defaultQuoteValidityDays = 30;
  // How many days after issue an invoice is due by default.
  static const int defaultInvoiceDueDays = 14;

  // Pagination page sizes for list queries.
  static const int listPageSize = 25;

  // Local-preference keys.
  static const String prefThemeMode = 'pref_theme_mode';

  // Photo categories.
  static const List<String> photoCategories = <String>[
    'Before Work',
    'Progress',
    'Completed Work',
  ];

  // Document categories.
  static const List<String> documentCategories = <String>[
    'Contract',
    'Certificate',
    'Guarantee',
    'Planning Document',
    'Receipt',
    'Invoice',
    'Other',
  ];

  // Expense categories.
  static const List<String> expenseCategories = <String>[
    'Materials',
    'Fuel',
    'Equipment',
    'Labour',
    'Skip Hire',
    'Other',
  ];

  // Payment methods.
  static const List<String> paymentMethods = <String>[
    'Bank Transfer',
    'Cash',
    'Card',
    'Cheque',
    'Direct Debit',
    'Other',
  ];
}
