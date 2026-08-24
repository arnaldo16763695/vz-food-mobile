import '../../../core/auth/auth_session.dart';
import '../domain/orders_models.dart';
import '../infrastructure/orders_api.dart';

class OrdersController {
  OrdersController(this._ordersApi, this._authSession);

  final OrdersApi _ordersApi;
  final AuthSession _authSession;

  Future<String> _requireAccessToken() async {
    final token = await _authSession.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('Login requerido para ver pedidos.');
    }
    return token;
  }

  Future<OrdersPayload> loadOrders({required String tenantSlug}) async {
    final accessToken = await _requireAccessToken();
    return _ordersApi.fetchOrders(
      tenantSlug: tenantSlug,
      accessToken: accessToken,
    );
  }

  Future<OrderDetailPayload> loadOrderDetail({
    required String tenantSlug,
    required String orderId,
  }) async {
    final accessToken = await _requireAccessToken();
    return _ordersApi.fetchOrderDetail(
      tenantSlug: tenantSlug,
      orderId: orderId,
      accessToken: accessToken,
    );
  }

  Future<bool> uploadPaymentProof({
    required String tenantSlug,
    required String orderId,
    required String paymentMethod,
    required String filePath,
  }) async {
    final accessToken = await _requireAccessToken();
    return _ordersApi.uploadPaymentProof(
      tenantSlug: tenantSlug,
      orderId: orderId,
      accessToken: accessToken,
      paymentMethod: paymentMethod,
      filePath: filePath,
    );
  }
}
