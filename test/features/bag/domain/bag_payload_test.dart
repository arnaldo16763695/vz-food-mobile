import 'package:flutter_test/flutter_test.dart';
import 'package:vz_food/features/bag/domain/bag_payload.dart';

void main() {
  group('BagPayload.fromJson', () {
    test('parses items from a well-formed payload', () {
      final payload = BagPayload.fromJson({
        'items': [
          {
            'id': 'item-1',
            'productId': 'product-1',
            'tenantSlug': 'acme',
            'branchId': 'branch-1',
            'name': 'Burger',
            'description': 'Beef burger',
            'category': 'Mains',
            'unitPrice': 9.5,
            'unitPriceLabel': '\$9.50',
            'quantity': 2,
            'modifierSelections': [
              {
                'modifierGroupId': 'group-1',
                'modifierGroupName': 'Extras',
                'modifierOptionId': 'option-1',
                'modifierOptionName': 'Cheese',
                'priceDelta': 1.5,
              },
            ],
          },
        ],
      });

      expect(payload.items, hasLength(1));
      final item = payload.items.single;
      expect(item.id, 'item-1');
      expect(item.unitPrice, 9.5);
      expect(item.quantity, 2);
      expect(item.modifierSelections.single.modifierOptionName, 'Cheese');
      expect(payload.isEmpty, isFalse);
    });

    test('defaults to an empty list when items is missing or not a list', () {
      expect(BagPayload.fromJson(const {}).items, isEmpty);
      expect(BagPayload.fromJson({'items': 'not-a-list'}).items, isEmpty);
      expect(BagPayload.fromJson(const {}).isEmpty, isTrue);
    });

    test('drops list entries that are not JSON objects', () {
      final payload = BagPayload.fromJson({
        'items': [
          'not-a-map',
          {'id': 'item-1'},
        ],
      });

      expect(payload.items, hasLength(1));
      expect(payload.items.single.id, 'item-1');
    });

    test('fills missing numeric/string fields with safe defaults', () {
      final item = BagPayload.fromJson({
        'items': [<String, dynamic>{}],
      }).items.single;

      expect(item.id, '');
      expect(item.unitPrice, 0);
      expect(item.quantity, 0);
      expect(item.modifierSelections, isEmpty);
      expect(item.productVariantId, isNull);
    });
  });

  group('BagPayload.copyWith', () {
    test('replaces items when provided', () {
      const original = BagPayload(items: []);
      final replacement = [_sampleItem(quantity: 3)];

      final updated = original.copyWith(items: replacement);

      expect(updated.items, replacement);
    });

    test('keeps existing items when items is omitted', () {
      final original = BagPayload(items: [_sampleItem(quantity: 1)]);

      final updated = original.copyWith();

      expect(updated.items, original.items);
    });
  });

  group('BagItem.copyWith', () {
    test('overrides quantity and keeps every other field', () {
      final item = _sampleItem(quantity: 1);

      final updated = item.copyWith(quantity: 5);

      expect(updated.quantity, 5);
      expect(updated.id, item.id);
      expect(updated.name, item.name);
      expect(updated.modifierSelections, item.modifierSelections);
    });

    test('keeps the original quantity when none is provided', () {
      final item = _sampleItem(quantity: 4);

      final updated = item.copyWith();

      expect(updated.quantity, 4);
    });
  });
}

BagItem _sampleItem({required int quantity}) {
  return BagItem(
    id: 'item-1',
    productId: 'product-1',
    productVariantId: null,
    variantName: null,
    tenantSlug: 'acme',
    branchId: 'branch-1',
    name: 'Burger',
    description: 'Beef burger',
    category: 'Mains',
    unitPrice: 9.5,
    unitPriceLabel: '\$9.50',
    quantity: quantity,
    modifierSelections: const [],
  );
}
