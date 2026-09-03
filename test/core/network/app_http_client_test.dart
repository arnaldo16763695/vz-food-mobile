import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vz_food/core/config/app_config.dart';
import 'package:vz_food/core/network/app_http_client.dart';
import 'package:vz_food/core/network/network_exception.dart';

/// A fake transport that always fails with a caller-chosen [DioException]
/// type, so we can exercise `AppHttpClient`'s error-normalization
/// interceptor without hitting the network.
class _FailingAdapter implements HttpClientAdapter {
  _FailingAdapter(this.buildError);

  final DioException Function(RequestOptions options) buildError;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw buildError(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioThatFails(DioException Function(RequestOptions options) buildError) {
  final client = AppHttpClient.create(
    config: const AppConfig(
      apiBaseUrl: 'https://example.test',
      supabaseUrl: '',
      supabaseAnonKey: '',
      authRedirectUrl: 'vzfood://auth-callback',
    ),
  );
  client.dio.httpClientAdapter = _FailingAdapter(buildError);
  return client.dio;
}

void main() {
  group('AppHttpClient error normalization', () {
    test('maps connection timeouts to NetworkException.timeout', () async {
      final dio = _dioThatFails(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        dio.get<Object?>('/ping'),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionTimeout,
          ),
        ),
      );
    });

    test('maps receive/send timeouts to NetworkException too', () async {
      final dio = _dioThatFails(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      );

      await expectLater(
        dio.get<Object?>('/ping'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('maps connectionError to NetworkException.noConnection', () async {
      final dio = _dioThatFails(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        dio.get<Object?>('/ping'),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionError,
          ),
        ),
      );
    });

    test(
      'maps a 500 bad response to NetworkException with the status code preserved',
      () async {
        final dio = _dioThatFails(
          (options) => DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: 500,
              data: {'error': 'boom'},
            ),
          ),
        );

        await expectLater(
          dio.get<Object?>('/ping'),
          throwsA(
            isA<NetworkException>().having(
              (e) => e.response?.statusCode,
              'response.statusCode',
              500,
            ),
          ),
        );
      },
    );

    test('leaves other DioException types (e.g. cancel) unmapped', () async {
      final dio = _dioThatFails(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        ),
      );

      await expectLater(
        dio.get<Object?>('/ping'),
        throwsA(
          isA<DioException>()
              .having((e) => e.type, 'type', DioExceptionType.cancel)
              .having(
                (e) => e,
                'is NetworkException',
                isNot(isA<NetworkException>()),
              ),
        ),
      );
    });
  });
}
