import 'package:builder_crm/core/utils/calculations.dart';
import 'package:builder_crm/models/line_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// The money maths is the highest-risk code in the app: an error here produces
/// an invoice that is wrong by a few pence, which a customer notices and an
/// accountant has to reconcile. These tests pin the exact behaviour.
void main() {
  group('Calc.round2', () {
    test('rounds to two decimal places', () {
      expect(Calc.round2(2.675), 2.68);
      expect(Calc.round2(1.0049), 1.0);
      expect(Calc.round2(1.006), 1.01);
    });

    test('kills floating-point drift', () {
      // The canonical example: 0.1 + 0.2 == 0.30000000000000004 in IEEE-754.
      expect(0.1 + 0.2 == 0.3, isFalse);
      expect(Calc.round2(0.1 + 0.2), 0.3);
    });

    test('rounds the double, not the decimal the literal looks like', () {
      // 1.005 cannot be represented exactly; the nearest double is slightly
      // BELOW it (1.00499999999999989...), so ×100 gives 100.49999999999999
      // and this rounds DOWN to 1.00.
      //
      // Pinned deliberately. Anyone "fixing" this to 1.01 must switch the
      // whole money layer to integer pence or Decimal — a change that has to
      // be made everywhere at once, or the editor, the stored document and
      // the PDF will stop agreeing.
      expect(Calc.round2(1.005), 1.00);
      expect(Calc.round2(-1.005), -1.00);
    });

    test('handles zero', () {
      expect(Calc.round2(0), 0);
    });

    test('survives values large enough for a real building job', () {
      expect(Calc.round2(1234567.891), 1234567.89);
    });
  });

  group('line maths', () {
    test('net is quantity times unit price', () {
      expect(Calc.lineNet(3, 250), 750);
      // 2.5 × 19.99 = 49.974999999999994 in binary floating point, so this
      // rounds to 49.97 rather than the 49.98 decimal arithmetic would give.
      expect(Calc.lineNet(2.5, 19.99), 49.97);
    });

    test('discount is a percentage of net', () {
      expect(Calc.lineDiscount(1, 100, 10), 10);
      expect(Calc.lineDiscount(4, 25, 50), 50);
      expect(Calc.lineDiscount(1, 100, 0), 0);
    });

    test('VAT is charged on the discounted net, not the gross', () {
      // £100 less 10% = £90 taxable; 20% VAT = £18, not £20.
      expect(Calc.lineNetAfterDiscount(1, 100, 10), 90);
      expect(Calc.lineVat(1, 100, 10, 20), 18);
      expect(Calc.lineTotal(1, 100, 10, 20), 108);
    });

    test('zero VAT and zero discount are handled', () {
      expect(Calc.lineTotal(2, 50, 0, 0), 100);
      expect(Calc.lineVat(2, 50, 0, 0), 0);
    });

    test('UK reduced rate of 5% works', () {
      expect(Calc.lineTotal(1, 200, 0, 5), 210);
    });

    test('a 100% discount produces a zero line', () {
      expect(Calc.lineNetAfterDiscount(1, 500, 100), 0);
      expect(Calc.lineVat(1, 500, 100, 20), 0);
      expect(Calc.lineTotal(1, 500, 100, 20), 0);
    });
  });

  group('clamps', () {
    test('clampPercent keeps values in 0..100', () {
      expect(Calc.clampPercent(-5), 0);
      expect(Calc.clampPercent(150), 100);
      expect(Calc.clampPercent(17.5), 17.5);
    });

    test('nonNegative floors at zero', () {
      expect(Calc.nonNegative(-10), 0);
      expect(Calc.nonNegative(10), 10);
    });
  });

  group('document totals', () {
    LineItem item(double qty, double price, {double disc = 0, double vat = 20}) =>
        LineItem(
          description: 'work',
          quantity: qty,
          unitPrice: price,
          discountPercent: disc,
          vatPercent: vat,
        );

    test('an empty document totals zero', () {
      final DocumentTotals t = <LineItem>[].totals;
      expect(t.subtotal, 0);
      expect(t.vatTotal, 0);
      expect(t.grandTotal, 0);
    });

    test('sums a realistic multi-line invoice', () {
      final DocumentTotals t = <LineItem>[
        item(1, 2500),          // groundworks
        item(40, 32.50),        // labour, 40 hrs
        item(1, 850, disc: 10), // materials, 10% trade discount
      ].totals;

      // 2500 + 1300 + 765 = 4565 net after discount
      expect(t.subtotal, closeTo(4565, 0.005));
      expect(t.discountTotal, closeTo(85, 0.005));
      expect(t.vatTotal, closeTo(913, 0.005));
      expect(t.grandTotal, closeTo(5478, 0.005));
    });

    test('grand total always equals subtotal plus VAT', () {
      final DocumentTotals t = <LineItem>[
        item(3, 19.99, disc: 7.5),
        item(1, 149.95, vat: 5),
        item(12, 8.33),
      ].totals;
      expect(t.grandTotal, closeTo(t.subtotal + t.vatTotal, 0.005));
    });

    test('mixed VAT rates are summed per line, not averaged', () {
      final DocumentTotals t = <LineItem>[
        item(1, 100, vat: 20), // 20 VAT
        item(1, 100, vat: 0),  // 0 VAT
      ].totals;
      expect(t.subtotal, 200);
      expect(t.vatTotal, 20);
      expect(t.grandTotal, 220);
    });

    test('rounding is applied per line so totals never drift', () {
      // Three lines that each round up; the total must match the sum of the
      // rounded lines, not the rounded sum of raw values.
      final List<LineItem> items = <LineItem>[
        item(1, 0.125, vat: 0),
        item(1, 0.125, vat: 0),
        item(1, 0.125, vat: 0),
      ];
      final DocumentTotals t = items.totals;
      final double lineSum = items.fold<double>(
        0,
        (double s, LineItem i) =>
            s + Calc.lineNetAfterDiscount(i.quantity, i.unitPrice, i.discountPercent),
      );
      expect(t.subtotal, closeTo(lineSum, 0.005));
    });
  });
}
