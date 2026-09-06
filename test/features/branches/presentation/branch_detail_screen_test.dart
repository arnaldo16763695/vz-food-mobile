import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vz_food/features/branches/domain/branch_detail.dart';
import 'package:vz_food/features/branches/infrastructure/branches_api.dart';
import 'package:vz_food/features/branches/presentation/branch_detail_screen.dart';

class _MockBranchesApi extends Mock implements BranchesApi {}

BranchDetailPayload _payload({
  required bool isActive,
  required bool storefrontEnabled,
}) {
  return BranchDetailPayload.fromJson({
    'branch': {
      'id': 'branch-1',
      'name': 'Centro',
      'addressLine1': 'Av. Principal 123',
      'city': 'Caracas',
      'isActive': isActive,
      'tenant': {
        'id': 'tenant-1',
        'name': 'Acme',
        'slug': 'acme',
        'storefrontEnabled': storefrontEnabled,
      },
    },
  });
}

Future<void> _pump(WidgetTester tester, BranchesApi api) {
  return tester.pumpWidget(
    MaterialApp(
      home: BranchDetailScreen(branchesApi: api, branchId: 'branch-1'),
    ),
  );
}

void main() {
  late _MockBranchesApi api;

  setUp(() {
    api = _MockBranchesApi();
  });

  testWidgets('renders the branch and enables "Ver menu" when reachable', (
    tester,
  ) async {
    when(() => api.fetchBranchDetail(branchId: 'branch-1')).thenAnswer(
      (_) async => _payload(isActive: true, storefrontEnabled: true),
    );

    await _pump(tester, api);
    await tester.pumpAndSettle();

    expect(find.text('Centro'), findsOneWidget);
    expect(find.text('Av. Principal 123, Caracas'), findsOneWidget);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Ver menu'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('disables "Ver menu" and explains when the branch is inactive', (
    tester,
  ) async {
    when(() => api.fetchBranchDetail(branchId: 'branch-1')).thenAnswer(
      (_) async => _payload(isActive: false, storefrontEnabled: true),
    );

    await _pump(tester, api);
    await tester.pumpAndSettle();

    expect(find.text('Inactiva'), findsOneWidget);
    expect(find.textContaining('inactiva por ahora'), findsOneWidget);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Ver menu'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('shows an error with retry when the request fails', (
    tester,
  ) async {
    when(
      () => api.fetchBranchDetail(branchId: 'branch-1'),
    ).thenAnswer((_) => Future.error(Exception('boom')));

    await _pump(tester, api);
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar la sucursal'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Reintentar'), findsOneWidget);
  });
}
