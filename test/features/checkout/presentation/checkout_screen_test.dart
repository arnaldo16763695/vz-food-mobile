import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vz_food/core/auth/auth_session.dart';
import 'package:vz_food/features/bag/application/bag_count_controller.dart';
import 'package:vz_food/features/bag/domain/bag_payload.dart';
import 'package:vz_food/features/bag/infrastructure/bag_api.dart';
import 'package:vz_food/features/checkout/domain/checkout_models.dart';
import 'package:vz_food/features/checkout/infrastructure/checkout_api.dart';
import 'package:vz_food/features/checkout/presentation/checkout_screen.dart';
import 'package:vz_food/features/customer/domain/customer_context.dart';
import 'package:vz_food/features/customer/infrastructure/customer_api.dart';
import 'package:vz_food/features/storefront/domain/storefront_payload.dart';
import 'package:vz_food/features/storefront/infrastructure/storefront_api.dart';

// Mirrors bag_screen_test.dart's gating coverage, but for the checkout
// payment step: "Crear orden" must be unreachable when the active branch
// stops accepting orders, not just discouraged.

class _MockBagApi extends Mock implements BagApi {}

class _MockStorefrontApi extends Mock implements StorefrontApi {}

class _MockAuthSession extends Mock implements AuthSession {}

class _MockCustomerApi extends Mock implements CustomerApi {}

class _MockCheckoutApi extends Mock implements CheckoutApi {}

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

CustomerContextPayload _prefilledCustomer() {
  return CustomerContextPayload.fromJson({
    'customer': {
      'user': {'id': 'user-1', 'email': 'jane@example.com'},
      'profile': {'id': 'profile-1'},
      'customer': {
        'id': 'customer-1',
        'fullName': 'Jane Doe',
        'email': 'jane@example.com',
        'phone': '555-0100',
      },
    },
  });
}

Future<void> _pumpCheckoutScreen(
  WidgetTester tester, {
  required _MockBagApi bagApi,
  required _MockStorefrontApi storefrontApi,
  required _MockAuthSession authSession,
  required _MockCustomerApi customerApi,
  required _MockCheckoutApi checkoutApi,
}) async {
  // The personal + payment steps are taller than the default 800x600 test
  // surface. Grow it so every control is actually laid out and hit-testable
  // instead of fighting the ListView's scroll offset.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: CheckoutScreen(
        authSession: authSession,
        bagApi: bagApi,
        bagCountController: BagCountController(),
        customerApi: customerApi,
        checkoutApi: checkoutApi,
        storefrontApi: storefrontApi,
        tenantSlug: _tenantSlug,
        branchId: _branchId,
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Step 1 (personal data) is prefilled from the customer context, so
  // "Siguiente" can advance straight to the payment step under test.
  await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
  await tester.pumpAndSettle();
}

void main() {
  late _MockBagApi bagApi;
  late _MockStorefrontApi storefrontApi;
  late _MockAuthSession authSession;
  late _MockCustomerApi customerApi;
  late _MockCheckoutApi checkoutApi;

  setUp(() {
    bagApi = _MockBagApi();
    storefrontApi = _MockStorefrontApi();
    authSession = _MockAuthSession();
    customerApi = _MockCustomerApi();
    checkoutApi = _MockCheckoutApi();

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
    when(
      () => customerApi.fetchCustomerContext(accessToken: _accessToken),
    ).thenAnswer((_) async => _prefilledCustomer());
    when(
      () => checkoutApi.fetchPaymentSettings(tenantSlug: _tenantSlug),
    ).thenAnswer(
      (_) async => const CheckoutPaymentSettings(
        mobilePaymentInstructions: 'Pay via app',
        bankTransferInstructions: null,
      ),
    );
  });

  testWidgets(
    'shows the closure banner and disables "Crear orden" when the branch is closed',
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

      await _pumpCheckoutScreen(
        tester,
        bagApi: bagApi,
        storefrontApi: storefrontApi,
        authSession: authSession,
        customerApi: customerApi,
        checkoutApi: checkoutApi,
      );

      expect(find.text('Cerrado por hoy'), findsOneWidget);

      final submitButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Crear orden'),
      );
      expect(submitButton.onPressed, isNull);
    },
  );

  testWidgets(
    'hides the closure banner and enables "Crear orden" when the branch is open',
    (tester) async {
      when(
        () => storefrontApi.fetchStorefront(
          tenantSlug: _tenantSlug,
          branchId: _branchId,
        ),
      ).thenAnswer((_) async => _storefrontWithBranch(acceptingOrders: true));

      await _pumpCheckoutScreen(
        tester,
        bagApi: bagApi,
        storefrontApi: storefrontApi,
        authSession: authSession,
        customerApi: customerApi,
        checkoutApi: checkoutApi,
      );

      expect(find.textContaining('no esta aceptando pedidos'), findsNothing);

      final submitButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Crear orden'),
      );
      expect(submitButton.onPressed, isNotNull);
    },
  );
}
