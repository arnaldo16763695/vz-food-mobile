import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:vz_food/core/auth/auth_session.dart';
import 'package:vz_food/features/auth/presentation/reset_password_screen.dart';

// The recovery session is single-use, so this screen must validate the new
// password locally before spending it, and return the customer home on success.

class _MockAuthAccountService extends Mock implements AuthAccountService {}

Future<void> _pumpResetPasswordScreen(
  WidgetTester tester, {
  required AuthAccountService service,
}) {
  final router = GoRouter(
    initialLocation: '/reset-password',
    routes: [
      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            ResetPasswordScreen(authAccountService: service),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HOME SCREEN')),
      ),
    ],
  );
  return tester.pumpWidget(MaterialApp.router(routerConfig: router));
}

void main() {
  late _MockAuthAccountService service;

  setUp(() {
    service = _MockAuthAccountService();
  });

  testWidgets('rejects mismatched passwords without calling the service', (
    tester,
  ) async {
    await _pumpResetPasswordScreen(tester, service: service);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nueva contrasena'),
      'secret123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar contrasena'),
      'secret999',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar contrasena'));
    await tester.pumpAndSettle();

    expect(find.text('Las contrasenas no coinciden'), findsOneWidget);
    verifyNever(
      () => service.updatePassword(newPassword: any(named: 'newPassword')),
    );
  });

  testWidgets('rejects a short password', (tester) async {
    await _pumpResetPasswordScreen(tester, service: service);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nueva contrasena'),
      '123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar contrasena'),
      '123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar contrasena'));
    await tester.pumpAndSettle();

    expect(find.text('Minimo 6 caracteres'), findsOneWidget);
    verifyNever(
      () => service.updatePassword(newPassword: any(named: 'newPassword')),
    );
  });

  testWidgets('updates the password and returns home on success', (
    tester,
  ) async {
    when(
      () => service.updatePassword(newPassword: any(named: 'newPassword')),
    ).thenAnswer((_) async {});

    await _pumpResetPasswordScreen(tester, service: service);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nueva contrasena'),
      'secret123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar contrasena'),
      'secret123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar contrasena'));
    await tester.pumpAndSettle();

    verify(() => service.updatePassword(newPassword: 'secret123')).called(1);
    expect(find.text('HOME SCREEN'), findsOneWidget);
  });

  testWidgets('maps a service failure to a friendly message', (tester) async {
    when(
      () => service.updatePassword(newPassword: any(named: 'newPassword')),
    ).thenThrow(
      const AuthException('Password should be at least 6 characters'),
    );

    await _pumpResetPasswordScreen(tester, service: service);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nueva contrasena'),
      'secret123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar contrasena'),
      'secret123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar contrasena'));
    await tester.pumpAndSettle();

    expect(find.text('La contrasena es demasiado corta.'), findsOneWidget);
    expect(find.text('HOME SCREEN'), findsNothing);
  });
}
