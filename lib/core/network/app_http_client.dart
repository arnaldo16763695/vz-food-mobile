import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'network_exception.dart';

class AppHttpClient {
  AppHttpClient._(this.dio);

  final Dio dio;

  static AppHttpClient create({required AppConfig config}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: const {
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          handler.reject(_mapError(error));
        },
      ),
    );

    return AppHttpClient._(dio);
  }

  static DioException _mapError(DioException error) {
    final response = error.response;

    // The app should not make widgets reverse-engineer raw Dio failures.
    // We normalize the most common transport/backend categories here so future
    // feature code can react with product language instead of transport details.
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return NetworkException.timeout(error.requestOptions);
      case DioExceptionType.connectionError:
        return NetworkException.noConnection(error.requestOptions);
      case DioExceptionType.badResponse:
        return NetworkException.badResponse(
          requestOptions: error.requestOptions,
          statusCode: response?.statusCode,
          data: response?.data,
        );
      default:
        return error;
    }
  }
}
