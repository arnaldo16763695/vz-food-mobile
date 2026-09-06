import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vz_food/core/auth/auth_session.dart';
import 'package:vz_food/features/bag/application/bag_count_controller.dart';
import 'package:vz_food/features/bag/infrastructure/bag_api.dart';
import 'package:vz_food/features/orders/domain/orders_models.dart';
import 'package:vz_food/features/orders/infrastructure/orders_api.dart';
import 'package:vz_food/features/orders/presentation/order_detail_screen.dart';

class _MockOrdersApi extends Mock implements OrdersApi {}

class _MockBagApi extends Mock implements BagApi {}

class _MockAuthSession extends Mock implements AuthSession {}

OrderDetailPayload _order({required int itemCount}) {
  return OrderDetailPayload.fromJson({
    'order': {
      'id': 'o1',
      'orderNumber': 1042,
      'status': 'preparing',
      'paymentStatus': 'awaiting_review',
      'paymentMethod': 'mobile_payment',
      'fulfillmentType': 'pickup',
      'totalAmount': 40.0,
      'subtotalAmount': 38.0,
      'placedAt': '2026-09-01T10:00:00.000Z',
      'customerName': 'Jane Doe',
      'customerPhone': '555-0100',
      'customerEmail': 'jane@example.com',
      'paymentReceiptSubmissions': const [],
      'items': [
        for (var i = 1; i <= itemCount; i++)
          {
            'id': 'i$i',
            'productName': 'Producto $i',
            'quantity': 1,
            'unitPrice': 4.0,
            'lineTotal': 4.0,
            'modifiers': i == 1
                ? [
                    {
                      'modifierGroupName': 'Extras',
                      'modifierOptionName': 'Queso',
                    },
                  ]
                : const [],
            'comboComponents': const [],
          },
      ],
    },
  });
}

void main() {
  late _MockOrdersApi ordersApi;
  late _MockAuthSession authSession;

  setUp(() {
    ordersApi = _MockOrdersApi();
    authSession = _MockAuthSession();
    when(() => authSession.getAccessToken()).thenAnswer((_) async => 'tok');
  });

  Future<void> pump(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    return tester.pumpWidget(
      MaterialApp(
        home: OrderDetailScreen(
          authSession: authSession,
          bagApi: _MockBagApi(),
          bagCountController: BagCountController(),
          ordersApi: ordersApi,
          tenantSlug: 'acme',
          orderId: 'o1',
          branchId: null,
        ),
      ),
    );
  }

  testWidgets('shows statuses in Spanish and a compact layout', (tester) async {
    when(
      () => ordersApi.fetchOrderDetail(
        tenantSlug: 'acme',
        orderId: 'o1',
        accessToken: 'tok',
      ),
    ).thenAnswer((_) async => _order(itemCount: 2));

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('En preparacion'), findsOneWidget);
    expect(find.text('En revision'), findsOneWidget);
    expect(find.text('Retiro'), findsWidgets); // chip + customer row
    expect(find.text('Cliente'), findsOneWidget);
    expect(find.text('Comprobante'), findsOneWidget);
    expect(find.text('Productos (2)'), findsOneWidget);
    expect(find.text('+ Extras: Queso'), findsOneWidget);
  });

  testWidgets('collapses long item lists behind a "ver mas" toggle', (
    tester,
  ) async {
    when(
      () => ordersApi.fetchOrderDetail(
        tenantSlug: 'acme',
        orderId: 'o1',
        accessToken: 'tok',
      ),
    ).thenAnswer((_) async => _order(itemCount: 10));

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Producto 8'), findsOneWidget);
    expect(find.text('Producto 9'), findsNothing);
    expect(find.text('Ver 2 productos mas'), findsOneWidget);

    await tester.tap(find.text('Ver 2 productos mas'));
    await tester.pumpAndSettle();

    expect(find.text('Producto 10'), findsOneWidget);
    expect(find.text('Ver menos'), findsOneWidget);
  });
}
