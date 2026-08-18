import '../core/utils/firestore_utils.dart';
import 'line_item.dart';
import 'trade_enums.dart';

/// A saved entry in the builder's price list. Collection `price_items`.
///
/// Builders quote the same things over and over — a day rate, a skip, a sheet
/// of plasterboard. Retyping the description, unit, price and VAT every time is
/// the single most repetitive thing this app used to make them do.
///
/// Adding a price item to a document **copies** its values into a [LineItem].
/// Editing the saved price afterwards never rewrites a historic invoice, which
/// would silently change what a customer was billed.
class PriceItem {
  const PriceItem({
    required this.id,
    required this.ownerId,
    required this.description,
    this.unitPrice = 0,
    this.unit = PriceUnit.each,
    this.category = LineCategory.materials,
    this.vatPercent = 20,
    this.defaultQuantity = 1,
    this.notes = '',
    this.useCount = 0,
    this.lastUsedAt,
    this.isSeeded = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String description;
  final double unitPrice;
  final PriceUnit unit;
  final LineCategory category;
  final double vatPercent;

  /// Pre-filled quantity when added to a document — a skip is usually 1, a
  /// day rate is often 1, plasterboard is rarely 1.
  final double defaultQuantity;

  final String notes;

  /// How often this has been added to a document. Drives most-used ordering,
  /// which matters once a builder has 80 saved prices.
  final int useCount;
  final DateTime? lastUsedAt;

  /// True for the starter items created on first run, so they can be cleared
  /// in one action without touching anything the builder added themselves.
  final bool isSeeded;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get searchText => '$description ${category.label} $notes'.toLowerCase();

  /// "£280.00 / day"
  String priceLabel(String symbol) =>
      '$symbol${unitPrice.toStringAsFixed(2)} / ${unit.short}';

  /// Copies this saved price onto a document line.
  LineItem toLineItem({double? quantity}) => LineItem(
        description: description,
        quantity: quantity ?? defaultQuantity,
        unitPrice: unitPrice,
        vatPercent: vatPercent,
        category: category,
        unit: unit,
      );

  /// Builds a saved price from a line the builder already typed, so "save this
  /// for next time" works straight off an invoice.
  factory PriceItem.fromLineItem(LineItem item) => PriceItem(
        id: '',
        ownerId: '',
        description: item.description,
        unitPrice: item.unitPrice,
        unit: item.unit,
        category: item.category,
        vatPercent: item.vatPercent,
        defaultQuantity: item.quantity,
      );

  PriceItem copyWith({
    String? description,
    double? unitPrice,
    PriceUnit? unit,
    LineCategory? category,
    double? vatPercent,
    double? defaultQuantity,
    String? notes,
    int? useCount,
    DateTime? lastUsedAt,
    DateTime? updatedAt,
  }) {
    return PriceItem(
      id: id,
      ownerId: ownerId,
      description: description ?? this.description,
      unitPrice: unitPrice ?? this.unitPrice,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      vatPercent: vatPercent ?? this.vatPercent,
      defaultQuantity: defaultQuantity ?? this.defaultQuantity,
      notes: notes ?? this.notes,
      useCount: useCount ?? this.useCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      isSeeded: isSeeded,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PriceItem.fromMap(String id, Map<String, dynamic> map) {
    return PriceItem(
      id: id,
      ownerId: asString(map['ownerId']),
      description: asString(map['description']),
      unitPrice: asDouble(map['unitPrice']),
      unit: PriceUnit.fromName(map['unit'] as String?),
      category: LineCategory.fromName(map['category'] as String?),
      vatPercent: asDouble(map['vatPercent'], fallback: 20),
      defaultQuantity: asDouble(map['defaultQuantity'], fallback: 1),
      notes: asString(map['notes']),
      useCount: asInt(map['useCount']),
      lastUsedAt: tsToDate(map['lastUsedAt']),
      isSeeded: asBool(map['isSeeded']),
      createdAt: tsToDate(map['createdAt']),
      updatedAt: tsToDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerId': ownerId,
        'description': description,
        'descriptionLower': description.toLowerCase(),
        'unitPrice': unitPrice,
        'unit': unit.name,
        'category': category.name,
        'vatPercent': vatPercent,
        'defaultQuantity': defaultQuantity,
        'notes': notes,
        'useCount': useCount,
        'lastUsedAt': dateToTs(lastUsedAt),
        'isSeeded': isSeeded,
        'createdAt': dateToTs(createdAt ?? DateTime.now()),
        'updatedAt': dateToTs(DateTime.now()),
      };
}

/// Starter price list created on first run.
///
/// A price library that starts empty is a feature nobody discovers. These are
/// realistic mid-2020s UK trade figures — deliberately round, because they are
/// a starting point the builder is expected to edit, not a quotation.
class PriceItemSeeds {
  const PriceItemSeeds._();

  static const List<({
    String description,
    double price,
    PriceUnit unit,
    LineCategory category,
    double qty,
  })> defaults = <({
    String description,
    double price,
    PriceUnit unit,
    LineCategory category,
    double qty,
  })>[
    // ---- Labour ----
    (description: 'Labour — day rate', price: 280, unit: PriceUnit.day, category: LineCategory.labour, qty: 1),
    (description: 'Labour — half day', price: 160, unit: PriceUnit.day, category: LineCategory.labour, qty: 1),
    (description: 'Labourer — day rate', price: 160, unit: PriceUnit.day, category: LineCategory.labour, qty: 1),
    (description: 'Labour — hourly', price: 45, unit: PriceUnit.hour, category: LineCategory.labour, qty: 8),
    (description: 'Emergency call-out', price: 120, unit: PriceUnit.each, category: LineCategory.labour, qty: 1),

    // ---- Materials ----
    (description: 'Plasterboard 12.5mm 2400×1200', price: 12.50, unit: PriceUnit.each, category: LineCategory.materials, qty: 10),
    (description: 'Multi-finish plaster 25kg', price: 11.00, unit: PriceUnit.each, category: LineCategory.materials, qty: 10),
    (description: 'Cement 25kg', price: 6.50, unit: PriceUnit.each, category: LineCategory.materials, qty: 10),
    (description: 'Sharp sand — bulk bag', price: 48, unit: PriceUnit.each, category: LineCategory.materials, qty: 1),
    (description: 'MOT Type 1 — bulk bag', price: 52, unit: PriceUnit.each, category: LineCategory.materials, qty: 1),
    (description: 'Ready-mix concrete', price: 135, unit: PriceUnit.cubicMetre, category: LineCategory.materials, qty: 1),
    (description: 'Facing bricks', price: 0.85, unit: PriceUnit.each, category: LineCategory.materials, qty: 500),
    (description: 'CLS timber 38×63mm', price: 4.20, unit: PriceUnit.linearMetre, category: LineCategory.materials, qty: 20),
    (description: 'OSB3 board 18mm', price: 26, unit: PriceUnit.each, category: LineCategory.materials, qty: 5),
    (description: 'Loft insulation 100mm', price: 9.50, unit: PriceUnit.squareMetre, category: LineCategory.materials, qty: 20),

    // ---- Plant & hire ----
    (description: 'Skip hire — 8 yard', price: 320, unit: PriceUnit.each, category: LineCategory.plant, qty: 1),
    (description: 'Skip hire — 6 yard', price: 265, unit: PriceUnit.each, category: LineCategory.plant, qty: 1),
    (description: 'Scaffold hire', price: 180, unit: PriceUnit.week, category: LineCategory.plant, qty: 2),
    (description: 'Mini digger hire', price: 145, unit: PriceUnit.day, category: LineCategory.plant, qty: 1),
    (description: 'Waste disposal / tip run', price: 85, unit: PriceUnit.load, category: LineCategory.plant, qty: 1),

    // ---- Other ----
    (description: 'Building control application', price: 340, unit: PriceUnit.each, category: LineCategory.other, qty: 1),
    (description: 'Skip permit', price: 45, unit: PriceUnit.each, category: LineCategory.other, qty: 1),
  ];
}
