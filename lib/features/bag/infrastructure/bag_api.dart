import 'package:dio/dio.dart';

import '../domain/bag_payload.dart';

class BagApi {
  BagApi(this._dio);

  final Dio _dio;

  Options _authOptions(String accessToken) {
    return Options(headers: {'Authorization': 'Bearer $accessToken'});
  }

  Future<void> addItem({
    required String tenantSlug,
    required String branchId,
    required String productId,
    required String accessToken,
    int quantity = 1,
    String? productVariantId,
    List<Map<String, dynamic>> modifierSelections = const [],
  }) async {
    await _dio.post<Object?>(
      '/api/mobile/storefront/$tenantSlug/bag/items',
      data: {
        'branchId': branchId,
        'productId': productId,
        'quantity': quantity,
        if (productVariantId != null && productVariantId.isNotEmpty)
          'productVariantId': productVariantId,
        'modifierSelections': modifierSelections,
      },
      options: _authOptions(accessToken),
    );
  }

  Future<void> replaceItem({
    required String tenantSlug,
    required String bagItemId,
    required String accessToken,
    required String branchId,
    required String productId,
    required int quantity,
    String? productVariantId,
    List<Map<String, dynamic>> modifierSelections = const [],
  }) async {
    await _dio.patch<Object?>(
      '/api/mobile/storefront/$tenantSlug/bag/items/$bagItemId',
      data: {
        'branchId': branchId,
        'productId': productId,
        'quantity': quantity,
        if (productVariantId != null && productVariantId.isNotEmpty)
          'productVariantId': productVariantId,
        'modifierSelections': modifierSelections,
      },
      options: _authOptions(accessToken),
    );
  }

  Future<void> decrementItem({
    required String tenantSlug,
    required String bagItemId,
    required String branchId,
    required String accessToken,
  }) async {
    await _dio.post<Object?>(
      '/api/mobile/storefront/$tenantSlug/bag/items/$bagItemId',
      queryParameters: {'branchId': branchId},
      options: _authOptions(accessToken),
    );
  }

  Future<void> removeItem({
    required String tenantSlug,
    required String bagItemId,
    required String branchId,
    required String accessToken,
  }) async {
    await _dio.delete<Object?>(
      '/api/mobile/storefront/$tenantSlug/bag/items/$bagItemId',
      queryParameters: {'branchId': branchId},
      options: _authOptions(accessToken),
    );
  }

  Future<BagPayload> fetchBag({
    required String tenantSlug,
    required String branchId,
    required String accessToken,
  }) async {
    final response = await _dio.get<Object?>(
      '/api/mobile/storefront/$tenantSlug/bag',
      queryParameters: {'branchId': branchId},
      options: _authOptions(accessToken),
    );
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return BagPayload.fromJson(data);
    }

    if (data is Map) {
      return BagPayload.fromJson(Map<String, dynamic>.from(data));
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Expected bag endpoint to return a JSON object.',
    );
  }
}
