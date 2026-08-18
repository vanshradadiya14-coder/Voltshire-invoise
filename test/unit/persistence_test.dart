import 'package:builder_crm/models/customer.dart';
import 'package:builder_crm/models/invoice.dart';
import 'package:builder_crm/models/line_item.dart';
import 'package:builder_crm/models/trade_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// These lock in the "create must not drop fields" contract.
///
/// Both repositories used to rebuild the model field by field before writing
/// it, which silently discarded anything not listed — the customer's whole
/// trade/tax setup, and an invoice's CIS status and payment-stage link. The
/// repositories now copyWith, so a newly added field is preserved by default.
/// A round-trip through toMap/fromMap proves the field actually persists.
void main() {
  group('customer persistence', () {
    const Customer configured = Customer(
      id: 'c1',
      ownerId: 'u1',
      name: 'Hetal',
      type: CustomerType.contractor,
      cisStatus: CisStatus.registered,
      reverseCharge: true,
      vatNumber: 'GB123456789',
      companyNumber: '16857630',
      contactName: 'Site manager',
      paymentTermsDays: 7,
    );

    test('copyWith can assign the server-side identity fields', () {
      final Customer saved = configured.copyWith(
        id: 'generated',
        ownerId: 'owner',
        createdAt: DateTime(2026, 8, 19),
      );
      expect(saved.id, 'generated');
      expect(saved.ownerId, 'owner');
      expect(saved.createdAt, DateTime(2026, 8, 19));
    });

    test('copyWith keeps every trade field the create path used to drop', () {
      final Customer saved = configured.copyWith(id: 'x', ownerId: 'y');
      expect(saved.type, CustomerType.contractor);
      expect(saved.cisStatus, CisStatus.registered);
      expect(saved.reverseCharge, isTrue);
      expect(saved.vatNumber, 'GB123456789');
      expect(saved.companyNumber, '16857630');
      expect(saved.contactName, 'Site manager');
      expect(saved.paymentTermsDays, 7);
    });

    test('trade settings survive a Firestore round trip', () {
      final Customer back = Customer.fromMap('c1', configured.toMap());
      expect(back.cisStatus, CisStatus.registered);
      expect(back.reverseCharge, isTrue);
      expect(back.type, CustomerType.contractor);
      expect(back.paymentTermsDays, 7);
    });
  });

  group('invoice persistence', () {
    const Invoice configured = Invoice(
      id: 'i1',
      ownerId: 'u1',
      number: 18,
      numberFormatted: 'INV-000018',
      customerId: 'c1',
      customerName: 'Hetal',
      items: <LineItem>[
        LineItem(
          description: 'Labour',
          unitPrice: 1000,
          vatPercent: 20,
          category: LineCategory.labour,
        ),
      ],
      cisStatus: CisStatus.registered,
      reverseCharge: true,
      stageId: 's1',
      stageLabel: 'First fix',
    );

    test('copyWith keeps CIS, reverse charge and the stage link', () {
      final Invoice saved = configured.copyWith(
        id: 'generated',
        ownerId: 'owner',
        number: 19,
        numberFormatted: 'INV-000019',
        createdAt: DateTime(2026, 8, 19),
      );
      expect(saved.id, 'generated');
      expect(saved.number, 19);
      expect(saved.cisStatus, CisStatus.registered);
      expect(saved.reverseCharge, isTrue);
      expect(saved.stageId, 's1');
      expect(saved.stageLabel, 'First fix');
    });

    test('tax treatment survives a Firestore round trip', () {
      final Invoice back = Invoice.fromMap('i1', configured.toMap());
      expect(back.cisStatus, CisStatus.registered);
      expect(back.reverseCharge, isTrue);
      expect(back.stageId, 's1');
    });

    test('dropping CIS would change what the customer owes', () {
      // Guards the money, not just the field: 20% CIS on £1000 of labour.
      final Invoice withoutCis =
          configured.copyWith(cisStatus: CisStatus.notApplicable);
      expect(configured.settlement.cisDeduction, 200);
      expect(withoutCis.settlement.cisDeduction, 0);
      expect(configured.amountDue, isNot(withoutCis.amountDue));
    });
  });
}
