import 'package:dio/dio.dart';

import '../domain/customer_context.dart';

class CustomerApi {
  CustomerApi(this._dio);

  final Dio _dio;

  Future<CustomerContextPayload> fetchCustomerContext({
    required String accessToken,
  }) async {
    final response = await _dio.get<Object?>(
      '/api/mobile/customer/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return CustomerContextPayload.fromJson(data);
    }

    if (data is Map) {
      return CustomerContextPayload.fromJson(Map<String, dynamic>.from(data));
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Expected customer/me to return a JSON object.',
    );
  }
}
