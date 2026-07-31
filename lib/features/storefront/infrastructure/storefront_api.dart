import 'package:dio/dio.dart';

import '../domain/storefront_payload.dart';

class StorefrontApi {
  StorefrontApi(this._dio);

  final Dio _dio;

  Future<StorefrontPayload> fetchStorefront({
    required String tenantSlug,
    String? branchId,
  }) async {
    final response = await _dio.get<Object?>(
      '/api/mobile/storefront/$tenantSlug',
      queryParameters: branchId == null || branchId.isEmpty
          ? null
          : {'branchId': branchId},
    );
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return StorefrontPayload.fromJson(data);
    }

    if (data is Map) {
      return StorefrontPayload.fromJson(Map<String, dynamic>.from(data));
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Expected storefront endpoint to return a JSON object.',
    );
  }
}
