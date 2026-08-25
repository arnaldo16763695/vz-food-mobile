class OrdersPayload {
  const OrdersPayload({required this.orders});

  final List<OrderSummary> orders;

  factory OrdersPayload.fromJson(Map<String, dynamic> json) {
    final rawOrders = json['orders'];
    if (rawOrders is! List) {
      return const OrdersPayload(orders: []);
    }

    return OrdersPayload(
      orders: rawOrders
          .whereType<Map>()
          .map((item) => OrderSummary.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }

  bool get isEmpty => orders.isEmpty;
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.fulfillmentType,
    required this.totalAmount,
    required this.placedAt,
    required this.itemCount,
  });

  final String id;
  final int orderNumber;
  final String status;
  final String fulfillmentType;
  final double totalAmount;
  final DateTime? placedAt;
  final int itemCount;

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      id: json['id'] as String? ?? '',
      orderNumber: (json['orderNumber'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      fulfillmentType: json['fulfillmentType'] as String? ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      placedAt: DateTime.tryParse(json['placedAt'] as String? ?? ''),
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class OrderDetailPayload {
  const OrderDetailPayload({required this.order});

  final OrderDetail order;

  factory OrderDetailPayload.fromJson(Map<String, dynamic> json) {
    return OrderDetailPayload(
      order: OrderDetail.fromJson(
        Map<String, dynamic>.from(
          json['order'] as Map? ?? const <String, dynamic>{},
        ),
      ),
    );
  }
}

class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.paymentReceiptImageUrl,
    required this.paymentRejectionReason,
    required this.fulfillmentType,
    required this.totalAmount,
    required this.subtotalAmount,
    required this.placedAt,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.notes,
    required this.paymentReceiptSubmissions,
    required this.items,
  });

  final String id;
  final int orderNumber;
  final String status;
  final String paymentStatus;
  final String? paymentMethod;
  final String? paymentReceiptImageUrl;
  final String? paymentRejectionReason;
  final String fulfillmentType;
  final double totalAmount;
  final double subtotalAmount;
  final DateTime? placedAt;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? notes;
  final List<PaymentReceiptSubmission> paymentReceiptSubmissions;
  final List<OrderDetailItem> items;

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return OrderDetail(
      id: json['id'] as String? ?? '',
      orderNumber: (json['orderNumber'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      paymentStatus: json['paymentStatus'] as String? ?? '',
      paymentMethod: json['paymentMethod'] as String?,
      paymentReceiptImageUrl: json['paymentReceiptImageUrl'] as String?,
      paymentRejectionReason: json['paymentRejectionReason'] as String?,
      fulfillmentType: json['fulfillmentType'] as String? ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      subtotalAmount: (json['subtotalAmount'] as num?)?.toDouble() ?? 0,
      placedAt: DateTime.tryParse(json['placedAt'] as String? ?? ''),
      customerName: json['customerName'] as String? ?? '',
      customerPhone: json['customerPhone'] as String?,
      customerEmail: json['customerEmail'] as String?,
      notes: json['notes'] as String?,
      paymentReceiptSubmissions:
          (json['paymentReceiptSubmissions'] as List?)
              ?.whereType<Map>()
              .map(
                (item) => PaymentReceiptSubmission.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false) ??
          const [],
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) =>
                      OrderDetailItem.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class PaymentReceiptSubmission {
  const PaymentReceiptSubmission({
    required this.id,
    required this.paymentMethod,
    required this.receiptImagePath,
    required this.reviewStatus,
    required this.rejectionReason,
    required this.submittedAt,
    required this.reviewedAt,
    required this.reviewedByName,
  });

  final String id;
  final String paymentMethod;
  final String receiptImagePath;
  final String reviewStatus;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedByName;

  factory PaymentReceiptSubmission.fromJson(Map<String, dynamic> json) {
    return PaymentReceiptSubmission(
      id: json['id'] as String? ?? '',
      paymentMethod: json['paymentMethod'] as String? ?? '',
      receiptImagePath: json['receiptImagePath'] as String? ?? '',
      reviewStatus: json['reviewStatus'] as String? ?? '',
      rejectionReason: json['rejectionReason'] as String?,
      submittedAt: DateTime.tryParse(json['submittedAt'] as String? ?? ''),
      reviewedAt: DateTime.tryParse(json['reviewedAt'] as String? ?? ''),
      reviewedByName: json['reviewedByName'] as String?,
    );
  }
}

class OrderDetailItem {
  const OrderDetailItem({
    required this.id,
    required this.productName,
    required this.categoryName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String id;
  final String productName;
  final String? categoryName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  factory OrderDetailItem.fromJson(Map<String, dynamic> json) {
    return OrderDetailItem(
      id: json['id'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      categoryName: json['categoryName'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
    );
  }
}
