import 'package:flutter_test/flutter_test.dart';
import 'package:vz_food/features/orders/domain/orders_models.dart';

void main() {
  group('PaymentReceiptSubmission.fromJson', () {
    test('parses a fully populated submission', () {
      final submission = PaymentReceiptSubmission.fromJson({
        'id': 'submission-1',
        'paymentMethod': 'mobile_payment',
        'receiptImagePath': 'receipts/1.png',
        'reviewStatus': 'approved',
        'rejectionReason': null,
        'submittedAt': '2026-08-24T10:00:00.000Z',
        'reviewedAt': '2026-08-24T11:00:00.000Z',
        'reviewedByName': 'Ops Team',
      });

      expect(submission.id, 'submission-1');
      expect(submission.reviewStatus, 'approved');
      expect(
        submission.submittedAt,
        DateTime.parse('2026-08-24T10:00:00.000Z'),
      );
      expect(submission.reviewedAt, DateTime.parse('2026-08-24T11:00:00.000Z'));
      expect(submission.reviewedByName, 'Ops Team');
    });

    test('defaults missing/unparsable dates to null instead of throwing', () {
      final submission = PaymentReceiptSubmission.fromJson({
        'id': 'submission-1',
      });

      expect(submission.submittedAt, isNull);
      expect(submission.reviewedAt, isNull);
      expect(submission.reviewStatus, '');
      expect(submission.rejectionReason, isNull);
    });
  });

  group('OrderDetail.fromJson', () {
    test('parses paymentReceiptSubmissions alongside order fields', () {
      final order = OrderDetail.fromJson({
        'id': 'order-1',
        'orderNumber': 1042,
        'status': 'pending',
        'paymentStatus': 'awaiting_review',
        'totalAmount': 25.5,
        'subtotalAmount': 23.0,
        'customerName': 'Jane Doe',
        'paymentReceiptSubmissions': [
          {
            'id': 'submission-1',
            'paymentMethod': 'bank_transfer',
            'reviewStatus': 'pending',
          },
          {
            'id': 'submission-2',
            'paymentMethod': 'bank_transfer',
            'reviewStatus': 'rejected',
            'rejectionReason': 'Monto no coincide',
          },
        ],
        'items': [],
      });

      expect(order.paymentReceiptSubmissions, hasLength(2));
      expect(order.paymentReceiptSubmissions.first.reviewStatus, 'pending');
      expect(
        order.paymentReceiptSubmissions.last.rejectionReason,
        'Monto no coincide',
      );
    });

    test('defaults paymentReceiptSubmissions to an empty list when absent', () {
      final order = OrderDetail.fromJson({
        'id': 'order-1',
        'orderNumber': 1042,
        'status': 'pending',
        'paymentStatus': 'unpaid',
        'totalAmount': 0,
        'subtotalAmount': 0,
        'customerName': 'Jane Doe',
      });

      expect(order.paymentReceiptSubmissions, isEmpty);
      expect(order.items, isEmpty);
    });

    test('ignores submission entries that are not JSON objects', () {
      final order = OrderDetail.fromJson({
        'id': 'order-1',
        'orderNumber': 1042,
        'status': 'pending',
        'paymentStatus': 'unpaid',
        'totalAmount': 0,
        'subtotalAmount': 0,
        'customerName': 'Jane Doe',
        'paymentReceiptSubmissions': [
          'not-a-map',
          {'id': 'submission-1', 'reviewStatus': 'pending'},
        ],
      });

      expect(order.paymentReceiptSubmissions, hasLength(1));
      expect(order.paymentReceiptSubmissions.single.id, 'submission-1');
    });
  });
}
