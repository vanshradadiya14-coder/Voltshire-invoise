import '../core/utils/calculations.dart';
import '../core/utils/firestore_utils.dart';
import 'trade_enums.dart';

/// A single line on a quote or invoice.
///
/// Line items are embedded as an array inside the parent quote/invoice
/// document (rather than a separate collection) so a document reads/writes
/// atomically and works seamlessly offline and in PDF generation.
class LineItem {
  const LineItem({
    required this.description,
    this.quantity = 1,
    this.unitPrice = 0,
    this.discountPercent = 0,
    this.vatPercent = 0,
    this.category = LineCategory.other,
    this.unit = PriceUnit.each,
  });

  final String description;
  final double quantity;
  final double unitPrice;

  /// Per-line discount as a percentage (0–100).
  final double discountPercent;

  /// Per-line VAT rate as a percentage (0–100).
  final double vatPercent;

  /// What this line is for. Drives the CIS labour/materials split and groups
  /// the line on the PDF.
  ///
  /// Defaults to [LineCategory.other], which is *not* CIS-deductible — so a
  /// legacy line item with no stored category settles to exactly the same
  /// figure it always did.
  final LineCategory category;

  /// The unit this was priced in, carried over from the price list so the
  /// document can read "2 days @ £280/day".
  final PriceUnit unit;

  // ---- Derived amounts (never stored; always recomputed) ----

  double get net => Calc.lineNet(quantity, unitPrice);
  double get discountAmount => Calc.lineDiscount(quantity, unitPrice, discountPercent);
  double get netAfterDiscount =>
      Calc.lineNetAfterDiscount(quantity, unitPrice, discountPercent);
  double get vatAmount =>
      Calc.lineVat(quantity, unitPrice, discountPercent, vatPercent);
  double get total =>
      Calc.lineTotal(quantity, unitPrice, discountPercent, vatPercent);

  /// True when CIS is withheld from this line.
  bool get isCisDeductible => category.cisDeductible;

  /// "2 days @ £280.00" — reads naturally on the document.
  String quantityLabel(String symbol) {
    final String qty = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
    final String suffix = unit == PriceUnit.each ? '' : ' ${unit.short}';
    return '$qty$suffix @ $symbol${unitPrice.toStringAsFixed(2)}';
  }

  LineItem copyWith({
    String? description,
    double? quantity,
    double? unitPrice,
    double? discountPercent,
    double? vatPercent,
    LineCategory? category,
    PriceUnit? unit,
  }) {
    return LineItem(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountPercent: discountPercent ?? this.discountPercent,
      vatPercent: vatPercent ?? this.vatPercent,
      category: category ?? this.category,
      unit: unit ?? this.unit,
    );
  }

  factory LineItem.fromMap(Map<String, dynamic> map) {
    return LineItem(
      description: asString(map['description']),
      quantity: asDouble(map['quantity'], fallback: 1),
      unitPrice: asDouble(map['unitPrice']),
      discountPercent: asDouble(map['discountPercent']),
      vatPercent: asDouble(map['vatPercent']),
      category: LineCategory.fromName(map['category'] as String?),
      unit: PriceUnit.fromName(map['unit'] as String?),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'description': description,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountPercent': discountPercent,
        'vatPercent': vatPercent,
        'category': category.name,
        'unit': unit.name,
      };
}

/// Aggregates a list of [LineItem]s into document-level totals.
extension LineItemTotals on List<LineItem> {
  DocumentTotals get totals {
    double subtotal = 0;
    double discount = 0;
    double vat = 0;
    for (final LineItem item in this) {
      subtotal += item.netAfterDiscount;
      discount += item.discountAmount;
      vat += item.vatAmount;
    }
    subtotal = Calc.round2(subtotal);
    discount = Calc.round2(discount);
    vat = Calc.round2(vat);
    return DocumentTotals(
      subtotal: subtotal,
      discountTotal: discount,
      vatTotal: vat,
      grandTotal: Calc.round2(subtotal + vat),
    );
  }
}
