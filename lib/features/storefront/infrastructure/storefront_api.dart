import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../domain/storefront_payload.dart';

class StorefrontApi {
  StorefrontApi(this._dio);

  final Dio _dio;

  Future<StorefrontPayload> fetchStorefront({
    required String tenantSlug,
    String? branchId,
  }) async {
    debugPrint(
      'GET /api/mobile/storefront/$tenantSlug branchId=${branchId ?? '(none)'}',
    );

    final response = await _dio.get<Object?>(
      '/api/mobile/storefront/$tenantSlug',
      queryParameters: branchId == null || branchId.isEmpty
          ? null
          : {'branchId': branchId},
    );

    debugPrint(
      'Storefront response status=${response.statusCode} type=${response.data.runtimeType}',
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

  Future<List<StorefrontProduct>> searchProducts({
    required String tenantSlug,
    required String query,
    String? branchId,
  }) async {
    debugPrint(
      'GET /api/mobile/storefront/$tenantSlug/search branchId=${branchId ?? '(none)'} q=$query',
    );

    final response = await _dio.get<Object?>(
      '/api/mobile/storefront/$tenantSlug/search',
      queryParameters: {
        if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
        'q': query,
      },
    );

    final data = response.data;

    if (data is Map<String, dynamic>) {
      return _parseSearchResponse(data, response);
    }

    if (data is Map) {
      return _parseSearchResponse(Map<String, dynamic>.from(data), response);
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Expected storefront search endpoint to return product results.',
    );
  }

  List<StorefrontProduct> _parseSearchResponse(
    Map<String, dynamic> data,
    Response<Object?> response,
  ) {
    final rawProducts = data['products'];
    if (rawProducts is List) {
      return _parseProductsList(rawProducts);
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message:
          'Expected storefront search response to include a products array.',
    );
  }

  List<StorefrontProduct> _parseProductsList(List rawProducts) {
    return rawProducts
        .whereType<Map>()
        .map(
          (item) => StorefrontProduct.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }
}
