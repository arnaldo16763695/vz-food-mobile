import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vz_food/core/auth/auth_session.dart';
import 'package:vz_food/features/bag/application/bag_count_controller.dart';
import 'package:vz_food/features/bag/infrastructure/bag_api.dart';
import 'package:vz_food/features/orders/domain/orders_models.dart';
import 'package:vz_food/features/orders/infrastructure/orders_api.dart';
import 'package:vz_food/features/orders/presentation/orders_screen.dart';

// Locks in the compact orders list: client-side paging (6 per page) and
// backend status codes rendered in Spanish.

class _MockOrdersApi extends Mock implements OrdersApi {}

class _MockBagApi extends Mock implements BagApi {}

class _MockAuthSession extends Mock implements AuthSession {}

OrdersPayload _orders(int count) {
  return OrdersPayload.fromJson({
    'orders': [
      for (var i = 1; i <= count; i++)
        {
          'id': 'o$i',
          'orderNumber': 1000 + i,
          'status': 'processing',
          'fulfillmentType': 'pickup',
          'totalAmount': 10.0 + i,
          'placedAt': '2026-09-01T10:00:00.000Z',
          'itemCount': i,
        },
    ],
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
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    return tester.pumpWidget(
      MaterialApp(
        home: OrdersScreen(
          authSession: authSession,
          bagApi: _MockBagApi(),
          bagCountController: BagCountController(),
          ordersApi: ordersApi,
          tenantSlug: 'acme',
          branchId: null,
        ),
      ),
    );
  }

  testWidgets('renders backend status codes in Spanish', (tester) async {
    when(
      () => ordersApi.fetchOrders(tenantSlug: 'acme', accessToken: 'tok'),
    ).thenAnswer((_) async => _orders(2));

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('En preparacion'), findsNWidgets(2));
    expect(find.text('Retiro'), findsNWidgets(2));
    expect(find.textContaining('processing'), findsNothing);
  });

  testWidgets('pages the list 6 at a time', (tester) async {
    when(
      () => ordersApi.fetchOrders(tenantSlug: 'acme', accessToken: 'tok'),
    ).thenAnswer((_) async => _orders(8));

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('#1001'), findsOneWidget);
    expect(find.text('#1006'), findsOneWidget);
    expect(find.text('#1007'), findsNothing);
    expect(find.text('Pagina 1 de 2'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Pagina 2 de 2'), findsOneWidget);
    expect(find.text('#1007'), findsOneWidget);
    expect(find.text('#1008'), findsOneWidget);
    expect(find.text('#1001'), findsNothing);
  });

  testWidgets('hides the pager when a single page is enough', (tester) async {
    when(
      () => ordersApi.fetchOrders(tenantSlug: 'acme', accessToken: 'tok'),
    ).thenAnswer((_) async => _orders(3));

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Pagina'), findsNothing);
  });
}
