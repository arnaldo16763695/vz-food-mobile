import 'dart:convert';

import 'package:dio/dio.dart';

import '../../bag/domain/bag_payload.dart';
import '../domain/checkout_models.dart';

class CheckoutApi {
  CheckoutApi(this._dio);

  final Dio _dio;

  Future<CheckoutResult> submit({
    required String accessToken,
    required CheckoutSubmission submission,
  }) async {
    final formData = FormData.fromMap({
      'branchId': submission.branchId,
      'fullName': submission.fullName,
      'phone': submission.phone,
      'email': submission.email,
      'fulfillmentType': 'pickup',
      'paymentMethod': submission.paymentMethod.apiValue,
      if (submission.notes != null && submission.notes!.trim().isNotEmpty)
        'notes': submission.notes!.trim(),
      'items': jsonEncode(
        submission.items.map(_bagItemToCheckoutPayload).toList(growable: false),
      ),
      // Checkout requires multipart with payment proof; keeping file assembly here
      // avoids leaking transport-specific concerns into the form widget tree.
      'paymentProof': await MultipartFile.fromFile(submission.paymentProofPath),
    });

    final response = await _dio.post<Object?>(
      '/api/mobile/storefront/${submission.tenantSlug}/checkout',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ),
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return CheckoutResult.fromJson(data);
    }

    if (data is Map) {
      return CheckoutResult.fromJson(Map<String, dynamic>.from(data));
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Expected checkout endpoint to return a JSON object.',
    );
  }

  Map<String, dynamic> _bagItemToCheckoutPayload(BagItem item) {
    return {
      'id': item.id,
      'productId': item.productId,
      'productVariantId': item.productVariantId,
      'variantName': item.variantName,
      'tenantSlug': item.tenantSlug,
      'branchId': item.branchId,
      'name': item.name,
      'description': item.description,
      'category': item.category,
      'unitPrice': item.unitPrice,
      'unitPriceLabel': item.unitPriceLabel,
      'quantity': item.quantity,
      'modifierSelections': item.modifierSelections
          .map((selection) => selection.toRequestJson())
          .toList(growable: false),
    };
  }
}
