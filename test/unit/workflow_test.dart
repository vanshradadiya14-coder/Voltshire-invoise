import 'package:builder_crm/core/flow/save_outcome.dart';
import 'package:builder_crm/models/customer.dart';
import 'package:builder_crm/models/line_item.dart';
import 'package:builder_crm/models/payment_stage.dart';
import 'package:builder_crm/models/price_item.dart';
import 'package:builder_crm/models/trade_enums.dart';
import 'package:builder_crm/models/variation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('save outcomes end the dead-ends', () {
    test('a new customer offers invoicing them first', () {
      const SaveOutcome outcome = SaveOutcome(
        kind: EntityKind.customer,
        id: 'c1',
        label: 'J. Smith',
        customerId: 'c1',
      );

      final List<NextStep> steps = outcome.nextSteps;
      expect(steps, isNotEmpty);
      // The whole point: creating a customer used to pop back to a list.
      expect(steps.first.label, 'Create invoice');
      expect(steps.first.isPrimary, isTrue);
      expect(steps.first.route, contains('customerId=c1'));
    });

    test('every customer next-step carries the new id through', () {
      const SaveOutcome outcome = SaveOutcome(
        kind: EntityKind.customer,
        id: 'c9',
        label: 'Acme',
        customerId: 'c9',
      );
      for (final NextStep s in outcome.nextSteps) {
        expect(s.route, contains('customerId=c9'),
            reason: '${s.label} must open pre-filled');
      }
    });

    test('a new job carries both its own id and the customer', () {
      const SaveOutcome outcome = SaveOutcome(
        kind: EntityKind.job,
        id: 'j1',
        label: 'Loft conversion',
        customerId: 'c1',
        jobId: 'j1',
      );

      final NextStep quote = outcome.nextSteps
          .firstWhere((NextStep s) => s.label.contains('Quote'));
      expect(quote.route, contains('jobId=j1'));
      expect(quote.route, contains('customerId=c1'));
    });

    test('a job offers photos and staged payments', () {
      const SaveOutcome outcome =
          SaveOutcome(kind: EntityKind.job, id: 'j2', label: 'Extension');
      final List<String> labels =
          outcome.nextSteps.map((NextStep s) => s.label).toList();
      expect(labels, contains('Add photos'));
      expect(labels.any((String l) => l.contains('staged payments')), isTrue);
    });

    test('a quote that already has a job does not offer to create one', () {
      const SaveOutcome withJob = SaveOutcome(
        kind: EntityKind.quote,
        id: 'q1',
        label: 'QT-000001',
        jobId: 'j1',
      );
      expect(
        withJob.nextSteps.any((NextStep s) => s.label == 'Create the job'),
        isFalse,
      );

      const SaveOutcome without =
          SaveOutcome(kind: EntityKind.quote, id: 'q2', label: 'QT-000002');
      expect(
        without.nextSteps.any((NextStep s) => s.label == 'Create the job'),
        isTrue,
      );
    });

    test('editing never interrupts with a workflow prompt', () {
      // Somebody fixing a typo does not want to be asked what to do next.
      for (final EntityKind kind in EntityKind.values) {
        final SaveOutcome edit =
            SaveOutcome(kind: kind, id: 'x', label: 'x', wasEdit: true);
        expect(edit.nextSteps, isEmpty, reason: '$kind');
        expect(edit.confirmation, contains('updated'));
      }
    });

    test('exactly one primary step is offered', () {
      for (final EntityKind kind in EntityKind.values) {
        final SaveOutcome outcome =
            SaveOutcome(kind: kind, id: 'x', label: 'x');
        final int primaries = outcome.nextSteps
            .where((NextStep s) => s.isPrimary)
            .length;
        expect(primaries, lessThanOrEqualTo(1), reason: '$kind');
      }
    });

    test('kinds with a detail screen resolve a route', () {
      expect(EntityKind.customer.detailRoute('c1'), '/customers/c1');
      expect(EntityKind.invoice.detailRoute('i1'), '/invoices/i1');
      // Expenses and payments have no detail screen; the flow must handle null
      // rather than navigating to a broken route.
      expect(EntityKind.expense.detailRoute('e1'), isNull);
      expect(EntityKind.payment.detailRoute('p1'), isNull);
    });
  });

  group('customer trade settings', () {
    test('a homeowner has no tax treatment', () {
      const Customer c = Customer(id: 'c', ownerId: 'o', name: 'Mrs Patel');
      expect(c.type, CustomerType.domestic);
      expect(c.cisStatus, CisStatus.notApplicable);
      expect(c.reverseCharge, isFalse);
      expect(c.hasTradeSettings, isFalse);
      expect(c.tradeSummary, 'Homeowner');
    });

    test('a contractor summarises its treatment', () {
      const Customer c = Customer(
        id: 'c',
        ownerId: 'o',
        name: 'Barratt',
        type: CustomerType.contractor,
        cisStatus: CisStatus.registered,
        reverseCharge: true,
      );
      expect(c.hasTradeSettings, isTrue);
      expect(c.tradeSummary, 'Contractor · CIS 20% · Reverse charge');
    });

    test('legacy documents decode to a homeowner with no deductions', () {
      // Every customer created before v2.1 has none of these fields.
      final Customer c = Customer.fromMap('c1', <String, dynamic>{
        'ownerId': 'o',
        'name': 'Old Record',
      });
      expect(c.type, CustomerType.domestic);
      expect(c.cisStatus, CisStatus.notApplicable);
      expect(c.reverseCharge, isFalse);
      expect(c.paymentTermsDays, isNull);
    });

    test('billing address falls back to the site address', () {
      const Customer c = Customer(
        id: 'c',
        ownerId: 'o',
        name: 'X',
        siteAddress: '12 Site Lane',
      );
      expect(c.invoiceAddress, '12 Site Lane');
    });
  });

  group('variations', () {
    Variation extra(double amount, VariationStatus status,
            {String? invoiceId}) =>
        Variation(
          id: 'v${amount.toInt()}',
          ownerId: 'o',
          jobId: 'j1',
          description: 'Extra',
          amount: amount,
          status: status,
          invoiceId: invoiceId,
        );

    test('net and gross are computed from quantity and VAT', () {
      const Variation v = Variation(
        id: 'v',
        ownerId: 'o',
        jobId: 'j',
        description: 'Move socket',
        amount: 120,
        quantity: 2,
        vatPercent: 20,
      );
      expect(v.netTotal, 240);
      expect(v.vatAmount, 48);
      expect(v.grossTotal, 288);
    });

    test('only approved-and-unbilled work counts as at risk', () {
      final List<Variation> list = <Variation>[
        extra(100, VariationStatus.proposed),
        extra(200, VariationStatus.approved),
        extra(300, VariationStatus.approved, invoiceId: 'inv1'),
        extra(400, VariationStatus.rejected),
        extra(500, VariationStatus.invoiced, invoiceId: 'inv2'),
      ];

      // The money most commonly lost: agreed, done, never billed.
      expect(list.unbilledNet, 200);
      expect(list.unbilled.length, 1);
      expect(list.proposedNet, 100);
      // Approved includes what has since been invoiced: the agreed 200, the
      // agreed-and-billed 300, and the 500 already invoiced.
      expect(list.approvedNet, 1000);
    });

    test('an approved variation with an invoice is no longer unbilled', () {
      expect(extra(200, VariationStatus.approved).isUnbilled, isTrue);
      expect(
        extra(200, VariationStatus.approved, invoiceId: 'i1').isUnbilled,
        isFalse,
      );
      expect(extra(200, VariationStatus.rejected).isUnbilled, isFalse);
    });

    test('converts to a line item labelled as a variation', () {
      const Variation v = Variation(
        id: 'v',
        ownerId: 'o',
        jobId: 'j',
        description: 'Extra socket',
        amount: 90,
        category: LineCategory.labour,
      );
      expect(v.toLineItem().description, 'Variation — Extra socket');
      expect(v.toLineItem().unitPrice, 90);
      expect(v.toLineItem().category, LineCategory.labour);
    });
  });

  group('payment stages', () {
    PaymentStage stage(String label, double pct, int order,
            {String? invoiceId}) =>
        PaymentStage(
          id: label,
          ownerId: 'o',
          jobId: 'j1',
          label: label,
          percent: pct,
          order: order,
          invoiceId: invoiceId,
        );

    test('a percentage stage is worked out against the job value', () {
      expect(stage('Deposit', 50, 0).amountFor(10000), 5000);
      expect(stage('Deposit', 40, 0).amountFor(2500), 1000);
    });

    test('a fixed stage ignores the job value', () {
      const PaymentStage s = PaymentStage(
        id: 's',
        ownerId: 'o',
        jobId: 'j',
        label: 'Deposit',
        fixedAmount: 750,
      );
      expect(s.amountFor(10000), 750);
      expect(s.amountFor(0), 750);
      expect(s.isPercentage, isFalse);
    });

    test('tracks what is billed and what is left', () {
      final List<PaymentStage> stages = <PaymentStage>[
        stage('Deposit', 50, 0, invoiceId: 'inv1'),
        stage('Completion', 50, 1),
      ];
      expect(stages.billedAgainst(8000), 4000);
      expect(stages.remainingAgainst(8000), 4000);
      expect(stages.nextUnbilled?.label, 'Completion');
    });

    test('flags a schedule that does not add up to 100%', () {
      expect(
        <PaymentStage>[stage('A', 50, 0), stage('B', 50, 1)]
            .percentagesBalance,
        isTrue,
      );
      // Would under-bill the job by 20%.
      expect(
        <PaymentStage>[stage('A', 50, 0), stage('B', 30, 1)]
            .percentagesBalance,
        isFalse,
      );
      expect(
        <PaymentStage>[stage('A', 60, 0), stage('B', 60, 1)].percentageTotal,
        120,
      );
    });

    test('orders by position regardless of insertion order', () {
      final List<PaymentStage> stages = <PaymentStage>[
        stage('Third', 25, 2),
        stage('First', 25, 0),
        stage('Second', 25, 1),
      ];
      expect(
        stages.ordered.map((PaymentStage s) => s.label).toList(),
        <String>['First', 'Second', 'Third'],
      );
    });

    test('every preset adds up to exactly 100%', () {
      for (final StagePreset p in StagePreset.values) {
        final double total = p.stages.fold<double>(
          0,
          (double s, ({String label, double percent}) x) => s + x.percent,
        );
        expect(total, 100, reason: '${p.label} must not over- or under-bill');
      }
    });

    test('every preset starts with a deposit', () {
      for (final StagePreset p in StagePreset.values) {
        expect(p.stages.first.label.toLowerCase(), contains('deposit'),
            reason: p.label);
      }
    });
  });

  group('price list', () {
    test('copies onto a line item without linking to it', () {
      const PriceItem p = PriceItem(
        id: 'p1',
        ownerId: 'o',
        description: 'Labour — day rate',
        unitPrice: 280,
        unit: PriceUnit.day,
        category: LineCategory.labour,
        vatPercent: 20,
        defaultQuantity: 2,
      );

      final LineItem line = p.toLineItem();
      expect(line.description, 'Labour — day rate');
      expect(line.unitPrice, 280);
      expect(line.quantity, 2);
      expect(line.category, LineCategory.labour);
      expect(line.unit, PriceUnit.day);
      // A copy, not a reference: editing the saved price later must never
      // rewrite what a customer was already billed.
      expect(line.total, 672); // (2 × 280) + 20% VAT
    });

    test('an explicit quantity overrides the default', () {
      const PriceItem p = PriceItem(
        id: 'p',
        ownerId: 'o',
        description: 'Skip',
        unitPrice: 320,
        defaultQuantity: 1,
      );
      expect(p.toLineItem(quantity: 3).quantity, 3);
    });

    test('can be saved back from a line the builder typed', () {
      // "Save this for next time" straight off an invoice.
      const PriceItem p = PriceItem(
        id: '',
        ownerId: '',
        description: 'Scaffold',
        unitPrice: 180,
        unit: PriceUnit.week,
        category: LineCategory.plant,
      );
      final PriceItem round = PriceItem.fromLineItem(p.toLineItem());
      expect(round.description, 'Scaffold');
      expect(round.unitPrice, 180);
      expect(round.unit, PriceUnit.week);
      expect(round.category, LineCategory.plant);
    });

    test('search text covers description and category', () {
      const PriceItem p = PriceItem(
        id: 'p',
        ownerId: 'o',
        description: 'Plasterboard 12.5mm',
        category: LineCategory.materials,
      );
      expect(p.searchText, contains('plasterboard'));
      expect(p.searchText, contains('materials'));
    });

    test('the starter list covers every category a builder uses', () {
      final Set<LineCategory> covered = PriceItemSeeds.defaults
          .map((({String description, double price, PriceUnit unit,
                  LineCategory category, double qty}) s) =>
              s.category)
          .toSet();
      expect(covered, contains(LineCategory.labour));
      expect(covered, contains(LineCategory.materials));
      expect(covered, contains(LineCategory.plant));
      expect(PriceItemSeeds.defaults.length, greaterThan(15));
    });
  });
}
