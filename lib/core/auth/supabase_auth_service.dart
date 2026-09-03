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
  SupabaseAccountService(this._client, {required this.authRedirectUrl});

  final SupabaseClient _client;

  /// Deep link the backend appends its token/code to for email confirmation and
  /// password recovery. Must be allow-listed in the Supabase project's auth
  /// "Redirect URLs" and registered as a native scheme on Android/iOS.
  final String authRedirectUrl;

  @override
  Stream<AuthAccountState> authStateChanges() {
    return _client.auth.onAuthStateChange.map((_) => currentState());
  }

  @override
  Stream<AuthLifecycleEvent> lifecycleEvents() {
    return _client.auth.onAuthStateChange.map((data) {
      switch (data.event) {
        case AuthChangeEvent.passwordRecovery:
          return AuthLifecycleEvent.passwordRecovery;
        case AuthChangeEvent.signedIn:
          return AuthLifecycleEvent.signedIn;
        case AuthChangeEvent.signedOut:
          return AuthLifecycleEvent.signedOut;
        default:
          return AuthLifecycleEvent.other;
      }
    });
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
      emailRedirectTo: authRedirectUrl,
    );
    return AuthSignUpResult(needsEmailConfirmation: response.session == null);
  }

  @override
  Future<void> sendPasswordReset({required String email}) {
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: authRedirectUrl,
    );
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }
}
