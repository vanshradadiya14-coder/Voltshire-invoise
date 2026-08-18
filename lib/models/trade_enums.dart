import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// What kind of client this is.
///
/// This one field decides whether the app shows any UK construction tax UI at
/// all. For a homeowner, CIS and the VAT reverse charge never appear anywhere —
/// they are irrelevant and would only be confusing. For a contractor they drive
/// every invoice automatically.
enum CustomerType {
  domestic(
    'Homeowner',
    'Private client — standard VAT, no CIS',
    Icons.home_outlined,
  ),
  contractor(
    'Contractor',
    'Business client — CIS and reverse charge may apply',
    Icons.apartment_outlined,
  );

  const CustomerType(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;

  bool get isBusiness => this == CustomerType.contractor;

  static CustomerType fromName(String? name) => CustomerType.values.firstWhere(
        (CustomerType t) => t.name == name,
        // Legacy documents have no type. Defaulting to domestic keeps every
        // existing invoice computing exactly as it does today.
        orElse: () => CustomerType.domestic,
      );
}

/// The customer's Construction Industry Scheme status.
///
/// Under CIS a contractor deducts tax from the **labour** element of a
/// subcontractor's invoice and pays it to HMRC on their behalf. Materials,
/// plant and VAT are never deducted from.
///
/// The rate depends on the *subcontractor's* registration with HMRC:
///   * gross payment status — 0%, paid in full
///   * registered           — 20%
///   * unregistered         — 30%
enum CisStatus {
  notApplicable('Not applicable', 0),
  gross('Gross payment status', 0),
  registered('Registered (20%)', 20),
  unregistered('Unregistered (30%)', 30);

  const CisStatus(this.label, this.ratePercent);

  final String label;
  final double ratePercent;

  bool get deducts => ratePercent > 0;

  /// Short form for chips and the invoice summary.
  String get shortLabel => switch (this) {
        CisStatus.notApplicable => 'No CIS',
        CisStatus.gross => 'CIS 0%',
        CisStatus.registered => 'CIS 20%',
        CisStatus.unregistered => 'CIS 30%',
      };

  static CisStatus fromName(String? name) => CisStatus.values.firstWhere(
        (CisStatus s) => s.name == name,
        orElse: () => CisStatus.notApplicable,
      );
}

/// What a line item is for.
///
/// Exists so CIS can deduct from labour without touching materials. It also
/// makes an invoice far more readable: a customer querying a bill wants to see
/// what was labour and what was materials.
enum LineCategory {
  labour('Labour', Icons.engineering_outlined, cisDeductible: true),
  materials('Materials', Icons.inventory_2_outlined),
  plant('Plant & hire', Icons.agriculture_outlined),
  subcontractor('Subcontractor', Icons.groups_outlined, cisDeductible: true),
  other('Other', Icons.more_horiz);

  const LineCategory(
    this.label,
    this.icon, {
    this.cisDeductible = false,
  });

  final String label;
  final IconData icon;

  /// Whether CIS is deducted from this category.
  ///
  /// Labour and subcontracted labour are deductible. Materials and plant hire
  /// (without an operator) are not — deducting from them would over-withhold
  /// and short-pay the subcontractor.
  final bool cisDeductible;

  Color get color => switch (this) {
        LineCategory.labour => AppColors.infoLight,
        LineCategory.materials => AppColors.successLight,
        LineCategory.plant => AppColors.warningLight,
        LineCategory.subcontractor => AppColors.seed,
        LineCategory.other => AppColors.neutralLight,
      };

  static LineCategory fromName(String? name) => LineCategory.values.firstWhere(
        (LineCategory c) => c.name == name,
        // Legacy line items are uncategorised. `other` is not CIS-deductible,
        // so an old invoice recalculates to exactly the same figure.
        orElse: () => LineCategory.other,
      );
}

/// The unit a price-list item is sold in.
enum PriceUnit {
  each('each', 'ea'),
  hour('per hour', 'hr'),
  day('per day', 'day'),
  squareMetre('per m²', 'm²'),
  linearMetre('per metre', 'm'),
  cubicMetre('per m³', 'm³'),
  tonne('per tonne', 't'),
  load('per load', 'load'),
  week('per week', 'wk'),
  item('per item', 'item');

  const PriceUnit(this.label, this.short);
  final String label;
  final String short;

  static PriceUnit fromName(String? name) => PriceUnit.values.firstWhere(
        (PriceUnit u) => u.name == name,
        orElse: () => PriceUnit.each,
      );
}

/// Lifecycle of a variation (extra work agreed after the job started).
enum VariationStatus {
  proposed('Proposed', 'Priced, waiting on the customer'),
  approved('Approved', 'Agreed — bill it with the job'),
  rejected('Rejected', 'Customer declined'),
  invoiced('Invoiced', 'Already billed');

  const VariationStatus(this.label, this.description);
  final String label;
  final String description;

  /// Approved work that has not yet been billed. This is the money builders
  /// most often lose.
  bool get isBillable => this == VariationStatus.approved;

  Color get color => switch (this) {
        VariationStatus.proposed => AppColors.warningLight,
        VariationStatus.approved => AppColors.infoLight,
        VariationStatus.rejected => AppColors.neutralLight,
        VariationStatus.invoiced => AppColors.successLight,
      };

  static VariationStatus fromName(String? name) =>
      VariationStatus.values.firstWhere(
        (VariationStatus s) => s.name == name,
        orElse: () => VariationStatus.proposed,
      );
}

/// Lifecycle of a scheduled payment stage.
enum StageStatus {
  pending('Not yet due'),
  due('Due now'),
  invoiced('Invoiced'),
  paid('Paid');

  const StageStatus(this.label);
  final String label;

  Color get color => switch (this) {
        StageStatus.pending => AppColors.neutralLight,
        StageStatus.due => AppColors.warningLight,
        StageStatus.invoiced => AppColors.infoLight,
        StageStatus.paid => AppColors.successLight,
      };

  static StageStatus fromName(String? name) => StageStatus.values.firstWhere(
        (StageStatus s) => s.name == name,
        orElse: () => StageStatus.pending,
      );
}

/// How firmly to chase an unpaid invoice.
enum ReminderStage {
  friendly(
    'Reminder',
    'A polite nudge',
    Icons.waving_hand_outlined,
  ),
  firm(
    'Second notice',
    'States how overdue it is',
    Icons.priority_high_rounded,
  ),
  finalNotice(
    'Final notice',
    'Formal, before further action',
    Icons.gavel_outlined,
  );

  const ReminderStage(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;

  Color get color => switch (this) {
        ReminderStage.friendly => AppColors.infoLight,
        ReminderStage.firm => AppColors.warningLight,
        ReminderStage.finalNotice => AppColors.dangerLight,
      };

  /// The suggested stage given how many days an invoice is overdue.
  static ReminderStage suggestedFor(int daysOverdue) {
    if (daysOverdue >= 30) return ReminderStage.finalNotice;
    if (daysOverdue >= 14) return ReminderStage.firm;
    return ReminderStage.friendly;
  }

  static ReminderStage fromName(String? name) =>
      ReminderStage.values.firstWhere(
        (ReminderStage s) => s.name == name,
        orElse: () => ReminderStage.friendly,
      );
}
