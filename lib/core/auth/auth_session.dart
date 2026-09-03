abstract class AuthSession {
  Future<String?> getAccessToken();
}

class NoopAuthSession implements AuthSession {
  @override
  Future<String?> getAccessToken() async => null;
}

abstract class AuthAccountService {
  Stream<AuthAccountState> authStateChanges();
  AuthAccountState currentState();
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  });
  Future<AuthSignUpResult> signUpWithEmailPassword({
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset({required String email});
  Future<void> signOut();
}

class AuthAccountState {
  const AuthAccountState({
    required this.isAuthenticated,
    this.email,
    this.userId,
  });

  final bool isAuthenticated;
  final String? email;
  final String? userId;
}

/// Outcome of a sign-up attempt. When the backend requires email confirmation
/// the SDK returns a user without a session, so the customer must confirm the
/// address before they can sign in.
class AuthSignUpResult {
  const AuthSignUpResult({required this.needsEmailConfirmation});

  final bool needsEmailConfirmation;
}
