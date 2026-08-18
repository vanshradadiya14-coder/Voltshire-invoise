import '../../models/line_item.dart';
import '../../models/trade_enums.dart';
import 'calculations.dart';

/// What a customer actually has to pay, after UK construction tax rules.
///
/// A plain invoice total is `subtotal + VAT`. For UK construction that is often
/// wrong in two ways at once:
///
///  * **CIS** — a contractor withholds tax from the *labour* element and pays
///    it to HMRC on the subcontractor's behalf. It reduces what lands in the
///    bank but not what was earned.
///  * **VAT domestic reverse charge** — for construction services between
///    VAT-registered businesses where the customer is not the end user, the
///    supplier charges no VAT at all; the customer accounts for it directly.
///
/// Both are properties of the *customer relationship*, so they are configured
/// once on the customer and applied automatically to every document.
class Settlement {
  const Settlement({
    required this.labourNet,
    required this.materialsNet,
    required this.subtotal,
    required this.discountTotal,
    required this.vatCharged,
    required this.vatReverseCharged,
    required this.cisRate,
    required this.cisDeduction,
    required this.amountDue,
    required this.reverseChargeApplies,
  });

  /// Net value of CIS-deductible lines (labour, subcontracted labour), after
  /// discount and excluding VAT.
  final double labourNet;

  /// Net value of everything else — materials, plant, other.
  final double materialsNet;

  /// labourNet + materialsNet.
  final double subtotal;

  final double discountTotal;

  /// VAT actually charged on this invoice. Zero under reverse charge.
  final double vatCharged;

  /// VAT the *customer* must account for to HMRC. Non-zero only under reverse
  /// charge. It is shown on the invoice but is not part of what they pay us.
  final double vatReverseCharged;

  final double cisRate;

  /// Tax withheld by the contractor: labourNet × cisRate.
  final double cisDeduction;

  /// The figure the customer transfers.
  final double amountDue;

  final bool reverseChargeApplies;

  static const Settlement zero = Settlement(
    labourNet: 0,
    materialsNet: 0,
    subtotal: 0,
    discountTotal: 0,
    vatCharged: 0,
    vatReverseCharged: 0,
    cisRate: 0,
    cisDeduction: 0,
    amountDue: 0,
    reverseChargeApplies: false,
  );

  bool get hasCis => cisDeduction > 0.005;

  /// True when the settlement differs from a plain `subtotal + VAT`, and the
  /// UI should therefore show the full breakdown rather than a single total.
  bool get isAdjusted => hasCis || reverseChargeApplies;

  /// The gross value of the work — what was earned, before CIS is withheld.
  /// This is the figure that belongs in revenue reporting, not [amountDue].
  double get grossTotal => Calc.round2(subtotal + vatCharged);

  /// Computes the settlement for a set of line items.
  ///
  /// With no CIS and no reverse charge this reduces exactly to
  /// `subtotal + VAT`, so existing invoices are unaffected.
  factory Settlement.of(
    List<LineItem> items, {
    CisStatus cis = CisStatus.notApplicable,
    bool reverseCharge = false,
  }) {
    double labour = 0;
    double materials = 0;
    double discount = 0;
    double vat = 0;

    for (final LineItem item in items) {
      final double net = item.netAfterDiscount;
      discount += item.discountAmount;
      vat += item.vatAmount;

      if (item.category.cisDeductible) {
        labour += net;
      } else {
        materials += net;
      }
    }

    labour = Calc.round2(labour);
    materials = Calc.round2(materials);
    discount = Calc.round2(discount);
    vat = Calc.round2(vat);

    final double subtotal = Calc.round2(labour + materials);

    // Under the reverse charge the supplier charges nothing; the customer
    // accounts for the same amount directly to HMRC. The invoice still has to
    // state the figure, so it is kept — just moved to the other column.
    final double vatCharged = reverseCharge ? 0 : vat;
    final double vatReverse = reverseCharge ? vat : 0;

    // CIS is deducted from labour only, and always from the net (ex-VAT) value.
    final double rate = cis.ratePercent;
    final double deduction =
        rate <= 0 ? 0 : Calc.round2(labour * (rate / 100));

    final double due =
        Calc.round2(Calc.nonNegative(subtotal + vatCharged - deduction));

    return Settlement(
      labourNet: labour,
      materialsNet: materials,
      subtotal: subtotal,
      discountTotal: discount,
      vatCharged: vatCharged,
      vatReverseCharged: vatReverse,
      cisRate: rate,
      cisDeduction: deduction,
      amountDue: due,
      reverseChargeApplies: reverseCharge,
    );
  }

  /// The statutory wording HMRC requires on a reverse-charge invoice.
  ///
  /// The exact phrasing is not decorative — an invoice missing it is not a
  /// valid reverse-charge invoice.
  static const String reverseChargeNotice =
      'Reverse charge: VAT Act 1994 Section 55A applies. '
      'Customer to account for the VAT to HMRC.';

  static const String cisNotice =
      'CIS deduction withheld and paid to HMRC by the contractor.';
}

/// Statutory late-payment entitlement under the Late Payment of Commercial
/// Debts (Interest) Act 1998.
///
/// **Business-to-business only.** A domestic customer is not covered, so the
/// final-notice template must never quote this at a homeowner — it would be a
/// legally meaningless threat.
class LatePayment {
  const LatePayment._();

  /// Statutory interest is the Bank of England base rate plus 8%.
  ///
  /// The base rate moves, so it is a parameter rather than a constant. The
  /// default reflects a mid-2026 base rate and should be confirmed against
  /// bankofengland.co.uk before relying on a figure in a formal notice.
  static const double defaultBaseRate = 4.0;
  static const double statutorySurcharge = 8.0;

  static double annualRate({double baseRate = defaultBaseRate}) =>
      baseRate + statutorySurcharge;

  /// Interest accrued on an overdue debt, calculated daily.
  static double interestOn(
    double amount,
    int daysOverdue, {
    double baseRate = defaultBaseRate,
  }) {
    if (amount <= 0 || daysOverdue <= 0) return 0;
    final double rate = annualRate(baseRate: baseRate) / 100;
    return Calc.round2(amount * rate * (daysOverdue / 365));
  }

  /// Fixed compensation a creditor may claim, banded by debt size.
  /// This is in addition to interest and does not accrue.
  static double compensationFor(double debt) {
    if (debt < 1000) return 40;
    if (debt < 10000) return 70;
    return 100;
  }

  /// Everything claimable on an overdue commercial debt.
  static LatePaymentClaim claimFor(
    double amount,
    int daysOverdue, {
    double baseRate = defaultBaseRate,
  }) {
    final double interest =
        interestOn(amount, daysOverdue, baseRate: baseRate);
    final double compensation =
        daysOverdue > 0 ? compensationFor(amount) : 0;
    return LatePaymentClaim(
      principal: amount,
      interest: interest,
      compensation: compensation,
      daysOverdue: daysOverdue,
      annualRatePercent: annualRate(baseRate: baseRate),
    );
  }
}

class LatePaymentClaim {
  const LatePaymentClaim({
    required this.principal,
    required this.interest,
    required this.compensation,
    required this.daysOverdue,
    required this.annualRatePercent,
  });

  final double principal;
  final double interest;
  final double compensation;
  final int daysOverdue;
  final double annualRatePercent;

  double get total => Calc.round2(principal + interest + compensation);
  bool get hasClaim => interest > 0 || compensation > 0;
}
