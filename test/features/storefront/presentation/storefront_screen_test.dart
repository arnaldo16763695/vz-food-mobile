import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vz_food/core/auth/auth_session.dart';
import 'package:vz_food/features/bag/application/bag_count_controller.dart';
import 'package:vz_food/features/bag/infrastructure/bag_api.dart';
import 'package:vz_food/features/storefront/domain/storefront_payload.dart';
import 'package:vz_food/features/storefront/infrastructure/storefront_api.dart';
import 'package:vz_food/features/storefront/presentation/storefront_screen.dart';

// Covers the product detail sheet opened by tapping anywhere on a product card
// except the add button: it must show ingredients / combo contents, and its own
// add button follows the branch's ordering state.

class _MockStorefrontApi extends Mock implements StorefrontApi {}

class _MockBagApi extends Mock implements BagApi {}

class _MockAuthSession extends Mock implements AuthSession {}

const _tenantSlug = 'acme';
const _branchId = 'branch-1';

StorefrontPayload _storefront({required bool acceptingOrders}) {
  return StorefrontPayload.fromJson({
    'storefront': {
      'tenant': {'id': 't1', 'name': 'Acme', 'slug': _tenantSlug},
      'activeBranch': {
        'id': _branchId,
        'name': 'Centro',
        'acceptingOrders': acceptingOrders,
        'isOpenNow': acceptingOrders,
      },
      'branches': [
        {'id': _branchId, 'name': 'Centro', 'acceptingOrders': acceptingOrders},
      ],
      'menu': [
        {
          'id': 'combo-1',
          'name': 'Combo Familiar',
          'description': 'Para compartir',
          'basePrice': '\$ 20.00',
          'category': 'Combos',
          'comboComponents': [
            {'componentProductName': 'Hamburguesa', 'quantity': 2},
            {
              'componentProductName': 'Papas',
              'componentVariantName': 'Grande',
              'quantity': 1,
            },
          ],
        },
      ],
    },
  });
}

Future<void> _pumpStorefront(
  WidgetTester tester, {
  required _MockStorefrontApi storefrontApi,
  required _MockBagApi bagApi,
  required _MockAuthSession authSession,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: StorefrontScreen(
        authSession: authSession,
        bagApi: bagApi,
        bagCountController: BagCountController(),
        storefrontApi: storefrontApi,
        tenantSlug: _tenantSlug,
        branchId: _branchId,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _MockStorefrontApi storefrontApi;
  late _MockBagApi bagApi;
  late _MockAuthSession authSession;

  setUp(() {
    storefrontApi = _MockStorefrontApi();
    bagApi = _MockBagApi();
    authSession = _MockAuthSession();

    when(() => authSession.getAccessToken()).thenAnswer((_) async => null);
  });

  testWidgets(
    'tapping a product card opens the detail sheet with combo contents and an add button',
    (tester) async {
      when(
        () => storefrontApi.fetchStorefront(
          tenantSlug: _tenantSlug,
          branchId: _branchId,
        ),
      ).thenAnswer((_) async => _storefront(acceptingOrders: true));

      await _pumpStorefront(
        tester,
        storefrontApi: storefrontApi,
        bagApi: bagApi,
        authSession: authSession,
      );

      expect(find.text('Combo Familiar'), findsOneWidget);

      await tester.tap(find.text('Combo Familiar'));
      await tester.pumpAndSettle();

      expect(find.text('Incluye'), findsOneWidget);
      expect(find.text('• 2x Hamburguesa'), findsOneWidget);
      expect(find.text('• 1x Papas (Grande)'), findsOneWidget);

      final addButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Agregar a la bolsa'),
      );
      expect(addButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'detail sheet is a read-only spec view when the branch is closed',
    (tester) async {
      when(
        () => storefrontApi.fetchStorefront(
          tenantSlug: _tenantSlug,
          branchId: _branchId,
        ),
      ).thenAnswer((_) async => _storefront(acceptingOrders: false));

      await _pumpStorefront(
        tester,
        storefrontApi: storefrontApi,
        bagApi: bagApi,
        authSession: authSession,
      );

      await tester.tap(find.text('Combo Familiar'));
      await tester.pumpAndSettle();

      expect(find.text('• 2x Hamburguesa'), findsOneWidget);

      final disabledButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'No disponible'),
      );
      expect(disabledButton.onPressed, isNull);
      expect(
        find.widgetWithText(ElevatedButton, 'Agregar a la bolsa'),
        findsNothing,
      );
    },
  );
}
