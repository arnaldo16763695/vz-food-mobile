import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:vz_food/core/auth/auth_session.dart';
import 'package:vz_food/features/auth/presentation/login_screen.dart';

// Covers the login surface's mode switching and result handling without a real
// Supabase client: sign-up that needs confirmation returns the customer to the
// sign-in form with guidance, and SDK errors render as mapped Spanish copy.

class _MockAuthAccountService extends Mock implements AuthAccountService {}

Future<void> _pumpLoginScreen(
  WidgetTester tester, {
  required AuthAccountService service,
  bool hasSupabaseConfig = true,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: LoginScreen(
        authAccountService: service,
        hasSupabaseConfig: hasSupabaseConfig,
      ),
    ),
  );
}

void main() {
  late _MockAuthAccountService service;

  setUp(() {
    service = _MockAuthAccountService();
  });

  testWidgets('starts in sign-in mode and can switch to sign-up', (
    tester,
  ) async {
    await _pumpLoginScreen(tester, service: service);

    expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'Crear cuenta'), findsOneWidget);
  });

  testWidgets(
    'sign-up that needs confirmation returns to sign-in with a note',
    (tester) async {
      when(
        () => service.signUpWithEmailPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => const AuthSignUpResult(needsEmailConfirmation: true),
      );

      await _pumpLoginScreen(tester, service: service);
      await tester.tap(find.widgetWithText(TextButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
      expect(find.textContaining('Confirmala'), findsOneWidget);
    },
  );

  testWidgets('maps invalid credentials to a friendly message', (tester) async {
    when(
      () => service.signInWithEmailPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const AuthException('Invalid login credentials'));

    await _pumpLoginScreen(tester, service: service);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'jane@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'whatever',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Email o contrasena incorrectos.'), findsOneWidget);
  });

  testWidgets('reset mode hides the password field and sends an email', (
    tester,
  ) async {
    when(
      () => service.sendPasswordReset(email: any(named: 'email')),
    ).thenAnswer((_) async {});

    await _pumpLoginScreen(tester, service: service);
    await tester.tap(find.widgetWithText(TextButton, 'Olvide mi contrasena'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Password'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'jane@example.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Enviar enlace'));
    await tester.pumpAndSettle();

    verify(
      () => service.sendPasswordReset(email: 'jane@example.com'),
    ).called(1);
    expect(find.textContaining('te enviamos un enlace'), findsOneWidget);
  });

  testWidgets('shows the config warning when Supabase is not configured', (
    tester,
  ) async {
    await _pumpLoginScreen(tester, service: service, hasSupabaseConfig: false);

    expect(
      find.textContaining('Falta configurar SUPABASE_URL'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsNothing);
  });
}
