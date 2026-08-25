import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vz_food/core/auth/auth_session.dart';
import 'package:vz_food/features/bag/domain/bag_payload.dart';
import 'package:vz_food/features/bag/infrastructure/bag_api.dart';
import 'package:vz_food/features/checkout/application/checkout_controller.dart';
import 'package:vz_food/features/checkout/domain/checkout_models.dart';
import 'package:vz_food/features/checkout/infrastructure/checkout_api.dart';
import 'package:vz_food/features/customer/domain/customer_context.dart';
import 'package:vz_food/features/customer/infrastructure/customer_api.dart';
import 'package:vz_food/features/storefront/domain/storefront_payload.dart';
import 'package:vz_food/features/storefront/infrastructure/storefront_api.dart';

class _MockAuthSession extends Mock implements AuthSession {}

class _MockBagApi extends Mock implements BagApi {}

class _MockCustomerApi extends Mock implements CustomerApi {}

class _MockCheckoutApi extends Mock implements CheckoutApi {}

class _MockStorefrontApi extends Mock implements StorefrontApi {}

class _FakeCheckoutSubmission extends Fake implements CheckoutSubmission {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeCheckoutSubmission());
  });

  late _MockAuthSession authSession;
  late _MockBagApi bagApi;
  late _MockCustomerApi customerApi;
  late _MockCheckoutApi checkoutApi;
  late _MockStorefrontApi storefrontApi;
  late CheckoutController controller;

  const tenantSlug = 'acme';
  const branchId = 'branch-1';

  setUp(() {
    authSession = _MockAuthSession();
    bagApi = _MockBagApi();
    customerApi = _MockCustomerApi();
    checkoutApi = _MockCheckoutApi();
    storefrontApi = _MockStorefrontApi();
    controller = CheckoutController(
      authSession,
      bagApi,
      customerApi,
      checkoutApi,
      storefrontApi,
    );
  });

  group('CheckoutController.load', () {
    test('rejects with StateError when there is no access token', () async {
      when(() => authSession.getAccessToken()).thenAnswer((_) async => null);

      await expectLater(
        controller.load(tenantSlug: tenantSlug, branchId: branchId),
        throwsA(isA<StateError>()),
      );

      verifyNever(
        () => bagApi.fetchBag(
          tenantSlug: any(named: 'tenantSlug'),
          branchId: any(named: 'branchId'),
          accessToken: any(named: 'accessToken'),
        ),
      );
    });

    test(
      'aggregates bag, customer, payment settings, and the active branch',
      () async {
        when(
          () => authSession.getAccessToken(),
        ).thenAnswer((_) async => 'token-1');
        when(
          () => bagApi.fetchBag(
            tenantSlug: tenantSlug,
            branchId: branchId,
            accessToken: 'token-1',
          ),
        ).thenAnswer((_) async => const BagPayload(items: []));
        when(
          () => customerApi.fetchCustomerContext(accessToken: 'token-1'),
        ).thenAnswer(
          (_) async => CustomerContextPayload.fromJson({
            'customer': {
              'user': {'id': 'user-1', 'email': 'jane@example.com'},
              'profile': {'id': 'profile-1'},
              'customer': {'id': 'customer-1'},
            },
          }),
        );
        when(
          () => checkoutApi.fetchPaymentSettings(tenantSlug: tenantSlug),
        ).thenAnswer(
          (_) async => const CheckoutPaymentSettings(
            mobilePaymentInstructions: 'Pay via app',
            bankTransferInstructions: null,
          ),
        );
        when(
          () => storefrontApi.fetchStorefront(
            tenantSlug: tenantSlug,
            branchId: branchId,
          ),
        ).thenAnswer(
          (_) async => StorefrontPayload.fromJson({
            'storefront': {
              'tenant': {'id': 't-1', 'name': 'Acme', 'slug': tenantSlug},
              'activeBranch': {
                'id': branchId,
                'name': 'Downtown',
                'acceptingOrders': false,
                'closureLabel': 'Cerrado por hoy',
              },
            },
          }),
        );

        final result = await controller.load(
          tenantSlug: tenantSlug,
          branchId: branchId,
        );

        expect(result.bag.isEmpty, isTrue);
        expect(result.customer.customer.user.email, 'jane@example.com');
        expect(result.paymentSettings.mobilePaymentInstructions, 'Pay via app');
        expect(result.branch, isNotNull);
        expect(result.branch!.acceptingOrders, isFalse);
        expect(result.branch!.closureLabel, 'Cerrado por hoy');
      },
    );

    test(
      'leaves branch null when the storefront has no active branch',
      () async {
        when(
          () => authSession.getAccessToken(),
        ).thenAnswer((_) async => 'token-1');
        when(
          () => bagApi.fetchBag(
            tenantSlug: tenantSlug,
            branchId: branchId,
            accessToken: 'token-1',
          ),
        ).thenAnswer((_) async => const BagPayload(items: []));
        when(
          () => customerApi.fetchCustomerContext(accessToken: 'token-1'),
        ).thenAnswer((_) async => CustomerContextPayload.fromJson(const {}));
        when(
          () => checkoutApi.fetchPaymentSettings(tenantSlug: tenantSlug),
        ).thenAnswer((_) async => CheckoutPaymentSettings.fromJson(const {}));
        when(
          () => storefrontApi.fetchStorefront(
            tenantSlug: tenantSlug,
            branchId: branchId,
          ),
        ).thenAnswer(
          (_) async => StorefrontPayload.fromJson({
            'storefront': {
              'tenant': {'id': 't-1', 'name': 'Acme', 'slug': tenantSlug},
            },
          }),
        );

        final result = await controller.load(
          tenantSlug: tenantSlug,
          branchId: branchId,
        );

        expect(result.branch, isNull);
      },
    );
  });

  group('CheckoutController.submit', () {
    test('rejects with StateError when there is no access token', () async {
      when(() => authSession.getAccessToken()).thenAnswer((_) async => '');

      await expectLater(
        controller.submit(
          const CheckoutSubmission(
            tenantSlug: tenantSlug,
            branchId: branchId,
            fullName: 'Jane Doe',
            phone: '555-0100',
            email: 'jane@example.com',
            paymentMethod: CheckoutPaymentMethod.mobilePayment,
            paymentProofPath: '/tmp/proof.png',
            items: [],
          ),
        ),
        throwsA(isA<StateError>()),
      );

      verifyNever(
        () => checkoutApi.submit(
          accessToken: any(named: 'accessToken'),
          submission: any(named: 'submission'),
        ),
      );
    });
  });
}
