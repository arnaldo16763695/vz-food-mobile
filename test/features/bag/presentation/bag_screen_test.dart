import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vz_food/core/auth/auth_session.dart';
import 'package:vz_food/features/bag/application/bag_count_controller.dart';
import 'package:vz_food/features/bag/domain/bag_payload.dart';
import 'package:vz_food/features/bag/infrastructure/bag_api.dart';
import 'package:vz_food/features/bag/presentation/bag_screen.dart';
import 'package:vz_food/features/storefront/domain/storefront_payload.dart';
import 'package:vz_food/features/storefront/infrastructure/storefront_api.dart';

// This suite locks in the "branch not accepting orders" gating added to the
// bag screen: quantity controls, remove, and checkout must all become
// unreachable (disabled), not just visually muted, whenever the active
// branch reports acceptingOrders == false.

class _MockBagApi extends Mock implements BagApi {}

class _MockStorefrontApi extends Mock implements StorefrontApi {}

class _MockAuthSession extends Mock implements AuthSession {}

const _tenantSlug = 'acme';
const _branchId = 'branch-1';
const _accessToken = 'token-1';

BagPayload _bagWithOneItem() {
  return BagPayload.fromJson({
    'items': [
      {
        'id': 'item-1',
        'productId': 'product-1',
        'tenantSlug': _tenantSlug,
        'branchId': _branchId,
        'name': 'Burger',
        'description': 'Beef burger',
        'category': 'Mains',
        'unitPrice': 9.5,
        'unitPriceLabel': '\$9.50',
        'quantity': 2,
      },
    ],
  });
}

StorefrontPayload _storefrontWithBranch({
  required bool acceptingOrders,
  String? closureLabel,
}) {
  return StorefrontPayload.fromJson({
    'storefront': {
      'tenant': {'id': 't-1', 'name': 'Acme', 'slug': _tenantSlug},
      'activeBranch': {
        'id': _branchId,
        'name': 'Downtown',
        'acceptingOrders': acceptingOrders,
        'closureLabel': closureLabel,
      },
    },
  });
}

Future<void> _pumpBagScreen(
  WidgetTester tester, {
  required _MockBagApi bagApi,
  required _MockStorefrontApi storefrontApi,
  required _MockAuthSession authSession,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BagScreen(
        bagApi: bagApi,
        bagCountController: BagCountController(),
        authSession: authSession,
        storefrontApi: storefrontApi,
        tenantSlug: _tenantSlug,
        branchId: _branchId,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _MockBagApi bagApi;
  late _MockStorefrontApi storefrontApi;
  late _MockAuthSession authSession;

  setUp(() {
    bagApi = _MockBagApi();
    storefrontApi = _MockStorefrontApi();
    authSession = _MockAuthSession();

    when(
      () => authSession.getAccessToken(),
    ).thenAnswer((_) async => _accessToken);
    when(
      () => bagApi.fetchBag(
        tenantSlug: _tenantSlug,
        branchId: _branchId,
        accessToken: _accessToken,
      ),
    ).thenAnswer((_) async => _bagWithOneItem());
  });

  testWidgets(
    'disables quantity, remove, and checkout controls when the branch is closed',
    (tester) async {
      when(
        () => storefrontApi.fetchStorefront(
          tenantSlug: _tenantSlug,
          branchId: _branchId,
        ),
      ).thenAnswer(
        (_) async => _storefrontWithBranch(
          acceptingOrders: false,
          closureLabel: 'Cerrado por hoy',
        ),
      );

      await _pumpBagScreen(
        tester,
        bagApi: bagApi,
        storefrontApi: storefrontApi,
        authSession: authSession,
      );

      expect(find.text('Cerrado por hoy'), findsOneWidget);
      expect(find.text('Sucursal cerrada'), findsOneWidget);

      final incrementButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add_rounded),
      );
      final decrementButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove_rounded),
      );
      expect(incrementButton.onPressed, isNull);
      expect(decrementButton.onPressed, isNull);

      final removeButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Eliminar'),
      );
      expect(removeButton.onPressed, isNull);

      final checkoutButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Sucursal cerrada'),
      );
      expect(checkoutButton.onPressed, isNull);
    },
  );

  testWidgets(
    'keeps quantity, remove, and checkout controls enabled when the branch is open',
    (tester) async {
      when(
        () => storefrontApi.fetchStorefront(
          tenantSlug: _tenantSlug,
          branchId: _branchId,
        ),
      ).thenAnswer((_) async => _storefrontWithBranch(acceptingOrders: true));

      await _pumpBagScreen(
        tester,
        bagApi: bagApi,
        storefrontApi: storefrontApi,
        authSession: authSession,
      );

      expect(find.text('Sucursal cerrada'), findsNothing);

      final incrementButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add_rounded),
      );
      expect(incrementButton.onPressed, isNotNull);

      final checkoutButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Ir a checkout'),
      );
      expect(checkoutButton.onPressed, isNotNull);
    },
  );
}
