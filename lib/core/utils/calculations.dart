import 'dart:math' as math;

/// Pure calculation helpers for line items and invoice/quote totals.
///
/// Centralising the maths here guarantees the on-screen editor, the saved
/// document and the generated PDF always agree to the penny.
class Calc {
  const Calc._();

  /// Rounds to 2 decimal places using standard half-up rounding, avoiding
  /// floating-point drift (e.g. 0.1 + 0.2).
  static double round2(double value) => (value * 100).roundToDouble() / 100;

  /// Net line amount before discount and VAT: quantity × unit price.
  static double lineNet(double quantity, double unitPrice) =>
      round2(quantity * unitPrice);

  /// Discount amount for a line given a discount percentage.
  static double lineDiscount(double quantity, double unitPrice, double discountPct) =>
      round2(lineNet(quantity, unitPrice) * (discountPct / 100));

  /// Net amount after discount is applied (the taxable amount).
  static double lineNetAfterDiscount(
          double quantity, double unitPrice, double discountPct) =>
      round2(lineNet(quantity, unitPrice) - lineDiscount(quantity, unitPrice, discountPct));

  /// VAT amount for a line, computed on the discounted net.
  static double lineVat(
          double quantity, double unitPrice, double discountPct, double vatPct) =>
      round2(lineNetAfterDiscount(quantity, unitPrice, discountPct) * (vatPct / 100));

  /// Gross line total: discounted net + VAT.
  static double lineTotal(
          double quantity, double unitPrice, double discountPct, double vatPct) =>
      round2(lineNetAfterDiscount(quantity, unitPrice, discountPct) +
          lineVat(quantity, unitPrice, discountPct, vatPct));

  static double clampPercent(double value) => value.clamp(0, 100).toDouble();

  static double nonNegative(double value) => math.max(0.0, value);
}

/// Immutable value object holding the aggregate totals of a document.
class DocumentTotals {
  const DocumentTotals({
    required this.subtotal,
    required this.discountTotal,
    required this.vatTotal,
    required this.grandTotal,
  });

  /// Sum of each line's net-after-discount (the taxable base).
  final double subtotal;

  /// Sum of all line discounts.
  final double discountTotal;

  /// Sum of all line VAT.
  final double vatTotal;

  /// Subtotal + VAT.
  final double grandTotal;

  static const DocumentTotals zero = DocumentTotals(
    subtotal: 0,
    discountTotal: 0,
    vatTotal: 0,
    grandTotal: 0,
  );
}
