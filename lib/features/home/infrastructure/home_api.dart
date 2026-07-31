import 'package:dio/dio.dart';

import '../domain/home_payload.dart';

class HomeApi {
  HomeApi(this._dio);

  final Dio _dio;

  Future<HomePayload> fetchHome({
    double? latitude,
    double? longitude,
  }) async {
    final response = await _dio.get<Object?>(
      '/api/mobile/home',
      queryParameters: latitude != null && longitude != null
          ? {
              'lat': latitude,
              'lng': longitude,
            }
          : null,
    );
    final data = response.data;

    // Home already has a documented contract. We still guard the top-level shape here so
    // feature widgets can trust a normalized payload instead of dealing with transport noise.
    if (data is Map<String, dynamic>) {
      return HomePayload.fromJson(data);
    }

    if (data is Map) {
      return HomePayload.fromJson(Map<String, dynamic>.from(data));
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Expected /api/mobile/home to return a JSON object.',
    );
  }
}
