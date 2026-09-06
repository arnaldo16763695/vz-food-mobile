import 'package:dio/dio.dart';

import '../domain/branch_detail.dart';

class BranchesApi {
  BranchesApi(this._dio);

  final Dio _dio;

  Future<BranchDetailPayload> fetchBranchDetail({
    required String branchId,
  }) async {
    final response = await _dio.get<Object?>('/api/mobile/branches/$branchId');
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return BranchDetailPayload.fromJson(data);
    }

    if (data is Map) {
      return BranchDetailPayload.fromJson(Map<String, dynamic>.from(data));
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Expected branch detail endpoint to return a JSON object.',
    );
  }
}
