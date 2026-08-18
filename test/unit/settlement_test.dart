import 'package:builder_crm/core/utils/settlement.dart';
import 'package:builder_crm/models/line_item.dart';
import 'package:builder_crm/models/trade_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// CIS and the VAT reverse charge change what a customer actually pays. Getting
/// either wrong means under- or over-billing a contractor, which is a real
/// financial and compliance problem — so every branch is pinned here.
void main() {
  LineItem labour(double amount, {double vat = 20}) => LineItem(
        description: 'Labour',
        quantity: 1,
        unitPrice: amount,
        vatPercent: vat,
        category: LineCategory.labour,
      );

  LineItem materials(double amount, {double vat = 20}) => LineItem(
        description: 'Materials',
        quantity: 1,
        unitPrice: amount,
        vatPercent: vat,
        category: LineCategory.materials,
      );

  group('no tax treatment — behaves exactly as before', () {
    test('reduces to subtotal + VAT', () {
      final Settlement s = Settlement.of(<LineItem>[
        labour(1000),
        materials(500),
      ]);

      expect(s.subtotal, 1500);
      expect(s.vatCharged, 300);
      expect(s.cisDeduction, 0);
      expect(s.amountDue, 1800);
      expect(s.grossTotal, 1800);
      expect(s.isAdjusted, isFalse);
      expect(s.reverseChargeApplies, isFalse);
    });

    test('an empty document settles to zero, not NaN', () {
      final Settlement s = Settlement.of(const <LineItem>[]);
      expect(s.subtotal, 0);
      expect(s.amountDue, 0);
      expect(s.grossTotal, 0);
    });

    test('uncategorised legacy lines are never CIS-deducted', () {
      // Documents written before categories existed decode to `other`, which
      // must not be treated as labour or their value would change.
      const LineItem legacy = LineItem(
        description: 'Work',
        quantity: 1,
        unitPrice: 1000,
        vatPercent: 20,
      );
      expect(legacy.category, LineCategory.other);

      final Settlement s = Settlement.of(
        <LineItem>[legacy],
        cis: CisStatus.registered,
      );
      expect(s.labourNet, 0);
      expect(s.materialsNet, 1000);
      expect(s.cisDeduction, 0);
      expect(s.amountDue, 1200);
    });
  });

  group('CIS', () {
    test('deducts 20% from labour only', () {
      final Settlement s = Settlement.of(
        <LineItem>[labour(1000), materials(500)],
        cis: CisStatus.registered,
      );

      expect(s.labourNet, 1000);
      expect(s.materialsNet, 500);
      expect(s.subtotal, 1500);
      expect(s.vatCharged, 300);
      // 20% of labour only — never of materials, never of VAT.
      expect(s.cisDeduction, 200);
      expect(s.amountDue, 1600); // 1500 + 300 − 200
      // The work was still worth £1,800; £200 just went to HMRC.
      expect(s.grossTotal, 1800);
      expect(s.hasCis, isTrue);
    });

    test('deducts 30% for an unregistered subcontractor', () {
      final Settlement s = Settlement.of(
        <LineItem>[labour(1000), materials(500)],
        cis: CisStatus.unregistered,
      );
      expect(s.cisDeduction, 300);
      expect(s.amountDue, 1500);
    });

    test('gross payment status deducts nothing', () {
      final Settlement s = Settlement.of(
        <LineItem>[labour(1000), materials(500)],
        cis: CisStatus.gross,
      );
      expect(s.cisDeduction, 0);
      expect(s.amountDue, 1800);
      expect(s.hasCis, isFalse);
    });

    test('subcontracted labour is deductible, plant is not', () {
      final Settlement s = Settlement.of(
        <LineItem>[
          const LineItem(
            description: 'Subbie',
            unitPrice: 800,
            vatPercent: 20,
            category: LineCategory.subcontractor,
          ),
          const LineItem(
            description: 'Digger hire',
            unitPrice: 200,
            vatPercent: 20,
            category: LineCategory.plant,
          ),
        ],
        cis: CisStatus.registered,
      );
      expect(s.labourNet, 800);
      expect(s.materialsNet, 200);
      expect(s.cisDeduction, 160);
    });

    test('deducts from the discounted net, not the headline price', () {
      final Settlement s = Settlement.of(
        <LineItem>[
          const LineItem(
            description: 'Labour',
            quantity: 1,
            unitPrice: 1000,
            discountPercent: 10,
            vatPercent: 20,
            category: LineCategory.labour,
          ),
        ],
        cis: CisStatus.registered,
      );
      expect(s.labourNet, 900);
      expect(s.cisDeduction, 180); // 20% of 900, not of 1000
    });

    test('a labour-only invoice deducts from the whole subtotal', () {
      final Settlement s = Settlement.of(
        <LineItem>[labour(2000)],
        cis: CisStatus.registered,
      );
      expect(s.cisDeduction, 400);
      expect(s.amountDue, 2000); // 2000 + 400 VAT − 400 CIS
    });

    test('amount due never goes negative', () {
      // Pathological, but a 30% deduction on zero-VAT labour must not produce
      // a negative bill.
      final Settlement s = Settlement.of(
        <LineItem>[labour(100, vat: 0)],
        cis: CisStatus.unregistered,
      );
      expect(s.amountDue, 70);
      expect(s.amountDue, greaterThanOrEqualTo(0));
    });
  });

  group('VAT domestic reverse charge', () {
    test('charges no VAT but still reports what the customer must account for',
        () {
      final Settlement s = Settlement.of(
        <LineItem>[labour(1000), materials(500)],
        reverseCharge: true,
      );

      expect(s.subtotal, 1500);
      expect(s.vatCharged, 0);
      // The customer pays this to HMRC directly; the invoice must state it.
      expect(s.vatReverseCharged, 300);
      expect(s.amountDue, 1500);
      expect(s.reverseChargeApplies, isTrue);
      expect(s.isAdjusted, isTrue);
    });

    test('combines with CIS', () {
      // The common real case: a subbie invoicing a main contractor.
      final Settlement s = Settlement.of(
        <LineItem>[labour(1000), materials(500)],
        cis: CisStatus.registered,
        reverseCharge: true,
      );

      expect(s.subtotal, 1500);
      expect(s.vatCharged, 0);
      expect(s.vatReverseCharged, 300);
      expect(s.cisDeduction, 200);
      expect(s.amountDue, 1300); // 1500 + 0 − 200
      expect(s.grossTotal, 1500);
    });

    test('carries the statutory wording HMRC requires', () {
      expect(Settlement.reverseChargeNotice, contains('Section 55A'));
      expect(Settlement.reverseChargeNotice, contains('account for the VAT'));
    });
  });

  group('rounding', () {
    test('an awkward split still balances', () {
      final Settlement s = Settlement.of(
        <LineItem>[
          const LineItem(
            description: 'Labour',
            quantity: 3,
            unitPrice: 33.33,
            vatPercent: 20,
            category: LineCategory.labour,
          ),
          const LineItem(
            description: 'Materials',
            quantity: 7,
            unitPrice: 12.49,
            vatPercent: 20,
            category: LineCategory.materials,
          ),
        ],
        cis: CisStatus.registered,
      );

      expect(s.subtotal, closeTo(s.labourNet + s.materialsNet, 0.005));
      expect(
        s.amountDue,
        closeTo(s.subtotal + s.vatCharged - s.cisDeduction, 0.005),
      );
    });

    test('grossTotal is always subtotal plus VAT charged', () {
      for (final CisStatus cis in CisStatus.values) {
        for (final bool rc in <bool>[true, false]) {
          final Settlement s = Settlement.of(
            <LineItem>[labour(777.77), materials(333.33)],
            cis: cis,
            reverseCharge: rc,
          );
          expect(
            s.grossTotal,
            closeTo(s.subtotal + s.vatCharged, 0.005),
            reason: 'cis=$cis rc=$rc',
          );
        }
      }
    });
  });

  group('late payment (Late Payment of Commercial Debts (Interest) Act 1998)',
      () {
    test('statutory rate is base + 8%', () {
      expect(LatePayment.annualRate(baseRate: 4), 12);
      expect(LatePayment.annualRate(baseRate: 5.25), 13.25);
    });

    test('interest accrues daily', () {
      // £10,000 at 12% for a year.
      final double year = LatePayment.interestOn(10000, 365, baseRate: 4);
      expect(year, closeTo(1200, 0.5));

      final double month = LatePayment.interestOn(10000, 30, baseRate: 4);
      expect(month, closeTo(1200 * 30 / 365, 0.5));
    });

    test('nothing accrues before the due date', () {
      expect(LatePayment.interestOn(5000, 0), 0);
      expect(LatePayment.interestOn(5000, -10), 0);
      expect(LatePayment.interestOn(0, 60), 0);
    });

    test('fixed compensation is banded by debt size', () {
      expect(LatePayment.compensationFor(500), 40);
      expect(LatePayment.compensationFor(999.99), 40);
      expect(LatePayment.compensationFor(1000), 70);
      expect(LatePayment.compensationFor(9999), 70);
      expect(LatePayment.compensationFor(10000), 100);
      expect(LatePayment.compensationFor(50000), 100);
    });

    test('a claim totals principal, interest and compensation', () {
      final LatePaymentClaim claim =
          LatePayment.claimFor(5000, 60, baseRate: 4);
      expect(claim.principal, 5000);
      expect(claim.compensation, 70);
      expect(claim.interest, greaterThan(0));
      expect(
        claim.total,
        closeTo(5000 + claim.interest + 70, 0.01),
      );
      expect(claim.hasClaim, isTrue);
    });

    test('an invoice that is not late has nothing to claim', () {
      final LatePaymentClaim claim = LatePayment.claimFor(5000, 0);
      expect(claim.interest, 0);
      expect(claim.compensation, 0);
      expect(claim.hasClaim, isFalse);
      expect(claim.total, 5000);
    });
  });

  group('reminder escalation', () {
    test('gets firmer the later it gets', () {
      expect(ReminderStage.suggestedFor(1), ReminderStage.friendly);
      expect(ReminderStage.suggestedFor(13), ReminderStage.friendly);
      expect(ReminderStage.suggestedFor(14), ReminderStage.firm);
      expect(ReminderStage.suggestedFor(29), ReminderStage.firm);
      expect(ReminderStage.suggestedFor(30), ReminderStage.finalNotice);
      expect(ReminderStage.suggestedFor(200), ReminderStage.finalNotice);
    });
  });
}
