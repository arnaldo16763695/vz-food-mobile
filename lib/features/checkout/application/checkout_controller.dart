import '../../../core/auth/auth_session.dart';
import '../../bag/domain/bag_payload.dart';
import '../../bag/infrastructure/bag_api.dart';
import '../../customer/domain/customer_context.dart';
import '../../customer/infrastructure/customer_api.dart';
import '../domain/checkout_models.dart';
import '../infrastructure/checkout_api.dart';

class CheckoutLoadData {
  const CheckoutLoadData({
    required this.bag,
    required this.customer,
    required this.paymentSettings,
  });

  final BagPayload bag;
  final CustomerContextPayload customer;
  final CheckoutPaymentSettings paymentSettings;
}

class CheckoutController {
  CheckoutController(
    this._authSession,
    this._bagApi,
    this._customerApi,
    this._checkoutApi,
  );

  final AuthSession _authSession;
  final BagApi _bagApi;
  final CustomerApi _customerApi;
  final CheckoutApi _checkoutApi;

  Future<String> _requireAccessToken() async {
    final token = await _authSession.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('Login requerido para continuar con checkout.');
    }
    return token;
  }

  Future<CheckoutLoadData> load({
    required String tenantSlug,
    required String branchId,
  }) async {
    final accessToken = await _requireAccessToken();

    final bagFuture = _bagApi.fetchBag(
      tenantSlug: tenantSlug,
      branchId: branchId,
      accessToken: accessToken,
    );
    final customerFuture = _customerApi.fetchCustomerContext(
      accessToken: accessToken,
    );
    final paymentSettingsFuture = _checkoutApi.fetchPaymentSettings(
      tenantSlug: tenantSlug,
    );

    final results = await Future.wait<Object>([
      bagFuture,
      customerFuture,
      paymentSettingsFuture,
    ]);
    return CheckoutLoadData(
      bag: results[0] as BagPayload,
      customer: results[1] as CustomerContextPayload,
      paymentSettings: results[2] as CheckoutPaymentSettings,
    );
  }

  Future<CheckoutResult> submit(CheckoutSubmission submission) async {
    final accessToken = await _requireAccessToken();
    return _checkoutApi.submit(
      accessToken: accessToken,
      submission: submission,
    );
  }
}
