import 'package:flutter_test/flutter_test.dart';
import 'package:vz_food/features/storefront/domain/storefront_payload.dart';

void main() {
  group('StorefrontBranch.fromJson', () {
    test('parses ordering-availability fields when the branch is open', () {
      final branch = StorefrontBranch.fromJson({
        'id': 'branch-1',
        'name': 'Downtown',
        'isOpenNow': true,
        'acceptingOrders': true,
        'orderingMode': 'auto',
        'closureLabel': null,
        'nextTransitionAt': '2026-08-24T22:00:00.000Z',
        'nextTransitionLabel': 'Cierra a las 10:00 pm',
      });

      expect(branch.acceptingOrders, isTrue);
      expect(branch.isClosedForOrdering, isFalse);
      expect(
        branch.nextTransitionAt,
        DateTime.parse('2026-08-24T22:00:00.000Z'),
      );
      expect(branch.nextTransitionLabel, 'Cierra a las 10:00 pm');
    });

    test(
      'defaults acceptingOrders/isOpenNow to false when the backend omits them '
      'so an unrecognized branch payload fails closed instead of open',
      () {
        final branch = StorefrontBranch.fromJson({
          'id': 'branch-1',
          'name': 'Downtown',
        });

        expect(branch.acceptingOrders, isFalse);
        expect(branch.isOpenNow, isFalse);
        expect(branch.isClosedForOrdering, isTrue);
        expect(branch.orderingMode, 'auto');
        expect(branch.nextTransitionAt, isNull);
      },
    );

    test('ignores an unparsable nextTransitionAt instead of throwing', () {
      final branch = StorefrontBranch.fromJson({
        'id': 'branch-1',
        'name': 'Downtown',
        'nextTransitionAt': 'not-a-date',
      });

      expect(branch.nextTransitionAt, isNull);
    });

    test('carries the closureLabel through for a manually closed branch', () {
      final branch = StorefrontBranch.fromJson({
        'id': 'branch-1',
        'name': 'Downtown',
        'acceptingOrders': false,
        'orderingMode': 'manual',
        'closureLabel': 'Cerrado temporalmente por el administrador.',
      });

      expect(branch.isClosedForOrdering, isTrue);
      expect(branch.orderingMode, 'manual');
      expect(
        branch.closureLabel,
        'Cerrado temporalmente por el administrador.',
      );
    });
  });

  group('Storefront.fromJson', () {
    test('leaves activeBranch null when the backend does not send one', () {
      final storefront = Storefront.fromJson({
        'tenant': {'id': 't-1', 'name': 'Acme', 'slug': 'acme'},
        'branches': [],
      });

      expect(storefront.activeBranch, isNull);
      expect(storefront.branches, isEmpty);
      expect(storefront.hasMenu, isFalse);
    });

    test('parses activeBranch with its availability fields', () {
      final storefront = Storefront.fromJson({
        'tenant': {'id': 't-1', 'name': 'Acme', 'slug': 'acme'},
        'activeBranch': {
          'id': 'branch-1',
          'name': 'Downtown',
          'acceptingOrders': false,
          'closureLabel': 'Fuera de horario',
        },
      });

      expect(storefront.activeBranch, isNotNull);
      expect(storefront.activeBranch!.acceptingOrders, isFalse);
      expect(storefront.activeBranch!.closureLabel, 'Fuera de horario');
    });

    test(
      'groups menu items by category, falling back for blank categories',
      () {
        final storefront = Storefront.fromJson({
          'tenant': {'id': 't-1', 'name': 'Acme', 'slug': 'acme'},
          'menu': [
            {'id': 'p-1', 'name': 'Burger', 'category': 'Mains'},
            {'id': 'p-2', 'name': 'Fries', 'category': 'Mains'},
            {'id': 'p-3', 'name': 'Mystery item', 'category': '  '},
          ],
        });

        expect(storefront.hasMenu, isTrue);
        final grouped = storefront.menuByCategory;
        expect(grouped['Mains'], hasLength(2));
        expect(grouped['Sin categoria'], hasLength(1));
      },
    );
  });

  group('StorefrontProduct combo components', () {
    test('parses comboComponents and exposes isCombo', () {
      final product = StorefrontProduct.fromJson({
        'id': 'combo-1',
        'name': 'Combo Familiar',
        'comboComponents': [
          {
            'componentProductName': 'Papas',
            'componentVariantName': 'Grande',
            'quantity': 2,
          },
          {'componentProductName': 'Refresco', 'quantity': 1},
        ],
      });

      expect(product.isCombo, isTrue);
      expect(product.comboComponents.first.label, '2x Papas (Grande)');
      expect(product.comboComponents.last.label, '1x Refresco');
    });

    test('defaults comboComponents to empty for a regular product', () {
      final product = StorefrontProduct.fromJson({
        'id': 'p-1',
        'name': 'Hamburguesa',
      });

      expect(product.isCombo, isFalse);
      expect(product.comboComponents, isEmpty);
    });
  });
}
