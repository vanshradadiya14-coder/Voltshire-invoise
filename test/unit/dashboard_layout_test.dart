import 'package:builder_crm/models/dashboard_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defaults', () {
    test('include every section, none hidden', () {
      expect(DashboardLayout.defaults.order.length,
          DashboardSection.values.length);
      expect(DashboardLayout.defaults.hidden, isEmpty);
      expect(DashboardLayout.defaults.visible.length,
          DashboardSection.values.length);
    });

    test('put the action centre near the top', () {
      // What needs doing should outrank what already happened.
      final int actions =
          DashboardLayout.defaults.order.indexOf(DashboardSection.actions);
      expect(actions, lessThan(3));
    });
  });

  group('visibility', () {
    test('toggling hides then shows a section', () {
      DashboardLayout l = DashboardLayout.defaults;
      expect(l.isVisible(DashboardSection.expenses), isTrue);

      l = l.toggle(DashboardSection.expenses);
      expect(l.isVisible(DashboardSection.expenses), isFalse);
      expect(l.visible, isNot(contains(DashboardSection.expenses)));

      l = l.toggle(DashboardSection.expenses);
      expect(l.isVisible(DashboardSection.expenses), isTrue);
    });

    test('locked sections cannot be hidden', () {
      expect(DashboardSection.actions.isLocked, isTrue);
      final DashboardLayout l =
          DashboardLayout.defaults.toggle(DashboardSection.actions);
      expect(l.isVisible(DashboardSection.actions), isTrue);
    });

    test('hiding preserves order for when it comes back', () {
      final DashboardLayout l =
          DashboardLayout.defaults.toggle(DashboardSection.cashFlow);
      expect(l.order.length, DashboardSection.values.length);
      expect(l.order, contains(DashboardSection.cashFlow));
    });
  });

  group('reordering', () {
    test('moving down accounts for the removed item', () {
      // ReorderableListView reports the target index before removal, so a
      // naive insert lands one place too far.
      final DashboardLayout l = DashboardLayout.defaults.reorder(0, 3);
      expect(l.order[2], DashboardLayout.defaults.order[0]);
      expect(l.order.length, DashboardSection.values.length);
    });

    test('moving up inserts at the reported index', () {
      final DashboardLayout l = DashboardLayout.defaults.reorder(3, 0);
      expect(l.order[0], DashboardLayout.defaults.order[3]);
    });

    test('no section is ever lost or duplicated', () {
      DashboardLayout l = DashboardLayout.defaults;
      for (final (int a, int b) in <(int, int)>[
        (0, 5), (4, 1), (9, 2), (2, 9), (1, 1)
      ]) {
        l = l.reorder(a, b);
      }
      expect(l.order.toSet().length, DashboardSection.values.length);
    });
  });

  group('persistence', () {
    test('round-trips through encode and decode', () {
      final DashboardLayout original = DashboardLayout.defaults
          .toggle(DashboardSection.expenses)
          .toggle(DashboardSection.topCustomers)
          .reorder(0, 4);

      final DashboardLayout restored = DashboardLayout.decode(
        original.encodeOrder(),
        original.encodeHidden(),
      );

      expect(restored.order, original.order);
      expect(restored.hidden, original.hidden);
    });

    test('missing preferences fall back to the defaults', () {
      final DashboardLayout l = DashboardLayout.decode(null, null);
      expect(l.order, DashboardLayout.defaults.order);
      expect(l.hidden, isEmpty);
    });

    test('a section added by a newer version is appended, not dropped', () {
      // Simulate a saved layout from an older build that predates the last
      // two sections. They must still appear, or an upgrade silently hides a
      // new feature.
      final List<DashboardSection> older =
          DashboardLayout.defaults.order.take(4).toList();
      final DashboardLayout l = DashboardLayout.decode(
        older.map((DashboardSection s) => s.name).join(','),
        '',
      );

      expect(l.order.length, DashboardSection.values.length);
      expect(l.order.take(4), older);
      for (final DashboardSection s in DashboardSection.values) {
        expect(l.order, contains(s));
      }
    });

    test('unknown section names in prefs are ignored', () {
      final DashboardLayout l =
          DashboardLayout.decode('hero,teleporter,actions', '');
      expect(l.order.first, DashboardSection.hero);
      expect(l.order.length, DashboardSection.values.length);
    });

    test('duplicates in prefs are collapsed', () {
      final DashboardLayout l =
          DashboardLayout.decode('hero,hero,actions,hero', '');
      expect(l.order.where((s) => s == DashboardSection.hero).length, 1);
    });

    test('a locked section persisted as hidden is ignored', () {
      final DashboardLayout l =
          DashboardLayout.decode(null, 'actions,expenses');
      expect(l.isVisible(DashboardSection.actions), isTrue);
      expect(l.isVisible(DashboardSection.expenses), isFalse);
    });
  });
}
