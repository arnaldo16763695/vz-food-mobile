import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_session.dart';

class SupabaseAuthSession implements AuthSession {
  SupabaseAuthSession(this._client);

  final SupabaseClient _client;

  @override
  Future<String?> getAccessToken() async {
    return _client.auth.currentSession?.accessToken;
  }
}

class SupabaseAccountService implements AuthAccountService {
  SupabaseAccountService(this._client);

  final SupabaseClient _client;

  @override
  Stream<AuthAccountState> authStateChanges() {
    return _client.auth.onAuthStateChange.map((_) => currentState());
  }

  @override
  AuthAccountState currentState() {
    final user = _client.auth.currentUser;
    return AuthAccountState(
      isAuthenticated: user != null,
      email: user?.email,
      userId: user?.id,
    );
  }

  @override
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<AuthSignUpResult> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    return AuthSignUpResult(needsEmailConfirmation: response.session == null);
  }

  @override
  Future<void> sendPasswordReset({required String email}) {
    return _client.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }
}
