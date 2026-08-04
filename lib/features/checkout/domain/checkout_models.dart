import '../../bag/domain/bag_payload.dart';

enum CheckoutPaymentMethod {
  mobilePayment('mobile_payment', 'Pago movil'),
  bankTransfer('bank_transfer', 'Transferencia bancaria');

  const CheckoutPaymentMethod(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class CheckoutSubmission {
  const CheckoutSubmission({
    required this.tenantSlug,
    required this.branchId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.paymentMethod,
    required this.paymentProofPath,
    required this.items,
    this.notes,
  });

  final String tenantSlug;
  final String branchId;
  final String fullName;
  final String phone;
  final String email;
  final String? notes;
  final CheckoutPaymentMethod paymentMethod;
  final String paymentProofPath;
  final List<BagItem> items;
}

class CheckoutResult {
  const CheckoutResult({
    required this.ok,
    this.orderId,
    this.orderNumber,
    this.error,
  });

  final bool ok;
  final String? orderId;
  final int? orderNumber;
  final String? error;

  factory CheckoutResult.fromJson(Map<String, dynamic> json) {
    return CheckoutResult(
      ok: json['ok'] as bool? ?? false,
      orderId: json['orderId'] as String?,
      orderNumber: (json['orderNumber'] as num?)?.toInt(),
      error: json['error'] as String?,
    );
  }
}

class CheckoutPaymentSettings {
  const CheckoutPaymentSettings({
    required this.mobilePaymentInstructions,
    required this.bankTransferInstructions,
  });

  final String? mobilePaymentInstructions;
  final String? bankTransferInstructions;

  factory CheckoutPaymentSettings.fromJson(Map<String, dynamic> json) {
    return CheckoutPaymentSettings(
      mobilePaymentInstructions: json['mobilePaymentInstructions'] as String?,
      bankTransferInstructions: json['bankTransferInstructions'] as String?,
    );
  }
}
