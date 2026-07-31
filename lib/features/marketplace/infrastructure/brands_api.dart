import 'package:dio/dio.dart';

import '../domain/brands_payload.dart';

class BrandsApi {
  BrandsApi(this._dio);

  final Dio _dio;

  Future<BrandsPayload> fetchBrands() async {
    final response = await _dio.get<Object?>('/api/mobile/brands');
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return BrandsPayload.fromJson(data);
    }

    if (data is Map) {
      return BrandsPayload.fromJson(Map<String, dynamic>.from(data));
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Expected /api/mobile/brands to return a JSON object.',
    );
  }
}
