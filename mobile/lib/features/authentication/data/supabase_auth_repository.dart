import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/authentication/auth_redirects.dart';
import '../domain/auth_models.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AuthSessionEvent> get authEvents {
    return _client.auth.onAuthStateChange.map((state) {
      final user = state.session?.user ?? _client.auth.currentUser;

      return AuthSessionEvent(
        type: _eventTypeFor(state.event.name),
        user: user == null ? null : _toAuthenticatedUser(user),
      );
    });
  }

  @override
  Future<AuthenticatedUser?> restoreSession() async {
    final user = _client.auth.currentUser;
    return user == null ? null : _toAuthenticatedUser(user);
  }

  @override
  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;

    if (user == null) {
      throw const AuthenticationServiceException(
        'Authentication did not return a user.',
      );
    }

    return _toAuthenticatedUser(user);
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: AuthRedirects.callback.toString(),
    );
    final user = response.user;

    if (user == null) {
      throw const AuthenticationServiceException(
        'Account creation did not return a user.',
      );
    }

    if (response.session == null) {
      return SignUpResult.verificationRequired(email: email);
    }

    return SignUpResult.authenticated(user: _toAuthenticatedUser(user));
  }

  @override
  Future<void> resendVerification({required String email}) async {
    await _client.auth.resend(
      email: email,
      type: OtpType.signup,
      emailRedirectTo: AuthRedirects.callback.toString(),
    );
  }

  @override
  Future<void> requestPasswordRecovery({required String email}) {
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: AuthRedirects.callback.toString(),
    );
  }

  @override
  Future<void> updatePassword({required String password}) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  AuthSessionEventType _eventTypeFor(String eventName) {
    return switch (eventName) {
      'signedOut' => AuthSessionEventType.signedOut,
      'passwordRecovery' => AuthSessionEventType.passwordRecovery,
      'tokenRefreshed' => AuthSessionEventType.tokenRefreshed,
      'userUpdated' => AuthSessionEventType.userUpdated,
      _ => AuthSessionEventType.signedIn,
    };
  }

  AuthenticatedUser _toAuthenticatedUser(User user) {
    return AuthenticatedUser(id: user.id, email: user.email ?? '');
  }
}

class AuthenticationServiceException implements Exception {
  const AuthenticationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
