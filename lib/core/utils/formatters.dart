import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Formatting helpers for money, dates and numbers used throughout the UI and
/// PDF output. The currency symbol is passed in so it always reflects the
/// company profile's configured currency.
class Formatters {
  const Formatters._();

  /// Formats [amount] as money with the given [symbol], e.g. `£5,250.00`.
  static String money(num amount, {String symbol = AppConstants.defaultCurrencySymbol}) {
    final NumberFormat f = NumberFormat.currency(
      locale: AppConstants.defaultLocale,
      symbol: symbol,
      decimalDigits: 2,
    );
    return f.format(amount);
  }

  /// Plain number with 2 decimals and thousands separators: `5,250.00`.
  static String number(num value, {int decimals = 2}) {
    return NumberFormat.decimalPatternDigits(
      locale: AppConstants.defaultLocale,
      decimalDigits: decimals,
    ).format(value);
  }

  /// A short date: `28/06/2026`.
  static String date(DateTime date) =>
      DateFormat('dd/MM/yyyy', AppConstants.defaultLocale).format(date);

  /// A long, human-friendly date: `28 June 2026`.
  static String longDate(DateTime date) =>
      DateFormat('d MMMM yyyy', AppConstants.defaultLocale).format(date);

  /// `28 Jun 2026, 14:30`.
  static String dateTime(DateTime date) =>
      DateFormat('d MMM yyyy, HH:mm', AppConstants.defaultLocale).format(date);

  /// `Jun 2026` — used in reports.
  static String monthYear(DateTime date) =>
      DateFormat('MMM yyyy', AppConstants.defaultLocale).format(date);

  /// Percentage without trailing zeros: `20%`, `17.5%`.
  static String percent(num value) {
    final String s = value.toStringAsFixed(2);
    return '${s.replaceAll(RegExp(r'\.?0+$'), '')}%';
  }

  /// Human-readable file size for the documents screen.
  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
