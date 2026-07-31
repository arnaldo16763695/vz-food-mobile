import '../../../core/auth/auth_session.dart';
import '../domain/customer_context.dart';
import '../infrastructure/customer_api.dart';

class CustomerController {
  CustomerController(this._customerApi, this._authSession);

  final CustomerApi _customerApi;
  final AuthSession _authSession;

  Future<CustomerContextPayload?> load() async {
    final accessToken = await _authSession.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    return _customerApi.fetchCustomerContext(accessToken: accessToken);
  }
}
