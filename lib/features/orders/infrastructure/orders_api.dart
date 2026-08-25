import 'package:dio/dio.dart';

import '../domain/orders_models.dart';

class OrdersApi {
  OrdersApi(this._dio);

  final Dio _dio;

  Options _authOptions(String accessToken) {
    return Options(headers: {'Authorization': 'Bearer $accessToken'});
  }

  Future<OrdersPayload> fetchOrders({
    required String tenantSlug,
    required String accessToken,
  }) async {
    final response = await _dio.get<Object?>(
      '/api/mobile/storefront/$tenantSlug/orders',
      options: _authOptions(accessToken),
    );
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return OrdersPayload.fromJson(data);
    }

    if (data is Map) {
      return OrdersPayload.fromJson(Map<String, dynamic>.from(data));
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Expected orders endpoint to return a JSON object.',
    );
  }

  Future<OrderDetailPayload> fetchOrderDetail({
    required String tenantSlug,
    required String orderId,
    required String accessToken,
  }) async {
    final response = await _dio.get<Object?>(
      '/api/mobile/storefront/$tenantSlug/orders/$orderId',
      options: _authOptions(accessToken),
    );
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return OrderDetailPayload.fromJson(data);
    }

    if (data is Map) {
      return OrderDetailPayload.fromJson(Map<String, dynamic>.from(data));
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Expected order detail endpoint to return a JSON object.',
    );
  }

  Future<bool> uploadPaymentProof({
    required String tenantSlug,
    required String orderId,
    required String accessToken,
    required String paymentMethod,
    required String filePath,
  }) async {
    final formData = FormData.fromMap({
      'paymentMethod': paymentMethod,
      'paymentProof': await MultipartFile.fromFile(filePath),
    });

    final response = await _dio.post<Object?>(
      '/api/mobile/storefront/$tenantSlug/orders/$orderId/payment-proof',
      data: formData,
      options: _authOptions(accessToken),
    );
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return data['ok'] as bool? ?? false;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data)['ok'] as bool? ?? false;
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Expected payment-proof endpoint to return a JSON object.',
    );
  }
}
