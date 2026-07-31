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
