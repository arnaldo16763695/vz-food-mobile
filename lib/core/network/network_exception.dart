import 'package:dio/dio.dart';

class NetworkException extends DioException {
  NetworkException({
    required super.requestOptions,
    required super.type,
    super.response,
    super.error,
    super.message,
  });

  factory NetworkException.timeout(RequestOptions requestOptions) {
    return NetworkException(
      requestOptions: requestOptions,
      type: DioExceptionType.connectionTimeout,
      message: 'The request timed out before the server could respond.',
    );
  }

  factory NetworkException.noConnection(RequestOptions requestOptions) {
    return NetworkException(
      requestOptions: requestOptions,
      type: DioExceptionType.connectionError,
      message: 'No network connection is available for this request.',
    );
  }

  factory NetworkException.badResponse({
    required RequestOptions requestOptions,
    required int? statusCode,
    required Object? data,
  }) {
    return NetworkException(
      requestOptions: requestOptions,
      response: Response(
        requestOptions: requestOptions,
        statusCode: statusCode,
        data: data,
      ),
      type: DioExceptionType.badResponse,
      message: 'The backend returned an unexpected response.',
    );
  }
}
